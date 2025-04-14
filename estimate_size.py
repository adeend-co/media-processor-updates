#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py
# Version: 1.1.0(Experimental) # <<< 增加版本號

import sys
import subprocess
import json
import argparse
import shutil
import re # For parsing format selectors

# --- 全局變數 ---
SCRIPT_VERSION = "v1.1.0(Experimental)"

# --- Helper Function to Get Size ---
def get_format_size(format_info):
    """
    Gets the size of a format, prioritizing 'filesize' over 'filesize_approx'.
    Returns size in bytes or 0 if neither is available or valid.
    """
    if not isinstance(format_info, dict): return 0 # Safety check

    filesize = format_info.get('filesize')
    filesize_approx = format_info.get('filesize_approx')

    # Check for valid integer/float and positive value
    if isinstance(filesize, (int, float)) and filesize > 0:
        return int(filesize)
    elif isinstance(filesize_approx, (int, float)) and filesize_approx > 0:
        return int(filesize_approx)
    else:
        return 0

# --- Helper Function to Parse yt-dlp format filter string ---
def parse_filter(filter_str):
    """
    Parses a simple yt-dlp filter string like "[height<=1080][ext=mp4]".
    Returns a dictionary of filters, e.g., {'height': ('<=', 1080), 'ext': ('==', 'mp4')}.
    Supports <=, >=, == (implicit for ext).
    """
    filters = {}
    # Regex to find filters like [key=value], [key<=value], [key>=value]
    # Handles integers for comparisons, strings for equality
    pattern = r"\[([a-zA-Z_]+)\s*(<=|>=)?\s*([a-zA-Z0-9_.-]+)\]"
    matches = re.findall(pattern, filter_str)

    for key, op, value in matches:
        op = op if op else '==' # Default operator is equality
        # Try converting value to int for comparison operators
        val_processed = value
        if op in ['<=', '>=']:
            try:
                val_processed = int(value)
            except ValueError:
                # If conversion fails for comparison, skip this filter? Or treat as string?
                # For simplicity, we'll skip if int conversion fails for <=/>=
                # print(f"Warning: Cannot convert '{value}' to int for comparison '{op}' on key '{key}'. Skipping filter.", file=sys.stderr)
                continue
        filters[key] = (op, val_processed)
    return filters

# --- Helper Function to Check if a format matches filters ---
def format_matches_filters(format_info, filters):
    """Checks if a format dictionary matches the parsed filters."""
    if not isinstance(format_info, dict): return False

    for key, (op, expected_value) in filters.items():
        actual_value = format_info.get(key)
        if actual_value is None:
            return False # Key doesn't exist in format info

        try:
            if op == '==':
                # Simple string comparison for equality (e.g., ext, vcodec)
                if str(actual_value).lower() != str(expected_value).lower():
                    return False
            elif op == '<=':
                if not (isinstance(actual_value, (int, float)) and actual_value <= expected_value):
                    return False
            elif op == '>=':
                 if not (isinstance(actual_value, (int, float)) and actual_value >= expected_value):
                    return False
            # Add other operators if needed
        except Exception:
             # Handle potential type errors during comparison
             # print(f"Warning: Comparison error for key '{key}' (op '{op}') between '{actual_value}' and '{expected_value}'.", file=sys.stderr)
             return False
    return True

# --- Helper Function to Select Best Format based on Filters and Preference ---
def select_best_filtered_format(available_formats, selector):
    """
    Selects the best format from 'available_formats' that matches the 'selector'.
    Selector can be like 'bv[ext=mp4][height<=1080]' or 'ba[ext=m4a]' or 'best'.
    Returns the best matching format dictionary or None.
    Prioritizes resolution/quality (higher is better), then filesize (if available).
    """
    if not available_formats or not selector:
        return None

    # Separate base selector (bv, ba, b, best, etc.) from filters
    base_selector = selector.split('[', 1)[0]
    filter_str = '[' + selector.split('[', 1)[1] if '[' in selector else ''
    filters = parse_filter(filter_str)

    # Filter formats based on type implied by base_selector and explicit filters
    matching_formats = []
    for fmt in available_formats:
        is_video = fmt.get('vcodec') != 'none' and fmt.get('vcodec') is not None
        is_audio = fmt.get('acodec') != 'none' and fmt.get('acodec') is not None

        # --- Type Matching ---
        type_match = False
        if base_selector.startswith('bv') or (base_selector == 'best' and is_video and not is_audio) or (base_selector == 'b' and is_video): # Treat 'b' as video-inclusive for simplicity here
            # Check if it's a video format (or video-only if 'best')
             if is_video: type_match = True
        elif base_selector.startswith('ba') or (base_selector == 'best' and is_audio and not is_video) or (base_selector == 'b' and is_audio): # Treat 'b' as audio-inclusive
            # Check if it's an audio format (or audio-only if 'best')
            if is_audio: type_match = True
        elif base_selector == 'best' or base_selector == 'b': # 'best' or 'b' without type filters can be anything
             type_match = True
        # --- End Type Matching ---

        if type_match and format_matches_filters(fmt, filters):
            matching_formats.append(fmt)

    if not matching_formats:
        # print(f"Debug: No formats found matching selector '{selector}'", file=sys.stderr)
        return None

    # Sort matching formats: higher resolution/quality first, then larger filesize
    # This sorting is simplified. yt-dlp's is much more complex.
    # Prioritize height, then tbr (total bitrate as quality proxy), then filesize
    def sort_key(fmt):
        height = fmt.get('height') if isinstance(fmt.get('height'), int) else 0
        tbr = fmt.get('tbr') if isinstance(fmt.get('tbr'), (int, float)) else 0
        size = get_format_size(fmt)
        # Prioritize formats *with* size info slightly? Maybe not needed here.
        return (height, tbr, size)

    matching_formats.sort(key=sort_key, reverse=True)

    # print(f"Debug: Best format found for '{selector}': ID={matching_formats[0].get('format_id', 'N/A')}", file=sys.stderr)
    return matching_formats[0]


