#!/bin/bash

# 腳本設定
SCRIPT_VERSION="v2.5.3-beta.28" # <<< 版本號更新
############################################
# <<< 新增：腳本更新日期 >>>
############################################
SCRIPT_UPDATE_DATE="2025-06-05" # 請根據實際情況修改此日期
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
# --- 日誌級別終端顯示設定 (預設值) ---
# 這些變數將控制對應級別的訊息是否默認顯示在終端
# true = 顯示在終端, false = 不顯示在終端 (但仍寫入日誌)
TERMINAL_LOG_SHOW_INFO="true"
TERMINAL_LOG_SHOW_WARNING="true"
TERMINAL_LOG_SHOW_ERROR="true"
TERMINAL_LOG_SHOW_SUCCESS="true"
TERMINAL_LOG_SHOW_DEBUG="false"  # DEBUG 預設不在終端顯示
TERMINAL_LOG_SHOW_SECURITY="true"
# 您可以根據需要添加更多級別
# --- 【重要】路徑設定 (根據您的實際情況修改) ---
# 假設您將 GitHub 倉庫 clone 到 $HOME/media-processor-updates
# 並且所有腳本 (bash + python) 都在倉庫根目錄下

# 主 Bash 腳本的完整路徑
SCRIPT_INSTALL_PATH="$HOME/media-processor-updates/media_processor.sh"

# Python 輔助腳本的完整路徑 (也在根目錄)（偵測檔案大小）
PYTHON_ESTIMATOR_SCRIPT_PATH="$HOME/media-processor-updates/estimate_size.py" # <<< 修改路徑

# Python 輔助腳本的完整路徑 (也在根目錄)（備份功能）
PYTHON_SYNC_HELPER_SCRIPT_PATH="$HOME/media-processor-updates/sync_helper.py" # <<< 新增

# Python 版本變數保留 (現在由設定檔管理，不再需要遠程檢查)
PYTHON_CONVERTER_VERSION="1.0.0" # 可以設定一個基礎版本或從設定檔讀取

# SCRIPT_DIR 應該指向 Git 倉庫的根目錄
SCRIPT_DIR="$HOME/media-processor-updates" # <<< 直接設定為倉庫根目錄
# 或者通過 SCRIPT_INSTALL_PATH 推導 (如果 SCRIPT_INSTALL_PATH 格式固定)
# SCRIPT_DIR=$(dirname "$SCRIPT_INSTALL_PATH")

# --- 檢查 SCRIPT_DIR 是否是有效的 Git 倉庫根目錄 ---
if [ ! -d "$SCRIPT_DIR/.git" ]; then
    echo -e "\033[0;31m[錯誤] SCRIPT_DIR ('$SCRIPT_DIR') 看起來不是有效的 Git 倉庫根目錄！\033[0m" >&2
    echo -e "\033[0;33m[提示] 請確保您已通過 'git clone' 獲取專案，並正確設定了 SCRIPT_INSTALL_PATH 和 SCRIPT_DIR。\033[0m" >&2
    # exit 1 # 首次運行或未 clone 時可能觸發，暫不退出，但更新功能會失敗
fi
# -------------------------------------------------------

# --- 平台偵測相關變數 ---
OS_TYPE="unknown"
DOWNLOAD_PATH_DEFAULT="" # 會被 detect_platform_and_set_vars 設定
TEMP_DIR_DEFAULT=""      # 會被 detect_platform_and_set_vars 設定
PACKAGE_MANAGER=""

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

############################################
# log_message (根據全局開關控制各級別終端輸出)
############################################
log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local plain_log_message="[$timestamp] [$level] $message"
    local colored_display_message=""
    local show_on_terminal=false # 預設不顯示，由開關決定

    # 根據級別和對應的開關變數決定是否在終端顯示
    case "$level" in
        "INFO")    [[ "${TERMINAL_LOG_SHOW_INFO:-true}" == "true" ]] && show_on_terminal=true ;;
        "WARNING") [[ "${TERMINAL_LOG_SHOW_WARNING:-true}" == "true" ]] && show_on_terminal=true ;;
        "ERROR")   [[ "${TERMINAL_LOG_SHOW_ERROR:-true}" == "true" ]] && show_on_terminal=true ;;
        "SUCCESS") [[ "${TERMINAL_LOG_SHOW_SUCCESS:-true}" == "true" ]] && show_on_terminal=true ;;
        "DEBUG")   [[ "${TERMINAL_LOG_SHOW_DEBUG:-false}" == "true" ]] && show_on_terminal=true ;; # 注意預設值
        "SECURITY")[[ "${TERMINAL_LOG_SHOW_SECURITY:-true}" == "true" ]] && show_on_terminal=true ;;
        *)         show_on_terminal=true ;; # 未明確配置的級別，預設顯示
    esac

    # 構建螢幕顯示的彩色訊息 (如果需要顯示)
    if $show_on_terminal; then
        case "$level" in
            "INFO")    colored_display_message="${BLUE}${BOLD}[$timestamp] [$level]${RESET}${BLUE} $message${RESET}" ;;
            "WARNING") colored_display_message="${YELLOW}${BOLD}[$timestamp] [$level]${RESET}${YELLOW} $message${RESET}" ;;
            "ERROR")   colored_display_message="${RED}${BOLD}[$timestamp] [$level]${RESET}${RED} $message${RESET}" ;;
            "SUCCESS") colored_display_message="${GREEN}${BOLD}[$timestamp] [$level]${RESET}${GREEN} $message${RESET}" ;;
            "DEBUG")   colored_display_message="${PURPLE}${BOLD}[$timestamp] [$level]${RESET}${PURPLE} $message${RESET}" ;;
            "SECURITY") colored_display_message="${WHITE}${BOLD}[$timestamp] [${RED_BG}$level${RESET}${WHITE}] $message${RESET}" ;;
            *)         colored_display_message="$plain_log_message" ;;
        esac
    fi

    # 寫入日誌檔案 (總是執行)
    if [ -n "$LOG_FILE" ]; then
        # ... (日誌寫入邏輯，與之前的版本相同，包含目錄檢查等) ...
        if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
            local log_dir_fail_ts=$(date "+%Y-%m-%d %H:%M:%S")
            if $show_on_terminal; then
                 echo -e "${RED}${BOLD}[$log_dir_fail_ts] [ERROR]${RESET}${RED} Failed to create directory for LOG_FILE: $(dirname "$LOG_FILE")${RESET}" >&2
            else
                 echo "[$log_dir_fail_ts] [ERROR] Failed to create directory for LOG_FILE: $(dirname "$LOG_FILE")" >> "$LOG_FILE" 2>/dev/null
            fi
        elif [ ! -w "$(dirname "$LOG_FILE")" ]; then
            local log_write_fail_ts=$(date "+%Y-%m-%d %H:%M:%S")
            if $show_on_terminal; then
                echo -e "${RED}${BOLD}[$log_write_fail_ts] [ERROR]${RESET}${RED} Directory for LOG_FILE is not writable: $(dirname "$LOG_FILE")${RESET}" >&2
            else
                echo "[$log_write_fail_ts] [ERROR] Directory for LOG_FILE is not writable: $(dirname "$LOG_FILE")" >> "$LOG_FILE" 2>/dev/null
            fi
        else
            echo "$plain_log_message" >> "$LOG_FILE"
        fi
    fi

    # 螢幕顯示 (如果 $show_on_terminal 為 true)
    if $show_on_terminal; then
        echo -e "$colored_display_message"
    fi
}

############################################
# 儲存設定檔 (包含所有設定，包括同步和日誌級別)
############################################
save_config() {
    # 嘗試記錄一個 INFO 級別的日誌，如果 log_message 此時可用
    # 如果在 load_config 完全完成前調用（例如首次創建設定檔），log_message 可能還不能完全工作
    if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
        log_message "INFO" "準備儲存目前設定到 $CONFIG_FILE ..."
    else
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] (Pre-log) 準備儲存目前設定到 $CONFIG_FILE ..."
    fi

    # 使用 > 覆蓋檔案，然後用 >> 追加。確保每個 echo 命令都成功。
    # 為了增強健壯性，可以將所有 echo 命令包裹在一個 if 條件中，
    # 但這裡為了清晰，保持每個命令後用 && 連接。

    # 開始寫入設定檔，首先是文件頭註解
    echo "# --- Configuration File for Media Processor ---" > "$CONFIG_FILE" && \
    echo "# Automatically generated by the script. Do not edit manually unless you know what you are doing." >> "$CONFIG_FILE" && \
    echo "" >> "$CONFIG_FILE" && \
    
    # --- 常規腳本設定 ---
    echo "# --- General Script Settings ---" >> "$CONFIG_FILE" && \
    echo "THREADS=\"${THREADS:-4}\"" >> "$CONFIG_FILE" && \
    echo "DOWNLOAD_PATH=\"${DOWNLOAD_PATH:-$HOME/Downloads}\"" >> "$CONFIG_FILE" && \
    echo "COLOR_ENABLED=\"${COLOR_ENABLED:-true}\"" >> "$CONFIG_FILE" && \
    echo "PYTHON_CONVERTER_VERSION=\"${PYTHON_CONVERTER_VERSION:-1.0.0}\"" >> "$CONFIG_FILE" && \
    echo "" >> "$CONFIG_FILE" && \

    # --- 終端日誌級別顯示設定 ---
    echo "# --- Terminal Log Level Display Settings ---" >> "$CONFIG_FILE" && \
    echo "# Set to 'true' to show on terminal, 'false' to hide (still logs to file)." >> "$CONFIG_FILE" && \
    echo "TERMINAL_LOG_SHOW_INFO=\"${TERMINAL_LOG_SHOW_INFO:-true}\"" >> "$CONFIG_FILE" && \
    echo "TERMINAL_LOG_SHOW_WARNING=\"${TERMINAL_LOG_SHOW_WARNING:-true}\"" >> "$CONFIG_FILE" && \
    echo "TERMINAL_LOG_SHOW_ERROR=\"${TERMINAL_LOG_SHOW_ERROR:-true}\"" >> "$CONFIG_FILE" && \
    echo "TERMINAL_LOG_SHOW_SUCCESS=\"${TERMINAL_LOG_SHOW_SUCCESS:-true}\"" >> "$CONFIG_FILE" && \
    echo "TERMINAL_LOG_SHOW_DEBUG=\"${TERMINAL_LOG_SHOW_DEBUG:-false}\"" >> "$CONFIG_FILE" && \
    echo "TERMINAL_LOG_SHOW_SECURITY=\"${TERMINAL_LOG_SHOW_SECURITY:-true}\"" >> "$CONFIG_FILE" && \
    echo "" >> "$CONFIG_FILE" && \

    # --- 同步功能設定 (新手機 -> 舊手機) ---
    echo "# --- Sync Feature Settings (New Phone -> Old Phone) ---" >> "$CONFIG_FILE" && \
    echo "SYNC_SOURCE_DIR_NEW_PHONE=\"${SYNC_SOURCE_DIR_NEW_PHONE:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_TARGET_SSH_HOST_OLD_PHONE=\"${SYNC_TARGET_SSH_HOST_OLD_PHONE:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_TARGET_SSH_USER_OLD_PHONE=\"${SYNC_TARGET_SSH_USER_OLD_PHONE:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_TARGET_SSH_PORT_OLD_PHONE=\"${SYNC_TARGET_SSH_PORT_OLD_PHONE:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_TARGET_DIR_OLD_PHONE=\"${SYNC_TARGET_DIR_OLD_PHONE:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_SSH_KEY_PATH_NEW_PHONE=\"${SYNC_SSH_KEY_PATH_NEW_PHONE:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_VIDEO_EXTENSIONS=\"${SYNC_VIDEO_EXTENSIONS:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_PHOTO_EXTENSIONS=\"${SYNC_PHOTO_EXTENSIONS:-}\"" >> "$CONFIG_FILE"
    # 注意：最後一個 echo 後面不需要 && 或 ;

    # 檢查上一個 echo 命令（即寫入 SYNC_PHOTO_EXTENSIONS）是否成功
    if [ $? -eq 0 ]; then
        if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
            log_message "INFO" "設定已成功儲存到 $CONFIG_FILE"
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] (Pre-log) 設定已成功儲存到 $CONFIG_FILE"
        fi
        # echo -e "${GREEN}設定已儲存。${RESET}" # 可選的即時反饋
    else
        if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
            log_message "ERROR" "無法寫入設定檔 $CONFIG_FILE！最後一個 echo 失敗。"
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [ERROR] (Pre-log) 無法寫入設定檔 $CONFIG_FILE！最後一個 echo 失敗。" >&2
        fi
        echo -e "${RED}錯誤：無法儲存完整設定到 $CONFIG_FILE！請檢查權限和磁碟空間。${RESET}" >&2
        # sleep 2 # 讓用戶看到錯誤
    fi
}

############################################
# <<< Termux 通知輔助函數 (最終版) v2.4.22+ >>>
############################################
_send_termux_notification() {
    local result_code="$1"
    local notification_title="$2"
    local msg_content="$3"
    local final_filepath="$4"

    # 檢查環境和命令
    if [[ "$OS_TYPE" != "termux" ]] || ! command -v termux-notification &> /dev/null; then
        if [[ "$OS_TYPE" == "termux" ]] && ! command -v termux-notification &> /dev/null; then
             log_message "INFO" "未找到 termux-notification 命令，跳過通知。"
        fi
        return
    fi

    local notification_content=""
    local is_summary_notification=false

    # 判斷是否為總結通知
    if [ -z "$final_filepath" ]; then
        is_summary_notification=true
    fi

    # --- 判斷成功或失敗 ---
    if [ "$result_code" -eq 0 ]; then
        # --- 處理成功情況 ---
        if $is_summary_notification; then
            # 總結通知的成功訊息
            notification_content="✅ 成功：$msg_content"
            log_message "INFO" "準備發送 Termux 成功通知 (總結) for $msg_content"
        else
            # 單項處理的成功訊息
            local final_basename=$(basename "$final_filepath" 2>/dev/null)
            if [ -n "$final_basename" ] && [ -f "$final_filepath" ]; then
                notification_content="✅ 成功：$msg_content 已儲存為 '$final_basename'。"
                log_message "INFO" "準備發送 Termux 成功通知 (單項) for $final_basename"
            else
                # 異常情況
                notification_content="⚠️ 成功？：$msg_content 但未找到最終檔案 '$final_basename'。"
                log_message "WARNING" "準備發送 Termux 成功通知但檔案未找到 (單項) for $msg_content"
            fi
        fi
    else
        # --- 處理失敗情況 ---
        notification_content="❌ 失敗：$msg_content 處理失敗。請查看輸出或日誌。"
        if $is_summary_notification; then
            log_message "INFO" "準備發送 Termux 失敗通知 (總結) for $msg_content"
        else
             log_message "INFO" "準備發送 Termux 失敗通知 (單項) for $msg_content"
        fi
    fi

    # --- 發送通知 ---
    if [ -n "$notification_content" ]; then
        # log_message "INFO" "Termux notification content to send: [$notification_content]" # DEBUG 已移除
        if ! termux-notification --title "$notification_title" --content "$notification_content"; then
            log_message "WARNING" "執行 termux-notification 命令失敗。"
        else
            log_message "INFO" "Termux 通知已成功發送。"
        fi
    else
         log_message "WARNING" "Notification content is empty, skipping sending notification."
    fi
}

