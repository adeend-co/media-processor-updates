#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py (with extensive debugging)

import sys
import subprocess
import json
import argparse
import shutil
import re
import os # For checking file existence

# --- 全局變數 ---
SCRIPT_VERSION = "v1.1.6(Experimental-Debug)"
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
    if not isinstance(format_info, dict): return 0
    filesize = format_info.get('filesize')
    filesize_approx = format_info.get('filesize_approx')
    format_id = format_info.get('format_id', 'N/A')

    if isinstance(filesize, (int, float)) and filesize > 0:
        # debug_print(f"  get_format_size: Using filesize {filesize} for format {format_id}")
        return int(filesize)
    elif isinstance(filesize_approx, (int, float)) and filesize_approx > 0:
        # debug_print(f"  get_format_size: Using filesize_approx {filesize_approx} for format {format_id}")
        return int(filesize_approx)
    else:
        # debug_print(f"  get_format_size: No valid size found for format {format_id}")
        return 0

# --- Helper Function to Parse yt-dlp format filter string ---
def parse_filter(filter_str):
    filters = {}
    pattern = r"\[([a-zA-Z_]+)\s*(<=|>=)?\s*([a-zA-Z0-9_.-]+)\]"
    matches = re.findall(pattern, filter_str)
    # debug_print(f"  parse_filter: Input='{filter_str}', Matches={matches}")

    for key, op, value in matches:
        op = op if op else '=='
        val_processed = value
        if op in ['<=', '>=']:
            try:
                val_processed = int(value)
            except ValueError:
                warning_print(f"  parse_filter: Cannot convert '{value}' to int for comparison '{op}' on key '{key}'. Skipping filter.")
                continue
        filters[key] = (op, val_processed)
    # debug_print(f"  parse_filter: Parsed filters={filters}")
    return filters

# --- Helper Function to Check if a format matches filters ---
def format_matches_filters(format_info, filters):
    if not isinstance(format_info, dict): return False
    format_id = format_info.get('format_id', 'N/A')
    # debug_print(f"    format_matches_filters: Checking format {format_id} against {filters}")

    for key, (op, expected_value) in filters.items():
        actual_value = format_info.get(key)
        # debug_print(f"      Filter Key='{key}', Op='{op}', Expected='{expected_value}', Actual='{actual_value}'")
        if actual_value is None:
            # debug_print(f"      Filter Fail: Key '{key}' not found in format {format_id}")
            return False

        try:
            if op == '==':
                if str(actual_value).lower() != str(expected_value).lower():
                    # debug_print(f"      Filter Fail: Equality mismatch ('{str(actual_value).lower()}' != '{str(expected_value).lower()}')")
                    return False
            elif op == '<=':
                # Ensure actual value is numeric before comparison
                if isinstance(actual_value, (int, float)):
                    if not (actual_value <= expected_value):
                        # debug_print(f"      Filter Fail: Less than or equal failed ({actual_value} not <= {expected_value})")
                        return False
                else:
                    # debug_print(f"      Filter Fail: Cannot perform '<=' on non-numeric actual value '{actual_value}'")
                    return False # Cannot compare non-numeric with <=
            elif op == '>=':
                 if isinstance(actual_value, (int, float)):
                     if not (actual_value >= expected_value):
                         # debug_print(f"      Filter Fail: Greater than or equal failed ({actual_value} not >= {expected_value})")
                         return False
                 else:
                     # debug_print(f"      Filter Fail: Cannot perform '>=' on non-numeric actual value '{actual_value}'")
                     return False
            # Add other operators if needed
        except Exception as e:
             warning_print(f"    format_matches_filters: Comparison error for key '{key}' (op '{op}') between '{actual_value}' and '{expected_value}': {e}")
             return False # Treat comparison errors as filter failure
    # debug_print(f"    format_matches_filters: Format {format_id} PASSED all filters.")
    return True


