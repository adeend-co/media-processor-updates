#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py (Refactored with Bitrate Fallback)

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
SCRIPT_VERSION = "v1.3.0(Refactored-BitrateFallback-Debug)" # <<< 新版本號
DEBUG_ENABLED = True # Keep debugging enabled

# --- Logging Helpers ---
def debug_print(*args, **kwargs):
    if DEBUG_ENABLED: print("DEBUG:", *args, file=sys.stderr, **kwargs)
def error_print(*args, **kwargs): print("ERROR:", *args, file=sys.stderr, **kwargs)
def warning_print(*args, **kwargs): print("WARNING:", *args, file=sys.stderr, **kwargs)

# --- Helper Function to Get Size (with Bitrate Fallback) ---
def get_format_size(format_info):
    """
    Gets the size of a format.
    1. Prioritize 'filesize'.
    2. Fallback to 'filesize_approx'.
    3. Fallback to calculation using duration and bitrate (tbr or vbr+abr).
    Returns size in bytes or 0 if all methods fail.
    """
    if not isinstance(format_info, dict): return 0
    format_id = format_info.get('format_id', 'N/A')

    # 1. Try filesize
    filesize = format_info.get('filesize')
    if isinstance(filesize, (int, float)) and filesize > 0:
        # debug_print(f"    get_format_size({format_id}): Using 'filesize' = {int(filesize)}")
        return int(filesize)

    # 2. Try filesize_approx
    filesize_approx = format_info.get('filesize_approx')
    if isinstance(filesize_approx, (int, float)) and filesize_approx > 0:
        # debug_print(f"    get_format_size({format_id}): Using 'filesize_approx' = {int(filesize_approx)}")
        return int(filesize_approx)

    # 3. Try duration * bitrate calculation
    duration = format_info.get('duration')
    if isinstance(duration, (int, float)) and duration > 0:
        tbr = format_info.get('tbr') # Total bitrate (kbps)
        vbr = format_info.get('vbr') # Video bitrate (kbps)
        abr = format_info.get('abr') # Audio bitrate (kbps)

        total_bitrate_kbps = 0
        # Prefer tbr if available
        if isinstance(tbr, (int, float)) and tbr > 0:
            total_bitrate_kbps = tbr
            # debug_print(f"    get_format_size({format_id}): Using tbr={tbr} kbps for calculation.")
        else:
            # Otherwise, try summing vbr and abr
            calculated_tbr = 0
            if isinstance(vbr, (int, float)) and vbr > 0:
                calculated_tbr += vbr
                # debug_print(f"    get_format_size({format_id}): Adding vbr={vbr} kbps.")
            if isinstance(abr, (int, float)) and abr > 0:
                calculated_tbr += abr
                # debug_print(f"    get_format_size({format_id}): Adding abr={abr} kbps.")
            total_bitrate_kbps = calculated_tbr

        if total_bitrate_kbps > 0:
            # Convert kbps to bytes per second: (kbps * 1000) / 8
            bytes_per_second = (total_bitrate_kbps * 1000) / 8
            estimated_size = int(bytes_per_second * duration)
            debug_print(f"    get_format_size({format_id}): Calculated size from bitrate ({total_bitrate_kbps} kbps) and duration ({duration}s) = {estimated_size} bytes")
            return estimated_size
        # else:
            # debug_print(f"    get_format_size({format_id}): Bitrate/duration calculation failed (no valid bitrate).")

    # All methods failed
    # debug_print(f"    get_format_size({format_id}): All methods failed to get size. Returning 0.")
    return 0

# --- Helper Function to Parse Filters (AI Corrected Regex) ---
def parse_filter(filter_str):
    """Parses simple filters like [height<=1080][ext=mp4]. Corrected Regex."""
    filters = {}
    pattern = r"\[([a-zA-Z_]+)\s*(<=|>=|=)?\s*([a-zA-Z0-9_.-]+)\]"
    matches = re.findall(pattern, filter_str)
    for key, op, value in matches:
        op = op if op else '=='
        if op == '=': op = '=='
        val_processed = value
        if op in ['<=', '>='] and key not in ['ext', 'format_id', 'acodec', 'vcodec', 'protocol']:
            try: val_processed = int(value)
            except ValueError: continue
        filters[key] = (op, val_processed)
    # debug_print(f"    parse_filter: Parsed filters={filters}") # Optional debug
    return filters