################################################################################
# 載入設定檔 (包含所有設定，並提供預設值)
# 版本：V3.1 - 優化 THREADS 驗證邏輯，全面審查
################################################################################
load_config() {
    # --- 為所有可配置變數設定初始預設值 ---
    # 這些值會在設定檔不存在、不可讀或設定檔中缺少對應條目時使用。

    # 常規設定預設值
    THREADS="${THREADS:-4}" # 預設執行緒數
    # DOWNLOAD_PATH 的預設值處理
    # 優先使用環境變數 DOWNLOAD_PATH_DEFAULT，否則使用 $HOME 下的特定預設路徑
    local default_dl_path_platform_base="${DOWNLOAD_PATH_DEFAULT:-$HOME/media_processor_downloads_default}"
    DOWNLOAD_PATH="${DOWNLOAD_PATH:-${default_dl_path_platform_base}}" # 若 DOWNLOAD_PATH 未設定，則使用上述預設
    COLOR_ENABLED="${COLOR_ENABLED:-true}" # 預設啟用顏色輸出
    PYTHON_CONVERTER_VERSION="${PYTHON_CONVERTER_VERSION:-1.0.0}" # Python 轉換器腳本的預期版本

    # 終端日誌級別顯示預設值
    TERMINAL_LOG_SHOW_INFO="${TERMINAL_LOG_SHOW_INFO:-true}"
    TERMINAL_LOG_SHOW_WARNING="${TERMINAL_LOG_SHOW_WARNING:-true}"
    TERMINAL_LOG_SHOW_ERROR="${TERMINAL_LOG_SHOW_ERROR:-true}"
    TERMINAL_LOG_SHOW_SUCCESS="${TERMINAL_LOG_SHOW_SUCCESS:-true}"
    TERMINAL_LOG_SHOW_DEBUG="${TERMINAL_LOG_SHOW_DEBUG:-false}" # Debug 資訊預設不顯示
    TERMINAL_LOG_SHOW_SECURITY="${TERMINAL_LOG_SHOW_SECURITY:-true}"

    # 同步功能設定預設值 (若未設定則為空字串，表示功能可能未配置或禁用)
    SYNC_SOURCE_DIR_NEW_PHONE="${SYNC_SOURCE_DIR_NEW_PHONE:-}"
    SYNC_TARGET_SSH_HOST_OLD_PHONE="${SYNC_TARGET_SSH_HOST_OLD_PHONE:-}"
    SYNC_TARGET_SSH_USER_OLD_PHONE="${SYNC_TARGET_SSH_USER_OLD_PHONE:-}"
    SYNC_TARGET_SSH_PORT_OLD_PHONE="${SYNC_TARGET_SSH_PORT_OLD_PHONE:-}" # SSH 端口，若為空，ssh 客戶端通常使用預設 22
    SYNC_TARGET_DIR_OLD_PHONE="${SYNC_TARGET_DIR_OLD_PHONE:-}"
    SYNC_SSH_KEY_PATH_NEW_PHONE="${SYNC_SSH_KEY_PATH_NEW_PHONE:-}" # SSH 私鑰路徑
    SYNC_VIDEO_EXTENSIONS="${SYNC_VIDEO_EXTENSIONS:-mp4,mov,mkv,webm,avi,flv,wmv}" # 預設同步的影片副檔名列表
    SYNC_PHOTO_EXTENSIONS="${SYNC_PHOTO_EXTENSIONS:-jpg,jpeg,png,heic,gif,webp,bmp,tif,tiff,raw,dng}" # 預設同步的相片副檔名列表

    # --- 記錄用於比較的初始值 (僅在此函數內使用，用於設定檔值無效時的回退) ---
    local initial_threads="$THREADS"
    local initial_dl_path="$DOWNLOAD_PATH"
    local initial_color="$COLOR_ENABLED"
    local initial_py_ver="$PYTHON_CONVERTER_VERSION"
    local initial_show_info="$TERMINAL_LOG_SHOW_INFO"
    local initial_show_warning="$TERMINAL_LOG_SHOW_WARNING"
    local initial_show_error="$TERMINAL_LOG_SHOW_ERROR"
    local initial_show_success="$TERMINAL_LOG_SHOW_SUCCESS"
    local initial_show_debug="$TERMINAL_LOG_SHOW_DEBUG"
    local initial_show_security="$TERMINAL_LOG_SHOW_SECURITY"
    local initial_sync_source_dir="$SYNC_SOURCE_DIR_NEW_PHONE"
    local initial_sync_target_ssh_host="$SYNC_TARGET_SSH_HOST_OLD_PHONE"
    local initial_sync_target_ssh_user="$SYNC_TARGET_SSH_USER_OLD_PHONE"
    local initial_sync_target_ssh_port="$SYNC_TARGET_SSH_PORT_OLD_PHONE"
    local initial_sync_target_dir="$SYNC_TARGET_DIR_OLD_PHONE"
    local initial_sync_ssh_key_path="$SYNC_SSH_KEY_PATH_NEW_PHONE"
    local initial_sync_video_extensions="$SYNC_VIDEO_EXTENSIONS"
    local initial_sync_photo_extensions="$SYNC_PHOTO_EXTENSIONS"

    # --- 開始從設定檔讀取 ---
    if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ]; then
        # 假設顏色變數 BLUE, GREEN, RESET 已在外部定義
        echo -e "${BLUE:-}正在從設定檔 $CONFIG_FILE 載入設定...${RESET:-}"

        local line_num=0
        local line var_name var_value # 宣告迴圈內使用的變數

        # 使用 IFS= 和 -r 選項來安全地讀取每一行，包括可能包含反斜線的行
        # || [ -n "$line" ] 確保處理檔案最後一行沒有換行符的情況
        while IFS= read -r line || [ -n "$line" ]; do
            ((line_num++))
            # 修剪行首尾的空白字符 (包括空格和製表符)
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            # 跳過空行和以 '#' 開頭的註解行 (允許註解前有空白)
            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi

            # 正則表達式匹配 VAR="VALUE" 或 VAR='VALUE'
            # ([A-Za-z_][A-Za-z0-9_]+) : 變數名
            # [[:space:]]*=[[:space:]]* : 等號前後的空白
            # (\"(([^\"\\]|\\.)*)\"|'(([^'\\]|\\.)*)') : 匹配雙引號或單引號括起來的值
            #   \"(([^\"\\]|\\.)*)\" : 處理雙引號，允許內部有轉義的雙引號 \" 或其他轉義字符 \\.
            #   '(([^'\\]|\\.)*)' : 處理單引號，允許內部有轉義的單引號 \' 或其他轉義字符 \\. (雖然單引號內通常不進行太多轉義)
            # 這裡我們專注於處理雙引號，因為您的原始正則表達式是針對雙引號的。
            # 如果要同時支持單引號，正則表達式會更複雜。目前保持與您原始版本一致的雙引號處理。
            # BASH_REMATCH[1] 是變數名，BASH_REMATCH[2] 是引號內的原始值。
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"(([^\"\\]|\\.)*)\"[[:space:]]*$ ]]; then
                var_name="${BASH_REMATCH[1]}"
                var_value="${BASH_REMATCH[2]}" # 這是引號內的原始值，可能包含轉義序列

                # 根據變數名賦值，並進行必要的驗證
                case "$var_name" in
                    "THREADS")
                        if [[ "$var_value" =~ ^[0-9]+$ ]]; then # 檢查是否為純數字
                            # 使用算術上下文 (( )) 進行數值比較
                            if (( var_value >= ${MIN_THREADS:-1} && var_value <= ${MAX_THREADS:-8} )); then
                                THREADS="$var_value"
                            else
                                echo "載入設定警告: 設定檔中 THREADS ('$var_value') 無效或超出範圍 (${MIN_THREADS:-1}-${MAX_THREADS:-8})，使用預設 '$initial_threads'。" >&2
                                THREADS="$initial_threads" # 回退到此函數開始時的預設值
                            fi
                        else
                            echo "載入設定警告: 設定檔中 THREADS ('$var_value') 非有效數字，使用預設 '$initial_threads'。" >&2
                            THREADS="$initial_threads" # 回退
                        fi
                        ;;
                    "DOWNLOAD_PATH")
                        # 對路徑的進一步處理和驗證在設定檔讀取完畢後進行
                        DOWNLOAD_PATH="$var_value"
                        ;;
                    "COLOR_ENABLED")
                        if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then
                            COLOR_ENABLED="$var_value"
                        else
                            # 如果值不是 "true" 或 "false"，則保留初始預設值
                            COLOR_ENABLED="$initial_color"
                            echo "載入設定警告: COLOR_ENABLED ('$var_value') 無效，使用預設 '$initial_color'。" >&2
                        fi
                        ;;
                    "PYTHON_CONVERTER_VERSION")
                        # 允許設定為空字串嗎？目前的邏輯是如果設定檔中為空，則用預設值。
                        # 如果希望 "" 被視為有效設定，則應直接賦值。
                        if [ -n "$var_value" ]; then # -n 檢查字串長度是否非零
                            PYTHON_CONVERTER_VERSION="$var_value"
                        else
                            PYTHON_CONVERTER_VERSION="$initial_py_ver" # 若設定檔提供的是空值，則回退
                            echo "載入設定提示: PYTHON_CONVERTER_VERSION 為空，使用預設 '$initial_py_ver'。" >&2
                        fi
                        ;;
                    "TERMINAL_LOG_SHOW_INFO") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_INFO="$var_value"; else TERMINAL_LOG_SHOW_INFO="$initial_show_info"; fi ;;
                    "TERMINAL_LOG_SHOW_WARNING") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_WARNING="$var_value"; else TERMINAL_LOG_SHOW_WARNING="$initial_show_warning"; fi ;;
                    "TERMINAL_LOG_SHOW_ERROR") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_ERROR="$var_value"; else TERMINAL_LOG_SHOW_ERROR="$initial_show_error"; fi ;;
                    "TERMINAL_LOG_SHOW_SUCCESS") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_SUCCESS="$var_value"; else TERMINAL_LOG_SHOW_SUCCESS="$initial_show_success"; fi ;;
                    "TERMINAL_LOG_SHOW_DEBUG") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_DEBUG="$var_value"; else TERMINAL_LOG_SHOW_DEBUG="$initial_show_debug"; fi ;;
                    "TERMINAL_LOG_SHOW_SECURITY") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_SECURITY="$var_value"; else TERMINAL_LOG_SHOW_SECURITY="$initial_show_security"; fi ;;

                    # 同步相關設定直接賦值，假設其內容的有效性由使用這些變數的功能來處理
                    "SYNC_SOURCE_DIR_NEW_PHONE") SYNC_SOURCE_DIR_NEW_PHONE="$var_value" ;;
                    "SYNC_TARGET_SSH_HOST_OLD_PHONE") SYNC_TARGET_SSH_HOST_OLD_PHONE="$var_value" ;;
                    "SYNC_TARGET_SSH_USER_OLD_PHONE") SYNC_TARGET_SSH_USER_OLD_PHONE="$var_value" ;;
                    "SYNC_TARGET_SSH_PORT_OLD_PHONE") SYNC_TARGET_SSH_PORT_OLD_PHONE="$var_value" ;;
                    "SYNC_TARGET_DIR_OLD_PHONE") SYNC_TARGET_DIR_OLD_PHONE="$var_value" ;;
                    "SYNC_SSH_KEY_PATH_NEW_PHONE") SYNC_SSH_KEY_PATH_NEW_PHONE="$var_value" ;;
                    "SYNC_VIDEO_EXTENSIONS") SYNC_VIDEO_EXTENSIONS="$var_value" ;;
                    "SYNC_PHOTO_EXTENSIONS") SYNC_PHOTO_EXTENSIONS="$var_value" ;;
                    *)
                        # 忽略設定檔中未知的變數，可以選擇性地發出提示
                        # echo "載入設定提示: 未知變數 '$var_name' 在設定檔中第 $line_num 行，已忽略。" >&2
                        ;;
                esac # 結束 case "$var_name"
            else # 如果行不匹配 VAR="VALUE" 格式
                if [ -n "$line" ]; then # 僅對非空的不匹配行發出警告
                    echo "載入設定警告: 第 $line_num 行格式不符: '$line'，已忽略。" >&2
                fi
            fi # 結束 if [[ "$line" =~ ... ]]
        done < "$CONFIG_FILE" # 結束 while 迴圈

        echo -e "${GREEN:-}已成功從 $CONFIG_FILE 載入使用者設定。${RESET:-}"
        sleep 0.5
    else
        # 設定檔不存在或不可讀
        echo -e "${YELLOW:-}設定檔 $CONFIG_FILE 未找到或不可讀，將使用預設設定。${RESET:-}"
        echo -e "${CYAN:-}提示：您可以通過腳本的設定選單來更改設定，更改後將自動創建設定檔。${RESET:-}"
        sleep 1
    fi # 結束 if [ -f "$CONFIG_FILE" ... ]

    # --- 完成 DOWNLOAD_PATH 的處理與驗證 (此步驟至關重要，因為 LOG_FILE 路徑依賴它) ---
    local sanitized_dl_path_final=""
    if [ -n "$DOWNLOAD_PATH" ]; then
        # 嘗試將路徑轉換為絕對路徑，-m 選項允許路徑的組成部分不存在
        # 然後使用 sed 移除潛在的 shell 特殊字元，作為額外的安全措施。
        # 這主要防止路徑字串本身被惡意利用，而不是驗證路徑的合法性。
        sanitized_dl_path_final=$(realpath -m "$DOWNLOAD_PATH" 2>/dev/null | sed 's/[;|&<>()$`{}]//g')
    fi

    if [ -z "$sanitized_dl_path_final" ]; then
        echo -e "${RED:-}警告：設定的下載路徑 '$DOWNLOAD_PATH' 解析失敗或包含不允許的字元，或為空！${RESET:-}" >&2
        # 使用一個絕對安全的備用路徑
        DOWNLOAD_PATH="$HOME/media_processor_safe_downloads"
        echo -e "${YELLOW:-}已將下載路徑重設為安全備用路徑: $DOWNLOAD_PATH ${RESET:-}" >&2
        if ! mkdir -p "$DOWNLOAD_PATH"; then
            echo -e "${RED:-}嚴重錯誤：無法創建備用下載目錄 '$DOWNLOAD_PATH'！腳本無法繼續。${RESET:-}" >&2
            exit 1 # 嚴重錯誤，退出
        fi
    else
        DOWNLOAD_PATH="$sanitized_dl_path_final"
    fi

    # 安全性檢查：確保最終的 DOWNLOAD_PATH 在允許的操作範圍內 (白名單機制)
    # 這是為了防止腳本在系統任意位置創建目錄或文件
    if ! [[ "$DOWNLOAD_PATH" =~ ^(/storage/emulated/0|/sdcard|$HOME|/data/data/com.termux/files/home) ]]; then
        echo -e "${RED:-}安全性錯誤：最終下載路徑 '$DOWNLOAD_PATH' 不在允許的安全操作範圍內！腳本無法啟動。${RESET:-}" >&2
        exit 1 # 安全性違規，退出
    fi

    # 確保最終的下載目錄存在且可寫
    if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then # 嘗試創建目錄，抑制錯誤輸出以便自訂訊息
        echo -e "${RED:-}錯誤：無法創建最終下載目錄 '$DOWNLOAD_PATH'！請檢查路徑和權限。腳本無法啟動。${RESET:-}" >&2
        exit 1 # 目錄創建失敗，退出
    elif [ ! -w "$DOWNLOAD_PATH" ]; then
        echo -e "${RED:-}錯誤：最終下載目錄 '$DOWNLOAD_PATH' 不可寫！請檢查權限。腳本無法啟動。${RESET:-}" >&2
        exit 1 # 目錄不可寫，退出
    fi

    # --- 設定最終的 LOG_FILE 路徑 (在 DOWNLOAD_PATH 完全確定後) ---
    LOG_FILE="$DOWNLOAD_PATH/script_log.txt"

    # --- 日誌記錄已載入的設定 (假設 log_message 函數已定義並可用) ---
    # 確保 log_message 函數在記錄前是可用的
    if command -v log_message >/dev/null 2>&1; then
        log_message "INFO" "load_config: 函數執行完畢。"
        log_message "INFO" "load_config: 最終下載路徑已確認為: '$DOWNLOAD_PATH'"
        log_message "INFO" "load_config: 日誌檔案將寫入: '$LOG_FILE'"
        # 記錄一些關鍵的載入後設定以供調試
        log_message "DEBUG" "load_config: THREADS='$THREADS' (Min: ${MIN_THREADS:-1}, Max: ${MAX_THREADS:-8})"
        log_message "DEBUG" "load_config: COLOR_ENABLED='$COLOR_ENABLED'"
        log_message "DEBUG" "load_config: TERM_LOG_INFO='$TERMINAL_LOG_SHOW_INFO', TERM_LOG_DEBUG='$TERMINAL_LOG_SHOW_DEBUG'"
        log_message "DEBUG" "load_config: SYNC_SRC_DIR='$SYNC_SOURCE_DIR_NEW_PHONE', SYNC_VIDEO_EXTS='$SYNC_VIDEO_EXTENSIONS'"
    else
        echo "提示: log_message 函數未定義，部分設定載入訊息將不會寫入日誌。" >&2
    fi

} # 務必確保函數以 '}' 正確結束

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
# <<< 最終修正 v2：腳本自我更新函數 (Git, 改進變更檢查, 移除冗餘提示) >>>
############################################
auto_update_script() {
    clear
    echo -e "${CYAN}--- 使用 Git 檢查腳本更新 ---${RESET}"
    log_message "INFO" "使用者觸發 Git 腳本更新檢查。"

    # 檢查 git 命令
    if ! command -v git &> /dev/null; then
        log_message "ERROR" "未找到 'git' 命令。"; echo -e "${RED}錯誤：找不到 'git' 命令！${RESET}";
        # <<< 移除冗餘提示 >>>
        return 1
    fi

    # 獲取倉庫目錄和原始目錄
    local repo_dir="$SCRIPT_DIR"
    local original_dir=$(pwd)

    # 檢查 Git 倉庫有效性
    if [ ! -d "$repo_dir/.git" ]; then
         log_message "ERROR" "目錄 '$repo_dir' 不是有效的 Git 倉庫。"; echo -e "${RED}錯誤：目錄 '$repo_dir' 非 Git 倉庫。${RESET}"; echo -e "${YELLOW}請通過 'git clone' 獲取。${RESET}";
         # <<< 移除冗餘提示 >>>
         return 1
    fi

    log_message "INFO" "檢查 Git 倉庫: $repo_dir"
    # 切換到倉庫目錄
    if ! cd "$repo_dir"; then
        log_message "ERROR" "無法切換到倉庫目錄 '$repo_dir'"; echo -e "${RED}錯誤：無法進入倉庫目錄！${RESET}";
        # <<< 移除冗餘提示 >>>
        return 1;
    fi

    # --- <<< 修改：使用 git status 檢查本地修改 >>> ---
    echo -e "${YELLOW}檢查本地是否有未追蹤或未提交的更改...${RESET}"
    local git_status_output
    git_status_output=$(git status --porcelain) # 獲取簡潔狀態輸出
    local needs_reset=false

    if [ -n "$git_status_output" ]; then # 如果輸出不為空，說明有更改
        log_message "WARNING" "檢測到本地有未追蹤或未提交的更改。"
        echo -e "${RED}警告：檢測到本地有更改！${RESET}"
        echo -e "${YELLOW}狀態詳情:${RESET}\n$git_status_output" # 顯示狀態幫助判斷
        echo -e "${YELLOW}強行更新會覆蓋未提交的修改。${RESET}"
        read -r -p "是否要放棄本地修改並繼續？ (輸入 'yes' 確認，其他則取消): " confirm_force
        if [[ "$confirm_force" != "yes" ]]; then
            log_message "INFO" "使用者因本地更改取消操作。"
            echo -e "${YELLOW}已取消。請處理本地更改。${RESET}"
            cd "$original_dir";
            # <<< 移除冗餘提示 >>>
            return 1 # 返回失敗狀態，以便調用者知道未完成
        fi
        needs_reset=true
    else
         echo -e "${GREEN}本地無未追蹤或未提交更改。${RESET}"
    fi
    # --- 本地修改檢查結束 ---

    # --- 如果需要，執行 reset ---
    if [ "$needs_reset" = true ]; then
        echo -e "${YELLOW}正在放棄本地更改 ('git reset --hard HEAD' & 'git clean -fd')...${RESET}"
        # 放棄已追蹤檔案的修改
        if ! git reset --hard HEAD --quiet; then
             log_message "ERROR" "'git reset --hard' 失敗！"; echo -e "${RED}錯誤：放棄已追蹤檔案的更改失敗！${RESET}"; cd "$original_dir"; return 1
        fi
        # 清理未追蹤的檔案和目錄 (-f 強制, -d 清理目錄)
        if ! git clean -fd --quiet; then
             log_message "ERROR" "'git clean -fd' 失敗！"; echo -e "${RED}錯誤：清理未追蹤檔案失敗！${RESET}"; cd "$original_dir"; return 1
        fi
        echo -e "${GREEN}本地更改已放棄並清理。${RESET}"
    fi

    # --- 獲取遠端資訊 ---
    echo -e "${YELLOW}正在從遠端倉庫獲取最新資訊 (git fetch)...${RESET}"
    if ! git fetch --quiet; then
        log_message "ERROR" "'git fetch' 失敗。"; echo -e "${RED}錯誤：無法獲取遠端更新！${RESET}"; cd "$original_dir"; return 1
    fi
    log_message "INFO" "'git fetch' 成功。"

    # --- 比較版本 ---
    local local_commit=$(git rev-parse @ 2>/dev/null)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null)
    local base_commit=$(git merge-base @ @{u} 2>/dev/null)

    if [ -z "$local_commit" ] || [ -z "$remote_commit" ] || [ -z "$base_commit" ]; then
         log_message "ERROR" "無法獲取 Git commit 信息。"; echo -e "${RED}錯誤：無法比較版本。請檢查上游分支。${RESET}"; cd "$original_dir"; return 1
    fi

    # --- 判斷狀態並執行更新 (如果需要) ---
    local update_performed=false
    local update_message="" # 用於最後統一顯示

    if [ "$local_commit" = "$remote_commit" ]; then
        log_message "INFO" "腳本已是最新版本。"
        update_message="${GREEN}腳本已是最新版本。無需更新。${RESET}"
    elif [ "$local_commit" = "$base_commit" ]; then
        # 本地落後，執行更新
        log_message "INFO" "檢測到新版本。"
        echo -e "${YELLOW}檢測到新版本！${RESET}"
        read -r -p "是否立即拉取更新 (git pull)？ (y/n): " confirm_update
        if [[ "$confirm_update" =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}正在從遠端拉取更新 (git pull)...${RESET}"
            if git pull --quiet --ff-only || git pull --quiet; then
                log_message "SUCCESS" "Git pull 成功。"
                update_message="${GREEN}更新成功！${RESET}"
                update_performed=true
            else
                log_message "ERROR" "'git pull' 失敗。"; update_message="${RED}錯誤：'git pull' 失敗！請手動檢查。${RESET}"; cd "$original_dir"; return 1
            fi
        else
            log_message "INFO" "使用者取消更新。"
            update_message="${YELLOW}已取消更新。${RESET}"
        fi
    elif [ "$remote_commit" = "$base_commit" ]; then
        log_message "WARNING", "本地分支領先遠端。"
        update_message="${YELLOW}本地版本比遠端更新。無需更新。${RESET}"
    else
        log_message "WARNING", "本地和遠端分支已分叉。"
        update_message="${RED}錯誤：本地和遠端分支已分叉！無法自動更新。請手動解決。${RESET}"; cd "$original_dir"; return 1
    fi

    # --- 重新設定權限 ---
    echo -e "${YELLOW}正在確保腳本執行權限...${RESET}"
    local chmod_success=true
    if [ -f "$SCRIPT_INSTALL_PATH" ]; then if ! chmod +x "$SCRIPT_INSTALL_PATH"; then chmod_success=false; fi; else chmod_success=false; log_message "WARNING" "主腳本 '$SCRIPT_INSTALL_PATH' 不存在。"; fi
    if [ -f "$PYTHON_ENRICHER_SCRIPT_PATH" ]; then if ! chmod +x "$PYTHON_ENRICHER_SCRIPT_PATH"; then chmod_success=false; fi; fi
    if [ -f "$PYTHON_ESTIMATOR_SCRIPT_PATH" ]; then if ! chmod +x "$PYTHON_ESTIMATOR_SCRIPT_PATH"; then chmod_success=false; fi; fi
    if [ -f "$PYTHON_SYNC_HELPER_SCRIPT_PATH" ]; then if ! chmod +x "$PYTHON_SYNC_HELPER_SCRIPT_PATH"; then chmod_success=false; fi; fi # <<< 新增
    if [ "$chmod_success" = true ]; then echo -e "${GREEN}腳本執行權限已設定。${RESET}"; else echo -e "${RED}錯誤：設定部分或全部腳本權限失敗！${RESET}"; fi

    # --- 顯示最終結果 ---
    echo -e "$update_message" # 顯示更新結果
    if [ "$update_performed" = true ]; then echo -e "${CYAN}建議重新啟動腳本以應用所有更改。${RESET}"; fi

    # 切換回原始目錄
    cd "$original_dir"
    # <<< 移除所有中間的 read -p，只保留函數末尾這個 >>>
    read -p "按 Enter 返回工具選單..."
    return 0 # 返回成功（即使沒有更新也算成功完成檢查）
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
    local pkg_tools=("ffmpeg" "jq" "curl" "python")
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
    echo -e "${YELLOW}[1/4] 正在更新套件列表 (${PACKAGE_MANAGER} update)...${RESET}"
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
    echo -e "${YELLOW}[2/4] 正在安裝/更新 ${PACKAGE_MANAGER} 套件: ${pkg_tools[*]}...${RESET}"
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
    echo -e "${YELLOW}[3/4] 正在更新 pip 套件: ${pip_tools[*]}...${RESET}"
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
    
    # --- 步驟 5: 最終驗證所有工具 (核心修改處) ---
    echo -e "${YELLOW}[4/4] 正在驗證所有必要工具是否已安裝...${RESET}"
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
# 新增：傳輸同步功能 (調用 Python 輔助腳本)
############################################
perform_sync_to_old_phone() {
    clear
    echo -e "${CYAN}--- 開始同步檔案到舊手機 (使用 Python 輔助腳本) ---${RESET}"
    log_message "INFO" "使用者觸發同步到舊手機功能 (Python Helper)。"

    # --- 檢查必要設定 (與之前類似，但可以簡化，因為Python會做更詳細的檢查) ---
    local missing_configs_bash=false
    if [ -z "$SYNC_SOURCE_DIR_NEW_PHONE" ]; then echo -e "${RED}錯誤：未設定來源目錄！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_TARGET_SSH_HOST_OLD_PHONE" ]; then echo -e "${RED}錯誤：未設定目標 SSH 主機！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_TARGET_SSH_USER_OLD_PHONE" ]; then echo -e "${RED}錯誤：未設定目標 SSH 用戶名！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_TARGET_DIR_OLD_PHONE" ]; then echo -e "${RED}錯誤：未設定目標目錄！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_VIDEO_EXTENSIONS" ] && [ -z "$SYNC_PHOTO_EXTENSIONS" ]; then
        echo -e "${RED}錯誤：未設定任何影片或照片擴展名！${RESET}"; missing_configs_bash=true;
    fi

    if $missing_configs_bash; then
        log_message "ERROR" "同步功能缺少必要的 Bash 設定。"
        echo -e "${YELLOW}請先在「腳本設定與工具」->「同步功能設定」中完成設定。${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    # --- 檢查 Python 和輔助腳本 ---
    local python_executable=""
    if command -v python3 &> /dev/null; then python_executable="python3";
    elif command -v python &> /dev/null; then python_executable="python";
    else
        log_message "ERROR" "同步失敗：找不到 python 或 python3 命令。"
        echo -e "${RED}錯誤：找不到 Python 解釋器 (python/python3)！${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi
    if [ ! -f "$PYTHON_SYNC_HELPER_SCRIPT_PATH" ]; then
        log_message "ERROR" "同步失敗：找不到 Python 同步輔助腳本 '$PYTHON_SYNC_HELPER_SCRIPT_PATH'。"
        echo -e "${RED}錯誤：找不到同步輔助腳本！路徑: $PYTHON_SYNC_HELPER_SCRIPT_PATH${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi
    if [ ! -x "$PYTHON_SYNC_HELPER_SCRIPT_PATH" ]; then # 確保可執行
         chmod +x "$PYTHON_SYNC_HELPER_SCRIPT_PATH"
    fi


    # --- 構建 Python 腳本調用命令 ---
    local python_sync_cmd_array=("$python_executable" "$PYTHON_SYNC_HELPER_SCRIPT_PATH")
    python_sync_cmd_array+=("$SYNC_SOURCE_DIR_NEW_PHONE")
    python_sync_cmd_array+=("$SYNC_TARGET_SSH_HOST_OLD_PHONE")
    python_sync_cmd_array+=("$SYNC_TARGET_SSH_USER_OLD_PHONE")
    python_sync_cmd_array+=("$SYNC_TARGET_DIR_OLD_PHONE")

    if [ -n "$SYNC_TARGET_SSH_PORT_OLD_PHONE" ]; then
        python_sync_cmd_array+=("--target-ssh-port" "$SYNC_TARGET_SSH_PORT_OLD_PHONE")
    fi
    if [ -n "$SYNC_SSH_KEY_PATH_NEW_PHONE" ]; then
        python_sync_cmd_array+=("--ssh-key-path" "$SYNC_SSH_KEY_PATH_NEW_PHONE")
    fi
    if [ -n "$SYNC_VIDEO_EXTENSIONS" ]; then
        python_sync_cmd_array+=("--video-exts" "$SYNC_VIDEO_EXTENSIONS")
    fi
    if [ -n "$SYNC_PHOTO_EXTENSIONS" ]; then
        python_sync_cmd_array+=("--photo-exts" "$SYNC_PHOTO_EXTENSIONS")
    fi
    
    # 可以添加一個 dry-run 選項從 Bash 傳遞
    # local dry_run_sync=false # 或 true
    # if $dry_run_sync; then python_sync_cmd_array+=("--dry-run"); fi

    echo -e "\n${YELLOW}將調用 Python 輔助腳本執行同步...${RESET}"
    echo -e "  來源: ${GREEN}${SYNC_SOURCE_DIR_NEW_PHONE}${RESET}"
    echo -e "  目標: ${GREEN}${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}:${SYNC_TARGET_DIR_OLD_PHONE}${RESET}"
    echo -e "  (詳細參數將傳遞給 Python 腳本)"
    echo -e "---------------------------------------------"

    local confirm_py_sync
    read -p "確定開始同步嗎？ (y/n): " confirm_py_sync
    if [[ ! "$confirm_py_sync" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了 Python 同步操作。"
        echo -e "${YELLOW}同步操作已取消。${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    # --- 執行 Python 腳本 ---
    echo -e "\n${CYAN}Python 輔助腳本執行中，請參考其輸出...${RESET}"
    log_message "INFO" "執行 Python 同步腳本: ${python_sync_cmd_array[*]}"

    # 執行 Python 腳本，Python 腳本自己會處理 rsync 的終端輸出
    if "${python_sync_cmd_array[@]}"; then
        log_message "SUCCESS" "Python 同步輔助腳本報告成功。"
        echo -e "\n${GREEN}同步過程已完成 (由 Python 腳本處理)。請查看上方輸出以了解詳情。${RESET}"
        # Python 腳本內部可以調用 _send_termux_notification, 或者Bash在這裡調用
        _send_termux_notification 0 "媒體同步" "檔案同步到舊手機成功 (Python輔助)。" ""
    else
        local py_exit_code=$?
        log_message "ERROR" "Python 同步輔助腳本報告失敗！退出碼: $py_exit_code"
        echo -e "\n${RED}同步過程失敗 (由 Python 腳本處理)！退出碼: $py_exit_code${RESET}"
        echo -e "${YELLOW}請檢查 Python 腳本的輸出以了解錯誤原因。${RESET}"
        _send_termux_notification 1 "媒體同步" "檔案同步到舊手機失敗 (Python輔助，代碼: $py_exit_code)。" ""
        read -p "按 Enter 返回..."
        return 1
    fi

    read -p "按 Enter 返回..."
    return 0
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
# <<< 修改：加入基於時長 (0.35小時) 的條件式通知 >>>
############################################
process_local_mp4() {
    local video_file="$1"
    local temp_dir base output_video normalized_audio result duration_secs should_notify_local=false

    # 檢查輸入檔案是否存在
    if [ ! -f "$video_file" ]; then
        echo -e "${RED}錯誤：檔案不存在！${RESET}"
        log_message "ERROR" "process_local_mp4: 檔案不存在 '$video_file'"
        return 1
    fi

    # --- <<< 新增：獲取時長並判斷是否通知 >>> ---
    echo -e "${YELLOW}正在獲取影片時長以決定是否需要通知...${RESET}"
    local duration_secs_str duration_exit_code
    # 使用 ffprobe 獲取格式信息中的時長 (秒)
    # -v error: 只顯示錯誤訊息
    # -show_entries format=duration: 只顯示 format section 中的 duration
    # -of default=noprint_wrappers=1:nokey=1: 以簡單格式輸出值 (無鍵名和外框)
    duration_secs_str=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")
    duration_exit_code=$?

    if [ $duration_exit_code -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        duration_secs=$(printf "%.0f" "$duration_secs_str") # 四捨五入到整數秒
        local duration_threshold_secs=1260 # 0.35 小時 * 3600 秒/小時
        log_message "INFO" "本機 MP4：檔案時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (0.35小時)."

        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "本機 MP4：時長超過閾值，啟用通知。"
            should_notify_local=true
            # 給使用者一個明確的提示
            echo -e "${CYAN}提示：影片時長 ($duration_secs 秒) 超過 0.35 小時，處理完成後將發送通知。${RESET}"
            sleep 1 # 短暫停留讓使用者看到提示
        else
            log_message "INFO" "本機 MP4：時長未超過閾值，禁用通知。"
            # 時長較短，保持安靜，不打擾使用者
        fi
    else
        # 如果 ffprobe 失敗或輸出格式不對，則記錄警告並禁用通知
        log_message "WARNING" "無法從 ffprobe 獲取有效的時長資訊 (退出碼: $duration_exit_code, 輸出: '$duration_secs_str')。將禁用通知。"
        echo -e "${YELLOW}警告：無法獲取影片時長，將禁用完成通知。${RESET}"
        should_notify_local=false
    fi
    # --- 時長判斷結束 ---

    # --- 原有的處理流程開始 ---
    # 創建臨時目錄
    temp_dir=$(mktemp -d)
    # 獲取基礎檔名（不含副檔名）
    base=$(basename "$video_file" | sed 's/\.[^.]*$//')
    # 設定最終輸出檔名
    output_video="$(dirname "$video_file")/${base}_normalized.mp4"
    # 設定標準化後臨時音訊檔的路徑
    normalized_audio="$temp_dir/audio_normalized.m4a"

    echo -e "${YELLOW}處理本機影片檔案：$video_file${RESET}"
    log_message "INFO" "處理本機影片檔案：$video_file (啟用通知: $should_notify_local)"

    # 調用音量標準化函數，處理音訊部分
    # 第一個參數是輸入影片，第二個是輸出的標準化音訊（臨時），第三個是臨時目錄，第四個 true 表示是影片
    normalize_audio "$video_file" "$normalized_audio" "$temp_dir" true
    result=$? # 保存 normalize_audio 的退出狀態 (0 為成功)

    # 僅在音量標準化成功時，才進行混流
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}正在混流標準化音訊與影片...${RESET}"
        # 使用 ffmpeg 合併
        # -i "$video_file": 輸入原始影片
        # -i "$normalized_audio": 輸入標準化後的音訊
        # -c:v copy: 直接複製視訊流，不重新編碼
        # -c:a aac -b:a 256k -ar 44100: 將音訊重新編碼為 AAC，設置位元速率和取樣率
        # -map 0:v:0: 映射第一個輸入(原始影片)的第0個視訊流
        # -map 1:a:0: 映射第二個輸入(標準化音訊)的第0個音訊流
        # -movflags +faststart: 優化 MP4 檔案，使其適合網路串流
        # "$output_video": 輸出檔案路徑
        ffmpeg -y -i "$video_file" -i "$normalized_audio" \
               -c:v copy -c:a aac -b:a 256k -ar 44100 \
               -map 0:v:0 -map 1:a:0 -movflags +faststart \
               "$output_video" > "$temp_dir/ffmpeg_local_mux.log" 2>&1
        local mux_result=$? # 保存 ffmpeg 混流的退出狀態

        if [ $mux_result -ne 0 ]; then
            # 混流失敗
            echo -e "${RED}錯誤：混流失敗！詳見日誌。${RESET}"
            log_message "ERROR" "本機 MP4 混流失敗！詳見 $temp_dir/ffmpeg_local_mux.log"
            cat "$temp_dir/ffmpeg_local_mux.log" # 在控制台顯示 ffmpeg 錯誤訊息
            result=1 # 將最終結果標記為失敗
        else
            # 混流成功
            echo -e "${GREEN}混流完成${RESET}"
            log_message "INFO" "本機 MP4 混流成功。"
            # result 保持 0 (成功)
        fi
        # 清理標準化後的臨時音訊檔 (無論混流成功與否)
        safe_remove "$normalized_audio"
        rm -f "$temp_dir/ffmpeg_local_mux.log" # 清理混流日誌
    else
        # 如果 normalize_audio 失敗 (result 非 0)
        log_message "ERROR" "本機 MP4 音量標準化失敗，跳過混流。"
        # 確保清理可能存在的臨時音訊檔
        safe_remove "$normalized_audio"
    fi

    # 清理臨時目錄
    [ -d "$temp_dir" ] && rmdir "$temp_dir" 2>/dev/null

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        # 處理成功，再次確認最終檔案是否存在
        if [ -f "$output_video" ]; then
            echo -e "${GREEN}處理完成！音量標準化後的影片已儲存至：$output_video${RESET}"
            log_message "SUCCESS" "本機 MP4 處理完成！音量標準化後的影片已儲存至：$output_video"
        else
            # 理論上不應發生，但作為防禦性程式設計
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video' 未找到！${RESET}"
            log_message "ERROR" "本機 MP4 處理完成但最終檔案未找到！"
            result=1 # 將結果更正為失敗
        fi
    else
        # 處理失敗
        echo -e "${RED}處理失敗！${RESET}"
        log_message "ERROR" "本機 MP4 處理失敗：$video_file"
        # 可以考慮提示使用者原始檔案仍然存在
        # echo -e "${YELLOW}原始檔案 '$video_file' 未被修改。${RESET}"
    fi

    # --- <<< 新增：條件式通知 >>> ---
    if $should_notify_local; then
        local notification_title="媒體處理器：本機 MP4 標準化"
        local base_name_for_notify=$(basename "$video_file") # 使用原始檔名，讓使用者知道是哪個檔案
        local base_msg_notify="處理本機檔案 '$base_name_for_notify'"
        local final_path_notify=""
        # 只有在處理成功且最終檔案確實存在時，才將最終路徑傳遞給通知函數
        if [ $result -eq 0 ] && [ -f "$output_video" ]; then
            final_path_notify="$output_video"
        fi
        # 調用通用的通知函數
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi
    # --- 通知結束 ---

    # 返回最終的處理結果 (0 代表成功，非 0 代表失敗)
    return $result
}

############################################
# 處理單一 YouTube 音訊（MP3）下載與處理
# (已修正 goto, 恢復時長判斷通知)
############################################
process_single_mp3() {
    local media_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local audio_file=""
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local base_name=""
    local result=0
    local should_notify=false
    local output_audio=""
    local video_title="" video_id="" sanitized_title=""

    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    video_title=$(yt-dlp --get-title "$media_url" 2>/dev/null) || video_title="audio_$(date +%s_default)"
    video_id=$(yt-dlp --get-id "$media_url" 2>/dev/null) || video_id="id_$(date +%s_default)"

    if [[ "$video_title" == "audio_$(date +%s_default)" && -z "$(yt-dlp --get-title "$media_url" 2>/dev/null)" ]]; then
        log_message "ERROR" "無法獲取媒體標題 (標準化 MP3) for URL: $media_url"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1
    else
        sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')
    fi

    # --- <<< 恢復：基於時長判斷是否通知 (僅單獨模式) >>> ---
    if [ $result -eq 0 ] && [[ "$mode" != "playlist_mode" ]]; then
        echo -e "${YELLOW}正在獲取媒體時長以決定是否通知...${RESET}"
        local duration_secs_str duration_exit_code
        # 使用 yt-dlp 獲取時長
        duration_secs_str=$(yt-dlp --no-warnings --print '%(duration)s' "$media_url" 2>"$temp_dir/yt-dlp-duration-mp3-std.log")
        duration_exit_code=$?
        log_message "DEBUG" "yt-dlp duration print (MP3 std): code=$duration_exit_code, output=[$duration_secs_str]"

        local duration_secs=0
        if [ "$duration_exit_code" -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            duration_secs=$(printf "%.0f" "$duration_secs_str")
        else
            log_message "WARNING" "無法從 yt-dlp 獲取有效的時長資訊 (MP3 std) for $media_url."
        fi
        # 原始閾值: > 0.5 小時 (1800 秒)
        local duration_threshold_secs=1800
        log_message "INFO" "MP3 標準化：媒體時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (0.5小時)."
        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "MP3 標準化：媒體時長超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP3 標準化：媒體時長未超過閾值，禁用通知。"
            should_notify=false
        fi
    elif [[ "$mode" == "playlist_mode" ]]; then
        should_notify=false
        log_message "INFO" "MP3 標準化：播放清單模式，禁用單項時長檢查和通知。"
    fi
    # --- 時長判斷結束 ---

    # ... (函數的其餘部分與我上次提供的 process_single_mp3 修正版相同) ...
    # (下載、元數據、標準化、清理、報告、通知邏輯)

    if [ $result -eq 0 ]; then
        mkdir -p "$DOWNLOAD_PATH"
        if [ ! -w "$DOWNLOAD_PATH" ]; then
            log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH"
            echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
            result=1
        fi
    fi

    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}處理 YouTube 媒體 (MP3 標準化)：$media_url${RESET}"
        log_message "INFO" "處理 YouTube 媒體 (MP3 標準化)：$media_url (通知: $should_notify)"

        echo -e "${YELLOW}開始下載：$video_title${RESET}"
        local output_template="$DOWNLOAD_PATH/${sanitized_title} [${video_id}].%(ext)s"
        local yt_dlp_dl_args=(yt-dlp -f bestaudio -o "$output_template" "$media_url" --newline --progress --concurrent-fragments "$THREADS")
        if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-mp3-std.log"; then
            log_message "ERROR" "音訊下載失敗 (標準化)，詳見 $temp_dir/yt-dlp-mp3-std.log"
            echo -e "${RED}錯誤：音訊下載失敗${RESET}"; cat "$temp_dir/yt-dlp-mp3-std.log";
            result=1
        else
            local yt_dlp_fn_args=(yt-dlp --get-filename -f bestaudio -o "$output_template" "$media_url")
            audio_file=$("${yt_dlp_fn_args[@]}")
            if [ ! -f "$audio_file" ]; then
                log_message "ERROR" "音訊下載失敗！找不到檔案 '$audio_file'"
                echo -e "${RED}錯誤：找不到下載的檔案${RESET}";
                result=1
            else
                base_name=$(basename "$audio_file" | sed 's/\.[^.]*$//')
            fi
        fi
    fi

    local cover_image=""
    if [ $result -eq 0 ]; then
        local metadata_json
        metadata_json=$(yt-dlp --dump-json "$media_url" 2>/dev/null)
        if [ -n "$metadata_json" ]; then
            artist_name=$(echo "$metadata_json" | jq -r '.artist // .uploader // "[不明]"')
            album_artist_name=$(echo "$metadata_json" | jq -r '.uploader // "[不明]"')
        fi
        [[ "$artist_name" == "null" || -z "$artist_name" ]] && artist_name="[不明]"
        [[ "$album_artist_name" == "null" || -z "$album_artist_name" ]] && album_artist_name="[不明]"

        if [ -n "$base_name" ]; then
            cover_image="$temp_dir/cover_${base_name}.png"
            echo -e "${YELLOW}下載封面圖片...${RESET}"
            if ! download_high_res_thumbnail "$media_url" "$cover_image"; then
                cover_image=""
            fi
        else
            log_message "WARNING" "base_name 為空 (MP3 std)，無法生成封面圖片路徑。"
            cover_image=""
        fi
    fi

    if [ $result -eq 0 ]; then
        if [ -n "$base_name" ]; then
            output_audio="$DOWNLOAD_PATH/${base_name}_normalized.mp3"
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
                    log_message "ERROR" "加入封面和元數據失敗！Output: $output_audio"
                    echo -e "${RED}錯誤：加入封面和元數據失敗${RESET}";
                    result=1;
                else
                    echo -e "${GREEN}封面和元數據加入完成${RESET}";
                    safe_remove "$normalized_temp"
                fi
            else
                log_message "ERROR" "音量標準化失敗！Input: $audio_file"
                result=1;
            fi
        else
            log_message "ERROR" "base_name 為空 (MP3 std)，無法進行標準化和後續處理。"
            result=1
        fi
    fi

    log_message "INFO" "清理臨時檔案 (MP3 標準化)..."
    if [ $result -eq 0 ] && [ -f "$audio_file" ]; then
        safe_remove "$audio_file"
    elif [ $result -ne 0 ] && [ -f "$audio_file" ]; then
        log_message "INFO" "MP3標準化處理失敗，保留原始下載檔案: $audio_file"
    fi
    [ -n "$cover_image" ] && [ -f "$cover_image" ] && safe_remove "$cover_image"
    safe_remove "$temp_dir/yt-dlp-mp3-std.log" "$temp_dir/yt-dlp-duration-mp3-std.log" # 修正日誌檔名
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    if [ $result -eq 0 ]; then
        if [ -f "$output_audio" ]; then
            echo -e "${GREEN}處理完成！音量標準化後的高品質音訊已儲存至：$output_audio${RESET}"
            log_message "SUCCESS" "處理完成 (MP3 標準化)！音訊已儲存至：$output_audio"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_audio' 未找到！${RESET}";
            log_message "ERROR" "處理完成但最終檔案未找到 (MP3 標準化)";
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MP3 標準化)！${RESET}"
        log_message "ERROR" "處理失敗 (MP3 標準化)：$media_url"
    fi

    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        local notification_title="媒體處理器：MP3 標準化"
        local title_for_notify="${sanitized_title:-$video_title}"
        title_for_notify="${title_for_notify:-$(basename "$media_url" 2>/dev/null)}"
        local base_msg_notify="處理音訊 '$title_for_notify'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_audio" ]; then final_path_notify="$output_audio"; fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

#########################################################
# 處理單一 YouTube 音訊（MP3）下載（無音量標準化）
# (已修正 goto, 恢復時長判斷通知)
#########################################################
process_single_mp3_no_normalize() {
    local media_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local audio_file_raw=""
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local base_name=""
    local result=0
    local should_notify=false
    local output_audio=""
    local video_title="" video_id="" sanitized_title=""

    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    video_title=$(yt-dlp --get-title "$media_url" 2>/dev/null) || video_title="audio_$(date +%s_default)"
    video_id=$(yt-dlp --get-id "$media_url" 2>/dev/null) || video_id="id_$(date +%s_default)"

    if [[ "$video_title" == "audio_$(date +%s_default)" && -z "$(yt-dlp --get-title "$media_url" 2>/dev/null)" ]]; then
        log_message "ERROR" "無法獲取媒體標題 (無標準化 MP3) for URL: $media_url"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1
    else
        base_name=$(echo "${video_title} [${video_id}]" | sed 's@[/\\:*?"<>|]@_@g')
        sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')
    fi

    # --- <<< 恢復：基於時長判斷是否通知 (僅單獨模式) >>> ---
    if [ $result -eq 0 ] && [[ "$mode" != "playlist_mode" ]]; then
        echo -e "${YELLOW}正在獲取媒體時長以決定是否通知...${RESET}"
        local duration_secs_str duration_exit_code
        duration_secs_str=$(yt-dlp --no-warnings --print '%(duration)s' "$media_url" 2>"$temp_dir/yt-dlp-duration-mp3-nonstd.log")
        duration_exit_code=$?
        log_message "DEBUG" "yt-dlp duration print (MP3 non-std): code=$duration_exit_code, output=[$duration_secs_str]"

        local duration_secs=0
        if [ "$duration_exit_code" -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            duration_secs=$(printf "%.0f" "$duration_secs_str")
        else
            log_message "WARNING" "無法從 yt-dlp 獲取有效的時長資訊 (MP3 non-std) for $media_url."
        fi
        # 原始閾值: > 2 小時 (7200 秒)
        local duration_threshold_secs=7200
        log_message "INFO" "MP3 無標準化：媒體時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (2小時)."
        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "MP3 無標準化：媒體時長超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP3 無標準化：媒體時長未超過閾值，禁用通知。"
            should_notify=false
        fi
    elif [[ "$mode" == "playlist_mode" ]]; then
        should_notify=false
        log_message "INFO" "MP3 無標準化：播放清單模式，禁用單項時長檢查和通知。"
    fi
    # --- 時長判斷結束 ---

    # ... (函數的其餘部分與我上次提供的 process_single_mp3_no_normalize 修正版相同) ...
    # (下載、元數據、嵌入、清理、報告、通知邏輯)
    if [ $result -eq 0 ]; then
        mkdir -p "$DOWNLOAD_PATH"
        if [ ! -w "$DOWNLOAD_PATH" ]; then
            log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH"
            echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
            result=1
        fi
    fi

    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}處理 YouTube 媒體 (MP3 無標準化)：$media_url${RESET}"
        log_message "INFO" "處理 YouTube 媒體 (MP3 無標準化)：$media_url (通知: $should_notify)"

        echo -e "${YELLOW}開始下載並轉換為 MP3：$video_title${RESET}"
        local temp_audio_file="$temp_dir/temp_audio.mp3"
        local yt_dlp_dl_args=(yt-dlp -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 -o "$temp_audio_file" "$media_url" --newline --progress --concurrent-fragments "$THREADS")
        log_message "INFO" "執行 yt-dlp (MP3 無標準化): ${yt_dlp_dl_args[*]}"
        if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-mp3-nonorm.log"; then
            log_message "ERROR" "音訊下載或轉換失敗 (無標準化)，詳見 $temp_dir/yt-dlp-mp3-nonorm.log"
            echo -e "${RED}錯誤：音訊下載或轉換失敗 (無標準化)${RESET}"; cat "$temp_dir/yt-dlp-mp3-nonorm.log"
            result=1
        elif [ ! -f "$temp_audio_file" ]; then
            log_message "ERROR" "音訊下載或轉換失敗！找不到臨時 MP3 檔案 '$temp_audio_file'"
            echo -e "${RED}錯誤：找不到下載或轉換後的音訊檔案${RESET}"
            result=1
        else
            log_message "INFO" "音訊下載並轉換為 MP3 成功: $temp_audio_file"
            audio_file_raw="$temp_audio_file"
        fi
    fi

    local cover_image=""
    if [ $result -eq 0 ]; then
        local metadata_json
        metadata_json=$(yt-dlp --dump-json "$media_url" 2>/dev/null)
        if [ -n "$metadata_json" ]; then
            artist_name=$(echo "$metadata_json" | jq -r '.artist // .uploader // "[不明]"')
            album_artist_name=$(echo "$metadata_json" | jq -r '.uploader // "[不明]"')
        fi
        [[ "$artist_name" == "null" || -z "$artist_name" ]] && artist_name="[不明]"
        [[ "$album_artist_name" == "null" || -z "$album_artist_name" ]] && album_artist_name="[不明]"

        cover_image="$temp_dir/cover.jpg"
        echo -e "${YELLOW}下載封面圖片...${RESET}"
        if ! download_high_res_thumbnail "$media_url" "$cover_image"; then
            cover_image=""
        fi
    fi

    if [ $result -eq 0 ]; then
        if [ -n "$base_name" ]; then
            output_audio="$DOWNLOAD_PATH/${base_name}.mp3"
            echo -e "${YELLOW}正在加入封面和元數據 (無標準化)...${RESET}"
            local ffmpeg_embed_args=(ffmpeg -y -i "$audio_file_raw")
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
                safe_remove "$audio_file_raw"
                rm -f "$temp_dir/ffmpeg_embed.log"
            fi
        else
            log_message "ERROR" "base_name 為空 (MP3 non-std)，無法確定最終輸出檔案名。"
            result=1
        fi
    fi

    log_message "INFO" "清理臨時檔案 (MP3 無標準化)..."
    [ -n "$cover_image" ] && [ -f "$cover_image" ] && safe_remove "$cover_image"
    safe_remove "$temp_dir/yt-dlp-mp3-nonorm.log" "$temp_dir/ffmpeg_embed.log" "$temp_dir/yt-dlp-duration-mp3-nonstd.log" # 修正日誌檔名
    if [ -f "$audio_file_raw" ]; then
        safe_remove "$audio_file_raw"
    fi
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    if [ $result -eq 0 ]; then
        if [ -f "$output_audio" ]; then
            echo -e "${GREEN}處理完成！高品質 MP3 音訊已儲存至：$output_audio${RESET}"
            log_message "SUCCESS" "處理完成 (MP3 無標準化)！音訊已儲存至：$output_audio"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_audio' 未找到！${RESET}";
            log_message "ERROR" "處理完成但最終檔案未找到 (MP3 無標準化)";
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MP3 無標準化)！${RESET}"
        log_message "ERROR" "處理失敗 (MP3 無標準化)：$media_url"
    fi

    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        local notification_title="媒體處理器：MP3 無標準化"
        local title_for_notify="${sanitized_title:-$video_title}"
        title_for_notify="${title_for_notify:-$(basename "$media_url" 2>/dev/null)}"
        local base_msg_notify="處理音訊 '$title_for_notify'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_audio" ]; then final_path_notify="$output_audio"; fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

