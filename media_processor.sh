#!/bin/bash

# 腳本設定
SCRIPT_VERSION="v2.4.13(Experimental)" # <<< 版本號更新
############################################
# <<< 新增：腳本更新日期 >>>
############################################
SCRIPT_UPDATE_DATE="2025-04-13" # 請根據實際情況修改此日期
############################################

# ... 其他設定 ...
TARGET_DATE="2025-07-11" # <<< 新增：設定您的目標日期
# DEFAULT_URL, THREADS, MAX_THREADS, MIN_THREADS 保留
DEFAULT_URL="https://www.youtube.com/watch?v=siNFnlqtd8M"
THREADS=4
MAX_THREADS=8
MIN_THREADS=1
COLOR_ENABLED=true
# --- Configuration File ---
# <<< 新增：設定檔路徑 >>>
CONFIG_FILE="$HOME/.media_processor_rc"
# 自動更新設定保留
REMOTE_VERSION_URL="https://raw.githubusercontent.com/adeend-co/media-processor-updates/refs/heads/main/latest_version.txt" # <<< 請務必修改此 URL
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/adeend-co/media-processor-updates/refs/heads/main/media_processor.sh"   # <<< 請務必修改此 URL
SCRIPT_INSTALL_PATH="$HOME/scripts/media_processor.sh"
# --- 新增：Python 轉換器相關設定 ---
PYTHON_CONVERTER_SCRIPT_NAME="vtt_to_ass_converter.py"
PYTHON_CONVERTER_INSTALL_PATH="$HOME/scripts/$PYTHON_CONVERTER_SCRIPT_NAME"
PYTHON_CONVERTER_VERSION="0.0.0" # <<< 本地版本，會從設定檔載入
PYTHON_CONVERTER_VERSION_URL="https://raw.githubusercontent.com/adeend-co/media-processor-updates/refs/heads/main/latest_version(Vtt_to_Ass)" # <<<【重要】需要您提供實際的 URL
PYTHON_CONVERTER_REMOTE_URL="https://raw.githubusercontent.com/adeend-co/media-processor-updates/refs/heads/main/vtt_to_ass_converter.py"   # <<<【重要】需要您提供實際的 URL
# --- 結束 Python 轉換器設定 ---
# <<< 修改：確保腳本安裝目錄存在，僅在創建時顯示訊息 >>>
SCRIPT_DIR=$(dirname "$SCRIPT_INSTALL_PATH") # 從完整路徑獲取目錄名稱 (~/scripts)

# 檢查目錄是否不存在
if [ ! -d "$SCRIPT_DIR" ]; then
    # 如果不存在，才顯示嘗試創建的訊息
    echo -e "\033[0;33m偵測到腳本目錄 '$SCRIPT_DIR' 不存在，正在創建... \033[0m"
    
    # 執行 mkdir -p
    if mkdir -p "$SCRIPT_DIR"; then
        # 創建成功後，顯示成功訊息
        echo -e "\033[0;32m目錄 '$SCRIPT_DIR' 創建成功。\033[0m"
        sleep 1 # 短暫停留讓使用者看到
    else
        # 如果創建失敗，顯示錯誤並退出
        echo -e "\033[0;31m錯誤：無法創建腳本目錄 '$SCRIPT_DIR'！請檢查權限。腳本無法繼續。\033[0m" >&2
        exit 1
    fi
# 如果目錄一開始就存在，則不執行上面 if 區塊內的任何操作，保持安靜
fi

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local colored_message=""

    # 避免顏色代碼問題的簡化版本
    if [ -n "$LOG_FILE" ]; then
        # 寫入日誌時使用純文本
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
        
        # 螢幕顯示時可以使用顏色
        case "$level" in
            "INFO") colored_message="${BLUE}[$timestamp] [${BOLD}$level${RESET}${BLUE}] $message${RESET}" ;;
            "WARNING") colored_message="${YELLOW}[$timestamp] [${BOLD}$level${RESET}${YELLOW}] $message${RESET}" ;;
            "ERROR") colored_message="${RED}[$timestamp] [${BOLD}$level${RESET}${RED}] $message${RESET}" ;;
            "SUCCESS") colored_message="${GREEN}[$timestamp] [${BOLD}$level${RESET}${GREEN}] $message${RESET}" ;;
            *) colored_message="[$timestamp] [$level] $message" ;;
        esac
        echo -e "$colored_message"
    else
        # 與原代碼相同
        case "$level" in
            "INFO") colored_message="${BLUE}[$timestamp] [${BOLD}$level${RESET}${BLUE}] $message${RESET}" ;;
            "WARNING") colored_message="${YELLOW}[$timestamp] [${BOLD}$level${RESET}${YELLOW}] $message${RESET}" ;;
            "ERROR") colored_message="${RED}[$timestamp] [${BOLD}$level${RESET}${RED}] $message${RESET}" ;;
            "SUCCESS") colored_message="${GREEN}[$timestamp] [${BOLD}$level${RESET}${GREEN}] $message${RESET}" ;;
            *) colored_message="[$timestamp] [$level] $message" ;;
        esac
        echo -e "$colored_message"
    fi
}

############################################
# <<< 修改：儲存設定檔 (加入 Python 版本) >>>
############################################
save_config() {
    log_message "INFO" "正在儲存目前設定到 $CONFIG_FILE ..."
    if echo "THREADS=\"$THREADS\"" > "$CONFIG_FILE" && \
       echo "DOWNLOAD_PATH=\"$DOWNLOAD_PATH\"" >> "$CONFIG_FILE" && \
       echo "COLOR_ENABLED=\"$COLOR_ENABLED\"" >> "$CONFIG_FILE" && \
       echo "PYTHON_CONVERTER_VERSION=\"$PYTHON_CONVERTER_VERSION\"" >> "$CONFIG_FILE"; then # <<< 新增
        log_message "INFO" "設定已成功儲存到 $CONFIG_FILE"
    else
        log_message "ERROR" "無法寫入設定檔 $CONFIG_FILE！請檢查權限。"
        echo -e "${RED}錯誤：無法儲存設定到 $CONFIG_FILE！${RESET}"
        sleep 2
    fi
}

############################################
# <<< 新增：Termux 通知輔助函數 (移除 ID) >>>
############################################
_send_termux_notification() {
    # $1: Result code (0 for success, non-zero for failure)
    # $2: Notification Title (e.g., "媒體處理器：MP4")
    # $3: Base message (e.g., "處理影片 'Title'") <-- ID 已移除
    # $4: Final file path (used to get basename on success)

    local result_code="$1"
    local notification_title="$2"
    local base_message="$3" # ID 已從這裡移除
    local final_filepath="$4"

    # 檢查是否為 Termux 環境以及命令是否存在
    if [[ "$OS_TYPE" != "termux" ]] || ! command -v termux-notification &> /dev/null; then
        if [[ "$OS_TYPE" == "termux" ]] && ! command -v termux-notification &> /dev/null; then
             log_message "INFO" "未找到 termux-notification 命令，跳過通知。"
        fi
        return # 非 Termux 或無命令，直接返回
    fi

    local notification_content=""
    local final_basename=$(basename "$final_filepath" 2>/dev/null) # 安全獲取檔名

    if [ "$result_code" -eq 0 ] && [ -n "$final_basename" ] && [ -f "$final_filepath" ]; then
        # 成功訊息 (不含 ID)
        notification_content="✅ 成功：$base_message 已儲存為 '$final_basename'。"
        log_message "INFO" "準備發送 Termux 成功通知 for $final_basename"
    else
        # 失敗訊息 (不含 ID)
        notification_content="❌ 失敗：$base_message 處理失敗。請查看輸出或日誌。"
        log_message "INFO" "準備發送 Termux 失敗通知 for $base_message"
    fi

    # 發送通知
    if ! termux-notification --title "$notification_title" --content "$notification_content"; then
        log_message "WARNING" "執行 termux-notification 命令失敗。"
    else
        log_message "INFO" "Termux 通知已成功發送。"
    fi
}

############################################
# <<< 修改：載入設定檔 (安全解析版，取代 source) >>>(2.3.9+)
############################################
load_config() {
    # 設定預設值 (這些值在設定檔未找到或無效時使用)
    # 注意：THREADS, DOWNLOAD_PATH 等的初始預設值應在腳本頂部設定好
    #       這裡主要是確保 Python 版本有預設值
    PYTHON_CONVERTER_VERSION="0.0.0"
    # 記錄一下初始預設值 (如果設定檔不存在，這些值會被使用)
    local initial_threads="$THREADS"
    local initial_dl_path="$DOWNLOAD_PATH"
    local initial_color="$COLOR_ENABLED"
    local initial_py_ver="$PYTHON_CONVERTER_VERSION"

    if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ]; then
        log_message "INFO" "正在從 $CONFIG_FILE 安全地載入設定..."
        echo -e "${BLUE}正在從 $CONFIG_FILE 載入設定...${RESET}" # 給使用者提示

        local line_num=0
        # 使用 IFS= 和 -r read 來正確處理行
        while IFS= read -r line || [[ -n "$line" ]]; do
            ((line_num++))
            # 移除行首行尾的空白字符 (可選，但更健壯)
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # 跳過空行和註解行 (以 # 開頭，前面可能有空白)
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi

            # 使用正則表達式匹配 VAR="VALUE" 格式
            # ^[[:space:]]* : 行首可能有空白
            # ([A-Za-z_][A-Za-z0-9_]+) : 捕獲合法的變數名 (字母/數字/底線，不能以數字開頭)
            # [[:space:]]*=[[:space:]]* : 等號，前後可能有空白
            # \"(.*)\" : 捕獲雙引號內的內容 (值)
            # [[:space:]]*$ : 行尾可能有空白
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"(.*)\"[[:space:]]*$ ]]; then
                local var_name="${BASH_REMATCH[1]}"
                local var_value="${BASH_REMATCH[2]}"

                # --- 安全核心：只處理已知的變數 ---
                case "$var_name" in
                    "THREADS")
                        # 驗證 THREADS
                        if [[ "$var_value" =~ ^[0-9]+$ ]] && [ "$var_value" -ge "$MIN_THREADS" ] && [ "$var_value" -le "$MAX_THREADS" ]; then
                            THREADS="$var_value"
                            log_message "INFO" "從設定檔載入: THREADS=$THREADS"
                        else
                            log_message "WARNING" "設定檔中的 THREADS ('$var_value') 無效或超出範圍 ($MIN_THREADS-$MAX_THREADS)，將使用預設值或自動調整。"
                            # 保留之前的預設值或讓後續 adjust_threads 處理
                            THREADS="$initial_threads" # 或設置為 MIN_THREADS
                        fi
                        ;;
                    "DOWNLOAD_PATH")
                        # 這裡只賦值，路徑的有效性檢查在函數末尾統一進行
                        DOWNLOAD_PATH="$var_value"
                        log_message "INFO" "從設定檔載入: DOWNLOAD_PATH=$DOWNLOAD_PATH"
                        ;;
                    "COLOR_ENABLED")
                        if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then
                            COLOR_ENABLED="$var_value"
                            log_message "INFO" "從設定檔載入: COLOR_ENABLED=$COLOR_ENABLED"
                        else
                            log_message "WARNING" "設定檔中的 COLOR_ENABLED ('$var_value') 無效，將使用預設值 '$initial_color'。"
                            COLOR_ENABLED="$initial_color"
                        fi
                        ;;
                    "PYTHON_CONVERTER_VERSION")
                        # 基礎檢查 (非空)
                        if [ -n "$var_value" ]; then
                             PYTHON_CONVERTER_VERSION="$var_value"
                             log_message "INFO" "從設定檔載入: PYTHON_CONVERTER_VERSION=$PYTHON_CONVERTER_VERSION"
                        else
                             log_message "WARNING" "設定檔中的 PYTHON_CONVERTER_VERSION 為空，將使用預設值 '$initial_py_ver'。"
                             PYTHON_CONVERTER_VERSION="$initial_py_ver"
                        fi
                        ;;
                    *)
                        # 忽略未知的變數
                        log_message "WARNING" "在設定檔第 $line_num 行發現未知或不處理的變數 '$var_name'，已忽略。"
                        ;;
                esac
            else
                # 記錄格式不符的行
                log_message "WARNING" "設定檔第 $line_num 行格式不符 '$line'，已忽略。"
            fi
        done < "$CONFIG_FILE"

        log_message "INFO" "設定檔載入完成。最終值: THREADS=$THREADS, DOWNLOAD_PATH=$DOWNLOAD_PATH, COLOR_ENABLED=$COLOR_ENABLED, PYTHON_CONVERTER_VERSION=$PYTHON_CONVERTER_VERSION"
        echo -e "${GREEN}已從 $CONFIG_FILE 載入使用者設定。${RESET}"
        sleep 1

    else
        log_message "INFO" "設定檔 $CONFIG_FILE 未找到或不可讀，將使用預設設定。"
        # 如果設定檔不存在，確保所有變數保持其初始預設值
        THREADS="$initial_threads"
        DOWNLOAD_PATH="$initial_dl_path"
        COLOR_ENABLED="$initial_color"
        PYTHON_CONVERTER_VERSION="$initial_py_ver"
         echo -e "${YELLOW}設定檔 $CONFIG_FILE 未找到，使用預設值。${RESET}"
         sleep 1
    fi

    # <<< 重要：在處理完設定檔後，執行路徑和日誌的最終設定與檢查 >>>
    # 無論是從設定檔載入還是使用預設值，都要確保 LOG_FILE 路徑基於最終的 DOWNLOAD_PATH
    # 同時進行下載路徑的有效性檢查和目錄創建

    # 1. 清理並驗證下載路徑 (來自設定檔或預設值)
    local sanitized_path=""
    # 使用 realpath 處理相對路徑、多餘斜線等，並移除危險字符
    sanitized_path=$(realpath -m "$DOWNLOAD_PATH" 2>/dev/null | sed 's/[;|&<>()$`{}]//g')

    if [ -z "$sanitized_path" ]; then
         log_message "ERROR" "最終下載路徑 '$DOWNLOAD_PATH' 無效或解析失敗！腳本無法啟動。"
         echo -e "${RED}錯誤：最終下載路徑 '$DOWNLOAD_PATH' 無效！腳本無法啟動。${RESET}" >&2
         exit 1
    fi
    DOWNLOAD_PATH="$sanitized_path" # 使用清理後的路徑

    # 2. 檢查路徑是否在允許範圍內 (保持原有的安全檢查)
    if ! [[ "$DOWNLOAD_PATH" =~ ^(/storage/emulated/0|$HOME|/data/data/com.termux/files/home) ]]; then
         log_message "SECURITY" "最終下載路徑 '$DOWNLOAD_PATH' 不在允許的安全範圍內！腳本無法啟動。"
         echo -e "${RED}安全性錯誤：最終下載路徑 '$DOWNLOAD_PATH' 不在允許範圍內！腳本無法啟動。${RESET}" >&2
         exit 1
    fi

    # 3. 嘗試創建最終確定的下載目錄並檢查寫入權限
    if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
        log_message "ERROR" "無法創建最終確定的下載目錄 '$DOWNLOAD_PATH'！腳本無法啟動。"
        echo -e "${RED}錯誤：無法創建最終下載目錄 '$DOWNLOAD_PATH'！腳本無法啟動。${RESET}" >&2
        exit 1
    elif [ ! -w "$DOWNLOAD_PATH" ]; then
         log_message "ERROR" "最終下載目錄 '$DOWNLOAD_PATH' 不可寫！腳本無法啟動。"
         echo -e "${RED}錯誤：最終下載目錄 '$DOWNLOAD_PATH' 不可寫！腳本無法啟動。${RESET}" >&2
         exit 1
    fi

    # 4. 設定最終的 LOG_FILE 路徑
    LOG_FILE="$DOWNLOAD_PATH/script_log.txt"

    log_message "INFO" "最終下載路徑確認: $DOWNLOAD_PATH, 日誌檔案: $LOG_FILE"
}

############################################
# <<< 新增：根據 COLOR_ENABLED 應用顏色設定 >>>
############################################
apply_color_settings() {
    # 根據 COLOR_ENABLED 的當前值來設定實際的顏色變數
    if [ "$COLOR_ENABLED" = true ]; then
        # 啟用顏色
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
        BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
        WHITE='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'
        # 可以選擇性地記錄調試信息
        # log_message "DEBUG" "顏色變數已設置為啟用狀態。"
    else
        # 禁用顏色，將變數設為空字串
        RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; BOLD=''; RESET=''
        # log_message "DEBUG" "顏色變數已設置為禁用狀態（空字串）。"
    fi
}

############################################
# 新增：計算並顯示倒數計時
############################################
display_countdown() {
    # 檢查目標日期變數是否存在且不為空
    if [ -z "$TARGET_DATE" ]; then
        # log_message "WARNING" "未設定目標日期 (TARGET_DATE)，無法顯示倒數計時。"
        # echo -e "${YELLOW}警告：未設定目標日期，無法顯示倒數計時。${RESET}" >&2
        return # 如果未設定，則不顯示任何內容
    fi

    local target_timestamp
    local current_timestamp
    local remaining_seconds
    local days hours minutes seconds
    local countdown_message=""

    # 嘗試將目標日期轉換為 Unix 時間戳 (從 Epoch 開始的秒數)
    # 假設目標是該日期的開始 (00:00:00)
    target_timestamp=$(date -d "$TARGET_DATE 00:00:00" +%s 2>/dev/null)

    # 檢查日期轉換是否成功
    if [[ $? -ne 0 || -z "$target_timestamp" ]]; then
        log_message "ERROR" "無法解析目標日期 '$TARGET_DATE'。請使用 YYYY-MM-DD 格式。"
        echo -e "${RED}錯誤：無法解析目標日期 '$TARGET_DATE'！請檢查格式。${RESET}" >&2
        return
    fi

    # 獲取當前時間的 Unix 時間戳
    current_timestamp=$(date +%s)

    # 計算剩餘秒數
    remaining_seconds=$(( target_timestamp - current_timestamp ))

    # 判斷是否已過期
    if [ "$remaining_seconds" -le 0 ]; then
        countdown_message="${RED}目標日期 ($TARGET_DATE) 已到期或已過！${RESET}"
    else
        # 計算天、時、分、秒
        days=$(( remaining_seconds / 86400 ))          # 86400 秒 = 1 天
        hours=$(( (remaining_seconds % 86400) / 3600 )) # 3600 秒 = 1 小時
        minutes=$(( (remaining_seconds % 3600) / 60 ))  # 60 秒 = 1 分鐘
        seconds=$(( remaining_seconds % 60 ))

        # 組合顯示訊息 (使用不同顏色區分)
        countdown_message="${CYAN}距離「分科測驗」（ ${TARGET_DATE} ）尚餘： ${GREEN}${days} ${WHITE}天 ${GREEN}${hours} ${WHITE}時 ${GREEN}${minutes} ${WHITE}分 ${GREEN}${seconds} ${WHITE}秒${RESET}"
    fi

    # 輸出倒數計時訊息
    echo -e "$countdown_message"
}

############################################
# 偵測平台並設定初始變數函數 (新增)
############################################
detect_platform_and_set_vars() {
    echo -e "${CYAN}正在偵測操作系統類型...${RESET}"
    # 初始化平台相關變數為空或預設
    OS_TYPE="unknown"
    DOWNLOAD_PATH_DEFAULT=""
    TEMP_DIR_DEFAULT=""
    PACKAGE_MANAGER="" # 用於存儲包管理器命令 (pkg, apt, dnf, yum)

    # 1. 檢查 Termux (最優先)
    if [[ -n "$TERMUX_VERSION" ]]; then
        OS_TYPE="termux"
        DOWNLOAD_PATH_DEFAULT="/sdcard/Termux/downloads"
        TEMP_DIR_DEFAULT="/data/data/com.termux/files/usr/tmp"
        PACKAGE_MANAGER="pkg"
        echo -e "${GREEN}  > 檢測到 Termux 環境。${RESET}"
        # log_message "INFO" "檢測到 Termux 環境。" # 在 log_message 可用前不能調用

    # 2. 檢查 WSL
    elif [[ "$(uname -r)" == *Microsoft* || "$(uname -r)" == *microsoft* ]]; then
        OS_TYPE="wsl"
        DOWNLOAD_PATH_DEFAULT="$HOME/Downloads_WSL"
        TEMP_DIR_DEFAULT="/tmp" # WSL 使用標準 Linux /tmp
        if command -v apt &> /dev/null; then
            PACKAGE_MANAGER="apt"
        elif command -v dnf &> /dev/null; then
             PACKAGE_MANAGER="dnf"
        elif command -v yum &> /dev/null; then
             PACKAGE_MANAGER="yum"
        else
             echo -e "${YELLOW}  > 警告：在 WSL 中找不到 apt/dnf/yum 套件管理器！依賴更新功能可能受限。${RESET}"
             # log_message "WARNING" "在 WSL 中找不到 apt/dnf/yum 套件管理器。"
        fi
        echo -e "${GREEN}  > 檢測到 Windows (WSL) 環境 (套件管理器: ${PACKAGE_MANAGER:-未找到})。${RESET}"
        # log_message "INFO" "檢測到 Windows (WSL) 環境 (套件管理器: ${PACKAGE_MANAGER:-未找到})。"

    # 3. (可選) 其他 Linux 作為後備
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        OS_TYPE="linux"
        DOWNLOAD_PATH_DEFAULT="$HOME/Downloads"
        TEMP_DIR_DEFAULT="/tmp"
        if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt";
        elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf";
        elif command -v yum &> /dev/null; then PACKAGE_MANAGER="yum"; fi
        echo -e "${GREEN}  > 檢測到 Linux 環境 (套件管理器: ${PACKAGE_MANAGER:-未找到})。${RESET}"
        # log_message "INFO" "檢測到 Linux 環境 (套件管理器: ${PACKAGE_MANAGER:-未找到})。"
    else
        echo -e "${RED}  > 錯誤：無法識別的操作系統類型！腳本可能無法正常工作。${RESET}"
        # log_message "ERROR" "無法識別的操作系統類型。"
    fi

    if [[ "$OS_TYPE" == "unknown" ]]; then
         echo -e "${RED}無法確定操作系統，腳本無法繼續。${RESET}"
         exit 1
    fi
     echo -e "${CYAN}平台檢測完成。${RESET}"
     sleep 1 # 短暫顯示檢測結果
}

