#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py (Corrected Structure)

import sys
import subprocess
import json
import argparse
import shutil
import re
import os # For checking file existence

# --- 全局變數 ---
SCRIPT_VERSION = "v1.1.7(Experimental-Debug)" # Keep your version
DEBUG_ENABLED = True # Set to False to disable debug prints

def debug_print(*args, **kwargs):
    """Helper function for conditional debug printing to stderr."""
    if DEBUG_ENABLED:
        print("DEBUG:", *args, file=sys.stderr, **kwargs)

def error_print(*args, **kwargs):
    """Helper function for error printing to stderr."""
    print("ERROR:", *args, file=sys.stderr, **kwargs)

def warning_print(*args, **kwargs):
    """Helper function for warning printing to stderr."""
    print("WARNING:", *args, file=sys.stderr, **kwargs)

# --- Helper Function to Get Size ---
def get_format_size(format_info):
    # (函數內容保持不變)
    if not isinstance(format_info, dict): return 0
    filesize = format_info.get('filesize')
    filesize_approx = format_info.get('filesize_approx')
    format_id = format_info.get('format_id', 'N/A')
    if isinstance(filesize, (int, float)) and filesize > 0: return int(filesize)
    elif isinstance(filesize_approx, (int, float)) and filesize_approx > 0: return int(filesize_approx)
    else: return 0

# --- Helper Function to Parse yt-dlp format filter string ---
def parse_filter(filter_str):
    # (函數內容保持不變)
    filters = {}
    pattern = r"\[([a-zA-Z_]+)\s*(<=|>=)?\s*([a-zA-Z0-9_.-]+)\]"
    matches = re.findall(pattern, filter_str)
    for key, op, value in matches:
        op = op if op else '=='
        val_processed = value
        if op in ['<=', '>=']:
            try: val_processed = int(value)
            except ValueError: continue
        filters[key] = (op, val_processed)
    return filters

# --- Helper Function to Check if a format matches filters ---
def format_matches_filters(format_info, filters):
    # (函數內容保持不變)
    if not isinstance(format_info, dict): return False
    for key, (op, expected_value) in filters.items():
        actual_value = format_info.get(key)
        if actual_value is None: return False
        try:
            if op == '==':
                if str(actual_value).lower() != str(expected_value).lower(): return False
            elif op == '<=':
                if not (isinstance(actual_value, (int, float)) and actual_value <= expected_value): return False
            elif op == '>=':
                 if not (isinstance(actual_value, (int, float)) and actual_value >= expected_value): return False
        except Exception: return False
    return True

