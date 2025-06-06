#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# sync_helper.py
# 版本: v2.0.1 - 優化 run_command 以解決進度條緩衝問題
# 保持與 v2.0.0 的功能一致，僅修改命令執行方式

import argparse
import os
import shlex
import subprocess
import sys

# 【優化】導入 pty 和 select 模組
import pty
import select


# --- 全域變數 ---
SCRIPT_VERSION = "v2.0.1"

# --- 日誌輔助函數 (保持不變) ---
def print_info(message):
    print(f"INFO: {message}", file=sys.stdout)

def print_warning(message):
    print(f"WARNING: {message}", file=sys.stderr)

def print_error(message):
    print(f"ERROR: {message}", file=sys.stderr)

def print_debug(message, debug_mode=False):
    if debug_mode:
        print(f"DEBUG: {message}", file=sys.stderr)

# --- rsync 錯誤碼解析 (保持不變) ---
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


# --- 【優化替換】執行外部命令 (使用 pty 解決緩衝問題) ---
def run_command(command, debug_mode=False):
    """執行外部命令並使用 pty 解決緩衝問題，即時串流其輸出。"""
    print_debug(f"Executing command with pty: {' '.join(map(shlex.quote, command))}", debug_mode)
    try:
        # 創建主從偽終端
        master_fd, slave_fd = pty.openpty()

        proc = subprocess.Popen(
            command,
            stdout=slave_fd,
            stderr=slave_fd, # 將 stdout 和 stderr 都定向到偽終端
            text=False, # 在 pty 模式下，我們手動解碼，所以 text=False
            # encoding 和 errors 在此模式下不需要
            preexec_fn=os.setsid # 確保程序在新的會話中運行
        )

        # 關閉子進程中的從偽終端文件描述符
        os.close(slave_fd)
        
        # 從主偽終端讀取輸出
        while proc.poll() is None:
            # 使用 select 來等待文件描述符變為可讀，避免忙碌等待
            r, _, _ = select.select([master_fd], [], [], 0.1) # 0.1秒超時
            if r:
                try:
                    # 讀取二進制數據並手動解碼
                    data_bytes = os.read(master_fd, 1024)
                    if data_bytes:
                        data_str = data_bytes.decode('utf-8', errors='replace')
                        sys.stdout.write(data_str)
                        sys.stdout.flush()
                    else:
                        # 如果 os.read 返回空，表示子進程已關閉其偽終端
                        break
                except OSError:
                    # 當子進程結束時，讀取可能會引發 OSError
                    break
        
        # 關閉主偽終端
        os.close(master_fd)

        # 等待子進程完全結束並獲取退出碼
        exit_code = proc.wait()
        
        return exit_code

    except FileNotFoundError:
        print_error(f"命令 '{command[0]}' 未找到。請確保它已安裝並在您的 PATH 中。")
        return 127
    except Exception as e:
        print_error(f"執行命令時發生未知錯誤: {e}")
        import traceback
        traceback.print_exc(file=sys.stderr)
        return 1

# --- 主函數 (保持不變) ---
def main():
    parser = argparse.ArgumentParser(
        description="使用 rsync 和 SSH 在兩台設備之間安全地同步媒體檔案。",
        epilog="範例: python sync_helper.py /path/to/source1;/path/to/source2 user@host /path/to/target --video-exts mp4,mov --photo-exts jpg,jpeg"
    )
    parser.add_argument("source_dirs", help="要同步的來源目錄，多個目錄請用分號(;)分隔。")
    parser.add_argument("target_ssh_host", help="目標 SSH 主機 (例如: user@192.168.1.100)")
    parser.add_argument("target_dir", help="目標主機上的接收目錄。")
    
    parser.add_argument("--target-ssh-user", help="目標 SSH 用戶名 (如果未在主機字串中提供)。")
    parser.add_argument("--target-ssh-port", default="22", help="目標 SSH 端口 (預設: 22)")
    parser.add_argument("--ssh-key-path", help="用於驗證的 SSH 私鑰的完整路徑。")
    
    parser.add_argument("--video-exts", help="要同步的影片副檔名列表 (逗號分隔)。")
    parser.add_argument("--photo-exts", help="要同步的照片副檔名列表 (逗號分隔)。")

    parser.add_argument("--progress-style", choices=['default', 'total'], default='default', help="進度顯示樣式: 'default' (每個檔案) 或 'total' (總進度)。")
    parser.add_argument("--bwlimit", type=int, default=0, help="限制頻寬 (單位 KB/s)，0 為不限制。")

    parser.add_argument("--dry-run", action="store_true", help="執行模擬運行，顯示將要執行的操作而不實際傳輸。")
    parser.add_argument("--rsync-path", default="rsync", help="rsync 可執行檔的路徑。")
    parser.add_argument("--ssh-path", default="ssh", help="ssh 可執行檔的路徑。")
    parser.add_argument("--debug", action="store_true", help="啟用詳細的除錯輸出。")
    parser.add_argument("-v", "--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}")
    
    args = parser.parse_args()

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
    if not ssh_user and '@' in ssh_host:
        try:
            ssh_user, ssh_host = ssh_host.split('@', 1)
        except ValueError:
            print_error("錯誤：目標 SSH 主機格式無效，請使用 'user@host' 或分別提供主機和用戶。")
            sys.exit(1)

    if not ssh_user or not ssh_host:
        print_error("錯誤：必須提供目標 SSH 用戶名和主機地址。")
        sys.exit(1)
        
    print_info(f"正在檢查遠端主機 '{ssh_host}' 上的 'rsync' 依賴...")
    check_ssh_cmd = [args.ssh_path, '-p', args.target_ssh_port, f'{ssh_user}@{ssh_host}', 'command -v rsync']
    if args.ssh_key_path:
        check_ssh_cmd.insert(1, '-i')
        check_ssh_cmd.insert(2, args.ssh_key_path)

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

    rsync_command = [args.rsync_path, "-a"] 
    if args.progress_style == 'total':
        rsync_command.append("--info=progress2")
    else:
        rsync_command.append("--progress")

    if args.dry_run:
        rsync_command.append("--dry-run")
        print_warning("--- 正在以乾跑 (Dry Run) 模式執行 ---")

    if args.bwlimit > 0:
        rsync_command.extend(["--bwlimit", str(args.bwlimit)])
        print_info(f"頻寬限制已設定為 {args.bwlimit} KB/s。")

    ssh_options = f"{args.ssh_path} -p {args.target_ssh_port}"
    if args.ssh_key_path:
        ssh_options += f" -i {shlex.quote(args.ssh_key_path)}"
    rsync_command.extend(["-e", ssh_options])

    include_rules = ["--include=*/"]
    all_extensions = []
    if args.video_exts:
        all_extensions.extend(args.video_exts.lower().split(','))
    if args.photo_exts:
        all_extensions.extend(args.photo_exts.lower().split(','))

    for ext in set(all_extensions):
        if ext:
            include_rules.append(f"--include=*.{ext}")
            include_rules.append(f"--include=*.{ext.upper()}")
    
    rsync_command.extend(include_rules)
    rsync_command.append("--exclude=*")
    rsync_command.extend(source_dirs)
    
    target_dir_rsync = args.target_dir.rstrip('/') + '/'
    rsync_command.append(f"{ssh_user}@{ssh_host}:{shlex.quote(target_dir_rsync)}")

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
        error_message = parse_rsync_exit_code(exit_code)
        print_error(f"同步過程失敗，退出碼: {exit_code} ({error_message})")

    sys.exit(exit_code)

if __name__ == "__main__":
    main()