############################################
# 處理單一 YouTube 影片（MP4）下載與處理
# (已修正 goto, 恢復時長判斷通知)
############################################
process_single_mp4() {
    local video_url="$1"
    local mode="$2"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA"
    local subtitle_options_val="--write-subs --sub-lang $target_sub_langs --convert-subs srt" # 重命名避免與全局衝突
    local subtitle_files=()
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=0
    local should_notify=false
    local video_file=""
    local output_video=""
    local video_title="" video_id="" sanitized_title=""

    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video_$(date +%s_default)"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id="id_$(date +%s_default)"

    if [[ "$video_title" == "video_$(date +%s_default)" && -z "$(yt-dlp --get-title "$video_url" 2>/dev/null)" ]]; then
        log_message "ERROR" "無法獲取媒體標題 (標準化 MP4) for URL: $video_url"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1
    else
        sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')
    fi

    local format_option_val="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/best[ext=mp4]" # 重命名
    local is_youtube_url_val=true # 重命名
    if [[ "$video_url" != *"youtube.com"* && "$video_url" != *"youtu.be"* ]]; then
        is_youtube_url_val=false
        format_option_val="best"
        log_message "WARNING" "非 YouTube URL (標準化 MP4)，使用 '$format_option_val' 格式，禁用字幕。"
        subtitle_options_val=""
        echo -e "${YELLOW}非 YouTube URL，將使用 '$format_option_val' 格式且不下載字幕...${RESET}"
    fi
    log_message "INFO" "使用格式 (標準化 MP4): $format_option_val"

    # --- <<< 恢復：基於時長判斷是否通知 (僅單獨模式) >>> ---
    if [ $result -eq 0 ] && [[ "$mode" != "playlist_mode" ]]; then
        echo -e "${YELLOW}正在獲取媒體時長以決定是否通知...${RESET}"
        local duration_secs_str duration_exit_code
        duration_secs_str=$(yt-dlp --no-warnings --print '%(duration)s' "$video_url" 2>"$temp_dir/yt-dlp-duration-mp4-std.log")
        duration_exit_code=$?
        log_message "DEBUG" "yt-dlp duration print (MP4 std): code=$duration_exit_code, output=[$duration_secs_str]"

        local duration_secs=0
        if [ "$duration_exit_code" -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            duration_secs=$(printf "%.0f" "$duration_secs_str")
        else
            log_message "WARNING" "無法從 yt-dlp 獲取有效的時長資訊 (MP4 std) for $video_url."
        fi
        # 原始閾值: > 0.35 小時 (1260 秒)
        local duration_threshold_secs=1260
        log_message "INFO" "MP4 標準化：媒體時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (0.35小時)."
        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "MP4 標準化：媒體時長超過閾值，啟用通知。"
            should_notify=true
        else
            log_message "INFO" "MP4 標準化：媒體時長未超過閾值，禁用通知。"
            should_notify=false
        fi
    elif [[ "$mode" == "playlist_mode" ]]; then
        should_notify=false
        log_message "INFO" "MP4 標準化：播放清單模式，禁用單項時長檢查和通知。"
    fi
    # --- 時長判斷結束 ---

    # ... (函數的其餘部分與我上次提供的 process_single_mp4 修正版相同) ...
    # (下載、字幕、標準化、混流、清理、報告、通知邏輯)
    if [ $result -eq 0 ]; then
        mkdir -p "$DOWNLOAD_PATH"
        if [ ! -w "$DOWNLOAD_PATH" ]; then
            log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH (標準化 MP4)"
            echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
            result=1
        fi
    fi

    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}處理 YouTube 影片 (MP4 標準化)：$video_url${RESET}"
        log_message "INFO" "處理 YouTube 影片 (MP4 標準化): $video_url (通知: $should_notify)"
        if $is_youtube_url_val && [ -n "$subtitle_options_val" ]; then
            log_message "INFO" "將嘗試請求以下字幕: $target_sub_langs"
            echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕...${RESET}"
        fi

        echo -e "${YELLOW}開始下載影片及字幕...${RESET}"
        local output_template="$DOWNLOAD_PATH/${sanitized_title} [${video_id}].%(ext)s"
        local yt_dlp_dl_args=(yt-dlp -f "$format_option_val")
        if $is_youtube_url_val && [ -n "$subtitle_options_val" ]; then
            local sub_opts_array
            IFS=' ' read -r -a sub_opts_array <<< "$subtitle_options_val"
            if [ ${#sub_opts_array[@]} -gt 0 ]; then yt_dlp_dl_args+=("${sub_opts_array[@]}"); fi
        fi
        yt_dlp_dl_args+=(-o "$output_template" "$video_url" --newline --progress --concurrent-fragments "$THREADS")
        if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-video-std.log"; then
            log_message "ERROR" "影片下載失敗 (標準化)...查看 $temp_dir/yt-dlp-video-std.log"
            echo -e "${RED}錯誤：影片下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-video-std.log";
            result=1
        else
            local yt_dlp_fn_args=(yt-dlp --get-filename -f "$format_option_val" -o "$output_template" "$video_url")
            video_file=$("${yt_dlp_fn_args[@]}" 2>/dev/null)
            if [ ! -f "$video_file" ]; then
                log_message "ERROR" "找不到下載的影片檔案 (標準化)...預期基於模板: $output_template"
                echo -e "${RED}錯誤：找不到下載的影片檔案！${RESET}";
                result=1
            else
                echo -e "${GREEN}影片下載完成：$video_file${RESET}";
                log_message "INFO" "影片下載完成 (標準化)：$video_file"
            fi
        fi
    fi

    if [ $result -eq 0 ] && $is_youtube_url_val && [ -n "$subtitle_options_val" ] && [ -f "$video_file" ]; then
        local base_for_subs="${video_file%.*}"
        subtitle_files=()
        log_message "INFO" "檢查字幕 (基於: ${base_for_subs}.*.srt)"
        IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
        for lang in "${langs_to_check[@]}"; do
            local potential_srt_file="${base_for_subs}.${lang}.srt"
            if [ -f "$potential_srt_file" ]; then
                local already_added=false
                for existing_file in "${subtitle_files[@]}"; do
                    [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }
                done
                if ! $already_added; then
                    subtitle_files+=("$potential_srt_file")
                    log_message "INFO" "找到字幕: $potential_srt_file"
                    echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}"
                fi
            fi
        done
        if [ ${#subtitle_files[@]} -eq 0 ]; then
            log_message "INFO" "未找到中文字幕。"; echo -e "${YELLOW}未找到中文字幕。${RESET}";
        fi
    fi

    if [ $result -eq 0 ] && [ -f "$video_file" ]; then
        local base_for_output="${video_file%.*}"
        output_video="${base_for_output}_normalized.mp4"
        local normalized_audio_temp="$temp_dir/audio_normalized.m4a"

        echo -e "${YELLOW}開始音量標準化...${RESET}"
        if normalize_audio "$video_file" "$normalized_audio_temp" "$temp_dir" true; then
            echo -e "${YELLOW}正在混流標準化音訊、影片與字幕...${RESET}"
            local ffmpeg_mux_args=(ffmpeg -y -i "$video_file" -i "$normalized_audio_temp")
            local sub_stream_map_start_index=2
            for sub_f in "${subtitle_files[@]}"; do
                ffmpeg_mux_args+=("-sub_charenc" "UTF-8" -i "$sub_f")
            done
            ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100" "-map" "0:v:0" "-map" "1:a:0")

            if [ ${#subtitle_files[@]} -gt 0 ]; then
                ffmpeg_mux_args+=("-c:s" "mov_text")
                for ((i=0; i<${#subtitle_files[@]}; i++)); do
                    ffmpeg_mux_args+=("-map" "$((sub_stream_map_start_index + i)):0")
                    local sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
                    local ffmpeg_lang=""
                    case "$sub_lang_code" in
                        zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                        zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                        zh) ffmpeg_lang="chi" ;;
                        *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;;
                    esac
                    ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang")
                done
            fi
            ffmpeg_mux_args+=("-movflags" "+faststart" "$output_video")

            log_message "INFO" "混流命令 (MP4 std): ${ffmpeg_mux_args[*]}"
            local ffmpeg_stderr_log="$temp_dir/ffmpeg_mux_std_stderr.log"
            if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then
                echo -e "${RED}錯誤：混流失敗！詳見日誌。${RESET}";
                [ -s "$ffmpeg_stderr_log" ] && cat "$ffmpeg_stderr_log";
                log_message "ERROR" "混流失敗 (標準化 MP4)...詳見 $ffmpeg_stderr_log";
                result=1;
            else
                echo -e "${GREEN}混流完成${RESET}";
                rm -f "$ffmpeg_stderr_log";
            fi
        else
            log_message "ERROR" "音量標準化失敗！Input: $video_file";
            result=1;
        fi
    elif [ $result -eq 0 ] && [ ! -f "$video_file" ]; then
        log_message "ERROR" "內部錯誤：video_file 變數未設定或檔案不存在 (MP4 std)，無法標準化。"
        result=1;
    fi

    log_message "INFO" "清理臨時檔案 (MP4 標準化)..."
    if [ $result -eq 0 ] && [ -f "$output_video" ]; then
        safe_remove "$video_file"
    elif [ $result -ne 0 ] && [ -f "$video_file" ]; then
         log_message "INFO" "MP4 標準化處理失敗，保留原始下載檔案: $video_file"
    fi
    safe_remove "$temp_dir/audio_normalized.m4a"
    for sub_f in "${subtitle_files[@]}"; do safe_remove "$sub_f"; done
    safe_remove "$temp_dir/yt-dlp-video-std.log" "$temp_dir/yt-dlp-duration-mp4-std.log" "$temp_dir/ffmpeg_mux_std_stderr.log" # 修正日誌檔名
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    if [ $result -eq 0 ]; then
        if [ -f "$output_video" ]; then
            echo -e "${GREEN}處理完成！影片已儲存至：$output_video${RESET}";
            log_message "SUCCESS" "處理完成 (MP4 標準化)！影片已儲存至：$output_video"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video' 未找到！${RESET}";
            log_message "ERROR" "處理完成但最終檔案未找到 (MP4 標準化)";
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MP4 標準化)！${RESET}";
        log_message "ERROR" "處理失敗 (MP4 標準化)：$video_url"
    fi

    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        local notification_title="媒體處理器：MP4 標準化"
        local title_for_notify="${sanitized_title:-$video_title}"
        title_for_notify="${title_for_notify:-$(basename "$video_url" 2>/dev/null)}"
        local base_msg_notify="處理影片 '$title_for_notify'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_video" ]; then final_path_notify="$output_video"; fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

#######################################################
# 處理單一 YouTube 影片（MP4）下載與處理（無音量標準化）
# (已修正 goto)
#######################################################
process_single_mp4_no_normalize() {
    local video_url="$1"
    local mode="$2" # 播放清單模式下，mode 為 "playlist_mode"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA"
    local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt"
    local subtitle_files=()
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=0 # 預設成功
    local should_notify=false
    # local is_playlist=false # 由 mode 決定
    local ytdlp_final_media_file="" # yt-dlp 下載並可能合併後的最終媒體檔案
    local final_video_with_subs="" # 加入字幕後的最終檔案 (如果嵌入字幕)
                                   # 或與 ytdlp_final_media_file 相同 (如果無字幕)
    local video_title="" video_id="" sanitized_title="" base_name="" # 提前聲明

    # is_playlist 的判斷
    local is_playlist_mode=false
    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist_mode=true
        log_message "INFO" "MP4 無標準化：播放清單模式，單項大小估計和通知將被禁用。"
    fi

    echo -e "${YELLOW}正在分析媒體資訊 (MP4 無標準化)...${RESET}"
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video_$(date +%s_default)"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id="id_$(date +%s_default)"

    if [[ "$video_title" == "video_$(date +%s_default)" && -z "$(yt-dlp --get-title "$video_url" 2>/dev/null)" ]]; then
        log_message "ERROR" "無法獲取媒體標題 (MP4 無標準化) for URL: $video_url"
        echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"
        result=1
    else
        sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')
        # base_name 用於 yt-dlp 的輸出模板
        base_name=$(echo "${sanitized_title} [${video_id}]" | sed 's@[/\\:*?"<>|]@_@g')
        log_message "INFO" "MP4 無標準化 - 處理URL: $video_url, 標題: '$video_title', ID: '$video_id'"
    fi

    local format_option="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/bestvideo[ext=mp4][height<=1440]+bestaudio/best[ext=mp4][height<=1440]/best[height<=1440]/best"
    local is_youtube_url=true # 預設是 YouTube URL
    if [[ "$video_url" != *"youtube.com"* && "$video_url" != *"youtu.be"* ]]; then
        is_youtube_url=false
        format_option="best"
        subtitle_options="" # 非 YouTube 不處理字幕
        echo -e "${YELLOW}非 YouTube URL，使用 'best' 格式且不下載字幕...${RESET}";
        log_message "WARNING" "MP4 無標準化：非 YouTube URL ($video_url)，使用 best 格式，禁用字幕。"
    fi
    log_message "INFO" "MP4 無標準化：使用格式 '$format_option'"

    if [ $result -eq 0 ] && ! $is_playlist_mode; then # 僅單獨模式且之前無錯
        echo -e "${YELLOW}正在預估檔案大小 (使用 Python 腳本)...${RESET}"
        local estimated_size_bytes=0
        local python_estimate_output
        local python_exec=""
        if command -v python3 &> /dev/null; then python_exec="python3"; elif command -v python &> /dev/null; then python_exec="python"; fi

        if [ -n "$python_exec" ] && [ -f "$PYTHON_ESTIMATOR_SCRIPT_PATH" ]; then
            log_message "DEBUG" "Calling Python estimator (MP4 NoNorm): $python_exec $PYTHON_ESTIMATOR_SCRIPT_PATH \"$video_url\" \"$format_option\""
            python_estimate_output=$($python_exec "$PYTHON_ESTIMATOR_SCRIPT_PATH" "$video_url" "$format_option" 2> "$temp_dir/py_estimator_mp4nn_stderr.log")
            local py_exit_code=$?
            if [ $py_exit_code -eq 0 ] && [[ "$python_estimate_output" =~ ^[0-9]+$ ]]; then
                estimated_size_bytes="$python_estimate_output";
                log_message "INFO" "Python 估計大小 (MP4 NoNorm): $estimated_size_bytes bytes"
                [ ! -s "$temp_dir/py_estimator_mp4nn_stderr.log" ] && rm -f "$temp_dir/py_estimator_mp4nn_stderr.log"
            else
                log_message "WARNING" "Python 估計失敗 (MP4 NoNorm Code: $py_exit_code, Output: '$python_estimate_output'). 詳見 $temp_dir/py_estimator_mp4nn_stderr.log"
                estimated_size_bytes=0
            fi
        else
            log_message "WARNING" "找不到 Python 或估計腳本 '$PYTHON_ESTIMATOR_SCRIPT_PATH' (MP4 NoNorm)，無法估計大小。"
            estimated_size_bytes=0
        fi
        local size_threshold_gb_mp4nn=1.0
        local size_threshold_bytes_mp4nn=$(awk "BEGIN {printf \"%d\", $size_threshold_gb_mp4nn * 1024 * 1024 * 1024}")
        log_message "INFO" "檔案大小預估 (MP4 NoNorm): $estimated_size_bytes bytes, 閾值: $size_threshold_bytes_mp4nn bytes."
        if [[ "$estimated_size_bytes" -gt "$size_threshold_bytes_mp4nn" ]]; then
            log_message "INFO" "大小超過閾值 (MP4 NoNorm)，啟用通知。"; should_notify=true
        else
            log_message "INFO" "大小未超過閾值 (MP4 NoNorm)，禁用通知。"; should_notify=false
        fi
    fi

    if [ $result -eq 0 ]; then
        mkdir -p "$DOWNLOAD_PATH"
        if [ ! -w "$DOWNLOAD_PATH" ]; then
            log_message "ERROR" "無法寫入下載目錄 (MP4 NoNorm): $DOWNLOAD_PATH"; echo -e "${RED}錯誤：無法寫入目錄${RESET}";
            result=1
        fi
    fi

    local output_base_template_path="" # 初始化
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}處理 YouTube 影片 (無標準化)：$video_url${RESET}";
        log_message "INFO" "處理 YouTube 影片 (無標準化): $video_url (通知: $should_notify)";
        if $is_youtube_url && [ -n "$subtitle_options" ]; then # 僅 YouTube 且字幕選項啟用
            log_message "INFO" "嘗試字幕: $target_sub_langs";
            echo -e "${YELLOW}嘗試下載繁/簡/通用中文字幕...${RESET}"
        fi

        echo -e "${YELLOW}開始下載影片 (yt-dlp 可能會自動合併視訊和音訊)...${RESET}"
        # 確保 base_name 已定義
        if [ -z "$base_name" ]; then
            log_message "ERROR" "內部錯誤：base_name 未定義，無法繼續下載。"
            result=1
        else
            output_base_template_path="$DOWNLOAD_PATH/${base_name}" # 不含 .%(ext)s
            local output_template_for_ytdlp="${output_base_template_path}.%(ext)s"

            local yt_dlp_dl_args=(yt-dlp -f "$format_option")
            if $is_youtube_url && [ -n "$subtitle_options" ]; then
                local sub_opts_array
                IFS=' ' read -r -a sub_opts_array <<< "$subtitle_options"
                yt_dlp_dl_args+=("${sub_opts_array[@]}")
            fi
            yt_dlp_dl_args+=(-o "$output_template_for_ytdlp" --merge-output-format mp4 "$video_url" --newline --progress --concurrent-fragments "$THREADS")

            log_message "DEBUG" "執行 yt_dlp 下載 (MP4 NoNorm): ${yt_dlp_dl_args[*]}"
            "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-nonorm.log"
            local ytdlp_download_exit_code=$?

            # 預期 yt-dlp 輸出的最終檔案名
            ytdlp_final_media_file="${output_base_template_path}.mp4"

            if [ ! -f "$ytdlp_final_media_file" ]; then
                log_message "ERROR" "影片(無標準化)下載失敗。預期的檔案 '$ytdlp_final_media_file' 未找到。yt-dlp code: $ytdlp_download_exit_code. Log: $temp_dir/yt-dlp-nonorm.log";
                echo -e "${RED}錯誤：影片下載核心檔案失敗！預期的媒體檔案未找到。${RESET}";
                [ -s "$temp_dir/yt-dlp-nonorm.log" ] && cat "$temp_dir/yt-dlp-nonorm.log";
                result=1;
            elif [ $ytdlp_download_exit_code -ne 0 ]; then
                log_message "WARNING" "影片(無標準化) '$ytdlp_final_media_file' 已下載，但 yt-dlp 回報錯誤 (code: $ytdlp_download_exit_code)。可能是字幕問題。繼續處理。Log: $temp_dir/yt-dlp-nonorm.log";
                echo -e "${YELLOW}警告：影片已下載，但 yt-dlp 可能因字幕等問題回報錯誤。將嘗試繼續處理。${RESET}";
                # result 保持 0，因為核心檔案已下載
            else
                echo -e "${GREEN}影片下載及合併完成 (by yt-dlp)：$(basename "$ytdlp_final_media_file")${RESET}";
                log_message "INFO" "影片(無標準化)下載命令成功完成：$ytdlp_final_media_file"
                # result 保持 0
            fi
        fi
    fi

    # --- 字幕處理 ---
    if [ $result -eq 0 ] && $is_youtube_url && [ -n "$subtitle_options" ] && [ -f "$ytdlp_final_media_file" ]; then
        subtitle_files=() # 清空
        log_message "INFO" "檢查字幕 (基於: ${output_base_template_path}.*.srt)"
        IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
        for lang in "${langs_to_check[@]}"; do
            local potential_srt_file="${output_base_template_path}.${lang}.srt"
            if [ -f "$potential_srt_file" ]; then
                 local already_added=false
                 for existing_file in "${subtitle_files[@]}"; do [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }; done
                 if ! $already_added; then
                     subtitle_files+=("$potential_srt_file")
                     log_message "INFO" "找到字幕: $potential_srt_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}";
                 fi
            fi
        done
        if [ ${#subtitle_files[@]} -eq 0 ]; then
            log_message "INFO" "未找到請求的中文字幕。"; echo -e "${YELLOW}未找到請求的中文字幕。${RESET}";
        fi
    fi

    # --- 後處理：字幕混入 ---
    # final_video_with_subs 將是最終用於報告和通知的檔案
    if [ $result -eq 0 ] && [ -f "$ytdlp_final_media_file" ]; then # 確保核心檔案存在
        if [ ${#subtitle_files[@]} -gt 0 ]; then
            final_video_with_subs="${output_base_template_path}_with_subs.mp4"
            echo -e "${YELLOW}開始將字幕嵌入到已下載的影片中...${RESET}"
            local ffmpeg_args=(ffmpeg -hide_banner -loglevel error -y -i "$ytdlp_final_media_file")
            local sub_input_map_idx=1 # 字幕檔案從輸入索引 1 開始
            for sub_file in "${subtitle_files[@]}"; do
                ffmpeg_args+=("-sub_charenc" "UTF-8" -i "$sub_file")
            done
            ffmpeg_args+=("-c:v" "copy" "-c:a" "copy" "-map" "0:v" "-map" "0:a") # 複製視訊和所有音訊流

            local output_sub_stream_idx=0 # ffmpeg 輸出字幕流的索引
            for ((i=0; i<${#subtitle_files[@]}; i++)); do
                ffmpeg_args+=("-map" "$((sub_input_map_idx + i))") # 映射第 i 個字幕輸入
                local sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
                local ffmpeg_lang=""
                case "$sub_lang_code" in
                    zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                    zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                    zh) ffmpeg_lang="chi" ;;
                    *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;;
                esac
                ffmpeg_args+=("-metadata:s:s:${output_sub_stream_idx}" "language=$ffmpeg_lang")
                output_sub_stream_idx=$((output_sub_stream_idx + 1))
            done
            ffmpeg_args+=("-c:s" "mov_text" "-movflags" "+faststart" "$final_video_with_subs")

            log_message "INFO" "執行 FFmpeg 字幕嵌入 (MP4 NoNorm): ${ffmpeg_args[*]}"
            local ffmpeg_stderr_log="$temp_dir/ffmpeg_subs_embed.log"
            if ! "${ffmpeg_args[@]}" 2> "$ffmpeg_stderr_log"; then
                echo -e "${RED}錯誤：字幕嵌入失敗！詳情如下：${RESET}";
                [ -s "$ffmpeg_stderr_log" ] && cat "$ffmpeg_stderr_log";
                log_message "ERROR" "字幕嵌入失敗 (MP4 NoNorm)。詳見 $ffmpeg_stderr_log";
                # 字幕嵌入失敗，但原始 ytdlp_final_media_file (無字幕) 仍然存在
                # 將 final_video_with_subs 設為原始下載的檔案，以便後續報告
                final_video_with_subs="$ytdlp_final_media_file"
                # 雖然字幕失敗，但核心檔案下載成功，result 可以保持 0 或設為特定警告碼
                # 此處保持 result=0，但會在通知和報告中體現差異
                log_message "WARNING" "字幕嵌入失敗，但保留無字幕版本: $final_video_with_subs"
            else
                echo -e "${GREEN}字幕嵌入完成：$(basename "$final_video_with_subs")${RESET}";
                log_message "SUCCESS" "字幕嵌入成功：$final_video_with_subs";
                rm -f "$ffmpeg_stderr_log";
                # 成功嵌入字幕後，刪除原始無字幕版本和字幕檔
                safe_remove "$ytdlp_final_media_file";
                for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done;
            fi
        else
            # 沒有字幕需要嵌入
            log_message "INFO" "未找到字幕或無需嵌入字幕。'$ytdlp_final_media_file' 即為最終檔案。"
            # echo -e "${GREEN}影片無需額外字幕處理。最終檔案：$(basename "$ytdlp_final_media_file")${RESET}" # 可選提示
            final_video_with_subs="$ytdlp_final_media_file" # 最終檔案就是 yt-dlp 下載的檔案
        fi
    elif [ $result -eq 0 ] && [ ! -f "$ytdlp_final_media_file" ]; then # 下載步驟聲稱成功但檔案不存在
        log_message "ERROR" "內部錯誤：ytdlp_final_media_file 未設定或檔案不存在，無法進行字幕處理。"
        result=1
    fi

    # --- 清理臨時檔案 ---
    log_message "INFO" "清理主要臨時檔案 (MP4 NoNorm)..."
    safe_remove "$temp_dir/yt-dlp-nonorm.log"
    safe_remove "$temp_dir/ffmpeg_subs_embed.log"
    safe_remove "$temp_dir/py_estimator_mp4nn_stderr.log"
    # 如果字幕嵌入失敗，ytdlp_final_media_file 未被刪除，字幕檔也可能未被刪除
    if [ "$final_video_with_subs" != "$ytdlp_final_media_file" ] && [ -f "$ytdlp_final_media_file" ]; then
         # 這種情況是字幕嵌入成功並生成新檔，舊的 ytdlp_final_media_file 已被 safe_remove
         # 或者字幕嵌入失敗，ytdlp_final_media_file 成為 final_video_with_subs，字幕檔應在此清理
         for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done;
    fi
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$final_video_with_subs" ]; then
            if [ "$final_video_with_subs" == "$ytdlp_final_media_file" ] && [ ${#subtitle_files[@]} -gt 0 ]; then
                 # 這種情況是字幕嵌入失敗或未執行，但有字幕檔本應嵌入
                 echo -e "${YELLOW}處理完成 (字幕未嵌入)！影片已儲存至：${final_video_with_subs}${RESET}";
                 log_message "WARNING" "處理完成但字幕未嵌入 (MP4 無標準化)！影片：$final_video_with_subs";
            else
                 echo -e "${GREEN}處理完成！影片已儲存至：${final_video_with_subs}${RESET}";
                 log_message "SUCCESS" "處理完成 (MP4 無標準化)！影片已儲存至：$final_video_with_subs";
            fi
        else
            echo -e "${RED}處理失敗 (MP4 無標準化)！最終檔案 '$final_video_with_subs' 未找到。${RESET}";
            log_message "ERROR" "處理失敗 (MP4 無標準化)：$video_url. 最終檔案 '$final_video_with_subs' 未找到。";
            result=1
        fi
    else # result is 1 from earlier stage
        echo -e "${RED}處理失敗 (MP4 無標準化)！${RESET}";
        log_message "ERROR" "處理失敗 (MP4 無標準化)：$video_url";
    fi

    # --- 條件式通知 (僅非播放清單模式) ---
    if ! $is_playlist_mode && $should_notify; then
        local notification_title="媒體處理器：MP4 無標準化"
        local title_for_notify="${sanitized_title:-$video_title}"
        title_for_notify="${title_for_notify:-$(basename "$video_url" 2>/dev/null)}"
        local base_msg_notify="處理影片 '$title_for_notify'"
        local path_for_notify="$final_video_with_subs" # 使用最終確定的檔案路徑
        local effective_result_for_notify=$result

        # 如果核心檔案下載成功，但字幕嵌入失敗，通知可以稍微調整
        if [ $result -eq 0 ] && [ "$final_video_with_subs" == "$ytdlp_final_media_file" ] && [ ${#subtitle_files[@]} -gt 0 ]; then
            base_msg_notify="處理影片 '$title_for_notify' (字幕未嵌入)"
            # effective_result_for_notify 可以保持 0，因為核心內容是好的
        fi
        _send_termux_notification "$effective_result_for_notify" "$notification_title" "$base_msg_notify" "$path_for_notify"
    fi

    return $result
}

##############################################################
# 處理單一 YouTube 影片（MP4）下載（無標準化，可選時段）
# (已修正 goto)
##############################################################
process_single_mp4_no_normalize_sections() {
    local video_url="$1"
    local start_time="$2"
    local end_time="$3"

    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA"
    # local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt" # 字幕選項在後面用到
    local subtitle_files=()
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=0 # 初始化結果為成功
    local output_video_file="" # 最終檔案 (可能帶字幕，也可能不帶)
    local video_title="" video_id="" sanitized_title="" base_name_for_output="" # 提前聲明
    local base_name_for_subs_dl="" # 字幕下載時的基礎檔名

    echo -e "${YELLOW}處理 YouTube 影片 (無標準化，指定時段 $start_time-$end_time)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube 影片 (無標準化，時段 $start_time-$end_time): $video_url"

    # --- 獲取標題和 ID ---
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video_section_$(date +%s)"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id="id_section_$(date +%s)"
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- 構建檔名 ---
    local safe_start_time=${start_time//:/-}
    local safe_end_time=${end_time//:/-}
    # base_name_for_output 用於最終分段影片的檔名
    base_name_for_output="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]_${safe_start_time}-${safe_end_time}"
    local initial_output_video_file="${base_name_for_output}.mp4" # yt-dlp 下載的分段影片檔名
    output_video_file="$initial_output_video_file" # 預設最終檔案是這個，除非嵌入字幕

    # base_name_for_subs_dl 用於 yt-dlp 下載完整字幕檔時的模板，不應包含時段信息
    base_name_for_subs_dl="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]"


    local format_option="bestvideo[height<=1440][ext=mp4][vcodec^=avc]+bestaudio[ext=m4a]/bestvideo[height<=1440][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1440]+bestaudio/best[height<=1440][ext=mp4]/best[height<=1440]/best"
    log_message "INFO" "使用格式 (無標準化，時段): $format_option"

    mkdir -p "$DOWNLOAD_PATH";
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入下載目錄 (無標準化，時段)：$DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
        result=1
    fi

    # --- 下載指定時段的影片 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載影片指定時段 ($start_time-$end_time)（高品質音質）...${RESET}"
        local yt_dlp_dl_args=(
            yt-dlp
            -f "$format_option"
            --download-sections "*${start_time}-${end_time}"
            -o "$initial_output_video_file" # 直接輸出到預期的分段檔名
            "$video_url"
            --newline
            --concurrent-fragments "$THREADS"
            --merge-output-format mp4
        )
        log_message "INFO" "執行 yt-dlp (無標準化，時段，影音): ${yt_dlp_dl_args[*]}"
        echo -e "${CYAN}提示：分段下載可能不會顯示即時進度，請耐心等候...${RESET}"

        if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-sections-video.log"; then
            log_message "ERROR" "影片指定時段下載失敗 (無標準化)...查看 $temp_dir/yt-dlp-sections-video.log"
            echo -e "${RED}錯誤：影片指定時段下載失敗！${RESET}"
            [ -s "$temp_dir/yt-dlp-sections-video.log" ] && cat "$temp_dir/yt-dlp-sections-video.log"
            result=1
        elif [ ! -f "$initial_output_video_file" ]; then
            log_message "ERROR" "找不到下載的影片檔案 (無標準化，時段): $initial_output_video_file"
            echo -e "${RED}錯誤：找不到下載的影片檔案！檢查上述 yt-dlp 日誌。${RESET}"
            result=1
        else
            echo -e "${GREEN}影片時段下載/合併完成：$initial_output_video_file${RESET}"
            log_message "INFO" "影片時段下載完成 (無標準化)：$initial_output_video_file"
            # 驗證視訊流
            if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$initial_output_video_file" > /dev/null 2>&1; then
                log_message "ERROR" "驗證失敗：下載的檔案 '$initial_output_video_file' 中似乎沒有視訊流！"
                echo -e "${RED}錯誤：下載完成的檔案似乎缺少視訊流！請檢查格式選擇或合併過程。${RESET}"
                # echo -e "${YELLOW}--- ffprobe 檔案資訊 ---${RESET}"; ffprobe -hide_banner "$initial_output_video_file"; echo -e "${YELLOW}--- ffprobe 資訊結束 ---${RESET}" # 可選調試
                result=1
            else
                log_message "INFO" "驗證成功：下載的檔案 '$initial_output_video_file' 包含視訊流。"
            fi
        fi
    fi

    # --- 下載字幕檔案 (完整字幕) ---
    local subtitle_options_cmd="--write-subs --sub-lang $target_sub_langs --convert-subs srt" # 字幕選項
    if [ $result -eq 0 ]; then # 僅在影片下載成功時才嘗試下載字幕
        log_message "INFO" "嘗試字幕: $target_sub_langs"
        echo -e "${YELLOW}嘗試下載繁/簡/通用中文字幕...${RESET}"
        echo -e "${YELLOW}正在嘗試下載字幕檔案 (完整影片的字幕)...${RESET}"
        # 字幕下載使用 base_name_for_subs_dl，不包含時段
        local yt_dlp_sub_args=(
            yt-dlp
            --skip-download ${subtitle_options_cmd}
            -o "${base_name_for_subs_dl}.%(ext)s" # 使用不含時段的基礎名
            "$video_url"
        )
        log_message "INFO" "執行 yt-dlp (僅字幕): ${yt_dlp_sub_args[*]}"
        if ! "${yt_dlp_sub_args[@]}" 2> "$temp_dir/yt-dlp-sections-subs.log"; then
            log_message "WARNING" "下載字幕失敗或無字幕。詳見 $temp_dir/yt-dlp-sections-subs.log"
            echo -e "${YELLOW}警告：下載字幕失敗或影片無字幕。${RESET}"
        fi

        # 查找下載的字幕檔
        log_message "INFO" "檢查字幕 (基於: ${base_name_for_subs_dl}.*.srt)"
        subtitle_files=() # 清空
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
            log_message "INFO" "未找到中文字幕。"; echo -e "${YELLOW}未找到中文字幕。${RESET}"
        fi
    fi

    # --- 字幕混流 (如果找到字幕且影片下載成功) ---
    if [ $result -eq 0 ] && [ ${#subtitle_files[@]} -gt 0 ]; then
        echo -e "${YELLOW}開始將字幕嵌入影片...${RESET}"
        local temp_video_with_subs="${base_name_for_output}_with_subs_temp.mp4" # 臨時混流檔名
        local ffmpeg_mux_args=(ffmpeg -y -i "$initial_output_video_file") # 輸入是已下載的分段影片

        local sub_input_map_idx=1
        for sub_file_path in "${subtitle_files[@]}"; do
            ffmpeg_mux_args+=("-i" "$sub_file_path")
        done
        ffmpeg_mux_args+=("-map" "0:v" "-map" "0:a" "-c:v" "copy" "-c:a" "copy") # 複製視訊和所有音訊流

        local output_sub_stream_idx=0
        for ((i=0; i<${#subtitle_files[@]}; i++)); do
            ffmpeg_mux_args+=("-map" "$((sub_input_map_idx + i))")
            local sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
            local ffmpeg_lang=""
            case "$sub_lang_code" in
                zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                zh) ffmpeg_lang="chi" ;;
                *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;;
            esac
            ffmpeg_mux_args+=("-metadata:s:s:${output_sub_stream_idx}" "language=$ffmpeg_lang")
            output_sub_stream_idx=$((output_sub_stream_idx + 1))
        done
        ffmpeg_mux_args+=("-c:s" "mov_text" "-movflags" "+faststart" "$temp_video_with_subs")

        log_message "INFO" "執行 FFmpeg 字幕混流: ${ffmpeg_mux_args[*]}"
        if ! "${ffmpeg_mux_args[@]}" 2> "$temp_dir/ffmpeg_mux_subs.log"; then
            log_message "ERROR" "字幕混流失敗！詳見 $temp_dir/ffmpeg_mux_subs.log"
            echo -e "${RED}錯誤：字幕混流失敗！${RESET}"; cat "$temp_dir/ffmpeg_mux_subs.log"
            # 字幕混流失敗，但 initial_output_video_file (無字幕) 仍然存在
            # output_video_file 保持為 initial_output_video_file
            log_message "WARNING" "字幕混流失敗，保留無字幕版本: $initial_output_video_file"
            # result 可以保持 0，表示核心影片下載成功，但帶有警告
        else
            echo -e "${GREEN}字幕混流完成：$temp_video_with_subs${RESET}"
            log_message "SUCCESS" "字幕混流成功：$temp_video_with_subs"
            # 混流成功，刪除原始分段影片，重命名混流後的檔案
            safe_remove "$initial_output_video_file"
            if mv "$temp_video_with_subs" "$initial_output_video_file"; then
                 log_message "INFO" "重命名 $temp_video_with_subs 為 $initial_output_video_file"
                 output_video_file="$initial_output_video_file" # 確認最終檔案名
            else
                 log_message "ERROR" "重命名 $temp_video_with_subs 失敗，最終檔案可能為 $temp_video_with_subs"
                 echo -e "${RED}錯誤：重命名最終檔案失敗，請檢查 $temp_video_with_subs ${RESET}"
                 output_video_file="$temp_video_with_subs" # 更新 output_video_file 為實際存在的檔案
            fi
            # 字幕檔在後面的清理階段統一處理
        fi
    else # 無字幕或影片下載失敗
        output_video_file="$initial_output_video_file" # 確保 output_video_file 指向已下載的（可能無字幕的）檔案
        if [ $result -eq 0 ]; then # 影片下載成功但無字幕
            log_message "INFO" "未找到字幕或未成功下載，無需混流。"
        fi
    fi

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (無標準化，時段)..."
    safe_remove "$temp_dir/yt-dlp-sections-video.log" "$temp_dir/yt-dlp-sections-subs.log" "$temp_dir/ffmpeg_mux_subs.log"
    # 清理下載的字幕檔 (無論混流成功與否)
    local langs_to_check_cleanup
    IFS=',' read -r -a langs_to_check_cleanup <<< "$target_sub_langs" # 重新讀取以防萬一
    for lang_clean in "${langs_to_check_cleanup[@]}"; do
        safe_remove "${base_name_for_subs_dl}.${lang_clean}.srt" # 清理基於 base_name_for_subs_dl 的字幕
    done
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 最終結果報告 (控制台) ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_video_file" ]; then
            local final_filename_display=$(basename "$output_video_file")
            echo -e "${GREEN}處理完成！影片 (無標準化，時段 $start_time-$end_time) 已儲存至：${final_filename_display}${RESET}"
            log_message "SUCCESS" "處理完成 (無標準化，時段)！影片已儲存至：$output_video_file"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video_file' 未找到！請檢查日誌。${RESET}"
            log_message "ERROR" "處理完成但最終檔案未找到 (無標準化，時段)：$output_video_file"
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (無標準化，時段)！${RESET}"
        log_message "ERROR" "處理失敗 (無標準化，時段)：$video_url"
    fi

    # --- Termux 通知邏輯 ---
    # (此處的通知邏輯與原腳本一致，使用 _send_termux_notification 會更統一)
    # 為了簡化，我們假設 _send_termux_notification 會被調用
    # 這裡的通知邏輯已在原腳本中存在，其結構與 _send_termux_notification 類似
    if [[ "$OS_TYPE" == "termux" ]]; then
        if command -v termux-notification &> /dev/null; then
            local notification_title_msg="媒體處理器：MP4 片段" # 保持與原腳本一致的標題
            local notification_content_msg=""
            local final_filename_for_notify=$(basename "$output_video_file" 2>/dev/null) # 純檔名

            if [ $result -eq 0 ] && [ -f "$output_video_file" ]; then
                notification_content_msg="✅ 成功：影片 '$sanitized_title' 時段 [$start_time-$end_time] 已儲存為 '$final_filename_for_notify'."
            else
                notification_content_msg="❌ 失敗：影片 '$sanitized_title' 時段 [$start_time-$end_time] 處理失敗。"
            fi
            # 使用 _send_termux_notification 以保持一致性
            _send_termux_notification "$result" "$notification_title_msg" "$notification_content_msg" "$([ $result -eq 0 ] && echo "$output_video_file" || echo "")"
        else
            log_message "INFO" "未找到 termux-notification 命令，跳過 MP4 片段通知。"
        fi
    fi

    return $result
}

############################################
# 處理單一 YouTube 影片（MKV）下載与處理 (修正版)
# (已移除 goto，整合清理與通知邏輯)
############################################
process_single_mkv() {
    local video_url="$1"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_format_pref="ass/vtt/best"
    local subtitle_files=()
    local temp_dir
    temp_dir=$(mktemp -d) # 確保 temp_dir 在函數開頭定義
    local result=0 # 預設成功
    local should_notify=false
    local output_mkv="" # 最終輸出檔案
    local video_temp_file="${temp_dir}/video_stream.mp4"
    local audio_temp_file="${temp_dir}/audio_stream.m4a"
    local normalized_audio_m4a="$temp_dir/audio_normalized.m4a"
    local sub_temp_template="${temp_dir}/sub_stream.%(ext)s"
    local video_title video_id sanitized_title sanitized_title_id output_base_name # 提前聲明

    echo -e "${YELLOW}處理 YouTube 影片 (輸出 MKV)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube MKV: $video_url"
    log_message "INFO" "將嘗試請求以下字幕 (格式: $subtitle_format_pref): $target_sub_langs"
    echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕 (保留樣式)...${RESET}"

    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video_$(date +%s)"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id="id_$(date +%s)"
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')
    # sanitized_title_id=$(echo "${video_title}_${video_id}" | sed 's@[/\\:*?"<>|]@_@g') # 如果檔名太長，這個可能導致問題
                                                                                   # 應使用 yt-dlp 的模板功能來控制檔名
    # 修正：讓 yt-dlp 的 -o 參數來構建檔名，避免手動拼接 video_id 導致過長
    output_base_name="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]" # 基礎名，不含後綴
    output_mkv="${output_base_name}_normalized.mkv" # 預期最終檔名

    # --- 使用 Python 估計大小並決定是否通知 ---
    local yt_dlp_format_string_estimate="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio/best[ext=mp4]/best"
    echo -e "${YELLOW}正在預估檔案大小 (使用 Python 腳本)...${RESET}"
    local estimated_size_bytes=0
    local python_estimate_output
    local python_exec=""
    if command -v python3 &> /dev/null; then python_exec="python3"; elif command -v python &> /dev/null; then python_exec="python"; fi

    if [ -n "$python_exec" ] && [ -f "$PYTHON_ESTIMATOR_SCRIPT_PATH" ]; then
        log_message "DEBUG" "Calling Python estimator (MKV): $python_exec \"$PYTHON_ESTIMATOR_SCRIPT_PATH\" \"$video_url\" \"$yt_dlp_format_string_estimate\""
        python_estimate_output=$($python_exec "$PYTHON_ESTIMATOR_SCRIPT_PATH" "$video_url" "$yt_dlp_format_string_estimate" 2> "$temp_dir/py_estimator_mkv_stderr.log")
        local py_exit_code=$?
        if [ $py_exit_code -eq 0 ] && [[ "$python_estimate_output" =~ ^[0-9]+$ ]]; then
            estimated_size_bytes="$python_estimate_output"
            log_message "INFO" "Python 腳本估計大小 (MKV): $estimated_size_bytes bytes"
            [ ! -s "$temp_dir/py_estimator_mkv_stderr.log" ] && rm -f "$temp_dir/py_estimator_mkv_stderr.log"
        else
            log_message "WARNING" "Python 估計腳本執行失敗 (MKV Code: $py_exit_code) 或輸出無效 ('$python_estimate_output')。詳見 $temp_dir/py_estimator_mkv_stderr.log"
            estimated_size_bytes=0
        fi
    else
        log_message "WARNING" "找不到 Python ('$python_exec') 或估計腳本 '$PYTHON_ESTIMATOR_SCRIPT_PATH' (MKV)，無法估計大小。"
        estimated_size_bytes=0
    fi
    local size_threshold_gb_mkv=0.5
    local size_threshold_bytes_mkv=$(awk "BEGIN {printf \"%d\", $size_threshold_gb_mkv * 1024 * 1024 * 1024}")
    log_message "INFO" "檔案大小預估 (MKV): $estimated_size_bytes bytes, 閾值: $size_threshold_bytes_mkv bytes."
    if [[ "$estimated_size_bytes" -gt "$size_threshold_bytes_mkv" ]]; then
        log_message "INFO" "大小超過閾值 (MKV)，啟用通知。"
        should_notify=true
    else
        log_message "INFO" "大小未超過閾值 (MKV)，禁用通知。"
        should_notify=false
    fi
    # --- 預估大小結束 ---

    mkdir -p "$DOWNLOAD_PATH";
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入下載目錄 (MKV): $DOWNLOAD_PATH"; echo -e "${RED}錯誤：無法寫入目錄${RESET}";
        result=1; # 標記失敗
    fi

    # --- 下載視訊流 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載最佳視訊流...${RESET}"
        if ! yt-dlp -f 'bv[ext=mp4][height<=1440]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video.log"; then
            echo -e "${YELLOW}警告：未找到 <=1440p 的 MP4 視訊流，嘗試下載最佳 MP4 視訊流...${RESET}"
            log_message "WARNING" "未找到 <=1440p 的 MP4 視訊流，嘗試最佳 MP4 for $video_url"
            if ! yt-dlp -f 'bv[ext=mp4]/bestvideo[ext=mp4]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video-fallback.log"; then # 使用不同日誌檔名
                log_message "ERROR" "視訊流下載失敗（包括備選方案）...查看 $temp_dir/yt-dlp-video.log 和 $temp_dir/yt-dlp-video-fallback.log";
                echo -e "${RED}錯誤：視訊流下載失敗！${RESET}";
                result=1;
            fi
        fi
        if [ $result -eq 0 ] && [ ! -f "$video_temp_file" ]; then
            log_message "ERROR" "視訊流下載後未找到檔案！"; echo -e "${RED}錯誤：視訊流下載失敗！${RESET}";
            result=1;
        elif [ $result -eq 0 ]; then
             log_message "INFO" "視訊流下載完成: $video_temp_file"
        fi
    fi

    # --- 下載音訊流 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載最佳音訊流...${RESET}"
        if ! yt-dlp -f 'ba[ext=m4a]' --no-warnings -o "$audio_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-audio.log"; then
            log_message "ERROR" "音訊流下載失敗...查看 $temp_dir/yt-dlp-audio.log"; echo -e "${RED}錯誤：音訊流下載失敗！${RESET}";
            result=1;
        fi
        if [ $result -eq 0 ] && [ ! -f "$audio_temp_file" ]; then
            log_message "ERROR" "音訊流下載後未找到檔案！"; echo -e "${RED}錯誤：音訊流下載失敗！${RESET}";
            result=1;
        elif [ $result -eq 0 ]; then
            log_message "INFO" "音訊流下載完成: $audio_temp_file"
        fi
    fi

    # --- 下載字幕 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載字幕 (格式: ${subtitle_format_pref})...${RESET}"
        yt-dlp --write-subs --sub-format "$subtitle_format_pref" --sub-lang "$target_sub_langs" --skip-download -o "$sub_temp_template" "$video_url" > "$temp_dir/yt-dlp-subs.log" 2>&1
        # 查找字幕檔案
        subtitle_files=() # 清空以防萬一
        for lang_code in "zh-Hant" "zh-TW" "zh-Hans" "zh-CN" "zh"; do
            for sub_ext in ass vtt; do # yt-dlp 可能會下載為 .ass 或 .vtt
                potential_sub_file="${temp_dir}/sub_stream.${lang_code}.${sub_ext}"
                if [ -f "$potential_sub_file" ]; then
                    # 檢查是否已加入，避免重複 (雖然此處 lang_code 和 sub_ext 的組合應該是唯一的)
                    local already_added=false
                    for existing_file in "${subtitle_files[@]}"; do
                        if [[ "$existing_file" == "$potential_sub_file" ]]; then
                            already_added=true; break
                        fi
                    done
                    if ! $already_added; then
                        subtitle_files+=("$potential_sub_file")
                        log_message "INFO" "找到字幕: $potential_sub_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_sub_file")${RESET}";
                        # 找到一種語言的一個格式後，可以考慮 break 內層或外層循環，取決於是否需要所有匹配的字幕
                        # 此處保留原邏輯，會收集所有找到的 ass/vtt 字幕
                    fi
                fi
            done
        done
        if [ ${#subtitle_files[@]} -eq 0 ]; then
            log_message "INFO" "未找到符合條件的中文字幕。"; echo -e "${YELLOW}未找到 ASS/VTT 格式的中文字幕。${RESET}";
        fi
    fi

    # --- 音量標準化與混流 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始音量標準化...${RESET}"
        if normalize_audio "$audio_temp_file" "$normalized_audio_m4a" "$temp_dir" true; then # true for video context (output m4a)
            echo -e "${YELLOW}正在混流成 MKV 檔案...${RESET}"
            local ffmpeg_mux_args=(ffmpeg -y -i "$video_temp_file" -i "$normalized_audio_m4a")
            local sub_input_index=2 # 視訊是0, 音訊是1, 字幕從2開始
            for sub_file_path in "${subtitle_files[@]}"; do ffmpeg_mux_args+=("-i" "$sub_file_path"); done

            ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100")
            ffmpeg_mux_args+=("-map" "0:v:0" "-map" "1:a:0") # 映射視訊和音訊

            if [ ${#subtitle_files[@]} -gt 0 ]; then
                ffmpeg_mux_args+=("-c:s" "copy") # 直接複製字幕流以保留樣式
                for ((i=0; i<${#subtitle_files[@]}; i++)); do
                    ffmpeg_mux_args+=("-map" "$sub_input_index:s:0") # 映射第 i 個字幕輸入的第0個字幕流
                                                                 # 注意：如果一個字幕檔內有多個流，這裡只取第一個。
                                                                 # 對於 yt-dlp 下載的字幕檔，通常一個檔案一個流。
                    # 獲取字幕語言碼，例如 sub_stream.zh-Hant.ass -> zh-Hant
                    local sub_lang_code
                    sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev) # smarter way to get lang code
                    local ffmpeg_lang=""
                    case "$sub_lang_code" in
                        zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                        zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                        zh) ffmpeg_lang="chi" ;;
                        *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;; # 取前三字母作為備用
                    esac
                    ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang") # 為第 i 個輸出的字幕流設定語言
                    ((sub_input_index++))
                done
            fi
            ffmpeg_mux_args+=("$output_mkv")

            log_message "INFO" "MKV 混流命令: ${ffmpeg_mux_args[*]}"
            local ffmpeg_stderr_log="$temp_dir/ffmpeg_mkv_mux_stderr.log"
            if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then
                echo -e "${RED}錯誤：MKV 混流失敗！以下是 FFmpeg 錯誤訊息：${RESET}"
                cat "$ffmpeg_stderr_log"
                log_message "ERROR" "MKV 混流失敗，詳見 $ffmpeg_stderr_log";
                result=1;
            else
                echo -e "${GREEN}MKV 混流完成${RESET}";
                # result 保持 0
                rm -f "$ffmpeg_stderr_log";
            fi
        else
            log_message "ERROR" "音量標準化失敗！Input: $audio_temp_file";
            result=1;
        fi
    fi

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (MKV)..."
    # 只有當處理成功 (result=0) 且最終檔案已生成時，才清理原始下載的視訊和音訊流
    # 如果 output_mkv 成功生成，則 video_temp_file 和 normalized_audio_m4a 就不再需要了
    if [ $result -eq 0 ] && [ -f "$output_mkv" ]; then
        safe_remove "$video_temp_file"
        # audio_temp_file 被 normalize_audio 用作輸入，其輸出是 normalized_audio_m4a
        # 所以 audio_temp_file 也應該在 normalize_audio 成功後就可以清理了
        safe_remove "$audio_temp_file"
        safe_remove "$normalized_audio_m4a" # 這個是 normalize_audio 的輸出
    else
        # 如果處理失敗，可以選擇保留 video_temp_file 和 audio_temp_file 供調試
        log_message "INFO" "MKV 處理失敗，可能保留臨時的視訊/音訊流在 $temp_dir"
        # normalized_audio_m4a 若存在也應清理，因其是中間產物
        safe_remove "$normalized_audio_m4a"
    fi

    for sub_f in "${subtitle_files[@]}"; do safe_remove "$sub_f"; done # 字幕檔總是清理
    safe_remove "$temp_dir/yt-dlp-video.log" "$temp_dir/yt-dlp-video-fallback.log" \
                "$temp_dir/yt-dlp-audio.log" "$temp_dir/yt-dlp-subs.log"
    safe_remove "$temp_dir/ffmpeg_mkv_mux_stderr.log"
    safe_remove "$temp_dir/py_estimator_mkv_stderr.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir" # 總是清理臨時目錄

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_mkv" ]; then
            echo -e "${GREEN}處理完成！MKV 影片已儲存至：$output_mkv${RESET}";
            log_message "SUCCESS" "MKV 處理完成！影片已儲存至：$output_mkv";
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_mkv' 未找到！${RESET}";
            log_message "ERROR" "處理完成但最終檔案未找到 (MKV)";
            result=1 # 標記失敗
        fi
    else
        echo -e "${RED}處理失敗 (MKV)！${RESET}";
        log_message "ERROR" "MKV 處理失敗：$video_url";
        # 提示用戶原始下載檔案可能存在於何處
        if [ -f "$video_temp_file" ]; then echo -e "${YELLOW}原始視訊流可能保留在: $video_temp_file${RESET}"; fi
        if [ -f "$audio_temp_file" ]; then echo -e "${YELLOW}原始音訊流可能保留在: $audio_temp_file${RESET}"; fi
    fi

    # --- 條件式通知 ---
    # 只有在非播放列表模式 (此函數假設為單獨調用) 且 should_notify 為 true 時
    if $should_notify; then # mode 參數在此函數未直接使用來判斷 should_notify，它依賴時長估計
        local notification_title="媒體處理器：MKV 處理"
        local title_for_notify="${sanitized_title:-$(basename "$video_url")}"
        local base_msg_notify="處理 MKV '$title_for_notify'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_mkv" ]; then
            final_path_notify="$output_mkv"
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

############################################
# 輔助函數：處理單一通用網站媒體項目 (含標準化)
# <<< 修改 v2.5.x：接收輸出模板參數以處理 Bilibili 長檔名 >>>
# <<< 新增修改：針對 Bilibili 使用 aria2c 並優化參數 (標準化版本) >>>
############################################
_process_single_other_site() {
    # --- 接收參數 ---
    local item_url="$1"; local choice_format="$2"; local item_index="$3"; local total_items="$4"
    local mode="$5"
    local output_template_playlist="$6" 
    local output_template_single_item="$7"

    # --- 局部變數 ---
    local temp_dir=$(mktemp -d); local thumbnail_file=""; local main_media_file="";
    local result=0; local output_final_file=""; local artist_name="[不明]"; local album_artist_name="[不明]"
    local progress_prefix=""; if [ -n "$item_index" ] && [ -n "$total_items" ]; then progress_prefix="[$item_index/$total_items] "; fi
    local should_notify=false
    local is_playlist=false
    local final_output_template_used=""
    local base_name_calculated_from_file="" # 用於從實際下載的檔名中提取基礎名

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        log_message "INFO" "通用下載 標準化：播放清單模式。"
    fi

    local item_title sanitized_title video_id
    item_title=$(yt-dlp --get-title "$item_url" 2>/dev/null) || item_title="media_item_$(date +%s)"
    video_id=$(yt-dlp --get-id "$item_url" 2>/dev/null) || video_id="no_id_$(date +%s)"
    sanitized_title=$(echo "${item_title}" | sed 's@[/\\:*?"<>|]@_@g')
    log_message "DEBUG" "基礎標題: '$item_title', ID: '$video_id', 清理後: '$sanitized_title'"

    # --- 預估大小 (僅單獨模式) ---
    local yt_dlp_format_string_for_estimate=""
    if [ "$choice_format" = "mp4" ]; then yt_dlp_format_string_for_estimate="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
    else yt_dlp_format_string_for_estimate="bestaudio/best"; fi # 標準化前獲取最佳音訊

    if ! $is_playlist; then
        echo -e "${YELLOW}正在預估檔案大小以決定是否通知...${RESET}"
        local estimated_size_bytes=0
        local size_list estimate_exit_code
        size_list=$(yt-dlp --no-warnings --print '%(filesize,filesize_approx)s' -f "$yt_dlp_format_string_for_estimate" "$item_url" 2>"$temp_dir/yt-dlp-estimate.log")
        estimate_exit_code=$?
        # ... (後續大小估計邏輯不變) ...
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
    
    echo -e "${CYAN}${progress_prefix}處理項目: $item_url (${choice_format})${RESET}"; log_message "INFO" "${progress_prefix}處理項目: $item_url (格式: $choice_format)"
    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; rm -rf "$temp_dir"; return 1; fi

    # --- 下載 ---
    local download_success=false
    local actual_yt_dlp_args=()
    local chosen_output_template=""

    echo -e "${YELLOW}${progress_prefix}開始下載主檔案...${RESET}"

### MODIFIED BLOCK START (下載邏輯) ###
    if [[ "$item_url" == *"bilibili.com"* ]]; then
        log_message "INFO" "檢測到 Bilibili URL (標準化流程)，將使用 aria2c 及優化參數。"
        echo -e "${CYAN}${progress_prefix}檢測到 Bilibili 網站，啟用 aria2c 加速下載 (標準化流程)。${RESET}"
        
        local bili_format_select=""
        if [ "$choice_format" = "mp4" ]; then
            bili_format_select="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        else # mp3 (下載最佳音訊給 normalize_audio)
            bili_format_select="bestaudio[ext=m4a]/bestaudio/best"
        fi

        actual_yt_dlp_args=(
            yt-dlp
            --no-warnings
            --no-simulate
            --newline
            --downloader aria2c
            --downloader-args "aria2c:-x4 -s4 -k1M --retry-wait=5 --max-tries=0 --lowest-speed-limit=10K"
            --retries infinite
            --fragment-retries infinite
            --add-metadata
            --embed-thumbnail
            -f "$bili_format_select"
        )
        if [ "$choice_format" = "mp4" ]; then
            actual_yt_dlp_args+=(--merge-output-format mp4)
        # 注意：對於 MP3 標準化流程，不在此處用 yt-dlp 轉換為 MP3
        # elif [ "$choice_format" = "mp3" ]; then
            # NO --extract-audio --audio-format mp3 here for normalization flow
        fi
    else
        # 非 Bilibili 網站，使用通用參數
        local generic_format_select=""
        if [ "$choice_format" = "mp4" ]; then
            generic_format_select="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
        else # mp3 (下載最佳音訊給 normalize_audio)
            generic_format_select="bestaudio/best"
        fi

        actual_yt_dlp_args=(
            yt-dlp
            -f "$generic_format_select"
            --newline 
            --progress 
            --concurrent-fragments "$THREADS" 
            --no-simulate 
            --no-abort-on-error
        )
        if [ "$choice_format" = "mp4" ]; then
             actual_yt_dlp_args+=(--merge-output-format mp4)
        # 注意：對於 MP3 標準化流程，不在此處用 yt-dlp 轉換為 MP3
        fi
    fi

    if $is_playlist; then
        chosen_output_template="$output_template_playlist"
    else
        chosen_output_template="$output_template_single_item"
    fi
    
    actual_yt_dlp_args+=(-o "$chosen_output_template")
    actual_yt_dlp_args+=("$item_url")

    log_message "INFO" "${progress_prefix}執行下載 (標準化流程): ${actual_yt_dlp_args[*]}"
    if "${actual_yt_dlp_args[@]}" 2> "$temp_dir/yt-dlp-other-std.log"; then
        download_success=true
        final_output_template_used="$chosen_output_template"
    else
        log_message "ERROR" "...下載失敗 (標準化流程)..."; echo -e "${RED}錯誤：下載失敗！${RESET}";
        cat "$temp_dir/yt-dlp-other-std.log"
        result=1
    fi
### MODIFIED BLOCK END (下載邏輯) ###

    if $download_success; then
        echo -e "${YELLOW}${progress_prefix}定位主檔案...${RESET}"
        local format_for_getfn="" # 需要和下載時的 format 選擇邏輯一致
        if [[ "$item_url" == *"bilibili.com"* ]]; then
             if [ "$choice_format" = "mp4" ]; then format_for_getfn="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best";
             else format_for_getfn="bestaudio[ext=m4a]/bestaudio/best"; fi
        else
             if [ "$choice_format" = "mp4" ]; then format_for_getfn="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
             else format_for_getfn="bestaudio/best"; fi
        fi

        local yt_dlp_getfn_args=(yt-dlp --no-warnings --print filename -f "$format_for_getfn" -o "$final_output_template_used" "$item_url")
        local actual_download_path=$( "${yt_dlp_getfn_args[@]}" | tr -d '\n' )
        local getfn_exit_code=$?
        log_message "DEBUG" "獲取檔名命令(標準化流程)退出碼: $getfn_exit_code, 獲取的路徑: '$actual_download_path'"

        if [ $getfn_exit_code -eq 0 ] && [ -n "$actual_download_path" ] && [ -f "$actual_download_path" ]; then
            main_media_file="$actual_download_path"
            log_message "INFO" "${progress_prefix}找到主檔案: $main_media_file";
            # 從實際檔案路徑計算 base_name_calculated_from_file (不含副檔名)
            base_name_calculated_from_file=$(basename "$main_media_file" | sed 's/\.[^.]*$//')
            log_message "DEBUG" "從檔案計算出的 Base Name: [$base_name_calculated_from_file]"
            result=0 
        else
            log_message "ERROR" "...找不到主檔案 (通用 std)..."; echo -e "${RED}錯誤：找不到主檔案！${RESET}";
            result=1
        fi
    else
         log_message "DEBUG" "下載標記為失敗，跳過檔案定位。"
    fi

    # --- 下載縮圖 (僅在定位檔案成功時) ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}${progress_prefix}嘗試下載縮圖...${RESET}"
        if [ -n "$base_name_calculated_from_file" ]; then # 使用從檔案計算的基礎名
            local media_dir=$(dirname "$main_media_file")
            # 縮圖模板使用計算出的基礎名，確保與主檔案名一致（除了副檔名）
            local thumb_dl_template="${media_dir}/${base_name_calculated_from_file}.%(ext)s"
            log_message "DEBUG" "嘗試使用縮圖模板: $thumb_dl_template"
            
            # yt-dlp --write-thumbnail 會下載並嘗試使用 base_name_calculated_from_file.<actual_thumb_ext> 這樣的檔名
            if ! yt-dlp --no-warnings --skip-download --write-thumbnail -o "$thumb_dl_template" "$item_url" 2> "$temp_dir/yt-dlp-thumb.log"; then
                log_message "WARNING" "...下載縮圖指令失敗或無縮圖，詳見 $temp_dir/yt-dlp-thumb.log"
            fi
            # 查找縮圖 (使用計算出的基礎名)
            thumbnail_file=$(find "$media_dir" -maxdepth 1 -type f -iname "${base_name_calculated_from_file}.*" \
                             \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
                             -print -quit)
            if [ -n "$thumbnail_file" ]; then log_message "INFO" "...找到縮圖: $thumbnail_file";
            else log_message "WARNING" "...在下載目錄中未找到縮圖檔案 (jpg/jpeg/png/webp) 匹配基礎名: ${base_name_calculated_from_file}"; fi
        else
            log_message "WARNING" "Base name (base_name_calculated_from_file) 未設定，跳過縮圖下載和查找。"
        fi
    fi

    # --- 處理邏輯 (MP3 或 MP4) (僅在成功時執行) ---
    if [ $result -eq 0 ]; then
        local media_output_dir=$(dirname "$main_media_file") # 獲取實際下載檔案的目錄

        if [ "$choice_format" = "mp3" ]; then
            # 最終輸出檔名基於計算出的基礎名和實際目錄
            output_final_file="${media_output_dir}/${base_name_calculated_from_file}_normalized.mp3";
            local normalized_temp_audio_for_mp3="$temp_dir/temp_normalized_for_mp3.mp3" # 臨時標準化後的 MP3
            
            echo -e "${YELLOW}${progress_prefix}開始標準化 (MP3)...${RESET}"
            # normalize_audio 的第二個參數是 *最終* 標準化音訊的輸出位置 (mp3 for mp3, m4a for video)
            # 所以這裡我們讓它輸出到一個臨時的 MP3，然後再加入封面
            if normalize_audio "$main_media_file" "$normalized_temp_audio_for_mp3" "$temp_dir" false; then # false 表示是音訊
                echo -e "${YELLOW}${progress_prefix}處理最終 MP3 (加入封面與元數據)...${RESET}"
                local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_temp_audio_for_mp3")
                if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then
                    ffmpeg_embed_args+=(-i "$thumbnail_file" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic)
                else
                    ffmpeg_embed_args+=(-c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name")
                fi
                ffmpeg_embed_args+=("$output_final_file")
                if ! "${ffmpeg_embed_args[@]}" > /dev/null 2>&1; then
                    log_message "ERROR" "...生成 MP3 失敗 (通用 std)..."; echo -e "${RED}錯誤：生成 MP3 失敗！${RESET}";
                    result=1; 
                else
                     result=0; 
                     safe_remove "$normalized_temp_audio_for_mp3" # 清理臨時標準化後的MP3
                fi
            else result=1; log_message "ERROR" "標準化失敗 (通用 MP3 std)"; fi

        elif [ "$choice_format" = "mp4" ]; then
            output_final_file="${media_output_dir}/${base_name_calculated_from_file}_normalized.mp4";
            local normalized_audio_m4a_for_mp4="$temp_dir/audio_normalized_for_mp4.m4a" # 標準化後的音訊(M4A)
            
            echo -e "${YELLOW}${progress_prefix}開始標準化 (提取音訊為 M4A)...${RESET}"
            # normalize_audio 的 is_video 參數為 true，所以它會輸出 M4A
            if normalize_audio "$main_media_file" "$normalized_audio_m4a_for_mp4" "$temp_dir" true; then # true 表示是影片
                echo -e "${YELLOW}${progress_prefix}混流影片與標準化音訊...${RESET}"
                local ffmpeg_mux_args=(ffmpeg -y -i "$main_media_file" -i "$normalized_audio_m4a_for_mp4" -c:v copy -c:a aac -b:a 256k -ar 44100 -map 0:v:0 -map 1:a:0 -movflags +faststart "$output_final_file")
                log_message "INFO" "執行 FFmpeg 混流 (通用 std): ${ffmpeg_mux_args[*]}"
                if ! "${ffmpeg_mux_args[@]}" > "$temp_dir/ffmpeg_mux.log" 2>&1; then
                     log_message "ERROR" "...混流 MP4 失敗 (通用 std)... 詳見 $temp_dir/ffmpeg_mux.log"; echo -e "${RED}錯誤：混流 MP4 失敗！${RESET}";
                     cat "$temp_dir/ffmpeg_mux.log"
                     result=1; 
                else
                     result=0; 
                     safe_remove "$normalized_audio_m4a_for_mp4" # 清理標準化後的M4A
                     rm -f "$temp_dir/ffmpeg_mux.log"
                fi
            else result=1; log_message "ERROR" "標準化失敗 (通用 MP4 std)"; fi
        fi
    fi 

    # --- 清理 ---
    log_message "INFO" "${progress_prefix}清理 (通用 std)...";
    if [ $result -eq 0 ] && [ -f "$main_media_file" ]; then # 處理成功才刪原始檔
        safe_remove "$main_media_file";
    fi
    if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then # 封面通常也應該在成功後與原始檔一起清理或嵌入後清理
        safe_remove "$thumbnail_file";
    fi
    safe_remove "$temp_dir/yt-dlp-other-std.log" "$temp_dir/yt-dlp-estimate.log" "$temp_dir/yt-dlp-thumb.log" "$temp_dir/ffmpeg_mux.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台報告 ---
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
        if [ -f "$main_media_file" ]; then echo -e "${YELLOW}原始下載檔案可能保留在：$main_media_file${RESET}"; fi
    fi

    # --- 條件式通知 (僅單獨模式) ---
    if ! $is_playlist && $should_notify; then
        local notification_title="媒體處理器：通用 標準化"
        local base_msg_notify="${progress_prefix}處理 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_final_file" ]; then
            final_path_notify="$output_final_file";
        elif [ -f "$main_media_file" ]; then 
             final_path_notify="$main_media_file"
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

###########################################################
# 輔助函數 - 處理單一通用網站媒體項目 (無音量標準化)
# <<< 修改 v2.5.x：接收輸出模板參數，修正檔名定位 >>>
# <<< 新增修改：針對 Bilibili 使用 aria2c 並優化參數 >>>
###########################################################
_process_single_other_site_no_normalize() {
    # --- 接收參數 ---
    local item_url="$1"; local choice_format="$2"; local item_index="$3"; local total_items="$4"
    local mode="$5"
    local output_template_playlist="$6" # 例如 "$DOWNLOAD_PATH/%(playlist_index)s-%(id)s.%(ext)s"
    local output_template_single_item="$7" # 例如 "$DOWNLOAD_PATH/%(id)s.%(ext)s"

    # --- 局部變數 ---
    local temp_dir=$(mktemp -d); local thumbnail_file=""; local main_media_file="";
    # base_name 將在成功獲取檔名後從實際檔名計算
    local base_name_from_template="" 
    local result=0;
    local progress_prefix=""; if [ -n "$item_index" ] && [ -n "$total_items" ]; then progress_prefix="[$item_index/$total_items] "; fi
    local should_notify=false
    local is_playlist=false
    local final_output_template_used="" 

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        log_message "INFO" "通用下載 無標準化：播放清單模式。"
    fi

    local item_title sanitized_title video_id
    item_title=$(yt-dlp --get-title "$item_url" 2>/dev/null) || item_title="media_item_$(date +%s)"
    video_id=$(yt-dlp --get-id "$item_url" 2>/dev/null) || video_id="no_id_$(date +%s)" # 確保 video_id 有值
    sanitized_title=$(echo "${item_title}" | sed 's@[/\\:*?"<>|]@_@g')
    log_message "DEBUG" "基礎標題: '$item_title', ID: '$video_id', 清理後: '$sanitized_title'"

    # --- 預估大小 (僅單獨模式) ---
    local yt_dlp_format_string_for_estimate=""
    if [ "$choice_format" = "mp4" ]; then yt_dlp_format_string_for_estimate="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
    else yt_dlp_format_string_for_estimate="bestaudio/best"; fi

    if ! $is_playlist; then
        echo -e "${YELLOW}正在預估檔案大小以決定是否通知...${RESET}"
        local estimated_size_bytes=0
        local size_list estimate_exit_code
        size_list=$(yt-dlp --no-warnings --print '%(filesize,filesize_approx)s' -f "$yt_dlp_format_string_for_estimate" "$item_url" 2>"$temp_dir/yt-dlp-estimate.log")
        estimate_exit_code=$?
        # ... (後續大小估計邏輯不變) ...
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
        local size_threshold_gb=0.5 
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

    echo -e "${CYAN}${progress_prefix}處理項目 (無標準化): $item_url (${choice_format})${RESET}";
    log_message "INFO" "${progress_prefix}處理項目 (無標準化): $item_url (格式: $choice_format)"

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; rm -rf "$temp_dir"; return 1; fi

    # --- 下載 ---
    local download_success=false
    local actual_yt_dlp_args=()
    local chosen_output_template=""

    echo -e "${YELLOW}${progress_prefix}開始下載 (無標準化)...${RESET}"

### MODIFIED BLOCK START ###
    # 判斷是否為 Bilibili URL 以使用特定參數
    if [[ "$item_url" == *"bilibili.com"* ]]; then
        log_message "INFO" "檢測到 Bilibili URL，將使用 aria2c 及優化參數。"
        echo -e "${CYAN}${progress_prefix}檢測到 Bilibili 網站，啟用 aria2c 加速下載。${RESET}"
        
        local bili_format_select=""
        if [ "$choice_format" = "mp4" ]; then
            # 優先選擇 AVC(H.264) 編碼的MP4，因其兼容性較好，最高1440p。
            # B站現在很多高畫質是HEVC(H.265)，如果需要HEVC，格式串要調整。
            # 此處格式串嘗試獲取 B站中常見的高清 MP4 (DASH分離的視訊和音訊)
            bili_format_select="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        else # mp3
            bili_format_select="bestaudio[ext=m4a]/bestaudio/best" # 優先m4a，yt-dlp會轉換
        fi

        actual_yt_dlp_args=(
            yt-dlp
            --no-warnings
            --no-simulate
            # --progress # aria2c 會自行顯示進度，yt-dlp 的 progress 可能與 aria2c 衝突或不準確
            --newline
            --downloader aria2c
            --downloader-args "aria2c:-x4 -s4 -k1M --retry-wait=5 --max-tries=0 --lowest-speed-limit=10K"
            --retries infinite
            --fragment-retries infinite # 對 HLS/DASH 片段重試
            --add-metadata
            --embed-thumbnail # 嘗試嵌入封面
            -f "$bili_format_select"
        )
        if [ "$choice_format" = "mp4" ]; then
            actual_yt_dlp_args+=(--merge-output-format mp4)
        elif [ "$choice_format" = "mp3" ]; then
            actual_yt_dlp_args+=(--extract-audio --audio-format mp3 --audio-quality 0)
        fi
    else
        # 非 Bilibili 網站，使用通用參數
        local generic_format_select=""
        if [ "$choice_format" = "mp4" ]; then
            generic_format_select="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
        else # mp3
            generic_format_select="bestaudio/best"
        fi

        actual_yt_dlp_args=(
            yt-dlp
            -f "$generic_format_select"
            --newline 
            --progress 
            --concurrent-fragments "$THREADS" 
            --no-simulate 
            --no-abort-on-error
            # --embed-thumbnail # 通用網站嵌入封面可能不穩定，可選
            # --add-metadata    # 通用網站元數據可能不佳，可選
        )
        if [ "$choice_format" = "mp4" ]; then
             actual_yt_dlp_args+=(--merge-output-format mp4) # 確保通用MP4合併
        elif [ "$choice_format" = "mp3" ]; then
            actual_yt_dlp_args+=(--extract-audio --audio-format mp3 --audio-quality 0)
        fi
    fi

    # 選擇輸出模板 (播放列表模式用 playlist 模板，單項用 single 模板)
    if $is_playlist; then
        chosen_output_template="$output_template_playlist"
    else
        chosen_output_template="$output_template_single_item"
    fi
    
    # 將選擇的輸出模板加入參數
    actual_yt_dlp_args+=(-o "$chosen_output_template")
    actual_yt_dlp_args+=("$item_url")

    log_message "INFO" "${progress_prefix}執行下載 (無標準化): ${actual_yt_dlp_args[*]}"
    if "${actual_yt_dlp_args[@]}" 2> "$temp_dir/yt-dlp-other-nonorm.log"; then
        download_success=true
        final_output_template_used="$chosen_output_template" 
    else
        log_message "ERROR" "...下載失敗 (無標準化)..."; echo -e "${RED}錯誤：下載失敗！${RESET}";
        cat "$temp_dir/yt-dlp-other-nonorm.log"
        result=1
    fi
### MODIFIED BLOCK END ###

    if $download_success; then
        echo -e "${YELLOW}${progress_prefix}定位下載的檔案...${RESET}"
        # 使用 --print filename 和記錄的 final_output_template_used 來獲取實際檔名
        # 格式參數需要與下載時一致
        local format_for_getfn=""
        if [[ "$item_url" == *"bilibili.com"* ]]; then
             if [ "$choice_format" = "mp4" ]; then format_for_getfn="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best";
             else format_for_getfn="bestaudio[ext=m4a]/bestaudio/best"; fi
        else
             if [ "$choice_format" = "mp4" ]; then format_for_getfn="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
             else format_for_getfn="bestaudio/best"; fi
        fi

        local yt_dlp_getfn_args=(yt-dlp --no-warnings --print filename -f "$format_for_getfn" -o "$final_output_template_used")
        # 如果是 MP3，yt-dlp 在 --extract-audio 後，--print filename 可能仍會打印原始下載的音訊檔名（如.m4a）而不是最終的.mp3
        # 所以這裡的 -f 參數主要用於確保 yt-dlp 能解析 URL 並應用模板，對於 MP3，最終檔名需要額外處理。

        # 對於 MP3 格式，由於 --extract-audio --audio-format mp3 的存在，
        # --print filename 可能不會直接給出 .mp3 的最終名稱，而是轉換前的。
        # 所以我們需要根據模板和選擇的 mp3 格式來推斷最終檔名。
        if [ "$choice_format" = "mp3" ]; then
            # 替換模板中的 %(ext)s 為 mp3
            # First, simulate what yt-dlp's template expansion would do for the base name part
            # This is tricky without actually running yt-dlp's template engine
            # A simpler approach: assume final_output_template_used gives the base, then change ext
            # Assuming final_output_template_used already has the download path and base filename (like /path/to/id.%(ext)s)
            # We need to get the part before .%(ext)s and append .mp3
            # This is still a heuristic. The most reliable way is often to list files after download.
            
            # Heuristic to get the filename that yt-dlp *would* create if it just used the template
            # and then change its extension to mp3 if needed.
            # yt-dlp --get-filename is safer for non-mp3. For mp3, it's complex.
            local temp_name_for_mp3_base
            temp_name_for_mp3_base=$(yt-dlp --no-warnings --get-filename -f "$format_for_getfn" -o "$final_output_template_used" "$item_url" | sed 's/\.[^.]*$//')
             if [ -n "$temp_name_for_mp3_base" ]; then
                actual_download_path="${temp_name_for_mp3_base}.mp3"
             else # Fallback if get-filename failed
                # Try to construct from template, highly heuristic
                # Example: output_template_single_item = $DOWNLOAD_PATH/%(id)s.%(ext)s
                # Replace %(id)s with actual id, and %(ext)s with mp3
                local base_template_no_ext=$(echo "$final_output_template_used" | sed 's/\.\%\(ext\)s$//')
                local populated_template_no_ext=$(echo "$base_template_no_ext" | sed "s/\%\(id\)s/$video_id/g" | sed "s/\%\(title\)s/$sanitized_title/g" ) # crude replacement
                actual_download_path="${populated_template_no_ext}.mp3"
             fi
             getfn_exit_code=0 # Assume success for this path
        else # For MP4
            # For MP4, --print filename with the format string used for download should be more reliable
             actual_download_path=$( "${yt_dlp_getfn_args[@]}" -o "$final_output_template_used" "$item_url" | tr -d '\n' )
             getfn_exit_code=$?
        fi

        log_message "DEBUG" "獲取檔名(格式: $choice_format)命令退出碼: $getfn_exit_code, 推斷/獲取的路徑: '$actual_download_path'"

        if [ $getfn_exit_code -eq 0 ] && [ -n "$actual_download_path" ] && [ -f "$actual_download_path" ]; then
            main_media_file="$actual_download_path"
            log_message "INFO" "${progress_prefix}成功定位到下載檔案: $main_media_file"
            # base_name_from_template is not used anymore, main_media_file is the final one
            result=0
        else
            log_message "ERROR" "...無法通過 --print filename / 推斷 獲取或驗證實際檔案路徑。退出碼: $getfn_exit_code, 路徑: '$actual_download_path'"
            echo -e "${RED}錯誤：下載後無法定位主要檔案！檢查日誌。${RESET}";
            result=1
        fi
    else
        log_message "DEBUG" "下載標記為失敗，跳過檔案定位。"
    fi

    # --- 無需處理縮圖和後續標準化，因為這是 no_normalize 版本 ---
    if [ $result -eq 0 ]; then
        log_message "INFO" "${progress_prefix}跳過音量標準化與後處理 (無標準化版本)。"
        echo -e "${GREEN}${progress_prefix}下載完成 (無標準化)。${RESET}"
    fi

    # --- 清理 ---
    log_message "INFO" "${progress_prefix}清理臨時檔案 (無標準化)..."
    safe_remove "$temp_dir/yt-dlp-other-nonorm.log" "$temp_dir/yt-dlp-estimate.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$main_media_file" ]; then
            echo -e "${GREEN}${progress_prefix}處理完成！檔案已儲存至：$main_media_file${RESET}";
            log_message "SUCCESS" "${progress_prefix}處理完成 (無標準化)！檔案：$main_media_file";
        else
            echo -e "${RED}${progress_prefix}處理似乎已完成，但最終檔案 '$main_media_file' 未找到！${RESET}";
            log_message "ERROR" "${progress_prefix}處理完成但最終檔案未找到 (無標準化)";
            result=1
        fi
    else
        echo -e "${RED}${progress_prefix}處理失敗 (無標準化)！${RESET}";
        log_message "ERROR" "${progress_prefix}處理失敗 (無標準化)：$item_url";
    fi

    # --- 條件式通知 (僅單獨模式) ---
    if ! $is_playlist && $should_notify; then
        local notification_title="媒體處理器：通用 無標準化"
        local base_msg_notify="${progress_prefix}處理 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$main_media_file" ]; then
             final_path_notify="$main_media_file"
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

############################################
# 處理其他網站媒體 (通用 MP3/MP4) - 支持實驗性批量下載 (含標準化)
# <<< 修改 v2.5.x：加入模板選擇邏輯；批量下載後發送總結通知 >>>
############################################
process_other_site_media_playlist() {
    local input_url=""; local choice_format=""
    local cf

    read -r -p "請輸入媒體網址 (單個或播放列表): " input_url; if [ -z "$input_url" ]; then echo -e "${RED}錯誤：未輸入！${RESET}"; return 1; fi

    log_message "INFO" "處理通用媒體/列表：$input_url"; echo -e "${YELLOW}處理通用媒體/列表：$input_url${RESET}"; echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"

    while true; do
        local cfn
        read -r -p "選擇格式 (1: MP3, 2: MP4): " cfn;
        case $cfn in
             1) cf="mp3"; break;;
             2) cf="mp4"; break;;
             *) echo "${RED}無效選項${RESET}";;
        esac;
    done;
    choice_format=$cf; log_message "INFO" "選擇格式: $choice_format"

    # --- 選擇輸出模板 (處理 Bilibili 長檔名) ---
    local template_playlist=""
    local template_single=""
    if [[ "$input_url" == *"bilibili.com"* ]]; then
        log_message "INFO" "檢測到 Bilibili URL (含標準化)，使用短檔名模板。"
        template_playlist="$DOWNLOAD_PATH/%(playlist_index)s-%(id)s.%(ext)s"
        template_single="$DOWNLOAD_PATH/%(id)s.%(ext)s"
    else
        log_message "INFO" "非 Bilibili URL (含標準化)，使用預設檔名模板。"
        template_playlist="$DOWNLOAD_PATH/%(playlist_index)s-%(title)s [%(id)s].%(ext)s"
        template_single="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    fi
    log_message "DEBUG" "使用的播放列表模板: $template_playlist"
    log_message "DEBUG" "使用的單一項目模板: $template_single"
    # --- 模板選擇結束 ---

    echo -e "${YELLOW}檢測是否為列表...${RESET}";
    local item_list_json; local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null); local jec=$?; if [ $jec -ne 0 ]; then log_message "WARNING" "dump-json 失敗..."; fi

    local item_urls=(); local item_count=0
    # ... (獲取 item_urls 和 item_count 的邏輯保持不變) ...
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url
            while IFS= read -r line; do
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    if [[ "$url" != "http"* ]]; then
                        # 嘗試從原始 URL 推斷域名
                        local domain=$(echo "$input_url" | grep -oP 'https?://[^/]+')
                        if [ -n "$domain" ]; then
                            url="${domain}${url}"
                        else # 如果無法推斷，預設 Bilibili (或提供錯誤)
                            url="https://www.bilibili.com${url}"
                            log_message "WARNING" "無法從原始URL推斷域名，預設為 Bilibili 補全相對路徑: $url"
                        fi
                    fi
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
        local ci=0; local success_count=0; local fail_count=0; local item_url_from_list # << 將 sc 改為 success_count, 新增 fail_count
        for item_url_from_list in "${item_urls[@]}"; do
            ci=$((ci + 1));
            # 傳遞模板參數，模式為 playlist_mode
            if _process_single_other_site "$item_url_from_list" "$choice_format" "$ci" "$item_count" "playlist_mode" "$template_playlist" "$template_single"; then
                success_count=$((success_count + 1)); # << 更新 success_count
            else
                fail_count=$((fail_count + 1));     # << 更新 fail_count
            fi
            echo "";
        done
        # --- 批量處理控制台總結 ---
        echo -e "${GREEN}列表處理完成！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。${RESET}"; # << 使用新變數名
        log_message "SUCCESS" "列表 $input_url 完成！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。"

        # --- <<< 新增：批量處理後發送總結通知 >>> ---
        local ovr=0
        if [ "$fail_count" -gt 0 ]; then ovr=1; fi
        local notification_title="媒體處理器：通用列表完成 (標準化)"
        local summary_msg="通用列表處理完成 ($success_count/$ci 成功)"
        _send_termux_notification "$ovr" "$notification_title" "$summary_msg" "" # 最後一個參數為空代表總結通知
        # --- 通知結束 ---

    else # 處理單個項目
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理...${RESET}";
            input_url=${item_urls[0]};
        else
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL。"
            echo -e "${YELLOW}未檢測到列表，按單個處理...${RESET}";
        fi
        # 單個處理，傳遞模板，不傳遞模式標記 (mode 為空)
        # _process_single_other_site 內部會執行大小判斷並觸發單項通知 (如果需要)
        _process_single_other_site "$input_url" "$choice_format" "" "" "" "$template_playlist" "$template_single"
    fi
}

#######################################################
# 處理其他網站媒體 (無音量標準化) - 支持實驗性批量下載
# <<< 修改 v2.5.x：加入模板選擇邏輯；批量下載後發送總結通知 >>>
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

    # --- 選擇輸出模板 (處理 Bilibili 長檔名) ---
    local template_playlist=""
    local template_single=""
    if [[ "$input_url" == *"bilibili.com"* ]]; then
        log_message "INFO" "檢測到 Bilibili URL (無標準化)，使用短檔名模板。"
        template_playlist="$DOWNLOAD_PATH/%(playlist_index)s-%(id)s.%(ext)s"
        template_single="$DOWNLOAD_PATH/%(id)s.%(ext)s"
    else
        log_message "INFO" "非 Bilibili URL (無標準化)，使用預設檔名模板。"
        template_playlist="$DOWNLOAD_PATH/%(playlist_index)s-%(title)s [%(id)s].%(ext)s"
        template_single="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    fi
    log_message "DEBUG" "使用的播放列表模板: $template_playlist"
    log_message "DEBUG" "使用的單一項目模板: $template_single"
    # --- 模板選擇結束 ---

    echo -e "${YELLOW}檢測是否為列表...${RESET}";
    local item_list_json; local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null); local jec=$?; if [ $jec -ne 0 ]; then log_message "WARNING" "dump-json 失敗..."; fi

    local item_urls=(); local item_count=0
    # ... (獲取 item_urls 和 item_count 的邏輯保持不變) ...
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url
            while IFS= read -r line; do
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    if [[ "$url" != "http"* ]]; then
                        local domain=$(echo "$input_url" | grep -oP 'https?://[^/]+')
                        if [ -n "$domain" ]; then
                            url="${domain}${url}"
                        else
                            url="https://www.bilibili.com${url}"
                            log_message "WARNING" "無法從原始URL推斷域名，預設為 Bilibili 補全相對路徑: $url"
                        fi
                    fi
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
        local ci=0; local success_count=0; local fail_count=0; local item_url_from_list # << 同上修改
        for item_url_from_list in "${item_urls[@]}"; do
            ci=$((ci + 1));
            # <<< 修改：傳遞模板參數，模式為 playlist_mode >>>
            if _process_single_other_site_no_normalize "$item_url_from_list" "$choice_format" "$ci" "$item_count" "playlist_mode" "$template_playlist" "$template_single"; then
                success_count=$((success_count + 1)); # << 更新
            else
                fail_count=$((fail_count + 1));     # << 更新
            fi
            echo "";
        done
        # --- 批量處理控制台總結 ---
        echo -e "${GREEN}列表處理完成 (無標準化)！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。${RESET}"; # << 使用新變數
        log_message "SUCCESS" "列表 $input_url (無標準化) 完成！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。"

        # --- <<< 新增：批量處理後發送總結通知 >>> ---
        local ovr=0
        if [ "$fail_count" -gt 0 ]; then ovr=1; fi
        local notification_title="媒體處理器：通用列表完成 (無標準化)" # << 標題區分
        local summary_msg="通用列表處理完成 ($success_count/$ci 成功)"
        _send_termux_notification "$ovr" "$notification_title" "$summary_msg" ""
        # --- 通知結束 ---

    else # 處理單個項目
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理 (無標準化)。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理 (無標準化)...${RESET}";
            input_url=${item_urls[0]};
        else
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL (無標準化)。"
            echo -e "${YELLOW}未檢測到列表，按單個處理 (無標準化)...${RESET}";
        fi
        # 單個處理，傳遞模板，不傳遞模式標記 (mode 為空)
        # _process_single_other_site_no_normalize 內部會執行大小判斷並觸發單項通知 (如果需要)
        _process_single_other_site_no_normalize "$input_url" "$choice_format" "" "" "" "$template_playlist" "$template_single"
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
# <<< v2.4.22+：僅總結通知，去除 DEBUG >>>
############################################
_process_youtube_playlist() {
    local playlist_url="$1"; local single_item_processor_func_name="$2"
    log_message "INFO" "處理 YouTube 播放列表: $playlist_url (處理器: $single_item_processor_func_name)"
    echo -e "${YELLOW}檢測到播放清單，開始批量處理...${RESET}"

    # --- 獲取數量 ---
    local raw_count_output
    raw_count_output=$(_get_playlist_video_count "$playlist_url")
    local total_videos_str
    total_videos_str=$(echo "$raw_count_output" | grep -oE '[0-9]+$' | tail -n 1)
    if ! [[ "$total_videos_str" =~ ^[0-9]+$ ]]; then
        log_message "ERROR" "無法從 _get_playlist_video_count 的輸出中提取有效的影片數量。原始輸出: $raw_count_output"
        echo -e "${RED}錯誤：無法解析播放清單數量。原始輸出:\n$raw_count_output${RESET}"
        return 1
    fi
    local total_videos="$total_videos_str"
    echo -e "${CYAN}播放清單共有 $total_videos 個影片${RESET}"

    # --- 獲取 IDs ---
    local playlist_ids_output; local yt_dlp_ids_args=(yt-dlp --flat-playlist -j "$playlist_url")
    playlist_ids_output=$("${yt_dlp_ids_args[@]}" 2>/dev/null); local gec=$?; if [ $gec -ne 0 ] || ! command -v jq &> /dev/null ; then log_message "ERROR" "無法獲取播放清單 IDs..."; echo -e "${RED}錯誤：無法獲取影片 ID 列表${RESET}"; return 1; fi
    local playlist_ids=(); while IFS= read -r id; do if [[ -n "$id" ]]; then playlist_ids+=("$id"); fi; done <<< "$(echo "$playlist_ids_output" | jq -r '.id // empty')"
    if [ ${#playlist_ids[@]} -eq 0 ]; then log_message "ERROR" "未找到影片 ID..."; echo -e "${RED}錯誤：未找到影片 ID${RESET}"; return 1; fi
    if [ ${#playlist_ids[@]} -ne "$total_videos" ]; then
        log_message "WARNING" "ID 數量 (${#playlist_ids[@]}) 與獲取的總數 ($total_videos) 不符，將以實際 ID 數量為準..."
        echo -e "${YELLOW}警告：實際數量 (${#playlist_ids[@]}) 與預計 ($total_videos) 不符，將以下載列表為準...${RESET}"
        total_videos=${#playlist_ids[@]}
    fi

    # --- 循環處理 ---
    local count=0; local success_count=0; local fail_count=0
    for id in "${playlist_ids[@]}"; do
        count=$((count + 1));
        local video_url="https://www.youtube.com/watch?v=$id"

        log_message "INFO" "[$count/$total_videos] 處理影片: $video_url"; echo -e "${CYAN}--- 正在處理第 $count/$total_videos 個影片 ---${RESET}"

        # 調用單項處理函數 (不傳遞模式標記)
        if "$single_item_processor_func_name" "$video_url"; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
            log_message "WARNING" "...處理失敗: $video_url"
            echo -e "${RED}處理失敗: $video_url${RESET}"
        fi
        echo ""
    done

    # --- 完成後報告 (控制台) ---
    echo -e "${GREEN}播放清單處理完成！共 $count 個影片，成功 $success_count 個，失敗 $fail_count 個${RESET}";
    log_message "SUCCESS" "播放清單 $playlist_url 完成！共 $count 個，成功 $success_count 個，失敗 $fail_count 個"

    # --- 發送總結通知 ---
    local ovr=0
    if [ "$fail_count" -gt 0 ]; then
         ovr=1
    # else # 不需要 else，ovr 預設為 0
    #     ovr=0
    fi
    # 直接在調用時使用字串
    _send_termux_notification "$ovr" "媒體處理器：播放清單完成" "播放清單處理完成 ($success_count/$count 成功)" ""
    # --- 通知結束 ---

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
# <<< 修改：設定 Termux 啟動時詢問 (使用變數路徑) >>>
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
    echo -e "${RED}${BOLD}警告：如果已有 .bashrc 文件，其內容將被覆蓋！${RESET}" # 稍微修改警告語氣
    echo -e "${YELLOW}如果您有自訂的 .bashrc 設定，請先備份 '${HOME}/.bashrc'。${RESET}"
    echo ""
    read -p "您確定要繼續嗎？ (y/n): " confirm_setup
    echo ""

    if [[ ! "$confirm_setup" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了 Termux 啟動設定。"
        echo -e "${YELLOW}已取消設定。${RESET}"
        return 1
    fi

    # --- 使用腳本內定義的 SCRIPT_INSTALL_PATH ---
    # 確保這個變數在腳本開頭被正確設定，指向 media_processor.sh 的實際位置
    local target_script_path="$SCRIPT_INSTALL_PATH"

    # 檢查目標腳本是否存在且可執行
    if [ ! -f "$target_script_path" ]; then
        log_message "ERROR" "找不到目標腳本檔案 '$target_script_path'。無法設定自動啟動。"
        echo -e "${RED}錯誤：找不到腳本檔案 '$target_script_path'！${RESET}"
        echo -e "${YELLOW}請確保 SCRIPT_INSTALL_PATH 變數指向正確的檔案路徑。${RESET}"
        return 1
    fi
    if [ ! -x "$target_script_path" ]; then
         echo -e "${YELLOW}警告：腳本檔案 '$target_script_path' 沒有執行權限，正在嘗試設定...${RESET}"
         if ! chmod +x "$target_script_path"; then
              log_message "ERROR" "無法設定 '$target_script_path' 的執行權限！"
              echo -e "${RED}錯誤：無法設定腳本的執行權限！請手動執行 'chmod +x $target_script_path'。${RESET}"
              return 1
         else
              log_message "INFO" "成功設定 '$target_script_path' 的執行權限。"
              echo -e "${GREEN}  > 執行權限設定成功。${RESET}"
         fi
    fi
    # --- 檢查結束 ---

    log_message "INFO" "開始設定 Termux 啟動腳本..."
    echo -e "${YELLOW}正在寫入設定到 ~/.bashrc ...${RESET}"

    # --- 使用 cat 和 EOF 將配置寫入 .bashrc ---
    # <<< 關鍵修改：alias 後面的路徑使用變數 $target_script_path >>>
cat > ~/.bashrc << EOF
# ~/.bashrc - v3 (Dynamic Alias Path)

# --- 媒體處理器啟動設定 ---

# 1. 定義別名 (使用腳本實際安裝路徑)
#    這個路徑是在運行 setup_termux_autostart 時由 media_processor.sh 腳本提供的
alias media='$target_script_path' # <<< 使用變數替換硬編碼路徑

# 2. 僅在交互式 Shell 啟動時顯示提示
if [[ \$- == *i* ]]; then
    # --- 在此處定義此 if 塊內使用的顏色變數 ---
    CLR_RESET='\033[0m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[1;33m'
    CLR_RED='\033[0;31m'
    CLR_CYAN='\033[0;36m'
    # --- 顏色定義結束 ---

    echo ""
    echo -e "\${CLR_CYAN}歡迎使用 Termux!\${CLR_RESET}"
    echo -e "\${CLR_YELLOW}是否要啟動媒體處理器？\${CLR_RESET}"
    echo -e "1) \${CLR_GREEN}立即啟動\${CLR_RESET}"
    echo -e "2) \${CLR_YELLOW}稍後啟動 (輸入 'media' 命令啟動)\${CLR_RESET}"
    echo -e "0) \${CLR_RED}不啟動\${CLR_RESET}"

    # read 命令
    read -t 60 -p "請選擇 (0-2) [60秒後自動選 2]: " choice
    choice=\${choice:-2} # 注意這裡 $choice 前面需要反斜線，防止被外層腳本解析

    case \$choice in # 注意這裡 $choice 前面需要反斜線
        1)
            echo -e "\n\${CLR_GREEN}正在啟動媒體處理器...\${CLR_RESET}"
            media # 執行別名
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
    # <<< EOF 結束 >>>

    # 檢查寫入是否成功
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Termux 啟動設定已成功寫入 ~/.bashrc (使用路徑: $target_script_path)"
        echo -e "${GREEN}設定成功！${RESET}"
        echo -e "${CYAN}請重新啟動 Termux 或執行 'source ~/.bashrc' 來讓設定生效。${RESET}"
        # 強制重新載入 .bashrc 使別名立即生效
        source ~/.bashrc
        echo -e "${CYAN}已嘗試重新載入設定，您現在應該可以使用 'media' 命令來執行 '$target_script_path' 了。${RESET}"
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
# <<< 修改：腳本設定與工具選單 (加入同步設定和Termux完整更新選項) >>>
############################################
utilities_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 腳本設定與工具 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 參數設定 (執行緒, 下載路徑, 顏色)"
        echo -e " 2. 檢視操作日誌"
        echo -e " 3. ${BOLD}檢查並更新依賴套件${RESET} (腳本自身依賴)"
        echo -e " 4. ${BOLD}檢查腳本更新${RESET}"
        echo -e " 5. ${BOLD}設定日誌終端顯示級別${RESET}"
        # <<< 新增同步功能設定選項 >>>
        echo -e " 6. ${BOLD}同步功能設定${RESET} (新手機 -> 舊手機)"

        local termux_options_start_index=7 # Termux 特定選項的起始編號 (因為前面加了同步設定)
        local current_max_option=6 # 非 Termux 時的最大選項號 (不計0)

        if [[ "$OS_TYPE" == "termux" ]]; then
            echo -e " ${termux_options_start_index}. ${BOLD}設定 Termux 啟動時詢問${RESET}"
            echo -e " $((termux_options_start_index + 1)). ${BOLD}完整更新 Termux 環境${RESET} (pkg update && upgrade)"
            current_max_option=$((termux_options_start_index + 1)) # Termux 時的最大選項號
        fi
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard # 清除緩衝區

        local choice_prompt="輸入選項 (0-${current_max_option}): "
        local choice

        read -rp "$choice_prompt" choice

        case $choice in
            1)
                config_menu
                # config_menu 內部處理返回
                ;;
            2)
                view_log
                # view_log 使用 less，退出後自動返回
                ;;
            3)
                update_dependencies # 更新腳本的依賴 (yt-dlp, ffmpeg 等)
                # update_dependencies 內部有 "按 Enter 返回"
                ;;
            4)
                auto_update_script # 腳本自我更新
                # auto_update_script 內部有 "按 Enter 返回"
                ;;
            5)
                configure_terminal_log_display_menu # 跳轉到日誌級別設定子選單
                # configure_terminal_log_display_menu 內部處理返回
                ;;
            6) # <<< 新增 Case，處理同步功能設定 >>>
                configure_sync_settings_menu # 跳轉到同步功能設定子選單
                # configure_sync_settings_menu 內部處理返回
                ;;
            7) # Termux 啟動詢問 (如果存在)
                if [[ "$OS_TYPE" == "termux" ]]; then
                    setup_termux_autostart
                    echo ""; read -p "按 Enter 返回工具選單..."
                else
                    # 如果不是 Termux，但用戶可能錯誤輸入了這個數字
                    echo -e "${RED}無效選項 '$choice' (非 Termux 環境或選項不存在)${RESET}"; sleep 1
                fi
                ;;
            8) # Termux 完整更新 (如果存在)
                if [[ "$OS_TYPE" == "termux" ]]; then
                    clear
                    echo -e "${CYAN}--- 完整更新 Termux 環境 ---${RESET}"
                    echo -e "${YELLOW}此操作將執行 'pkg update -y && pkg upgrade -y'。${RESET}"
                    echo -e "${YELLOW}這會更新您 Termux 環境中所有已安裝的套件，可能需要一些時間。${RESET}"
                    echo -e "${RED}${BOLD}請確保您的網路連線穩定。${RESET}"
                    echo ""
                    local confirm_full_termux_update # 使用不同變數名以示區分
                    read -p "您確定要繼續嗎？ (y/n): " confirm_full_termux_update

                    if [[ "$confirm_full_termux_update" =~ ^[Yy]$ ]]; then
                        log_message "INFO" "使用者觸發 Termux 環境完整更新。"
                        echo -e "\n${CYAN}正在開始更新 Termux 環境... 這可能需要幾分鐘或更長時間。${RESET}"
                        echo -e "${CYAN}請耐心等待，不要中斷此過程。${RESET}"
                        
                        if pkg update -y && pkg upgrade -y; then
                            log_message "SUCCESS" "Termux 環境已成功更新。"
                            echo -e "\n${GREEN}Termux 環境已成功更新完畢！${RESET}"
                        else
                            log_message "ERROR" "Termux 環境更新過程中發生錯誤。"
                            echo -e "\n${RED}Termux 環境更新過程中發生錯誤。${RESET}"
                            echo -e "${RED}請檢查上面的輸出訊息以了解詳情。${RESET}"
                            echo -e "${YELLOW}您可能需要手動執行 'pkg update' 和 'pkg upgrade' 來解決問題。${RESET}"
                        fi
                    else
                        log_message "INFO" "使用者取消了 Termux 環境完整更新。"
                        echo -e "\n${YELLOW}已取消 Termux 環境更新。${RESET}"
                    fi
                    echo ""; read -p "按 Enter 返回工具選單..."
                else
                    echo -e "${RED}無效選項 '$choice' (非 Termux 環境或選項不存在)${RESET}"; sleep 1
                fi
                ;;
            0)
                return # 返回到主選單
                ;;
            *)
                if [[ -z "$choice" ]]; then
                    continue # 如果是空輸入，重新顯示選單
                else
                    echo -e "${RED}無效選項 '$choice'${RESET}"
                    log_message "WARNING" "工具選單輸入無效選項: $choice"
                    sleep 1
                fi
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
# 新增：設定同步功能參數選單
# (此函數用於設定 Bash 變數，這些變數將傳遞給 Python 輔助腳本)
############################################
configure_sync_settings_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 同步功能設定 (新手機 -> 舊手機) ---${RESET}"
        echo -e "${YELLOW}這些設定將用於配置 Rsync + SSH 同步。${RESET}"
        echo -e "${YELLOW}當前設定：${RESET}"
        echo -e " 1. 新手機來源目錄: ${GREEN}${SYNC_SOURCE_DIR_NEW_PHONE:-未設定}${RESET}"
        echo -e " 2. 舊手機 SSH IP  : ${GREEN}${SYNC_TARGET_SSH_HOST_OLD_PHONE:-未設定}${RESET}"
        echo -e " 3. 舊手機 SSH 用戶: ${GREEN}${SYNC_TARGET_SSH_USER_OLD_PHONE:-未設定}${RESET}"
        echo -e " 4. 舊手機 SSH 端口: ${GREEN}${SYNC_TARGET_SSH_PORT_OLD_PHONE:-預設22 (Termux 常為 8022)}${RESET}"
        echo -e " 5. 舊手機目標目錄: ${GREEN}${SYNC_TARGET_DIR_OLD_PHONE:-未設定}${RESET}"
        echo -e " 6. 新手機 SSH 私鑰: ${GREEN}${SYNC_SSH_KEY_PATH_NEW_PHONE:-未使用/將提示密碼}${RESET}"
        echo -e " 7. 同步影片擴展名: ${GREEN}${SYNC_VIDEO_EXTENSIONS:-未設定}${RESET} (例: mp4,mov,mkv)"
        echo -e " 8. 同步照片擴展名: ${GREEN}${SYNC_PHOTO_EXTENSIONS:-未設定}${RESET} (例: jpg,jpeg,png,heic)"
        echo -e "---------------------------------------------"
        echo -e " 9. ${BOLD}測試 SSH 連線到舊手機${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回上一層選單 (並儲存設定)${RESET}"
        echo -e "---------------------------------------------"
        echo -e "${CYAN}輸入選項編號以修改，或輸入 0 返回。${RESET}"

        read -t 0.1 -N 10000 discard # 清除緩衝區
        local choice
        read -rp "輸入選項 (0-9): " choice

        case $choice in
            1)
                read -e -p "輸入新手機的來源目錄 (例如 /sdcard/DCIM/Camera 或 ~/storage/shared/DCIM/Camera): " SYNC_SOURCE_DIR_NEW_PHONE
                # 可以在此處加入對輸入路徑的基礎驗證，例如是否為空
                ;;
            2)
                read -e -p "輸入舊手機的 SSH IP 地址: " SYNC_TARGET_SSH_HOST_OLD_PHONE
                ;;
            3)
                read -e -p "輸入登錄舊手機的 SSH 用戶名 (通常與 Termux 用戶名相同): " SYNC_TARGET_SSH_USER_OLD_PHONE
                ;;
            4)
                read -e -p "輸入舊手機的 SSH 端口號 (預設 22, Termux 常為 8022): " SYNC_TARGET_SSH_PORT_OLD_PHONE
                ;;
            5)
                read -e -p "輸入舊手機上接收檔案的【完整】目錄路徑: " SYNC_TARGET_DIR_OLD_PHONE
                ;;
            6)
                read -e -p "輸入新手機上 SSH 私鑰的【完整】路徑 (可選, 留空則提示密碼): " SYNC_SSH_KEY_PATH_NEW_PHONE
                if [ -n "$SYNC_SSH_KEY_PATH_NEW_PHONE" ] && [ ! -f "$SYNC_SSH_KEY_PATH_NEW_PHONE" ]; then
                    echo -e "${RED}警告：指定的 SSH 私鑰路徑檔案不存在！${RESET}"; sleep 2
                fi
                ;;
            7)
                read -e -p "輸入要同步的影片擴展名 (逗號分隔, 無點, 例如 mp4,mov,mkv): " SYNC_VIDEO_EXTENSIONS
                # 清理可能的空格並轉換為小寫 (可選，但建議)
                SYNC_VIDEO_EXTENSIONS=$(echo "$SYNC_VIDEO_EXTENSIONS" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]//g')
                ;;
            8)
                read -e -p "輸入要同步的照片擴展名 (逗號分隔, 無點, 例如 jpg,jpeg,png): " SYNC_PHOTO_EXTENSIONS
                SYNC_PHOTO_EXTENSIONS=$(echo "$SYNC_PHOTO_EXTENSIONS" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]//g')
                ;;
            9) # 測試 SSH 連線
                if [ -n "$SYNC_TARGET_SSH_HOST_OLD_PHONE" ] && [ -n "$SYNC_TARGET_SSH_USER_OLD_PHONE" ]; then
                    local test_ssh_port_val="${SYNC_TARGET_SSH_PORT_OLD_PHONE:-8022}" # Termux 預設 8022，標準 SSH 22
                    local test_ssh_key_opt_val=""
                    if [ -n "$SYNC_SSH_KEY_PATH_NEW_PHONE" ] && [ -f "$SYNC_SSH_KEY_PATH_NEW_PHONE" ]; then
                        # 確保引用私鑰路徑，以防路徑中包含空格 (雖然不常見於私鑰路徑)
                        test_ssh_key_opt_val="-i \"$SYNC_SSH_KEY_PATH_NEW_PHONE\""
                    fi
                    echo -e "\n${YELLOW}正在嘗試連接到 ${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE} 端口 ${test_ssh_port_val}...${RESET}"
                    echo -e "${CYAN}將執行 'ssh -o ConnectTimeout=10 ${test_ssh_key_opt_val} -p \"${test_ssh_port_val}\" \"${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}\" exit'${RESET}"
                    echo -e "${YELLOW}如果需要密碼，系統會提示您輸入。${RESET}"
                    
                    # 使用 eval 來正確處理帶有引號的 $test_ssh_key_opt_val
                    # 或者不使用 eval，但確保 $test_ssh_key_opt_val 中的引號被 ssh 命令正確解析
                    # 更安全的方式是構建數組：
                    local ssh_test_cmd_array=("ssh" "-o" "ConnectTimeout=10")
                    if [ -n "$SYNC_SSH_KEY_PATH_NEW_PHONE" ] && [ -f "$SYNC_SSH_KEY_PATH_NEW_PHONE" ]; then
                        ssh_test_cmd_array+=("-i" "$SYNC_SSH_KEY_PATH_NEW_PHONE")
                    fi
                    ssh_test_cmd_array+=("-p" "$test_ssh_port_val" "${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}" "exit")

                    if "${ssh_test_cmd_array[@]}"; then
                        echo -e "${GREEN}SSH 連線測試成功！${RESET}"
                    else
                        echo -e "${RED}SSH 連線測試失敗！請檢查設定、網路、舊手機SSHD服務是否運行以及防火牆設定。${RESET}"
                    fi
                else
                    echo -e "${RED}請先設定舊手機的 SSH 主機 IP 和 SSH 用戶名才能進行測試。${RESET}"
                fi
                read -p "按 Enter 繼續..."
                ;;
            0)
                save_config # 退出前保存所有更改
                log_message "INFO" "同步設定已儲存。"
                return 0 # 返回到 utilities_menu
                ;;
            *)
                if [[ -z "$choice" ]]; then
                    continue # 如果是空輸入，重新顯示選單
                else
                    echo -e "${RED}無效選項 '$choice'${RESET}"
                    log_message "WARNING" "同步設定選單輸入無效: $choice"
                    sleep 1
                fi
                ;;
        esac
        # 每次有效修改後（選項1-8）都保存一次
        if [[ "$choice" -ge 1 && "$choice" -le 8 ]]; then
             save_config
             log_message "INFO" "同步設定已更新 (選項: $choice)。"
             # sleep 0.5 # 短暫停頓讓用戶看到更改，或在循環開始時清屏已足夠
        fi
    done
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

############################################
# 新增：設定日誌終端顯示級別選單
############################################
configure_terminal_log_display_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 設定日誌終端顯示級別 ---${RESET}"
        echo -e "${YELLOW}選擇要切換顯示狀態的日誌級別：${RESET}"
        # 輔助函數來獲取當前狀態的顯示文字
        get_display_status() {
            if [[ "$1" == "true" ]]; then echo -e "${GREEN}顯示${RESET}"; else echo -e "${RED}隱藏${RESET}"; fi
        }

        echo -e " 1. INFO    級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_INFO")"
        echo -e " 2. WARNING 級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_WARNING")"
        echo -e " 3. ERROR   級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_ERROR")"
        echo -e " 4. SUCCESS 級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_SUCCESS")"
        echo -e " 5. DEBUG   級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_DEBUG")"
        echo -e " 6. SECURITY級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_SECURITY")"
        echo -e "---------------------------------------------"
        echo -e " 7. ${GREEN}全部設定為顯示${RESET}"
        echo -e " 8. ${YELLOW}全部設定為隱藏 (除 ERROR 和 SECURITY 外)${RESET}"
        echo -e " 9. ${BLUE}恢復預設設定${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回上一層選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice
        read -rp "輸入選項 (0-9): " choice

        case $choice in
            1) toggle_terminal_log_level "INFO" ;;
            2) toggle_terminal_log_level "WARNING" ;;
            3) toggle_terminal_log_level "ERROR" ;;
            4) toggle_terminal_log_level "SUCCESS" ;;
            5) toggle_terminal_log_level "DEBUG" ;;
            6) toggle_terminal_log_level "SECURITY" ;;
            7) # 全部顯示
                TERMINAL_LOG_SHOW_INFO="true"
                TERMINAL_LOG_SHOW_WARNING="true"
                TERMINAL_LOG_SHOW_ERROR="true"
                TERMINAL_LOG_SHOW_SUCCESS="true"
                TERMINAL_LOG_SHOW_DEBUG="true"
                TERMINAL_LOG_SHOW_SECURITY="true"
                log_message "INFO" "所有日誌級別的終端顯示已設為：顯示"
                save_config
                echo -e "${GREEN}所有日誌級別的終端顯示已設為：顯示${RESET}"; sleep 1
                ;;
            8) # 全部隱藏 (除關鍵外)
                TERMINAL_LOG_SHOW_INFO="false"
                TERMINAL_LOG_SHOW_WARNING="false"
                TERMINAL_LOG_SHOW_ERROR="true"   # 保留 ERROR
                TERMINAL_LOG_SHOW_SUCCESS="false"
                TERMINAL_LOG_SHOW_DEBUG="false"
                TERMINAL_LOG_SHOW_SECURITY="true" # 保留 SECURITY
                log_message "INFO" "大部分日誌級別的終端顯示已設為：隱藏 (ERROR, SECURITY 除外)"
                save_config
                echo -e "${YELLOW}大部分日誌級別的終端顯示已設為：隱藏 (ERROR, SECURITY 除外)${RESET}"; sleep 1
                ;;
            9) # 恢復預設
                TERMINAL_LOG_SHOW_INFO="true"    # 預設 INFO 顯示
                TERMINAL_LOG_SHOW_WARNING="true" # 預設 WARNING 顯示
                TERMINAL_LOG_SHOW_ERROR="true"   # 預設 ERROR 顯示
                TERMINAL_LOG_SHOW_SUCCESS="true" # 預設 SUCCESS 顯示
                TERMINAL_LOG_SHOW_DEBUG="false"  # 預設 DEBUG 隱藏
                TERMINAL_LOG_SHOW_SECURITY="true" # 預設 SECURITY 顯示
                log_message "INFO" "日誌終端顯示已恢復預設設定。"
                save_config
                echo -e "${BLUE}日誌終端顯示已恢復預設設定。${RESET}"; sleep 1
                ;;
            0) return ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "日誌顯示設定選單輸入無效: $choice"; sleep 1; fi
                ;;
        esac
    done
}

