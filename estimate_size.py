#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py (Refactored Version)

# --- Imports ---
import sys
import subprocess
import json
import argparse
import shutil # To find yt-dlp executable
import re     # For parsing format selectors
import os     # For checking file existence
import traceback # For detailed exception logging

# --- Global Variables ---
# Increment version number for this refactored attempt
SCRIPT_VERSION = "v1.2.0(Refactored-Debug)"
DEBUG_ENABLED = True # Keep debugging enabled for now

# --- Helper Functions for Logging ---
def debug_print(*args, **kwargs):
    if DEBUG_ENABLED: print("DEBUG:", *args, file=sys.stderr, **kwargs)
def error_print(*args, **kwargs): print("ERROR:", *args, file=sys.stderr, **kwargs)
def warning_print(*args, **kwargs): print("WARNING:", *args, file=sys.stderr, **kwargs)

# --- Helper Function to Get Size ---
def get_format_size(format_info):
    """Gets the size of a format, prioritizing 'filesize' over 'filesize_approx'."""
    if not isinstance(format_info, dict): return 0
    filesize = format_info.get('filesize')
    filesize_approx = format_info.get('filesize_approx')
    if isinstance(filesize, (int, float)) and filesize > 0: return int(filesize)
    if isinstance(filesize_approx, (int, float)) and filesize_approx > 0: return int(filesize_approx)
    return 0

# --- Helper Function to Parse yt-dlp format filter string ---
def parse_filter(filter_str):
    """Parses simple filters like [height<=1080][ext=mp4]."""
    filters = {}
    pattern = r"\[([a-zA-Z_]+)\s*(<=|>=)?\s*([a-zA-Z0-9_.-]+)\]"
    matches = re.findall(pattern, filter_str)
    for key, op, value in matches:
        op = op if op else '=='
        val_processed = value
        if op in ['<=', '>=']:
            try: val_processed = int(value)
            except ValueError: continue # Skip if non-int for numeric comparison
        filters[key] = (op, val_processed)
    return filters

# --- Helper Function to Check if a format matches filters ---
def format_matches_filters(format_info, filters):
    """Checks if a format dict matches the parsed filters."""
    if not isinstance(format_info, dict): return False
    for key, (op, expected_value) in filters.items():
        actual_value = format_info.get(key)
        if actual_value is None: return False # Filter key not present
        try:
            if op == '==':
                # Special case for 'ext' - compare case-insensitively
                if key == 'ext':
                    if str(actual_value).lower() != str(expected_value).lower(): return False
                elif str(actual_value) != str(expected_value): return False # Other string comparisons
            elif op == '<=':
                if not (isinstance(actual_value, (int, float)) and actual_value <= expected_value): return False
            elif op == '>=':
                 if not (isinstance(actual_value, (int, float)) and actual_value >= expected_value): return False
        except Exception as e:
             warning_print(f"Filter comparison error: key='{key}', op='{op}', expected='{expected_value}', actual='{actual_value}', error={e}")
             return False # Treat comparison errors as filter failure
    return True

