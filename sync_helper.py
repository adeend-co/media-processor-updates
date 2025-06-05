#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# sync_helper.py

import argparse
import subprocess
import shlex
import os
import sys

# --- Global Variables ---
SCRIPT_VERSION = "v1.0.0"
DEBUG_ENABLED = True # Set to False for production, or control via env var

# --- Logging Helpers (can be more sophisticated if needed) ---
def print_debug(message):
    if DEBUG_ENABLED:
        print(f"DEBUG: {message}", file=sys.stderr)

def print_info(message):
    print(f"INFO: {message}", file=sys.stdout) # stdout for user-facing info

def print_error(message):
    print(f"ERROR: {message}", file=sys.stderr)

def print_warning(message):
    print(f"WARNING: {message}", file=sys.stderr)

def run_command(command_list, dry_run=False):
    """Executes a command and returns its exit code, stdout, and stderr."""
    print_debug(f"Executing command: {' '.join(shlex.quote(str(s)) for s in command_list)}")
    if dry_run:
        print_info(f"[DRY RUN] Would execute: {' '.join(shlex.quote(str(s)) for s in command_list)}")
        return 0, "[Dry Run]", ""
    try:
        process = subprocess.Popen(command_list, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, bufsize=1, universal_newlines=True)
        
        stdout_lines = []
        stderr_lines = []

        # Stream stdout and stderr to print them live and capture for return
        # This allows for live progress from rsync
        if process.stdout:
            for stdout_line in process.stdout:
                # rsync progress often ends with \r, so handle it to avoid messy terminal output
                # but for logging or direct printing, we might want the raw line.
                # For now, just print directly.
                sys.stdout.write(stdout_line) # Print to terminal directly
                sys.stdout.flush()
                stdout_lines.append(stdout_line.strip()) # Store stripped line

        if process.stderr:
            for stderr_line in process.stderr:
                sys.stderr.write(stderr_line) # Print to terminal directly
                sys.stderr.flush()
                stderr_lines.append(stderr_line.strip())

        process.wait() # Wait for the process to complete
        return process.returncode, "\n".join(stdout_lines), "\n".join(stderr_lines)

    except FileNotFoundError:
        print_error(f"Command not found: {command_list[0]}")
        return -1, "", f"Command not found: {command_list[0]}"
    except Exception as e:
        print_error(f"Exception during command execution: {e}")
        return -2, "", str(e)