############################################
# 輔助函數：切換指定日誌級別的終端顯示狀態
############################################
toggle_terminal_log_level() {
    local level_name="$1" # 例如 "INFO", "DEBUG"
    local var_name="TERMINAL_LOG_SHOW_${level_name}"
    local current_status
    eval "current_status=\"\$$var_name\"" # 獲取變數的當前值

    if [[ "$current_status" == "true" ]]; then
        eval "$var_name=\"false\""
        echo -e "${level_name} 級別日誌終端顯示已切換為：${RED}隱藏${RESET}"
    else
        eval "$var_name=\"true\""
        echo -e "${level_name} 級別日誌終端顯示已切換為：${GREEN}顯示${RESET}"
    fi
    log_message "INFO" "${level_name} 級別日誌終端顯示切換為: \$$var_name" # \$$var_name 輸出變數名
    save_config # 保存更改
    sleep 1
}

############################################
# 檢視日誌
############################################
view_log() {
    # --- 函數邏輯不變 ---
    if [ -f "$LOG_FILE" ]; then less -R "$LOG_FILE"; else echo -e "${RED}日誌不存在: $LOG_FILE ${RESET}"; log_message "WARNING" "日誌不存在: $LOG_FILE"; sleep 2; fi
}

############################################
# <<< 修改：關於訊息 (顯示 Git 版本、環境狀態、yt-dlp版本，修正顏色和對齊) >>>
############################################
show_about_enhanced() {
    clear
    echo -e "${CYAN}=== 整合式影音處理平台 ===${RESET}"
    echo -e "---------------------------------------------"

    # --- 嘗試從 Git 獲取版本信息 ---
    local git_version_info=""
    local git_commit_hash=""
    local git_tag=""
    if command -v git &> /dev/null && [ -d "$SCRIPT_DIR/.git" ]; then
        git_tag=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null)
        git_commit_hash=$(git -C "$SCRIPT_DIR" log -1 --pretty=%h 2>/dev/null)
        if [ -n "$git_tag" ]; then
            git_version_info="$git_tag"
            if [ -n "$git_commit_hash" ]; then
                 local commit_for_tag=$(git -C "$SCRIPT_DIR" rev-list -n 1 "$git_tag" 2>/dev/null)
                 local current_head=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)
                 if [[ "$commit_for_tag" != "$current_head" ]]; then
                      git_version_info+=" (+${git_commit_hash})" # 標記非 tag 的最新 commit
                 fi
            fi
        elif [ -n "$git_commit_hash" ]; then
             git_version_info="commit ${git_commit_hash}" # 如果沒有 tag，顯示 commit hash
        fi
    fi
    # 如果無法從 Git 獲取，則使用腳本內定義的版本
    local display_version="${git_version_info:-$SCRIPT_VERSION}"

    echo -e "${BOLD}版本:${RESET}        ${GREEN}${display_version}${RESET}"
    if [ -n "$SCRIPT_UPDATE_DATE" ]; then echo -e "${BOLD}更新日期:${RESET}    ${GREEN}${SCRIPT_UPDATE_DATE}${RESET}"; fi

    # --- 腳本 SHA256 (可以保留作為參考，但 Git hash 更可靠) ---
    local current_script_checksum="無法計算"
    if command -v sha256sum &> /dev/null && [ -f "$SCRIPT_INSTALL_PATH" ]; then current_script_checksum=$(sha256sum "$SCRIPT_INSTALL_PATH" | awk '{print $1}'); fi
    echo -e "${BOLD}主腳本 SHA256:${RESET} ${YELLOW}${current_script_checksum}${RESET}"
    echo -e "---------------------------------------------"

    # --- 新增：腳本環境狀態 ---
    echo -e "${CYAN}--- 腳本環境狀態 ---${RESET}"

    # 輔助函數顯示狀態 (使用 printf 進行對齊，修正顏色處理)
    display_status() {
        local item_name="$1"
        local is_ok="$2"    # true or false
        local detail="$3"   # e.g., version or path
        local item_name_display="${item_name}:" 
        
        # 調整欄位寬度，您可以根據實際效果修改此值
        # 20 是一個比較折衷的值，可以根據您的終端和字型調整
        local name_field_width=20 

        if [ "$is_ok" = true ]; then
            # 將顏色代碼直接放入 printf 的格式字串
            if [ -n "$detail" ]; then # 如果有詳細資訊
                printf "%-${name_field_width}s \033[0;32m%s\033[0m \033[0;32m%s\033[0m\n" "$item_name_display" "已安裝 / 已獲取" "$detail"
            else # 如果沒有詳細資訊
                printf "%-${name_field_width}s \033[0;32m%s\033[0m\n" "$item_name_display" "已安裝 / 已獲取"
            fi
        else # is_ok is false
            if [ -n "$detail" ]; then # 如果有詳細資訊
                printf "%-${name_field_width}s \033[0;31m%s\033[0m \033[0;31m%s\033[0m\n" "$item_name_display" "未安裝 / 未獲取" "$detail"
            else # 如果沒有詳細資訊
                printf "%-${name_field_width}s \033[0;31m%s\033[0m\n" "$item_name_display" "未安裝 / 未獲取"
            fi
        fi
    }

    local tool_status py_status ytdlp_status aria2c_status
    local py_exe py_version ytdlp_version

    echo -e "${YELLOW}核心工具:${RESET}"
    # 為核心工具名稱添加兩個前導空格，以便在視覺上與分類標題區分
    for tool in ffmpeg ffprobe jq curl; do
        tool_status=false; command -v "$tool" &> /dev/null && tool_status=true
        display_status "  $tool" "$tool_status" ""
    done

    py_status=false; py_exe=""
    if command -v python3 &> /dev/null; then py_exe="python3"; py_status=true;
    elif command -v python &> /dev/null; then py_exe="python"; py_status=true; fi
    if $py_status; then
        py_version=$($py_exe --version 2>&1 | sed 's/Python //') # 獲取並清理版本號
        display_status "  Python" true "(版本: $py_version)"
    else
        display_status "  Python" false ""
    fi

    ytdlp_status=false; ytdlp_version="N/A"
    if command -v yt-dlp &> /dev/null; then
        ytdlp_status=true
        ytdlp_version=$(yt-dlp --version 2>/dev/null || echo "無法獲取")
    fi
    display_status "  yt-dlp" "$ytdlp_status" "(版本: $ytdlp_version)"
    
    aria2c_status=false
    command -v aria2c &> /dev/null && aria2c_status=true
    display_status "  aria2c" "$aria2c_status" "(用於 Bilibili 加速)"

    echo -e "\n${YELLOW}權限與路徑:${RESET}"
    if [[ "$OS_TYPE" == "termux" ]]; then
        local termux_storage_ok=false
        if [ -d "/sdcard" ] && touch "/sdcard/.termux-test-write-about" 2>/dev/null; then
            termux_storage_ok=true
            rm -f "/sdcard/.termux-test-write-about" # 清理測試檔案
        fi
        display_status "  Termux 儲存權限" "$termux_storage_ok" ""
    fi

    local dl_path_ok=false
    local dl_path_display="$DOWNLOAD_PATH"
    if [ -z "$dl_path_display" ]; then dl_path_display="(未設定)"; fi
    if [ -n "$DOWNLOAD_PATH" ] && [ -d "$DOWNLOAD_PATH" ] && [ -w "$DOWNLOAD_PATH" ]; then dl_path_ok=true; fi
    display_status "  下載目錄可寫" "$dl_path_ok" "$dl_path_display"

    local temp_dir_ok=false
    local temp_dir_display="$TEMP_DIR"
    if [ -z "$temp_dir_display" ]; then temp_dir_display="(未設定)"; fi
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ] && [ -w "$TEMP_DIR" ]; then temp_dir_ok=true; fi
    display_status "  臨時目錄可寫" "$temp_dir_ok" "$temp_dir_display"
    echo -e "---------------------------------------------"
    # --- 環境狀態結束 ---


    echo -e "\n${GREEN}主要功能特色：${RESET}"
    echo -e "- YouTube 影音下載 (MP3/MP4/MKV)"
    echo -e "- 通用網站媒體下載 (MP3/MP4, 實驗性, Bilibili 使用 aria2c 加速)"
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
# <<< 修改：環境檢查 (移除 webvtt-py 和 mkvmerge 相關內容) >>>
############################################
check_environment() {
    # <<< core_tools 保持不變 (beta.7 已移除 mkvmerge) >>>
    local core_tools=("yt-dlp" "ffmpeg" "ffprobe" "jq" "curl")
    local missing_tools=()
    local python_found=false
    local python_cmd=""
    # local webvtt_lib_found=false # 移除 webvtt-py 變數
    local check_failed=false

    echo -e "${CYAN}正在進行環境檢查...${RESET}"
    log_message "INFO" "開始環境檢查 (OS: $OS_TYPE)..."

    # 檢查核心工具
    for tool in "${core_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            echo -e "${YELLOW}  - 缺少: $tool ${RESET}"
            check_failed=true
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
        check_failed=true
    fi

    # <<< 移除檢查 webvtt-py 庫的程式碼區塊 >>>

    # --- Termux 特定儲存權限檢查 ---
    if [[ "$OS_TYPE" == "termux" ]]; then
        echo -e "${CYAN}正在檢查 Termux 儲存權限...${RESET}"
        if [ ! -d "/sdcard" ] || ! touch "/sdcard/.termux-test-write" 2>/dev/null; then
            clear
            echo -e "${RED}=== 環境檢查失敗 (Termux 儲存權限) ===${RESET}"
            echo -e "${YELLOW}無法存取或寫入外部存儲 (/sdcard)！${RESET}"
            echo -e "${CYAN}請先在 Termux 中手動執行以下命令授予權限：${RESET}"
            echo -e "${GREEN}termux-setup-storage${RESET}"
            echo -e "${CYAN}然後重新啟動 Termux 和此腳本。${RESET}"
            log_message "ERROR" "環境檢查失敗：無法存取或寫入 /sdcard"
            rm -f "/sdcard/.termux-test-write"
            check_failed=true
        else
            rm -f "/sdcard/.termux-test-write"
             echo -e "${GREEN}  > Termux 儲存權限正常。${RESET}"
        fi
    fi

    # --- 通用下載和臨時目錄檢查 ---
    echo -e "${CYAN}正在檢查目錄權限...${RESET}"
    if [ -z "$DOWNLOAD_PATH" ]; then
         echo -e "${RED}錯誤：下載目錄路徑未設定！${RESET}"; log_message "ERROR" "環境檢查失敗：下載目錄未設定。"; check_failed=true;
    elif ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建下載目錄：$DOWNLOAD_PATH ${RESET}"; log_message "ERROR" "環境檢查失敗：無法創建下載目錄 $DOWNLOAD_PATH"; check_failed=true;
    elif [ ! -w "$DOWNLOAD_PATH" ]; then
         echo -e "${RED}錯誤：下載目錄不可寫：$DOWNLOAD_PATH ${RESET}"; log_message "ERROR" "環境檢查失敗：下載目錄不可寫 $DOWNLOAD_PATH"; check_failed=true;
    else
         echo -e "${GREEN}  > 下載目錄 '$DOWNLOAD_PATH' 可寫。${RESET}"
    fi

    if [ -z "$TEMP_DIR" ]; then
         echo -e "${RED}錯誤：臨時目錄路徑未設定！${RESET}"; log_message "ERROR" "環境檢查失敗：臨時目錄未設定。"; check_failed=true;
    elif ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建臨時目錄：$TEMP_DIR ${RESET}"; log_message "ERROR" "環境檢查失敗：無法創建臨時目錄 $TEMP_DIR"; check_failed=true;
    elif [ ! -w "$TEMP_DIR" ]; then
         echo -e "${RED}錯誤：臨時目錄不可寫：$TEMP_DIR ${RESET}"; log_message "ERROR" "環境檢查失敗：臨時目錄不可寫 $TEMP_DIR"; check_failed=true;
    else
         echo -e "${GREEN}  > 臨時目錄 '$TEMP_DIR' 可寫。${RESET}"
    fi

    # --- 檢查是否有任何失敗標記 ---
    if [ "$check_failed" = true ]; then
        log_message "ERROR" "環境檢查檢測到問題。"
        if [ ${#missing_tools[@]} -ne 0 ]; then
             echo -e "\n${YELLOW}檢測到缺少以下工具或庫：${RESET}"
             for tool in "${missing_tools[@]}"; do echo -e "${RED}  - $tool${RESET}"; done
             echo -e "\n${CYAN}安裝提示:${RESET}"
             if [[ "$OS_TYPE" == "termux" ]]; then
                  # <<< 移除提示中的 webvtt-py >>>
                  # <<< update_dependencies 不安裝 mkvtoolnix，所以提示也不需要 mkvmerge >>>
                  echo -e "${GREEN}Termux: pkg install ffmpeg jq curl python python-pip && pip install -U yt-dlp${RESET}"
             elif [[ "$OS_TYPE" == "wsl" || "$OS_TYPE" == "linux" ]]; then
                 local install_cmd=""
                 # <<< 從安裝命令建議中移除 mkvmerge >>>
                 if [[ "$PACKAGE_MANAGER" == "apt" ]]; then install_cmd="sudo apt install -y ffmpeg jq curl python3 python3-pip";
                 elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then install_cmd="sudo dnf install -y ffmpeg jq curl python3 python3-pip";
                 elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then install_cmd="sudo yum install -y ffmpeg jq curl python3 python3-pip"; fi

                 if [ -n "$install_cmd" ]; then
                     # <<< 移除提示中的 webvtt-py >>>
                     echo -e "${GREEN}WSL/Linux ($PACKAGE_MANAGER): $install_cmd ; $python_cmd -m pip install --upgrade --user yt-dlp${RESET}"
                 else
                     # <<< 從安裝命令建議中移除 mkvmerge, 移除 webvtt-py >>>
                     echo -e "${YELLOW}請參考你的 Linux 發行版文檔安裝 ffmpeg, jq, curl, python3, pip, 然後執行 pip install --upgrade yt-dlp${RESET}"
                 fi
             fi
             # <<< 移除單獨安裝 webvtt-py 的提示 >>>
        fi
        return 1 # 返回失敗狀態碼
    fi

    # 如果所有檢查都通過
    log_message "INFO" "環境檢查通過。"
    echo -e "${GREEN}環境檢查通過。${RESET}"
    sleep 1 # 短暫顯示成功信息
    return 0 # 返回成功狀態碼
}

############################################
# <<< 修改：新的主選單 (多層級，加入執行同步選項) >>>
############################################
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 整合式影音處理平台(IAVPP) ${SCRIPT_VERSION} ===${RESET}"
        display_countdown # 保留倒數計時顯示
        echo -e "${YELLOW}請選擇主要功能分類：${RESET}"
        echo -e " 1. ${BOLD}MP3 相關處理${RESET} (YouTube/本機)"
        echo -e " 2. ${BOLD}MP4 / MKV 相關處理${RESET} (YouTube/本機)"
        echo -e " 3. ${BOLD}通用媒體下載${RESET} (其他網站 / ${YELLOW}實驗性${RESET})"
        # <<< 新增的同步執行選項 >>>
        echo -e " 4. ${BOLD}執行同步 (新手機 -> 舊手機)${RESET}"
        echo -e "---------------------------------------------"
        # 後續選項編號順延
        echo -e " 5. ${BOLD}腳本設定與工具${RESET}"
        echo -e " 6. ${BOLD}關於此工具${RESET}"
        echo -e " 0. ${RED}退出腳本${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard # 清除可能的緩衝輸入

        local choice
        read -rp "輸入選項 (0-6): " choice # <<< 修改選項範圍提示

        case $choice in
            1) mp3_menu ;;
            2) mp4_mkv_menu ;;
            3) general_download_menu ;;
            4) # <<< 新增 Case，執行同步功能 >>>
                perform_sync_to_old_phone # 這個函數內部現在會調用 Python 輔助腳本
                # perform_sync_to_old_phone 內部應包含 "按 Enter 返回"
                ;;
            5) utilities_menu ;;       # 原來的選項 4
            6) show_about_enhanced ;; # 原來的選項 5
            0)
                echo -e "${GREEN}感謝使用，正在退出...${RESET}"
                log_message "INFO" "使用者選擇退出。"
                sleep 1
                exit 0
                ;;
            *)
                if [[ -z "$choice" ]]; then
                    continue
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