# --- Refactored Function to Select Best Format ---
def select_best_filtered_format(available_formats, selector):
    """
    Selects the best format matching the selector (e.g., 'bv[ext=mp4][height<=1080]').
    Applies type filtering first, then explicit filters, then sorts.
    """
    debug_print(f"\n===== Running select_best_filtered_format for selector: '{selector}' =====")
    if not available_formats or not selector:
        warning_print("  select_best_filtered_format: (Exit A) No available formats or selector. Returning None.")
        return None

    # --- Parse selector and filters ---
    base_selector = selector.split('[', 1)[0]
    filter_str = '[' + selector.split('[', 1)[1] if '[' in selector else ''
    filters = parse_filter(filter_str)
    debug_print(f"  Base selector='{base_selector}', Parsed filters={filters}")

    # --- Step 1: Filter by TYPE based on base_selector ---
    type_matched_formats = []
    debug_print(f"  Step 1: Filtering {len(available_formats)} formats by TYPE ('{base_selector}')...")
    for fmt in available_formats:
        vcodec = fmt.get('vcodec')
        acodec = fmt.get('acodec')
        has_video = vcodec is not None and vcodec != 'none'
        has_audio = acodec is not None and acodec != 'none'
        is_video_only = has_video and not has_audio
        is_audio_only = has_audio and not has_video
        is_merged = has_video and has_audio

        type_ok = False
        if base_selector.startswith('bv'):
            if is_video_only: type_ok = True
        elif base_selector.startswith('ba'):
            if is_audio_only: type_ok = True
        elif base_selector == 'b' or base_selector == 'best':
            if is_video_only or is_audio_only or is_merged: type_ok = True
        else: # Assume specific ID or other selector
            type_ok = True # Rely on explicit filters later

        if type_ok:
            type_matched_formats.append(fmt)

    debug_print(f"  Step 1 Result: {len(type_matched_formats)} formats passed TYPE filter.")
    if not type_matched_formats:
        debug_print(f"  select_best_filtered_format: (Exit B1) No formats passed TYPE filtering. Returning None.")
        return None

    # --- Step 2: Filter by explicit FILTERS ---
    filtered_formats = []
    debug_print(f"  Step 2: Applying explicit filters {filters} to {len(type_matched_formats)} candidates...")
    if filters:
        for fmt in type_matched_formats:
            if format_matches_filters(fmt, filters):
                filtered_formats.append(fmt)
        debug_print(f"  Step 2 Result: {len(filtered_formats)} formats passed explicit filters.")
    else:
        debug_print("  Step 2 Result: No explicit filters to apply.")
        filtered_formats = type_matched_formats # All type-matched pass

    if not filtered_formats:
        debug_print(f"  select_best_filtered_format: (Exit B2) No formats passed EXPLICIT filtering. Returning None.")
        return None

    # --- Step 3: Sorting ---
    debug_print(f"  Step 3: Sorting {len(filtered_formats)} final candidates...")

    def sort_key(fmt):
        size = get_format_size(fmt)
        has_valid_size = 1 if size > 0 else 0
        height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
        vbr = fmt.get('vbr') if isinstance(fmt.get('vbr'), (int, float)) else 0
        tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
        video_rate = vbr if vbr > 0 else tbr
        abr = fmt.get('abr') if isinstance(fmt.get('abr'), (int, float)) else 0
        # Include 'ext' preference (e.g., prefer mp4 over webm if quality is similar?) - Optional
        ext = fmt.get('ext', '')
        ext_pref = 1 if ext == 'mp4' else 0 # Example preference
        # Return sort tuple
        # Prioritize: Has Size > Height > Video Rate > Audio Rate > Ext Pref > Size
        return (has_valid_size, height, video_rate, abr, ext_pref, size)

    sorted_formats = []
    try:
        sorted_formats = sorted(filtered_formats, key=sort_key, reverse=True)
        debug_print(f"  Sorting successful. Top 5 results:")
        for i, fmt in enumerate(sorted_formats[:5]):
             debug_print(f"    {i+1}: ID={fmt.get('format_id')}, HasSize={1 if get_format_size(fmt)>0 else 0}, H={fmt.get('height')}, VR={fmt.get('vbr') or fmt.get('tbr')}, AR={fmt.get('abr')}, Ext={fmt.get('ext')}, Size={get_format_size(fmt)}")

    except Exception as e:
        error_print(f"  >>> EXCEPTION DURING SORTING: {e} <<<")
        traceback.print_exc(file=sys.stderr)
        warning_print("  Fallback: Sorting failed. Using first format that passed filters.")
        if filtered_formats:
             selected_format = filtered_formats[0]
             warning_print(f"  Fallback: Using unfiltered first match: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
             debug_print(f"  select_best_filtered_format: (Exit C - Fallback). Returning unfiltered first match.")
             return selected_format
        else:
             error_print("  Fallback failed: filtered_formats list empty!")
             debug_print(f"  select_best_filtered_format: (Exit D - Fallback failed). Returning None.")
             return None

    # --- Step 4: Selection ---
    if not sorted_formats:
        error_print("  >>> ERROR: sorted_formats list empty after sort! <<<")
        debug_print(f"  select_best_filtered_format: (Exit E - List empty after sort). Returning None.")
        return None

    selected_format = sorted_formats[0]
    if selected_format and isinstance(selected_format, dict):
        debug_print(f"  Selected Best: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
        debug_print(f"===== select_best_filtered_format for '{selector}' finished successfully. Returning format. =====")
        return selected_format
    else:
        error_print(f"  >>> ERROR: Invalid selected format! Value: {selected_format} <<<")
        debug_print(f"  select_best_filtered_format: (Exit F - Invalid selected format). Returning None.")
        return None
# <<< select_best_filtered_format 函數定義結束 >>>


# --- Main Execution Function ---
def main():
    debug_print(f"--- estimate_size.py {SCRIPT_VERSION} Starting ---")
    # --- Argument Parsing (保持不變) ---
    parser = argparse.ArgumentParser(
        description="Estimate media size by simulating yt-dlp format selection.",
        epilog="Example: python estimate_size.py 'https://...' 'bv[ext=mp4]+ba[ext=m4a]/b'"
    )
    parser.add_argument("url", nargs='?', default=None, help="Media URL")
    parser.add_argument("format_selector", nargs='?', default=None, help="yt-dlp format selector string")
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}", help="Show program's version number and exit")
    try:
        args = parser.parse_args()
        debug_print(f"Arguments received: URL='{args.url}', Format='{args.format_selector}'")
    except SystemExit as e: sys.exit(e.code)
    except Exception as e: error_print(f"Error parsing arguments: {e}"); print("0"); sys.exit(1)
    if args.url is None or args.format_selector is None:
        if len(sys.argv) <= 1: parser.print_help(sys.stderr); sys.exit(1)
        # Handle missing arguments if not exiting due to --version etc.
        if args.url is None: error_print("Media URL is required."); print("0"); sys.exit(1)
        if args.format_selector is None: error_print("Format selector is required."); print("0"); sys.exit(1)

    # --- Get ALL available formats (保持不變, 但增加錯誤處理) ---
    debug_print("\nStep 1: Getting all available formats using yt-dlp --dump-json...")
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd: error_print("yt-dlp command not found."); print("0"); sys.exit(1)
    if not os.path.exists(yt_dlp_cmd): error_print(f"yt-dlp path '{yt_dlp_cmd}' not found."); print("0"); sys.exit(1)

    command_list_formats = [yt_dlp_cmd, "--no-warnings", "--dump-json", args.url]
    available_formats = []
    try:
        debug_print(f"Running command: {' '.join(command_list_formats)}")
        process = subprocess.run(command_list_formats, capture_output=True, text=True, encoding='utf-8', check=False, timeout=60)
        debug_print(f"yt-dlp (dump-json) exited with code {process.returncode}")
        if process.returncode != 0: error_print(f"yt-dlp (dump-json) failed.\nstderr:\n{process.stderr}"); print("0"); sys.exit(0)
        if not process.stdout.strip(): error_print(f"yt-dlp (dump-json) empty stdout."); print("0"); sys.exit(0)
        media_info = json.loads(process.stdout)
        if isinstance(media_info, list): media_info = media_info[0]
        if not isinstance(media_info, dict): error_print("Parsed JSON not a dict."); print("0"); sys.exit(0)
        available_formats = media_info.get('formats')
        if not available_formats or not isinstance(available_formats, list):
             if media_info.get('format_id'): available_formats = [media_info]
             else: warning_print("No 'formats' list found."); print("0"); sys.exit(0)
        debug_print(f"Successfully retrieved {len(available_formats)} formats.")
    except Exception as e: error_print(f"Error getting/parsing formats: {e}"); print("0"); sys.exit(1)
    if not available_formats: warning_print("Available formats list empty."); print("0"); sys.exit(0)

    # --- Simulate Format Selection (主邏輯 - 保持不變) ---
    debug_print(f"\nStep 2: Simulating format selection for: '{args.format_selector}'")
    final_estimated_size = 0
    selection_groups = args.format_selector.split('/')
    debug_print(f"Found {len(selection_groups)} selection group(s): {selection_groups}")
    group_found = False
    for i, group in enumerate(selection_groups):
        debug_print(f"\n--- Processing Selection Group {i+1}: '{group}' ---")
        group_estimated_size = 0
        all_parts_found = True
        individual_selectors = group.split('+')
        debug_print(f"  Group parts: {individual_selectors}")
        selected_formats_in_group_ids = set()
        for j, selector in enumerate(individual_selectors):
            debug_print(f"  --- Processing Part {j+1}: '{selector}' ---")
            best_match = select_best_filtered_format(available_formats, selector) # Call the refactored function
            if best_match:
                format_id = best_match.get('format_id')
                if format_id not in selected_formats_in_group_ids:
                    part_size = get_format_size(best_match)
                    debug_print(f"    Part {j+1} Match: ID={format_id}, Size={part_size}")
                    # Only add size if it's positive. If a part MUST have size, fail group if part_size is 0.
                    # Current logic: Allow 0 size parts, they just don't add to total.
                    if part_size > 0: group_estimated_size += part_size
                    else: warning_print(f"    Part {j+1} Match (ID={format_id}) has size 0.")
                    selected_formats_in_group_ids.add(format_id) # Mark as found even if size is 0
                else: debug_print(f"    Part {j+1}: Format ID {format_id} already included.")
            else:
                debug_print(f"    >>>>> Part {j+1} ('{selector}') FAILED to find match. <<<<<")
                all_parts_found = False; break # Fail this group
        if all_parts_found:
            debug_print(f"--- SUCCESS: All parts found for Group {i+1} ('{group}'). Estimated Size: {group_estimated_size} ---")
            final_estimated_size = group_estimated_size; group_found = True; break # Use this group and stop
        else: debug_print(f"--- FAILED: Could not find all parts for Group {i+1} ('{group}'). Trying next fallback. ---")
    if not group_found: warning_print("Could not satisfy any selection group completely.")

    # --- Output Final Result ---
    debug_print(f"\n--- Final Estimated Size Calculation ---")
    debug_print(f"Total Estimated Size (bytes): {final_estimated_size}")
    print(final_estimated_size) # !!! IMPORTANT: Only print the final number to stdout !!!
    sys.exit(0)

# --- Script Entry Point ---
if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        # Catch unexpected errors in main execution
        error_print(f"An unexpected error occurred in main: {e}")
        traceback.print_exc(file=sys.stderr)
        print("0") # Output 0 on unexpected error
        sys.exit(1)
