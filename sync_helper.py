#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# sync_helper.py
# 版本: v2.0.0 - 支援多來源目錄、進度條切換、遠端依賴檢查、錯誤碼解析

import argparse
import os
import shlex
import subprocess
import sys

# --- 全域變數 ---
SCRIPT_VERSION = "v2.0.0"

# --- 日誌輔助函數 ---
def print_info(message):
    print(f"INFO: {message}", file=sys.stdout)

def print_warning(message):
    print(f"WARNING: {message}", file=sys.stderr)

def print_error(message):
    print(f"ERROR: {message}", file=sys.stderr)

def print_debug(message, debug_mode=False):
    if debug_mode:
        print(f"DEBUG: {message}", file=sys.stderr)

# --- rsync 錯誤碼解析 ---
def parse_rsync_exit_code(code):
    """解析 rsync 的退出碼並返回人類可讀的訊息。"""
    error_map = {
        1: "語法或使用錯誤 (Syntax or usage error)",
        2: "協定不相容 (Protocol incompatibility)",
        3: "檔案 I/O 發生錯誤 (Errors selecting input/output files, dirs)",
        4: "請求的操作無法分配記憶體 (Requested action not supported or no space)",
        5: "啟動客戶端/伺服器時出錯 (Error starting client-server protocol)",
        6: "與 rsync 伺服器通訊時出錯 (Daemon unable to append to log-file)",
        10: "Socket I/O 錯誤 (Error in socket I/O)",
        11: "檔案 I/O 錯誤，可能是磁碟空間不足 (Error in file I/O, maybe out of space?)",
        12: "rsync 協定資料流錯誤 (Error in rsync protocol data stream)",
        13: "輸入格式錯誤 (Error with input usage formats)",
        14: "子程序報告錯誤 (Error from running ancillary program)",
        20: "收到了 SIGUSR1 或 SIGHUP 信號 (Received SIGUSR1 or SIGHUP)",
        21: "產生檔案列表時發生錯誤 (Some error returned by waitpid())",
        22: "與目標主機通訊錯誤 (Error allocating core memory buffers)",
        23: "部分檔案傳輸失敗 (Partial transfer due to error)",
        24: "部分檔案因來源檔案消失而傳輸失敗 (Partial transfer due to vanished source files)",
        25: "rsync 協定限制導致無法傳輸 (The --max-delete limit stopped deletions)",
        30: "因 I/O 超時而逾時 (Timeout in data send/receive)",
        35: "因連線逾時而逾時 (Timeout waiting for daemon connection)"
    }
    return error_map.get(code, f"未知的 rsync 錯誤 (Unknown rsync error code: {code})")

# --- 執行外部命令 ---
def run_command(command, debug_mode=False):
    """執行外部命令並即時串流其輸出。"""
    print_debug(f"Executing command: {' '.join(map(shlex.quote, command))}", debug_mode)
    try:
        proc = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding='utf-8',
            errors='replace'
        )

        # 即時讀取 stdout 和 stderr
        while True:
            # 讀取 stdout
            stdout_line = proc.stdout.readline()
            if stdout_line:
                # \r 用於覆蓋同一行，實現進度條效果
                # \n 用於換行
                # end='' 防止 print 額外添加換行
                if '\r' in stdout_line:
                    sys.stdout.write(stdout_line)
                    sys.stdout.flush()
                else:
                    print(stdout_line, end='')

            # 讀取 stderr
            stderr_line = proc.stderr.readline()
            if stderr_line:
                print(stderr_line, end='', file=sys.stderr)

            # 檢查程序是否已結束
            if proc.poll() is not None and not stdout_line and not stderr_line:
                break
        
        # 獲取最終的退出碼
        exit_code = proc.returncode
        return exit_code

    except FileNotFoundError:
        print_error(f"命令 '{command[0]}' 未找到。請確保它已安裝並在您的 PATH 中。")
        return 127
    except Exception as e:
        print_error(f"執行命令時發生未知錯誤: {e}")
        return 1