# --- Helper Function to Match Filters (Prioritizing ext) ---
def format_matches_filters(format_info, filters):
    """Checks if a format dict matches filters, prioritizing 'ext'."""
    if not isinstance(format_info, dict): return False
    format_id = format_info.get('format_id', 'N/A')

    # Prioritize ext filter
    if 'ext' in filters:
        op_ext, expected_ext = filters['ext']
        actual_ext = format_info.get('ext', '')
        if op_ext == '==' and str(actual_ext).lower() != str(expected_ext).lower():
            return False # Ext mismatch

    # Check other filters
    for key, (op, expected_value) in filters.items():
        if key == 'ext': continue # Already checked
        actual_value = format_info.get(key)
        if actual_value is None: return False # Key missing
        try:
            if op == '==':
                if str(actual_value) != str(expected_value): return False
            elif op == '<=':
                if not (isinstance(actual_value, (int, float)) and actual_value <= expected_value): return False
            elif op == '>=':
                 if not (isinstance(actual_value, (int, float)) and actual_value >= expected_value): return False
        except Exception as e:
             warning_print(f"      Filter comparison error: key='{key}', error={e}")
             return False
    return True # Passed all checks

# --- select_best_filtered_format (Using Corrected Type Match & Filters) ---
def select_best_filtered_format(available_formats, selector):
    """Selects the best format based on type, filters, and sorting preference."""
    debug_print(f"\n===== Running select_best_filtered_format for selector: '{selector}' =====")
    if not available_formats or not selector: return None # Exit A

    base_selector = selector.split('[', 1)[0]
    filter_str = '[' + selector.split('[', 1)[1] if '[' in selector else ''
    filters = parse_filter(filter_str)
    debug_print(f"  Base selector='{base_selector}', Parsed filters={filters}")

    # --- Step 1: Filter by TYPE ---
    type_matched_formats = []
    debug_print(f"  Step 1: Filtering {len(available_formats)} formats by TYPE ('{base_selector}')...")
    for fmt in available_formats:
        format_id = fmt.get('format_id', 'N/A')
        vcodec = fmt.get('vcodec')
        acodec = fmt.get('acodec')
        has_video = vcodec is not None and vcodec != 'none'
        has_audio = acodec is not None and acodec != 'none'
        is_video_only = has_video and not has_audio
        is_audio_only = has_audio and not has_video
        is_merged = has_video and has_audio

        type_match_passed = False
        if base_selector.startswith('bv'):
            if is_video_only: type_match_passed = True
        elif base_selector.startswith('ba'):
            if is_audio_only: type_match_passed = True
        elif base_selector == 'b' or base_selector == 'best':
             if is_video_only or is_audio_only or is_merged: type_match_passed = True
        elif base_selector not in ['bv', 'ba', 'b', 'best']: # Corrected else if
             type_match_passed = True # Assume specific ID

        if type_match_passed: type_matched_formats.append(fmt)

    debug_print(f"  Step 1 Result: {len(type_matched_formats)} formats passed TYPE filter.")
    if not type_matched_formats: return None # Exit B1

    # --- Step 2: Filter by explicit FILTERS ---
    filtered_formats = []
    debug_print(f"  Step 2: Applying explicit filters {filters} to {len(type_matched_formats)} candidates...")
    if filters:
        for fmt in type_matched_formats:
            if format_matches_filters(fmt, filters): # <<< Use corrected function
                filtered_formats.append(fmt)
        debug_print(f"  Step 2 Result: {len(filtered_formats)} formats passed explicit filters.")
    else:
        debug_print("  Step 2 Result: No explicit filters to apply.")
        filtered_formats = type_matched_formats

    if not filtered_formats: return None # Exit B2

    # --- Step 3: Sorting ---
    debug_print(f"  Step 3: Sorting {len(filtered_formats)} final candidates...")
    def sort_key(fmt):
        # <<< get_format_size now includes bitrate fallback >>>
        size = get_format_size(fmt)
        has_valid_size = 1 if size > 0 else 0
        height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
        vbr = fmt.get('vbr') if isinstance(fmt.get('vbr'), (int, float)) else 0
        tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
        video_rate = vbr if vbr > 0 else tbr
        abr = fmt.get('abr') if isinstance(fmt.get('abr'), (int, float)) else 0
        ext = fmt.get('ext', '')
        # Slightly prefer mp4/m4a, then webm/opus, then others
        ext_pref = 2 if ext in ['mp4', 'm4a'] else (1 if ext in ['webm', 'opus'] else 0)
        # Sort Tuple: Prioritize size validity, then resolution, rates, ext, size
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
        if filtered_formats: return filtered_formats[0] # Fallback C
        else: return None # Fallback D

    # --- Step 4: Selection ---
    if not sorted_formats: return None # Exit E
    selected_format = sorted_formats[0]
    if selected_format and isinstance(selected_format, dict):
        debug_print(f"  Selected Best: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
        return selected_format # Success Exit
    else: return None # Exit F
# <<< select_best_filtered_format 函數定義結束 >>>

# --- Main Execution Function ---
def main():
    """Main function to parse args, get formats, simulate selection, and print size."""
    debug_print(f"--- estimate_size.py {SCRIPT_VERSION} Starting ---")
    # --- Argument Parsing ---
    # (保持不變)
    parser = argparse.ArgumentParser(description="Estimate media size...",epilog="Example: ...")
    parser.add_argument("url", nargs='?', default=None)
    parser.add_argument("format_selector", nargs='?', default=None)
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}")
    try: args = parser.parse_args(); debug_print(f"Args: URL='{args.url}', Format='{args.format_selector}'")
    except SystemExit as e: sys.exit(e.code)
    except Exception as e: error_print(f"Arg parse error: {e}"); print("0"); sys.exit(1)
    if not args.url or not args.format_selector: error_print("URL and Format selector required."); print("0"); sys.exit(1)

    # --- Get ALL available formats ---
    # (保持不變，增加簡單重試？暫不加)
    debug_print("\nStep 1: Getting formats via yt-dlp --dump-json...")
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd or not os.path.exists(yt_dlp_cmd): error_print("yt-dlp not found."); print("0"); sys.exit(1)
    command = [yt_dlp_cmd, "--no-warnings", "--dump-json", args.url]
    available_formats = []
    try:
        debug_print(f"Running: {' '.join(command)}")
        process = subprocess.run(command, capture_output=True, text=True, encoding='utf-8', check=False, timeout=60)
        debug_print(f"yt-dlp exited with code {process.returncode}")
        if process.returncode != 0 or not process.stdout.strip(): raise ValueError(f"yt-dlp failed or empty output.\nstderr:\n{process.stderr}")
        media_info = json.loads(process.stdout)
        if isinstance(media_info, list): media_info = media_info[0] # Take first if list
        if not isinstance(media_info, dict): raise TypeError("Parsed JSON not a dict.")
        available_formats = media_info.get('formats')
        if not available_formats or not isinstance(available_formats, list):
             if media_info.get('format_id'): available_formats = [media_info]
             else: raise ValueError("No 'formats' list found.")
        debug_print(f"Retrieved {len(available_formats)} formats.")
    except Exception as e: error_print(f"Error getting/parsing formats: {e}"); traceback.print_exc(file=sys.stderr); print("0"); sys.exit(1)
    if not available_formats: warning_print("Format list empty."); print("0"); sys.exit(0)

    # --- Simulate Format Selection Loop ---
    debug_print(f"\nStep 2: Simulating selection for: '{args.format_selector}'")
    final_estimated_size = 0
    selection_groups = args.format_selector.split('/')
    group_found = False
    for i, group in enumerate(selection_groups):
        debug_print(f"\n--- Processing Group {i+1}: '{group}' ---")
        group_estimated_size = 0
        all_parts_found = True
        individual_selectors = group.split('+')
        selected_ids_in_group = set()
        for j, selector in enumerate(individual_selectors):
            debug_print(f"  --- Processing Part {j+1}: '{selector}' ---")
            best_match = select_best_filtered_format(available_formats, selector) # Call refactored function
            if best_match:
                format_id = best_match.get('format_id')
                if format_id not in selected_ids_in_group:
                    part_size = get_format_size(best_match) # <<< Uses enhanced get_format_size
                    debug_print(f"    Part {j+1} Match: ID={format_id}, Size={part_size}")
                    group_estimated_size += part_size
                    selected_ids_in_group.add(format_id)
                    if part_size == 0: warning_print(f"    Part {j+1} Match (ID={format_id}) has size 0 or could not be estimated.")
                else: debug_print(f"    Part {j+1}: Format ID {format_id} already added.")
            else:
                debug_print(f"    >>>>> Part {j+1} ('{selector}') FAILED to find match. <<<<<")
                all_parts_found = False; break
        if all_parts_found:
            debug_print(f"--- SUCCESS: Group {i+1} ('{group}') successful. Estimated Size: {group_estimated_size} ---")
            final_estimated_size = group_estimated_size; group_found = True; break
        else: debug_print(f"--- FAILED: Group {i+1} ('{group}'). Trying next fallback. ---")
    if not group_found: warning_print("Could not satisfy any selection group completely.")

    # --- Output Final Result ---
    debug_print(f"\n--- Final Estimated Size Calculation ---")
    debug_print(f"Total Estimated Size (bytes): {final_estimated_size}")
    print(final_estimated_size) # Output only the final number
    sys.exit(0)

# --- Script Entry Point ---
if __name__ == "__main__":
    try: main()
    except Exception as e: error_print(f"Unexpected error in main: {e}"); traceback.print_exc(file=sys.stderr); print("0"); sys.exit(1)