def main():
    parser = argparse.ArgumentParser(description=f"Sync Helper Script {SCRIPT_VERSION} - Transfers files using rsync over SSH.")
    parser.add_argument("source_dir", help="Source directory on the new phone (e.g., /sdcard/DCIM/Camera)")
    parser.add_argument("target_ssh_host", help="Target SSH host (old phone IP address)")
    parser.add_argument("target_ssh_user", help="Target SSH username for the old phone")
    parser.add_argument("target_remote_dir", help="Target directory on the old phone")
    parser.add_argument("--target-ssh-port", default="22", help="Target SSH port (default: 22, Termux often 8022)")
    parser.add_argument("--ssh-key-path", default=None, help="Path to the SSH private key on the new phone (optional)")
    parser.add_argument("--video-exts", default="", help="Comma-separated list of video extensions (e.g., mp4,mov)")
    parser.add_argument("--photo-exts", default="", help="Comma-separated list of photo extensions (e.g., jpg,png)")
    parser.add_argument("--rsync-path", default="rsync", help="Path to rsync executable (default: rsync)")
    parser.add_argument("--ssh-path", default="ssh", help="Path to ssh executable (default: ssh)")
    parser.add_argument("--dry-run", action="store_true", help="Perform a dry run (show what would be done)")
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}")


    args = parser.parse_args()

    print_info(f"--- Starting Sync Helper {SCRIPT_VERSION} ---")
    print_debug(f"Received arguments: {args}")

    # --- Validate source directory ---
    if not os.path.isdir(args.source_dir):
        print_error(f"Source directory '{args.source_dir}' does not exist or is not a directory.")
        sys.exit(1)

    # --- Prepare rsync command ---
    rsync_command = [args.rsync_path]
    rsync_options = [
        "-av", "--checksum", "--no-owner", "--no-group", 
        "--progress", "--human-readable"
    ]
    # Using -v for rsync can be very verbose, --info=progress2 is often better for scripting
    # but --progress is good for user feedback. We'll stick to -av for now.
    # If you want less rsync output during the run_command stdout streaming, remove -v from -av

    if args.dry_run:
        rsync_options.append("--dry-run")

    rsync_command.extend(rsync_options)

    # --- Prepare SSH options for rsync's -e ---
    ssh_exe_path = args.ssh_path
    ssh_connection_options = [ssh_exe_path, "-p", str(args.target_ssh_port)]
    if args.ssh_key_path and os.path.isfile(args.ssh_key_path):
        ssh_connection_options.extend(["-i", args.ssh_key_path])
        print_info(f"Using SSH key: {args.ssh_key_path}")
    else:
        if args.ssh_key_path: # Path provided but not found
            print_warning(f"SSH key path '{args.ssh_key_path}' not found. Will attempt password authentication.")
        else:
            print_info("No SSH key path provided. Will attempt password authentication if needed.")

    # Ensure options that might contain spaces are handled correctly for the -e argument
    # shlex.join is Python 3.8+
    try:
        e_option_value = ' '.join(shlex.quote(str(s)) for s in ssh_connection_options)
    except AttributeError: # Fallback for older Python if shlex.join is not available
        e_option_value = ' '.join(map(shlex.quote, ssh_connection_options))


    rsync_command.extend(["-e", e_option_value])


    # --- Prepare include/exclude rules ---
    # Rsync filter rule order:
    # 1. Include directories to allow traversal ('*/')
    # 2. Include specific file patterns ('*.jpg')
    # 3. Exclude everything else ('*')

    filter_rules = []
    has_extensions = False

    if args.video_exts:
        has_extensions = True
        for ext in args.video_exts.split(','):
            ext = ext.strip().lower()
            if ext:
                filter_rules.append(f"--include=*/") # Essential for directory traversal
                filter_rules.append(f"--include=*.{ext}")
                filter_rules.append(f"--include=*.{ext.upper()}") # Case-insensitivity
    if args.photo_exts:
        has_extensions = True
        for ext in args.photo_exts.split(','):
            ext = ext.strip().lower()
            if ext:
                filter_rules.append(f"--include=*/")
                filter_rules.append(f"--include=*.{ext}")
                filter_rules.append(f"--include=*.{ext.upper()}")
    
    if not has_extensions:
        print_error("No video or photo extensions specified for sync. Aborting.")
        sys.exit(1)
        
    # Add filter rules to rsync command
    # Important: Add --include='*/' many times is fine, rsync handles it.
    # The final --exclude='*' ensures only matched items are synced.
    unique_filter_rules = sorted(list(set(filter_rules))) # Remove duplicates, sort for consistency
    rsync_command.extend(unique_filter_rules)
    rsync_command.append("--exclude=*") # Exclude everything not explicitly included


    # --- Prepare source and destination paths ---
    # Ensure source_dir ends with a slash for rsync to copy contents
    source_path_rsync = args.source_dir if args.source_dir.endswith('/') else args.source_dir + '/'
    
    # Ensure target_remote_dir ends with a slash
    target_dir_rsync = args.target_remote_dir if args.target_remote_dir.endswith('/') else args.target_remote_dir + '/'
    destination_rsync = f"{args.target_ssh_user}@{args.target_ssh_host}:{target_dir_rsync}"

    rsync_command.append(source_path_rsync)
    rsync_command.append(destination_rsync)

    print_info(f"Source: {source_path_rsync}")
    print_info(f"Target: {destination_rsync}")
    print_info(f"Video extensions: {args.video_exts or 'None'}")
    print_info(f"Photo extensions: {args.photo_exts or 'None'}")
    if args.dry_run:
        print_warning("DRY RUN MODE ENABLED - NO FILES WILL BE TRANSFERRED.")
    
    print_info("---------------------------------------------")
    print_info("Starting rsync process...")
    
    exit_code, stdout_data, stderr_data = run_command(rsync_command, dry_run=args.dry_run)

    print_info("---------------------------------------------")
    if exit_code == 0:
        print_info(f"Sync process completed {'successfully' if not args.dry_run else '(dry run successful)'}.")
        if args.dry_run and stdout_data:
             print_debug(f"Rsync dry-run output summary:\n{stdout_data}")
    else:
        print_error(f"Sync process failed with exit code: {exit_code}")
        if stderr_data:
            print_error(f"Rsync stderr:\n{stderr_data}")
        if stdout_data and DEBUG_ENABLED : # Print stdout too on error if debugging
            print_debug(f"Rsync stdout on error:\n{stdout_data}")

    sys.exit(exit_code if exit_code >= 0 else 1) # Ensure exit code is 0-255

if __name__ == "__main__":
    main()