############################################
# 腳本自我更新函數 (手動觸發)
# MODIFIED: Added Checksum Verification (v2 - Simplified expected checksum reading)
############################################
auto_update_script() {
    # 與其他選單選項行為一致
    clear
    echo -e "${CYAN}--- 開始檢查腳本更新 ---${RESET}"
    log_message "INFO" "使用者觸發檢查腳本更新。"
    
    local local_version="$SCRIPT_VERSION"
    local remote_version=""
    local remote_version_raw="" # 用於儲存原始下載內容
    local remote_version_file="$TEMP_DIR/remote_version.txt"
    local temp_script="$TEMP_DIR/media_processor_new.sh"
    
    # --- 新增：定義校驗和相關變數 ---
    local temp_checksum_file="$TEMP_DIR/media_processor_new.sh.sha256"
    # 假設校驗和檔案與腳本檔案在同一目錄下，名稱為腳本檔名加上 .sha256
    local remote_checksum_url="${REMOTE_SCRIPT_URL}.sha256"

    # --- 1. 獲取遠程版本號 ---
    echo -e "${YELLOW}正在從 $REMOTE_VERSION_URL 獲取最新版本號...${RESET}"
    if curl -Ls "$REMOTE_VERSION_URL" -o "$remote_version_file" --fail --connect-timeout 5; then
        remote_version_raw=$(tr -d '\r\n' < "$remote_version_file")
        # 移除 UTF-8 BOM (如果有的話)
        remote_version=${remote_version_raw/#$'\xEF\xBB\xBF'/}

        if [ -z "$remote_version" ]; then
             log_message "ERROR" "無法從遠程文件讀取有效的版本號。"
             echo -e "${RED}錯誤：無法讀取遠程版本號。${RESET}"
             rm -f "$remote_version_file"
             return 1
        fi
        log_message "INFO" "獲取的遠程版本號：$remote_version"
        rm -f "$remote_version_file"
    else
        log_message "ERROR" "無法下載版本文件：$REMOTE_VERSION_URL (Curl failed with code $?)"
        echo -e "${RED}錯誤：無法下載版本文件，請檢查網路連線或 URL。${RESET}"
        return 1
    fi

    # --- 2. 比較版本號 ---
    local local_version_clean
    local remote_version_clean
    local_version_clean=${local_version//\(*\)/}
    remote_version_clean=${remote_version//\(*\)/}
    
    latest_version=$(printf '%s\n%s\n' "$remote_version_clean" "$local_version_clean" | sort -V | tail -n 1)

    # 使用字串比較和 sort -V 聯合判斷
    if [[ "$local_version_clean" == "$remote_version_clean" ]] || [[ "$local_version_clean" == "$latest_version" && "$local_version_clean" != "$remote_version_clean" ]]; then
        log_message "INFO" "腳本已是最新版本 ($local_version)。"
        echo -e "${GREEN}腳本已是最新版本 ($local_version)。${RESET}"
        return 0
    fi

    # --- 3. 確認更新 ---
    echo -e "${YELLOW}發現新版本：$remote_version (當前版本：$local_version)。${RESET}"
    read -r -p "是否要立即下載並更新腳本？ (y/n): " confirm_update
    if [[ ! "$confirm_update" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消更新。"
        echo -e "${YELLOW}已取消更新。${RESET}"
        return 0
    fi

    # --- 4. 下載新腳本 ---
    echo -e "${YELLOW}正在從 $REMOTE_SCRIPT_URL 下載新版本腳本...${RESET}"
    if curl -Ls "$REMOTE_SCRIPT_URL" -o "$temp_script" --fail --connect-timeout 30; then
        log_message "INFO" "新版本腳本下載成功：$temp_script"

        # --- 4.1 新增：下載校驗和檔案 ---
        echo -e "${YELLOW}正在從 $remote_checksum_url 下載校驗和檔案...${RESET}"
        if ! curl -Ls "$remote_checksum_url" -o "$temp_checksum_file" --fail --connect-timeout 5; then
            log_message "ERROR" "下載校驗和檔案失敗：$remote_checksum_url (Curl failed with code $?)"
            echo -e "${RED}錯誤：下載校驗和檔案失敗，請檢查網路連線或 URL。取消更新。${RESET}"
            # 清理已下載的腳本檔案
            rm -f "$temp_script"
            return 1
        fi
        log_message "INFO" "校驗和檔案下載成功：$temp_checksum_file"

        # --- 4.2 新增：校驗和驗證 ---
        echo -e "${YELLOW}正在驗證檔案完整性...${RESET}"
        # 計算本地下載腳本的 SHA256 校驗和
        local calculated_checksum
        local expected_checksum
        calculated_checksum=$(sha256sum "$temp_script" | awk '{print $1}')
        # 讀取從伺服器下載的預期校驗和
        expected_checksum=$(cat "$temp_checksum_file")

        # 比較校驗和
        if [[ "$calculated_checksum" == "$expected_checksum" ]]; then
            echo -e "${GREEN}校驗和驗證通過。檔案完整且未被篡改。${RESET}"
            log_message "SUCCESS" "校驗和驗證通過 (SHA256: $calculated_checksum)"
            # 驗證通過後，刪除臨時校驗和檔案
            rm -f "$temp_checksum_file"

            # --- 5. 替換舊腳本 (校驗和驗證通過後才執行) ---
            echo -e "${YELLOW}正在替換舊腳本：$SCRIPT_INSTALL_PATH ${RESET}"
            # 賦予新腳本執行權限
            chmod +x "$temp_script"
            # 確保目標目錄存在
            mkdir -p "$(dirname "$SCRIPT_INSTALL_PATH")"

            # 嘗試移動替換
            if mv "$temp_script" "$SCRIPT_INSTALL_PATH"; then
                log_message "SUCCESS" "腳本已成功更新至版本 $remote_version。"
                echo -e "${GREEN}腳本更新成功！版本：$remote_version ${RESET}"
                echo -e "${CYAN}請重新啟動腳本 ('media' 或執行 '$SCRIPT_INSTALL_PATH') 以載入新版本。${RESET}"
                # 成功更新後退出腳本，強制使用者重新啟動
                exit 0
            else
                log_message "ERROR" "無法替換舊腳本 '$SCRIPT_INSTALL_PATH'。請檢查權限。"
                echo -e "${RED}錯誤：無法替換舊腳本。請檢查權限。${RESET}"
                echo -e "${YELLOW}下載的新腳本保留在：$temp_script ${RESET}" # 提示使用者手動替換
                # 不刪除 temp_script，方便手動處理
                return 1 # 返回到主選單，但提示錯誤
            fi

        else # 校驗和驗證失敗
            log_message "ERROR" "校驗和驗證失敗！下載的檔案可能已損壞或被篡改。"
            log_message "ERROR" "預期校驗和 (來自伺服器): $expected_checksum"
            log_message "ERROR" "計算出的校驗和 (本地下載): $calculated_checksum"
            echo -e "${RED}錯誤：校驗和驗證失敗！下載的檔案可能已損壞或被篡改。取消更新。${RESET}"
            # 清理下載的腳本檔案和校驗和檔案
            rm -f "$temp_script" "$temp_checksum_file"
            return 1 # 返回到主選單
        fi
    else # 下載新腳本失敗
        log_message "ERROR" "下載新腳本失敗：$REMOTE_SCRIPT_URL (Curl failed with code $?)"
        echo -e "${RED}錯誤：下載新腳本失敗。${RESET}"
        return 1
    fi
}

############################################
# <<< 新增：Python 轉換器更新函數 >>>
############################################
update_python_converter() {
    echo -e "${CYAN}--- 開始檢查 Python 字幕轉換器更新 ---${RESET}"
    log_message "INFO" "開始檢查 Python 轉換器更新。"
    
    local local_py_version="$PYTHON_CONVERTER_VERSION" # 使用從設定檔載入或預設的本地版本
    local remote_py_version=""
    local remote_py_version_raw="" 
    local remote_py_version_file="$TEMP_DIR/remote_py_version.txt"
    local temp_py_script="$TEMP_DIR/vtt_to_ass_converter_new.py"
    local temp_py_checksum_file="$TEMP_DIR/vtt_to_ass_converter_new.py.sha256"
    local remote_py_checksum_url="${PYTHON_CONVERTER_REMOTE_URL}.sha256" # 假設校驗和檔名規則

    # --- 1. 獲取遠程版本號 ---
    echo -e "${YELLOW}正在從 $PYTHON_CONVERTER_VERSION_URL 獲取最新版本號...${RESET}"
    if curl -Ls "$PYTHON_CONVERTER_VERSION_URL" -o "$remote_py_version_file" --fail --connect-timeout 5; then
        remote_py_version_raw=$(tr -d '\r\n' < "$remote_py_version_file")
        remote_py_version=${remote_py_version_raw/#$'\xEF\xBB\xBF'/} # 移除 BOM

        if [ -z "$remote_py_version" ]; then
             log_message "ERROR" "無法讀取 Python 轉換器遠程版本號。"
             echo -e "${RED}錯誤：無法讀取 Python 轉換器遠程版本號。${RESET}"
             rm -f "$remote_py_version_file"
             return 1 # 返回失敗，但不退出主腳本
        fi
        log_message "INFO" "獲取的 Python 轉換器遠程版本號：$remote_py_version"
        rm -f "$remote_py_version_file"
    else
        log_message "ERROR" "無法下載 Python 轉換器版本文件：$PYTHON_CONVERTER_VERSION_URL (Curl failed with code $?)"
        echo -e "${RED}錯誤：無法下載 Python 轉換器版本文件。${RESET}"
        return 1 # 返回失敗
    fi

    # --- 2. 比較版本號 ---
    # 使用 sort -V 進行版本比較
    latest_py_version=$(printf '%s\n%s\n' "$remote_py_version" "$local_py_version" | sort -V | tail -n 1)

    if [[ "$local_py_version" == "$remote_py_version" ]] || [[ "$local_py_version" == "$latest_py_version" && "$local_py_version" != "$remote_py_version" ]]; then
        log_message "INFO" "Python 轉換器已是最新版本 ($local_py_version)。"
        echo -e "${GREEN}Python 字幕轉換器已是最新版本 ($local_py_version)。${RESET}"
        return 0 # 返回成功，無需更新
    fi

    # --- 3. 確認更新 (可選，或直接更新) ---
    echo -e "${YELLOW}發現 Python 轉換器新版本：$remote_py_version (當前版本：$local_py_version)。${RESET}"
    # 由於是在依賴更新流程中，可以考慮直接更新，或添加確認
    # read -r -p "是否要立即下載並更新 Python 轉換器？ (y/n): " confirm_py_update
    # if [[ ! "$confirm_py_update" =~ ^[Yy]$ ]]; then
    #     log_message "INFO" "使用者取消 Python 轉換器更新。"
    #     echo -e "${YELLOW}已取消 Python 轉換器更新。${RESET}"
    #     return 0
    # fi

    # --- 4. 下載新腳本 ---
    echo -e "${YELLOW}正在從 $PYTHON_CONVERTER_REMOTE_URL 下載新版本 Python 轉換器...${RESET}"
    if curl -Ls "$PYTHON_CONVERTER_REMOTE_URL" -o "$temp_py_script" --fail --connect-timeout 30; then
        log_message "INFO" "新版本 Python 轉換器下載成功：$temp_py_script"

        # --- 4.1 下載校驗和檔案 ---
        echo -e "${YELLOW}正在從 $remote_py_checksum_url 下載校驗和檔案...${RESET}"
        if ! curl -Ls "$remote_py_checksum_url" -o "$temp_py_checksum_file" --fail --connect-timeout 5; then
            log_message "ERROR" "下載 Python 轉換器校驗和檔案失敗：$remote_py_checksum_url (Curl failed with code $?)"
            echo -e "${RED}錯誤：下載 Python 轉換器校驗和檔案失敗。取消更新。${RESET}"
            rm -f "$temp_py_script"
            return 1
        fi
        log_message "INFO" "Python 轉換器校驗和檔案下載成功：$temp_py_checksum_file"

        # --- 4.2 校驗和驗證 ---
        echo -e "${YELLOW}正在驗證 Python 轉換器檔案完整性...${RESET}"
        local calculated_py_checksum expected_py_checksum
        calculated_py_checksum=$(sha256sum "$temp_py_script" | awk '{print $1}')
        expected_py_checksum=$(cat "$temp_py_checksum_file")

        if [[ "$calculated_py_checksum" == "$expected_py_checksum" ]]; then
            echo -e "${GREEN}Python 轉換器校驗和驗證通過。${RESET}"
            log_message "SUCCESS" "Python 轉換器校驗和驗證通過 (SHA256: $calculated_py_checksum)"
            rm -f "$temp_py_checksum_file"

            # --- 5. 替換舊腳本 ---
            echo -e "${YELLOW}正在替換舊的 Python 轉換器：$PYTHON_CONVERTER_INSTALL_PATH ${RESET}"
            chmod +x "$temp_py_script" # 賦予執行權限 (雖然通常用 python 執行)
            mkdir -p "$(dirname "$PYTHON_CONVERTER_INSTALL_PATH")" # 確保目錄存在

            if mv "$temp_py_script" "$PYTHON_CONVERTER_INSTALL_PATH"; then
                log_message "SUCCESS" "Python 轉換器已成功更新至版本 $remote_py_version。"
                echo -e "${GREEN}Python 轉換器更新成功！版本：$remote_py_version ${RESET}"
                # <<< 更新 Bash 中的版本變數並儲存設定檔 >>>
                PYTHON_CONVERTER_VERSION="$remote_py_version" 
                save_config 
                return 0 # 更新成功
            else
                log_message "ERROR" "無法替換舊的 Python 轉換器 '$PYTHON_CONVERTER_INSTALL_PATH'。請檢查權限。"
                echo -e "${RED}錯誤：無法替換舊的 Python 轉換器。請檢查權限。${RESET}"
                echo -e "${YELLOW}下載的新轉換器保留在：$temp_py_script ${RESET}" 
                return 1 # 更新失敗
            fi

        else # 校驗和驗證失敗
            log_message "ERROR" "Python 轉換器校驗和驗證失敗！"
            log_message "ERROR" "預期校驗和: $expected_py_checksum"
            log_message "ERROR" "計算出的校驗和: $calculated_py_checksum"
            echo -e "${RED}錯誤：Python 轉換器校驗和驗證失敗！取消更新。${RESET}"
            rm -f "$temp_py_script" "$temp_py_checksum_file"
            return 1 # 更新失敗
        fi
    else # 下載新腳本失敗
        log_message "ERROR" "下載新 Python 轉換器失敗：$PYTHON_CONVERTER_REMOTE_URL (Curl failed with code $?)"
        echo -e "${RED}錯誤：下載新 Python 轉換器失敗。${RESET}"
        return 1
    fi
}

# 高解析度封面圖片下載函數（僅用於 YouTube 下載）
download_high_res_thumbnail() {
    # --- 函數邏輯不變 ---
    local media_url="$1"
    local output_image="$2"
    echo -e "${YELLOW}正在取得影片 ID...${RESET}"
    video_id=$(yt-dlp --get-id "$media_url" 2>/dev/null)
    if [ -z "$video_id" ]; then
        log_message "WARNING" "無法取得影片 ID，將跳過封面圖片下載。"
        return 1
    fi
    echo -e "${YELLOW}搜尋最佳解析度縮略圖...${RESET}"
    local thumbnail_sizes=("maxresdefault" "sddefault" "hqdefault" "mqdefault" "default")
    for size in "${thumbnail_sizes[@]}"; do
        echo -e "${YELLOW}嘗試下載 $size 解析度縮略圖...${RESET}"
        local thumbnail_url="https://i.ytimg.com/vi/${video_id}/${size}.jpg"
        local http_status
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "$thumbnail_url")
        if [ "$http_status" -eq 200 ]; then
            echo -e "${YELLOW}正在下載縮略圖 ($size)...${RESET}"
            if curl -s "$thumbnail_url" -o "$output_image"; then
                log_message "INFO" "下載封面圖片成功：$thumbnail_url"
                echo -e "${GREEN}封面圖片下載完成！${RESET}"
                return 0
            else
                log_message "WARNING" "下載圖片失敗：$thumbnail_url"
            fi
        fi
    done
    log_message "WARNING" "無法下載封面圖片。"
    echo -e "${RED}封面圖片下載失敗！${RESET}"
    return 1
}

# 安全刪除函數
safe_remove() {
    for file in "$@"; do
        if [ -f "$file" ]; then
            echo -e "${YELLOW}清理臨時檔案：$file${RESET}"
            if rm -f "$file"; then
                log_message "INFO" "已安全刪除：$file"
            else
                log_message "WARNING" "無法刪除：$file"
            fi
        fi
    done
}

############################################
# <<< 修改：檢查並更新依賴套件 (修正驗證邏輯) >>>
############################################
update_dependencies() {
    # --- 工具列表定義 (保持不變) ---
    # 包含需要用包管理器安裝的 *包名*
    local pkg_tools=("ffmpeg" "jq" "curl" "python" "mkvtoolnix")
    # 包含需要用 pip 安裝的 *包名*
    local pip_tools=("yt-dlp")
    # --- 結束工具列表定義 ---

    # 用於記錄更新過程中的問題
    local update_failed=false
    # 用於記錄最終驗證後仍然缺少的 *命令*
    local missing_after_update=()

    clear
    echo -e "${CYAN}--- 開始檢查並更新依賴套件 ---${RESET}"
    log_message "INFO" "使用者觸發依賴套件更新流程。"

    # --- 步驟 1: 更新包管理器列表 (保持不變) ---
    echo -e "${YELLOW}[1/5] 正在更新套件列表 (${PACKAGE_MANAGER} update)...${RESET}"
    # 使用檢測到的包管理器
    local update_cmd=""
    if [[ "$PACKAGE_MANAGER" == "pkg" ]]; then
        update_cmd="pkg update -y"
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        update_cmd="sudo apt update -y"
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        update_cmd="sudo dnf check-update" # dnf 通常不需要 -y
    elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
        update_cmd="sudo yum check-update"
    else
         echo -e "${RED}  > 錯誤：未知的包管理器 '$PACKAGE_MANAGER'，無法更新列表。${RESET}"
         log_message "ERROR" "未知包管理器 '$PACKAGE_MANAGER'，跳過列表更新。"
         update_failed=true # 標記為失敗，因為無法更新
         # 即使無法更新列表，也繼續嘗試安裝
    fi

    if [[ -n "$update_cmd" ]]; then
        if $update_cmd; then
            log_message "INFO" "$PACKAGE_MANAGER list update succeeded"
            echo -e "${GREEN}  > 套件列表更新成功。${RESET}"
        else
            log_message "WARNING" "$PACKAGE_MANAGER list update failed (exit code $?), proceeding anyway."
            echo -e "${RED}  > 警告：套件列表更新失敗，將嘗試使用現有列表。${RESET}"
            # 不標記為 update_failed=true，因為可能只是沒有更新但包已存在
        fi
    fi
    echo "" # 空行分隔

    # --- 步驟 2: 安裝/更新 包管理器管理的工具 (保持不變) ---
    echo -e "${YELLOW}[2/5] 正在安裝/更新 ${PACKAGE_MANAGER} 套件: ${pkg_tools[*]}...${RESET}"
    local install_cmd=""
    if [[ "$PACKAGE_MANAGER" == "pkg" ]]; then
        install_cmd="pkg install -y ${pkg_tools[*]}"
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_cmd="sudo apt install -y ${pkg_tools[*]}"
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_cmd="sudo dnf install -y ${pkg_tools[*]}"
    elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
         install_cmd="sudo yum install -y ${pkg_tools[*]}"
    else
        echo -e "${RED}  > 錯誤：未知的包管理器 '$PACKAGE_MANAGER'，無法安裝套件。${RESET}"
        log_message "ERROR" "未知包管理器 '$PACKAGE_MANAGER'，跳過套件安裝。"
        update_failed=true # 標記為失敗
    fi

    if [[ -n "$install_cmd" ]]; then
         if $install_cmd; then
             log_message "INFO" "Installation/update of ${pkg_tools[*]} via $PACKAGE_MANAGER successful or already up-to-date."
             echo -e "${GREEN}  > 安裝/更新 ${pkg_tools[*]} 完成。${RESET}"
         else
             log_message "ERROR" "Installation/update of ${pkg_tools[*]} via $PACKAGE_MANAGER failed!"
             echo -e "${RED}  > 錯誤：安裝/更新 ${pkg_tools[*]} 失敗！${RESET}"
             update_failed=true
         fi
    fi
    echo ""

    # --- 步驟 3: 更新 pip 管理的工具 (保持不變) ---
    echo -e "${YELLOW}[3/5] 正在更新 pip 套件: ${pip_tools[*]}...${RESET}"
    local python_cmd=""
    if command -v python3 &> /dev/null; then python_cmd="python3";
    elif command -v python &> /dev/null; then python_cmd="python"; fi

    if [[ -n "$python_cmd" ]]; then
         # 使用 --user 可能在某些系統上避免權限問題，但需確保 $HOME/.local/bin 在 PATH 中
         # 或者直接全局安裝 (需要 root/sudo 或在 venv 中)
         # 這裡保留原來的全局升級方式
         if $python_cmd -m pip install --upgrade "${pip_tools[@]}"; then
             log_message "INFO" "Update of ${pip_tools[*]} via pip succeeded."
             echo -e "${GREEN}  > 更新 ${pip_tools[*]} 完成。${RESET}"
         else
             log_message "ERROR" "Update of ${pip_tools[*]} via pip failed!"
             echo -e "${RED}  > 錯誤：更新 ${pip_tools[*]} 失敗！${RESET}"
             update_failed=true
         fi
    else
        log_message "ERROR" "Python command not found, cannot update pip packages: ${pip_tools[*]}."
        echo -e "${RED}  > 錯誤：找不到 python/python3 命令，無法更新 ${pip_tools[*]}。請確保步驟 2 已成功安裝 python。${RESET}"
        update_failed=true
    fi
    echo ""

    # --- 步驟 4: 更新 Python 字幕轉換器 (保持不變) ---
    echo -e "${YELLOW}[4/5] 正在檢查並更新 Python 字幕轉換器...${RESET}"
    if ! update_python_converter; then
        log_message "WARNING" "Python subtitle converter update failed or was not completed."
        # 不標記為 update_failed=true
    fi
    echo ""

    # --- 步驟 5: 最終驗證所有工具 (核心修改處) ---
    echo -e "${YELLOW}[5/5] 正在驗證所有必要工具是否已安裝...${RESET}"
    # <<< 保持 all_tools 的原始構建邏輯 >>>
    #    它會包含 pkg_tools 中的 *包名* 和 pip_tools 中的 *包名*，再加上 ffprobe
    local all_tools=("${pkg_tools[@]}" "${pip_tools[@]}" "ffprobe")

    # <<< 修改驗證循環 >>>
    for tool_in_list in "${all_tools[@]}"; do
        local command_to_check="" # 要實際檢查的命令

        # --- 在這裡處理特殊情況：包名和命令名不一致 ---
        if [[ "$tool_in_list" == "mkvtoolnix" ]]; then
            command_to_check="mkvmerge" # 如果列表項是 mkvtoolnix(包名)，我們實際檢查 mkvmerge(命令名)
        # --- 如果有其他特殊情況，可以在這裡加 elif ---
        # elif [[ "$tool_in_list" == "some-package" ]]; then
        #     command_to_check="some-command"
        else
            # 默認情況：假設列表中的名稱就是要檢查的命令名
            command_to_check="$tool_in_list"
        fi
        # --- 特殊情況處理結束 ---

        # 使用 command -v 檢查實際的命令是否存在
        if ! command -v "$command_to_check" &> /dev/null; then
            # 如果命令不存在，將 *列表中的原始名稱* (更符合用戶預期) 加入缺少列表
            missing_after_update+=("$tool_in_list")
            echo -e "${RED}  > 驗證失敗：找不到 $command_to_check (來自 $tool_in_list)${RESET}"
            # 或者更簡潔的報告：
            # echo -e "${RED}  > 驗證失敗：找不到 $command_to_check ${RESET}"
        else
            # 如果命令存在，報告成功
            echo -e "${GREEN}  > 驗證成功：找到 $command_to_check (來自 $tool_in_list)${RESET}"
            # 或者更簡潔的報告：
            # echo -e "${GREEN}  > 驗證成功：找到 $command_to_check ${RESET}"
        fi
    done
    echo ""

    # --- 總結結果 (保持不變) ---
    if [ ${#missing_after_update[@]} -ne 0 ]; then
        log_message "ERROR" "Update process completed, but still missing tools: ${missing_after_update[*]}"
        echo -e "${RED}--- 更新結果：失敗 ---${RESET}"
        echo -e "${RED}更新/安裝後，仍然缺少以下必要工具或其對應命令：${RESET}"
        for tool in "${missing_after_update[@]}"; do
            # 顯示列表中的原始名稱
            echo -e "${YELLOW}  - $tool${RESET}"
        done
        echo -e "${CYAN}請檢查網路連線或嘗試手動安裝。${RESET}"
    elif [ "$update_failed" = true ]; then
        log_message "WARNING" "Update process completed with some errors during the process. Tools seem to exist now, but might not be the latest version."
        echo -e "${YELLOW}--- 更新結果：部分成功 ---${RESET}"
        echo -e "${YELLOW}更新過程中出現一些錯誤，但所有必要工具似乎都已安裝。${RESET}"
        echo -e "${YELLOW}可能部分工具未能更新到最新版本。${RESET}"
    else
        log_message "SUCCESS" "All dependencies checked and successfully updated/installed."
        echo -e "${GREEN}--- 更新結果：成功 ---${RESET}"
        echo -e "${GREEN}所有依賴套件均已成功檢查並更新/安裝。${RESET}"
    fi

    # 等待使用者按 Enter 返回
    echo ""
    read -p "按 Enter 返回主選單..."
}

############################################
# 音量標準化共用函數 (無圖形進度條)
############################################
normalize_audio() {
    # --- 函數邏輯不變 ---
    local input_file="$1"
    local output_file="$2"
    local temp_dir="$3"
    local is_video="$4"
    local audio_wav="$temp_dir/audio_temp.wav"
    local normalized_wav="$temp_dir/normalized_audio.wav"
    local loudnorm_log="$temp_dir/loudnorm.log"
    local stats_json="$temp_dir/stats.json"
    local ffmpeg_status=0

    echo -e "${YELLOW}正在提取音訊為 WAV 格式...${RESET}"
    ffmpeg -y -i "$input_file" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$audio_wav" > /dev/null 2>&1
    local ffmpeg_exit_code=$?
    if [ $ffmpeg_exit_code -ne 0 ] || [ ! -f "$audio_wav" ]; then
        log_message "ERROR" "轉換為 WAV 失敗！ (ffmpeg exit code: $ffmpeg_exit_code)"
        echo -e "${RED}錯誤：無法轉換為 WAV 格式${RESET}"
        return 1
    fi
    echo -e "${GREEN}轉換為 WAV 格式完成${RESET}"

    echo -e "${YELLOW}正在執行第一遍音量分析...${RESET}"
    ffmpeg -y -i "$audio_wav" -af loudnorm=I=-12:TP=-1.5:LRA=11:print_format=json -f null - 2> "$loudnorm_log"
    if [ $? -ne 0 ]; then
        log_message "ERROR" "第一遍音量分析失敗！"
        echo -e "${RED}錯誤：音量分析失敗${RESET}"
        safe_remove "$audio_wav"
        return 1
    fi
    echo -e "${GREEN}第一遍音量分析完成${RESET}"

    echo -e "${YELLOW}解析音量分析結果...${RESET}"
    awk '/^\{/{flag=1}/^\}/{print;flag=0}flag' "$loudnorm_log" > "$stats_json"
    local measured_I=$(jq -r '.input_i' "$stats_json")
    local measured_TP=$(jq -r '.input_tp' "$stats_json")
    local measured_LRA=$(jq -r '.input_lra' "$stats_json")
    local measured_thresh=$(jq -r '.input_thresh' "$stats_json")
    local offset=$(jq -r '.target_offset' "$stats_json")

    if [ -z "$measured_I" ] || [ -z "$measured_TP" ] || [ -z "$measured_LRA" ] || [ -z "$measured_thresh" ] || [ -z "$offset" ]; then
        log_message "ERROR" "音量分析參數提取失敗"
        echo -e "${RED}錯誤：音量分析參數提取失敗${RESET}"
        safe_remove "$audio_wav" "$loudnorm_log" "$stats_json"
        return 1
    fi
    echo -e "${YELLOW}正在執行第二遍音量標準化 (此步驟可能需要一些時間)...${RESET}"
    ffmpeg -y -i "$audio_wav" \
        -af "loudnorm=I=-12:TP=-1.5:LRA=11:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset:linear=true:print_format=summary" \
        -c:a pcm_s16le "$normalized_wav" > /dev/null 2>&1
    ffmpeg_status=$?

    if [ "$ffmpeg_status" -ne 0 ] || [ ! -f "$normalized_wav" ]; then
        log_message "ERROR" "第二遍音量標準化失敗！ (ffmpeg exit code: $ffmpeg_status, file exists: $([ -f "$normalized_wav" ] && echo true || echo false))"
        echo -e "${RED}錯誤：音量標準化失敗${RESET}"
        safe_remove "$audio_wav" "$normalized_wav" "$loudnorm_log" "$stats_json"
        return 1
    fi
    echo -e "${GREEN}第二遍音量標準化完成${RESET}"

    if [ "$is_video" = true ]; then
        echo -e "${YELLOW}正在轉換音訊為 AAC 格式...${RESET}"
        local normalized_audio_aac="$temp_dir/audio_normalized.m4a"
        ffmpeg -y -i "$normalized_wav" -c:a aac -b:a 256k -ar 44100 "$normalized_audio_aac" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_message "ERROR" "轉換為 AAC 失敗！"
            echo -e "${RED}錯誤：轉換為 AAC 失敗${RESET}"
            safe_remove "$audio_wav" "$normalized_wav" "$loudnorm_log" "$stats_json"
            return 1
        fi
        echo -e "${GREEN}AAC 轉換完成${RESET}"
        mv "$normalized_audio_aac" "$output_file"
    else
        echo -e "${YELLOW}正在轉換為 MP3 格式...${RESET}"
        ffmpeg -y -i "$normalized_wav" -c:a libmp3lame -b:a 320k "$output_file" > /dev/null 2>&1
        if [ $? -ne 0 ] || [ ! -f "$output_file" ]; then
             log_message "ERROR" "轉換為 MP3 失敗！"
             echo -e "${RED}錯誤：MP3 轉換失敗${RESET}"
             safe_remove "$audio_wav" "$normalized_wav" "$loudnorm_log" "$stats_json"
             return 1
        fi
        echo -e "${GREEN}MP3 轉換完成${RESET}"
    fi

    safe_remove "$audio_wav" "$normalized_wav" "$loudnorm_log" "$stats_json"
    return 0
}

############################################
# 處理本機 MP3 音訊（音量標準化）
############################################
process_local_mp3() {
    local audio_file="$1"
    local temp_dir base_name output_audio result
    
    if [ ! -f "$audio_file" ]; then
        echo -e "${RED}錯誤：檔案不存在！${RESET}"
        return 1
    fi
    
    temp_dir=$(mktemp -d)
    base_name=$(basename "$audio_file" | sed 's/\.[^.]*$//')
    output_audio="$(dirname "$audio_file")/${base_name}_normalized.mp3"

    echo -e "${YELLOW}處理本機音訊檔案：$audio_file${RESET}"
    log_message "INFO" "處理本機音訊檔案：$audio_file"
    
    if normalize_audio "$audio_file" "$output_audio" "$temp_dir" false; then
        echo -e "${GREEN}處理完成！音量標準化後的高品質音訊已儲存至：$output_audio${RESET}"
        log_message "SUCCESS" "處理完成！音量標準化後的高品質音訊已儲存至：$output_audio"
        result=0
    else
        echo -e "${RED}處理失敗！${RESET}"
        log_message "ERROR" "處理失敗：$audio_file"
        result=1
    fi

    [ -d "$temp_dir" ] && rmdir "$temp_dir" 2>/dev/null
    return $result
}

############################################
# 處理本機 MP4 影片（音量標準化）
############################################
process_local_mp4() {
    # --- 函數邏輯不變 ---
    local video_file="$1"
    if [ ! -f "$video_file" ]; then echo -e "${RED}錯誤：檔案不存在！${RESET}"; return 1; fi
    local temp_dir=$(mktemp -d)
    local base=$(basename "$video_file" | sed 's/\.[^.]*$//')
    local output_video="$(dirname "$video_file")/${base}_normalized.mp4"
    local normalized_audio="$temp_dir/audio_normalized.m4a"
    echo -e "${YELLOW}處理本機影片檔案：$video_file${RESET}"
    log_message "INFO" "處理本機影片檔案：$video_file"
    normalize_audio "$video_file" "$normalized_audio" "$temp_dir" true
    local result=$?
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}正在混流標準化音訊與影片...${RESET}"
        ffmpeg -y -i "$video_file" -i "$normalized_audio" -c:v copy -c:a aac -b:a 256k -ar 44100 -map 0:v:0 -map 1:a:0 -movflags +faststart "$output_video" > /dev/null 2>&1
        if [ $? -ne 0 ]; then echo -e "${RED}錯誤：混流失敗！${RESET}"; result=1;
        else echo -e "${GREEN}混流完成${RESET}"; fi
    fi
    safe_remove "$normalized_audio"
    [ -d "$temp_dir" ] && rmdir "$temp_dir" 2>/dev/null
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}處理完成！音量標準化後的影片已儲存至：$output_video${RESET}"
        log_message "SUCCESS" "處理完成！音量標準化後的影片已儲存至：$output_video"
    else
        echo -e "${RED}處理失敗！${RESET}"
        log_message "ERROR" "處理失敗：$video_file"
    fi
    return $result
}

############################################
# 處理單一 YouTube 音訊（MP3）下載與處理
# <<< 修改：基於時長條件式通知 v2.4.12+ >>>
############################################
process_single_mp3() {
    local media_url="$1"
    local mode="$2" # 接收模式參數
    local temp_dir=$(mktemp -d)
    local audio_file=""
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local base_name=""
    local result=0
    local should_notify=false
    local is_playlist=false
    local output_audio="" # 初始化最終輸出路徑

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        should_notify=true
        log_message "INFO" "MP3 標準化：播放清單模式，啟用通知。"
    fi

    # --- 獲取資訊 ---
    local video_title video_id sanitized_title
    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    video_title=$(yt-dlp --get-title "$media_url" 2>/dev/null) || video_title="audio"
    video_id=$(yt-dlp --get-id "$media_url" 2>/dev/null)
    if [ -z "$video_title" ]; then
        log_message "ERROR" "無法獲取媒體標題 (標準化 MP3)"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1; goto cleanup_and_notify
    fi
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- <<< 修改：基於時長判斷是否通知 (僅單獨模式) >>> ---
    if ! $is_playlist; then
        echo -e "${YELLOW}正在獲取媒體時長以決定是否通知...${RESET}"
        local duration_secs_str duration_exit_code
        duration_secs_str=$(yt-dlp --no-warnings --print '%(duration)s' "$media_url" 2>"$temp_dir/yt-dlp-duration.log")
        duration_exit_code=$?
        log_message "DEBUG" "yt-dlp duration print exit code (MP3 std): $duration_exit_code"
        log_message "DEBUG" "yt-dlp duration print raw output (MP3 std): [$duration_secs_str]"

        local duration_secs=0
        if [ "$duration_exit_code" -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            duration_secs=$(printf "%.0f" "$duration_secs_str") # 轉換為整數秒
        else
            log_message "WARNING" "無法從 yt-dlp 獲取有效的時長資訊 (MP3 std)。"
        fi

        # 設定閾值：> 0.5 小時 (1800 秒)
        local duration_threshold_secs=1800
        log_message "INFO" "MP3 標準化：媒體時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (0.5小時)."
        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "MP3 標準化：媒體時長超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP3 標準化：媒體時長未超過閾值，禁用通知。"
            should_notify=false
        fi
    fi
    # --- 時長判斷結束 ---

    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH"; echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"; result=1; goto cleanup_and_notify; fi

    echo -e "${YELLOW}處理 YouTube 媒體 (MP3 標準化)：$media_url${RESET}"
    log_message "INFO" "處理 YouTube 媒體 (MP3 標準化)：$media_url"

    # --- 下載 ---
    echo -e "${YELLOW}開始下載：$video_title${RESET}"
    local output_template="$DOWNLOAD_PATH/${sanitized_title} [${video_id:-unknown_id}].%(ext)s"
    local yt_dlp_dl_args=(yt-dlp -f bestaudio -o "$output_template" "$media_url" --newline --progress --concurrent-fragments "$THREADS")
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-mp3-std.log"; then
        log_message "ERROR" "音訊下載失敗 (標準化)，詳見 $temp_dir/yt-dlp-mp3-std.log"
        echo -e "${RED}錯誤：音訊下載失敗${RESET}"; cat "$temp_dir/yt-dlp-mp3-std.log";
        result=1; goto cleanup_and_notify
    fi
    local yt_dlp_fn_args=(yt-dlp --get-filename -f bestaudio -o "$output_template" "$media_url")
    audio_file=$("${yt_dlp_fn_args[@]}")
    if [ ! -f "$audio_file" ]; then
        log_message "ERROR" "音訊下載失敗！找不到檔案 '$audio_file'"
        echo -e "${RED}錯誤：找不到下載的檔案${RESET}";
        result=1; goto cleanup_and_notify
    fi
    base_name=$(basename "$audio_file" | sed 's/\.[^.]*$//')

    # --- 元數據和封面 ---
    # ... (獲取元數據和下載封面的邏輯不變) ...
    local metadata_json=$(yt-dlp --dump-json "$media_url" 2>/dev/null)
    if [ -n "$metadata_json" ]; then artist_name=$(echo "$metadata_json" | jq -r '.artist // .uploader // "[不明]"'); album_artist_name=$(echo "$metadata_json" | jq -r '.uploader // "[不明]"'); fi
    [[ "$artist_name" == "null" ]] && artist_name="[不明]"
    [[ "$album_artist_name" == "null" ]] && album_artist_name="[不明]"
    local cover_image="$temp_dir/cover_${base_name}.png"
    echo -e "${YELLOW}下載封面圖片...${RESET}"
    if ! download_high_res_thumbnail "$media_url" "$cover_image"; then cover_image=""; fi


    # --- 音量標準化與最終處理 ---
    output_audio="$DOWNLOAD_PATH/${base_name}_normalized.mp3" # 確保路徑正確
    local normalized_temp="$temp_dir/temp_normalized.mp3"
    echo -e "${YELLOW}開始音量標準化...${RESET}"
    if normalize_audio "$audio_file" "$normalized_temp" "$temp_dir" false; then
        echo -e "${YELLOW}正在加入封面和元數據...${RESET}"
        local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_temp")
        if [ -n "$cover_image" ] && [ -f "$cover_image" ]; then
            ffmpeg_embed_args+=(-i "$cover_image" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic)
        else
            ffmpeg_embed_args+=(-c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name")
        fi
        ffmpeg_embed_args+=("$output_audio")
        if ! "${ffmpeg_embed_args[@]}" > /dev/null 2>&1; then
            log_message "ERROR" "加入封面和元數據失敗！"; echo -e "${RED}錯誤：加入封面和元數據失敗${RESET}";
            result=1;
        else
            echo -e "${GREEN}封面和元數據加入完成${RESET}";
            result=0;
            safe_remove "$normalized_temp"
        fi
    else
        log_message "ERROR" "音量標準化失敗！";
        result=1;
    fi

: cleanup_and_notify

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (MP3 標準化)..."
    [ -f "$audio_file" ] && safe_remove "$audio_file"
    [ -n "$cover_image" ] && [ -f "$cover_image" ] && safe_remove "$cover_image"
    safe_remove "$temp_dir/yt-dlp-mp3-std.log" "$temp_dir/yt-dlp-duration.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_audio" ]; then # 增加檢查最終檔案
            echo -e "${GREEN}處理完成！音量標準化後的高品質音訊已儲存至：$output_audio${RESET}"
            log_message "SUCCESS" "處理完成 (MP3 標準化)！音訊已儲存至：$output_audio"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_audio' 未找到！${RESET}";
            log_message "ERROR" "處理完成但最終檔案未找到 (MP3 標準化)";
            result=1 # 標記失敗
        fi
    else
        echo -e "${RED}處理失敗 (MP3 標準化)！${RESET}"
        log_message "ERROR" "處理失敗 (MP3 標準化)：$media_url"
    fi

    # --- 條件式通知 ---
    if $should_notify; then
        local notification_title="媒體處理器：MP3 標準化"
        local base_msg_notify="處理音訊 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_audio" ]; then final_path_notify="$output_audio"; fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

#########################################################
# 處理單一 YouTube 音訊（MP3）下載（無音量標準化）
# <<< 修改：基於時長條件式通知 v2.4.12+ >>>
#########################################################
process_single_mp3_no_normalize() {
    local media_url="$1"
    local mode="$2" # 接收模式參數
    local temp_dir=$(mktemp -d)
    local audio_file_raw=""
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local base_name=""
    local result=0
    local should_notify=false
    local is_playlist=false
    local output_audio=""

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        should_notify=true
        log_message "INFO" "MP3 無標準化：播放清單模式，啟用通知。"
    fi

    # --- 獲取資訊 ---
    local video_title video_id sanitized_title
    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    video_title=$(yt-dlp --get-title "$media_url" 2>/dev/null) || video_title="audio"
    video_id=$(yt-dlp --get-id "$media_url" 2>/dev/null)
    if [ -z "$video_title" ]; then
        log_message "ERROR" "無法獲取媒體標題 (無標準化 MP3)"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1; goto cleanup_and_notify
    fi
    base_name=$(echo "${video_title} [${video_id:-unknown_id}]" | sed 's@[/\\:*?"<>|]@_@g')
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- <<< 修改：基於時長判斷是否通知 (僅單獨模式) >>> ---
    if ! $is_playlist; then
        echo -e "${YELLOW}正在獲取媒體時長以決定是否通知...${RESET}"
        local duration_secs_str duration_exit_code
        duration_secs_str=$(yt-dlp --no-warnings --print '%(duration)s' "$media_url" 2>"$temp_dir/yt-dlp-duration.log")
        duration_exit_code=$?
        log_message "DEBUG" "yt-dlp duration print exit code (MP3 non-std): $duration_exit_code"
        log_message "DEBUG" "yt-dlp duration print raw output (MP3 non-std): [$duration_secs_str]"

        local duration_secs=0
        if [ "$duration_exit_code" -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            duration_secs=$(printf "%.0f" "$duration_secs_str")
        else
            log_message "WARNING" "無法從 yt-dlp 獲取有效的時長資訊 (MP3 non-std)。"
        fi

        # 設定閾值：> 2 小時 (7200 秒)
        local duration_threshold_secs=7200
        log_message "INFO" "MP3 無標準化：媒體時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (2小時)."
        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "MP3 無標準化：媒體時長超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP3 無標準化：媒體時長未超過閾值，禁用通知。"
            should_notify=false
        fi
    fi
    # --- 時長判斷結束 ---

    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
        result=1; goto cleanup_and_notify
    fi

    echo -e "${YELLOW}處理 YouTube 媒體 (MP3 無標準化)：$media_url${RESET}"
    log_message "INFO" "處理 YouTube 媒體 (MP3 無標準化)：$media_url"

    # --- 下載並轉換為 MP3 ---
    echo -e "${YELLOW}開始下載並轉換為 MP3：$video_title${RESET}"
    local temp_audio_file="$temp_dir/temp_audio.mp3"
    local yt_dlp_dl_args=(yt-dlp -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o "$temp_audio_file" "$media_url" --newline --progress --concurrent-fragments "$THREADS")
    log_message "INFO" "執行 yt-dlp (MP3 無標準化): ${yt_dlp_dl_args[*]}"
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-mp3-nonorm.log"; then
        log_message "ERROR" "音訊下載或轉換失敗 (無標準化)，詳見 $temp_dir/yt-dlp-mp3-nonorm.log"
        echo -e "${RED}錯誤：音訊下載或轉換失敗 (無標準化)${RESET}"; cat "$temp_dir/yt-dlp-mp3-nonorm.log"
        result=1; goto cleanup_and_notify
    fi
    if [ ! -f "$temp_audio_file" ]; then
        log_message "ERROR" "音訊下載或轉換失敗！找不到臨時 MP3 檔案 '$temp_audio_file'"
        echo -e "${RED}錯誤：找不到下載或轉換後的音訊檔案${RESET}"
        result=1; goto cleanup_and_notify
    fi
    log_message "INFO" "音訊下載並轉換為 MP3 成功: $temp_audio_file"
    audio_file_raw="$temp_audio_file"

    # --- 元數據和封面 ---
    # ... (獲取元數據和下載封面的邏輯不變) ...
     local metadata_json=$(yt-dlp --dump-json "$media_url" 2>/dev/null)
    if [ -n "$metadata_json" ]; then artist_name=$(echo "$metadata_json" | jq -r '.artist // .uploader // "[不明]"'); album_artist_name=$(echo "$metadata_json" | jq -r '.uploader // "[不明]"'); fi
    [[ "$artist_name" == "null" ]] && artist_name="[不明]"
    [[ "$album_artist_name" == "null" ]] && album_artist_name="[不明]"
    local cover_image="$temp_dir/cover.jpg"
    echo -e "${YELLOW}下載封面圖片...${RESET}"
    if ! download_high_res_thumbnail "$media_url" "$cover_image"; then cover_image=""; fi

    # --- 嵌入封面和元數據 ---
    output_audio="$DOWNLOAD_PATH/${base_name}.mp3" # 最終輸出路徑
    echo -e "${YELLOW}正在加入封面和元數據 (無標準化)...${RESET}"
    local ffmpeg_embed_args=(ffmpeg -y -i "$audio_file_raw")
    # ... (ffmpeg 嵌入邏輯不變) ...
    if [ -n "$cover_image" ] && [ -f "$cover_image" ]; then
        ffmpeg_embed_args+=(-i "$cover_image" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic)
    else
        ffmpeg_embed_args+=(-c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name")
    fi
    ffmpeg_embed_args+=("$output_audio")

    log_message "INFO" "執行 FFmpeg 嵌入 (MP3 無標準化): ${ffmpeg_embed_args[*]}"
    if ! "${ffmpeg_embed_args[@]}" > "$temp_dir/ffmpeg_embed.log" 2>&1; then
        log_message "ERROR" "加入封面和元數據失敗 (無標準化)！詳見 $temp_dir/ffmpeg_embed.log"
        echo -e "${RED}錯誤：加入封面和元數據失敗 (無標準化)${RESET}"; cat "$temp_dir/ffmpeg_embed.log"
        result=1;
    else
        echo -e "${GREEN}封面和元數據加入完成 (無標準化)${RESET}"
        result=0;
        safe_remove "$audio_file_raw" # 成功後清理臨時檔
        rm -f "$temp_dir/ffmpeg_embed.log"
    fi

: cleanup_and_notify

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (MP3 無標準化)..."
    # ... (清理邏輯基本不變，確保清理 duration 日誌) ...
    [ -n "$cover_image" ] && [ -f "$cover_image" ] && safe_remove "$cover_image"
    safe_remove "$temp_dir/yt-dlp-mp3-nonorm.log" "$temp_dir/ffmpeg_embed.log" "$temp_dir/yt-dlp-duration.log"
    [ -f "$audio_file_raw" ] && safe_remove "$audio_file_raw" # 如果嵌入失敗，清理殘留
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_audio" ]; then # 增加檢查
            echo -e "${GREEN}處理完成！高品質 MP3 音訊已儲存至：$output_audio${RESET}"
            log_message "SUCCESS" "處理完成 (MP3 無標準化)！音訊已儲存至：$output_audio"
        else
             echo -e "${RED}處理似乎已完成，但最終檔案 '$output_audio' 未找到！${RESET}";
             log_message "ERROR" "處理完成但最終檔案未找到 (MP3 無標準化)";
             result=1 # 標記失敗
        fi
    else
        echo -e "${RED}處理失敗 (MP3 無標準化)！${RESET}"
        log_message "ERROR" "處理失敗 (MP3 無標準化)：$media_url"
    fi

    # --- 條件式通知 ---
    if $should_notify; then
        local notification_title="媒體處理器：MP3 無標準化"
        local base_msg_notify="處理音訊 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_audio" ]; then final_path_notify="$output_audio"; fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

############################################
# 處理單一 YouTube 影片（MP4）下載與處理
# <<< 修改：基於時長條件式通知 v2.4.12+ >>>
############################################
process_single_mp4() {
    local video_url="$1"
    local mode="$2" # 接收模式參數
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt"
    local subtitle_files=()
    local temp_dir=$(mktemp -d)
    local result=0
    local should_notify=false
    local is_playlist=false
    local video_file=""
    local output_video="" # 初始化最終輸出路徑

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        should_notify=true
        log_message "INFO" "MP4 標準化：播放清單模式，啟用通知。"
    fi

    # --- 獲取資訊 ---
    local video_title video_id sanitized_title
    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null)
    if [ -z "$video_title" ]; then
        log_message "ERROR" "無法獲取媒體標題 (標準化 MP4)"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1; goto cleanup_and_notify
    fi
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- 格式設定 ---
    local format_option="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/best[ext=mp4]"
    if [[ "$video_url" != *"youtube.com"* && "$video_url" != *"youtu.be"* ]]; then
        format_option="best"; log_message "WARNING" "...非 YouTube URL (標準化 MP4)..."; subtitle_options=""; echo -e "${YELLOW}非 YouTube URL...${RESET}";
    fi
    log_message "INFO" "使用格式 (標準化 MP4): $format_option"

    # --- <<< 修改：基於時長判斷是否通知 (僅單獨模式) >>> ---
    if ! $is_playlist; then
        echo -e "${YELLOW}正在獲取媒體時長以決定是否通知...${RESET}"
        local duration_secs_str duration_exit_code
        duration_secs_str=$(yt-dlp --no-warnings --print '%(duration)s' "$video_url" 2>"$temp_dir/yt-dlp-duration.log")
        duration_exit_code=$?
        log_message "DEBUG" "yt-dlp duration print exit code (MP4 std): $duration_exit_code"
        log_message "DEBUG" "yt-dlp duration print raw output (MP4 std): [$duration_secs_str]"

        local duration_secs=0
        if [ "$duration_exit_code" -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            duration_secs=$(printf "%.0f" "$duration_secs_str")
        else
            log_message "WARNING" "無法從 yt-dlp 獲取有效的時長資訊 (MP4 std)。"
        fi

        # 設定閾值：> 0.35 小時 (1260 秒) - 與MP3標準化保持一致，也可按需調整
        local duration_threshold_secs=1260
        log_message "INFO" "MP4 標準化：媒體時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (0.35小時)."
        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "MP4 標準化：媒體時長超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP4 標準化：媒體時長未超過閾值，禁用通知。"
            should_notify=false
        fi
    fi
    # --- 時長判斷結束 ---

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; goto cleanup_and_notify; fi

    echo -e "${YELLOW}處理 YouTube 影片 (MP4 標準化)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube 影片 (MP4 標準化): $video_url"; log_message "INFO" "將嘗試請求以下字幕: $target_sub_langs"
    echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕...${RESET}"

    # --- 下載 ---
    echo -e "${YELLOW}開始下載影片及字幕...${RESET}"
    local output_template="$DOWNLOAD_PATH/${sanitized_title} [${video_id:-unknown_id}].%(ext)s"
    local yt_dlp_dl_args=(yt-dlp -f "$format_option")
    IFS=' ' read -r -a sub_opts_array <<< "$subtitle_options"; if [ ${#sub_opts_array[@]} -gt 0 ]; then yt_dlp_dl_args+=("${sub_opts_array[@]}"); fi
    yt_dlp_dl_args+=(-o "$output_template" "$video_url" --newline --progress --concurrent-fragments "$THREADS")
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-video-std.log"; then
        log_message "ERROR" "影片下載失敗 (標準化)..."; echo -e "${RED}錯誤：影片下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-video-std.log";
        result=1; goto cleanup_and_notify
    fi
    local yt_dlp_fn_args=(yt-dlp --get-filename -f "$format_option" -o "$output_template" "$video_url")
    video_file=$("${yt_dlp_fn_args[@]}" 2>/dev/null)
    if [ ! -f "$video_file" ]; then
        log_message "ERROR" "找不到下載的影片檔案 (標準化)..."; echo -e "${RED}錯誤：找不到下載的影片檔案！${RESET}";
        result=1; goto cleanup_and_notify
    fi
    echo -e "${GREEN}影片下載完成：$video_file${RESET}"; log_message "INFO" "影片下載完成 (標準化)：$video_file"

    # --- 字幕檢查 ---
    local base="${video_file%.*}"; subtitle_files=()
    # ... (字幕檢查邏輯不變) ...
    log_message "INFO" "檢查字幕 (基於: $base.*.srt)"
    IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
    for lang in "${langs_to_check[@]}"; do local potential_srt_file="${base}.${lang}.srt"; if [ -f "$potential_srt_file" ]; then local already_added=false; for existing_file in "${subtitle_files[@]}"; do [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }; done; if ! $already_added; then subtitle_files+=("$potential_srt_file"); log_message "INFO" "找到字幕: $potential_srt_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}"; fi; fi; done
    if [ ${#subtitle_files[@]} -eq 0 ]; then log_message "INFO" "未找到中文字幕。"; echo -e "${YELLOW}未找到中文字幕。${RESET}"; fi


    # --- 音量標準化與混流 ---
    output_video="${base}_normalized.mp4" # 最終檔名
    local normalized_audio="$temp_dir/audio_normalized.m4a"
    echo -e "${YELLOW}開始音量標準化...${RESET}"
    if normalize_audio "$video_file" "$normalized_audio" "$temp_dir" true; then
        echo -e "${YELLOW}正在混流標準化音訊、影片與字幕...${RESET}"
        local ffmpeg_mux_args=(ffmpeg -y -i "$video_file" -i "$normalized_audio")
        # ... (混流參數和字幕處理邏輯不變) ...
        for sub_file in "${subtitle_files[@]}"; do ffmpeg_mux_args+=("-sub_charenc" "UTF-8" -i "$sub_file"); done
        ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100" "-map" "0:v:0" "-map" "1:a:0")
        local sub_stream_index=2
        if [ ${#subtitle_files[@]} -gt 0 ]; then
             for ((i=0; i<${#subtitle_files[@]}; i++)); do ffmpeg_mux_args+=("-map" "$sub_stream_index:0"); ((sub_stream_index++)); done
             ffmpeg_mux_args+=("-c:s" "mov_text")
             sub_stream_index=2
             for ((i=0; i<${#subtitle_files[@]}; i++)); do
                 local sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
                 local ffmpeg_lang=""; case "$sub_lang_code" in zh-Hant|zh-TW) ffmpeg_lang="zht" ;; zh-Hans|zh-CN) ffmpeg_lang="zhs" ;; zh) ffmpeg_lang="chi" ;; *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;; esac
                 ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang")
                 ((sub_stream_index++))
             done
        fi
        ffmpeg_mux_args+=("-movflags" "+faststart" "$output_video")

        log_message "INFO" "混流命令: ${ffmpeg_mux_args[*]}"
        local ffmpeg_stderr_log="$temp_dir/ffmpeg_mux_std_stderr.log"
        if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then
            echo -e "${RED}錯誤：混流失敗！...${RESET}"; cat "$ffmpeg_stderr_log"; log_message "ERROR" "混流失敗 (標準化)...";
            result=1;
        else
            echo -e "${GREEN}混流完成${RESET}";
            result=0;
            rm -f "$ffmpeg_stderr_log";
            safe_remove "$video_file"; safe_remove "$normalized_audio"
            for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done;
        fi
    else
        log_message "ERROR" "音量標準化失敗！";
        result=1;
        for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done;
        safe_remove "$normalized_audio"
    fi

: cleanup_and_notify

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (MP4 標準化)..."
    safe_remove "$temp_dir/yt-dlp-video-std.log" "$temp_dir/yt-dlp-duration.log" "$temp_dir/ffmpeg_mux_std_stderr.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
         if [ -f "$output_video" ]; then # 增加檢查
            echo -e "${GREEN}處理完成！影片已儲存至：$output_video${RESET}";
            log_message "SUCCESS" "處理完成 (MP4 標準化)！影片已儲存至：$output_video"
         else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video' 未找到！${RESET}";
            log_message "ERROR" "處理完成但最終檔案未找到 (MP4 標準化)";
            result=1 # 標記失敗
         fi
    else
        echo -e "${RED}處理失敗 (MP4 標準化)！${RESET}";
        log_message "ERROR" "處理失敗 (MP4 標準化)：$video_url"
        if [ -f "$video_file" ]; then echo -e "${YELLOW}原始下載檔案可能保留在：$video_file${RESET}"; fi
    fi

    # --- 條件式通知 ---
    if $should_notify; then
        local notification_title="媒體處理器：MP4 標準化"
        local base_msg_notify="處理影片 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_video" ]; then final_path_notify="$output_video"; fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

#######################################################
# 處理單一 YouTube 影片（MP4）下載與處理（無音量標準化）
# <<< 修改：加入條件式通知 >>>
#######################################################
process_single_mp4_no_normalize() {
    local video_url="$1"
    # <<< 新增：接收模式參數 >>>
    local mode="$2" # 可能為 "playlist_mode" 或空
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA"
    local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt"
    local subtitle_files=()
    local temp_dir=$(mktemp -d)
    local result=0
    # <<< 新增：通知標記 >>>
    local should_notify=false
    local is_playlist=false

    # <<< 新增：判斷是否為播放清單模式 >>>
    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        should_notify=true # 播放清單模式下總是通知
        log_message "INFO" "MP4 無標準化：播放清單模式，啟用通知。"
    fi

    echo -e "${YELLOW}處理 YouTube 影片 (無標準化)：$video_url${RESET}"; log_message "INFO" "處理 YouTube 影片 (無標準化): $video_url"; log_message "INFO" "嘗試字幕: $target_sub_langs"
    echo -e "${YELLOW}嘗試下載繁/簡/通用中文字幕...${RESET}"
    local format_option="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=flac]/bestvideo[ext=mp4][height<=1440]+bestaudio[ext=wav]/bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/best[ext=mp4][height<=1440]/best[height<=1440]/best"
    if [[ "$video_url" != *"youtube.com"* && "$video_url" != *"youtu.be"* ]]; then format_option="best"; log_message "WARNING" "...非 YouTube URL..."; subtitle_options=""; echo -e "${YELLOW}非 YouTube URL...${RESET}"; fi
    log_message "INFO" "使用格式 (無標準化): $format_option"

    # <<< [最終替換開始] 預估檔案大小 (僅在非播放清單模式下進行，精確提取版) >>>
    if ! $is_playlist; then
        echo -e "${YELLOW}正在預估檔案大小以決定是否通知...${RESET}"
        local estimated_size_bytes=0
        local size_list # 儲存提取到的所有大小值 (每行一個)
        local estimate_exit_code

        # 使用 --print '%(filesize,filesize_approx)s' 直接打印選中格式的大小
        # 它會為每個選中的格式（視訊和音訊）單獨打印一行大小值
        # 如果大小未知，可能會打印 'NA' 或空字串
        size_list=$(yt-dlp --no-warnings --print '%(filesize,filesize_approx)s' -f "$format_option" "$video_url" 2>"$temp_dir/yt-dlp-estimate.log")
        estimate_exit_code=$?

        log_message "DEBUG" "yt-dlp size print exit code: $estimate_exit_code"
        log_message "DEBUG" "yt-dlp size print raw output:\n$size_list"

        # 只有在 yt-dlp 成功退出時才嘗試計算
        if [ "$estimate_exit_code" -eq 0 ] && [ -n "$size_list" ]; then
            if ! command -v bc &> /dev/null; then
                 log_message "WARNING" "bc 命令未找到，無法精確計算總大小，跳過大小檢查。"
                 should_notify=false
            else
                # 過濾掉非數字行 (例如 'NA')，然後用 bc 加總
                local size_sum_expr=$(echo "$size_list" | grep '^[0-9]\+$' | paste -sd+)

                if [ -n "$size_sum_expr" ]; then
                    estimated_size_bytes=$(echo "$size_sum_expr" | bc)
                    log_message "DEBUG" "Calculated size expression: $size_sum_expr"
                    if ! [[ "$estimated_size_bytes" =~ ^[0-9]+$ ]]; then
                        estimated_size_bytes=0
                        log_message "WARNING" "bc 計算估計大小失敗。"
                    fi
                else
                     estimated_size_bytes=0
                     log_message "WARNING" "未能從 yt-dlp 輸出中提取任何有效的檔案大小數字。"
                fi
            fi
        else
            log_message "WARNING" "無法從 yt-dlp 獲取格式大小資訊 (yt-dlp exit code: $estimate_exit_code)，詳見 $temp_dir/yt-dlp-estimate.log"
        fi

        local size_threshold_gb=1.0
        local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")

        log_message "INFO" "MP4 無標準化：預估大小 = $estimated_size_bytes bytes, 閾值 = $size_threshold_bytes bytes."
        if [[ "$estimated_size_bytes" -gt "$size_threshold_bytes" ]]; then
            log_message "INFO" "MP4 無標準化：預估大小超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP4 無標準化：預估大小未超過閾值，禁用通知。"
            should_notify=false
        fi
    fi
    # <<< [最終替換結束] 預估大小 >>>

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${YELLOW}開始下載影片及字幕（高品質音質）...${RESET}"
    local output_template="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    local yt_dlp_dl_args=(yt-dlp -f "$format_option")
    IFS=' ' read -r -a sub_opts_array <<< "$subtitle_options"; if [ ${#sub_opts_array[@]} -gt 0 ]; then yt_dlp_dl_args+=("${sub_opts_array[@]}"); fi
    yt_dlp_dl_args+=(-o "$output_template" "$video_url" --newline --progress --concurrent-fragments "$THREADS")
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-nonorm.log"; then
        log_message "ERROR" "影片(無標準化)下載失敗..."; echo -e "${RED}錯誤：影片下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-nonorm.log";
        result=1; goto cleanup_and_notify # 跳轉到清理和通知
    fi
    local yt_dlp_fn_args=(yt-dlp --get-filename -f "$format_option" -o "$output_template" "$video_url")
    local video_file=$("${yt_dlp_fn_args[@]}" 2>/dev/null)
    if [ ! -f "$video_file" ]; then
        log_message "ERROR" "找不到下載的影片檔案..."; echo -e "${RED}錯誤：找不到下載的影片檔案！${RESET}";
        result=1; goto cleanup_and_notify # 跳轉
    fi
    echo -e "${GREEN}影片下載完成：$video_file${RESET}"; log_message "INFO" "影片(無標準化)下載完成：$video_file"

    # --- 字幕處理 (不變) ---
    local base="${video_file%.*}"; subtitle_files=()
    log_message "INFO" "檢查字幕 (基於: $base.*.srt)"
    IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
    for lang in "${langs_to_check[@]}"; do local potential_srt_file="${base}.${lang}.srt"; if [ -f "$potential_srt_file" ]; then local already_added=false; for existing_file in "${subtitle_files[@]}"; do [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }; done; if ! $already_added; then subtitle_files+=("$potential_srt_file"); log_message "INFO" "找到字幕: $potential_srt_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}"; fi; fi; done
    if [ ${#subtitle_files[@]} -eq 0 ]; then log_message "INFO" "未找到中文字幕。"; echo -e "${YELLOW}未找到中文字幕。${RESET}"; fi

    # --- 後處理 (不變) ---
    local final_video="${base}_final.mp4"
    echo -e "${YELLOW}開始後處理，重新編碼音訊為 AAC 並混流...${RESET}"
    local ffmpeg_args=(ffmpeg -hide_banner -loglevel error -y -i "$video_file")
    for sub_file in "${subtitle_files[@]}"; do ffmpeg_args+=("-sub_charenc" "UTF-8" -i "$sub_file"); done
    ffmpeg_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100" "-map" "0:v:0" "-map" "0:a:0")
    local sub_stream_index=1
    if [ ${#subtitle_files[@]} -gt 0 ]; then for ((i=0; i<${#subtitle_files[@]}; i++)); do ffmpeg_args+=("-map" "$sub_stream_index:0"); ((sub_stream_index++)); done; ffmpeg_args+=("-c:s" "mov_text"); fi
    ffmpeg_args+=("-movflags" "+faststart" "$final_video")
    log_message "INFO" "執行 FFmpeg 後處理: ${ffmpeg_args[*]}"
    local ffmpeg_stderr_log="$temp_dir/ffmpeg_nonorm_stderr.log"
    if ! "${ffmpeg_args[@]}" 2> "$ffmpeg_stderr_log"; then
        echo -e "${RED}錯誤：影片後處理失敗！...${RESET}"; cat "$ffmpeg_stderr_log"; log_message "ERROR" "影片後處理失敗...";
        result=1; # 標記失敗，但保留原始檔
    else
        echo -e "${GREEN}影片後處理完成：$final_video${RESET}"; log_message "SUCCESS" "影片(無標準化)處理完成：$final_video";
        result=0; # 標記成功
        rm -f "$ffmpeg_stderr_log";
        # 成功後才清理原始檔
        echo -e "${YELLOW}清理原始下載檔案...${RESET}";
        rm -f "$video_file"; log_message "INFO" "刪除原始影片：$video_file";
        for sub_file in "${subtitle_files[@]}"; do rm -f "$sub_file"; log_message "INFO" "刪除字幕：$sub_file"; done;
        echo -e "${GREEN}清理完成，最終檔案：$final_video${RESET}";
    fi

# <<< 新增：清理與通知標籤 >>>
: cleanup_and_notify

    # 如果處理失敗且 $video_file 仍然存在 (例如後處理失敗)，則保留它
    if [ $result -ne 0 ]; then
        echo -e "${YELLOW}處理失敗，可能保留原始檔案以便檢查。${RESET}";
    fi

    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # <<< 新增：條件式調用通知 >>>
    if $should_notify; then
        local notification_title="媒體處理器：MP4 無標準化"
        local base_msg="處理影片 '$sanitized_title'"
        # 判斷最終檔案路徑
        local final_output_path=""
        if [ $result -eq 0 ]; then
            final_output_path="$final_video" # 成功時是 _final.mp4
        elif [ -f "$video_file" ]; then
            final_output_path="$video_file" # 失敗但原始檔存在
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg" "$final_output_path"
    fi
    # <<< 通知調用結束 >>>

    return $result
}

##############################################################
# <<< 修正：調整 format_option 以確保下載視訊流 >>>
# <<< 新增：完成後在 Termux 發送通知 >>>
# 處理單一 YouTube 影片（MP4）下載（無標準化，可選時段）
##############################################################
process_single_mp4_no_normalize_sections() {
    local video_url="$1"
    local start_time="$2"
    local end_time="$3"

    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA"
    local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt"
    local subtitle_files=()
    local temp_dir=$(mktemp -d)
    local result=0 # 初始化結果為成功

    echo -e "${YELLOW}處理 YouTube 影片 (無標準化，指定時段 $start_time-$end_time)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube 影片 (無標準化，時段 $start_time-$end_time): $video_url"
    log_message "INFO" "嘗試字幕: $target_sub_langs"
    echo -e "${YELLOW}嘗試下載繁/簡/通用中文字幕...${RESET}"

    # --- <<< 修正點：調整 format_option >>> ---
    local format_option="bestvideo[height<=1440][ext=mp4][vcodec^=avc]+bestaudio[ext=m4a]/bestvideo[height<=1440][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1440]+bestaudio/best[height<=1440][ext=mp4]/best[height<=1440]/best"
    log_message "INFO" "使用格式 (無標準化，時段，修正版): $format_option"

    mkdir -p "$DOWNLOAD_PATH";
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入下載目錄 (無標準化，時段)：$DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
        [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1;
    fi

    local video_title video_id sanitized_title base_name
    # 嘗試獲取標題和 ID，如果失敗則提供預設值
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id=$(date +%s)
    # 清理標題中的非法字元
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # 建立安全的檔名片段
    local safe_start_time=${start_time//:/-}
    local safe_end_time=${end_time//:/-}
    # 構建基礎檔名 (包含下載路徑)
    base_name="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]_${safe_start_time}-${safe_end_time}"
    # 最終的輸出影片檔名
    local output_video_file="${base_name}.mp4"

    echo -e "${YELLOW}開始下載影片指定時段 ($start_time-$end_time) 及字幕（高品質音質）...${RESET}"

    local yt_dlp_dl_args=(
        yt-dlp
        -f "$format_option"
        --download-sections "*${start_time}-${end_time}"
        -o "$output_video_file" # 直接輸出到最終檔名
        "$video_url"
        --newline
        # --progress # 移除，因為它可能在分段下載時不準確或不顯示
        --concurrent-fragments "$THREADS"
        --merge-output-format mp4
        # --verbose # 可選，用於詳細日誌調試
    )

    log_message "INFO" "執行 yt-dlp (無標準化，時段，影音，修正格式): ${yt_dlp_dl_args[*]}"
    # 顯示提示訊息，告知使用者進度可能不明顯
    echo -e "${CYAN}提示：分段下載可能不會顯示即時進度，請耐心等候...${RESET}"

    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-sections-video.log"; then
        log_message "ERROR" "影片指定時段下載失敗 (無標準化)..."
        echo -e "${RED}錯誤：影片指定時段下載失敗！${RESET}"
        echo -e "${YELLOW}--- yt-dlp 錯誤日誌開始 ---${RESET}"
        cat "$temp_dir/yt-dlp-sections-video.log"
        echo -e "${YELLOW}--- yt-dlp 錯誤日誌結束 ---${RESET}"
        result=1 # 標記失敗
        # >>> 在失敗時也跳轉到清理和通知邏輯 <<<
        goto cleanup_and_notify
    fi

    # 檢查檔案是否真的被下載
    if [ ! -f "$output_video_file" ]; then
        log_message "ERROR" "找不到下載的影片檔案 (無標準化，時段): $output_video_file"
        echo -e "${RED}錯誤：找不到下載的影片檔案！檢查上述 yt-dlp 日誌。${RESET}"
        result=1 # 標記失敗
        goto cleanup_and_notify
    fi
    echo -e "${GREEN}影片時段下載/合併完成：$output_video_file${RESET}"
    log_message "INFO" "影片時段下載完成 (無標準化)：$output_video_file"

    # 驗證視訊流是否存在
    if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$output_video_file" > /dev/null 2>&1; then
        log_message "ERROR" "驗證失敗：下載的檔案 '$output_video_file' 中似乎沒有視訊流！"
        echo -e "${RED}錯誤：下載完成的檔案似乎缺少視訊流！請檢查 yt-dlp 格式選擇或合併過程。${RESET}"
        echo -e "${YELLOW}--- ffprobe 檔案資訊 ---${RESET}"
        ffprobe -hide_banner "$output_video_file"
        echo -e "${YELLOW}--- ffprobe 資訊結束 ---${RESET}"
        result=1 # 標記失敗
        goto cleanup_and_notify
    else
        log_message "INFO" "驗證成功：下載的檔案 '$output_video_file' 包含視訊流。"
    fi

    # --- 字幕處理 ---
    echo -e "${YELLOW}正在嘗試下載字幕檔案...${RESET}"
    local base_name_for_subs_dl="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]" # 字幕檔名不需要時間戳
    local yt_dlp_sub_args=(
        yt-dlp
        --skip-download --write-subs --sub-lang "$target_sub_langs" --convert-subs srt
        -o "$base_name_for_subs_dl.%(ext)s"
        "$video_url"
    )
    log_message "INFO" "執行 yt-dlp (僅字幕): ${yt_dlp_sub_args[*]}"
    if ! "${yt_dlp_sub_args[@]}" 2> "$temp_dir/yt-dlp-sections-subs.log"; then
        log_message "WARNING" "下載字幕失敗或無字幕。詳見 $temp_dir/yt-dlp-sections-subs.log"
        echo -e "${YELLOW}警告：下載字幕失敗或影片無字幕。${RESET}"
    fi

    # 查找下載的字幕檔
    log_message "INFO" "檢查字幕 (基於: ${base_name_for_subs_dl}.*.srt)"
    subtitle_files=()
    IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
    for lang in "${langs_to_check[@]}"; do
        local potential_srt_file="${base_name_for_subs_dl}.${lang}.srt"
        if [ -f "$potential_srt_file" ]; then
            local already_added=false
            for existing_file in "${subtitle_files[@]}"; do [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }; done
            if ! $already_added; then
                subtitle_files+=("$potential_srt_file")
                log_message "INFO" "找到字幕: $potential_srt_file"
                echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}"
            fi
        fi
    done
    if [ ${#subtitle_files[@]} -eq 0 ]; then
        log_message "INFO" "未找到中文字幕。"
        echo -e "${YELLOW}未找到中文字幕。${RESET}"
    fi

    # 如果找到字幕，則進行混流
    if [ ${#subtitle_files[@]} -gt 0 ]; then
        echo -e "${YELLOW}開始將字幕嵌入影片...${RESET}"
        local final_video_with_subs="${base_name}_with_subs.mp4" # 臨時混流檔名
        local ffmpeg_mux_args=(ffmpeg -y -i "$output_video_file")

        for sub_file in "${subtitle_files[@]}"; do ffmpeg_mux_args+=("-i" "$sub_file"); done
        ffmpeg_mux_args+=("-map" "0:v" "-map" "0:a" "-c:v" "copy" "-c:a" "copy")

        local sub_input_index=1
        for ((i=0; i<${#subtitle_files[@]}; i++)); do
            ffmpeg_mux_args+=("-map" "$sub_input_index")
            local sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
            local ffmpeg_lang=""
            case "$sub_lang_code" in
                zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                zh) ffmpeg_lang="chi" ;;
                *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;; # 取前三字母作為備用
            esac
            # 設定字幕軌的語言元數據
            ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang")
            ((sub_input_index++))
        done
        ffmpeg_mux_args+=("-c:s" "mov_text" "-movflags" "+faststart" "$final_video_with_subs")

        log_message "INFO" "執行 FFmpeg 字幕混流: ${ffmpeg_mux_args[*]}"
        if ! "${ffmpeg_mux_args[@]}" 2> "$temp_dir/ffmpeg_mux_subs.log"; then
            log_message "ERROR" "字幕混流失敗！詳見 $temp_dir/ffmpeg_mux_subs.log"
            echo -e "${RED}錯誤：字幕混流失敗！${RESET}"
            cat "$temp_dir/ffmpeg_mux_subs.log"
            result=1 # 混流失敗也算失敗
            # 保留原始影片檔案 (無字幕)
        else
            echo -e "${GREEN}字幕混流完成：$final_video_with_subs${RESET}"
            log_message "SUCCESS" "字幕混流成功：$final_video_with_subs"
            # 混流成功，刪除原始影片和字幕檔，重命名混流後的檔案
            safe_remove "$output_video_file"
            for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done
            if mv "$final_video_with_subs" "$output_video_file"; then
                 log_message "INFO" "重命名 $final_video_with_subs 為 $output_video_file"
            else
                 log_message "ERROR" "重命名 $final_video_with_subs 失敗，最終檔案可能為 $final_video_with_subs"
                 echo -e "${RED}錯誤：重命名最終檔案失敗，請檢查 $final_video_with_subs ${RESET}"
                 # 即使重命名失敗，也認為主要操作成功了，但可能檔名不對
                 # 將 output_video_file 更新為實際存在的檔名，以便後續通知使用
                 output_video_file="$final_video_with_subs"
                 result=0 # 仍然視為成功，但有警告
            fi
            # result 維持 0 (成功)
        fi
    else
        log_message "INFO" "未找到字幕或未成功下載，無需混流。"
        # result 維持 0 (成功)
    fi

# 使用 goto 跳轉標籤，集中處理清理和通知
: cleanup_and_notify

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (無標準化，時段)..."
    safe_remove "$temp_dir/yt-dlp-sections-video.log" "$temp_dir/yt-dlp-sections-subs.log" "$temp_dir/ffmpeg_mux_subs.log"
    # 清理可能殘留的字幕檔 (即使混流失敗也清理)
    for lang in "${langs_to_check[@]}"; do safe_remove "${base_name_for_subs_dl}.${lang}.srt"; done
    # 刪除臨時目錄
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 最終結果報告 (控制台) ---
    if [ $result -eq 0 ]; then
        # 如果 output_video_file 仍然存在 (成功下載，可能混流成功或無字幕)
        if [ -f "$output_video_file" ]; then
             echo -e "${GREEN}處理完成！影片 (無標準化，時段 $start_time-$end_time) 已儲存至：$(basename "$output_video_file")${RESET}"
             log_message "SUCCESS" "處理完成 (無標準化，時段)！影片已儲存至：$output_video_file"
        else
             # 可能是混流後重命名失敗，或者其他意外情況檔案沒了
             echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video_file' 未找到！請檢查日誌。${RESET}"
             log_message "ERROR" "處理完成但最終檔案未找到 (無標準化，時段)：$output_video_file"
             result=1 # 標記為失敗狀態
        fi
    else
        echo -e "${RED}處理失敗 (無標準化，時段)！${RESET}"
        log_message "ERROR" "處理失敗 (無標準化，時段)：$video_url"
    fi


    # --- >>> 新增：Termux 通知邏輯 <<< ---
    if [[ "$OS_TYPE" == "termux" ]]; then
        # 檢查 termux-notification 命令是否存在
        if command -v termux-notification &> /dev/null; then
            local notification_title="媒體處理器：MP4 片段"
            local notification_content=""
            # 使用 basename 獲取純檔名，避免路徑過長
            local final_filename=$(basename "$output_video_file")

            if [ $result -eq 0 ] && [ -f "$output_video_file" ]; then
                # 成功訊息
                notification_content="✅ 成功：影片 '$sanitized_title' 時段 [$start_time-$end_time] 已儲存為 '$final_filename'。"
                log_message "INFO" "準備發送 Termux 成功通知。"
            else
                # 失敗訊息 (包括檔案最終未找到的情況)
                notification_content="❌ 失敗：影片 '$sanitized_title' 時段 [$start_time-$end_time] 處理失敗。請查看腳本輸出或日誌。"
                 log_message "INFO" "準備發送 Termux 失敗通知。"
            fi

            # 嘗試發送通知
            if ! termux-notification --title "$notification_title" --content "$notification_content"; then
                log_message "WARNING" "執行 termux-notification 命令失敗。Termux:API 是否安裝並運作正常？"
                # 可選擇性地在控制台也顯示警告
                # echo -e "${YELLOW}警告：無法發送 Termux 通知。${RESET}"
            else
                 log_message "INFO" "Termux 通知已成功發送。"
            fi
        else
            log_message "INFO" "未找到 termux-notification 命令 (Termux:API 未安裝？)，跳過通知。"
        fi
    fi
    # --- >>> 通知邏輯結束 <<< ---

    return $result
}

############################################
# 處理單一 YouTube 影片（MKV）下載與處理 (修正版)(1.8.4+)
############################################
process_single_mkv() {
    local video_url="$1"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_format_pref="ass/vtt/best"
    local subtitle_files=()
    local temp_dir=$(mktemp -d)
    local result=0

    echo -e "${YELLOW}處理 YouTube 影片 (輸出 MKV)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube MKV: $video_url"; log_message "INFO" "將嘗試請求以下字幕 (格式: $subtitle_format_pref): $target_sub_langs"
    echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕 (保留樣式)...${RESET}"

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi

    # --- 改進：獲取標題和 ID，並清理標題中的非法字元 ---
    local video_title video_id sanitized_title_id
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id=$(date +%s)
    # 移除標題中常見的非法檔案名字符：/ \ : * ? " < > |
    sanitized_title_id=$(echo "${video_title}_${video_id}" | sed 's@[/\\:*?"<>|]@_@g')
    local output_base_name="$DOWNLOAD_PATH/$sanitized_title_id" # <<< 使用清理後的名稱
    # --- 結束檔名處理改進 ---

    local video_temp_file="${temp_dir}/video_stream.mp4"
    local audio_temp_file="${temp_dir}/audio_stream.m4a"
    local sub_temp_template="${temp_dir}/sub_stream.%(ext)s"

    echo -e "${YELLOW}開始下載最佳視訊流...${RESET}"
    # ... (下載視訊流邏輯) ...
# 修改後的命令 (添加 [height<=1440])：
if ! yt-dlp -f 'bv[ext=mp4][height<=1440]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video.log"; then
    # 如果找不到 1440p 或以下的 MP4 視訊流，可以添加一個備選方案，例如下載最佳的 MP4 視訊流
    echo -e "${YELLOW}警告：未找到 <=1440p 的 MP4 視訊流，嘗試下載最佳 MP4 視訊流...${RESET}"
    log_message "WARNING" "未找到 <=1440p 的 MP4 視訊流，嘗試最佳 MP4 for $video_url"
    if ! yt-dlp -f 'bv[ext=mp4]/bestvideo[ext=mp4]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video.log"; then
        log_message "ERROR" "視訊流下載失敗（包括備選方案）..."; echo -e "${RED}錯誤：視訊流下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-video.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1;
    fi
fi
log_message "INFO" "視訊流下載完成: $video_temp_file"

    echo -e "${YELLOW}開始下載最佳音訊流...${RESET}"
    # ... (下載音訊流邏輯) ...
     if ! yt-dlp -f 'ba[ext=m4a]' --no-warnings -o "$audio_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-audio.log"; then
             log_message "ERROR" "音訊流下載失敗..."; echo -e "${RED}錯誤：音訊流下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-audio.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1;
        fi
    log_message "INFO" "音訊流下載完成: $audio_temp_file"

    echo -e "${YELLOW}開始下載字幕 (格式: ${subtitle_format_pref})...${RESET}"
    # ... (下載字幕和查找邏輯) ...
    yt-dlp --write-subs --sub-format "$subtitle_format_pref" --sub-lang "$target_sub_langs" --skip-download -o "$sub_temp_template" "$video_url" > "$temp_dir/yt-dlp-subs.log" 2>&1
    local found_sub=false
    for lang_code in "zh-Hant" "zh-TW" "zh-Hans" "zh-CN" "zh"; do
        for sub_ext in ass vtt; do
             potential_sub_file="${temp_dir}/sub_stream.${lang_code}.${sub_ext}"
             if [ -f "$potential_sub_file" ]; then
                 subtitle_files+=("$potential_sub_file")
                 log_message "INFO" "找到字幕: $potential_sub_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_sub_file")${RESET}";
                 found_sub=true; break;
             fi; done
        if $found_sub; then break; fi
    done
    if [ ${#subtitle_files[@]} -eq 0 ]; then log_message "INFO" "未找到符合條件的中文字幕。"; echo -e "${YELLOW}未找到 ASS/VTT 格式的中文字幕。${RESET}"; fi

    local normalized_audio_m4a="$temp_dir/audio_normalized.m4a"
    echo -e "${YELLOW}開始音量標準化...${RESET}"
    if normalize_audio "$audio_temp_file" "$normalized_audio_m4a" "$temp_dir" true; then
        echo -e "${YELLOW}正在混流成 MKV 檔案...${RESET}"
        local output_mkv="${output_base_name}_normalized.mkv" # <<< 使用清理後的 base name

        local ffmpeg_mux_args=(ffmpeg -y -i "$video_temp_file" -i "$normalized_audio_m4a")
        local sub_input_index=2
        for sub_file in "${subtitle_files[@]}"; do ffmpeg_mux_args+=("-i" "$sub_file"); done
        
        # 編碼器和映射邏輯
        ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100") 
        ffmpeg_mux_args+=("-map" "0:v:0" "-map" "1:a:0") 
        if [ ${#subtitle_files[@]} -gt 0 ]; then 
            ffmpeg_mux_args+=("-c:s" "copy") 
            for ((i=0; i<${#subtitle_files[@]}; i++)); do 
                ffmpeg_mux_args+=("-map" "$sub_input_index:s:0")
                ((sub_input_index++)) 
            done
        fi
        ffmpeg_mux_args+=("$output_mkv") # <<< 輸出到清理後的檔名

        log_message "INFO" "MKV 混流命令: ${ffmpeg_mux_args[*]}"
        local ffmpeg_stderr_log="$temp_dir/ffmpeg_mkv_mux_stderr.log"

        # --- 改進：在失敗時輸出錯誤日誌 ---
        if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then
            echo -e "${RED}錯誤：MKV 混流失敗！以下是 FFmpeg 錯誤訊息：${RESET}"
            cat "$ffmpeg_stderr_log" # <<< 輸出錯誤訊息到控制檯
            log_message "ERROR" "MKV 混流失敗，詳見 $ffmpeg_stderr_log (錯誤內容已輸出)";
            result=1;
        else
        # --- 結束錯誤輸出改進 ---
            echo -e "${GREEN}MKV 混流完成${RESET}";
            result=0;
            # 在成功後才刪除日誌檔
            rm -f "$ffmpeg_stderr_log";
        fi
    else
        log_message "ERROR" "音量標準化失敗！";
        result=1;
    fi

    log_message "INFO" "清理臨時檔案..."
    # ... (清理邏輯，確保 ffmpeg_stderr_log 如果失敗了不會被這裡誤刪) ...
    safe_remove "$video_temp_file" "$audio_temp_file" "$normalized_audio_m4a"
    for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done
    safe_remove "$temp_dir/yt-dlp-video.log" "$temp_dir/yt-dlp-audio.log" "$temp_dir/yt-dlp-subs.log"
    # 只有在成功時 ffmpeg_stderr_log 才被刪除，失敗時保留它（雖然內容已輸出）
    [ -f "$ffmpeg_stderr_log" ] && safe_remove "$ffmpeg_stderr_log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    if [ $result -eq 0 ]; then
        echo -e "${GREEN}處理完成！MKV 影片已儲存至：$output_mkv${RESET}";
        log_message "SUCCESS" "MKV 處理完成！影片已儲存至：$output_mkv";
    else
        echo -e "${RED}處理失敗！${RESET}";
        log_message "ERROR" "MKV 處理失敗：$video_url";
    fi
    return $result
}

############################################
# 輔助函數：處理單一通用網站媒體項目
# <<< 修改：改進縮圖查找與清理 v2.4.9+ >>>
############################################
_process_single_other_site() {
    local item_url="$1"; local choice_format="$2"; local item_index="$3"; local total_items="$4"
    local mode="$5"
    local temp_dir=$(mktemp -d); local thumbnail_file=""; local main_media_file=""; local base_name=""
    local result=0; local output_final_file=""; local artist_name="[不明]"; local album_artist_name="[不明]"
    local progress_prefix=""; if [ -n "$item_index" ] && [ -n "$total_items" ]; then progress_prefix="[$item_index/$total_items] "; fi
    local should_notify=false
    local is_playlist=false

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        should_notify=true
        log_message "INFO" "通用下載 標準化：播放清單模式，啟用通知。"
    fi

    # --- 獲取標題用於基本訊息 ---
    local item_title sanitized_title
    item_title=$(yt-dlp --get-title "$item_url" 2>/dev/null) || item_title="media_item"
    sanitized_title=$(echo "${item_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- 預估大小 (僅單獨模式) ---
    local yt_dlp_format_string=""
    if [ "$choice_format" = "mp4" ]; then yt_dlp_format_string="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
    else yt_dlp_format_string="bestaudio/best"; fi

    if ! $is_playlist; then
        # ... (預估大小邏輯保持不變，使用之前的最終版本) ...
        echo -e "${YELLOW}正在預估檔案大小以決定是否通知...${RESET}"
        local estimated_size_bytes=0
        local size_list estimate_exit_code
        size_list=$(yt-dlp --no-warnings --print '%(filesize,filesize_approx)s' -f "$yt_dlp_format_string" "$item_url" 2>"$temp_dir/yt-dlp-estimate.log")
        estimate_exit_code=$?
        log_message "DEBUG" "yt-dlp size print exit code (通用 std): $estimate_exit_code"
        log_message "DEBUG" "yt-dlp size print raw output (通用 std):\n$size_list"
        if [ "$estimate_exit_code" -eq 0 ] && [ -n "$size_list" ]; then
            if command -v bc &> /dev/null; then
                local size_sum_expr=$(echo "$size_list" | grep '^[0-9]\+$' | paste -sd+)
                if [ -n "$size_sum_expr" ]; then
                    estimated_size_bytes=$(echo "$size_sum_expr" | bc)
                    if ! [[ "$estimated_size_bytes" =~ ^[0-9]+$ ]]; then estimated_size_bytes=0; fi
                else estimated_size_bytes=0; fi
            else estimated_size_bytes=0; log_message "WARNING" "bc missing"; fi
        else log_message "WARNING" "Failed to get size info (通用 std)"; fi
        local size_threshold_gb=0.12
        local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
        log_message "INFO" "通用下載 標準化：預估大小 = $estimated_size_bytes bytes, 閾值 = $size_threshold_bytes bytes."
        if [[ "$estimated_size_bytes" -gt "$size_threshold_bytes" ]]; then
            log_message "INFO" "通用下載 標準化：預估大小超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "通用下載 標準化：預估大小未超過閾值，禁用通知。"
            should_notify=false
        fi
    fi
    # --- 預估結束 ---

    echo -e "${CYAN}${progress_prefix}處理項目: $item_url (${choice_format})${RESET}"; log_message "INFO" "${progress_prefix}處理項目: $item_url (格式: $choice_format)"
    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; goto cleanup_and_notify; fi

    # --- 下載 ---
    # <<< 修改：移除 --write-thumbnail，下載後再單獨獲取 >>>
    local yt_dlp_extra_args=(--newline --progress --concurrent-fragments "$THREADS")
    # 保持兩個模板
    local output_template="$DOWNLOAD_PATH/%(playlist_index)s-%(title)s [%(id)s].%(ext)s"
    local output_template_single="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"

    echo -e "${YELLOW}${progress_prefix}開始下載主檔案...${RESET}"
    local yt_dlp_cmd_args=(yt-dlp -f "$yt_dlp_format_string" "${yt_dlp_extra_args[@]}" -o "$output_template" "$item_url")
    log_message "INFO" "${progress_prefix}執行下載 (模板1): ${yt_dlp_cmd_args[*]}"
    if ! "${yt_dlp_cmd_args[@]}" 2> "$temp_dir/yt-dlp-other1.log"; then
        echo -e "${YELLOW}${progress_prefix}模板1下載失敗，嘗試模板2...${RESET}"
        local yt_dlp_cmd_args_single=(yt-dlp -f "$yt_dlp_format_string" "${yt_dlp_extra_args[@]}" -o "$output_template_single" "$item_url")
        log_message "INFO" "${progress_prefix}執行下載 (模板2): ${yt_dlp_cmd_args_single[*]}"
        if ! "${yt_dlp_cmd_args_single[@]}" 2> "$temp_dir/yt-dlp-other2.log"; then
             log_message "ERROR" "...下載失敗 (通用 std)..."; echo -e "${RED}錯誤：下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-other2.log";
             result=1; goto cleanup_and_notify
        fi
    fi

    # --- 定位主檔案 ---
    echo -e "${YELLOW}${progress_prefix}定位主檔案...${RESET}"
    # 嘗試用兩個模板獲取檔名
    local get_filename_args1=(yt-dlp --get-filename -f "$yt_dlp_format_string" -o "$output_template" "$item_url")
    main_media_file=$("${get_filename_args1[@]}" 2>/dev/null)
    if [ ! -f "$main_media_file" ]; then
        local get_filename_args2=(yt-dlp --get-filename -f "$yt_dlp_format_string" -o "$output_template_single" "$item_url")
        main_media_file=$("${get_filename_args2[@]}" 2>/dev/null)
    fi

    if [ ! -f "$main_media_file" ]; then
         log_message "ERROR" "...找不到主檔案 (通用 std)..."; echo -e "${RED}錯誤：找不到主檔案！${RESET}";
         result=1; goto cleanup_and_notify
    fi
    log_message "INFO" "${progress_prefix}找到主檔案: $main_media_file";

    # --- <<< 修改：更精確地獲取 base_name >>> ---
    # 獲取檔案所在的目錄
    local media_dir=$(dirname "$main_media_file")
    # 獲取不含路徑和副檔名的基本檔名
    local base_filename=$(basename "$main_media_file")
    # 移除最後一個點及其後面的所有內容來獲得 base_name
    base_name="${base_filename%.*}"
    log_message "DEBUG" "計算出的 Base Name: [$base_name]"
    # 組合成包含路徑的 base_name_with_path，用於查找縮圖
    local base_name_with_path="${media_dir}/${base_name}"
    log_message "DEBUG" "用於查找縮圖的路徑前綴: [$base_name_with_path]"

    # --- <<< 修改：單獨下載縮圖並查找 >>> ---
    echo -e "${YELLOW}${progress_prefix}嘗試下載縮圖...${RESET}"
    # 使用與主檔案相同的模板模式，但只下載縮圖
    local thumb_dl_template="${base_name_with_path}.%(ext)s" # 直接指定基礎檔名
    if ! yt-dlp --skip-download --write-thumbnail -o "$thumb_dl_template" "$item_url" 2> "$temp_dir/yt-dlp-thumb.log"; then
        log_message "WARNING" "...下載縮圖指令失敗或無縮圖，詳見 $temp_dir/yt-dlp-thumb.log"
        # cat "$temp_dir/yt-dlp-thumb.log" # 可選
    fi

    # --- <<< 修改：改進縮圖查找邏輯 >>> ---
    thumbnail_file="" # 先清空
    # 使用 find 命令在下載目錄中查找匹配的圖片檔案
    # -maxdepth 1 避免遞歸子目錄
    # -type f 確保是檔案
    # -name "${base_name}.*" 匹配檔名
    # \( ... \) -o \( ... \) 匹配多種副檔名 (大小寫不敏感 -iname)
    # -print -quit 找到第一個匹配就停止並打印路徑
    thumbnail_file=$(find "$media_dir" -maxdepth 1 -type f -iname "${base_name}.*" \
                     \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
                     -print -quit)

    if [ -n "$thumbnail_file" ]; then
        log_message "INFO" "...找到縮圖: $thumbnail_file";
    else
        log_message "WARNING" "...在下載目錄中未找到縮圖檔案 (jpg/jpeg/png/webp)。";
    fi
    # --- 縮圖查找結束 ---

    # --- 處理邏輯 (MP3 或 MP4) ---
    if [ "$choice_format" = "mp3" ]; then
        output_final_file="${media_dir}/${base_name}_normalized.mp3"; # 確保路徑正確
        local normalized_temp="$temp_dir/temp_normalized.mp3"
        echo -e "${YELLOW}${progress_prefix}開始標準化 (MP3)...${RESET}"
        if normalize_audio "$main_media_file" "$normalized_temp" "$temp_dir" false; then
            echo -e "${YELLOW}${progress_prefix}處理最終 MP3...${RESET}"
            local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_temp")
            if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then
                ffmpeg_embed_args+=(-i "$thumbnail_file" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic)
            else
                ffmpeg_embed_args+=(-c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name")
            fi
            ffmpeg_embed_args+=("$output_final_file")
            if ! "${ffmpeg_embed_args[@]}" > /dev/null 2>&1; then
                log_message "ERROR" "...生成 MP3 失敗 (通用 std)..."; echo -e "${RED}錯誤：生成 MP3 失敗！${RESET}";
                result=1; # 可能保留 $normalized_temp
            else
                 result=0; # 成功
                 safe_remove "$normalized_temp"
            fi
        else result=1; log_message "ERROR" "標準化失敗 (通用 MP3 std)"; fi
    elif [ "$choice_format" = "mp4" ]; then
        output_final_file="${media_dir}/${base_name}_normalized.mp4"; # 確保路徑正確
        local normalized_audio_m4a="$temp_dir/audio_normalized.m4a" # 臨時音訊檔
        echo -e "${YELLOW}${progress_prefix}開始標準化 (提取音訊)...${RESET}"
        # 這裡 normalize_audio 的第二個參數是輸出檔路徑
        if normalize_audio "$main_media_file" "$normalized_audio_m4a" "$temp_dir" true; then
            echo -e "${YELLOW}${progress_prefix}混流影片與音訊...${RESET}"
            local ffmpeg_mux_args=(ffmpeg -y -i "$main_media_file" -i "$normalized_audio_m4a" -c:v copy -c:a aac -b:a 256k -ar 44100 -map 0:v:0 -map 1:a:0 -movflags +faststart "$output_final_file")
            log_message "INFO" "執行 FFmpeg 混流 (通用 std): ${ffmpeg_mux_args[*]}"
            if ! "${ffmpeg_mux_args[@]}" > "$temp_dir/ffmpeg_mux.log" 2>&1; then
                 log_message "ERROR" "...混流 MP4 失敗 (通用 std)... 詳見 $temp_dir/ffmpeg_mux.log"; echo -e "${RED}錯誤：混流 MP4 失敗！${RESET}";
                 # cat "$temp_dir/ffmpeg_mux.log" # 可選
                 result=1; # 保留 $main_media_file 和 $normalized_audio_m4a
            else
                 result=0; # 成功
                 safe_remove "$normalized_audio_m4a" # 成功後清理臨時音訊
                 rm -f "$temp_dir/ffmpeg_mux.log"
            fi
        else result=1; log_message "ERROR" "標準化失敗 (通用 MP4 std)"; fi
    fi

: cleanup_and_notify

    # --- [確認] 清理 (含標準化版本) ---
    log_message "INFO" "${progress_prefix}清理 (通用 std)...";
    # 明確刪除原始下載檔案 (因為已被處理或合併到新檔案)
    safe_remove "$main_media_file";
    # <<< 修改：使用已賦值的 thumbnail_file 變數 >>>
    if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then
        log_message "DEBUG" "準備清理已找到的縮圖: $thumbnail_file"
        safe_remove "$thumbnail_file";
    else
        log_message "DEBUG" "無需清理縮圖 (thumbnail_file 為空或檔案不存在)"
    fi
    # 移除之前 overly broad 的清理
    # safe_remove "${base_name}".*;

    # 清理日誌檔案
    safe_remove "$temp_dir/yt-dlp-other1.log" "$temp_dir/yt-dlp-other2.log" "$temp_dir/yt-dlp-estimate.log" "$temp_dir/yt-dlp-thumb.log" "$temp_dir/ffmpeg_mux.log"
    # 清理臨時目錄
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    # --- 清理結束 ---

    # --- 控制台報告 (保持不變，但增加檢查) ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_final_file" ]; then
            echo -e "${GREEN}${progress_prefix}處理完成！檔案：$output_final_file${RESET}";
            log_message "SUCCESS" "${progress_prefix}處理完成！檔案：$output_final_file";
        else
            echo -e "${RED}${progress_prefix}處理似乎已完成，但最終檔案 '$output_final_file' 未找到！${RESET}";
            log_message "ERROR" "${progress_prefix}處理完成但最終檔案未找到";
             result=1
        fi
    else
        echo -e "${RED}${progress_prefix}處理失敗！${RESET}";
        log_message "ERROR" "${progress_prefix}處理失敗：$item_url";
        # 如果失敗，提示原始檔可能還在 (雖然此流程會嘗試刪除)
        # if [ -f "$main_media_file" ]; then echo -e "${YELLOW}原始下載檔案可能保留在：$main_media_file${RESET}"; fi
    fi

    # --- 條件式通知 (保持不變) ---
    if $should_notify; then
        local notification_title="媒體處理器：通用 標準化"
        local base_msg_notify="${progress_prefix}處理 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_final_file" ]; then
            final_path_notify="$output_final_file";
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

###########################################################
# 輔助函數 - 處理單一通用網站媒體項目 (無音量標準化)
# <<< 修改：加入條件式通知 v2.4.6+ >>>
###########################################################
_process_single_other_site_no_normalize() {
    local item_url="$1"; local choice_format="$2"; local item_index="$3"; local total_items="$4"
    # <<< 新增：接收模式參數 >>>
    local mode="$5"
    local temp_dir=$(mktemp -d); local thumbnail_file=""; local main_media_file=""; local base_name=""
    local result=0;
    local progress_prefix=""; if [ -n "$item_index" ] && [ -n "$total_items" ]; then progress_prefix="[$item_index/$total_items] "; fi
    # <<< 新增：通知標記 >>>
    local should_notify=false
    local is_playlist=false

    # <<< 新增：判斷模式 >>>
    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        should_notify=true
        log_message "INFO" "通用下載 無標準化：播放清單模式，啟用通知。"
    fi

    # --- 獲取標題用於基本訊息 ---
    local item_title sanitized_title
    item_title=$(yt-dlp --get-title "$item_url" 2>/dev/null) || item_title="media_item"
    sanitized_title=$(echo "${item_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- 預估大小 (僅單獨模式) ---
    local yt_dlp_format_string=""
    if [ "$choice_format" = "mp4" ]; then yt_dlp_format_string="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
    else yt_dlp_format_string="bestaudio/best"; fi

    if ! $is_playlist; then
        echo -e "${YELLOW}正在預估檔案大小以決定是否通知...${RESET}"
        local estimated_size_bytes=0
        local size_list estimate_exit_code
        size_list=$(yt-dlp --no-warnings --print '%(filesize,filesize_approx)s' -f "$yt_dlp_format_string" "$item_url" 2>"$temp_dir/yt-dlp-estimate.log")
        estimate_exit_code=$?
        log_message "DEBUG" "yt-dlp size print exit code (通用 non-std): $estimate_exit_code"
        log_message "DEBUG" "yt-dlp size print raw output (通用 non-std):\n$size_list"

        if [ "$estimate_exit_code" -eq 0 ] && [ -n "$size_list" ]; then
            if command -v bc &> /dev/null; then
                local size_sum_expr=$(echo "$size_list" | grep '^[0-9]\+$' | paste -sd+)
                if [ -n "$size_sum_expr" ]; then
                    estimated_size_bytes=$(echo "$size_sum_expr" | bc)
                    if ! [[ "$estimated_size_bytes" =~ ^[0-9]+$ ]]; then estimated_size_bytes=0; fi
                else estimated_size_bytes=0; fi
            else estimated_size_bytes=0; log_message "WARNING" "bc missing"; fi
        else log_message "WARNING" "Failed to get size info (通用 non-std)"; fi

        local size_threshold_gb=0.5 # 對通用下載統一用 0.5GB
        local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
        log_message "INFO" "通用下載 無標準化：預估大小 = $estimated_size_bytes bytes, 閾值 = $size_threshold_bytes bytes."
        if [[ "$estimated_size_bytes" -gt "$size_threshold_bytes" ]]; then
            log_message "INFO" "通用下載 無標準化：預估大小超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "通用下載 無標準化：預估大小未超過閾值，禁用通知。"
            should_notify=false
        fi
    fi
    # --- 預估結束 ---

    echo -e "${CYAN}${progress_prefix}處理項目 (無標準化): $item_url (${choice_format})${RESET}";
    log_message "INFO" "${progress_prefix}處理項目 (無標準化): $item_url (格式: $choice_format)"

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; goto cleanup_and_notify; fi

    # --- 下載 ---
    local yt_dlp_extra_args=(--write-thumbnail --newline --progress --concurrent-fragments "$THREADS")
    local output_template="$DOWNLOAD_PATH/%(playlist_index)s-%(title)s [%(id)s].%(ext)s"
    local output_template_single="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    echo -e "${YELLOW}${progress_prefix}開始下載 (無標準化)...${RESET}"
    local yt_dlp_cmd_args=(yt-dlp -f "$yt_dlp_format_string" "${yt_dlp_extra_args[@]}" -o "$output_template" "$item_url")
    log_message "INFO" "${progress_prefix}執行下載 (無標準化，模板1): ${yt_dlp_cmd_args[*]}"
    if ! "${yt_dlp_cmd_args[@]}" 2> "$temp_dir/yt-dlp-other-nonorm1.log"; then
        echo -e "${YELLOW}${progress_prefix}模板1下載失敗，嘗試模板2...${RESET}"
        local yt_dlp_cmd_args_single=(yt-dlp -f "$yt_dlp_format_string" "${yt_dlp_extra_args[@]}" -o "$output_template_single" "$item_url")
        log_message "INFO" "${progress_prefix}執行下載 (無標準化，模板2): ${yt_dlp_cmd_args_single[*]}"
        if ! "${yt_dlp_cmd_args_single[@]}" 2> "$temp_dir/yt-dlp-other-nonorm2.log"; then
            log_message "ERROR" "...下載失敗 (無標準化)..."; echo -e "${RED}錯誤：下載失敗！${RESET}";
            [ -f "$temp_dir/yt-dlp-other-nonorm2.log" ] && cat "$temp_dir/yt-dlp-other-nonorm2.log" || cat "$temp_dir/yt-dlp-other-nonorm1.log"
            result=1; goto cleanup_and_notify
        fi
    fi
    # --- 定位檔案 ---
    echo -e "${YELLOW}${progress_prefix}定位下載的檔案...${RESET}"
    local get_filename_args1=(yt-dlp --get-filename -f "$yt_dlp_format_string" -o "$output_template" "$item_url")
    main_media_file=$("${get_filename_args1[@]}" 2>/dev/null)
    if [ ! -f "$main_media_file" ]; then local get_filename_args2=(yt-dlp --get-filename -f "$yt_dlp_format_string" -o "$output_template_single" "$item_url"); main_media_file=$("${get_filename_args2[@]}" 2>/dev/null); fi
    if [ ! -f "$main_media_file" ]; then
        log_message "ERROR" "...找不到主要下載檔案 (無標準化)..."; echo -e "${RED}錯誤：找不到主要下載檔案！${RESET}";
        result=1; goto cleanup_and_notify
    fi
    log_message "INFO" "${progress_prefix}找到主要下載檔案: $main_media_file";
    base_name="${main_media_file%.*}"
    # 查找縮圖... (略)

    # --- 跳過處理 ---
    log_message "INFO" "${progress_prefix}跳過音量標準化與後處理。"
    echo -e "${GREEN}${progress_prefix}下載完成 (無標準化)。${RESET}"
    result=0 # 下載成功即成功

: cleanup_and_notify # 跳轉標籤保持不變

    # --- [修正開始] 清理 (無標準化版本) ---
    log_message "INFO" "${progress_prefix}清理臨時檔案 (無標準化)..."
    # 刪除臨時目錄、下載日誌以及下載的縮圖檔案
    safe_remove "$temp_dir/yt-dlp-other-nonorm1.log" "$temp_dir/yt-dlp-other-nonorm2.log" "$temp_dir/yt-dlp-estimate.log"
    # 移除對 main_media_file 的清理！
    if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then
        safe_remove "$thumbnail_file"
    fi
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    # --- [修正結束] 清理 ---

    # --- 控制台報告 (保持不變) ---
    if [ $result -eq 0 ]; then
        # 檢查最終檔案是否存在
        if [ -f "$main_media_file" ]; then
            echo -e "${GREEN}${progress_prefix}處理完成！檔案已儲存至：$main_media_file${RESET}";
            log_message "SUCCESS" "${progress_prefix}處理完成 (無標準化)！檔案：$main_media_file";
        else
            # 如果檔案意外消失 (理論上不該發生，除非下載本身有問題)
            echo -e "${RED}${progress_prefix}處理似乎已完成，但最終檔案 '$main_media_file' 未找到！${RESET}";
            log_message "ERROR" "${progress_prefix}處理完成但最終檔案未找到 (無標準化)";
            result=1 # 標記為失敗
        fi
    else
        echo -e "${RED}${progress_prefix}處理失敗 (無標準化)！${RESET}";
        log_message "ERROR" "${progress_prefix}處理失敗 (無標準化)：$item_url";
    fi

    # --- 條件式通知 (邏輯基本不變，確保傳遞正確路徑) ---
    if $should_notify; then
        local notification_title="媒體處理器：通用 無標準化"
        local base_msg_notify="${progress_prefix}處理 '$sanitized_title'"
        local final_path_notify=""
        # 成功時，通知的檔案路徑就是 main_media_file
        if [ $result -eq 0 ] && [ -f "$main_media_file" ]; then
             final_path_notify="$main_media_file"
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
} # 確保這是函數的結尾大括號

############################################
# 處理其他網站媒體 (通用 MP3/MP4) - 支持實驗性批量下載
# <<< 修改：加入播放清單標記傳遞 v2.4.6+ >>>
############################################
process_other_site_media_playlist() {
    local input_url=""; local choice_format=""
    local cf # Declare cf for case statement scope

    read -r -p "請輸入媒體網址 (單個或播放列表): " input_url; if [ -z "$input_url" ]; then echo -e "${RED}錯誤：未輸入！${RESET}"; return 1; fi

    log_message "INFO" "處理通用媒體/列表：$input_url"; echo -e "${YELLOW}處理通用媒體/列表：$input_url${RESET}"; echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"

    while true; do
        local cfn # Declare cfn for loop scope
        read -r -p "選擇格式 (1: MP3, 2: MP4): " cfn;
        case $cfn in
             1) cf="mp3"; break;;
             2) cf="mp4"; break;;
             *) echo "${RED}無效選項${RESET}";;
        esac;
    done;
    choice_format=$cf; log_message "INFO" "選擇格式: $choice_format"

    echo -e "${YELLOW}檢測是否為列表...${RESET}";
    local item_list_json; local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null); local jec=$?; if [ $jec -ne 0 ]; then log_message "WARNING" "dump-json 失敗..."; fi

    local item_urls=(); local item_count=0
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url
            while IFS= read -r line; do
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    item_urls+=("$url");
                fi;
            done <<< "$(echo "$item_list_json" | jq -c '. // empty | select(type == "object" and (.url != null))')"
            item_count=${#item_urls[@]};
            if [ "$item_count" -eq 0 ]; then log_message "WARNING" "透過 JQ 解析，未找到有效的 URL 項目。"; fi
        else log_message "WARNING" "dump-json 成功，但輸出為空。"; fi
    elif ! command -v jq &> /dev/null; then
        log_message "WARNING" "未找到 jq，無法自動檢測列表項目 URL。將嘗試處理原始 URL。"
        item_count=0
    fi

    if [ "$item_count" -gt 1 ]; then
        log_message "INFO" "檢測到列表 ($item_count 項)。"; echo -e "${CYAN}檢測到列表 ($item_count 項)。開始批量處理...${RESET}";
        local ci=0; local sc=0; local item_url
        for item_url in "${item_urls[@]}"; do
            ci=$((ci + 1));
            # <<< 修改：傳遞播放清單標記 >>>
            if _process_single_other_site "$item_url" "$choice_format" "$ci" "$item_count" "playlist_mode"; then
                sc=$((sc + 1));
            fi
            echo "";
        done
        echo -e "${GREEN}列表處理完成！共 $ci 項，成功 $sc 項。${RESET}"; log_message "SUCCESS" "列表 $input_url 完成！共 $ci 項，成功 $sc 項。"
    else
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理...${RESET}";
            input_url=${item_urls[0]};
        else
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL。"
            echo -e "${YELLOW}未檢測到列表，按單個處理...${RESET}";
        fi
        # <<< 修改：單個處理不傳遞標記 >>>
        _process_single_other_site "$input_url" "$choice_format" # 移除 $ci, $item_count，因為不需要了
    fi
}

#######################################################
# 處理其他網站媒體 (無音量標準化) - 支持實驗性批量下載
# <<< 修改：加入播放清單標記傳遞 v2.4.6+ >>>
#######################################################
process_other_site_media_playlist_no_normalize() {
    local input_url=""; local choice_format=""
    local cf

    read -r -p "請輸入媒體網址 (單個或播放列表，無標準化): " input_url; if [ -z "$input_url" ]; then echo -e "${RED}錯誤：未輸入！${RESET}"; return 1; fi

    log_message "INFO" "處理通用媒體/列表 (無標準化)：$input_url"; echo -e "${YELLOW}處理通用媒體/列表 (無標準化)：$input_url${RESET}"; echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"

    while true; do
        local cfn
        read -r -p "選擇下載偏好 (1: 音訊優先MP3, 2: 影片優先MP4): " cfn;
        case $cfn in
             1) cf="mp3"; break;;
             2) cf="mp4"; break;;
             *) echo "${RED}無效選項${RESET}";;
        esac;
    done;
    choice_format=$cf; log_message "INFO" "選擇格式 (無標準化): $choice_format"

    echo -e "${YELLOW}檢測是否為列表...${RESET}";
    local item_list_json; local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null); local jec=$?; if [ $jec -ne 0 ]; then log_message "WARNING" "dump-json 失敗..."; fi

    local item_urls=(); local item_count=0
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url
            while IFS= read -r line; do
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    item_urls+=("$url");
                fi;
            done <<< "$(echo "$item_list_json" | jq -c '. // empty | select(type == "object" and (.url != null))')"
            item_count=${#item_urls[@]};
            if [ "$item_count" -eq 0 ]; then log_message "WARNING" "透過 JQ 解析，未找到有效的 URL 項目。"; fi
        else log_message "WARNING" "dump-json 成功，但輸出為空。"; fi
    elif ! command -v jq &> /dev/null; then
        log_message "WARNING" "未找到 jq，無法自動檢測列表項目 URL。將嘗試處理原始 URL。"
        item_count=0
    fi

    if [ "$item_count" -gt 1 ]; then
        log_message "INFO" "檢測到列表 ($item_count 項，無標準化)。"; echo -e "${CYAN}檢測到列表 ($item_count 項)。開始批量處理 (無標準化)...${RESET}";
        local ci=0; local sc=0; local item_url
        for item_url in "${item_urls[@]}"; do
            ci=$((ci + 1));
            # <<< 修改：傳遞播放清單標記 >>>
            if _process_single_other_site_no_normalize "$item_url" "$choice_format" "$ci" "$item_count" "playlist_mode"; then
                sc=$((sc + 1));
            fi
            echo "";
        done
        echo -e "${GREEN}列表處理完成 (無標準化)！共 $ci 項，成功 $sc 項。${RESET}"; log_message "SUCCESS" "列表 $input_url (無標準化) 完成！共 $ci 項，成功 $sc 項。"
    else
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理 (無標準化)。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理 (無標準化)...${RESET}";
            input_url=${item_urls[0]};
        else
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL (無標準化)。"
            echo -e "${YELLOW}未檢測到列表，按單個處理 (無標準化)...${RESET}";
        fi
        # <<< 修改：單個處理不傳遞標記 >>>
        _process_single_other_site_no_normalize "$input_url" "$choice_format"
    fi
}

# ==================================================
# === START REFACTORED YOUTUBE PLAYLIST HANDLING ===
# ==================================================
############################################
# 新增：輔助函數 - 獲取播放清單影片數量
############################################
_get_playlist_video_count() {
    # --- 函數邏輯不變 ---
    local url="$1"; local total_videos=""
    echo -e "${YELLOW}獲取播放清單資訊...${RESET}"
    total_videos=$(yt-dlp --flat-playlist --dump-json "$url" 2>/dev/null | grep -c '^{')
    if ! [[ "$total_videos" =~ ^[0-9]+$ ]] || [ "$total_videos" -eq 0 ]; then local playlist_info=$(yt-dlp --flat-playlist --simulate "$url" 2>&1); if [[ "$playlist_info" =~ [Pp]laylist[[:space:]]+.*with[[:space:]]+([0-9]+)[[:space:]]+video ]]; then total_videos=${BASH_REMATCH[1]}; elif [[ "$playlist_info" =~ ([0-9]+)[[:space:]]+video ]]; then total_videos=$(echo "$playlist_info" | grep -o '[0-9]\+[[:space:]]\+video' | head -1 | grep -o '[0-9]\+'); fi; fi
    if ! [[ "$total_videos" =~ ^[0-9]+$ ]] || [ "$total_videos" -eq 0 ]; then local json_output=$(yt-dlp --dump-single-json "$url" 2>/dev/null); if [ -n "$json_output" ]; then local json_output_clean=$(echo "$json_output" | sed -n '/^{/,$p'); if [ -n "$json_output_clean" ] && command -v jq &>/dev/null; then if echo "$json_output_clean" | jq -e '.entries' > /dev/null 2>&1; then total_videos=$(echo "$json_output_clean" | jq '.entries | length'); elif echo "$json_output_clean" | jq -e '.n_entries' > /dev/null 2>&1; then total_videos=$(echo "$json_output_clean" | jq '.n_entries'); elif echo "$json_output_clean" | jq -e '.playlist_count' > /dev/null 2>&1; then total_videos=$(echo "$json_output_clean" | jq '.playlist_count'); fi; fi; fi; fi
    if ! [[ "$total_videos" =~ ^[0-9]+$ ]] || [ -z "$total_videos" ] || [ "$total_videos" -eq 0 ]; then log_message "ERROR" "無法獲取播放清單數量 for $url"; echo ""; else log_message "INFO" "獲取到 $total_videos 個影片 for $url"; echo "$total_videos"; fi
}
############################################
# 新增：輔助函數 - 處理 YouTube 播放清單通用流程
############################################
_process_youtube_playlist() {
    # --- 函數邏輯不變 ---
    local playlist_url="$1"; local single_item_processor_func_name="$2"
    log_message "INFO" "處理 YouTube 播放列表: $playlist_url (處理器: $single_item_processor_func_name)"
    echo -e "${YELLOW}檢測到播放清單，開始批量處理...${RESET}"

    # --- !!! 修改點開始 !!! ---
    # 先執行 _get_playlist_video_count 並捕獲其完整輸出
    local raw_count_output
    raw_count_output=$(_get_playlist_video_count "$playlist_url")
    
    # 從捕獲的輸出中，提取最後一行看起來像數字的部分
    # grep -oE '[0-9]+$' 會嘗試匹配行尾的數字
    # tail -n 1 確保只取最後一行匹配到的數字 (以防萬一有多行數字)
    local total_videos_str
    total_videos_str=$(echo "$raw_count_output" | grep -oE '[0-9]+$' | tail -n 1)

    # 檢查提取結果是否為純數字
    if ! [[ "$total_videos_str" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "無法從 _get_playlist_video_count 的輸出中提取有效的影片數量。原始輸出: $raw_count_output"
        echo -e "${RED}錯誤：無法解析播放清單數量。原始輸出:\n$raw_count_output${RESET}"
        return 1
    fi
    local total_videos="$total_videos_str" # 將提取到的純數字字串賦值給 total_videos
    # --- !!! 修改點結束 !!! ---

    # 接下來的邏輯使用已經清理過的 $total_videos 變數
    echo -e "${CYAN}播放清單共有 $total_videos 個影片${RESET}" 

    local playlist_ids_output; local yt_dlp_ids_args=(yt-dlp --flat-playlist -j "$playlist_url")
    playlist_ids_output=$("${yt_dlp_ids_args[@]}" 2>/dev/null); local gec=$?; if [ $gec -ne 0 ] || ! command -v jq &> /dev/null ; then log_message "ERROR" "無法獲取播放清單 IDs..."; echo -e "${RED}錯誤：無法獲取影片 ID 列表${RESET}"; return 1; fi
    local playlist_ids=(); while IFS= read -r id; do if [[ -n "$id" ]]; then playlist_ids+=("$id"); fi; done <<< "$(echo "$playlist_ids_output" | jq -r '.id // empty')"
    if [ ${#playlist_ids[@]} -eq 0 ]; then log_message "ERROR" "未找到影片 ID..."; echo -e "${RED}錯誤：未找到影片 ID${RESET}"; return 1; fi

    # --- 這裡的數字比較現在應該可以正常工作了 ---
    if [ ${#playlist_ids[@]} -ne "$total_videos" ]; then 
        log_message "WARNING" "ID 數量 (${#playlist_ids[@]}) 與獲取的總數 ($total_videos) 不符，將以實際 ID 數量為準..."
        echo -e "${YELLOW}警告：實際數量 (${#playlist_ids[@]}) 與預計 ($total_videos) 不符，將以下載列表為準...${RESET}"
        total_videos=${#playlist_ids[@]} # 更新 total_videos 為實際 ID 數
    fi

    local count=0; local success_count=0
    for id in "${playlist_ids[@]}"; do
        count=$((count + 1)); 
        local video_url="https://www.youtube.com/watch?v=$id"
        
        # --- 這裡的進度顯示現在也應該正常了 ---
        log_message "INFO" "[$count/$total_videos] 處理影片: $video_url"; echo -e "${CYAN}--- 正在處理第 $count/$total_videos 個影片 ---${RESET}"
        
        # 調用單個項目處理器
        if "$single_item_processor_func_name" "$video_url" "playlist_mode"; then 
            success_count=$((success_count + 1))
        else 
            log_message "WARNING" "...處理失敗: $video_url"
            echo -e "${RED}處理失敗: $video_url${RESET}" # 也可以加上用戶提示
        fi
        echo "" # 保留處理間隔的空行
    done

    echo -e "${GREEN}播放清單處理完成！共 $count 個影片，成功 $success_count 個${RESET}"; log_message "SUCCESS" "播放清單 $playlist_url 完成！共 $count 個，成功 $success_count 個"
    return 0
}

# ================================================
# === END REFACTORED YOUTUBE PLAYLIST HANDLING ===
# ================================================


############################################
# 處理 MP3 音訊（支援單一或播放清單、本機檔案）
############################################
process_mp3() {
    # --- 函數邏輯不變 ---
    read -p "輸入 YouTube 網址或本機路徑 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}
    if [ -f "$input" ]; then process_local_mp3 "$input"; elif [[ "$input" == *"list="* ]]; then _process_youtube_playlist "$input" "process_single_mp3"; else process_single_mp3 "$input"; fi
}

############################################
# 新增：處理 MP3 音訊（無音量標準化，僅網路下載）
############################################
process_mp3_no_normalize() {
    local input
    read -p "輸入 YouTube 網址 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}

    # 檢查是否為播放清單
    if [[ "$input" == *"list="* ]]; then
        # 播放清單處理，傳遞新的單項處理函數名
        _process_youtube_playlist "$input" "process_single_mp3_no_normalize"
    # 檢查是否為 YouTube 網址 (包含 youtu.be 短網址)
    elif [[ "$input" == *"youtube.com"* || "$input" == *"youtu.be"* ]]; then
        # 單一 YouTube 影片處理
        process_single_mp3_no_normalize "$input"
    else
        # 提示錯誤，此選項不支援本機檔案或非 YouTube 網址
        echo -e "${RED}錯誤：此選項僅支援 YouTube 網址。${RESET}"
        log_message "ERROR" "MP3 無標準化：輸入非 YouTube URL 或本機路徑: $input"
        return 1
    fi
}

############################################
# 處理 MP4 影片（支援單一或播放清單、本機檔案）
############################################
process_mp4() {
    # --- 函數邏輯不變 ---
    read -p "輸入 YouTube 網址或本機路徑 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}
    if [ -f "$input" ]; then process_local_mp4 "$input"; elif [[ "$input" == *"list="* ]]; then _process_youtube_playlist "$input" "process_single_mp4"; else process_single_mp4 "$input"; fi
}

############################################
# 處理 MP4 影片（無音量標準化，僅網路下載）
############################################
process_mp4_no_normalize() {
    # --- 函數邏輯不變 ---
    read -p "輸入 YouTube 網址 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}
    if [[ "$input" == *"list="* ]]; then _process_youtube_playlist "$input" "process_single_mp4_no_normalize"; elif [[ "$input" == *"youtu"* ]]; then process_single_mp4_no_normalize "$input"; else echo -e "${RED}錯誤：僅支援 YouTube 網址。${RESET}"; log_message "ERROR" "...非 YouTube URL..."; return 1; fi
}

#######################################################
# 新增：MP4 無標準化指定時段下載的入口函數(2.3.0+)
#######################################################
process_mp4_sections_entry() {
    local input
    read -p "輸入 YouTube 影片網址 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}

    # 檢查是否為播放清單
    if [[ "$input" == *"list="* ]]; then
        echo -e "${RED}錯誤：此功能（指定下載時段）目前僅支援單一 YouTube 影片，不支援播放列表。${RESET}"
        log_message "ERROR" "MP4 指定時段：使用者嘗試輸入播放列表 $input"
        return 1
    # 檢查是否為 YouTube 網址
    elif [[ "$input" == *"youtube.com"* || "$input" == *"youtu.be"* ]]; then
        # 是單一 YouTube 影片，獲取時段
        local start_time end_time
        local is_valid_time=false
        while ! $is_valid_time; do
            read -p "輸入開始時間 (HH:MM:SS 或 秒數): " start_time
            # 基礎驗證：非空
            if [ -z "$start_time" ]; then
                 echo -e "${RED}錯誤：開始時間不能為空。${RESET}"
                 continue
            fi
            # 簡單驗證格式 (HH:MM:SS 或 數字)
            if [[ "$start_time" =~ ^[0-9]+(:[0-5][0-9]){1,2}$ ]] || [[ "$start_time" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                 # 如果是 MM:SS 格式，補全為 00:MM:SS
                 if [[ "$start_time" =~ ^[0-9]+:[0-5][0-9]$ ]]; then
                     start_time="00:$start_time"
                 fi
                 is_valid_time=true
            else
                 echo -e "${RED}錯誤：開始時間格式無效，請使用 HH:MM:SS、MM:SS 或純數字秒數。${RESET}"
            fi
        done

        is_valid_time=false
        while ! $is_valid_time; do
            read -p "輸入結束時間 (HH:MM:SS 或 秒數，可選): " end_time
            # 結束時間可以為空 (下載到結尾)
            if [ -z "$end_time" ]; then
                 is_valid_time=true
                 break # 允許空值
            fi
            # 簡單驗證格式 (HH:MM:SS 或 數字)
            if [[ "$end_time" =~ ^[0-9]+(:[0-5][0-9]){1,2}$ ]] || [[ "$end_time" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                 # 如果是 MM:SS 格式，補全為 00:MM:SS
                 if [[ "$end_time" =~ ^[0-9]+:[0-5][0-9]$ ]]; then
                     end_time="00:$end_time"
                 fi
                 is_valid_time=true
            else
                 echo -e "${RED}錯誤：結束時間格式無效，請使用 HH:MM:SS、MM:SS 或純數字秒數，或留空。${RESET}"
            fi
        done

        log_message "INFO" "MP4 指定時段：URL='$input', Start='$start_time', End='$end_time'"
        # 調用實際的處理函數
        process_single_mp4_no_normalize_sections "$input" "$start_time" "$end_time"
        return $? # 返回處理函數的退出狀態

    else
        echo -e "${RED}錯誤：此選項僅支援 YouTube 網址。${RESET}"
        log_message "ERROR" "MP4 指定時段：輸入非 YouTube URL: $input"
        return 1
    fi
}

############################################
# 處理 MKV 影片（支援單一或播放清單，網路）
############################################
process_mkv() {
    read -p "輸入 YouTube 網址 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}
    
    # 暫不支援本機 MKV 處理，因為主要目標是處理網路影片的複雜字幕
    if [ -f "$input" ]; then
        echo -e "${RED}錯誤：此功能目前僅支援處理 YouTube 網路影片以保留原始字幕。${RESET}"
        log_message "ERROR" "MKV 處理：使用者嘗試輸入本機檔案 $input"
        return 1
    fi

    if [[ "$input" == *"list="* ]]; then 
        # 播放清單處理
        _process_youtube_playlist "$input" "process_single_mkv" 
    elif [[ "$input" == *"youtu"* ]]; then 
        # 單一影片處理
        process_single_mkv "$input"
    else 
        echo -e "${RED}錯誤：僅支援 YouTube 網址。${RESET}"; 
        log_message "ERROR" "MKV 處理：輸入非 YouTube URL: $input"; 
        return 1; 
    fi
}

############################################
# 動態調整執行緒數量
############################################
adjust_threads() {
    local cpu_cores current_threads=$THREADS # 保存調整前的值
    # 獲取 CPU 核心數 (保持不變)
    if command -v nproc &> /dev/null; then cpu_cores=$(nproc --all); elif [ -f /proc/cpuinfo ]; then cpu_cores=$(grep -c ^processor /proc/cpuinfo); elif command -v sysctl &> /dev/null && sysctl -n hw.ncpu > /dev/null 2>&1; then cpu_cores=$(sysctl -n hw.ncpu); else cpu_cores=4; log_message "WARNING" "無法檢測 CPU 核心數，預設計算基於 4 核心。"; fi
    if ! [[ "$cpu_cores" =~ ^[0-9]+$ ]] || [ "$cpu_cores" -lt 1 ]; then log_message "WARNING" "檢測到的 CPU 核心數 '$cpu_cores' 無效，預設計算基於 4 核心。"; cpu_cores=4; fi

    # 計算推薦執行緒數 (保持不變)
    local recommended_threads=$((cpu_cores * 3 / 4)); [ "$recommended_threads" -lt 1 ] && recommended_threads=1
    if [ $recommended_threads -gt $MAX_THREADS ]; then recommended_threads=$MAX_THREADS; elif [ $recommended_threads -lt $MIN_THREADS ]; then recommended_threads=$MIN_THREADS; fi

    # 只有在計算出的推薦值與目前值不同時才更新並儲存
    if [[ "$THREADS" != "$recommended_threads" ]]; then
        log_message "INFO" "執行緒自動調整：從 $THREADS -> $recommended_threads (基於 $cpu_cores 核心計算)"
        THREADS=$recommended_threads
        echo -e "${GREEN}執行緒已自動調整為 $THREADS (基於 CPU 核心數)${RESET}"
        # <<< 新增：儲存設定 >>>
        save_config
    else
        # 如果值沒有變化，可以選擇性地顯示訊息或保持安靜
        log_message "INFO" "自動調整執行緒檢查：目前值 ($THREADS) 已是推薦值，無需更改。"
        # echo -e "${CYAN}執行緒數量 ($THREADS) 已是自動調整的推薦值。${RESET}" # 可以取消註解此行
    fi
    # 不需要 sleep，因為它通常在腳本啟動時或從選單觸發後調用
}

############################################
# 新增：設定 Termux 啟動時詢問 (僅限 Termux)
############################################
setup_termux_autostart() {
    # 僅在 Termux 環境下執行此功能
    if [[ "$OS_TYPE" != "termux" ]]; then
        log_message "WARNING" "此功能僅適用於 Termux 環境。"
        echo -e "${YELLOW}警告：此功能僅適用於 Termux 環境。${RESET}"
        sleep 2
        return 1
    fi

    clear
    echo -e "${CYAN}--- 設定 Termux 啟動時詢問 ---${RESET}"
    echo -e "${YELLOW}此操作將修改您的 '$HOME/.bashrc' 文件。${RESET}"
    echo -e "${RED}${BOLD}警告：這將覆蓋您現有的 .bashrc 內容！${RESET}"
    echo -e "${YELLOW}如果您有自訂的 .bashrc 設定，請先備份。${RESET}"
    echo ""
    read -p "您確定要繼續嗎？ (y/n): " confirm_setup
    echo ""

    if [[ ! "$confirm_setup" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了 Termux 啟動設定。"
        echo -e "${YELLOW}已取消設定。${RESET}"
        return 1
    fi

    # --- BEGIN FIX ---
    # 再次確認腳本安裝路徑 (與腳本開頭 SCRIPT_INSTALL_PATH 保持一致)
    local target_script_path="$SCRIPT_INSTALL_PATH"

    # 檢查目標腳本是否存在
    if [ ! -f "$target_script_path" ]; then
        log_message "ERROR" "找不到目標腳本檔案 '$target_script_path'。無法設定權限和別名。"
        echo -e "${RED}錯誤：找不到腳本檔案 '$target_script_path'！${RESET}"
        echo -e "${YELLOW}請確保腳本已放置在正確位置，或先執行一次更新 (選項 8) 來下載。${RESET}"
        return 1
    fi

    # 為目標腳本添加執行權限
    echo -e "${YELLOW}正在確保腳本檔案 '$target_script_path' 具有執行權限...${RESET}"
    if chmod +x "$target_script_path"; then
        log_message "INFO" "成功設定 '$target_script_path' 的執行權限。"
        echo -e "${GREEN}  > 執行權限設定成功。${RESET}"
    else
        # 如果 chmod 失敗，可能是檔案不存在或沒有權限修改它
        log_message "ERROR" "無法設定 '$target_script_path' 的執行權限！請檢查檔案權限或腳本是否有權限修改它。"
        echo -e "${RED}錯誤：無法設定腳本的執行權限！${RESET}"
        echo -e "${YELLOW}請嘗試手動執行 'chmod +x $target_script_path'。${RESET}"
        # 決定是否繼續。這裡選擇繼續，但警告使用者。
        echo -e "${YELLOW}警告：權限設定失敗，但仍將繼續嘗試寫入 .bashrc。別名可能無法正常工作。${RESET}"
        # 如果希望更嚴格，可以在這裡取消註解 return 1
        # return 1
    fi
    # --- END FIX ---

    log_message "INFO" "開始設定 Termux 啟動腳本..."
    echo -e "${YELLOW}正在寫入設定到 ~/.bashrc ...${RESET}"

    # 使用 cat 和 EOF 將配置寫入 .bashrc
    # 注意：EOF 內的 $target_script_path 會被正確解析
cat > ~/.bashrc << EOF
# ~/.bashrc - v2 (Revised Color Handling & Alias Path)

# --- 媒體處理器啟動設定 ---

# 1. 定義別名
#    使用變數確保路徑一致性，或直接寫入絕對路徑
# alias media='$target_script_path'
#    或者使用更常見的絕對路徑寫法 (推薦，避免潛在的變數解析問題)
alias media='/data/data/com.termux/files/home/scripts/media_processor.sh'

# 2. 僅在交互式 Shell 啟動時顯示提示
if [[ \$- == *i* ]]; then
    # --- 在此處定義此 if 塊內使用的顏色變數 ---
    #     不加 local，讓它們在此 if 塊的範圍內可用
    #     使用標準 ANSI 顏色代碼
    CLR_RESET='\033[0m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[1;33m' # 加粗黃色，更醒目
    CLR_RED='\033[0;31m'
    CLR_CYAN='\033[0;36m'
    # --- 顏色定義結束 ---

    echo ""
    # 使用雙引號 "..." 確保變數 \$CLR_... 被展開
    # 使用 echo -e 確保 \033 被解釋為 ESCAPE 字元
    echo -e "\${CLR_CYAN}歡迎使用 Termux!\${CLR_RESET}"
    echo -e "\${CLR_YELLOW}是否要啟動媒體處理器？\${CLR_RESET}"
    echo -e "1) \${CLR_GREEN}立即啟動\${CLR_RESET}"
    echo -e "2) \${CLR_YELLOW}稍後啟動 (輸入 'media' 命令啟動)\${CLR_RESET}"
    echo -e "0) \${CLR_RED}不啟動\${CLR_RESET}"

    # read 命令保持不變
    read -t 60 -p "請選擇 (0-2) [60秒後自動選 2]: " choice
    choice=\${choice:-2}

    case \$choice in
        1)
            # 確保 echo -e 和雙引號的使用
            echo -e "\n\${CLR_GREEN}正在啟動媒體處理器...\${CLR_RESET}"
            # 執行腳本 (透過別名)
            media
            ;;
        2)
            echo -e "\n\${CLR_YELLOW}您可以隨時輸入 'media' 命令啟動媒體處理器\${CLR_RESET}"
            ;;
        *)
            echo -e "\n\${CLR_RED}已取消啟動媒體處理器\${CLR_RESET}"
            ;;
    esac
    echo ""
fi

# --- 媒體處理器啟動設定結束 ---

# (可選) 在此處加入您其他的 .bashrc 自訂內容

EOF
    # 注意：上面的 EOF 內部，$ 符號需要轉義 (\$) 以防止在 cat 命令執行時被當前 Shell 解析
    # 只有 $target_script_path (如果使用) 不需要轉義，因為我們希望它被解析

    # 檢查寫入是否成功 (基本檢查)
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Termux 啟動設定已成功寫入 ~/.bashrc"
        echo -e "${GREEN}設定成功！${RESET}"
        echo -e "${CYAN}請重新啟動 Termux 或執行 'source ~/.bashrc' 來讓設定生效。${RESET}"
        # 強制重新載入 .bashrc 使別名立即生效
        source ~/.bashrc
        echo -e "${CYAN}已嘗試重新載入設定，您現在應該可以使用 'media' 命令了。${RESET}"
    else
        log_message "ERROR" "寫入 ~/.bashrc 失敗！"
        echo -e "${RED}錯誤：寫入設定失敗！請檢查權限。${RESET}"
        return 1
    fi

    return 0
}

############################################
# <<< 新增：MP3 處理選單 >>>
############################################
mp3_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- MP3 相關處理 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 下載/處理 MP3 (${BOLD}含${RESET}音量標準化 / YouTube 或 本機檔案)"
        echo -e " 2. 下載 MP3 (${BOLD}無${RESET}音量標準化 / 僅限 YouTube)"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice
        read -rp "輸入選項 (0-2): " choice

        case $choice in
            1)
                process_mp3 # 調用原有的標準化處理函數
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            2)
                process_mp3_no_normalize # 調用原有的無標準化處理函數
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            0)
                return # 返回到調用它的 main_menu
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "MP3 選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}
############################################

############################################
# <<< 修改：MP4 / MKV 處理選單 (加入時段選項) >>>
############################################
mp4_mkv_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- MP4 / MKV 相關處理 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 下載/處理 MP4 (${BOLD}含${RESET}音量標準化 / YouTube 或 本機檔案)"
        echo -e " 2. 下載 MP4 (${BOLD}無${RESET}音量標準化 / 僅限 YouTube)"
        echo -e " 3. 下載/處理 MKV (${BOLD}含${RESET}音量標準化 / 僅限 YouTube / 實驗性字幕保留)"
        # <<< 新增選項 >>>
        echo -e " 4. 下載 MP4 (${BOLD}無${RESET}音量標準化 + ${YELLOW}指定時段${RESET} / 僅限單一 YouTube 影片)"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice
        # <<< 修改範圍 >>>
        read -rp "輸入選項 (0-4): " choice

        case $choice in
            1)
                process_mp4 # 調用原有的 MP4 標準化處理函數
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            2)
                process_mp4_no_normalize # 調用原有的 MP4 無標準化處理函數
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            3)
                process_mkv # 調用原有的 MKV 處理函數
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            # <<< 新增 Case >>>
            4)
                process_mp4_sections_entry # 調用新的指定時段入口函數
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            0)
                return # 返回到調用它的 main_menu
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "MP4/MKV 選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}
############################################

############################################
# <<< 新增：通用媒體下載選單 >>>
############################################
general_download_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 通用媒體下載 (實驗性) ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 下載並處理 (${BOLD}含${RESET}音量標準化 / 內部選擇 MP3/MP4)"
        echo -e " 2. 下載 (${BOLD}無${RESET}音量標準化 / 內部選擇 MP3/MP4)"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice
        read -rp "輸入選項 (0-2): " choice

        case $choice in
            1)
                process_other_site_media_playlist # 調用原有的通用標準化處理函數
                echo ""; read -p "按 Enter 返回通用下載選單..."
                ;;
            2)
                process_other_site_media_playlist_no_normalize # 調用原有的通用無標準化處理函數
                echo ""; read -p "按 Enter 返回通用下載選單..."
                ;;
            0)
                return # 返回到調用它的 main_menu
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "通用下載選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}
############################################

############################################
# <<< 新增：腳本設定與工具選單 >>>
############################################
utilities_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 腳本設定與工具 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 參數設定 (執行緒, 下載路徑, 顏色)"
        echo -e " 2. 檢視操作日誌"
        echo -e " 3. ${BOLD}檢查並更新依賴套件${RESET}"
        echo -e " 4. ${BOLD}檢查腳本更新${RESET}"
        # 根據 OS_TYPE 動態顯示 Termux 選項
        if [[ "$OS_TYPE" == "termux" ]]; then
            echo -e " 5. ${BOLD}設定 Termux 啟動時詢問${RESET}"
        fi
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice_range="0-4"
        [[ "$OS_TYPE" == "termux" ]] && choice_range="0-5" # 如果是 Termux，範圍是 0-5
        local choice
        read -rp "輸入選項 (${choice_range}): " choice

        case $choice in
            1)
                config_menu # 調用原有的設定選單函數
                # config_menu 內部處理返回，這裡不需要額外操作
                ;;
            2)
                view_log # 調用原有的檢視日誌函數
                # view_log 使用 less，退出後自動返回
                ;;
            3)
                update_dependencies # 調用原有的依賴更新函數
                # update_dependencies 內部有 "按 Enter 返回"
                ;;
            4)
                auto_update_script # 調用原有的腳本更新函數
                echo ""; read -p "按 Enter 返回工具選單..." # 確保更新後能返回
                ;;
            5)
                if [[ "$OS_TYPE" == "termux" ]]; then
                    setup_termux_autostart # 調用原有的 Termux 設定函數
                    echo ""; read -p "按 Enter 返回工具選單..." # 確保設定後能返回
                else
                    echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1
                fi
                ;;
            0)
                return # 返回到調用它的 main_menu
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "工具選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}
############################################


############################################
# 設定選單
############################################
config_menu() {
    # --- 函數邏輯不變 ---
    while true; do
        clear; echo -e "${CYAN}設定選單${RESET}"; echo -e "${YELLOW}選擇項目：${RESET}"
        echo -e "1. 設定執行緒 (當前: $THREADS)"; echo -e "2. 設定下載路徑 (當前: $DOWNLOAD_PATH)"
        echo -e "3. 啟用/關閉顏色 (當前: $(if $COLOR_ENABLED; then echo '啟用'; else echo '關閉'; fi))"
        echo -e "4. 自動調整執行緒"; echo -e "0. 返回主選單"
        read -p "輸入選項 (0-4): " choice
        case $choice in 1) configure_threads;; 2) configure_download_path;; 3) toggle_color;; 4) adjust_threads;; 0) return;; *) echo "${RED}無效選項${RESET}"; sleep 1;; esac; sleep 1
    done
}

# 設定執行緒數量
configure_threads() {
    local tt current_threads=$THREADS # 保存當前值用於提示
    read -p "設定執行緒 ($MIN_THREADS-$MAX_THREADS) [當前: $current_threads]: " tt
    if [[ "$tt" =~ ^[0-9]+$ ]] && [ "$tt" -ge "$MIN_THREADS" ] && [ "$tt" -le "$MAX_THREADS" ]; then
        THREADS=$tt
        log_message "INFO" "使用者手動設定執行緒為 $THREADS"
        echo -e "${GREEN}執行緒設為 $THREADS${RESET}"
        # <<< 新增：儲存設定 >>>
        save_config
    else
        echo -e "${RED}輸入無效或超出範圍 ($MIN_THREADS-$MAX_THREADS)。未作更改。${RESET}"
        log_message "WARNING" "使用者嘗試設定無效執行緒: $tt"
    fi
    # sleep 1 # 在 config_menu 循環中已有 sleep
}

############################################
# 設定下載路徑 (安全性增強版)
############################################
configure_download_path() {
    local sanitized_path=""
    local user_path current_path=$DOWNLOAD_PATH # 保存當前值

    # -e 允許使用 readline 編輯, -i 提供預設值 (雖然 read -p 也能顯示)
    read -e -p "設定下載路徑 [當前: $current_path]: " user_path
    # 如果使用者直接按 Enter，保留當前值
    user_path="${user_path:-$current_path}"

    # 如果使用者輸入的路徑與目前相同，則無需處理
    if [[ "$user_path" == "$current_path" ]]; then
        echo -e "${YELLOW}路徑未更改。${RESET}"
        # sleep 1 # 在 config_menu 循環中已有 sleep
        return 0
    fi

    # 使用 realpath 處理相對路徑、多餘斜線等，並移除危險字符
    # -m, --canonicalize-missing   no error if components are missing
    sanitized_path=$(realpath -m "$user_path" | sed 's/[;|&<>()$`{}]//g')

    # 安全性檢查：確保路徑在允許的範圍內 (Termux/標準 Linux Home)
    if [[ "$sanitized_path" =~ ^(/storage/emulated/0|$HOME|/data/data/com.termux/files/home) ]]; then
        # 嘗試創建目錄並檢查寫入權限
        if mkdir -p "$sanitized_path" 2>/dev/null && [ -w "$sanitized_path" ]; then
            DOWNLOAD_PATH="$sanitized_path"
            LOG_FILE="$DOWNLOAD_PATH/script_log.txt" # 同步更新日誌檔案路徑
            log_message "INFO" "使用者手動設定下載路徑為：$sanitized_path"
            echo -e "${GREEN}下載路徑已成功更新為：$sanitized_path${RESET}"
            # <<< 新增：儲存設定 >>>
            save_config
        else
            log_message "ERROR" "嘗試設定的路徑 '$sanitized_path' 無法創建或不可寫。"
            echo -e "${RED}錯誤：路徑 '$sanitized_path' 無法創建或不可寫！未作更改。${RESET}"
            # 保持舊路徑不變
        fi
    else
        log_message "SECURITY" "使用者嘗試設定越界路徑 (原始: '$user_path', 清理後: '$sanitized_path')。已阻止。"
        echo -e "${RED}安全性錯誤：路徑必須在 Termux 儲存、用戶家目錄或 Termux 私有目錄範圍內！未作更改。${RESET}"
        # 保持舊路徑不變
    fi
     # sleep 1 # 在 config_menu 循環中已有 sleep
}

############################################
# 切換顏色輸出 (修正版)
############################################
toggle_color() {
    if [ "$COLOR_ENABLED" = true ]; then
        # 如果當前是啟用狀態，則切換為禁用
        COLOR_ENABLED=false
        log_message "INFO" "使用者禁用顏色輸出"

        # >>> 修改點：呼叫 apply_color_settings 來清空顏色變數 <<<
        apply_color_settings

        # 現在 echo 時，因為顏色變數已被清空，所以不會有顏色
        echo "顏色輸出已禁用"

    else
        # 如果當前是禁用狀態，則切換為啟用
        COLOR_ENABLED=true
        log_message "INFO" "使用者啟用顏色輸出"

        # >>> 修改點：呼叫 apply_color_settings 來設置顏色變數 <<<
        apply_color_settings

        # 現在 echo 時，因為顏色變數已被設置，可以使用顏色輸出
        echo -e "${GREEN}顏色輸出已啟用${RESET}"
    fi

    # <<< 保留：將更改後的 COLOR_ENABLED 狀態儲存到設定檔 >>>
    save_config

    # 通常不需要在這裡加 sleep，因為 config_menu 循環會在返回後處理暫停
    # sleep 1
}

# 檢視日誌
view_log() {
    # --- 函數邏輯不變 ---
    if [ -f "$LOG_FILE" ]; then less -R "$LOG_FILE"; else echo -e "${RED}日誌不存在: $LOG_FILE ${RESET}"; log_message "WARNING" "日誌不存在: $LOG_FILE"; sleep 2; fi
}

############################################
# <<< 新增/替換：關於訊息 (增強版) >>>
############################################
show_about_enhanced() {
    clear
    echo -e "${CYAN}=== 關於 整合式影音處理平台 ===${RESET}"
    echo -e "---------------------------------------------"
    # --- 顯示版本和日期 ---
    echo -e "${BOLD}版本:${RESET}        ${GREEN}${SCRIPT_VERSION}${RESET}"
    # 檢查日期變數是否存在
    if [ -n "$SCRIPT_UPDATE_DATE" ]; then
        echo -e "${BOLD}更新日期:${RESET}    ${GREEN}${SCRIPT_UPDATE_DATE}${RESET}"
    fi

    # --- 顯示腳本校驗和 ---
    local current_script_checksum="無法計算"
    # 檢查 sha256sum 命令是否存在，以及 SCRIPT_INSTALL_PATH 是否已定義且檔案存在
    if command -v sha256sum &> /dev/null && [ -n "$SCRIPT_INSTALL_PATH" ] && [ -f "$SCRIPT_INSTALL_PATH" ]; then
        # 計算校驗和，只取校驗和部分
        current_script_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | awk '{print $1}')
    elif command -v sha256sum &> /dev/null && [ -f "$0" ]; then
        # 如果 SCRIPT_INSTALL_PATH 無法使用，嘗試計算當前執行檔案的校驗和 ($0)
        current_script_checksum=$(sha256sum "$0" | awk '{print $1}')
        current_script_checksum="${current_script_checksum} (當前執行檔)" # 加上標註
    fi
    echo -e "${BOLD}腳本 SHA256:${RESET} ${YELLOW}${current_script_checksum}${RESET}"
    echo -e "---------------------------------------------"

    echo -e "${GREEN}主要功能特色：${RESET}"
    echo -e "- YouTube 影音下載 (MP3/MP4/MKV)"
    echo -e "- 通用網站媒體下載 (MP3/MP4, 實驗性)"
    echo -e "- 音量標準化 (EBU R128) / 無標準化選項"
    echo -e "- YouTube 字幕處理 (下載/轉換/嵌入)"
    echo -e "- 播放清單批次處理 (YouTube/通用實驗性)"
    echo -e "- 本機 MP3/MP4 音量標準化"
    echo -e "- 依賴管理與腳本自我更新 (含校驗和)"
    echo -e "- 跨平台適應 (Termux/WSL/Linux)"
    echo -e "- 設定持久化與互動式選單"
    echo -e "- 主選單重構（v2.2.0+)"
    echo -e "-「MP4片段下載」支援完成通知 (僅限Termux環境，且需加裝額外插件)(v2.3.12+)"
    echo -e "- ${BOLD}MP3/MP4/通用 下載支援條件式完成通知${RESET} (批量處理或檔案>閾值)(v2.4.13+)"

    echo -e "\n${YELLOW}使用須知：${RESET}"
    echo -e "本工具僅供個人學習與合法使用，請尊重版權並遵守當地法律。"
    echo -e "下載受版權保護的內容而導致違法，請自行承擔責任。"

    echo -e "\n${CYAN}日誌檔案位於: ${LOG_FILE}${RESET}"
    echo -e "---------------------------------------------"
    echo ""
    read -p "按 Enter 返回主選單..."
}
############################################


############################################
# <<< 修改：環境檢查 (加入 Python 庫檢查提示) >>>
############################################
check_environment() {
    local core_tools=("yt-dlp" "ffmpeg" "ffprobe" "jq" "curl" "mkvmerge") # <<< 新增 mkvmerge
    local missing_tools=()
    local python_found=false
    local python_cmd=""
    local webvtt_lib_found=false

    echo -e "${CYAN}正在進行環境檢查...${RESET}"
    log_message "INFO" "開始環境檢查 (OS: $OS_TYPE)..."

    # 檢查核心工具
    for tool in "${core_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            echo -e "${YELLOW}  - 缺少: $tool ${RESET}"
        fi
    done

    # 檢查 Python
    if command -v python3 &> /dev/null; then 
        python_found=true; python_cmd="python3"; 
    elif command -v python &> /dev/null; then 
        python_found=true; python_cmd="python"; 
    else
        missing_tools+=("python/python3")
        echo -e "${YELLOW}  - 缺少: python 或 python3 ${RESET}"
    fi
    
    # 如果找到 Python，檢查 webvtt-py 庫
    if $python_found; then
        if $python_cmd -c "import webvtt" &> /dev/null; then
            webvtt_lib_found=true
        else
             missing_tools+=("Python 庫: webvtt-py")
             echo -e "${YELLOW}  - 缺少 Python 庫: webvtt-py ${RESET}"
        fi
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        clear
        echo -e "${RED}=== 環境檢查失敗 ===${RESET}"
        echo -e "${YELLOW}缺少以下必要工具或組件：${RESET}"
        for tool in "${missing_tools[@]}"; do echo -e "${RED}  - $tool${RESET}"; done
        echo -e "\n${CYAN}請嘗試運行選項 '6' (檢查並更新依賴套件) 來自動安裝，"
        echo -e "或者根據你的系統手動安裝它們。${RESET}"
        # 提供安裝提示
        if [[ "$OS_TYPE" == "termux" ]]; then
             echo -e "${GREEN}Termux:"
             echo -e "  pkg install ffmpeg jq curl python mkvmerge python-pip" 
             echo -e "  pip install -U yt-dlp webvtt-py"
             echo -e "${RESET}"
        elif [[ "$OS_TYPE" == "wsl" || "$OS_TYPE" == "linux" ]]; then
             local install_cmd=""
             if [[ "$PACKAGE_MANAGER" == "apt" ]]; then install_cmd="sudo apt install -y ffmpeg jq curl python3 python3-pip mkvmerge"; 
             elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then install_cmd="sudo dnf install -y ffmpeg jq curl python3 python3-pip mkvmerge"; 
             elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then install_cmd="sudo yum install -y ffmpeg jq curl python3 python3-pip mkvmerge"; fi
             
             if [ -n "$install_cmd" ]; then
                 echo -e "${GREEN}WSL/Linux ($PACKAGE_MANAGER):"
                 echo -e "  $install_cmd"
                 echo -e "  $python_cmd -m pip install --upgrade --user yt-dlp webvtt-py" # 使用 --user 可能更安全
                 echo -e "${RESET}"
             else
                 echo -e "${YELLOW}請參考你的 Linux 發行版文檔安裝: ffmpeg, jq, curl, python3, pip, mkvmerge${RESET}"
                 echo -e "${YELLOW}然後執行: pip install --upgrade yt-dlp webvtt-py${RESET}"
             fi
        fi
        # 提示 webvtt-py 的單獨安裝方法
        if ! $webvtt_lib_found && $python_found; then
             echo -e "\n${YELLOW}如果僅缺少 webvtt-py 庫，請執行:${RESET}"
             echo -e "${GREEN}  pip install webvtt-py${RESET}"
        fi
        
        echo -e "\n${RED}腳本無法繼續執行，請安裝所需工具後重試。${RESET}"
        log_message "ERROR" "環境檢查失敗，缺少: ${missing_tools[*]}"
        exit 1
    fi
    echo -e "${GREEN}  > 必要工具和庫檢查通過。${RESET}"

    # --- Termux 特定儲存權限檢查 ---
    if [[ "$OS_TYPE" == "termux" ]]; then
        echo -e "${CYAN}正在檢查 Termux 儲存權限...${RESET}"
        if [ ! -d "/sdcard" ] || ! touch "/sdcard/.termux-test-write" 2>/dev/null; then
            clear
            echo -e "${RED}=== 環境檢查失敗 (Termux) ===${RESET}"
            echo -e "${YELLOW}無法存取或寫入外部存儲 (/sdcard)！${RESET}"
            echo -e "${CYAN}請先在 Termux 中執行以下命令授予權限：${RESET}"
            echo -e "${GREEN}termux-setup-storage${RESET}"
            echo -e "${CYAN}然後重新啟動 Termux 和此腳本。${RESET}"
            log_message "ERROR" "環境檢查失敗：無法存取或寫入 /sdcard"
            rm -f "/sdcard/.termux-test-write"
            exit 1
        else
            rm -f "/sdcard/.termux-test-write"
             echo -e "${GREEN}  > Termux 儲存權限正常。${RESET}"
        fi
    fi # 結束 Termux 特定檢查

    # --- 通用下載和臨時目錄檢查 ---
    echo -e "${CYAN}正在檢查目錄權限...${RESET}"
    if [ -z "$DOWNLOAD_PATH" ]; then
         echo -e "${RED}錯誤：下載目錄路徑未設定！${RESET}"; log_message "ERROR" "環境檢查失敗：下載目錄未設定。"; exit 1;
    elif ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建下載目錄：$DOWNLOAD_PATH ${RESET}"; log_message "ERROR" "環境檢查失敗：無法創建下載目錄 $DOWNLOAD_PATH"; exit 1;
    elif [ ! -w "$DOWNLOAD_PATH" ]; then
         echo -e "${RED}錯誤：下載目錄不可寫：$DOWNLOAD_PATH ${RESET}"; log_message "ERROR" "環境檢查失敗：下載目錄不可寫 $DOWNLOAD_PATH"; exit 1;
    else
         echo -e "${GREEN}  > 下載目錄 '$DOWNLOAD_PATH' 可寫。${RESET}"
    fi

    if [ -z "$TEMP_DIR" ]; then
         echo -e "${RED}錯誤：臨時目錄路徑未設定！${RESET}"; log_message "ERROR" "環境檢查失敗：臨時目錄未設定。"; exit 1;
    elif ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建臨時目錄：$TEMP_DIR ${RESET}"; log_message "ERROR" "環境檢查失敗：無法創建臨時目錄 $TEMP_DIR"; exit 1;
    elif [ ! -w "$TEMP_DIR" ]; then
         echo -e "${RED}錯誤：臨時目錄不可寫：$TEMP_DIR ${RESET}"; log_message "ERROR" "環境檢查失敗：臨時目錄不可寫 $TEMP_DIR"; exit 1;
    else
         echo -e "${GREEN}  > 臨時目錄 '$TEMP_DIR' 可寫。${RESET}"
    fi

    log_message "INFO" "環境檢查通過。"
    echo -e "${GREEN}環境檢查通過。${RESET}"
    sleep 2
    return 0
}

############################################
# <<< 替換：新的主選單 (多層級) >>>
############################################
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 整合式影音處理平台 ${SCRIPT_VERSION} ===${RESET}"
        display_countdown # 保留倒數計時顯示
        echo -e "${YELLOW}請選擇主要功能分類：${RESET}"
        echo -e " 1. ${BOLD}MP3 相關處理${RESET} (YouTube/本機)"
        echo -e " 2. ${BOLD}MP4 / MKV 相關處理${RESET} (YouTube/本機)"
        echo -e " 3. ${BOLD}通用媒體下載${RESET} (其他網站 / ${YELLOW}實驗性${RESET})"
        echo -e "---------------------------------------------"
        echo -e " 4. ${BOLD}腳本設定與工具${RESET}"
        echo -e " 5. ${BOLD}關於此工具${RESET}"
        echo -e " 0. ${RED}退出腳本${RESET}"
        echo -e "---------------------------------------------"

        # 清除可能的緩衝輸入
        read -t 0.1 -N 10000 discard

        local choice
        read -rp "輸入選項 (0-5): " choice

        case $choice in
            1) mp3_menu ;;           # 跳轉到 MP3 子選單
            2) mp4_mkv_menu ;;       # 跳轉到 MP4/MKV 子選單
            3) general_download_menu ;; # 跳轉到通用下載子選單
            4) utilities_menu ;;     # 跳轉到設定與工具子選單
            5) show_about_enhanced ;; # 顯示增強的關於訊息
            0)
                echo -e "${GREEN}感謝使用，正在退出...${RESET}"
                log_message "INFO" "使用者選擇退出。"
                sleep 1
                exit 0
                ;;
            *)
                # 處理無效輸入或空輸入
                if [[ -z "$choice" ]]; then
                    continue # 如果是空輸入，重新顯示選單
                else
                    echo -e "${RED}無效選項 '$choice'${RESET}"
                    log_message "WARNING" "主選單輸入無效選項: $choice"
                    sleep 1
                fi
                ;;
        esac
    done
}
############################################


# --- 在主要函數執行前，調用檢測函數並初始化路徑 ---
# <<< 新增：調用平台檢測函數 >>>
detect_platform_and_set_vars

# <<< 新增：使用檢測到的預設值初始化路徑變數 >>>
DOWNLOAD_PATH="${USER_CONFIG_DOWNLOAD_PATH:-$DOWNLOAD_PATH_DEFAULT}"
TEMP_DIR="${USER_CONFIG_TEMP_DIR:-$TEMP_DIR_DEFAULT}"
LOG_FILE="$DOWNLOAD_PATH/script_log.txt" # 根據最終的 DOWNLOAD_PATH 設定日誌檔

# <<< 新增：確保最終目錄存在 >>>
if [ -z "$DOWNLOAD_PATH" ] || [ -z "$TEMP_DIR" ]; then
    # 在 log_message 可用前不能調用，所以直接 echo 錯誤並退出
    echo -e "${RED}錯誤：下載路徑或臨時目錄未能成功設定！腳本無法啟動。${RESET}" >&2
    exit 1
fi
# 嘗試創建目錄，如果失敗則報錯退出
if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
    echo -e "${RED}錯誤：無法創建下載目錄 '$DOWNLOAD_PATH'！請檢查權限。腳本無法啟動。${RESET}" >&2
    exit 1
fi
if ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
     echo -e "${RED}錯誤：無法創建臨時目錄 '$TEMP_DIR'！腳本無法啟動。${RESET}" >&2
     exit 1
fi

# 主程式
main() {
    # --- 設定預設值 (假設這些已在腳本頂部完成) ---
    # DEFAULT_URL="..."; THREADS=4; MAX_THREADS=8; MIN_THREADS=1; COLOR_ENABLED=true; etc.
    # DOWNLOAD_PATH="$DOWNLOAD_PATH_DEFAULT"; TEMP_DIR="$TEMP_DIR_DEFAULT"; etc.

    # --- <<< 新增：載入使用者設定檔 >>> ---
    #      這會覆蓋上面設定的預設值（如果設定檔存在且有效）
    #      並且會根據最終的 DOWNLOAD_PATH 更新 LOG_FILE
    load_config

    # --- <<< 新增：應用載入後的顏色設定 >>> ---
    #      這一步會根據 load_config 後的 COLOR_ENABLED 值，
    #      正確地定義 RED, GREEN 等變數。
    apply_color_settings

    # --- 在 load_config 之後記錄啟動訊息，因為 LOG_FILE 路徑此時才最終確定 ---
    log_message "INFO" "腳本啟動 (版本: $SCRIPT_VERSION, OS: $OS_TYPE, Config: $CONFIG_FILE)"

    # --- 環境檢查 (現在會使用載入後的 DOWNLOAD_PATH 和 TEMP_DIR) ---
    if ! check_environment; then
        # check_environment 內部會在失敗時 exit
        return 1
    fi

    # --- 自動調整執行緒 (可能會根據載入的或預設的 THREADS 再次調整並儲存) ---
    adjust_threads
    # 給使用者一點時間看到調整結果
    sleep 0

    # --- 進入主選單 ---
    main_menu
}

# --- 執行主函數 ---
main
