#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py (Complete Version Integrating AI Suggestions)

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
SCRIPT_VERSION = "v1.2.1(AI-Integrated-Debug)" # Keeping version from AI integration
DEBUG_ENABLED = True # Keep debugging enabled

# --- Logging Helpers ---
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

# --- Helper Function to Parse Filters (AI Corrected Regex) ---
def parse_filter(filter_str):
    """Parses simple filters like [height<=1080][ext=mp4]. Corrected Regex."""
    filters = {}
    # <<< AI 建議的修正正則：增加 = 捕獲 >>>
    pattern = r"\[([a-zA-Z_]+)\s*(<=|>=|=)?\s*([a-zA-Z0-9_.-]+)\]"
    matches = re.findall(pattern, filter_str)
    # debug_print(f"    parse_filter: Input='{filter_str}', Matches={matches}") # Optional debug
    for key, op, value in matches:
        op = op if op else '==' # Default to == if no operator
        if op == '=': op = '=='  # Ensure single '=' becomes '=='
        val_processed = value
        # Only convert to int for numeric comparisons, exclude 'ext' etc.
        if op in ['<=', '>='] and key not in ['ext', 'format_id', 'acodec', 'vcodec', 'protocol']:
            try: val_processed = int(value)
            except ValueError:
                 warning_print(f"    parse_filter: Cannot convert '{value}' to int for key '{key}'. Skipping filter.")
                 continue
        filters[key] = (op, val_processed)
    # debug_print(f"    parse_filter: Parsed filters={filters}") # Optional debug
    return filters

# --- Helper Function to Match Filters (AI Suggestion: Prioritize ext) ---
def format_matches_filters(format_info, filters):
    """Checks if a format dict matches filters, prioritizing 'ext'."""
    if not isinstance(format_info, dict): return False
    format_id = format_info.get('format_id', 'N/A')

    # <<< AI 建議：優先處理 ext 過濾器 >>>
    if 'ext' in filters:
        op_ext, expected_ext = filters['ext']
        actual_ext = format_info.get('ext', '')
        # debug_print(f"        Checking ext: Op='{op_ext}', Expected='{expected_ext}', Actual='{actual_ext}'")
        if op_ext == '==' and str(actual_ext).lower() != str(expected_ext).lower():
            # debug_print(f"        >>> ext filter FAILED for {format_id}")
            return False # Immediately fail if ext doesn't match
        # else:
            # debug_print(f"        ext filter PASSED for {format_id}")

    # --- 檢查其他過濾器 ---
    for key, (op, expected_value) in filters.items():
        if key == 'ext': continue # Skip ext, already checked

        actual_value = format_info.get(key)
        # debug_print(f"        Checking filter: Key='{key}', Op='{op}', Expected='{expected_value}', Actual='{actual_value}'")
        if actual_value is None:
            # debug_print(f"        >>> Filter FAILED (Key '{key}' missing) for {format_id}")
            return False

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