# --- Helper Function to Select Best Format based on Filters and Preference (Corrected Version) ---
def select_best_filtered_format(available_formats, selector):
    debug_print(f"\n===== Running select_best_filtered_format for selector: '{selector}' =====")
    if not available_formats or not selector:
        warning_print("  select_best_filtered_format: (Exit A) No available formats or selector provided. Returning None.")
        return None

    base_selector = selector.split('[', 1)[0]
    filter_str = '[' + selector.split('[', 1)[1] if '[' in selector else ''
    filters = parse_filter(filter_str)
    debug_print(f"  Base selector='{base_selector}', Parsed filters={filters}")

    matching_formats = []
    debug_print(f"  Filtering {len(available_formats)} available formats...")
    for index, fmt in enumerate(available_formats):
        format_id = fmt.get('format_id', f'Unknown_{index}')
        is_video = fmt.get('vcodec') != 'none' and fmt.get('vcodec') is not None
        is_audio = fmt.get('acodec') != 'none' and fmt.get('acodec') is not None

        # --- Corrected Type Matching ---
        type_match = False
        if base_selector.startswith('bv'):
            if is_video and not is_audio: type_match = True
        elif base_selector.startswith('ba'):
            if is_audio and not is_video: type_match = True
        elif base_selector == 'b':
             if is_video or is_audio: type_match = True
        elif base_selector == 'best':
             if is_video or is_audio: type_match = True
        else: # Assume specific ID or other; rely on filters
             type_match = True
        # --- End Corrected Type Matching ---

        if type_match:
            if format_matches_filters(fmt, filters):
                matching_formats.append(fmt)

    debug_print(f"  Filtering complete. Found {len(matching_formats)} matching formats.")

    if not matching_formats:
        debug_print(f"  select_best_filtered_format: (Exit B) No formats passed filtering for '{selector}'. Returning None.")
        return None

    # --- Sorting ---
    debug_print(f"  Attempting to sort {len(matching_formats)} matching formats (prioritizing valid size)...")

    # Define sort_key function (Only defined HERE, inside the function)
    def sort_key(fmt):
        size = get_format_size(fmt)
        has_valid_size = 1 if size > 0 else 0
        height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
        vbr = fmt.get('vbr') if isinstance(fmt.get('vbr'), (int, float)) else 0
        tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
        video_rate = vbr if vbr > 0 else tbr
        abr = fmt.get('abr') if isinstance(fmt.get('abr'), (int, float)) else 0
        return (has_valid_size, height, video_rate, abr, size)

    # Use a separate variable for the sorted list
    sorted_matching_formats = []
    try:
        # Correct try...except block (Only occurs HERE)
        sorted_matching_formats = sorted(matching_formats, key=sort_key, reverse=True)
        debug_print(f"  Sorting successful. Top 5 results (or fewer):")
        for i, fmt in enumerate(sorted_matching_formats[:5]):
             debug_print(f"    {i+1}: ID={fmt.get('format_id')}, HasSize={1 if get_format_size(fmt)>0 else 0}, H={fmt.get('height')}, VR={fmt.get('vbr') or fmt.get('tbr')}, AR={fmt.get('abr')}, Size={get_format_size(fmt)}")

    except Exception as e:
        error_print(f"  >>> EXCEPTION DURING SORTING: {e} <<<")
        import traceback
        traceback.print_exc(file=sys.stderr)
        error_print(f"  >>> END OF EXCEPTION TRACEBACK <<<")
        warning_print("  Fallback: Sorting failed. Attempting to use first unsorted match.")
        if matching_formats:
             selected_format = matching_formats[0]
             warning_print(f"  Fallback: Using unsorted first match: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
             debug_print(f"  select_best_filtered_format: (Exit C - Fallback due to sort exception). Returning unsorted first match.")
             return selected_format
        else:
             error_print("  Fallback failed: Original matching_formats list is missing or empty!")
             debug_print(f"  select_best_filtered_format: (Exit D - Fallback failed in exception). Returning None.")
             return None

    # --- Selection after successful sort ---
    if not sorted_matching_formats:
        error_print("  >>> ERROR: sorted_matching_formats is unexpectedly empty after successful sort call! <<<")
        debug_print(f"  select_best_filtered_format: (Exit E - List empty after sort). Returning None.")
        return None

    selected_format = sorted_matching_formats[0]
    if selected_format and isinstance(selected_format, dict):
        debug_print(f"  Selected Best after sort: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
        debug_print(f"===== select_best_filtered_format for '{selector}' finished successfully. Returning format. =====")
        return selected_format
    else:
        error_print(f"  >>> ERROR: selected_format is invalid after sorting! Value: {selected_format} <<<")
        debug_print(f"  select_best_filtered_format: (Exit F - Invalid selected format). Returning None.")
        return None
# <<< select_best_filtered_format 函數定義結束 >>>


# --- Main Execution ---
def main():
    # (函數內容保持不變)
    debug_print(f"--- estimate_size.py {SCRIPT_VERSION} Starting ---")
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
    except SystemExit as e:
         debug_print(f"Argparse exited with code {e.code}")
         sys.exit(e.code)
    except Exception as e:
        error_print(f"Error parsing arguments: {e}"); print("0"); sys.exit(1)

    if args.url is None or args.format_selector is None:
        if len(sys.argv) <= 1: parser.print_help(sys.stderr); sys.exit(1)
        elif args.url is None: error_print("Media URL is required."); print("0"); sys.exit(1)
        elif args.format_selector is None: error_print("Format selector is required."); print("0"); sys.exit(1)
        else: sys.exit(1)

    debug_print("Step 1: Getting all available formats using yt-dlp --dump-json...")
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd: error_print("yt-dlp command not found in PATH."); print("0"); sys.exit(1)
    if not os.path.exists(yt_dlp_cmd): error_print(f"yt-dlp path found ('{yt_dlp_cmd}') but file does not exist."); print("0"); sys.exit(1)

    command_list_formats = [yt_dlp_cmd, "--no-warnings", "--dump-json", args.url]
    available_formats = []
    try:
        debug_print(f"Running command: {' '.join(command_list_formats)}")
        process = subprocess.run(command_list_formats, capture_output=True, text=True, encoding='utf-8', check=False, timeout=60)
        debug_print(f"yt-dlp (dump-json) exited with code {process.returncode}")
        if process.returncode != 0: error_print(f"yt-dlp (dump-json) failed."); error_print(f"stderr:\n{process.stderr}"); print("0"); sys.exit(0)
        if not process.stdout.strip(): error_print(f"yt-dlp (dump-json) produced empty stdout."); print("0"); sys.exit(0)
        media_info = json.loads(process.stdout)
        if isinstance(media_info, list): media_info = media_info[0]
        if not isinstance(media_info, dict): error_print("Parsed JSON is not a dict."); print("0"); sys.exit(0)
        available_formats = media_info.get('formats')
        if not available_formats or not isinstance(available_formats, list):
             if media_info.get('format_id'): available_formats = [media_info]; debug_print("Treating top-level JSON as single format.")
             else: warning_print("No 'formats' list found in JSON."); print("0"); sys.exit(0)
        debug_print(f"Successfully retrieved {len(available_formats)} available formats.")
    except subprocess.TimeoutExpired: error_print(f"yt-dlp (dump-json) timed out."); print("0"); sys.exit(0)
    except json.JSONDecodeError as e: error_print(f"Failed to decode JSON: {e}"); print("0"); sys.exit(0)
    except FileNotFoundError: error_print(f"Failed to execute yt-dlp command '{yt_dlp_cmd}'."); print("0"); sys.exit(1)
    except Exception as e: error_print(f"Error getting available formats: {e}"); print("0"); sys.exit(1)

    if not available_formats: warning_print("Available formats list is empty."); print("0"); sys.exit(0)

    debug_print(f"\nStep 2: Simulating format selection for selector: '{args.format_selector}'")
    final_estimated_size = 0
    selection_groups = args.format_selector.split('/')
    debug_print(f"Found {len(selection_groups)} selection group(s): {selection_groups}")
    group_found = False
    for i, group in enumerate(selection_groups):
        debug_print(f"\n--- Processing Selection Group {i+1}: '{group}' ---")
        group_estimated_size = 0
        all_parts_found = True
        individual_selectors = group.split('+')
        debug_print(f"  Group parts (split by '+'): {individual_selectors}")
        selected_formats_in_group_ids = set()
        for j, selector in enumerate(individual_selectors):
            debug_print(f"  --- Processing Part {j+1}: '{selector}' ---")
            best_match = select_best_filtered_format(available_formats, selector)
            if best_match:
                format_id = best_match.get('format_id')
                if format_id not in selected_formats_in_group_ids:
                    part_size = get_format_size(best_match)
                    debug_print(f"    Match found: ID={format_id}, Size={part_size}")
                    if part_size > 0:
                        group_estimated_size += part_size
                        selected_formats_in_group_ids.add(format_id)
                        debug_print(f"    Added size {part_size}. Current group total: {group_estimated_size}")
                    else: warning_print(f"    Match found (ID={format_id}) but has zero size. Not adding to total."); selected_formats_in_group_ids.add(format_id)
                else: debug_print(f"    Format ID {format_id} already included in this group. Skipping size addition.")
            else: debug_print(f"    >>>>> No suitable format found for selector part '{selector}' <<<<<"); all_parts_found = False; break
        if all_parts_found: debug_print(f"--- SUCCESS: All parts found for Group {i+1} ('{group}') ---"); final_estimated_size = group_estimated_size; group_found = True; break
        else: debug_print(f"--- FAILED: Could not find all parts for Group {i+1} ('{group}'). Trying next fallback (if any). ---")
    if not group_found: warning_print("Could not satisfy any selection group completely.")
    debug_print(f"\n--- Final Estimated Size Calculation ---")
    debug_print(f"Total Estimated Size (bytes): {final_estimated_size}")
    print(final_estimated_size)
    sys.exit(0)

if __name__ == "__main__":
    main()