# --- Helper Function to Select Best Format based on Filters and Preference (More Robust Version) ---
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
        # debug_print(f"    Checking format {index+1}/{len(available_formats)}: ID={format_id}")
        is_video = fmt.get('vcodec') != 'none' and fmt.get('vcodec') is not None
        is_audio = fmt.get('acodec') != 'none' and fmt.get('acodec') is not None

        # --- Type Matching ---
        type_match = False
        if base_selector.startswith('bv'):
            # bestvideo: must have video, must NOT have audio
            if is_video and not is_audio:
                type_match = True
        elif base_selector.startswith('ba'):
            # bestaudio: must have audio, must NOT have video
            if is_audio and not is_video:
                type_match = True
        elif base_selector == 'b':
             # best: can have video, audio, or both (but not none)
             if is_video or is_audio:
                 type_match = True
        elif base_selector == 'best':
             # 'best' often implies video+audio combined if available,
             # or the best single stream otherwise.
             # For filtering, let's treat it like 'b' - accept anything with video or audio.
             # Sorting logic will handle preferring higher quality.
             if is_video or is_audio:
                 type_match = True
        else:
             # Could be a specific format ID or other selector yt-dlp understands.
             # We'll assume it matches for now and rely on filters.
             # A more robust solution would try to match specific IDs here.
             type_match = True # Keep this permissive for unknown selectors for now
        # --- <<< 類型匹配修改結束 >>> ---

        if type_match:
            if format_matches_filters(fmt, filters):
                matching_formats.append(fmt)

    # ... (函數後面的程式碼不變) ...
    debug_print(f"  Filtering complete. Found {len(matching_formats)} matching formats.")

    if not matching_formats:
        debug_print(f"  select_best_filtered_format: (Exit B) No formats passed filtering for '{selector}'. Returning None.")
        return None

    # --- Sorting ---
    debug_print(f"  Attempting to sort {len(matching_formats)} matching formats (prioritizing valid size)...")

    # Define sort_key function (same as before)
    def sort_key(fmt):
        size = get_format_size(fmt)
        has_valid_size = 1 if size > 0 else 0
        height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
        vbr = fmt.get('vbr') if isinstance(fmt.get('vbr'), (int, float)) else 0
        tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
        video_rate = vbr if vbr > 0 else tbr
        abr = fmt.get('abr') if isinstance(fmt.get('abr'), (int, float)) else 0
        # Return tuple for sorting
        return (has_valid_size, height, video_rate, abr, size)

    # Use a separate variable for the sorted list to avoid modifying original in case of error
    sorted_matching_formats = []
    try:
        # Create a copy before sorting if needed, though sort is in-place
        # We'll sort directly and handle exceptions
        sorted_matching_formats = sorted(matching_formats, key=sort_key, reverse=True) # Use sorted() for new list
        # matching_formats.sort(key=sort_key, reverse=True) # In-place sort
        debug_print(f"  Sorting successful. Top 5 results (or fewer):")
        for i, fmt in enumerate(sorted_matching_formats[:5]): # Print top 5 for inspection
             debug_print(f"    {i+1}: ID={fmt.get('format_id')}, HasSize={1 if get_format_size(fmt)>0 else 0}, H={fmt.get('height')}, VR={fmt.get('vbr') or fmt.get('tbr')}, AR={fmt.get('abr')}, Size={get_format_size(fmt)}")

    except Exception as e:
        error_print(f"  >>> EXCEPTION DURING SORTING: {e} <<<")
        import traceback
        traceback.print_exc(file=sys.stderr)
        error_print(f"  >>> END OF EXCEPTION TRACEBACK <<<")
        warning_print("  Fallback: Sorting failed. Attempting to use first unsorted match.")
        # If sorting failed, use the original unsorted list
        if matching_formats: # Check if original list exists
             selected_format = matching_formats[0]
             warning_print(f"  Fallback: Using unsorted first match: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
             debug_print(f"  select_best_filtered_format: (Exit C - Fallback due to sort exception). Returning unsorted first match.")
             return selected_format
        else:
             error_print("  Fallback failed: Original matching_formats list is missing or empty in exception handler!")
             debug_print(f"  select_best_filtered_format: (Exit D - Fallback failed in exception). Returning None.")
             return None

    # --- Selection after successful sort ---
    # Check if the sorted list is non-empty (it should be if no exception occurred)
    if not sorted_matching_formats:
        error_print("  >>> ERROR: sorted_matching_formats is unexpectedly empty after successful sort call! <<<")
        debug_print(f"  select_best_filtered_format: (Exit E - List empty after sort). Returning None.")
        return None

    # Select the best format (the first one after sorting)
    selected_format = sorted_matching_formats[0]

    # Final check if selected_format is valid
    if selected_format and isinstance(selected_format, dict):
        debug_print(f"  Selected Best after sort: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
        debug_print(f"===== select_best_filtered_format for '{selector}' finished successfully. Returning format. =====")
        return selected_format
    else:
        error_print(f"  >>> ERROR: selected_format (sorted_matching_formats[0]) is invalid after sorting! Value: {selected_format} <<<")
        debug_print(f"  select_best_filtered_format: (Exit F - Invalid selected format). Returning None.")
        return None

# <<< 函數定義結束 >>>

    # In select_best_filtered_format function:
def sort_key(fmt):
    # <<< 新增：優先級基於是否有有效大小 >>>
    size = get_format_size(fmt)
    has_valid_size = 1 if size > 0 else 0 # 1 if size > 0, 0 otherwise

    # 後續排序條件
    height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
    vbr = fmt.get('vbr') if isinstance(fmt.get('vbr'), (int, float)) else 0
    tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
    video_rate = vbr if vbr > 0 else tbr
    abr = fmt.get('abr') if isinstance(fmt.get('abr'), (int, float)) else 0

    # 返回一個元組，優先級從左到右
    # 將 has_valid_size 放在最前面，確保有大小的排在前面
    return (has_valid_size, height, video_rate, abr, size)

        # <<< 在 sort_key 函數定義之後 >>>

    try:
        # 排序 (在 try 塊內部)
        debug_print(f"    Attempting to sort {len(matching_formats)} formats...") # 添加排序前計數
        matching_formats.sort(key=sort_key, reverse=True)
        debug_print(f"    Sorting complete.")

        # 檢查排序後列表是否為空 (理論上不應該，除非 sort_key 有問題)
        if not matching_formats:
             error_print("    >>> ERROR: matching_formats became empty after sorting! <<<")
             return None

        # <<< 這三行應該放在 try 塊內部，緊接在 sort 和 debug_print 之後 >>>
        selected_format = matching_formats[0]
        debug_print(f"    Selected Best after sort: ID={selected_format.get('format_id', 'N/A')}, Size={get_format_size(selected_format)}")
        return selected_format
        # --- try 塊結束 ---

    # <<< except 與 try 對齊 >>>
    except Exception as e:
        # --- except 塊開始 (與 try 對齊) ---
        # <<< 加強除錯輸出 >>>
        error_print(f"    >>> EXCEPTION DURING SORTING OR SELECTION: {e} <<<")
        # 打印出異常的詳細追蹤信息
        import traceback
        traceback.print_exc(file=sys.stderr)
        error_print(f"    >>> END OF EXCEPTION TRACEBACK <<<")

        # Fallback: 嘗試返回第一個未排序的匹配項
        # 注意：這裡的 matching_formats 仍然是排序前的列表（如果 sort 出錯）或排序後的列表（如果 selection 出錯）
        # 我們需要確保它仍然有效且非空
        warning_print("    Fallback: Attempting to return first match found *before* sorting attempt...")

        # 為了安全，我們應該在 try 之前複製一份列表，或者在這裡重新獲取？
        # 為簡單起見，假設 matching_formats 在異常發生時仍然包含原始數據
        # 但更健壯的做法是在 try 前備份: original_matches = matching_formats[:]

        # 檢查列表是否真的存在且非空
        if 'matching_formats' in locals() and matching_formats: # 檢查變數是否存在且非空
             fallback_format = matching_formats[0]
             warning_print(f"    Fallback: Returning unsorted first match: ID={fallback_format.get('format_id', 'N/A')}, Size={get_format_size(fallback_format)}")
             return fallback_format
        else:
             error_print("    Fallback: matching_formats list is missing or empty in exception handler!")
             return None
        # --- except 塊結束 ---

# <<< 函數定義結束 >>>


# --- Main Execution ---
def main():
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
        # Handle argparse exit (e.g., for --version or --help)
        # We don't need to print 0 here as argparse handles the exit.
         debug_print(f"Argparse exited with code {e.code}")
         sys.exit(e.code) # Propagate exit code
    except Exception as e:
        error_print(f"Error parsing arguments: {e}")
        print("0") # Output 0 on argument parse error
        sys.exit(1)


    if args.url is None or args.format_selector is None:
        # This check might be redundant due to argparse handling, but good as safety net
        if len(sys.argv) <= 1: parser.print_help(sys.stderr); sys.exit(1)
        elif args.url is None: error_print("Media URL is required."); print("0"); sys.exit(1)
        elif args.format_selector is None: error_print("Format selector is required."); print("0"); sys.exit(1)
        else: sys.exit(1)

    # --- Get ALL available formats ---
    debug_print("Step 1: Getting all available formats using yt-dlp --dump-json...")
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd:
        error_print("yt-dlp command not found in PATH."); print("0"); sys.exit(1)
    if not os.path.exists(yt_dlp_cmd):
         error_print(f"yt-dlp path found ('{yt_dlp_cmd}') but file does not exist."); print("0"); sys.exit(1)


    command_list_formats = [yt_dlp_cmd, "--no-warnings", "--dump-json", args.url]
    available_formats = []
    try:
        debug_print(f"Running command: {' '.join(command_list_formats)}")
        process = subprocess.run(command_list_formats, capture_output=True, text=True, encoding='utf-8', check=False, timeout=60) # Added timeout
        debug_print(f"yt-dlp (dump-json) exited with code {process.returncode}")

        if process.returncode != 0:
            error_print(f"yt-dlp (dump-json) failed.")
            error_print(f"stderr:\n{process.stderr}")
            print("0"); sys.exit(0) # Exit 0 for Bash, error logged

        if not process.stdout.strip():
             error_print(f"yt-dlp (dump-json) produced empty stdout.")
             print("0"); sys.exit(0)

        media_info = json.loads(process.stdout)
        if isinstance(media_info, list): media_info = media_info[0]
        if not isinstance(media_info, dict): error_print("Parsed JSON is not a dict."); print("0"); sys.exit(0)

        available_formats = media_info.get('formats')
        if not available_formats or not isinstance(available_formats, list):
             if media_info.get('format_id'):
                 available_formats = [media_info]
                 debug_print("Treating top-level JSON as single format.")
             else:
                 warning_print("No 'formats' list found in JSON. Cannot estimate size."); print("0"); sys.exit(0)

        debug_print(f"Successfully retrieved {len(available_formats)} available formats.")
        # Optionally print all formats here for deep debugging
        # print("--- Available Formats ---", file=sys.stderr)
        # for fmt in available_formats:
        #     print(json.dumps(fmt, indent=2), file=sys.stderr)
        # print("--- End Available Formats ---", file=sys.stderr)


    except subprocess.TimeoutExpired:
        error_print(f"yt-dlp (dump-json) timed out after 60 seconds."); print("0"); sys.exit(0)
    except json.JSONDecodeError as e:
        error_print(f"Failed to decode JSON from yt-dlp: {e}"); print("0"); sys.exit(0)
    except FileNotFoundError:
        error_print(f"Failed to execute yt-dlp command '{yt_dlp_cmd}'."); print("0"); sys.exit(1)
    except Exception as e:
        error_print(f"Error getting available formats: {e}"); print("0"); sys.exit(1)

    if not available_formats: # Double check if formats list ended up empty
        warning_print("Available formats list is empty after processing. Cannot estimate.")
        print("0")
        sys.exit(0)

    # --- Simulate Format Selection ---
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

        selected_formats_in_group_ids = set() # Use a set for efficient check

        for j, selector in enumerate(individual_selectors):
            debug_print(f"  --- Processing Part {j+1}: '{selector}' ---")
            best_match = select_best_filtered_format(available_formats, selector)

            if best_match:
                format_id = best_match.get('format_id')
                # Check if this specific format ID has already been added in this group
                if format_id not in selected_formats_in_group_ids:
                    part_size = get_format_size(best_match)
                    debug_print(f"    Match found: ID={format_id}, Size={part_size}")
                    if part_size > 0: # Only add if size is valid
                        group_estimated_size += part_size
                        selected_formats_in_group_ids.add(format_id)
                        debug_print(f"    Added size {part_size}. Current group total: {group_estimated_size}")
                    else:
                        # Found a match but it has no size info - treat as failure for this part?
                        # Or allow it but size contribution is 0? Let's be strict for now.
                        # If a format part MUST have size, uncomment the next lines:
                        # warning_print(f"    Match found (ID={format_id}) but has zero size. Treating as failure for this part.")
                        # all_parts_found = False
                        # break
                        # If zero size is acceptable (won't contribute to total):
                        warning_print(f"    Match found (ID={format_id}) but has zero size. Not adding to total.")
                        selected_formats_in_group_ids.add(format_id) # Still mark as found
                else:
                    debug_print(f"    Format ID {format_id} already included in this group. Skipping size addition.")
            else:
                debug_print(f"    >>>>> No suitable format found for selector part '{selector}' <<<<<")
                all_parts_found = False
                break # If any part is not found, this group fails

        if all_parts_found:
            debug_print(f"--- SUCCESS: All parts found for Group {i+1} ('{group}') ---")
            final_estimated_size = group_estimated_size
            group_found = True
            break # Found a working group, stop processing fallbacks
        else:
            debug_print(f"--- FAILED: Could not find all parts for Group {i+1} ('{group}'). Trying next fallback (if any). ---")

    if not group_found:
         warning_print("Could not satisfy any selection group completely.")

    # --- Output the final calculated size ---
    debug_print(f"\n--- Final Estimated Size Calculation ---")
    debug_print(f"Total Estimated Size (bytes): {final_estimated_size}")
    print(final_estimated_size) # Output ONLY the final number to stdout
    sys.exit(0)


if __name__ == "__main__":
    main()