# --- 主函數 ---
def main():
    parser = argparse.ArgumentParser(
        description="使用 rsync 和 SSH 在兩台設備之間安全地同步媒體檔案。",
        epilog="範例: python sync_helper.py /path/to/source1;/path/to/source2 user@host /path/to/target --video-exts mp4,mov --photo-exts jpg,jpeg"
    )
    # --- 【優化】支援多個來源目錄，以分號分隔 ---
    parser.add_argument("source_dirs", help="要同步的來源目錄，多個目錄請用分號(;)分隔。")
    parser.add_argument("target_ssh_host", help="目標 SSH 主機 (例如: user@192.168.1.100)")
    parser.add_argument("target_dir", help="目標主機上的接收目錄。")
    
    parser.add_argument("--target-ssh-user", help="目標 SSH 用戶名 (如果未在主機字串中提供)。")
    parser.add_argument("--target-ssh-port", default="22", help="目標 SSH 端口 (預設: 22)")
    parser.add_argument("--ssh-key-path", help="用於驗證的 SSH 私鑰的完整路徑。")
    
    parser.add_argument("--video-exts", help="要同步的影片副檔名列表 (逗號分隔)。")
    parser.add_argument("--photo-exts", help="要同步的照片副檔名列表 (逗號分隔)。")

    # --- 【優化】進度條樣式 ---
    parser.add_argument("--progress-style", choices=['default', 'total'], default='default', help="進度顯示樣式: 'default' (每個檔案) 或 'total' (總進度)。")

    # --- 【優化】頻寬限制 ---
    parser.add_argument("--bwlimit", type=int, default=0, help="限制頻寬 (單位 KB/s)，0 為不限制。")

    parser.add_argument("--dry-run", action="store_true", help="執行模擬運行，顯示將要執行的操作而不實際傳輸。")
    parser.add_argument("--rsync-path", default="rsync", help="rsync 可執行檔的路徑。")
    parser.add_argument("--ssh-path", default="ssh", help="ssh 可執行檔的路徑。")
    parser.add_argument("--debug", action="store_true", help="啟用詳細的除錯輸出。")
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}")
    
    args = parser.parse_args()

    # --- 參數驗證 ---
    # 【優化】將來源目錄字串分割為列表
    source_dirs = [d.strip() for d in args.source_dirs.split(';') if d.strip()]
    if not source_dirs:
        print_error("錯誤：必須提供至少一個有效的來源目錄。")
        sys.exit(1)

    for src_dir in source_dirs:
        if not os.path.isdir(src_dir):
            print_error(f"錯誤：來源目錄 '{src_dir}' 不存在或不是一個目錄。")
            sys.exit(1)

    if args.ssh_key_path and not os.path.isfile(args.ssh_key_path):
        print_error(f"錯誤：指定的 SSH 私鑰檔案 '{args.ssh_key_path}' 不存在。")
        sys.exit(1)
        
    ssh_host = args.target_ssh_host
    ssh_user = args.target_ssh_user
    # 如果 user@host 格式，解析出來
    if not ssh_user and '@' in ssh_host:
        try:
            ssh_user, ssh_host = ssh_host.split('@', 1)
        except ValueError:
            print_error("錯誤：目標 SSH 主機格式無效，請使用 'user@host' 或分別提供主機和用戶。")
            sys.exit(1)

    if not ssh_user or not ssh_host:
        print_error("錯誤：必須提供目標 SSH 用戶名和主機地址。")
        sys.exit(1)
        
    # --- 【優化】遠端依賴檢查 ---
    print_info(f"正在檢查遠端主機 '{ssh_host}' 上的 'rsync' 依賴...")
    check_ssh_cmd = [args.ssh_path, '-p', args.target_ssh_port, f'{ssh_user}@{ssh_host}', 'command -v rsync']
    if args.ssh_key_path:
        check_ssh_cmd[1:1] = ['-i', args.ssh_key_path]

    try:
        proc_check = subprocess.run(check_ssh_cmd, capture_output=True, text=True, timeout=15)
        if proc_check.returncode != 0:
            print_error(f"依賴檢查失敗：遠端主機 '{ssh_host}' 上找不到 'rsync' 命令！")
            print_error("請在舊手機的 Termux 中執行 'pkg install rsync'。")
            print_debug(f"SSH 檢查錯誤輸出: {proc_check.stderr}", args.debug)
            sys.exit(1)
        print_info("遠端 'rsync' 依賴檢查通過。")
    except subprocess.TimeoutExpired:
        print_error(f"依賴檢查失敗：連線到 '{ssh_host}' 超時。請檢查網路和 SSH 設定。")
        sys.exit(1)
    except Exception as e:
        print_error(f"依賴檢查時發生未知錯誤：{e}")
        sys.exit(1)


    # --- 構建 rsync 命令 ---
    rsync_command = [args.rsync_path, "-a"] # -a 包含了 -rlptgoD

    # --- 【優化】進度條樣式 ---
    if args.progress_style == 'total':
        rsync_command.append("--info=progress2")
    else: # default
        rsync_command.append("--progress")

    if args.dry_run:
        rsync_command.append("--dry-run")
        print_warning("--- 正在以乾跑 (Dry Run) 模式執行 ---")

    # --- 【優化】頻寬限制 ---
    if args.bwlimit > 0:
        rsync_command.extend(["--bwlimit", str(args.bwlimit)])
        print_info(f"頻寬限制已設定為 {args.bwlimit} KB/s。")

    # SSH 選項
    ssh_options = f"{args.ssh_path} -p {args.target_ssh_port}"
    if args.ssh_key_path:
        ssh_options += f" -i {shlex.quote(args.ssh_key_path)}"
    rsync_command.extend(["-e", ssh_options])

    # 檔案過濾規則
    include_rules = []
    # 始終包含所有目錄以便遍歷
    include_rules.append("--include=*/")
    
    all_extensions = []
    if args.video_exts:
        all_extensions.extend(args.video_exts.lower().split(','))
    if args.photo_exts:
        all_extensions.extend(args.photo_exts.lower().split(','))

    for ext in set(all_extensions): # 使用 set 去重
        if ext:
            # 包含大小寫
            include_rules.append(f"--include=*.{ext}")
            include_rules.append(f"--include=*.{ext.upper()}")
    
    # 添加規則到命令中
    rsync_command.extend(include_rules)
    # 排除所有其他檔案
    rsync_command.append("--exclude=*")

    # --- 【優化】加入來源和目標目錄 ---
    rsync_command.extend(source_dirs)
    
    # 確保目標目錄以斜線結尾
    target_dir_rsync = args.target_dir.rstrip('/') + '/'
    rsync_command.append(f"{ssh_user}@{ssh_host}:{shlex.quote(target_dir_rsync)}")

    # --- 執行同步 ---
    print_info("---------------------------------------------")
    print_info("開始同步...")
    for i, src in enumerate(source_dirs):
        print_info(f"  來源目錄 {i+1}: {src}")
    print_info(f"  目標: {ssh_user}@{ssh_host}:{args.target_dir}")
    print_info("---------------------------------------------")

    exit_code = run_command(rsync_command, args.debug)
    
    print_info("---------------------------------------------")
    if exit_code == 0:
        print_info("同步過程成功完成。")
    else:
        # --- 【優化】錯誤碼解析 ---
        error_message = parse_rsync_exit_code(exit_code)
        print_error(f"同步過程失敗，退出碼: {exit_code} ({error_message})")

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