# --- Main Execution ---
def main():
    parser = argparse.ArgumentParser(
        description="Estimate media size by simulating yt-dlp format selection.",
        epilog="Example: python estimate_size.py 'https://...' 'bv[ext=mp4]+ba[ext=m4a]/b'"
    )
    parser.add_argument("url", nargs='?', default=None, help="Media URL")
    parser.add_argument("format_selector", nargs='?', default=None, help="yt-dlp format selector string")
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}", help="Show program's version number and exit")

    args = parser.parse_args()

    if args.url is None or args.format_selector is None:
        if len(sys.argv) <= 1: parser.print_help(sys.stderr); sys.exit(1)
        elif args.url is None: print("Error: Media URL is required.", file=sys.stderr); sys.exit(1)
        elif args.format_selector is None: print("Error: Format selector is required.", file=sys.stderr); sys.exit(1)
        else: sys.exit(1)

    # --- Get ALL available formats ---
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd:
        print("Error: yt-dlp command not found.", file=sys.stderr); print("0"); sys.exit(1)

    command_list_formats = [yt_dlp_cmd, "--dump-json", args.url]
    try:
        # print(f"Debug: Running command: {' '.join(command_list_formats)}", file=sys.stderr)
        process = subprocess.run(command_list_formats, capture_output=True, text=True, encoding='utf-8', check=False)
        if process.returncode != 0:
            print(f"Error: yt-dlp (list formats) exited with code {process.returncode}", file=sys.stderr); print(f"stderr:\n{process.stderr}", file=sys.stderr); print("0"); sys.exit(0)
        if not process.stdout.strip():
             print(f"Error: yt-dlp (list formats) produced empty output.", file=sys.stderr); print("0"); sys.exit(0)

        media_info = json.loads(process.stdout)
        if isinstance(media_info, list): media_info = media_info[0] # Take first if playlist
        if not isinstance(media_info, dict): print("Error: Parsed JSON is not a dict.", file=sys.stderr); print("0"); sys.exit(0)

        available_formats = media_info.get('formats')
        if not available_formats or not isinstance(available_formats, list):
             # Handle case where the top-level object IS the format info
             if media_info.get('format_id'):
                 available_formats = [media_info]
             else:
                 print("Warning: No 'formats' list found in JSON.", file=sys.stderr); print("0"); sys.exit(0)

    except json.JSONDecodeError as e:
        print(f"Error: Failed to decode JSON: {e}", file=sys.stderr); print("0"); sys.exit(0)
    except FileNotFoundError:
        print(f"Error: Failed to execute yt-dlp.", file=sys.stderr); print("0"); sys.exit(1)
    except Exception as e:
        print(f"Error getting available formats: {e}", file=sys.stderr); print("0"); sys.exit(1)

    # --- Simulate Format Selection ---
    final_estimated_size = 0
    selection_groups = args.format_selector.split('/') # Split by fallback '/'

    for group in selection_groups:
        # print(f"Debug: Trying selection group: '{group}'", file=sys.stderr)
        group_estimated_size = 0
        all_parts_found = True
        individual_selectors = group.split('+') # Split by merge '+'

        selected_formats_in_group = [] # Keep track of selected format IDs to avoid double counting if selector is 'b+b' etc.

        for selector in individual_selectors:
            # print(f"Debug:   Trying selector part: '{selector}'", file=sys.stderr)
            best_match = select_best_filtered_format(available_formats, selector)

            if best_match:
                format_id = best_match.get('format_id')
                # Avoid adding size if the same format is selected multiple times in one group
                if format_id not in selected_formats_in_group:
                    part_size = get_format_size(best_match)
                    # print(f"Debug:     Found match: ID={format_id}, Size={part_size}", file=sys.stderr)
                    group_estimated_size += part_size
                    selected_formats_in_group.append(format_id)
                # else:
                #     print(f"Debug:     Skipping already added format: ID={format_id}", file=sys.stderr)
            else:
                # print(f"Debug:     No match found for selector '{selector}'", file=sys.stderr)
                all_parts_found = False
                break # If any part of the merge group is not found, this group fails

        if all_parts_found:
            # print(f"Debug: Success! Found all parts for group '{group}'. Total size: {group_estimated_size}", file=sys.stderr)
            final_estimated_size = group_estimated_size
            break # Found a working group, stop processing fallbacks
        # else:
            # print(f"Debug: Failed to find all parts for group '{group}'. Trying next fallback.", file=sys.stderr)

    # --- Output the final calculated size ---
    print(final_estimated_size)
    sys.exit(0)


if __name__ == "__main__":
    main()