############################################
# <<< 修改：主程式 (環境檢查失敗時，延後 clear 以便查看錯誤訊息) >>>
############################################
main() {
    # --- 設定預設值 (假設這些已在腳本頂部完成) ---
    # DEFAULT_URL="..."; THREADS=4; MAX_THREADS=8; MIN_THREADS=1; COLOR_ENABLED=true; etc.
    # DOWNLOAD_PATH="$DOWNLOAD_PATH_DEFAULT"; TEMP_DIR="$TEMP_DIR_DEFAULT"; etc.

    # --- 載入使用者設定檔 ---
    load_config

    # --- 應用載入後的顏色設定 ---
    apply_color_settings

    # --- 在 load_config 之後記錄啟動訊息 ---
    log_message "INFO" "腳本啟動 (版本: $SCRIPT_VERSION, OS: $OS_TYPE, Config: $CONFIG_FILE)"

    # --- 環境檢查 ---
    # <<< 修改：調用 check_environment 並檢查返回值 >>>
    if ! check_environment; then # 第一次檢查，非靜默模式
        # <<< 修改：移除這裡的 clear，並在標題前加換行以便與 check_environment 的輸出分隔 >>>
        echo -e "\n${RED}##############################################${RESET}"
        echo -e "${RED}# ${BOLD}環境檢查發現問題！腳本可能無法正常運行。${RESET}${RED} #${RESET}"
        echo -e "${RED}##############################################${RESET}"
        echo -e "${YELLOW}檢測到缺少必要的工具、權限或設定。${RESET}"
        # <<< 修改：提示語更明確指向 "上方" 的訊息 >>>
        echo -e "${YELLOW}${BOLD}請查看檢查過程中（上方）列出的具體錯誤訊息。${RESET}"

        if [[ "$OS_TYPE" == "termux" ]]; then
            # 特別檢查並提示 Termux 儲存權限問題
            # 這裡的測試檔案使用不同的後綴以避免與 check_environment 中的衝突
            if [ ! -d "/sdcard" ] || ! touch "/sdcard/.termux-test-write-main-prompt" 2>/dev/null; then
                echo -e "\n${RED}${BOLD}*** Termux 儲存權限問題 ***${RESET}"
                echo -e "${YELLOW}腳本無法存取或寫入外部存儲 (/sdcard)。${RESET}"
                echo -e "${CYAN}請先在 Termux 中手動執行以下命令授予權限：${RESET}"
                echo -e "    ${GREEN}termux-setup-storage${RESET}"
                echo -e "${CYAN}然後完全關閉並重新啟動 Termux 和此腳本。${RESET}"
                echo -e "${YELLOW}依賴更新功能無法解決此權限問題。${RESET}"
            fi
            rm -f "/sdcard/.termux-test-write-main-prompt" # 清理測試檔案
        fi

        echo -e "\n${CYAN}您可以選擇讓腳本嘗試自動安裝/更新缺失的依賴套件。${RESET}"
        echo -e "${YELLOW}注意：此操作無法修復 Termux 儲存權限問題。${RESET}"
        echo ""
        # <<< 新增：讓使用者有時間查看由 check_environment 打印的錯誤訊息 >>>
        read -p "按 Enter 鍵以顯示後續選項..."
        # <<< 新增：在顯示後續選項前清屏，使界面整潔 >>>
        clear

        local run_dep_update=""
        read -rp "是否立即嘗試運行依賴更新？ (y/n): " run_dep_update

        if [[ "$run_dep_update" =~ ^[Yy]$ ]]; then
            log_message "INFO" "使用者選擇在環境檢查失敗後運行依賴更新。"
            # <<< 調用依賴更新函數 >>>
            update_dependencies # update_dependencies 內部有其自身的輸出和 "按 Enter 返回" 的提示

            # <<< 依賴更新後再次檢查環境 >>>
            # 這裡的 clear 是為了清掉 update_dependencies 的輸出，準備顯示重新檢查的提示
            clear
            echo -e "\n${CYAN}---------------------------------------------${RESET}"
            echo -e "${CYAN}依賴更新流程已執行完畢。${RESET}"
            echo -e "${CYAN}正在重新檢查環境以確認問題是否解決...${RESET}"
            echo -e "${CYAN}---------------------------------------------${RESET}"
            sleep 1 # 給使用者一點時間看提示

            if ! check_environment "--silent"; then # 第二次檢查，使用靜默模式
                # check_environment 在靜默模式失敗時，其自身會打印出仍然存在的問題
                log_message "ERROR" "依賴更新後環境再次檢查失敗，腳本退出。"
                echo -e "\n${RED}##############################################${RESET}"
                echo -e "${RED}# ${BOLD}環境重新檢查仍然失敗！${RESET}${RED}           #${RESET}"
                echo -e "${RED}# ${BOLD}腳本無法繼續執行。${RESET}${RED}                 #${RESET}"
                echo -e "${RED}# ${BOLD}請仔細檢查上面列出的問題，${RESET}${RED}         #${RESET}"
                echo -e "${RED}# ${BOLD}或嘗試手動解決。${RESET}${RED}                   #${RESET}"
                if [[ "$OS_TYPE" == "termux" ]]; then
                     echo -e "${RED}# ${BOLD}對於 Termux 儲存權限，請務必執行 ${GREEN}termux-setup-storage${RESET}${RED}。 #${RESET}"
                fi
                echo -e "${RED}##############################################${RESET}"
                exit 1 # 退出腳本
            else
                # <<< 如果再次檢查成功 >>>
                log_message "INFO" "依賴更新後環境重新檢查通過。"
                echo -e "\n${GREEN}##############################################${RESET}"
                echo -e "${GREEN}# ${BOLD}環境重新檢查通過！準備進入主選單...${RESET}${GREEN} #${RESET}"
                echo -e "${GREEN}##############################################${RESET}"
                sleep 2 # 顯示成功信息
            fi
        else
            # <<< 如果使用者選擇不運行依賴更新 >>>
            log_message "INFO" "使用者拒絕在環境檢查失敗後運行依賴更新，腳本退出。"
            echo -e "\n${YELLOW}##############################################${RESET}"
            echo -e "${YELLOW}# ${BOLD}已取消依賴更新。${RESET}${YELLOW}                 #${RESET}"
            echo -e "${YELLOW}# ${BOLD}腳本無法在當前環境下運行，正在退出。${RESET}${YELLOW} #${RESET}"
            echo -e "${YELLOW}##############################################${RESET}"
            exit 1 # 退出腳本
        fi
        # <<< 結束環境檢查失敗的處理 >>>
    fi # 結束 if ! check_environment

    # --- 環境檢查通過（或修復後通過）後的正常流程 ---
    log_message "INFO" "環境檢查通過，繼續執行腳本。"

    # --- 自動調整執行緒 ---
    adjust_threads
    # sleep 0 # 短暫暫停 (這一行在您的原始 main 函數中是存在的，我予以保留)

    # --- 進入主選單 ---
    main_menu
}

# --- 執行主函數 ---
main