# --- select_best_filtered_format (Using Corrected Helpers and Type Match) ---
def select_best_filtered_format(available_formats, selector):
    """Selects the best format based on type, filters, and sorting preference."""
    debug_print(f"\n===== Running select_best_filtered_format for selector: '{selector}' =====")
    if not available_formats or not selector:
        warning_print("  select_best_filtered_format: (Exit A) No available formats or selector. Returning None.")
        return None

    base_selector = selector.split('[', 1)[0]
    filter_str = '[' + selector.split('[', 1)[1] if '[' in selector else ''
    filters = parse_filter(filter_str) # <<< Use corrected parse_filter
    debug_print(f"  Base selector='{base_selector}', Parsed filters={filters}")

    matching_formats = []
    debug_print(f"  Filtering {len(available_formats)} formats...")
    for fmt in available_formats:
        format_id = fmt.get('format_id', 'N/A')
        vcodec = fmt.get('vcodec')
        acodec = fmt.get('acodec')
        has_video = vcodec is not None and vcodec != 'none'
        has_audio = acodec is not None and acodec != 'none'
        is_video_only = has_video and not has_audio
        is_audio_only = has_audio and not has_video
        is_merged = has_video and has_audio

        # --- Corrected Type Matching Logic ---
        type_match_passed = False
        if base_selector.startswith('bv'):
            if is_video_only: type_match_passed = True
        elif base_selector.startswith('ba'):
            if is_audio_only: type_match_passed = True
        elif base_selector == 'b' or base_selector == 'best':
             if is_video_only or is_audio_only or is_merged: type_match_passed = True
        elif base_selector not in ['bv', 'ba', 'b', 'best']: # Corrected else if
             type_match_passed = True # Assume specific ID

        filters_passed = format_matches_filters(fmt, filters) # <<< Use corrected format_matches_filters

        # Debug print decision process
        # debug_print(f"    Format {format_id}: V={has_video}, A={has_audio} -> V_Only={is_video_only}, A_Only={is_audio_only}, Merged={is_merged}")
        # debug_print(f"      Selector='{base_selector}', TypeMatchPassed={type_match_passed}, Filters={filters}, FiltersPassed={filters_passed}")

        if type_match_passed and filters_passed:
            # debug_print(f"      >>> Format {format_id} ADDED.")
            matching_formats.append(fmt)

    debug_print(f"  Filtering complete. Found {len(matching_formats)} matching formats.")
    if not matching_formats:
        debug_print(f"  select_best_filtered_format: (Exit B) No formats passed filtering for '{selector}'. Returning None.")
        return None

    # --- Sorting ---
    debug_print(f"  Attempting to sort {len(matching_formats)} matching formats (prioritizing valid size)...")
    def sort_key(fmt):
        size = get_format_size(fmt)
        has_valid_size = 1 if size > 0 else 0
        height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
        vbr = fmt.get('vbr') if isinstance(fmt.get('vbr'), (int, float)) else 0
        tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
        video_rate = vbr if vbr > 0 else tbr
        abr = fmt.get('abr') if isinstance(fmt.get('abr'), (int, float)) else 0
        ext = fmt.get('ext', '')
        ext_pref = 1 if ext == 'mp4' else (0 if ext == 'webm' else -1) # Prefer mp4 > webm > others
        # Sort Tuple
        return (has_valid_size, height, video_rate, abr, ext_pref, size)

    sorted_formats = []
    try:
        sorted_formats = sorted(matching_formats, key=sort_key, reverse=True)
        debug_print(f"  Sorting successful. Top 5 results:")
        for i, fmt in enumerate(sorted_formats[:5]):
             debug_print(f"    {i+1}: ID={fmt.get('format_id')}, HasSize={1 if get_format_size(fmt)>0 else 0}, H={fmt.get('height')}, VR={fmt.get('vbr') or fmt.get('tbr')}, AR={fmt.get('abr')}, Ext={fmt.get('ext')}, Size={get_format_size(fmt)}")
    except Exception as e:
        error_print(f"  >>> EXCEPTION DURING SORTING: {e} <<<")
        traceback.print_exc(file=sys.stderr)
        # Fallback logic...
        if matching_formats: return matching_formats[0]
        else: return None
    if not sorted_formats: return None
    selected_format = sorted_formats[0]
    if selected_format and isinstance(selected_format, dict):
        debug_print(f"  Selected Best: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
        return selected_format
    else: return None
# <<< select_best_filtered_format 函數定義結束 >>>

# --- Main Execution Function ---
def main():
    """Main function to parse args, get formats, simulate selection, and print size."""
    debug_print(f"--- estimate_size.py {SCRIPT_VERSION} Starting ---")
    # --- Argument Parsing ---
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
    except SystemExit as e: sys.exit(e.code) # Allow --version to exit cleanly
    except Exception as e: error_print(f"Error parsing arguments: {e}"); print("0"); sys.exit(1)
    # Check if required arguments are provided (if not exiting from --version)
    if args.url is None or args.format_selector is None:
        if len(sys.argv) > 1: # Avoid printing help if called with no args
            if args.url is None: error_print("Media URL is required."); print("0"); sys.exit(1)
            if args.format_selector is None: error_print("Format selector is required."); print("0"); sys.exit(1)
        else:
            parser.print_help(sys.stderr); sys.exit(1)

    # --- Get ALL available formats ---
    debug_print("\nStep 1: Getting all available formats using yt-dlp --dump-json...")
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd or not os.path.exists(yt_dlp_cmd):
        error_print(f"yt-dlp command not found or path invalid ('{yt_dlp_cmd}')."); print("0"); sys.exit(1)

    command_list_formats = [yt_dlp_cmd, "--no-warnings", "--dump-json", args.url]
    available_formats = []
    try:
        debug_print(f"Running command: {' '.join(command_list_formats)}")
        process = subprocess.run(command_list_formats, capture_output=True, text=True, encoding='utf-8', check=False, timeout=60)
        debug_print(f"yt-dlp (dump-json) exited with code {process.returncode}")
        if process.returncode != 0: error_print(f"yt-dlp failed.\nstderr:\n{process.stderr}"); print("0"); sys.exit(0)
        if not process.stdout.strip(): error_print("yt-dlp empty stdout."); print("0"); sys.exit(0)
        media_info = json.loads(process.stdout)
        # Handle potential playlist dump (take first video's info)
        if isinstance(media_info, dict) and 'entries' in media_info and isinstance(media_info['entries'], list) and media_info['entries']:
             warning_print("Input seems to be a playlist, using info from the first entry.")
             media_info = media_info['entries'][0]
        elif isinstance(media_info, list) and media_info: # Handle case where output is just a list of video infos
             warning_print("yt-dlp output is a list, using the first item.")
             media_info = media_info[0]

        if not isinstance(media_info, dict): error_print("Parsed JSON is not a dict."); print("0"); sys.exit(0)
        available_formats = media_info.get('formats')
        if not available_formats or not isinstance(available_formats, list):
             if media_info.get('format_id'): available_formats = [media_info]; debug_print("Using top-level JSON as single format.")
             else: warning_print("No 'formats' list found."); print("0"); sys.exit(0)
        debug_print(f"Successfully retrieved {len(available_formats)} formats.")
    except subprocess.TimeoutExpired: error_print("yt-dlp timed out."); print("0"); sys.exit(0)
    except json.JSONDecodeError as e: error_print(f"JSON decode error: {e}"); print("0"); sys.exit(0)
    except Exception as e: error_print(f"Error getting formats: {e}"); traceback.print_exc(file=sys.stderr); print("0"); sys.exit(1)
    if not available_formats: warning_print("Available formats list empty."); print("0"); sys.exit(0)

    # --- Simulate Format Selection Loop ---
    debug_print(f"\nStep 2: Simulating format selection for: '{args.format_selector}'")
    final_estimated_size = 0
    selection_groups = args.format_selector.split('/')
    group_found = False
    for i, group in enumerate(selection_groups):
        debug_print(f"\n--- Processing Selection Group {i+1}: '{group}' ---")
        group_estimated_size = 0
        all_parts_found = True
        individual_selectors = group.split('+')
        selected_formats_in_group_ids = set()
        for j, selector in enumerate(individual_selectors):
            debug_print(f"  --- Processing Part {j+1}: '{selector}' ---")
            best_match = select_best_filtered_format(available_formats, selector) # Call the corrected function
            if best_match:
                format_id = best_match.get('format_id')
                if format_id not in selected_formats_in_group_ids:
                    part_size = get_format_size(best_match)
                    debug_print(f"    Part {j+1} Match: ID={format_id}, Size={part_size}")
                    if part_size >= 0: # Include 0 size formats if they are selected
                        group_estimated_size += part_size
                        selected_formats_in_group_ids.add(format_id)
                        if part_size == 0: warning_print(f"    Part {j+1} Match (ID={format_id}) has reported size 0.")
                    # Removed strict failure for size 0, as some valid streams might report 0 initially
                else: debug_print(f"    Part {j+1}: Format ID {format_id} already added.")
            else:
                debug_print(f"    >>>>> Part {j+1} ('{selector}') FAILED to find match. <<<<<")
                all_parts_found = False; break
        if all_parts_found:
            debug_print(f"--- SUCCESS: Group {i+1} ('{group}') successful. Estimated Size: {group_estimated_size} ---")
            final_estimated_size = group_estimated_size; group_found = True; break
        else: debug_print(f"--- FAILED: Group {i+1} ('{group}'). Trying next fallback. ---")
    if not group_found: warning_print("Could not satisfy any selection group.")

    # --- Output Final Result ---
    debug_print(f"\n--- Final Estimated Size Calculation ---")
    debug_print(f"Total Estimated Size (bytes): {final_estimated_size}")
    print(final_estimated_size)
    sys.exit(0)

# --- Script Entry Point ---
if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        error_print(f"An unexpected error occurred in main: {e}")
        traceback.print_exc(file=sys.stderr)
        print("0")
        sys.exit(1)
