#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# estimate_size.py

import sys
import subprocess
import json
import argparse
import shutil # For shutil.which

# --- Helper Function to Get Size ---
def get_format_size(format_info):
    """
    Gets the size of a format, prioritizing 'filesize' over 'filesize_approx'.
    Returns size in bytes or 0 if neither is available or valid.
    """
    filesize = format_info.get('filesize')
    filesize_approx = format_info.get('filesize_approx')

    if isinstance(filesize, (int, float)) and filesize > 0:
        return int(filesize)
    elif isinstance(filesize_approx, (int, float)) and filesize_approx > 0:
        return int(filesize_approx)
    else:
        # print(f"Debug: Format {format_info.get('format_id', 'N/A')} has no valid size.", file=sys.stderr)
        return 0

# --- Helper Function to Select Best Format (Simplified Logic) ---
def select_best_format(formats, media_type):
    """
    Selects the 'best' format based on type and size availability.
    media_type can be 'video', 'audio', or 'any'.
    Returns the selected format dictionary or None.
    This is a simplified selection, prioritizing *any* format with a valid size.
    A more sophisticated approach might consider resolution, bitrate, etc.
    """
    best_format = None
    max_size = -1 # Use -1 to ensure any format with size 0 is still considered if nothing better exists

    if not formats:
        return None

    for fmt in formats:
        # Basic type check
        is_video = fmt.get('vcodec') != 'none' and fmt.get('vcodec') is not None
        is_audio = fmt.get('acodec') != 'none' and fmt.get('acodec') is not None

        type_matches = False
        if media_type == 'video' and is_video:
            type_matches = True
        elif media_type == 'audio' and is_audio:
            type_matches = True
        elif media_type == 'any' and (is_video or is_audio): # Consider formats that have at least one stream
            type_matches = True

        if type_matches:
            current_size = get_format_size(fmt)
            # Select if it's the first valid one or has a larger size
            # We prioritize *any* format with a size over one without, then pick largest size
            if best_format is None or current_size > max_size:
                 # Ensure we only select if size is non-negative (get_format_size returns 0 if invalid)
                if current_size >= 0:
                    best_format = fmt
                    max_size = current_size

    # If after checking all, max_size is still -1, it means no format with a valid size was found
    if max_size == -1:
         # Fallback: maybe return the first matching type even without size? For now, return None.
         # print(f"Debug: No {media_type} format found with valid size.", file=sys.stderr)
         return None

    # print(f"Debug: Selected best {media_type}: ID={best_format.get('format_id', 'N/A')}, Size={max_size}", file=sys.stderr)
    return best_format

# --- Main Execution ---
def main():
    parser = argparse.ArgumentParser(description="Estimate media size using yt-dlp --dump-json.")
    parser.add_argument("url", help="Media URL")
    parser.add_argument("format_selector", help="yt-dlp format selector string (e.g., 'bv+ba/b')")
    args = parser.parse_args()

    # Check if yt-dlp exists
    yt_dlp_cmd = shutil.which("yt-dlp")
    if not yt_dlp_cmd:
        print("Error: yt-dlp command not found in PATH.", file=sys.stderr)
        print("0") # Output 0 for size as we can't estimate
        sys.exit(1) # Exit with error for Bash script

    # Construct command
    command = [
        yt_dlp_cmd,
        "--dump-json",
        "-f", args.format_selector,
        args.url
    ]

    # Execute command
    try:
        # print(f"Debug: Running command: {' '.join(command)}", file=sys.stderr)
        process = subprocess.run(
            command,
            capture_output=True,
            text=True,
            encoding='utf-8',
            check=False # Don't raise exception on non-zero exit, check manually
        )

        if process.returncode != 0:
            print(f"Error: yt-dlp exited with code {process.returncode}", file=sys.stderr)
            print(f"yt-dlp stderr:\n{process.stderr}", file=sys.stderr)
            print("0")
            sys.exit(0) # Exit 0 for Bash, as we handled the error by outputting 0

        # Check if stdout is empty
        if not process.stdout.strip():
             print(f"Error: yt-dlp produced empty output.", file=sys.stderr)
             print("0")
             sys.exit(0)

    except FileNotFoundError:
        print(f"Error: Failed to execute yt-dlp. Is it installed and in PATH?", file=sys.stderr)
        print("0")
        sys.exit(1)
    except Exception as e:
        print(f"Error running subprocess: {e}", file=sys.stderr)
        print("0")
        sys.exit(1)

    # Parse JSON
    try:
        media_info = json.loads(process.stdout)
        # Handle cases where yt-dlp dumps multiple JSON objects (e.g., playlists)
        # We typically only care about the first one for single URL info or the main playlist info
        if isinstance(media_info, list):
             if not media_info:
                 print("Error: yt-dlp returned an empty list.", file=sys.stderr)
                 print("0")
                 sys.exit(0)
             media_info = media_info[0] # Take the first item

        if not isinstance(media_info, dict):
            print("Error: Parsed JSON is not a dictionary.", file=sys.stderr)
            print("0")
            sys.exit(0)

    except json.JSONDecodeError as e:
        print(f"Error: Failed to decode JSON from yt-dlp output: {e}", file=sys.stderr)
        # print(f"yt-dlp stdout:\n{process.stdout}", file=sys.stderr) # Optional: print raw output for debugging
        print("0")
        sys.exit(0)
    except Exception as e:
        print(f"Error processing JSON: {e}", file=sys.stderr)
        print("0")
        sys.exit(0)


    # Extract formats list
    formats = media_info.get('formats')
    if not formats or not isinstance(formats, list):
        # Maybe it's a single format info dump? Check top level keys
        if get_format_size(media_info) > 0:
             formats = [media_info] # Treat the top-level dict as a single format
        else:
             print(f"Warning: No 'formats' list found in JSON, or it's empty. Cannot estimate size precisely.", file=sys.stderr)
             # Attempt to get top-level filesize as a last resort?
             top_level_size = get_format_size(media_info)
             print(top_level_size) # Output whatever size we found (might be 0)
             sys.exit(0)

    # --- Simplified Format Selection Simulation ---
    total_size = 0
    selected_video = None
    selected_audio = None

    # Decide if we need separate video and audio based on '+' in selector
    # This is a heuristic and might not cover all complex selectors perfectly
    needs_video_audio = '+' in args.format_selector

    if needs_video_audio:
        # Try to select best video and best audio
        selected_video = select_best_format(formats, 'video')
        selected_audio = select_best_format(formats, 'audio')

        if selected_video:
            total_size += get_format_size(selected_video)
        if selected_audio:
            total_size += get_format_size(selected_audio)
        # If we needed both but only found one (or none), the estimate might be off, but we proceed.
        if not selected_video: print("Warning: Could not select a suitable video stream based on available formats.", file=sys.stderr)
        if not selected_audio: print("Warning: Could not select a suitable audio stream based on available formats.", file=sys.stderr)

    else:
        # Assume we need the single best format (audio or video)
        selected_single = select_best_format(formats, 'any')
        if selected_single:
            total_size += get_format_size(selected_single)
        else:
             print("Warning: Could not select any suitable single stream based on available formats.", file=sys.stderr)


    # --- Output the final calculated size ---
    print(total_size)
    sys.exit(0)

if __name__ == "__main__":
    main()
