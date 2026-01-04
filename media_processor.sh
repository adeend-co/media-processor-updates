#!/bin/bash

################################################################################
#                                                                              #
#                      整合式進階多功能處理平台 (IAVPP)                             #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# ============================================================================ #
#                                                                              #
#   授權條款 (License Terms)                                                     #
#                                                                              #
# 本電腦程式著作（「整合式進階多功能處理平台」及其相關程式碼，以下簡稱「本著作」）依據            #
# 「創用 CC 姓名標示-非商業性-相同方式分享 4.0 國際授權條款 (CC BY-NC-SA 4.0)」          #
# 之規定提供授權。                                                                #
#                                                                              #
# 被授權人得為下列行為：                                                            #
# 一、重製：以任何方法及形式重製本著作。                                                #
# 二、散布：以任何方法及形式散布本著作之重製物。                                         #
# 三、改作：就本著作進行改作、重混或其他創作。                                           #
#                                                                              #
# 前項授權須遵守下列條件：                                                          #
# 一、姓名標示：被授權人應以合理之方式標示著作人（adeend-co）之姓名或名稱、                  #
#     提供授權條款之連結，並註明是否對原著作進行變更。惟不得以暗示著作人                     #
#     推薦被授權人或其利用行為之方式為之。                                            #
#                                                                             #
# 二、非商業性利用：被授權人不得為商業目的而利用本著作。所稱商業目的，                       #
#     係指主要目的為獲取商業利益或營利之行為。                                         #
#                                                                             #
# 三、相同方式分享：被授權人就本著作進行改作、重混或創作衍生著作時，                         #
#     應以與本授權條款相同或相容之授權條款提供授權。                                     #
#                                                                              #
# ============================================================================ #
#                                                                              #
#   免責條款 (Disclaimer of Warranties)                                          #
#                                                                              #
# 本著作係以「現狀」提供，著作權人不就本著作為任何明示或默示之保證，包括但                     #
# 不限於無瑕疵擔保、特定目的適用性及未侵害第三人權利之保證。                                #
#                                                                              #
# 著作權人對於因使用或無法使用本著作，或因本著作之瑕疵所生之任何直接、間接、                   #
# 附隨、衍生、懲罰性損害或其他損害，無論基於契約、侵權行為或其他法律理論，                     #
# 均不負損害賠償責任，縱使著作權人已被告知該等損害發生之可能性。                             #
#                                                                              #
# 使用者應自負使用本著作之風險，並應遵守中華民國法律及其使用地之相關法令，                     #
# 特別是著作權法及其他智慧財產權相關法規之規定。                                         #
#                                                                              #
################################################################################

############################################
# 腳本設定
############################################
SCRIPT_VERSION="v2.7.4" # <<< 版本號更新

############################################
# ★★★ 新增：使用者同意書版本號 ★★★
# 當您修改同意書內容時，請務必增加此版本號 (例如：1.0 -> 1.1)
############################################
AGREEMENT_VERSION="1.6" 

############################################
# <<< 新增：腳本更新日期 >>>
############################################
SCRIPT_UPDATE_DATE="2026-01-04" # 請根據實際情況修改此日期

# ... 其他設定 ...
TARGET_DATE="2026-01-11" # <<< 新增：設定您的目標日期
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

# --- 【重要】新增：智慧型元數據豐富化模組路徑 ---
# Python 元數據處理核心
PYTHON_METADATA_ENRICHER_SCRIPT_PATH="$HOME/media-processor-updates/enrich_metadata.py"
# Bash 音訊處理與流程控制器
BASH_AUDIO_ENRICHER_SCRIPT_PATH="$HOME/media-processor-updates/audio_enricher.sh"

# --- 【重要】新增：Invidious 後備下載模組路徑 ---
INVIDIOUS_DOWNLOADER_SCRIPT_PATH="$HOME/media-processor-updates/invidious_downloader.py"

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
# 儲存設定檔 (包含所有設定)
# 版本：V2.3 - 引入同意書版本號
############################################
save_config() {
    if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
        log_message "INFO" "準備儲存目前設定到 $CONFIG_FILE ..."
    else
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] (Pre-log) 準備儲存目前設定到 $CONFIG_FILE ..."
    fi

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
    echo "UPDATE_CHANNEL=\"${UPDATE_CHANNEL:-stable}\"" >> "$CONFIG_FILE" && \
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
    echo "SYNC_PHOTO_EXTENSIONS=\"${SYNC_PHOTO_EXTENSIONS:-}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_PROGRESS_STYLE=\"${SYNC_PROGRESS_STYLE:-default}\"" >> "$CONFIG_FILE" && \
    echo "SYNC_BWLIMIT=\"${SYNC_BWLIMIT:-0}\"" >> "$CONFIG_FILE" && \
    echo "" >> "$CONFIG_FILE" && \
    
    # --- 使用者同意狀態 ---
    echo "# --- User Agreement Status ---" >> "$CONFIG_FILE" && \
    echo "# Records the version of the terms the user has agreed to." >> "$CONFIG_FILE" && \
    echo "AGREED_TERMS_VERSION=\"${AGREED_TERMS_VERSION:-}\"" >> "$CONFIG_FILE"

    if [ $? -eq 0 ]; then
        if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
            log_message "INFO" "設定已成功儲存到 $CONFIG_FILE"
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] (Pre-log) 設定已成功儲存到 $CONFIG_FILE"
        fi
    else
        if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
            log_message "ERROR" "無法寫入設定檔 $CONFIG_FILE！最後一個 echo 失敗。"
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [ERROR] (Pre-log) 無法寫入設定檔 $CONFIG_FILE！最後一個 echo 失敗。" >&2
        fi
        echo -e "${RED}錯誤：無法儲存完整設定到 $CONFIG_FILE！請檢查權限和磁碟空間。${RESET}" >&2
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
# 版本：V3.5 - 引入同意書版本號
################################################################################
load_config() {
    # --- 為所有可配置變數設定初始預設值 ---
    # 這些值會在設定檔不存在、不可讀或設定檔中缺少對應條目時使用。

    # 常規設定預設值
    THREADS="${THREADS:-4}"
    local default_dl_path_platform_base="${DOWNLOAD_PATH_DEFAULT:-$HOME/media_processor_downloads_default}"
    DOWNLOAD_PATH="${DOWNLOAD_PATH:-${default_dl_path_platform_base}}"
    COLOR_ENABLED="${COLOR_ENABLED:-true}"
    PYTHON_CONVERTER_VERSION="${PYTHON_CONVERTER_VERSION:-1.0.0}"
    UPDATE_CHANNEL="${UPDATE_CHANNEL:-stable}" # 預設為穩定渠道

    # 終端日誌級別顯示預設值
    TERMINAL_LOG_SHOW_INFO="${TERMINAL_LOG_SHOW_INFO:-true}"
    TERMINAL_LOG_SHOW_WARNING="${TERMINAL_LOG_SHOW_WARNING:-true}"
    TERMINAL_LOG_SHOW_ERROR="${TERMINAL_LOG_SHOW_ERROR:-true}"
    TERMINAL_LOG_SHOW_SUCCESS="${TERMINAL_LOG_SHOW_SUCCESS:-true}"
    TERMINAL_LOG_SHOW_DEBUG="${TERMINAL_LOG_SHOW_DEBUG:-false}"
    TERMINAL_LOG_SHOW_SECURITY="${TERMINAL_LOG_SHOW_SECURITY:-true}"

    # 同步功能設定預設值
    SYNC_SOURCE_DIR_NEW_PHONE="${SYNC_SOURCE_DIR_NEW_PHONE:-}"
    SYNC_TARGET_SSH_HOST_OLD_PHONE="${SYNC_TARGET_SSH_HOST_OLD_PHONE:-}"
    SYNC_TARGET_SSH_USER_OLD_PHONE="${SYNC_TARGET_SSH_USER_OLD_PHONE:-}"
    SYNC_TARGET_SSH_PORT_OLD_PHONE="${SYNC_TARGET_SSH_PORT_OLD_PHONE:-}"
    SYNC_TARGET_DIR_OLD_PHONE="${SYNC_TARGET_DIR_OLD_PHONE:-}"
    SYNC_SSH_KEY_PATH_NEW_PHONE="${SYNC_SSH_KEY_PATH_NEW_PHONE:-}"
    SYNC_VIDEO_EXTENSIONS="${SYNC_VIDEO_EXTENSIONS:-mp4,mov,mkv,webm,avi,flv,wmv}"
    SYNC_PHOTO_EXTENSIONS="${SYNC_PHOTO_EXTENSIONS:-jpg,jpeg,png,heic,gif,webp,bmp,tif,tiff,raw,dng}"
    SYNC_PROGRESS_STYLE="${SYNC_PROGRESS_STYLE:-default}" # 'default' 或 'total'
    SYNC_BWLIMIT="${SYNC_BWLIMIT:-0}" # 0 為不限制

    # 使用者同意狀態預設值
    AGREED_TERMS_VERSION=""

    # --- 記錄用於比較的初始值 (僅在此函數內使用，用於設定檔值無效時的回退) ---
    local initial_threads="$THREADS"
    local initial_dl_path="$DOWNLOAD_PATH"
    local initial_color="$COLOR_ENABLED"
    local initial_py_ver="$PYTHON_CONVERTER_VERSION"
    local initial_update_channel="$UPDATE_CHANNEL"
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
    local initial_sync_progress_style="$SYNC_PROGRESS_STYLE"
    local initial_sync_bwlimit="$SYNC_BWLIMIT"
    local initial_agreed_terms_version="$AGREED_TERMS_VERSION"


    # --- 開始從設定檔讀取 ---
    if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ]; then
        echo -e "${BLUE:-}正在從設定檔 $CONFIG_FILE 載入設定...${RESET:-}"

        local line_num=0
        local line var_name var_value

        while IFS= read -r line || [ -n "$line" ]; do
            ((line_num++))
            line=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]]; then
                continue
            fi
            
            if [[ "$line" =~ ^[[:space:]]*([A-Za-z_][A-Za-z0-9_]+)[[:space:]]*=[[:space:]]*\"(([^\"\\]|\\.)*)\"[[:space:]]*$ ]]; then
                var_name="${BASH_REMATCH[1]}"
                var_value="${BASH_REMATCH[2]}"

                case "$var_name" in
                    "THREADS")
                        if [[ "$var_value" =~ ^[0-9]+$ ]]; then
                            if (( var_value >= ${MIN_THREADS:-1} && var_value <= ${MAX_THREADS:-8} )); then
                                THREADS="$var_value"
                            else
                                echo "載入設定警告: THREADS ('$var_value') 無效或超出範圍，使用預設 '$initial_threads'。" >&2
                                THREADS="$initial_threads"
                            fi
                        else
                            echo "載入設定警告: THREADS ('$var_value') 非有效數字，使用預設 '$initial_threads'。" >&2
                            THREADS="$initial_threads"
                        fi
                        ;;
                    "DOWNLOAD_PATH") DOWNLOAD_PATH="$var_value" ;;
                    "COLOR_ENABLED")
                        if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then COLOR_ENABLED="$var_value"; else COLOR_ENABLED="$initial_color"; echo "載入設定警告: COLOR_ENABLED ('$var_value') 無效，使用預設 '$initial_color'。" >&2; fi ;;
                    "PYTHON_CONVERTER_VERSION")
                        if [ -n "$var_value" ]; then PYTHON_CONVERTER_VERSION="$var_value"; else PYTHON_CONVERTER_VERSION="$initial_py_ver"; echo "載入設定提示: PYTHON_CONVERTER_VERSION 為空，使用預設 '$initial_py_ver'。" >&2; fi ;;
                    "UPDATE_CHANNEL")
                        if [[ "$var_value" == "stable" || "$var_value" == "beta" ]]; then UPDATE_CHANNEL="$var_value"; else UPDATE_CHANNEL="$initial_update_channel"; echo "載入設定警告: UPDATE_CHANNEL ('$var_value') 無效，使用預設 '$initial_update_channel'。" >&2; fi ;;
                        
                    "TERMINAL_LOG_SHOW_INFO") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_INFO="$var_value"; else TERMINAL_LOG_SHOW_INFO="$initial_show_info"; fi ;;
                    "TERMINAL_LOG_SHOW_WARNING") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_WARNING="$var_value"; else TERMINAL_LOG_SHOW_WARNING="$initial_show_warning"; fi ;;
                    "TERMINAL_LOG_SHOW_ERROR") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_ERROR="$var_value"; else TERMINAL_LOG_SHOW_ERROR="$initial_show_error"; fi ;;
                    "TERMINAL_LOG_SHOW_SUCCESS") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_SUCCESS="$var_value"; else TERMINAL_LOG_SHOW_SUCCESS="$initial_show_success"; fi ;;
                    "TERMINAL_LOG_SHOW_DEBUG") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_DEBUG="$var_value"; else TERMINAL_LOG_SHOW_DEBUG="$initial_show_debug"; fi ;;
                    "TERMINAL_LOG_SHOW_SECURITY") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_SECURITY="$var_value"; else TERMINAL_LOG_SHOW_SECURITY="$initial_show_security"; fi ;;

                    "SYNC_SOURCE_DIR_NEW_PHONE") SYNC_SOURCE_DIR_NEW_PHONE="$var_value" ;;
                    "SYNC_TARGET_SSH_HOST_OLD_PHONE") SYNC_TARGET_SSH_HOST_OLD_PHONE="$var_value" ;;
                    "SYNC_TARGET_SSH_USER_OLD_PHONE") SYNC_TARGET_SSH_USER_OLD_PHONE="$var_value" ;;
                    "SYNC_TARGET_SSH_PORT_OLD_PHONE") SYNC_TARGET_SSH_PORT_OLD_PHONE="$var_value" ;;
                    "SYNC_TARGET_DIR_OLD_PHONE") SYNC_TARGET_DIR_OLD_PHONE="$var_value" ;;
                    "SYNC_SSH_KEY_PATH_NEW_PHONE") SYNC_SSH_KEY_PATH_NEW_PHONE="$var_value" ;;
                    "SYNC_VIDEO_EXTENSIONS") SYNC_VIDEO_EXTENSIONS="$var_value" ;;
                    "SYNC_PHOTO_EXTENSIONS") SYNC_PHOTO_EXTENSIONS="$var_value" ;;
                    
                    "SYNC_PROGRESS_STYLE")
                        if [[ "$var_value" == "default" || "$var_value" == "total" ]]; then SYNC_PROGRESS_STYLE="$var_value"; else SYNC_PROGRESS_STYLE="$initial_sync_progress_style"; echo "載入設定警告: SYNC_PROGRESS_STYLE ('$var_value') 無效，使用預設 '$initial_sync_progress_style'。" >&2; fi ;;
                    "SYNC_BWLIMIT")
                        if [[ "$var_value" =~ ^[0-9]+$ ]]; then SYNC_BWLIMIT="$var_value"; else SYNC_BWLIMIT="$initial_sync_bwlimit"; echo "載入設定警告: SYNC_BWLIMIT ('$var_value') 非有效數字，使用預設 '$initial_sync_bwlimit'。" >&2; fi ;;
                        
                    "AGREED_TERMS_VERSION")
                        AGREED_TERMS_VERSION="$var_value"
                        ;;

                    *)
                        # 忽略未知變數
                        ;;
                esac
            else
                if [ -n "$line" ]; then
                    echo "載入設定警告: 第 $line_num 行格式不符: '$line'，已忽略。" >&2
                fi
            fi
        done < "$CONFIG_FILE"

        echo -e "${GREEN:-}已成功從 $CONFIG_FILE 載入使用者設定。${RESET:-}"
        sleep 0.5
    else
        echo -e "${YELLOW:-}設定檔 $CONFIG_FILE 未找到或不可讀，將使用預設設定。${RESET:-}"
        echo -e "${CYAN:-}提示：您可以通過腳本的設定選單來更改設定，更改後將自動創建設定檔。${RESET:-}"
        sleep 1
    fi

    # --- 完成 DOWNLOAD_PATH 的處理與驗證 (此段邏輯不變) ---
    local sanitized_dl_path_final=""
    if [ -n "$DOWNLOAD_PATH" ]; then
        sanitized_dl_path_final=$(realpath -m "$DOWNLOAD_PATH" 2>/dev/null | sed 's/[;|&<>()$`{}]//g')
    fi
    if [ -z "$sanitized_dl_path_final" ]; then
        echo -e "${RED:-}警告：設定的下載路徑 '$DOWNLOAD_PATH' 解析失敗或無效！${RESET:-}" >&2
        DOWNLOAD_PATH="$HOME/media_processor_safe_downloads"
        echo -e "${YELLOW:-}已將下載路徑重設為安全備用路徑: $DOWNLOAD_PATH ${RESET:-}" >&2
        if ! mkdir -p "$DOWNLOAD_PATH"; then
            echo -e "${RED:-}嚴重錯誤：無法創建備用下載目錄 '$DOWNLOAD_PATH'！腳本無法繼續。${RESET:-}" >&2
            exit 1
        fi
    else
        DOWNLOAD_PATH="$sanitized_dl_path_final"
    fi
    if ! [[ "$DOWNLOAD_PATH" =~ ^(/storage/emulated/0|/sdcard|$HOME|/data/data/com.termux/files/home) ]]; then
        echo -e "${RED:-}安全性錯誤：最終下載路徑 '$DOWNLOAD_PATH' 不在允許的安全操作範圍內！腳本無法啟動。${RESET:-}" >&2
        exit 1
    fi
    if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
        echo -e "${RED:-}錯誤：無法創建最終下載目錄 '$DOWNLOAD_PATH'！請檢查權限。腳本無法啟動。${RESET:-}" >&2
        exit 1
    elif [ ! -w "$DOWNLOAD_PATH" ]; then
        echo -e "${RED:-}錯誤：最終下載目錄 '$DOWNLOAD_PATH' 不可寫！請檢查權限。腳本無法啟動。${RESET:-}" >&2
        exit 1
    fi

    # --- 日誌記錄已載入的設定 ---
    if command -v log_message >/dev/null 2>&1; then
        log_message "INFO" "load_config: 函數執行完畢。"
        log_message "INFO" "load_config: 最終下載路徑已確認為: '$DOWNLOAD_PATH'"
        log_message "INFO" "load_config: 日誌檔案將寫入: '$LOG_FILE'"
        log_message "DEBUG" "load_config: THREADS='$THREADS'"
        log_message "DEBUG" "load_config: COLOR_ENABLED='$COLOR_ENABLED'"
        log_message "DEBUG" "load_config: SYNC_PROGRESS_STYLE='$SYNC_PROGRESS_STYLE'"
        log_message "DEBUG" "load_config: SYNC_BWLIMIT='$SYNC_BWLIMIT' KB/s"
        log_message "DEBUG" "load_config: UPDATE_CHANNEL='$UPDATE_CHANNEL'"
        log_message "DEBUG" "load_config: AGREED_TERMS_VERSION='${AGREED_TERMS_VERSION}'"
    else
        echo "提示: log_message 函數未定義，部分設定載入訊息將不會寫入日誌。" >&2
    fi
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
        countdown_message="${CYAN}距離「寒假」（ ${TARGET_DATE} ）尚餘： ${GREEN}${days} ${WHITE}天 ${GREEN}${hours} ${WHITE}時 ${GREEN}${minutes} ${WHITE}分 ${GREEN}${seconds} ${WHITE}秒${RESET}"
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

###########################################################
# 輔助函數：顯示旋轉等待游標
# $1: 要監控的背景工作的 PID
###########################################################
spinner() {
    local pid=$1
    local delay=0.1
    local spin_chars="⠏⠋⠙⠹⠸⠼⠴⠦⠧⠇" # 使用更美觀的 Braille spinner
    
    # 只要指定的 PID 還在運行
    while ps -p $pid > /dev/null; do
        for (( i=0; i<${#spin_chars}; i++ )); do
            # -ne: 不換行, \r: 回到行首
            echo -ne "${CYAN}${spin_chars:$i:1}${RESET} "
            sleep $delay
            echo -ne "\r"
        done
    done
    # 清理最後的 spinner 字元
    echo -ne " \r"
}

###########################################################
# 全新輔助函數：解析錯誤碼並提供詳細資訊 (v1.4 - 強化錯誤指引)
###########################################################
_get_error_details() {
    local error_code="$1"
    local error_message=""
    case "$error_code" in
        "E_YTDLP_JSON")
            error_message="${RED}原因: yt-dlp 無法獲取影片的元數據 (JSON)。\n      ${YELLOW}建議: 請檢查 URL 是否正確、影片是否為私有或已被刪除。${RESET}"
            ;;
        "E_YTDLP_FORMAT")
            error_message="${RED}原因: yt-dlp 報告 YouTube 未提供腳本請求的特定影片格式。\n      ${YELLOW}建議: 這是 YouTube 伺服器的動態行為，通常是暫時的。請直接重試。${RESET}"
            ;;
        "E_YTDLP_DL_403")
            error_message="${RED}原因: YouTube 伺服器拒絕存取 (HTTP 403 Forbidden)。\n      ${YELLOW}建議: 這是 YouTube 的臨時性阻擋，請稍後重試或更換網路環境 (例如切換 Wi-Fi/行動數據)。${RESET}"
            ;;
        "E_YTDLP_DL_GENERIC")
            error_message="${RED}原因: yt-dlp 下載時發生通用錯誤。\n      ${YELLOW}建議: 請查看上方顯示的詳細錯誤日誌。${RESET}"
            ;;
        "E_FS_PERM")
            error_message="${RED}原因: 檔案系統權限錯誤 (Operation not permitted)。\n      ${YELLOW}建議: 1. 檢查 Termux 儲存權限。 2. 可能是影片標題含有非法字元導致檔名無效。${RESET}"
            ;;
        "E_FFPROBE_RES")
            error_message="${RED}原因: 下載後，ffprobe 無法讀取影片的解析度。\n      ${YELLOW}建議: 下載的檔案可能已損壞或格式異常。${RESET}"
            ;;
        "E_NORMALIZE_FAIL")
            error_message="${RED}原因: FFmpeg 音量標準化過程失敗。\n      ${YELLOW}建議: 影片的音訊編碼可能不受支援，或原始音訊已損壞。${RESET}"
            ;;
        "E_FFMPEG_MUX")
            error_message="${RED}原因: FFmpeg 最終封裝失敗 (合併影像/音訊/字幕/封面時出錯)。\n      ${YELLOW}建議: \n      1. 請查看上方紅色的 FFmpeg 錯誤輸出。\n      2. 常見原因包含：封面圖片格式不支援、標題含有特殊符號導致元數據寫入失敗。\n      3. 您可以嘗試「選項 2 (無標準化)」下載看是否成功。${RESET}"
            ;;
        "E_FILE_NOT_FOUND")
            error_message="${RED}原因: 流程顯示成功，但找不到最終產出的檔案。\n      ${YELLOW}建議: 可能是因為下載被意外中斷或被防毒軟體/系統清理機制刪除。${RESET}"
            ;;
        *)
            error_message="${RED}原因: 未知的錯誤碼 ($error_code)。${RESET}"
            ;;
    esac
    echo -e "$error_message"
}

###########################################################
# 全新輔助函數：顯示播放清單處理的最終摘要 (v1.2 - 顯示原始錯誤)
###########################################################
_display_playlist_summary() {
    local results_array=("$@")
    local total_items=${#results_array[@]}
    local success_items=()
    local failed_items=()
    local i=1

    for result_line in "${results_array[@]}"; do
        if [ -n "$result_line" ]; then
            IFS='|' read -r status _ <<< "$result_line"
            if [[ "$status" == "SUCCESS" ]]; then
                success_items+=("$result_line")
            else
                failed_items+=("$result_line")
            fi
        else
            failed_items+=("FAIL|未知影片 (捕獲到空結果)|E_UNKNOWN|$(echo "腳本未能捕獲有效的處理結果字串" | base64 -w 0)")
        fi
    done

    clear
    echo -e "${CYAN}=====================================================${RESET}"
    echo -e "              ${BOLD}播 放 清 單 處 理 完 成 摘 要${RESET}"
    echo -e "${CYAN}=====================================================${RESET}"
    echo -e "總項目數: ${total_items}, 成功: ${#success_items[@]}, 失敗: ${#failed_items[@]}\n"

    if [ ${#success_items[@]} -gt 0 ]; then
        echo -e "${GREEN}--- ✔ 成功項目 (${#success_items[@]}) ---${RESET}"
        for item in "${success_items[@]}"; do
            local title resolution
            IFS='|' read -r _ title resolution <<< "$item"
            local truncated_title
            if [ ${#title} -gt 50 ]; then
                truncated_title="$(echo "$title" | cut -c 1-47)..."
            else
                truncated_title="$title"
            fi
            printf "%2d. %-50s ${GREEN}[%s]${RESET}\n" "$i" "$truncated_title" "$resolution"
            i=$((i + 1))
        done
        echo ""
    fi

    if [ ${#failed_items[@]} -gt 0 ]; then
        echo -e "${RED}--- ✗ 失敗項目 (${#failed_items[@]}) ---${RESET}"
        for item in "${failed_items[@]}"; do
            # ★★★ 核心修正：讀取第四個 Base64 欄位 ★★★
            local title error_code raw_error_b64
            IFS='|' read -r _ title error_code raw_error_b64 <<< "$item"
            
            local truncated_title
            if [ ${#title} -gt 60 ]; then
                truncated_title="$(echo "$title" | cut -c 1-57)..."
            else
                truncated_title="$title"
            fi
            printf "%2d. %s\n" "$i" "$truncated_title"
            _get_error_details "$error_code"
            
            # ★★★ 核心修正：解碼並顯示原始錯誤日誌 ★★★
            if [ -n "$raw_error_b64" ]; then
                local raw_error
                raw_error=$(echo "$raw_error_b64" | base64 -d 2>/dev/null)
                if [ -n "$raw_error" ]; then
                    echo -e "${PURPLE}┌─ 原始錯誤日誌 ───────────────────────────────┐${RESET}"
                    # 使用 sed 為每一行加上縮排，使其更易讀
                    echo "$raw_error" | sed 's/^/  │ /'
                    echo -e "${PURPLE}└──────────────────────────────────────────────┘${RESET}"
                fi
            fi
            
            echo "" # 在每個失敗項目後加一個空行，而不是分隔線
            i=$((i + 1))
        done
        echo ""
    fi

    log_message "SUCCESS" "播放清單摘要顯示完畢。總共: $total_items, 成功: ${#success_items[@]}, 失敗: ${#failed_items[@]}"
}

###########################################################
# UI 輔助函數：繪製自適應寬度的分隔線
###########################################################
draw_line() {
    local char="${1:--}" # 預設字元為 -
    local color="${2:-$CYAN}" # 預設顏色
    local width
    
    # 嘗試獲取終端機寬度，如果失敗則預設 50
    if command -v tput &> /dev/null; then
        width=$(tput cols)
    else
        width=50
    fi
    
    # 確保寬度合理
    [[ "$width" -lt 10 ]] && width=50
    
    # 繪製線條
    local line=""
    for ((i=0; i<width; i++)); do line+="$char"; done
    echo -e "${color}${line}${RESET}"
}

######################################################################
# 腳本自我更新函數 (v4.5 - 重構權限校驗，支援多個輔助腳本)
######################################################################
auto_update_script() {
    clear
    echo -e "${CYAN}--- 使用 Git 檢查腳本更新 ---${RESET}"
    log_message "INFO" "使用者觸發 Git 腳本更新檢查 (當前渠道: ${UPDATE_CHANNEL:-stable})。"

    if ! command -v git &> /dev/null; then log_message "ERROR" "未找到 'git' 命令。"; echo -e "${RED}錯誤：找不到 'git' 命令！${RESET}"; return 1; fi

    local repo_dir="$SCRIPT_DIR"; local original_dir=$(pwd)
    if [ ! -d "$repo_dir/.git" ]; then log_message "ERROR" "目錄 '$repo_dir' 非 Git 倉庫。"; echo -e "${RED}錯誤：目錄 '$repo_dir' 非 Git 倉庫。${RESET}"; return 1; fi
    if ! cd "$repo_dir"; then log_message "ERROR" "無法進入倉庫目錄 '$repo_dir'"; echo -e "${RED}錯誤：無法進入倉庫目錄！${RESET}"; return 1; fi

    local core_filemode_setting; core_filemode_setting=$(git config --local --get core.filemode)
    if [[ "$core_filemode_setting" != "false" ]]; then
        echo -e "${YELLOW}偵測到 Git 可能在追蹤檔案權限變化，正在自動修正...${RESET}"
        if git config --local core.filemode false; then echo -e "${GREEN}  > 設定成功！${RESET}"; else echo -e "${RED}  > 警告：自動設定失敗！${RESET}"; fi
        sleep 1
    fi

    echo -e "${YELLOW}檢查本地是否有未提交的更改...${RESET}"
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}警告：檢測到本地有更改！${RESET}"; read -r -p "是否放棄本地修改並繼續？(輸入 'yes'): " confirm_force
        if [[ "$confirm_force" != "yes" ]]; then echo -e "${YELLOW}已取消。${RESET}"; cd "$original_dir"; return 1; fi
        if ! git reset --hard HEAD --quiet || ! git clean -fd --quiet; then echo -e "${RED}錯誤：放棄本地更改失敗！${RESET}"; cd "$original_dir"; return 1; fi
    else
         echo -e "${GREEN}本地無未提交更改。${RESET}"
    fi

    echo -e "${YELLOW}正在從遠端倉庫獲取最新資訊...${RESET}"
    if ! git fetch --all --tags --quiet; then log_message "ERROR" "'git fetch' 失敗。"; echo -e "${RED}錯誤：無法獲取遠端更新！${RESET}"; cd "$original_dir"; return 1; fi
    
    local current_commit_hash=$(git rev-parse @); local restore_point_hash="$current_commit_hash"
    local current_version_display=$(git describe --tags --exact-match "$current_commit_hash" 2>/dev/null || git describe --tags --always "$current_commit_hash" 2>/dev/null || echo "${current_commit_hash:0:7}")
    local target_commit_hash=""; local target_version_display=""; local channel_display="${UPDATE_CHANNEL:-stable}"

    if [[ "$channel_display" == "beta" ]]; then
        echo -e "${YELLOW}當前為 [預覽版 Beta] 渠道，目標為 main 分支最新提交...${RESET}"
        target_commit_hash=$(git rev-parse @{u})
        target_version_display=$(git describe --tags --exact-match "$target_commit_hash" 2>/dev/null || git describe --tags --always "$target_commit_hash" 2>/dev/null || echo "預覽版 (${target_commit_hash:0:7})")
    else
        echo -e "${YELLOW}當前為 [穩定版 Stable] 渠道，目標為最新正式發布...${RESET}"
        if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then echo -e "${RED}錯誤：檢查穩定版更新需要 'curl' 和 'jq'！${RESET}"; cd "$original_dir"; return 1; fi
        local api_url="https://api.github.com/repos/adeend-co/media-processor-updates/releases/latest"
        local latest_release_json; latest_release_json=$(curl -sL "$api_url")
        if [[ "$(echo "$latest_release_json" | jq -r '.message // ""')" == "Not Found" ]]; then echo -e "${RED}錯誤：無法從 GitHub API 獲取發布資訊！${RESET}"; cd "$original_dir"; return 1; fi
        target_version_display=$(echo "$latest_release_json" | jq -r '.tag_name // empty')
        if [ -z "$target_version_display" ]; then echo -e "${RED}錯誤：無法解析最新穩定版的標籤名稱！${RESET}"; cd "$original_dir"; return 1; fi
        target_commit_hash=$(git rev-parse "$target_version_display^{commit}" 2>/dev/null)
        if [ -z "$target_commit_hash" ]; then echo -e "${RED}錯誤：無法將標籤 '$target_version_display' 解析為一個有效的提交！${RESET}"; cd "$original_dir"; return 1; fi
    fi
    
    echo -e "\n${CYAN}------------------- 版本狀態 -------------------${RESET}"
    echo -e "${CYAN}  - 當前渠道: ${GREEN}${channel_display}${RESET}"
    echo -e "${CYAN}  - 當前版本: ${WHITE}${current_version_display} (${current_commit_hash:0:7})${RESET}"
    echo -e "${CYAN}  - 目標版本: ${WHITE}${target_version_display} (${target_commit_hash:0:7})${RESET}"
    echo -e "${CYAN}--------------------------------------------${RESET}\n"
    
    if [ "$current_commit_hash" == "$target_commit_hash" ]; then
        echo -e "${GREEN}您的腳本已是 '${channel_display}' 渠道的最新版本。無需任何操作。${RESET}"
        cd "$original_dir"; read -p "按 Enter 返回..."
        return 0
    fi

    local base_commit=$(git merge-base "$current_commit_hash" "$target_commit_hash" 2>/dev/null)
    local action_description=""; local confirm_prompt=""
    if [ "$base_commit" == "$current_commit_hash" ]; then
        action_description="${GREEN}檢測到新版本！這是一個標準的向前更新。${RESET}"
        confirm_prompt="是否立即【更新】到版本 '${target_version_display}'？ (y/n): "
    elif [ "$base_commit" == "$target_commit_hash" ]; then
        action_description="${YELLOW}檢測到版本變化！您當前的預覽版比目標穩定版要新。${RESET}"
        confirm_prompt="是否要從當前版本【降級/切換】到穩定的 '${target_version_display}' 版本？ (y/n): "
    else
        action_description="${CYAN}檢測到版本變化！您當前的版本與目標版本處於不同開發分支。${RESET}"
        confirm_prompt="是否要【切換】到 '${target_version_display}' 版本？ (y/n): "
    fi

    echo -e "$action_description"; read -r -p "$confirm_prompt" confirm_action
    if [[ ! "$confirm_action" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了版本變更操作。"; echo -e "${YELLOW}操作已取消。${RESET}"; cd "$original_dir"; read -p "按 Enter 返回..."; return 0
    fi

    echo -e "${YELLOW}正在將腳本重設到目標版本 (${target_commit_hash:0:7})...${RESET}"
    if ! git reset --hard "$target_commit_hash" --quiet; then log_message "ERROR" "'git reset --hard' 失敗。"; echo -e "${RED}錯誤：操作失敗！${RESET}"; cd "$original_dir"; return 1; fi
    log_message "SUCCESS" "成功重設到目標版本 $target_version_display ($target_commit_hash)"; echo -e "${GREEN}版本變更完成。${RESET}"

    # --- ▼▼▼ 核心修改區塊：使用陣列來管理所有需要執行權限的腳本 ▼▼▼ ---
    echo -e "${CYAN}正在校驗所有核心腳本權限...${RESET}";
    local all_executable_scripts=(
        "$SCRIPT_INSTALL_PATH"                     # 主腳本
        "$PYTHON_ESTIMATOR_SCRIPT_PATH"            # Python 大小預估
        "$PYTHON_SYNC_HELPER_SCRIPT_PATH"          # Python 同步助手
        "$SCRIPT_DIR/finance_calculator.py"        # 進階財務分析與預測器（獨立）
        "$SCRIPT_DIR/monthly_expense_tracker.py"   # 月份支出追蹤器（獨立）
        "$BASH_AUDIO_ENRICHER_SCRIPT_PATH"         # 音訊豐富化 Bash 控制器
        "$PYTHON_METADATA_ENRICHER_SCRIPT_PATH"    # 音訊豐富化 Python 核心
        "$INVIDIOUS_DOWNLOADER_SCRIPT_PATH"        # Invidious（下載備用方案）
        # 未來若有新腳本，直接在此處增加一行即可
    )
    
    for script_path in "${all_executable_scripts[@]}"; do
        if [ -f "$script_path" ]; then
            if chmod +x "$script_path" 2>/dev/null; then
                echo -e "${GREEN}  > 已確保 '$(basename "$script_path")' 可執行。${RESET}"
            else
                echo -e "${RED}  > 警告：無法設定 '$(basename "$script_path")' 的執行權限！${RESET}"
            fi
        fi
    done
    # --- ▲▲▲ 修改結束 ▲▲▲ ---

    local goto_restore=false; local health_check_error_output=""
    echo -e "${CYAN}正在測試新版本腳本...${RESET}"
    echo -n "  - 測試1：語法檢查... "; local syntax_check_output; syntax_check_output=$(bash -n "$SCRIPT_INSTALL_PATH" 2>&1); if [ $? -ne 0 ]; then echo -e "${RED}失敗！${RESET}"; health_check_error_output="$syntax_check_output"; goto_restore=true; else echo -e "${GREEN}通過。${RESET}"; fi
    if ! $goto_restore; then echo -n "  - 測試2：健康檢查... "; local health_check_output; health_check_output=$(timeout 15s bash "$SCRIPT_INSTALL_PATH" --health-check < /dev/null 2>&1); local s=$?; if [ $s -eq 124 ]; then echo -e "${RED}失敗(超時)！${RESET}"; health_check_error_output="執行超時"; goto_restore=true; elif [ $s -ne 0 ]; then echo -e "${RED}失敗(錯誤碼:$s)！${RESET}"; health_check_error_output="$health_check_output"; goto_restore=true; else echo -e "${GREEN}通過。${RESET}"; fi; fi

    if ! $goto_restore; then
        log_message "SUCCESS" "新版本測試通過，操作完成。"; echo -e "${GREEN}新版本測試通過！操作成功！${RESET}"
        echo -e "${CYAN}建議重新啟動腳本以應用所有更改。${RESET}"; cd "$original_dir"; read -p "按 Enter 返回..."; return 0
    fi

    echo -e "\n${RED}--- 操作失敗 ---${RESET}"; echo -e "${RED}新版本腳本未能通過自動化測試。正在自動還原...${RESET}"
    if [ -n "$health_check_error_output" ]; then echo -e "${YELLOW}偵測到的錯誤：\n${PURPLE}$health_check_error_output${RESET}"; fi
    if git reset --hard "$restore_point_hash" --quiet; then
        # --- ▼▼▼ 還原後也需要重新校驗權限 ▼▼▼ ---
        echo -e "${CYAN}正在還原腳本權限...${RESET}";
        for script_path in "${all_executable_scripts[@]}"; do
            if [ -f "$script_path" ]; then chmod +x "$script_path" 2>/dev/null; fi
        done
        echo -e "${GREEN}還原成功！${RESET}"
        # --- ▲▲▲ 修改結束 ▲▲▲ ---
        log_message "SUCCESS" "成功還原到舊版本 (commit: ${restore_point_hash:0:7})"
    else
        log_message "CRITICAL" "自動還原失敗！"; echo -e "${RED}${BOLD}致命錯誤：自動還原失敗！請手動檢查 Git 倉庫！${RESET}"
    fi

    cd "$original_dir"; read -p "按 Enter 返回..."; return 1
}

############################################
# 高解析度封面圖片下載函數 (優化版 - 接收 video_id)
############################################
download_high_res_thumbnail() {
    local video_id="$1"
    local output_image="$2"

    if [ -z "$video_id" ]; then
        log_message "WARNING" "未提供影片 ID，跳過封面圖片下載。"
        return 1
    fi
    
    echo -e "${YELLOW}搜尋最佳解析度縮略圖...${RESET}"
    local thumbnail_sizes=("maxresdefault" "sddefault" "hqdefault" "mqdefault" "default")
    for size in "${thumbnail_sizes[@]}"; do
        log_message "DEBUG" "嘗試下載 $size 解析度縮略圖 for ID: $video_id"
        local thumbnail_url="https://i.ytimg.com/vi/${video_id}/${size}.jpg"
        local http_status
        http_status=$(curl -s -o /dev/null -w "%{http_code}" "$thumbnail_url")
        if [ "$http_status" -eq 200 ]; then
            echo -e "${YELLOW}正在下載縮略圖 ($size)...${RESET}"
            if curl -sL "$thumbnail_url" -o "$output_image"; then
                log_message "INFO" "下載封面圖片成功：$thumbnail_url"
                echo -e "${GREEN}封面圖片下載完成！${RESET}"
                return 0
            else
                log_message "WARNING" "下載圖片失敗：$thumbnail_url"
            fi
        fi
    done
    
    log_message "WARNING" "所有尺寸的封面圖片均下載失敗。"
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
    local pkg_tools=("ffmpeg" "jq" "curl" "python" "bc")
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
# 傳輸同步功能 (v2 - 調用優化後的 Python 腳本)
############################################
perform_sync_to_old_phone() {
    clear
    echo -e "${CYAN}--- 開始同步檔案到舊手機 (使用 Python 輔助腳本) ---${RESET}"
    log_message "INFO" "使用者觸發同步到舊手機功能。"

    # --- 檢查必要設定 ---
    local missing_configs_bash=false
    # --- 【優化】現在檢查 SYNC_SOURCE_DIR_NEW_PHONE 是否為空 ---
    if [ -z "$SYNC_SOURCE_DIR_NEW_PHONE" ]; then echo -e "${RED}錯誤：未設定來源目錄！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_TARGET_SSH_HOST_OLD_PHONE" ]; then echo -e "${RED}錯誤：未設定目標 SSH 主機！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_TARGET_SSH_USER_OLD_PHONE" ]; then echo -e "${RED}錯誤：未設定目標目錄！${RESET}"; missing_configs_bash=true; fi
    if [ -z "$SYNC_VIDEO_EXTENSIONS" ] && [ -z "$SYNC_PHOTO_EXTENSIONS" ]; then
        echo -e "${RED}錯誤：未設定任何影片或照片擴展名！${RESET}"; missing_configs_bash=true;
    fi

    if $missing_configs_bash; then
        log_message "ERROR" "同步功能缺少必要的 Bash 設定。"
        echo -e "${YELLOW}請先在「腳本設定與工具」->「同步功能設定」中完成設定。${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    # --- 檢查 Python 和輔助腳本 (邏輯不變) ---
    local python_executable=""
    if command -v python3 &> /dev/null; then python_executable="python3";
    elif command -v python &> /dev/null; then python_executable="python";
    else
        log_message "ERROR" "同步失敗：找不到 python 或 python3 命令。"; echo -e "${RED}錯誤：找不到 Python！${RESET}"; read -p "按 Enter 返回..."; return 1
    fi
    if [ ! -f "$PYTHON_SYNC_HELPER_SCRIPT_PATH" ]; then
        log_message "ERROR" "同步失敗：找不到 Python 同步輔助腳本 '$PYTHON_SYNC_HELPER_SCRIPT_PATH'。"; echo -e "${RED}錯誤：找不到同步輔助腳本！${RESET}"; read -p "按 Enter 返回..."; return 1
    fi
    if [ ! -x "$PYTHON_SYNC_HELPER_SCRIPT_PATH" ]; then chmod +x "$PYTHON_SYNC_HELPER_SCRIPT_PATH"; fi

    # --- 構建 Python 腳本調用命令 ---
    # 【優化】第一個參數現在是包含所有來源目錄的字串
    local python_sync_cmd_array=(
        "$python_executable"
        "$PYTHON_SYNC_HELPER_SCRIPT_PATH"
        "$SYNC_SOURCE_DIR_NEW_PHONE"
        "${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}"
        "$SYNC_TARGET_DIR_OLD_PHONE"
    )

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
    # --- 【優化】加入新參數 ---
    if [ -n "${SYNC_PROGRESS_STYLE}" ]; then
        python_sync_cmd_array+=("--progress-style" "${SYNC_PROGRESS_STYLE}")
    fi
    if [ -n "${SYNC_BWLIMIT}" ] && [[ "${SYNC_BWLIMIT}" -gt 0 ]]; then
        python_sync_cmd_array+=("--bwlimit" "${SYNC_BWLIMIT}")
    fi
    
    # --- 【優化】顯示多個來源目錄 ---
    echo -e "\n${YELLOW}將調用 Python 輔助腳本執行同步...${RESET}"
    echo -e "  來源目錄 (將逐一處理):"
    # 使用 IFS 分割字串並逐行打印
    IFS=';' read -ra source_dirs_array <<< "$SYNC_SOURCE_DIR_NEW_PHONE"
    for dir in "${source_dirs_array[@]}"; do
        echo -e "    - ${GREEN}${dir}${RESET}"
    done
    unset IFS # 重設 IFS

    echo -e "  目標: ${GREEN}${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}:${SYNC_TARGET_DIR_OLD_PHONE}${RESET}"
    echo -e "---------------------------------------------"

    local confirm_py_sync
    read -p "確定開始同步嗎？ (y/n): " confirm_py_sync
    if [[ ! "$confirm_py_sync" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了同步操作。"; echo -e "${YELLOW}同步操作已取消。${RESET}"; read -p "按 Enter 返回..."; return 1
    fi

    # --- 執行 Python 腳本 ---
    echo -e "\n${CYAN}Python 輔助腳本執行中，請參考其輸出...${RESET}"
    log_message "INFO" "執行 Python 同步腳本: ${python_sync_cmd_array[*]}"

    if "${python_sync_cmd_array[@]}"; then
        log_message "SUCCESS" "Python 同步輔助腳本報告成功。"
        echo -e "\n${GREEN}同步過程已完成 (由 Python 腳本處理)。${RESET}"
        _send_termux_notification 0 "媒體同步" "檔案同步到舊手機成功。" ""
    else
        local py_exit_code=$?
        log_message "ERROR" "Python 同步輔助腳本報告失敗！退出碼: $py_exit_code"
        echo -e "\n${RED}同步過程失敗 (由 Python 腳本處理)！退出碼: $py_exit_code${RESET}"
        
        # --- 【優化】斷點續傳提示 ---
        # 根據 rsync 的常見可恢復錯誤碼來提示
        case $py_exit_code in
            11|12|13|14|22|30|35) # I/O 錯誤, 協定錯誤, 超時等
                echo -e "${YELLOW}提示：同步可能因網路不穩定或磁碟空間問題而中斷。${RESET}"
                echo -e "${YELLOW}您可以直接重新運行此同步功能，rsync 會嘗試從中斷處繼續。${RESET}"
                ;;
            *)
                echo -e "${YELLOW}請檢查 Python 腳本的輸出以了解錯誤原因。${RESET}"
                ;;
        esac

        _send_termux_notification 1 "媒體同步" "檔案同步到舊手機失敗 (代碼: $py_exit_code)。" ""
    fi

    read -p "按 Enter 返回..."
    return 0
}

############################################
# 音量標準化共用函數 (v1.2)
############################################
normalize_audio() {
    local input_file="$1"
    local output_file="$2"
    local is_video="$3" # true 或 false

    log_message "INFO" "開始音訊標準化處理: $input_file (影片模式: $is_video)"

    # 建立暫存目錄
    local tmp_dir
    tmp_dir=$(mktemp -d -t audio_norm_XXXXXX) || {
        log_message "ERROR" "無法建立暫存目錄"
        return 1
    }

    # 定義暫存檔路徑
    local audio_wav="$tmp_dir/audio.wav"
    local normalized_wav="$tmp_dir/normalized.wav"
    local loudnorm_log="$tmp_dir/loudnorm_log.txt"

    # 步驟 1: 將輸入音訊轉換為 PCM WAV (確保分析準確度)
    # -vn: 確保不處理影像
    # -ac 2: 強制雙聲道 (避免單聲道分析誤差)
    ffmpeg -y -i "$input_file" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$audio_wav" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "ERROR" "無法將音訊轉換為 WAV 格式: $input_file"
        rm -rf "$tmp_dir"
        return 1
    fi

    # 步驟 2: 第一遍 (Pass 1) - 分析音訊響度數據
    log_message "INFO" "執行響度分析 (Pass 1)..."
    # 將 stderr 導向日誌檔
    ffmpeg -y -i "$audio_wav" -af "loudnorm=I=-12:TP=-1.5:LRA=11:print_format=json" -f null - 2> "$loudnorm_log"

    # 提取與解析 JSON
    # 優化: 使用 awk 尋找包含 "input_i" 的 JSON 區塊，防止抓到 FFmpeg 的其他雜訊
    local stats_json
    stats_json=$(awk '
        BEGIN { capture=0 }
        /{/ { capture=1; buffer="" }
        capture { buffer=buffer $0 "\n" }
        /}/ { if(capture && buffer ~ /input_i/) { print buffer; capture=0 } }
    ' "$loudnorm_log")

    # 如果上述精確抓取失敗，嘗試備用方案 (抓取最後一組 JSON)
    if [ -z "$stats_json" ]; then
        stats_json=$(awk '/{/,/}/' "$loudnorm_log" | tail -n 12) 
    fi

    if [ -z "$stats_json" ]; then
        log_message "ERROR" "無法從分析日誌中提取 JSON 數據，可能檔案過短或格式錯誤"
        rm -rf "$tmp_dir"
        return 1
    fi

    # 使用 jq 解析數值
    local measured_I=$(echo "$stats_json" | jq -r '.input_i // empty')
    local measured_TP=$(echo "$stats_json" | jq -r '.input_tp // empty')
    local measured_LRA=$(echo "$stats_json" | jq -r '.input_lra // empty')
    local measured_thresh=$(echo "$stats_json" | jq -r '.input_thresh // empty')
    local offset=$(echo "$stats_json" | jq -r '.target_offset // empty')

    # 防呆檢查：如果解析出空值，終止處理
    if [ -z "$measured_I" ] || [ -z "$measured_LRA" ]; then
        log_message "ERROR" "JSON 數據解析不完整"
        rm -rf "$tmp_dir"
        return 1
    fi

    # === ★★★ 混合智慧偵測與策略選擇 ★★★ ===

    # 1. 關鍵字檢查 (Case Insensitive)
    # 涵蓋: 英文(Piano/Solo...), 日文(ピアノ...), 中文(鋼琴...)
    local filename_check=$(basename "$input_file" | grep -iE "piano|nocturne|sonata|etude|recital|solo|variations|concerto|ピアノ|鋼琴|演奏|弾き語り")

    # 定義變數容器
    local target_I="-12"
    local target_LRA
    local target_TP
    local mode_name
    local mode_color
    local trigger_reason

    # 2. 判斷邏輯
    # 條件: LRA > 11.5 (高動態) 或者 檔名包含關鍵字 (鋼琴/純音樂)
    if (( $(echo "$measured_LRA > 11.5" | bc -l) )) || [ -n "$filename_check" ]; then
        
        # === 分支 A: 高動態保真模式 (High Dynamic Preservation) ===
        mode_name="高動態保真模式 (High Dynamic Preservation)"
        mode_color="${CYAN}" # 青色

        # 記錄觸發原因
        if [ -n "$filename_check" ]; then
            trigger_reason="偵測到關鍵字 (Piano/Solo/ピアノ)"
        else
            trigger_reason="偵測到高動態 (LRA > 11.5)"
        fi

        # [核心修正]: 鎖定動態範圍
        # 為了不讓 LRA 低的鋼琴曲 (如動漫翻奏) 被強行拉大動態導致忽大忽小，
        # 我們將目標 LRA 設定為等於原曲的 LRA。
        if (( $(echo "$measured_LRA < 5.0" | bc -l) )); then
             target_LRA="5.0" # 設定下限保護
        elif (( $(echo "$measured_LRA > 20.0" | bc -l) )); then
             target_LRA="20.0" # 設定上限保護
        else
             target_LRA="$measured_LRA"
        fi

        # 放寬峰值限制 (True Peak)
        target_TP="-0.5"

        log_message "INFO" "啟動保真模式 ($trigger_reason)。鎖定 Target_LRA=$target_LRA, 放寬 TP=$target_TP"

    else
        # === 分支 B: 標準廣播模式 (Standard Broadcast) ===
        mode_name="標準廣播模式 (Standard)"
        mode_color="${GREEN}" # 綠色
        trigger_reason="普通動態且無關鍵字"

        # 標準參數
        target_LRA="11"     # 統一拉至標準動態
        target_TP="-1.5"    # 嚴格防止削波

        log_message "INFO" "啟動標準模式。LRA: $measured_LRA"
    fi

    # 顯示狀態給使用者
    echo -e "    -> 響度分析: I=${measured_I} LUFS, LRA=${measured_LRA} LU"
    echo -e "    -> 判定結果: ${mode_color}${BOLD}${mode_name}${RESET}"
    echo -e "    -> 觸發原因: ${trigger_reason}"

    # =======================================================

    # 步驟 3: 第二遍 (Pass 2) - 應用標準化
    # 這裡將計算好的參數帶入
    ffmpeg -y -i "$audio_wav" \
        -af "loudnorm=I=${target_I}:TP=${target_TP}:LRA=${target_LRA}:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset:linear=true:print_format=summary" \
        -c:a pcm_s16le "$normalized_wav" > /dev/null 2>&1

    if [ $? -ne 0 ]; then
        log_message "ERROR" "音訊標準化處理失敗 (Pass 2)"
        rm -rf "$tmp_dir"
        return 1
    fi

    # 步驟 4: 最終編碼與輸出
    if [ "$is_video" = true ]; then
        # 影片模式轉 AAC
        ffmpeg -y -i "$normalized_wav" -c:a aac -b:a 256k -movflags +faststart "$output_file" > /dev/null 2>&1
    else
        # 音訊模式轉 MP3
        ffmpeg -y -i "$normalized_wav" -c:a libmp3lame -b:a 320k -id3v2_version 3 -write_id3v1 1 "$output_file" > /dev/null 2>&1
    fi

    if [ $? -ne 0 ]; then
        log_message "ERROR" "最終音訊編碼失敗"
        rm -rf "$tmp_dir"
        return 1
    fi

    # 清理
    rm -rf "$tmp_dir"
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

######################################################################
# 處理單一 YouTube 音訊（MP3）下載與處理 (v7.0 - Modern UI & Responsive)
######################################################################
process_single_mp3() {
    local media_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=1
    local final_result_string=""
    local should_notify=false

    # --- UI 變數與設置 ---
    local term_width=$(tput cols 2>/dev/null || echo 60)
    local step_current=0
    local step_total=4
    
    # 定義進度顯示函數
    print_step() {
        step_current=$((step_current + 1))
        echo -e "${BLUE}${BOLD}┌─ [Step ${step_current}/${step_total}] ${1} ${RESET}"
    }
    
    # 定義子訊息顯示函數 (灰色/縮排)
    print_sub() {
        echo -e "${WHITE}│  ${CYAN}➥ ${WHITE}${1}${RESET}"
    }

    ### --- 階段 0: 獲取元數據 --- ###
    # 不顯示進度條，這是前置作業
    local media_json
    echo -e "${YELLOW}⏳ 正在解析媒體資訊...${RESET}"
    
    media_json=$(yt-dlp --no-warnings --dump-json "$media_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: 無法獲取元數據。"
        local raw_err_b64=$(echo "無法獲取元數據" | base64 -w 0)
        final_result_string="FAIL|${media_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id="" artist_name="" album_artist_name="" duration_secs=0
    local final_audio_file="" output_audio="" temp_audio_file=""
    local sanitized_title="" final_base_name=""

    if ! $goto_cleanup; then
        # 解析 JSON
        video_title=$(echo "$media_json" | jq -r '.title // "audio_$(date +%s_default)"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_$(date +%s_default)"')
        artist_name=$(echo "$media_json" | jq -r '.artist // .uploader // "[不明]"')
        album_artist_name=$(echo "$media_json" | jq -r '.uploader // "[不明]"')
        duration_secs=$(echo "$media_json" | jq -r '.duration // 0')
        
        # --- 顯示現代化資訊卡片 ---
        clear
        draw_line "=" "$CYAN"
        echo -e "${CYAN}${BOLD} 🎵 MP3 音量標準化處理程序 ${RESET}"
        draw_line "-" "$CYAN"
        printf "${WHITE} 📌 標題 : ${GREEN}%s${RESET}\n" "$video_title"
        printf "${WHITE} 🎤 演出 : ${YELLOW}%s${RESET}\n" "$artist_name"
        printf "${WHITE} 🆔 ID   : ${PURPLE}%s${RESET}\n" "$video_id"
        printf "${WHITE} ⏱ 時長 : ${BLUE}%s 秒${RESET}\n" "$duration_secs"
        draw_line "=" "$CYAN"
        echo ""

        # 判斷是否通知 (無 bc)
        if [[ "$mode" != "playlist_mode" ]]; then
            local duration_int=${duration_secs%.*}
            local duration_threshold_secs=1800
            if [[ "$duration_int" -gt "$duration_threshold_secs" ]]; then
                should_notify=true
                log_message "INFO" "時長超過閾值，將啟用通知。"
            fi
        fi

        # 檔名清理 (v6.7 邏輯)
        local safe_chars_regex='[^a-zA-Z0-9\u4e00-\u9fff\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef _.\[\]()-]'
        if command -v iconv &> /dev/null; then
            sanitized_title=$(echo "${video_title}" | iconv -f UTF-8 -t UTF-8 -c | sed -E "s/${safe_chars_regex}/_/g")
        else
            sanitized_title=$(echo "${video_title}" | sed -E "s/${safe_chars_regex}/_/g")
        fi
        sanitized_title=$(echo "$sanitized_title" | sed 's@[/\\:*?"<>|]@_@g') # 移除保留字元
        sanitized_title=$(echo "$sanitized_title" | sed -E 's/[_ ]+/_/g')
        if [ ${#sanitized_title} -gt 80 ]; then sanitized_title="${sanitized_title:0:80}"; fi
        sanitized_title=$(echo "$sanitized_title" | sed -E 's/^[_.]+|[_.]+$//g')
        
        final_base_name="${sanitized_title} [${video_id}]"
        output_audio="${DOWNLOAD_PATH}/${final_base_name}_normalized.mp3"
        
        ### --- 階段 1: 下載 --- ###
        print_step "下載原始音訊"
        print_sub "目標: 最佳 M4A/Audio"
        
        local temp_output_template="${temp_dir}/%(id)s.%(ext)s"
        local format_option="bestaudio[ext=m4a]/bestaudio"
        
        # 使用 yt-dlp 原生進度條，但稍微縮排以符合 UI
        echo -e "${WHITE}│${RESET}" 
        local yt_dlp_audio_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$media_url" --concurrent-fragments "$THREADS" --newline --progress)
        
        if ! "${yt_dlp_audio_args[@]}" 2> "$temp_dir/yt-dlp-audio-std.log"; then
            # 下載失敗區塊
            echo -e "${RED}└─ ❌ 下載失敗！${RESET}"
            draw_line "-" "$RED"
            echo -e "${RED}${BOLD} [錯誤日誌] yt-dlp output: ${RESET}"
            cat "$temp_dir/yt-dlp-audio-std.log"
            draw_line "-" "$RED"
            
            local error_code_to_return="E_YTDLP_DL_GENERIC"
            local raw_err_b64=$(cat "$temp_dir/yt-dlp-audio-std.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|${error_code_to_return}|${raw_err_b64}"
            goto_cleanup=true
        else
            echo -e "${BLUE}└─ ✅ 下載完成${RESET}"
            temp_audio_file=$(find "$temp_dir" -maxdepth 1 -type f \( -name "*.m4a" -o -name "*.opus" -o -name "*.webm" -o -name "*.mp3" \) -print -quit)
            if [ -z "$temp_audio_file" ]; then
                log_message "ERROR" "找不到下載後的檔案。"
                goto_cleanup=true
            fi
        fi
    fi

    if ! $goto_cleanup; then
        ### --- 階段 2: 下載封面 --- ###
        print_step "獲取高解析封面"
        local cover_image="$temp_dir/cover.jpg"
        # 靜默執行，只更新狀態
        if download_high_res_thumbnail "$video_id" "$cover_image" > /dev/null 2>&1; then
            print_sub "封面下載成功"
        else
            print_sub "無法獲取封面 (將使用預設或略過)"
        fi
        echo -e "${BLUE}└─ ✅ 準備就緒${RESET}"

        ### --- 階段 3: 音量標準化 --- ###
        print_step "音量標準化 (Loudnorm)"
        print_sub "分析響度並調整至 -12 LUFS..."
        
        local normalized_temp="$temp_dir/temp_normalized.mp3"
        
        # 這裡我們需要捕獲 normalize_audio 的輸出，避免它破壞我們的 UI
        # 但因為 normalize_audio 內部也有 echo，我們讓它顯示，這部分可以接受
        if normalize_audio "$temp_audio_file" "$normalized_temp" "$temp_dir" false; then
             # normalize_audio 內部會印出綠色的成功訊息，我們補上結尾線
             echo -e "${BLUE}└─ ✅ 標準化完成${RESET}"
        else
             echo -e "${RED}└─ ❌ 標準化失敗！${RESET}"
             log_message "ERROR" "E_NORMALIZE_FAIL"
             local raw_err_b64=$(echo "normalize_audio 執行失敗" | base64 -w 0)
             final_result_string="FAIL|${video_title}|E_NORMALIZE_FAIL|${raw_err_b64}"
             result=1
             goto_cleanup=true # 標記跳過後續
        fi
    fi

    if ! $goto_cleanup && [ "$result" -eq 1 ]; then
        ### --- 階段 4: 最終封裝 (Muxing) --- ###
        print_step "封裝最終檔案"
        print_sub "寫入 ID3 標籤、封面圖片..."
        
        local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_temp")
        if [ -f "$cover_image" ]; then
            ffmpeg_embed_args+=(-i "$cover_image" -map 0:a -map 1:v -c copy -id3v2_version 3 -disposition:v attached_pic)
        else
            ffmpeg_embed_args+=(-c copy -id3v2_version 3)
        fi
        
        ffmpeg_embed_args+=(-metadata "title=${video_title}" -metadata "artist=${artist_name}" -metadata "album_artist=${album_artist_name}" "$output_audio")
        
        if ! "${ffmpeg_embed_args[@]}" > "$temp_dir/ffmpeg_embed.log" 2>&1; then
            echo -e "${RED}└─ ❌ 封裝失敗！${RESET}"
            
            # --- 完整錯誤顯示區塊 ---
            draw_line "!" "$RED"
            echo -e "${RED}${BOLD} [嚴重錯誤] FFmpeg 封裝失敗 ${RESET}"
            echo -e "${YELLOW} 這通常是因為封面格式(WebP)不支援或標題編碼問題。${RESET}"
            draw_line "-" "$RED"
            cat "$temp_dir/ffmpeg_embed.log"
            draw_line "!" "$RED"
            # -----------------------

            local raw_err_b64=$(cat "$temp_dir/ffmpeg_embed.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|E_FFMPEG_MUX|${raw_err_b64}"
            result=1
            
            # 救援機制
            echo -e "${YELLOW}🚑 啟動救援程序...${RESET}"
            local rescue_file="${DOWNLOAD_PATH}/${final_base_name}_no_meta.mp3"
            if cp "$normalized_temp" "$rescue_file"; then
                echo -e "${GREEN}   ✅ 已救援純音訊檔 (無封面):${RESET}"
                echo -e "${GREEN}   📂 $rescue_file${RESET}"
            else
                # 終極救援 (使用 ID)
                rescue_file="${DOWNLOAD_PATH}/${video_id}_safe_rescue.mp3"
                cp "$normalized_temp" "$rescue_file" && \
                echo -e "${GREEN}   ✅ 已救援純音訊檔 (使用ID檔名): $rescue_file${RESET}"
            fi
        else
            echo -e "${BLUE}└─ ✅ 封裝完成${RESET}"
            final_result_string="SUCCESS|${video_title}|MP3-320kbps"
            result=0
        fi
    fi

    ### --- 最終結果摘要區塊 --- ###
    if [ $result -eq 0 ] && [ -f "$output_audio" ]; then
        echo ""
        draw_line "=" "$GREEN"
        echo -e "${GREEN}${BOLD} 🎉 處理成功！ ${RESET}"
        echo -e "${WHITE} 📂 檔案: ${GREEN}$output_audio${RESET}"
        draw_line "=" "$GREEN"
        echo ""
    elif [ "$goto_cleanup" = false ] && [ "$result" -ne 0 ]; then 
        # 只有在非救援狀態下的失敗才顯示這個 (救援狀態上面已經顯示過了)
        # 這裡主要捕捉未知錯誤
        echo ""
    fi

    # 清理
    rm -rf "$temp_dir"
    
    # 通知邏輯
    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        if [ $result -eq 0 ]; then
            _send_termux_notification 0 "MP3 完成" "處理音訊 '$sanitized_title'" "$output_audio"
        else
            _send_termux_notification 1 "MP3 失敗" "處理音訊 '$sanitized_title' 失敗" ""
        fi
    fi

    # 播放清單模式返回值
    if [[ "$mode" == "playlist_mode" ]]; then
        echo "${final_result_string}"
    fi
    return $result
}

######################################################################
# 處理單一 YouTube 音訊（MP3）下載（無標準化）(v6.4 - 修正終端回饋)
######################################################################
process_single_mp3_no_normalize() {
    local media_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=1
    local final_result_string=""
    local should_notify=false

    ### --- 通知閥值設定 --- ###
    local size_threshold_gb=0.1

    local media_json
    media_json=$(yt-dlp --no-warnings --dump-json "$media_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: (MP3 無標準化) 無法獲取媒體的 JSON 資訊。"
        local raw_err_b64=$(echo "無法獲取元數據" | base64 -w 0)
        final_result_string="FAIL|${media_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id="" artist_name="" album_artist_name=""
    local output_audio="" temp_audio_file=""

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "audio_$(date +%s_default)"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_$(date +%s_default)"')
        artist_name=$(echo "$media_json" | jq -r '.artist // .uploader // "[不明]"')
        album_artist_name=$(echo "$media_json" | jq -r '.uploader // "[不明]"')
        
        local sanitized_title
        local safe_chars_regex='[^a-zA-Z0-9\u4e00-\u9fff\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef _.\[\]()-]'
        if command -v iconv &> /dev/null; then
            sanitized_title=$(echo "${video_title}" | iconv -f UTF-8 -t UTF-8 -c | sed -E "s/${safe_chars_regex}/_/g")
        else
            sanitized_title=$(echo "${video_title}" | sed -E "s/${safe_chars_regex}/_/g")
        fi
        sanitized_title=$(echo "$sanitized_title" | sed -E 's/[_ ]+/_/g' | cut -c 1-80)
        local final_base_name="${sanitized_title} [${video_id}]"
        
        log_message "INFO" "(MP3 無標準化) 將下載音訊到臨時目錄: ${temp_dir}"
        local temp_output_template="${temp_dir}/%(id)s.%(ext)s"
        local format_option="bestaudio/best"
        local yt_dlp_audio_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$media_url" --concurrent-fragments "$THREADS" --extract-audio --audio-format mp3 --audio-quality 0)
        
        if ! "${yt_dlp_audio_args[@]}" 2> "$temp_dir/yt-dlp-audio-std.log"; then
            log_message "WARNING" "(MP3 無標準化) yt-dlp 下載時回報錯誤。"
        fi

        temp_audio_file=$(find "$temp_dir" -maxdepth 1 -type f -name "*.mp3" -print -quit)

        if [ -z "$temp_audio_file" ]; then
            local error_code_to_return="E_YTDLP_DL_GENERIC"
            log_message "ERROR" "$error_code_to_return: (MP3 無標準化) 下載失敗。"
            local raw_err_b64=$(cat "$temp_dir/yt-dlp-audio-std.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|${error_code_to_return}|${raw_err_b64}"
            goto_cleanup=true
        else
            output_audio="${DOWNLOAD_PATH}/${final_base_name}.mp3"
            if ! mv "$temp_audio_file" "$output_audio"; then
                final_base_name="[${video_id}]"
                output_audio="${DOWNLOAD_PATH}/${final_base_name}.mp3"
                if ! mv "$temp_audio_file" "$output_audio"; then
                    goto_cleanup=true
                fi
            fi
        fi
    fi

    if ! $goto_cleanup; then
        local cover_image="$temp_dir/cover.jpg"
        download_high_res_thumbnail "$video_id" "$cover_image" > /dev/null 2>&1
        
        if [ -f "$cover_image" ]; then
            local temp_final_audio="${temp_dir}/final.mp3"
            local ffmpeg_embed_args=(ffmpeg -y -i "$output_audio" -i "$cover_image" -map 0:a -map 1:v -c copy -id3v2_version 3 -disposition:v attached_pic)
            ffmpeg_embed_args+=(-metadata "title=${video_title}" -metadata "artist=${artist_name}" -metadata "album_artist=${album_artist_name}" "$temp_final_audio")
            
            if "${ffmpeg_embed_args[@]}" > /dev/null 2>&1; then
                mv "$temp_final_audio" "$output_audio"
            fi
        fi
        
        final_result_string="SUCCESS|${video_title}|MP3-320kbps"
        result=0

        if [[ "$mode" != "playlist_mode" ]] && [ -f "$output_audio" ]; then
            local actual_size_bytes=$(stat -c %s "$output_audio" 2>/dev/null)
            local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
            if [[ "$actual_size_bytes" -gt "$size_threshold_bytes" ]]; then
                should_notify=true
                log_message "INFO" "MP3 無標準化：實際大小 ($actual_size_bytes B) 超過閥值 ($size_threshold_bytes B)，啟用通知。"
            fi
        fi
    fi

    ### --- ★★★ 核心修正：補回控制台最終報告 ★★★ --- ###
    if [ $result -eq 0 ]; then
        if [ -f "$output_audio" ]; then
            echo -e "${GREEN}處理完成！音訊已儲存至：$output_audio${RESET}"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_audio' 未找到！${RESET}"
            log_message "ERROR" "(MP3 無標準化) 處理完成但最終檔案未找到"
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MP3 無標準化)！請檢查日誌。${RESET}"
    fi

    rm -rf "$temp_dir"
    
    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        if [ $result -eq 0 ]; then
            _send_termux_notification 0 "媒體處理器：MP3 無標準化" "處理音訊 '$sanitized_title'" "$output_audio"
        else
            _send_termux_notification 1 "媒體處理器：MP3 無標準化" "處理音訊 '$sanitized_title' 失敗" ""
        fi
    fi

    if [[ "$mode" == "playlist_mode" ]]; then
        echo "${final_result_string}"
    fi
    return $result
}

######################################################################
# 處理單一 YouTube 影片（MP4）下載與處理 (v6.5 - 畫質邏輯修正)
######################################################################
process_single_mp4() {
    local video_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local subtitle_files=()
    local final_result_string="" 
    local result=1
    local should_notify=false

    ### --- 通知閥值設定 --- ###
    local duration_threshold_secs=1260 # 0.35 小時 (21 分鐘)

    local media_json
    media_json=$(yt-dlp --no-warnings --dump-json "$video_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: 無法獲取媒體的 JSON 資訊。URL: $video_url"
        local raw_err_b64=$(echo "無法獲取元數據，無特定日誌檔案。" | base64 -w 0)
        final_result_string="FAIL|${video_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id="" duration_secs=0
    local final_video_file="" output_video=""
    local temp_video_file="" 

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "video_$(date +%s_default)"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_$(date +%s_default)"')
        duration_secs=$(echo "$media_json" | jq -r '.duration // 0')

        if [[ "$mode" != "playlist_mode" ]]; then
            if (( $(echo "$duration_secs > $duration_threshold_secs" | bc -l) )); then
                should_notify=true
                log_message "INFO" "MP4 標準化：時長 ($duration_secs s) 超過閥值 ($duration_threshold_secs s)，啟用通知。"
            fi
        fi
        
        local sanitized_title
        local safe_chars_regex='[^a-zA-Z0-9\u4e00-\u9fff\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef _.\[\]()-]'
        if command -v iconv &> /dev/null; then
            sanitized_title=$(echo "${video_title}" | iconv -f UTF-8 -t UTF-8 -c | sed -E "s/${safe_chars_regex}/_/g")
        else
            sanitized_title=$(echo "${video_title}" | sed -E "s/${safe_chars_regex}/_/g")
        fi
        sanitized_title=$(echo "$sanitized_title" | sed -E 's/[_ ]+/_/g' | cut -c 1-80)
        local final_base_name="${sanitized_title} [${video_id}]"
        
        log_message "INFO" "將下載影片到臨時目錄: ${temp_dir}"
        local temp_output_template="${temp_dir}/%(id)s.%(ext)s"
        
        ### --- 核心修正：優化畫質選擇字串，優先保證畫質 --- ###
        local format_option="bestvideo[height<=1440]+bestaudio/best[height<=1440]/best"
        
        local yt_dlp_video_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$video_url" --concurrent-fragments "$THREADS")
        
        if ! "${yt_dlp_video_args[@]}" 2> "$temp_dir/yt-dlp-video-std.log"; then
            log_message "WARNING" "yt-dlp 影片下載時回報錯誤，將進行錯誤分析。"
        fi

        temp_video_file=$(find "$temp_dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) -print -quit)

        if [ -z "$temp_video_file" ]; then
            local error_code_to_return="E_YTDLP_DL_GENERIC"
            if grep -q "Requested format is not available" "$temp_dir/yt-dlp-video-std.log"; then error_code_to_return="E_YTDLP_FORMAT";
            elif grep -q "HTTP Error 403" "$temp_dir/yt-dlp-video-std.log"; then error_code_to_return="E_YTDLP_DL_403";
            elif grep -q "Operation not permitted" "$temp_dir/yt-dlp-video-std.log"; then error_code_to_return="E_FS_PERM";
            else error_code_to_return="E_FILE_NOT_FOUND"; fi
            
            log_message "ERROR" "$error_code_to_return: 下載失敗，在臨時目錄中找不到任何影片檔案。"
            local raw_err_b64=$(cat "$temp_dir/yt-dlp-video-std.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|${error_code_to_return}|${raw_err_b64}"
            goto_cleanup=true
        else
            local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
            local yt_dlp_subs_args=(yt-dlp --skip-download --write-subs --sub-lang "$target_sub_langs" --convert-subs srt -o "${temp_dir}/%(id)s.%(sublang)s.%(ext)s" "$video_url")
            "${yt_dlp_subs_args[@]}" > /dev/null 2>&1

            local extension="${temp_video_file##*.}"
            final_video_file="${DOWNLOAD_PATH}/${final_base_name}.${extension}"
            output_video="${DOWNLOAD_PATH}/${final_base_name}_normalized.mp4"

            local mv_error
            if ! mv_error=$(mv "$temp_video_file" "$final_video_file" 2>&1); then
                log_message "WARNING" "使用清理後的標題重命名失敗，將降級為僅使用影片 ID。"
                final_base_name="[${video_id}]"
                final_video_file="${DOWNLOAD_PATH}/${final_base_name}.${extension}"
                if ! mv_error=$(mv "$temp_video_file" "$final_video_file" 2>&1); then
                    log_message "ERROR" "E_FS_PERM: 降級後重命名依然失敗！"
                    local raw_err_b64=$(echo -e "命令: mv \"$temp_video_file\" \"$final_video_file\"\n錯誤: $mv_error" | base64 -w 0)
                    final_result_string="FAIL|${video_title}|E_FS_PERM|${raw_err_b64}"
                    goto_cleanup=true
                fi
            fi
            
            if ! $goto_cleanup; then
                 output_video="${DOWNLOAD_PATH}/${final_base_name}_normalized.mp4"
            fi
        fi
    fi

    if ! $goto_cleanup; then
        local resolution
        local ffprobe_error
        ffprobe_output=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$final_video_file" 2>&1)
        local ffprobe_exit_code=$?

        if [ $ffprobe_exit_code -ne 0 ] || [ -z "$ffprobe_output" ]; then
            resolution=""; ffprobe_error=$ffprobe_output
        else
            resolution=$ffprobe_output
        fi
        
        if [ -z "$resolution" ]; then
            log_message "ERROR" "E_FFPROBE_RES: 無法獲取影片解析度: $final_video_file"
            safe_remove "$final_video_file"
            local raw_err_b64=$(echo -e "命令: ffprobe ... \"$final_video_file\"\n錯誤: $ffprobe_error" | base64 -w 0)
            final_result_string="FAIL|${video_title}|E_FFPROBE_RES|${raw_err_b64}"
            goto_cleanup=true
        else
            log_message "INFO" "影片重命名並驗證成功：$final_video_file, 解析度: $resolution"
        fi
    fi

    if ! $goto_cleanup; then
        while IFS= read -r srt_file; do
            local srt_basename=$(basename "$srt_file")
            local new_srt_path="${DOWNLOAD_PATH}/${final_base_name}.${srt_basename#*.}"
            if mv "$srt_file" "$new_srt_path"; then
                subtitle_files+=("$new_srt_path"); log_message "INFO" "找到並移動字幕到: $new_srt_path"
            fi
        done < <(find "$temp_dir" -maxdepth 1 -type f -name "${video_id}.*.srt")

        local normalized_audio_temp="$temp_dir/audio_normalized.m4a"
        if normalize_audio "$final_video_file" "$normalized_audio_temp" "$temp_dir" true; then
            local ffmpeg_mux_args=(ffmpeg -y -i "$final_video_file" -i "$normalized_audio_temp")
            for sub_f in "${subtitle_files[@]}"; do ffmpeg_mux_args+=("-i" "$sub_f"); done
            ffmpeg_mux_args+=(-metadata "title=${video_title}")
            ffmpeg_mux_args+=(-map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 256k -ar 44100)
            if [ ${#subtitle_files[@]} -gt 0 ]; then
                ffmpeg_mux_args+=("-c:s" mov_text)
                for ((i=0; i<${#subtitle_files[@]}; i++)); do
                    ffmpeg_mux_args+=(-map $((i+2)):0)
                    local sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev); local ffmpeg_lang="und"
                    case "$sub_lang_code" in zh-Hant|zh-TW) ffmpeg_lang="zht" ;; zh-Hans|zh-CN) ffmpeg_lang="zhs" ;; zh) ffmpeg_lang="chi" ;; esac
                    ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang")
                done
            fi
            ffmpeg_mux_args+=(-movflags "+faststart" "$output_video")
            
            if ! "${ffmpeg_mux_args[@]}" > "$temp_dir/ffmpeg_mux.log" 2>&1; then
                log_message "ERROR" "E_FFMPEG_MUX: 混流失敗！"
                local raw_err_b64=$(cat "$temp_dir/ffmpeg_mux.log" | base64 -w 0)
                final_result_string="FAIL|${video_title}|E_FFMPEG_MUX|${raw_err_b64}"
                result=1
            else
                log_message "SUCCESS" "混流成功"
                final_result_string="SUCCESS|${video_title}|${resolution}"
                result=0
            fi
        else
            log_message "ERROR" "E_NORMALIZE_FAIL: 音量標準化失敗！"
            local raw_err_b64=$(echo "normalize_audio 函數執行失敗，請檢查其日誌。" | base64 -w 0)
            final_result_string="FAIL|${video_title}|E_NORMALIZE_FAIL|${raw_err_b64}"
            result=1
        fi
    fi
    
    if [ $result -eq 0 ]; then
        if [ -f "$output_video" ]; then
            echo -e "${GREEN}處理完成！影片已儲存至：$output_video${RESET}"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video' 未找到！${RESET}"
            log_message "ERROR" "(MP4 標準化) 處理完成但最終檔案未找到"
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MP4 標準化)！請檢查日誌。${RESET}"
    fi
    
    log_message "INFO" "清理檔案 (MP4 標準化)..."
    if [ -f "$final_video_file" ]; then
        safe_remove "$final_video_file"
    fi
    for sub_f in "${subtitle_files[@]}"; do safe_remove "$sub_f"; done
    rm -rf "$temp_dir"
    
    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        if [ $result -eq 0 ]; then
            _send_termux_notification 0 "媒體處理器：MP4 標準化" "處理影片 '$sanitized_title'" "$output_video"
        else
            _send_termux_notification 1 "媒體處理器：MP4 標準化" "處理影片 '$sanitized_title' 失敗" ""
        fi
    fi

    if [[ "$mode" == "playlist_mode" ]]; then
        echo "${final_result_string}"
    fi
    return $result
}

######################################################################
# 處理單一 YouTube 影片（MP4）下載（無標準化）(v6.5 - 畫質邏輯修正)
######################################################################
process_single_mp4_no_normalize() {
    local video_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local subtitle_files=()
    local final_result_string="" 
    local result=1
    local should_notify=false

    ### --- 通知閥值設定 (易於修改) --- ###
    local size_threshold_gb=1.0

    local media_json
    media_json=$(yt-dlp --no-warnings --dump-json "$video_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: (無標準化) 無法獲取媒體的 JSON 資訊。URL: $video_url"
        local raw_err_b64=$(echo "無法獲取元數據，無特定日誌檔案。" | base64 -w 0)
        final_result_string="FAIL|${video_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id=""
    local final_video_file="" temp_video_file="" 

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "video_$(date +%s_default)"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_$(date +%s_default)"')
        
        local sanitized_title
        local safe_chars_regex='[^a-zA-Z0-9\u4e00-\u9fff\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef _.\[\]()-]'
        if command -v iconv &> /dev/null; then
            sanitized_title=$(echo "${video_title}" | iconv -f UTF-8 -t UTF-8 -c | sed -E "s/${safe_chars_regex}/_/g")
        else
            sanitized_title=$(echo "${video_title}" | sed -E "s/${safe_chars_regex}/_/g")
        fi
        sanitized_title=$(echo "$sanitized_title" | sed -E 's/[_ ]+/_/g' | cut -c 1-80)
        local final_base_name="${sanitized_title} [${video_id}]"
        
        log_message "INFO" "(無標準化) 將下載影片到臨時目錄: ${temp_dir}"
        local temp_output_template="${temp_dir}/%(id)s.%(ext)s"
        
        ### --- 核心修正：優化畫質選擇字串，優先保證畫質 --- ###
        local format_option="bestvideo[height<=1440]+bestaudio/best[height<=1440]/best"
        
        local yt_dlp_video_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$video_url" --concurrent-fragments "$THREADS" --merge-output-format mp4 --write-subs --embed-subs --sub-lang "zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA")
        
        if ! "${yt_dlp_video_args[@]}" 2> "$temp_dir/yt-dlp-video-std.log"; then
            log_message "WARNING" "(無標準化) yt-dlp 影片下載時回報錯誤，將進行錯誤分析。"
        fi

        temp_video_file=$(find "$temp_dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) -print -quit)

        if [ -z "$temp_video_file" ]; then
            local error_code_to_return="E_YTDLP_DL_GENERIC"
            if grep -q "Requested format is not available" "$temp_dir/yt-dlp-video-std.log"; then error_code_to_return="E_YTDLP_FORMAT";
            elif grep -q "HTTP Error 403" "$temp_dir/yt-dlp-video-std.log"; then error_code_to_return="E_YTDLP_DL_403";
            elif grep -q "Operation not permitted" "$temp_dir/yt-dlp-video-std.log"; then error_code_to_return="E_FS_PERM";
            else error_code_to_return="E_FILE_NOT_FOUND"; fi
            
            log_message "ERROR" "$error_code_to_return: (無標準化) 下載失敗。"
            local raw_err_b64=$(cat "$temp_dir/yt-dlp-video-std.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|${error_code_to_return}|${raw_err_b64}"
            goto_cleanup=true
        else
            local extension="${temp_video_file##*.}"
            final_video_file="${DOWNLOAD_PATH}/${final_base_name}.${extension}"
            
            local mv_error
            if ! mv_error=$(mv "$temp_video_file" "$final_video_file" 2>&1); then
                log_message "WARNING" "(無標準化) 使用清理後的標題重命名失敗，將降級為僅使用影片 ID。"
                final_base_name="[${video_id}]"
                final_video_file="${DOWNLOAD_PATH}/${final_base_name}.${extension}"
                if ! mv_error=$(mv "$temp_video_file" "$final_video_file" 2>&1); then
                    log_message "ERROR" "E_FS_PERM: (無標準化) 降級後重命名依然失敗！"
                    local raw_err_b64=$(echo -e "命令: mv \"$temp_video_file\" \"$final_video_file\"\n錯誤: $mv_error" | base64 -w 0)
                    final_result_string="FAIL|${video_title}|E_FS_PERM|${raw_err_b64}"
                    goto_cleanup=true
                fi
            fi
        fi
    fi

    if ! $goto_cleanup; then
        local resolution
        local ffprobe_error
        ffprobe_output=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$final_video_file" 2>&1)
        local ffprobe_exit_code=$?
        if [ $ffprobe_exit_code -ne 0 ] || [ -z "$ffprobe_output" ]; then
            resolution="未知"; ffprobe_error=$ffprobe_output
        else
            resolution=$ffprobe_output
        fi
        
        log_message "INFO" "(無標準化) 影片處理完成：$final_video_file, 解析度: $resolution"
        final_result_string="SUCCESS|${video_title}|${resolution}"
        result=0

        if [[ "$mode" != "playlist_mode" ]] && [ -f "$final_video_file" ]; then
            local actual_size_bytes=$(stat -c %s "$final_video_file" 2>/dev/null)
            local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
            if [[ "$actual_size_bytes" -gt "$size_threshold_bytes" ]]; then
                should_notify=true
                log_message "INFO" "MP4 無標準化：實際大小 ($actual_size_bytes B) 超過閥值 ($size_threshold_bytes B)，啟用通知。"
            fi
        fi
    fi
    
    if [ $result -eq 0 ]; then
        if [ -f "$final_video_file" ]; then
            echo -e "${GREEN}處理完成！影片已儲存至：$final_video_file${RESET}"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$final_video_file' 未找到！${RESET}"
            log_message "ERROR" "(無標準化) 處理完成但最終檔案未找到"
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MP4 無標準化)！請檢查日誌。${RESET}"
    fi

    rm -rf "$temp_dir"
    
    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        if [ $result -eq 0 ]; then
            _send_termux_notification 0 "媒體處理器：MP4 無標準化" "處理影片 '$sanitized_title'" "$final_video_file"
        else
            _send_termux_notification 1 "媒體處理器：MP4 無標準化" "處理影片 '$sanitized_title' 失敗" ""
        fi
    fi

    if [[ "$mode" == "playlist_mode" ]]; then
        echo "${final_result_string}"
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
# <<< ★★★ 版本更新：將通知決策移至檔案下載後，基於實際大小判斷 ★★★ >>>
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

    # <<< 舊的預估大小邏輯已被移除 >>>
    
    echo -e "${CYAN}${progress_prefix}處理項目: $item_url (${choice_format})${RESET}"; log_message "INFO" "${progress_prefix}處理項目: $item_url (格式: $choice_format)"
    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; rm -rf "$temp_dir"; return 1; fi

    # --- 下載 ---
    local download_success=false
    local actual_yt_dlp_args=()
    local chosen_output_template=""

    echo -e "${YELLOW}${progress_prefix}開始下載主檔案...${RESET}"

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
        fi
    else
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

    if $download_success; then
        echo -e "${YELLOW}${progress_prefix}定位主檔案...${RESET}"
        local format_for_getfn=""
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
            base_name_calculated_from_file=$(basename "$main_media_file" | sed 's/\.[^.]*$//')
            log_message "DEBUG" "從檔案計算出的 Base Name: [$base_name_calculated_from_file]"
            result=0

            # ★★★ 新增：在檔案下載並驗證後，根據實際大小決定是否通知 ★★★
            if ! $is_playlist; then
                echo -e "${YELLOW}正在檢查實際檔案大小以決定是否通知...${RESET}"
                local actual_size_bytes
                actual_size_bytes=$(stat -c %s "$main_media_file" 2>/dev/null)

                if [[ "$actual_size_bytes" =~ ^[0-9]+$ ]]; then
                    # 根據格式選擇不同的閾值
                    local size_threshold_gb=0.12 # 預設閾值
                    if [ "$choice_format" = "mp4" ]; then
                        size_threshold_gb=0.3 # MP4 使用較大的閾值
                    fi
                    local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
                    log_message "INFO" "通用下載 標準化：實際大小 = $actual_size_bytes bytes, 閾值 = $size_threshold_bytes bytes."
                    
                    if [[ "$actual_size_bytes" -gt "$size_threshold_bytes" ]]; then
                        log_message "INFO" "通用下載 標準化：實際大小超過閾值，啟用通知。"
                        should_notify=true
                    else
                        log_message "INFO" "通用下載 標準化：實際大小未超過閾值，禁用通知。"
                        should_notify=false
                    fi
                else
                    log_message "WARNING" "無法獲取下載檔案的實際大小，將禁用通知。"
                    should_notify=false
                fi
            fi
            # ★★★ 判斷結束 ★★★

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
        if [ -n "$base_name_calculated_from_file" ]; then
            local media_dir=$(dirname "$main_media_file")
            local thumb_dl_template="${media_dir}/${base_name_calculated_from_file}.%(ext)s"
            log_message "DEBUG" "嘗試使用縮圖模板: $thumb_dl_template"
            
            if ! yt-dlp --no-warnings --skip-download --write-thumbnail -o "$thumb_dl_template" "$item_url" 2> "$temp_dir/yt-dlp-thumb.log"; then
                log_message "WARNING" "...下載縮圖指令失敗或無縮圖，詳見 $temp_dir/yt-dlp-thumb.log"
            fi
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
        local media_output_dir=$(dirname "$main_media_file")

        if [ "$choice_format" = "mp3" ]; then
            output_final_file="${media_output_dir}/${base_name_calculated_from_file}_normalized.mp3";
            local normalized_temp_audio_for_mp3="$temp_dir/temp_normalized_for_mp3.mp3"
            
            echo -e "${YELLOW}${progress_prefix}開始標準化 (MP3)...${RESET}"
            if normalize_audio "$main_media_file" "$normalized_temp_audio_for_mp3" "$temp_dir" false; then
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
                     safe_remove "$normalized_temp_audio_for_mp3"
                fi
            else result=1; log_message "ERROR" "標準化失敗 (通用 MP3 std)"; fi

        elif [ "$choice_format" = "mp4" ]; then
            output_final_file="${media_output_dir}/${base_name_calculated_from_file}_normalized.mp4";
            local normalized_audio_m4a_for_mp4="$temp_dir/audio_normalized_for_mp4.m4a"
            
            echo -e "${YELLOW}${progress_prefix}開始標準化 (提取音訊為 M4A)...${RESET}"
            if normalize_audio "$main_media_file" "$normalized_audio_m4a_for_mp4" "$temp_dir" true; then
                echo -e "${YELLOW}${progress_prefix}混流影片與標準化音訊...${RESET}"
                local ffmpeg_mux_args=(ffmpeg -y -i "$main_media_file" -i "$normalized_audio_m4a_for_mp4" -c:v copy -c:a aac -b:a 256k -ar 44100 -map 0:v:0 -map 1:a:0 -movflags +faststart "$output_final_file")
                log_message "INFO" "執行 FFmpeg 混流 (通用 std): ${ffmpeg_mux_args[*]}"
                if ! "${ffmpeg_mux_args[@]}" > "$temp_dir/ffmpeg_mux.log" 2>&1; then
                     log_message "ERROR" "...混流 MP4 失敗 (通用 std)... 詳見 $temp_dir/ffmpeg_mux.log"; echo -e "${RED}錯誤：混流 MP4 失敗！${RESET}";
                     cat "$temp_dir/ffmpeg_mux.log"
                     result=1; 
                else
                     result=0; 
                     safe_remove "$normalized_audio_m4a_for_mp4"
                     rm -f "$temp_dir/ffmpeg_mux.log"
                fi
            else result=1; log_message "ERROR" "標準化失敗 (通用 MP4 std)"; fi
        fi
    fi 

    # --- 清理 ---
    log_message "INFO" "${progress_prefix}清理 (通用 std)...";
    if [ $result -eq 0 ] && [ -f "$main_media_file" ]; then
        safe_remove "$main_media_file";
    fi
    if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then
        safe_remove "$thumbnail_file";
    fi
    safe_remove "$temp_dir/yt-dlp-other-std.log" "$temp_dir/yt-dlp-thumb.log" "$temp_dir/ffmpeg_mux.log"
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
# <<< ★★★ 版本更新：將通知決策移至檔案下載後，基於實際大小判斷 ★★★ >>>
###########################################################
_process_single_other_site_no_normalize() {
    # --- 接收參數 ---
    local item_url="$1"; local choice_format="$2"; local item_index="$3"; local total_items="$4"
    local mode="$5"
    local output_template_playlist="$6"
    local output_template_single_item="$7"

    # --- 局部變數 ---
    local temp_dir=$(mktemp -d); local thumbnail_file=""; local main_media_file="";
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
    video_id=$(yt-dlp --get-id "$item_url" 2>/dev/null) || video_id="no_id_$(date +%s)"
    sanitized_title=$(echo "${item_title}" | sed 's@[/\\:*?"<>|]@_@g')
    log_message "DEBUG" "基礎標題: '$item_title', ID: '$video_id', 清理後: '$sanitized_title'"

    # <<< 舊的預估大小邏輯已被移除 >>>

    echo -e "${CYAN}${progress_prefix}處理項目 (無標準化): $item_url (${choice_format})${RESET}";
    log_message "INFO" "${progress_prefix}處理項目 (無標準化): $item_url (格式: $choice_format)"

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; result=1; rm -rf "$temp_dir"; return 1; fi

    # --- 下載 ---
    local download_success=false
    local actual_yt_dlp_args=()
    local chosen_output_template=""

    echo -e "${YELLOW}${progress_prefix}開始下載 (無標準化)...${RESET}"

    if [[ "$item_url" == *"bilibili.com"* ]]; then
        log_message "INFO" "檢測到 Bilibili URL，將使用 aria2c 及優化參數。"
        echo -e "${CYAN}${progress_prefix}檢測到 Bilibili 網站，啟用 aria2c 加速下載。${RESET}"
        
        local bili_format_select=""
        if [ "$choice_format" = "mp4" ]; then
            bili_format_select="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
        else # mp3
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
        elif [ "$choice_format" = "mp3" ]; then
            actual_yt_dlp_args+=(--extract-audio --audio-format mp3 --audio-quality 0)
        fi
    else
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
        )
        if [ "$choice_format" = "mp4" ]; then
             actual_yt_dlp_args+=(--merge-output-format mp4)
        elif [ "$choice_format" = "mp3" ]; then
            actual_yt_dlp_args+=(--extract-audio --audio-format mp3 --audio-quality 0)
        fi
    fi

    if $is_playlist; then
        chosen_output_template="$output_template_playlist"
    else
        chosen_output_template="$output_template_single_item"
    fi
    
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

    if $download_success; then
        echo -e "${YELLOW}${progress_prefix}定位下載的檔案...${RESET}"
        local format_for_getfn=""
        if [[ "$item_url" == *"bilibili.com"* ]]; then
             if [ "$choice_format" = "mp4" ]; then format_for_getfn="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best";
             else format_for_getfn="bestaudio[ext=m4a]/bestaudio/best"; fi
        else
             if [ "$choice_format" = "mp4" ]; then format_for_getfn="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
             else format_for_getfn="bestaudio/best"; fi
        fi

        local yt_dlp_getfn_args=(yt-dlp --no-warnings --print filename -f "$format_for_getfn" -o "$final_output_template_used")
        local actual_download_path=""
        local getfn_exit_code=1

        if [ "$choice_format" = "mp3" ]; then
            local temp_name_for_mp3_base
            temp_name_for_mp3_base=$(yt-dlp --no-warnings --get-filename -f "$format_for_getfn" -o "$final_output_template_used" "$item_url" | sed 's/\.[^.]*$//')
             if [ -n "$temp_name_for_mp3_base" ]; then
                actual_download_path="${temp_name_for_mp3_base}.mp3"
                getfn_exit_code=0
             fi
        else # For MP4
             actual_download_path=$( "${yt_dlp_getfn_args[@]}" "$item_url" | tr -d '\n' )
             getfn_exit_code=$?
        fi

        log_message "DEBUG" "獲取檔名(格式: $choice_format)命令退出碼: $getfn_exit_code, 推斷/獲取的路徑: '$actual_download_path'"

        if [ $getfn_exit_code -eq 0 ] && [ -n "$actual_download_path" ] && [ -f "$actual_download_path" ]; then
            main_media_file="$actual_download_path"
            log_message "INFO" "${progress_prefix}成功定位到下載檔案: $main_media_file"
            result=0

            # ★★★ 新增：在檔案下載並驗證後，根據實際大小決定是否通知 ★★★
            if ! $is_playlist; then
                echo -e "${YELLOW}正在檢查實際檔案大小以決定是否通知...${RESET}"
                local actual_size_bytes
                actual_size_bytes=$(stat -c %s "$main_media_file" 2>/dev/null)

                if [[ "$actual_size_bytes" =~ ^[0-9]+$ ]]; then
                    local size_threshold_gb=0.5 # 無標準化流程使用較大的預設閾值
                    local size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
                    log_message "INFO" "通用下載 無標準化：實際大小 = $actual_size_bytes bytes, 閾值 = $size_threshold_bytes bytes."
                    
                    if [[ "$actual_size_bytes" -gt "$size_threshold_bytes" ]]; then
                        log_message "INFO" "通用下載 無標準化：實際大小超過閾值，啟用通知。"
                        should_notify=true
                    else
                        log_message "INFO" "通用下載 無標準化：實際大小未超過閾值，禁用通知。"
                        should_notify=false
                    fi
                else
                    log_message "WARNING" "無法獲取下載檔案的實際大小，將禁用通知。"
                    should_notify=false
                fi
            fi
            # ★★★ 判斷結束 ★★★

        else
            log_message "ERROR" "...無法通過 --print filename / 推斷 獲取或驗證實際檔案路徑。退出碼: $getfn_exit_code, 路徑: '$actual_download_path'"
            echo -e "${RED}錯誤：下載後無法定位主要檔案！檢查日誌。${RESET}";
            result=1
        fi
    else
        log_message "DEBUG" "下載標記為失敗，跳過檔案定位。"
    fi

    if [ $result -eq 0 ]; then
        log_message "INFO" "${progress_prefix}跳過音量標準化與後處理 (無標準化版本)。"
        echo -e "${GREEN}${progress_prefix}下載完成 (無標準化)。${RESET}"
    fi

    # --- 清理 ---
    log_message "INFO" "${progress_prefix}清理臨時檔案 (無標準化)..."
    safe_remove "$temp_dir/yt-dlp-other-nonorm.log"
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
# 輔助函數 - 獲取播放清單影片數量 (優化版 v2)
############################################
_get_playlist_video_count() {
    local url="$1"
    echo -e "${YELLOW}正在獲取播放清單項目總數...${RESET}"

    # 方法1: 使用 --print 'playlist_count'，這是最直接且高效的方式
    local count
    count=$(yt-dlp --no-warnings --print '%(playlist_count)s' "$url" 2>/dev/null | head -n 1)

    # 驗證獲取的 count 是否為有效數字
    if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
        log_message "INFO" "透過 --print 成功獲取到 $count 個影片 for $url"
        echo "$count"
        return 0
    fi

    # 方法2: 如果方法1失敗（例如對於非典型播放清單），回退到原有的 dump-json + jq 方式
    log_message "WARNING" "--print '%(playlist_count)s' 未能獲取數量，嘗試回退到 jq 方法..."
    local json_output
    json_output=$(yt-dlp --flat-playlist --dump-json "$url" 2>/dev/null)
    
    if [ -n "$json_output" ] && command -v jq &>/dev/null; then
        # 使用 jq 計算 JSON 物件的行數
        count=$(echo "$json_output" | jq -s 'length' 2>/dev/null)
        if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
            log_message "INFO" "透過 jq 回退方法成功獲取到 $count 個影片 for $url"
            echo "$count"
            return 0
        fi
    fi
    
    # 如果所有方法都失敗
    log_message "ERROR" "無法獲取播放清單數量 for $url"
    echo "" # 輸出空字串表示失敗
    return 1
}

###################################################################
# 輔助函數 - 處理 YouTube 播放清單通用流程 (v3.5 - 引入智能重試)
###################################################################
_process_youtube_playlist() {
    local playlist_url="$1"
    local single_item_processor_func_name="$2"
    log_message "INFO" "處理 YouTube 播放列表: $playlist_url (處理器: $single_item_processor_func_name)"

    echo -e "${YELLOW}正在獲取播放清單的影片 ID 列表 (穩健模式)...${RESET}"

    # ★★★ 核心修正：引入智能重試機制 ★★★
    local id_list=""
    local attempts=3
    for (( i=1; i<=attempts; i++ )); do
        id_list=$(yt-dlp --flat-playlist --print '%(id)s' "$playlist_url" 2> >(log_message "DEBUG" "yt-dlp stderr (attempt $i): " >&2))
        
        # 如果成功獲取到 ID 列表，就立即跳出循環
        if [ -n "$id_list" ]; then
            log_message "INFO" "在第 $i 次嘗試中成功獲取到影片 ID 列表。"
            break
        fi
        
        # 如果還不是最後一次嘗試，就顯示提示並等待
        if [ "$i" -lt "$attempts" ]; then
            log_message "WARNING" "獲取影片 ID 列表失敗 (第 $i 次嘗試)，將在 2 秒後重試。"
            echo -e "${YELLOW}獲取影片資訊失敗，2 秒後進行第 $((i+1)) 次重試...${RESET}"
            sleep 2
        fi
    done

    if [ -z "$id_list" ]; then
        log_message "ERROR" "在 $attempts 次嘗試後，依然無法從 yt-dlp 獲取影片 ID 列表 (輸出為空)。"
        echo -e "${RED}錯誤：無法獲取播放清單的影片 ID 列表。請檢查 URL 或網路連線。${RESET}"
        return 1
    fi

    local video_ids=()
    while IFS= read -r line; do [ -n "$line" ] && video_ids+=("$line"); done <<< "$id_list"
    local total_videos=${#video_ids[@]}
    if [ "$total_videos" -eq 0 ]; then
        log_message "ERROR" "解析後，影片 ID 列表為空。"; echo -e "${RED}錯誤：未找到任何有效的影片 ID。${RESET}"; return 1
    fi

    if [[ "$total_videos" -gt 1 ]]; then
        echo -e "${CYAN}播放清單共有 $total_videos 個影片。開始處理...${RESET}"
    else
        echo -e "${CYAN}檢測到單一影片，開始處理...${RESET}"
    fi

    local count=0
    local PLAYLIST_RESULTS=()
    local overall_fail_count=0

    for video_id in "${video_ids[@]}"; do
        count=$((count + 1))
        local video_url="https://www.youtube.com/watch?v=$video_id"
        
        if [[ "$total_videos" -gt 1 ]]; then
            clear
            echo -e "${CYAN}--- 正在處理第 $count/$total_videos 個影片 ---${RESET}"
            echo -e "${YELLOW}URL: $video_url${RESET}"
        fi
        
        log_message "INFO" "[$count/$total_videos] 處理影片: $video_url"

        set -o pipefail
        local processing_result
        processing_result=$( "$single_item_processor_func_name" "$video_url" "playlist_mode" | tee /dev/tty | tail -n 1 )
        local exit_code=$?
        set +o pipefail
        
        PLAYLIST_RESULTS+=("$processing_result")

        if [ $exit_code -ne 0 ]; then
            overall_fail_count=$((overall_fail_count + 1))
        fi
    done

    if [[ "$total_videos" -eq 1 ]] && [[ "$overall_fail_count" -gt 0 ]]; then
        read -p "處理時發生錯誤，請檢查上方輸出。按 Enter 繼續以查看摘要報告..."
    fi
    
    _display_playlist_summary "${PLAYLIST_RESULTS[@]}"

    if [[ "$total_videos" -gt 1 ]]; then
        local ovr=0
        local success_count=$((count - overall_fail_count))
        local summary_msg=""
        
        if [ "$overall_fail_count" -gt 0 ]; then
            ovr=1
            summary_msg="播放清單處理有 ${overall_fail_count} 個項目失敗"
        else
            ovr=0
            summary_msg="播放清單處理完成 ($success_count/$count 全部成功)"
        fi

        _send_termux_notification "$ovr" "媒體處理器：播放清單完成" "$summary_msg" ""
    fi
    
    if [ "$overall_fail_count" -gt 0 ]; then return 1; else return 0; fi
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
    # 提示使用者輸入，並設定預設值
    read -p "輸入 YouTube 網址或本機路徑 [預設: $DEFAULT_URL]: " input; input=${input:-$DEFAULT_URL}
    
    ### --- 核心修正：明確區分本機檔案、播放列表和單一影片，進行正確分流 --- ###
    if [ -f "$input" ]; then
        # 情況一：輸入的是一個存在的本機檔案。
        # 直接交給本機檔案處理器。
        log_message "INFO" "process_mp4: 檢測到本機檔案 '$input'，將調用本機處理器。"
        process_local_mp4 "$input"
        
    elif [[ "$input" == *"list="* ]]; then
        # 情況二：輸入的網址包含 'list='，明確是播放列表。
        # 將播放列表交給專為處理播放列表設計的函數。
        log_message "INFO" "process_mp4: 檢測到播放列表 '$input'，將調用播放列表處理器。"
        _process_youtube_playlist "$input" "process_single_mp4"
        
    elif [[ "$input" == *"youtube.com"* || "$input" == *"youtu.be"* ]]; then
        # 情況三：輸入的是 YouTube 網址，但不是播放列表，視為單一影片。
        # 直接調用為處理單一影片設計的函數，這才是正確的流程。
        log_message "INFO" "process_mp4: 檢測到單一 YouTube 影片 '$input'，將調用單項處理器。"
        process_single_mp4 "$input"
        
    else
        # 情況四：輸入的不是上述任何一種有效格式。
        echo -e "${RED}錯誤：輸入的不是有效的 YouTube 網址或本機檔案路徑。${RESET}"
        log_message "ERROR" "process_mp4: 無效的輸入 '$input'"
        return 1
    fi
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

    local magic_seed=2006092711211412914
    local adjustment_factor=$(( magic_seed % 4 ))
    local adjusted_cores=$(( cpu_cores ^ adjustment_factor ))
    local recommended_threads=$(( adjusted_cores * 3 / 4 ))

    # 確保計算結果在預設的最大和最小執行緒數之間，這讓整個邏輯更完整、更合理。
    if [ "$recommended_threads" -lt "$MIN_THREADS" ]; then
        recommended_threads=$MIN_THREADS
    elif [ "$recommended_threads" -gt "$MAX_THREADS" ]; then
        recommended_threads=$MAX_THREADS
    fi

    # 只有在計算出的推薦值與目前值不同時才更新並儲存
    if [[ "$THREADS" != "$recommended_threads" ]]; then
        log_message "INFO" "執行緒自動調整：從 $THREADS -> $recommended_threads (基於 $cpu_cores 核心與個人化因子計算)"
        THREADS=$recommended_threads
        echo -e "${GREEN}執行緒已自動調整為 $THREADS (基於 CPU 核心數)${RESET}"
        save_config
    else
        # 如果值沒有變化，可以選擇性地顯示訊息或保持安靜
        log_message "INFO" "自動調整執行緒檢查：目前值 ($THREADS) 已是推薦值，無需更改。"
    fi
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
    echo -e "${RED}${BOLD}警告：如果已有 .bashrc 文件，其內容將被覆蓋！${RESET}"
    echo -e "${YELLOW}如果您有自訂的 .bashrc 設定，請先備份 '${HOME}/.bashrc'。${RESET}"
    echo ""
    read -p "您確定要繼續嗎？ (y/n): " confirm_setup
    echo ""

    if [[ ! "$confirm_setup" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了 Termux 啟動設定。"
        echo -e "${YELLOW}已取消設定。${RESET}"
        return 1
    fi

    # --- 定義所有需要用到的腳本路徑 ---
    local main_script_path="$SCRIPT_INSTALL_PATH"

    # --- 檢查所有目標腳本是否存在且可執行 ---
    local script_check_ok=true
    for script in "$main_script_path" "$tracker_script_path" "$calculator_script_path"; do
        if [ ! -f "$script" ]; then
            log_message "ERROR" "找不到必要的腳本檔案 '$script'。無法設定自動啟動。"
            echo -e "${RED}錯誤：找不到腳本檔案 '$script'！${RESET}"
            script_check_ok=false
        elif [ ! -x "$script" ]; then
            echo -e "${YELLOW}警告：腳本檔案 '$script' 沒有執行權限，正在嘗試設定...${RESET}"
            if ! chmod +x "$script"; then
                log_message "ERROR" "無法設定 '$script' 的執行權限！"
                echo -e "${RED}錯誤：無法設定 '$script' 的執行權限！請手動設定。${RESET}"
                script_check_ok=false
            else
                log_message "INFO" "成功設定 '$script' 的執行權限。"
                echo -e "${GREEN}  > '$script' 權限設定成功。${RESET}"
            fi
        fi
    done

    if ! $script_check_ok; then
        echo -e "${RED}由於腳本檔案缺失或權限問題，設定程序中止。${RESET}"
        return 1
    fi
    # --- 檢查結束 ---

    log_message "INFO" "開始設定 Termux 啟動腳本..."
    echo -e "${YELLOW}正在寫入設定到 ~/.bashrc ...${RESET}"

    # --- 使用 cat 和 EOF 將配置寫入 .bashrc ---
cat > ~/.bashrc << EOF
# ~/.bashrc - v4 (Multi-script Launcher)

# --- 整合式平台啟動設定 ---

# 1. 定義別名 (使用腳本實際安裝路徑)
alias media='$main_script_path'
alias track='$tracker_script_path'
alias analyze='$calculator_script_path'

# 2. 僅在交互式 Shell 啟動時顯示提示
if [[ \$- == *i* ]]; then
    # --- 在此處定義此 if 塊內使用的顏色變數 ---
    CLR_RESET='\033[0m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[1;33m'
    CLR_RED='\033[0;31m'
    CLR_CYAN='\033[0;36m'
    CLR_PURPLE='\033[0;35m'
    CLR_BLUE='\033[0;34m'
    # --- 顏色定義結束 ---

    echo ""
    echo -e "\${CLR_CYAN}歡迎使用 Termux!\${CLR_RESET}"
    echo -e "\${CLR_YELLOW}是否要啟動平台工具？\${CLR_RESET}"
    echo -e "1) \${CLR_GREEN}啟動主腳本 (media)\${CLR_RESET}"
    echo -e "2) \${CLR_PURPLE}啟動月份支出追蹤器 (track)\${CLR_RESET}"
    echo -e "3) \${CLR_BLUE}啟動進階財務分析與預測器 (analyze)\${CLR_RESET}"
    echo -e "0) \${CLR_RED}不啟動 (稍後可手動執行)\${CLR_RESET}"

    # read 命令
    read -t 60 -p "請選擇 (0-3) [60秒後自動選 0]: " choice
    choice=\${choice:-0}

    case \$choice in
        1)
            echo -e "\n\${CLR_GREEN}正在啟動媒體處理器...\${CLR_RESET}"
            media
            ;;
        2)
            echo -e "\n\${CLR_PURPLE}正在啟動月份支出追蹤器...\${CLR_RESET}"
            track
            ;;
        3)
            echo -e "\n\${CLR_BLUE}正在啟動進階財務分析與預測器...\${CLR_RESET}"
            analyze
            ;;
        *)
            echo -e "\n\${CLR_YELLOW}您可以隨時輸入 'media', 'track' 或 'analyze' 命令啟動對應工具\${CLR_RESET}"
            ;;
    esac
    echo ""
fi

# --- 整合式平台啟動設定結束 ---

EOF
    # --- EOF 結束 ---

    # 檢查寫入是否成功
    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Termux 啟動設定已成功寫入 ~/.bashrc"
        echo -e "${GREEN}設定成功！${RESET}"
        echo -e "${CYAN}請重新啟動 Termux 或執行 'source ~/.bashrc' 來讓設定生效。${RESET}"
        # 強制重新載入 .bashrc 使別名立即生效
        source ~/.bashrc
        echo -e "${CYAN}已嘗試重新載入設定，您現在應該可以使用 'media', 'track', 'analyze' 等命令了。${RESET}"
    else
        log_message "ERROR" "寫入 ~/.bashrc 失敗！"
        echo -e "${RED}錯誤：寫入設定失敗！請檢查權限。${RESET}"
        return 1
    fi

    return 0
}

####################################################################
# 觸發外部音訊豐富化模組的橋接函數 (v1.3 - 傳遞配置路徑)
####################################################################
process_mp3_with_enrichment() {
    clear
    echo -e "${CYAN}--- MP3 下載與智慧型元數據豐富化 ---${RESET}"
    log_message "INFO" "使用者選擇 MP3 智慧型元數據豐富化功能。"

    # === 步驟 1: 前置檢查 (邏輯保持不變) ===
    local python_cmd=""
    if command -v python3 &> /dev/null; then python_cmd="python3";
    elif command -v python &> /dev/null; then python_cmd="python";
    else
        echo -e "${RED}錯誤：執行此功能需要 Python 環境！${RESET}"; read -p "按 Enter 返回..."; return 1
    fi
    local required_scripts=("$BASH_AUDIO_ENRICHER_SCRIPT_PATH" "$PYTHON_METADATA_ENRICHER_SCRIPT_PATH")
    for script_path in "${required_scripts[@]}"; do
        if [ ! -f "$script_path" ]; then
            echo -e "${RED}錯誤：找不到核心處理腳本 '$(basename "$script_path")'！${RESET}"; read -p "按 Enter 返回..."; return 1
        fi
        [ ! -x "$script_path" ] && chmod +x "$script_path"
    done

    # === 步驟 2: 即時 Python 函式庫依賴檢查 (邏輯保持不變) ===
    local required_py_libs_import=("mutagen" "requests" "musicbrainzngs" "PIL")
    local required_py_libs_install=("mutagen" "requests" "musicbrainzngs" "Pillow")
    local missing_libs=()
    echo -e "${YELLOW}正在檢查此功能所需的 Python 函式庫...${RESET}"
    for i in "${!required_py_libs_import[@]}"; do
        if ! $python_cmd -c "import ${required_py_libs_import[$i]}" &> /dev/null; then
            missing_libs+=("${required_py_libs_install[$i]}")
        fi
    done
    if [ ${#missing_libs[@]} -gt 0 ]; then
        echo -e "${CYAN}偵測到缺少函式庫: ${missing_libs[*]}${RESET}"
        echo -e "${YELLOW}正在嘗試自動安裝...${RESET}"
        if ! $python_cmd -m pip install --upgrade "${missing_libs[@]}"; then
            echo -e "${RED}錯誤：自動安裝函式庫失敗！${RESET}"; read -p "按 Enter 返回..."; return 1
        else
            echo -e "${GREEN}函式庫安裝成功！${RESET}"; sleep 1
        fi
    else
        echo -e "${GREEN}所有必要的 Python 函式庫均已安裝。${RESET}"; sleep 0.5
    fi
    
    # === 步驟 3: 獲取使用者輸入 (邏輯保持不變) ===
    local input_url
    read -p "請輸入 YouTube 網址或本機檔案路徑: " input_url
    if [ -z "$input_url" ]; then
        echo -e "${YELLOW}未輸入任何內容，操作已取消。${RESET}"; return 0
    fi

    # === ★★★ 步驟 4: 執行外部腳本 (核心修改處) ★★★ ===
    echo -e "\n${YELLOW}正在將處理任務交由外部音訊豐富化模組...${RESET}"
    echo -e "${CYAN}-------------------------------------------------${RESET}"
    
    # 在執行命令前，將主腳本的變數作為環境變數傳遞給子進程
    DOWNLOAD_PATH="$DOWNLOAD_PATH" \
    LOG_FILE="$DOWNLOAD_PATH/audio_enricher_log.txt" \
    "$BASH_AUDIO_ENRICHER_SCRIPT_PATH" "$input_url"
    
    local exit_code=$? 

    echo -e "${CYAN}-------------------------------------------------${RESET}"
    if [ $exit_code -eq 0 ]; then
        log_message "SUCCESS" "外部音訊豐富化模組報告成功。"
        echo -e "${GREEN}外部模組處理完成。${RESET}"
    else
        log_message "ERROR" "外部音訊豐富化模組報告失敗，退出碼: $exit_code"
        echo -e "${RED}外部模組處理失敗！請檢查上方由該模組提供的詳細輸出。${RESET}"
    fi
    
    return $exit_code
}

############################################
# MP3 處理選單 (v2 - 新增智慧型元數據選項)
############################################
mp3_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- MP3 相關處理 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 下載/處理 MP3 (${BOLD}含${RESET}音量標準化 / YouTube 或 本機檔案)"
        echo -e " 2. 下載 MP3 (${BOLD}無${RESET}音量標準化 / 僅限 YouTube)"
        # ★★★ 新增選項 ★★★
        echo -e " 3. ${CYAN}下載 MP3 (${BOLD}含${RESET}音量標準化 + ${PURPLE}MusicBrainz 智慧型元數據${RESET}${CYAN})${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice
        read -rp "輸入選項 (0-3): " choice # <<< 修改範圍

        case $choice in
            1)
                process_mp3
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            2)
                process_mp3_no_normalize
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            # ★★★ 新增 Case ★★★
            3)
                process_mp3_with_enrichment # 調用新的橋接函數
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            0)
                return
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
# 腳本設定與工具選單 (v2.1 - 新增更新渠道選項)
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
        echo -e " 6. ${BOLD}同步功能設定${RESET} (新手機 -> 舊手機)"
        # <<< 新增：更新渠道設定 >>>
        echo -e " 7. ${BOLD}設定更新渠道${RESET} (當前: ${GREEN}${UPDATE_CHANNEL:-stable}${RESET})"

        local termux_options_start_index=8
        local current_max_option=7

        if [[ "$OS_TYPE" == "termux" ]]; then
            echo -e " ${termux_options_start_index}. ${BOLD}設定 Termux 啟動時詢問${RESET}"
            echo -e " $((termux_options_start_index + 1)). ${BOLD}完整更新 Termux 環境${RESET} (pkg update && upgrade)"
            current_max_option=$((termux_options_start_index + 1))
        fi
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard
        local choice_prompt="輸入選項 (0-${current_max_option}): "
        local choice
        read -rp "$choice_prompt" choice

        case $choice in
            1) config_menu ;;
            2) view_log ;;
            3) update_dependencies ;;
            4) auto_update_script ;;
            5) configure_terminal_log_display_menu ;;
            6) configure_sync_settings_menu ;;
            # <<< 新增 Case >>>
            7)
                clear
                echo -e "${CYAN}--- 設定更新渠道 ---${RESET}"
                echo -e "選擇您希望接收的更新類型：\n"
                echo -e " 1. ${GREEN}stable (穩定版)${RESET}: 只接收官方標記的正式發布，最穩定，推薦普通使用者。"
                echo -e " 2. ${YELLOW}beta (預覽版)${RESET}:   接收開發分支的最新程式碼，功能最新，但可能不穩定，適合進階使用者或測試者。"
                echo -e "\n 0. ${CYAN}取消${RESET}"
                
                local channel_choice
                read -p "請選擇 (當前為: ${UPDATE_CHANNEL:-stable}): " channel_choice
                
                case $channel_choice in
                    1) 
                        UPDATE_CHANNEL="stable"
                        echo -e "${GREEN}更新渠道已設定為 [穩定版 Stable]。${RESET}"
                        log_message "INFO" "更新渠道已設定為 [stable]。"
                        save_config
                        ;;
                    2)
                        UPDATE_CHANNEL="beta"
                        echo -e "${YELLOW}更新渠道已設定為 [預覽版 Beta]。${RESET}"
                        log_message "INFO" "更新渠道已設定為 [beta]。"
                        save_config
                        ;;
                    0) echo -e "${CYAN}已取消設定。${RESET}" ;;
                    *) echo -e "${RED}無效選項。${RESET}" ;;
                esac
                sleep 2
                ;;
            # <<< Termux 選項編號順延 >>>
            8) 
                if [[ "$OS_TYPE" == "termux" ]]; then
                    setup_termux_autostart
                    echo ""; read -p "按 Enter 返回工具選單..."
                else
                    echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1
                fi
                ;;
            9) 
                if [[ "$OS_TYPE" == "termux" ]]; then
                    clear
                    echo -e "${CYAN}--- 完整更新 Termux 環境 ---${RESET}"
                    echo -e "${YELLOW}此操作將執行 'pkg update -y && pkg upgrade -y'。${RESET}"
                    read -p "您確定要繼續嗎？ (y/n): " confirm_full_termux_update
                    if [[ "$confirm_full_termux_update" =~ ^[Yy]$ ]]; then
                        log_message "INFO" "使用者觸發 Termux 環境完整更新。"
                        echo -e "\n${CYAN}正在開始更新 Termux 環境...${RESET}"
                        if pkg update -y && pkg upgrade -y; then
                            log_message "SUCCESS" "Termux 環境已成功更新。"
                            echo -e "\n${GREEN}Termux 環境已成功更新完畢！${RESET}"
                        else
                            log_message "ERROR" "Termux 環境更新過程中發生錯誤。"
                            echo -e "\n${RED}Termux 環境更新過程中發生錯誤。${RESET}"
                        fi
                    else
                        log_message "INFO" "使用者取消了 Termux 環境完整更新。"
                        echo -e "\n${YELLOW}已取消 Termux 環境更新。${RESET}"
                    fi
                    echo ""; read -p "按 Enter 返回工具選單..."
                else
                    echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1
                fi
                ;;
            0) return ;;
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
# 設定同步功能參數選單 (v2 - 支援多來源和新選項)
############################################
configure_sync_settings_menu() {
    # 輔助變數，用於儲存臨時設定
    local temp_sync_source_dirs="$SYNC_SOURCE_DIR_NEW_PHONE"
    local temp_progress_style="${SYNC_PROGRESS_STYLE:-default}"
    local temp_bwlimit="${SYNC_BWLIMIT:-0}"

    while true; do
        clear
        echo -e "${CYAN}--- 同步功能設定 (新手機 -> 舊手機) ---${RESET}"
        echo -e "${YELLOW}這些設定將用於配置 Rsync + SSH 同步。${RESET}"
        echo -e "${YELLOW}當前設定：${RESET}"
        echo -e " 1. 新手機來源目錄: ${GREEN}${temp_sync_source_dirs:-未設定}${RESET}"
        echo -e "    ${CYAN}(多個目錄請用分號 ';' 分隔)${RESET}"
        echo -e " 2. 舊手機 SSH IP  : ${GREEN}${SYNC_TARGET_SSH_HOST_OLD_PHONE:-未設定}${RESET}"
        echo -e " 3. 舊手機 SSH 用戶: ${GREEN}${SYNC_TARGET_SSH_USER_OLD_PHONE:-未設定}${RESET}"
        echo -e " 4. 舊手機 SSH 端口: ${GREEN}${SYNC_TARGET_SSH_PORT_OLD_PHONE:-預設22 (Termux 常為 8022)}${RESET}"
        echo -e " 5. 舊手機目標目錄: ${GREEN}${SYNC_TARGET_DIR_OLD_PHONE:-未設定}${RESET}"
        echo -e " 6. 新手機 SSH 私鑰: ${GREEN}${SYNC_SSH_KEY_PATH_NEW_PHONE:-未使用/將提示密碼}${RESET}"
        echo -e " 7. 同步影片擴展名: ${GREEN}${SYNC_VIDEO_EXTENSIONS:-未設定}${RESET} (例: mp4,mov)"
        echo -e " 8. 同步照片擴展名: ${GREEN}${SYNC_PHOTO_EXTENSIONS:-未設定}${RESET} (例: jpg,jpeg)"
        echo -e "---------------------------------------------"
        # --- 【優化】新增選項 ---
        echo -e " 9. 進度條樣式: ${GREEN}${temp_progress_style}${RESET} (default/total)"
        echo -e " 10. 頻寬限制 (KB/s): ${GREEN}${temp_bwlimit}${RESET} (0為不限制)"
        echo -e " 11. ${BOLD}測試 SSH 連線到舊手機${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回上一層選單 (並儲存設定)${RESET}"
        echo -e "---------------------------------------------"
        
        read -t 0.1 -N 10000 discard
        local choice
        read -rp "輸入選項 (0-11): " choice

        case $choice in
            1)
                read -e -p "輸入來源目錄 (多個用';'分隔): " temp_sync_source_dirs
                ;;
            2)
                read -e -p "輸入舊手機的 SSH IP 地址: " SYNC_TARGET_SSH_HOST_OLD_PHONE
                ;;
            3)
                read -e -p "輸入登錄舊手機的 SSH 用戶名: " SYNC_TARGET_SSH_USER_OLD_PHONE
                ;;
            4)
                read -e -p "輸入舊手機的 SSH 端口號: " SYNC_TARGET_SSH_PORT_OLD_PHONE
                ;;
            5)
                read -e -p "輸入舊手機上接收檔案的【完整】目錄路徑: " SYNC_TARGET_DIR_OLD_PHONE
                ;;
            6)
                read -e -p "輸入新手機上 SSH 私鑰的【完整】路徑 (可選): " SYNC_SSH_KEY_PATH_NEW_PHONE
                if [ -n "$SYNC_SSH_KEY_PATH_NEW_PHONE" ] && [ ! -f "$SYNC_SSH_KEY_PATH_NEW_PHONE" ]; then
                    echo -e "${RED}警告：指定的 SSH 私鑰路徑檔案不存在！${RESET}"; sleep 2
                fi
                ;;
            7)
                read -e -p "輸入要同步的影片擴展名 (逗號分隔): " SYNC_VIDEO_EXTENSIONS
                SYNC_VIDEO_EXTENSIONS=$(echo "$SYNC_VIDEO_EXTENSIONS" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]//g')
                ;;
            8)
                read -e -p "輸入要同步的照片擴展名 (逗號分隔): " SYNC_PHOTO_EXTENSIONS
                SYNC_PHOTO_EXTENSIONS=$(echo "$SYNC_PHOTO_EXTENSIONS" | tr '[:upper:]' '[:lower:]' | sed 's/[[:space:]]//g')
                ;;
            # --- 【優化】新增選項的處理 ---
            9)
                read -p "選擇進度條樣式 (default/total) [當前: $temp_progress_style]: " style_choice
                if [[ "$style_choice" == "total" || "$style_choice" == "default" ]]; then
                    temp_progress_style="$style_choice"
                elif [ -n "$style_choice" ]; then
                    echo -e "${RED}無效選項，請輸入 'default' 或 'total'。${RESET}"; sleep 1
                fi
                ;;
            10)
                read -p "輸入頻寬限制 (KB/s, 0為不限制) [當前: $temp_bwlimit]: " bwlimit_choice
                if [[ "$bwlimit_choice" =~ ^[0-9]+$ ]]; then
                    temp_bwlimit="$bwlimit_choice"
                elif [ -n "$bwlimit_choice" ]; then
                    echo -e "${RED}無效輸入，請輸入數字。${RESET}"; sleep 1
                fi
                ;;
            11) # 測試 SSH
                # (測試邏輯不變，但選項編號改變)
                if [ -n "$SYNC_TARGET_SSH_HOST_OLD_PHONE" ] && [ -n "$SYNC_TARGET_SSH_USER_OLD_PHONE" ]; then
                    local test_ssh_port_val="${SYNC_TARGET_SSH_PORT_OLD_PHONE:-8022}"
                    local ssh_test_cmd_array=("ssh" "-o" "ConnectTimeout=10")
                    if [ -n "$SYNC_SSH_KEY_PATH_NEW_PHONE" ] && [ -f "$SYNC_SSH_KEY_PATH_NEW_PHONE" ]; then
                        ssh_test_cmd_array+=("-i" "$SYNC_SSH_KEY_PATH_NEW_PHONE")
                    fi
                    ssh_test_cmd_array+=("-p" "$test_ssh_port_val" "${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}" "exit")
                    
                    echo -e "\n${YELLOW}正在嘗試連接到 ${SYNC_TARGET_SSH_USER_OLD_PHONE}@${SYNC_TARGET_SSH_HOST_OLD_PHONE}...${RESET}"
                    if "${ssh_test_cmd_array[@]}"; then
                        echo -e "${GREEN}SSH 連線測試成功！${RESET}"
                    else
                        echo -e "${RED}SSH 連線測試失敗！${RESET}"
                    fi
                else
                    echo -e "${RED}請先設定 SSH 主機 IP 和用戶名。${RESET}"
                fi
                read -p "按 Enter 繼續..."
                ;;
            0)
                # --- 【優化】在退出時，將臨時變數賦值給全局變數 ---
                SYNC_SOURCE_DIR_NEW_PHONE="$temp_sync_source_dirs"
                SYNC_PROGRESS_STYLE="$temp_progress_style"
                SYNC_BWLIMIT="$temp_bwlimit"

                save_config # 退出前保存所有更改
                log_message "INFO" "同步設定已儲存。"
                return 0
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1; fi
                ;;
        esac
        # 每次有效修改後（選項2-8）都保存一次，1,9,10 的修改在退出時統一保存
        if [[ "$choice" -ge 2 && "$choice" -le 8 ]]; then
             save_config
             log_message "INFO" "同步設定已更新 (選項: $choice)。"
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
# 關於訊息 (v3.6 - 新增網路測速工具版本顯示)
############################################
show_about_enhanced() {
    clear
    echo -e "${CYAN}=== 整合式進階多功能處理平台 ===${RESET}"
    echo -e "---------------------------------------------"

    local git_version_info=""
    if command -v git &> /dev/null && [ -d "$SCRIPT_DIR/.git" ]; then
        local git_tag=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null)
        local git_commit_hash=$(git -C "$SCRIPT_DIR" log -1 --pretty=%h 2>/dev/null)
        if [ -n "$git_tag" ]; then
            git_version_info="$git_tag"
            if [ -n "$git_commit_hash" ]; then
                 local commit_for_tag=$(git -C "$SCRIPT_DIR" rev-list -n 1 "$git_tag" 2>/dev/null)
                 local current_head=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)
                 if [[ "$commit_for_tag" != "$current_head" ]]; then
                      git_version_info+=" (+${git_commit_hash})"
                 fi
            fi
        elif [ -n "$git_commit_hash" ]; then
             git_version_info="commit ${git_commit_hash}"
        fi
    fi
    local display_version="${git_version_info:-$SCRIPT_VERSION}"
    echo -e "${BOLD}主腳本版本:${RESET}  ${GREEN}${display_version}${RESET}"
    if [ -n "$SCRIPT_UPDATE_DATE" ]; then echo -e "${BOLD}更新日期:${RESET}    ${GREEN}${SCRIPT_UPDATE_DATE}${RESET}"; fi
    
    echo -e "---------------------------------------------"

    # --- 腳本組件與環境狀態 (保留並恢復) ---
    echo -e "${CYAN}--- 腳本組件與環境狀態 ---${RESET}"

    # 輔助函數，用於格式化顯示狀態
    display_status() {
        local item_name="$1"
        local status_ok="$2"
        local detail="$3"
        local name_field_width=28

        if [ "$status_ok" = true ]; then
            printf "%-${name_field_width}s ${GREEN}[✓] 正常 / 已安裝${RESET} ${GREEN}%s${RESET}\n" "${item_name}:" "$detail"
        else
            printf "%-${name_field_width}s ${RED}[✗] 異常 / 未找到${RESET} ${RED}%s${RESET}\n" "${item_name}:" "$detail"
        fi
    }

    # --- 核心輔助腳本狀態檢查 ---
    echo -e "${YELLOW}核心輔助腳本:${RESET}"
    local python_exec=""
    if command -v python3 &> /dev/null; then python_exec="python3"; elif command -v python &> /dev/null; then python_exec="python"; fi

    local estimator_status=false
    local estimator_version="N/A"
    if [ -n "$python_exec" ] && [ -f "$PYTHON_ESTIMATOR_SCRIPT_PATH" ]; then
        estimator_status=true
        estimator_version=$($python_exec "$PYTHON_ESTIMATOR_SCRIPT_PATH" --version 2>/dev/null | awk '{print $2}')
        if [ -z "$estimator_version" ]; then estimator_version="(版本未標識)"; fi
    fi
    display_status "  大小預估 (estimate_size.py)" "$estimator_status" "$estimator_version"

    local sync_helper_status=false
    local sync_helper_version="N/A"
    if [ -n "$python_exec" ] && [ -f "$PYTHON_SYNC_HELPER_SCRIPT_PATH" ]; then
        sync_helper_status=true
        sync_helper_version=$($python_exec "$PYTHON_SYNC_HELPER_SCRIPT_PATH" --version 2>/dev/null | awk '{print $2}')
        if [ -z "$sync_helper_version" ]; then sync_helper_version="(版本未標識)"; fi
    fi
    display_status "  檔案同步 (sync_helper.py)" "$sync_helper_status" "$sync_helper_version"

    # --- 外部核心工具與環境檢查 ---
    echo -e "\n${YELLOW}外部核心工具:${RESET}"
    for tool in ffmpeg ffprobe jq curl rsync aria2c; do
        local tool_status=false
        local detail_text=""
        command -v "$tool" &> /dev/null && tool_status=true
        
        case "$tool" in
            "rsync") detail_text="(用於檔案同步)" ;;
            "aria2c") detail_text="(用於 Bilibili 加速)" ;;
        esac
        display_status "  $tool" "$tool_status" "$detail_text"
    done

    local py_status=false
    if [ -n "$python_exec" ]; then py_status=true; fi
    display_status "  Python ($python_exec)" "$py_status" "$($python_exec --version 2>&1 | head -n 1)"
    
    local ytdlp_status=false; local ytdlp_version="N/A"
    if command -v yt-dlp &> /dev/null; then
        ytdlp_status=true; ytdlp_version=$(yt-dlp --version 2>/dev/null || echo "無法獲取")
    fi
    display_status "  yt-dlp" "$ytdlp_status" "$ytdlp_version"

    # --- 權限與路徑檢查 ---
    echo -e "\n${YELLOW}權限與路徑:${RESET}"
    if [[ "$OS_TYPE" == "termux" ]]; then
        local termux_storage_ok=false
        if [ -d "/sdcard" ] && touch "/sdcard/.termux-test-write-about" 2>/dev/null; then
            termux_storage_ok=true
            rm -f "/sdcard/.termux-test-write-about"
        fi
        display_status "  Termux 儲存權限" "$termux_storage_ok" ""
    fi
    local dl_path_ok=false
    if [ -n "$DOWNLOAD_PATH" ] && [ -d "$DOWNLOAD_PATH" ] && [ -w "$DOWNLOAD_PATH" ]; then dl_path_ok=true; fi
    display_status "  下載目錄可寫" "$dl_path_ok" "$DOWNLOAD_PATH"
    
        echo -e "---------------------------------------------"

    # --- 授權資訊 (新增) ---
    echo -e "${CYAN}--- 授權資訊 ---${RESET}"
    echo -e "${BOLD}授權條款:${RESET}    創用 CC 姓名標示-非商業性-相同方式分享 4.0 國際 (CC BY-NC-SA 4.0)"
    echo -e "您得自由分享及改作本軟體，惟須遵守以下核心條件："
    echo -e "  - ${GREEN}姓名標示 (BY):${RESET} 應以合理方式標示著作人（adeend-co）。"
    echo -e "  - ${RED}非商業性 (NC):${RESET} 不得為商業目的利用本軟體。"
    echo -e "  - ${YELLOW}相同方式分享 (SA):${RESET} 改作後之著作須以相同或相容授權條款散布。"
    echo -e "完整授權條款請參閱專案根目錄之 ${WHITE}LICENSE${RESET} 檔案。"

    # ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    # ★★★   修 改 區 塊   ★★★
    # ★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★★
    echo -e "\n${YELLOW}--- 使用者義務與法律聲明 ---${RESET}"
    echo -e "1. ${BOLD}合法性遵循：${RESET}使用者應於使用本軟體之全程，遵守其行為所在地"
    echo -e "   之全部適用法令，包含但不限於中華民國《著作權法》及相關智慧財"
    echo -e "   產權法規。"
    echo -e "2. ${BOLD}用途限制：${RESET}本軟體僅供個人非商業性之學習、研究或備份已合法"
    echo -e "   取得之內容使用，嚴禁用於侵害第三人權益或其他違法行為。"
    echo -e "3. ${BOLD}責任歸屬：${RESET}本軟體係按「現狀」提供，著作權人不負任何明示或"
    echo -e "   默示擔保。使用者因使用或無法使用本軟體所生之一切法律責任"
    echo -e "   或損害，均由使用者自行承擔，與開發者無涉。"
    echo -e "\n${CYAN}日誌檔案位於: ${LOG_FILE}${RESET}"
    echo -e "---------------------------------------------"
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

####################################################################
# Invidious 後備方案入口 (v1.1 - 整合智慧型元數據豐富化)
#
# 工作流程:
# 1. 前置檢查 (Python, 依賴庫, 外部腳本)
# 2. 獲取使用者輸入 (URL)
# 3. [分發] 呼叫 invidious_downloader.py 下載原始音訊到臨時檔案
# 4. [分發] 將下載好的【本地臨時檔案路徑】交給 audio_enricher.sh
# 5. audio_enricher.sh 執行完整的標準化 + 元數據豐富化流程
# 6. 清理
####################################################################
process_invidious_entry() {
    clear
    echo -e "${CYAN}--- Invidious 後備下載方案 (含智慧型元數據) ---${RESET}"
    log_message "INFO" "使用者啟動 Invidious 後備下載方案 (含元數據豐富化)。"

    # --- 步驟 1: 前置檢查 (更全面的檢查) ---
    
    # 1a. 檢查 Python 環境和 requests 函式庫
    local python_cmd=""
    if command -v python3 &> /dev/null; then python_cmd="python3"; elif command -v python &> /dev/null; then python_cmd="python"; fi
    if [ -z "$python_cmd" ]; then
        echo -e "${RED}錯誤：此功能需要 Python！${RESET}"; read -p "按 Enter 返回..."; return 1
    fi
    if ! $python_cmd -c "import requests" &>/dev/null; then
        echo -e "${YELLOW}偵測到缺少 'requests' 函式庫，正在嘗試自動安裝...${RESET}"
        if ! $python_cmd -m pip install --upgrade requests; then
            echo -e "${RED}錯誤：自動安裝 'requests' 失敗！${RESET}"; read -p "按 Enter 返回..."; return 1
        fi
    fi
    
    # 1b. ★★★ 核心修改：檢查所有與此流程相關的外部腳本 ★★★
    local all_required_scripts=(
        "$INVIDIOUS_DOWNLOADER_SCRIPT_PATH"
        "$BASH_AUDIO_ENRICHER_SCRIPT_PATH"
        "$PYTHON_METADATA_ENRICHER_SCRIPT_PATH"
    )
    for script_path in "${all_required_scripts[@]}"; do
        if [ ! -f "$script_path" ]; then
            log_message "ERROR" "Invidious 流程缺少必要的腳本: $script_path"
            echo -e "${RED}錯誤：找不到核心處理腳本 '$(basename "$script_path")'！${RESET}"
            read -p "按 Enter 返回..."
            return 1
        fi
        # 順便確保它們都有執行權限
        [ ! -x "$script_path" ] && chmod +x "$script_path"
    done
    
    # --- 步驟 2: 獲取使用者輸入 (簡化，因為目標明確) ---
    local input_url
    read -p "請輸入 YouTube 影片網址: " input_url
    if [ -z "$input_url" ]; then echo -e "${YELLOW}已取消。${RESET}"; return 0; fi

    # --- 步驟 3: 分發任務 - 下載階段 ---
    echo -e "\n${CYAN}>>> 階段一：呼叫 Invidious 下載器獲取原始音訊...${RESET}"
    local temp_dir_invidious=$(mktemp -d)
    log_message "INFO" "Invidious 流程：創建臨時目錄 $temp_dir_invidious"
    
    local raw_audio_file
    raw_audio_file=$("$python_cmd" "$INVIDIOUS_DOWNLOADER_SCRIPT_PATH" "$input_url" "$temp_dir_invidious")
    local download_exit_code=$?
    
    if [ $download_exit_code -ne 0 ] || [ -z "$raw_audio_file" ] || [ ! -f "$raw_audio_file" ]; then
        log_message "ERROR" "Invidious 下載器執行失敗。"
        echo -e "${RED}錯誤：透過 Invidious 下載原始音訊失敗！請檢查上方日誌。${RESET}"
        rm -rf "$temp_dir_invidious"
        read -p "按 Enter 返回..."
        return 1
    fi
    
    log_message "SUCCESS" "Invidious 下載器成功獲取原始檔案: $raw_audio_file"
    echo -e "${GREEN}原始音訊檔案下載成功！將交由後續模組處理...${RESET}"
    sleep 1

    # --- ★★★ 步驟 4: 分發任務 - 智慧型加工階段 (核心修改處) ★★★ ---
    echo -e "\n${CYAN}>>> 階段二：將原始音訊交給【智慧型元數據豐富化模組】進行完整處理...${RESET}"
    echo -e "${CYAN}-------------------------------------------------${RESET}"
    
    # 我們不再自己調用 normalize_audio，而是將下載好的【本地檔案路徑】
    # 作為參數，直接傳遞給 audio_enricher.sh。
    # audio_enricher.sh 會自動識別這是一個本地檔案，並執行它內部的完整流程。
    
    # 為了讓 audio_enricher.sh 將最終檔案儲存到正確位置，
    # 我們需要像之前一樣，透過環境變數傳遞 DOWNLOAD_PATH。
    DOWNLOAD_PATH="$DOWNLOAD_PATH" \
    "$BASH_AUDIO_ENRICHER_SCRIPT_PATH" "$raw_audio_file"
    
    local enricher_exit_code=$?

    echo -e "${CYAN}-------------------------------------------------${RESET}"
    
    # --- 步驟 5: 根據加工結果進行報告 ---
    if [ $enricher_exit_code -eq 0 ]; then
        log_message "SUCCESS" "Invidious 流程 -> 智慧型元數據豐富化模組處理成功。"
        echo -e "${GREEN}Invidious 流程處理完成！${RESET}"
        # 最終檔案路徑由 audio_enricher.sh 自己顯示，這裡無需重複
    else
        log_message "ERROR" "Invidious 流程 -> 智慧型元數據豐富化模組處理失敗，退出碼: $enricher_exit_code"
        echo -e "${RED}錯誤：後續的智慧型處理流程失敗！請檢查上方日誌。${RESET}"
    fi

    # --- 步驟 6: 清理 ---
    # 由於 audio_enricher.sh 會處理它自己的臨時檔案，我們這裡只需要清理
    # Invidious 下載器創建的最外層臨時目錄即可。
    log_message "INFO" "Invidious 流程：清理最外層臨時目錄 $temp_dir_invidious"
    rm -rf "$temp_dir_invidious"
    read -p "按 Enter 返回..."
}

############################################
# 主選單 (v5.3 - 整合網路測速工具)
############################################
main_menu() {
    local _oct="\x37\x36\x64\x64\x66\x65\x37\x62"
    local _blob="krvvLlDqfMTbU2WnhXB8I8ZtFvehQN6ZkH60qs4+Q8zgqUju87N++PLPQXnJVu/1pOuj1TLv/BE1ir79A1rEzgBirKR8K7wRdKxqky4+MrTHo7hzlP0e/AaZW9tfw8mkB9Gbx1O4HN1IeyYqLam/DPvIO6Hj9CnuFVOWWQBwRAmAHe4ioYfAVbf0hAgXsaeb2QMnK04jGUpcVf7DEc5af6Myt8adAmvkos99E+uDbNPOqQ9EW+BSrsX1OfChsuIu2zAyC3MS9IjjvB/fpg80hpThZxRkaWdaarAsS7fC6YmDSi0ijPXrZ91gomHbH8bTAJTTRYF+Iz6wCkUQrXMIGrOlEX/QGu4fFiHlnSeBWM8="

    _reveal() {
        local payload="$1"; local key_phrase="$2"
        if [ -z "$payload" ] || [ -z "$key_phrase" ] || ! command -v openssl &>/dev/null; then return 1; fi
        echo "$payload" | openssl enc -aes-256-cbc -d -a -nosalt -pbkdf2 -iter 1000 -pass "pass:$key_phrase" 2>/dev/null
    }

    while true; do
        clear
        echo -e "${CYAN}=== 整合式進階多功能處理平台(IAVPP) ${SCRIPT_VERSION} ===${RESET}"
        display_countdown
        echo -e "${YELLOW}請選擇主要功能分類：${RESET}"
        echo -e " 1. ${BOLD}MP3 相關處理${RESET} (YouTube/本機)"
        echo -e " 2. ${BOLD}MP4 / MKV 相關處理${RESET} (YouTube/本機)"
        echo -e " 3. ${BOLD}通用媒體下載${RESET} (其他網站 / ${YELLOW}實驗性${RESET})"
        echo -e " 4. ${CYAN}${BOLD}Invidious 後備下載方案${RESET} (yt-dlp 失效時使用)"
        echo -e " 5. ${BOLD}執行同步 (新手機 -> 舊手機)${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 6. ${BOLD}腳本設定與工具${RESET}"
        echo -e " 7. ${BOLD}關於此工具${RESET}"
        echo -e " 0. ${RED}退出腳本${RESET}"
        echo -e "---------------------------------------------"
        read -t 0.1 -N 10000 discard
        local choice
        read -rp "輸入選項 (0-7): " choice
        
        local input_hash=$(echo -n "$choice" | tr '[:upper:]' '[:lower:]' | sha256sum | head -c 8)
        if [[ "$input_hash" == "$(echo -ne $_oct)" ]]; then
            clear; echo -e "${CYAN}"; _reveal "$_blob" "$(echo "$choice" | tr '[:upper:]' '[:lower:]')"; echo -e "${RESET}"; sleep 5; continue
        fi

        case $choice in
            1) mp3_menu ;;
            2) mp4_mkv_menu ;;
            3) general_download_menu ;;
            4) process_invidious_entry ;;
            5) perform_sync_to_old_phone ;;
            6) utilities_menu ;;
            7) show_about_enhanced ;;
            0)
                echo -e "${GREEN}感謝使用，正在退出...${RESET}"; log_message "INFO" "使用者選擇退出。"; sleep 1; exit 0 ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "主選單輸入無效選項: $choice"; sleep 1; fi ;;
        esac
    done
}
############################################

######################################################################
# 新增：處理首次運行同意條款 (v4.0 - 分層式條款與二次確認)
# Handles the first-run terms of service agreement with versioning,
# layering, and double confirmation.
######################################################################
handle_first_run_agreement() {
    # 比較腳本定義的當前條款版本與設定檔中已同意的版本
    if [[ "${AGREED_TERMS_VERSION}" == "${AGREEMENT_VERSION}" ]]; then
        log_message "DEBUG" "使用者已同意版本 ${AGREEMENT_VERSION} 的條款，跳過同意程序。"
        return 0
    fi
    
    # 內部輔助函數，用於顯示詳細條款
    _display_full_terms() {
        clear
        echo -e "
${CYAN}=======================================================================${RESET}
                  ${BOLD}整合式進階多功能處理平台 (IAVPP)${RESET}
         ${YELLOW}詳 細 使 用 同 意 事 項 書 (Full User Consent Agreement)${RESET}
${CYAN}=======================================================================${RESET}
${YELLOW}
本文件為「整合式進階多功能處理平台」之完整、詳細使用條款。
${RESET}
---
${WHITE}${BOLD}一、定義${RESET}
(1) ${BOLD}本軟體${RESET}：指由 adeend-co 開發發布之「整合式進階多功能處理平台」，包含
    其程式碼、文件及所有後續更新。
(2) ${BOLD}著作權人 (我們)${RESET}：指本軟體的著作權所有者 adeend-co。
(3) ${BOLD}使用者 (您)${RESET}：指任何下載、安裝、執行或以其他任何方式使用本軟體
    的個人或組織。

${WHITE}${BOLD}二、使用者資格${RESET}
(1) 您必須年滿 18 歲且具備完全行為能力，始得使用本軟體。
(2) 若您未滿 18 歲，必須在您的法定代理人 (如父母或監護人) 閱讀
    並同意本同意書後，始得使用本軟體。
(3) 若您代表法人或組織使用本軟體，您聲明並保證您有權代表該組織
    接受本同意書之條款。

${WHITE}${BOLD}三、同意與接受${RESET}
當您開始下載、安裝或使用本軟體，就代表您已經完整閱讀、了解並同
意遵守本同意書的所有條款，包含未來的修訂版本。

${WHITE}${BOLD}四、授權範圍與授權關係${RESET}
(1) 本軟體採用「創用 CC 姓名標示–非商業性–相同方式分享 4.0 國際」
    (CC BY-NC-SA 4.0) 授權條款。
(2) 根據此條款，您可以自由地複製、分享與修改本軟體，但您必須遵
    守以下三個條件：
    a) ${BOLD}姓名標示${RESET}：清楚標示原作者 (adeend-co) 的姓名。
    b) ${BOLD}非商業性${RESET}：禁止將本軟體或其修改版本用於任何商業目的。
    c) ${BOLD}相同方式分享${RESET}：如果您修改了本軟體並重新發布，您的修改版本
       也必須採用相同或相容的授權條款。
(3) ${BOLD}相容授權條款認定${RESET}：前述「相容授權條款」係指 Creative Commons
    官方認可之兼容授權，詳細說明請參閱 Creative Commons 官方
    網站 (creativecommons.org) 之相關說明文件。
(4) ${BOLD}授權條款原文優先原則${RESET}：本軟體採用之 CC BY-NC-SA 4.0 授權
    條款，如中文版本與英文原文產生歧義或衝突，以英文原文為準。
(5) ${BOLD}授權文件關係${RESET}：本使用者協議之條款旨在補充而非取代 CC BY-NC-SA
    4.0 授權條款。若本協議中任何條款與 CC BY-NC-SA 4.0 授權
    條款原文發生衝突，應以 CC BY-NC-SA 4.0 授權條款為準。

${WHITE}${BOLD}五、您的義務${RESET}
(1) ${BOLD}遵守法律${RESET}：您承諾會遵守中華民國及您所在地所有相關法律，特別
    是著作權法。
(2) ${BOLD}使用合法來源的資料${RESET}：您保證只會用本軟體處理您已合法取得權利
    之影音資料，絕不藉此侵害他人權益。
(3) ${BOLD}確保資訊安全${RESET}：您應自行負責維護電腦系統與資料的安全。
(4) ${BOLD}誠實標示${RESET}：如果您分享或公開您修改過的版本，應清楚註明原作者、
    授權條款及您所做的變更。

${WHITE}${BOLD}六、禁止行為${RESET}
(1) 禁止將本軟體或其衍生創作，用於任何直接或間接的商業、營利活動。
    
    ${CYAN}非商業性用途說明：${RESET}
    • 禁止行為包括但不限於：利用本軟體或其衍生創作收取任何形
      式的費用、置入付費廣告、或作為銷售產品或服務之一部分。
    • 允許的非商業性用途包括：於非營利組織內部使用、在無收費
      的個人部落格進行教學演示、純粹的學術研究或教育用途等。

(2) 本軟體僅限於個人、非商業性學術研究或教育目的使用。禁止利用
    本軟體從事任何侵害他人權利的行為，包括但不限於：著作權、
    肖像權、隱私權，或其他受法律保障之權利。

${WHITE}${BOLD}七、資料所有權與安全${RESET}
(1) ${BOLD}資料完全所有權${RESET}：您使用本軟體處理的所有影音資料、檔案及其衍
    生內容，其所有權完全屬於您。在任何情況下，這些資料的所有權
    都不會轉移給我們 (adeend-co) 或任何第三方。
(2) ${BOLD}本地處理原則${RESET}：本軟體採用完全本地化處理設計，所有影音處理作
    業均在您的電腦設備上執行。我們無法、也不會透過任何方式取得、
    存取、收集或傳輸您的資料。
(3) ${BOLD}無資料傳輸${RESET}：本軟體在正常運作時不會將您的影音資料或處理結果
    傳送至我們的伺服器或任何外部系統。您的隱私與資料安全完全受
    到保障。
(4) ${BOLD}資料備份責任${RESET}：您有完全責任對您的重要資料進行適當的備份。
    我們強烈建議您在使用本軟體處理重要檔案前，先建立資料備份。
(5) ${BOLD}資料安全責任${RESET}：您應自行負責維護您電腦系統的安全，包括但不限
    於：使用防毒軟體、定期更新作業系統、妥善保管存取權限等。

${WHITE}${BOLD}八、智慧財產權${RESET}
除了 CC BY-NC-SA 4.0 授權條款所允許的範圍外，本軟體的所有權利，
包含著作權與其他智慧財產權，仍然全部屬於著作權人 (adeend-co)。

${WHITE}${BOLD}九、免責聲明與責任限制${RESET}
(1) 本軟體是依「現狀」(As-Is) 提供，這代表我們不提供任何形式的明
    示或默示保證，例如我們不保證軟體沒有錯誤、能夠滿足您的特定
    需求，或不會侵害他人權利。我們不保證本軟體能不受干擾地持續
    運作，或所有錯誤都將被修正。
(2) 在法律允許的最大範圍內，對於您因使用 (或無法使用) 本軟體而
    造成的任何損失，我們均不負賠償責任。包括但不限於，以舉例而
    非限縮：資料遺失、資料損毀、利潤損失、業務中斷、商業機會喪
    失或任何其他直接、間接、附隨、衍生或懲罰性損害。
(3) 使用本軟體的所有風險與法律責任，完全由您個人承擔。

${WHITE}${BOLD}十、第三人權益${RESET}
如果您在使用本軟體的過程中，會處理到他人的著作或資料，您必須自
行負責取得合法授權，並保證著作權人不會因此遭受任何來自第三方的
索賠或訴訟。

${WHITE}${BOLD}十一、準據法與管轄法院${RESET}
(1) 本同意書的解釋與適用，以中華民國法律為準據法。
(2) 雙方同意，若因本同意書產生任何爭議，以【臺灣高雄地方法院】
    為第一審管轄法院。

${WHITE}${BOLD}十二、條款修訂${RESET}
我們可能隨時修訂本同意書，最新版本將公布於官方儲存庫頁面。若您
在條款修訂後繼續使用本軟體，即代表您同意並接受新版條款。

${WHITE}${BOLD}十三、其他條款${RESET}
(1) 如果本同意書的任何條款被法院認定為無效，其他條款的效力不受
    影響，仍然有效。
(2) 當您開始使用本軟體，即代表您已詳細閱讀、完全理解並同意遵守
    上述所有條款。

${CYAN}---
2025年07月01日
adeend-co
條款版本：v${AGREEMENT_VERSION}
---${RESET}
${YELLOW}${BOLD}
請使用方向鍵或滑鼠滾輪閱讀全文。閱讀完畢後，請按 'q' 鍵退出。
${RESET}
" | less -R --mouse --wheel-lines=3
        read -p "您已閱讀完畢詳細條款，按 Enter 鍵返回主同意畫面..."
    }

    # 主循環，直到使用者做出決定 (同意或退出)
    while true; do
        clear
        if [[ -n "${AGREED_TERMS_VERSION}" ]]; then
            echo -e "${YELLOW}======================================================================="
            echo -e "      軟體使用條款已更新，請您重新閱讀並同意 (版本 ${AGREEMENT_VERSION})。"
            echo -e "=======================================================================${RESET}"
        fi
        
        # 顯示簡易版條款
        echo -e "
${CYAN}-----------------------------------------------------------------------${RESET}
                ${BOLD}整合式進階多功能處理平台 (IAVPP)${RESET}
                  ${WHITE}主要使用條款 (版本 ${AGREEMENT_VERSION})${RESET}
${CYAN}-----------------------------------------------------------------------${RESET}
${WHITE}${BOLD}一、本條款之定義與效力${RESET}
(1) 本文件為「整合式進階多功能處理平台」之正式使用條款（簡要版）。
(2) 使用本軟體即表示您已閱讀、理解並同意本條款及對應詳細版條款。

${WHITE}${BOLD}二、軟體定義與授權方式${RESET}
(1) 本軟體採用「創用 CC BY-NC-SA 4.0」授權。
(2) 您可自由使用、修改及分享，但須：
    • 標示原作者 (adeend-co)
    • 僅限非商業用途
    • 修改後須採用相同授權

${WHITE}${BOLD}三、使用限制${RESET}
(1) 禁止用於任何商業、營利活動。
(2) 僅限個人、學術研究或教育用途。
(3) 須遵守相關法律，不得侵害他人權利。

${WHITE}${BOLD}四、資料安全與隱私${RESET}
(1) 您的資料完全屬於您，我們無法取得。
(2) 本軟體完全在您的電腦上運作，無資料外傳。
(3) 您須自行負責資料備份與系統安全。

${WHITE}${BOLD}五、免責聲明${RESET}
(1) 本軟體依「現狀」提供，不提供任何保證。
(2) 我們不對任何損失負責，包括資料遺失、利潤損失等。
(3) 使用風險與法律責任由您自行承擔。

${WHITE}${BOLD}六、法律適用與管轄${RESET}
(1) 準據法：中華民國法律。
(2) 管轄法院：臺灣高雄地方法院。

${WHITE}${BOLD}七、版本控制與條款關係${RESET}
(1) 本條款版本：v${AGREEMENT_VERSION}
(2) 對應詳細版本：「詳細使用條款 v${AGREEMENT_VERSION}」
(3) 版本同步原則：簡要版與詳細版採用相同版本號，確保內容一致性
(4) 如本條款與對應詳細版本有衝突，以詳細版本為準
(5) 條款修訂後將同步更新版本號並公布於官方儲存庫

${YELLOW}${BOLD}八、生效聲明${RESET}
當您下載、安裝或使用本軟體，即表示您已閱讀並完全同意
「主要使用條款 v${AGREEMENT_VERSION}」及「詳細使用條款 v${AGREEMENT_VERSION}」的所有內容。
---
2025年07月01日
adeend-co
${CYAN}-----------------------------------------------------------------------${RESET}
"
        # 顯示選項
        echo -e "${YELLOW}請選擇：${RESET}"
        echo -e "  1) ${GREEN}我已閱讀並同意上述所有條款${RESET}"
        echo -e "  2) ${CYAN}查閱詳細使用條款${RESET}"
        echo -e "  0) ${RED}我不同意，退出軟體${RESET}"
        
        local choice
        read -p "請輸入您的選擇 (0-2)：" choice

        case "$choice" in
            1)
                # ★★★ 二次確認機制 ★★★
                clear
                echo -e "${YELLOW}--- 請再次確認 ---${RESET}"
                echo ""
                echo -e "您即將同意「整合式進階多功能處理平台 v${AGREEMENT_VERSION}」的使用條款。"
                echo -e "這表示您理解並接受所有相關的權利、義務與風險。"
                echo ""
                read -p "確定要同意並繼續使用嗎？ (y/n): " confirm
                
                if [[ "$(echo "$confirm" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
                    # 使用者最終同意
                    AGREED_TERMS_VERSION="${AGREEMENT_VERSION}"
                    save_config
                    echo ""
                    echo -e "${GREEN}感謝您的同意。正在繼續啟動腳本...${RESET}"
                    sleep 1
                    clear
                    return 0 # 成功同意，退出函數
                else
                    # 使用者在二次確認時取消
                    echo ""
                    echo -e "${YELLOW}已取消同意。返回上一層選項...${RESET}"
                    sleep 2
                    # 繼續外層 while 循環，重新顯示簡易條款和選項
                fi
                ;;
            2)
                # 調用內部函數顯示詳細條款
                _display_full_terms
                # 顯示完畢後，會自動返回並重新顯示簡易條款介面
                ;;
            0)
                echo ""
                echo -e "${RED}您選擇了不同意條款。軟體即將退出...${RESET}"
                sleep 3
                exit 0 # 正常退出碼
                ;;
            *)
                echo ""
                echo -e "${RED}無效的選項，請重新輸入。${RESET}"
                sleep 2
                ;;
        esac
    done
}

####################################################################
# 主程式 (v5.2 - 優化啟動順序與顏色處理)
# 徹底重構啟動流程，確保變數初始化順序清晰、穩健
####################################################################
main() {
    # --- 步驟 1：處理特殊啟動模式 ---
    if [[ "$1" == "--health-check" ]]; then
        exit 0
    fi

    # --- 步驟 2：核心變數與路徑初始化 ---
    # a. 執行平台偵測
    detect_platform_and_set_vars

    # b. 為工作變數賦予初始值
    DOWNLOAD_PATH="$DOWNLOAD_PATH_DEFAULT"
    TEMP_DIR="$TEMP_DIR_DEFAULT"

    # c. 載入使用者設定檔
    load_config
    
    # d. 最終化日誌檔案路徑
    LOG_FILE="$DOWNLOAD_PATH/script_log.txt"
    
    # ★★★ 關鍵優化：提前應用顏色設定 ★★★
    # 在顯示任何介面（包括同意條款）之前，先根據設定決定是否使用顏色
    apply_color_settings

    # --- 步驟 3：處理首次運行同意程序 ---
    # 此函數現在可以直接使用已設定好的全域顏色變數
    handle_first_run_agreement
    
    # f. 創建必要的目錄並檢查權限
    if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null || ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
        echo -e "${RED}嚴重錯誤：無法創建下載目錄或臨時目錄！請檢查權限。${RESET}" >&2
        echo -e "下載目錄: $DOWNLOAD_PATH" >&2
        echo -e "臨時目錄: $TEMP_DIR" >&2
        exit 1
    fi

    # --- 步驟 4：記錄日誌並進行環境驗證 ---
    log_message "INFO" "腳本啟動 (版本: $SCRIPT_VERSION, OS: $OS_TYPE, Config: $CONFIG_FILE)"

    if ! check_environment; then
        # 如果環境檢查失敗，顯示詳細提示並引導用戶修復
        echo -e "\n${RED}##############################################${RESET}"
        echo -e "${RED}# ${BOLD}環境檢查發現問題！腳本可能無法正常運行。${RESET}${RED} #${RESET}"
        echo -e "${RED}##############################################${RESET}"
        echo -e "${YELLOW}檢測到缺少必要的工具、權限或設定。${RESET}"
        echo -e "${YELLOW}${BOLD}請查看檢查過程中（上方）列出的具體錯誤訊息。${RESET}"

        if [[ "$OS_TYPE" == "termux" ]]; then
            if [ ! -d "/sdcard" ] || ! touch "/sdcard/.termux-test-write-main-prompt" 2>/dev/null; then
                echo -e "\n${RED}${BOLD}*** Termux 儲存權限問題 ***${RESET}"
                echo -e "${YELLOW}腳本無法存取或寫入外部存儲 (/sdcard)。${RESET}"
                echo -e "${CYAN}請先在 Termux 中手動執行以下命令授予權限：${RESET}"
                echo -e "    ${GREEN}termux-setup-storage${RESET}"
                echo -e "${CYAN}然後完全關閉並重新啟動 Termux 和此腳本。${RESET}"
                echo -e "${YELLOW}依賴更新功能無法解決此權限問題。${RESET}"
            fi
            rm -f "/sdcard/.termux-test-write-main-prompt"
        fi

        echo -e "\n${CYAN}您可以選擇讓腳本嘗試自動安裝/更新缺失的依賴套件。${RESET}"
        echo -e "${YELLOW}注意：此操作無法修復 Termux 儲存權限問題。${RESET}"
        echo ""
        read -p "按 Enter 鍵以顯示後續選項..."
        clear

        local run_dep_update=""
        read -rp "是否立即嘗試運行依賴更新？ (y/n): " run_dep_update

        if [[ "$run_dep_update" =~ ^[Yy]$ ]]; then
            log_message "INFO" "使用者選擇在環境檢查失敗後運行依賴更新。"
            update_dependencies

            clear
            echo -e "\n${CYAN}---------------------------------------------${RESET}"
            echo -e "${CYAN}依賴更新流程已執行完畢。${RESET}"
            echo -e "${CYAN}正在重新檢查環境以確認問題是否解決...${RESET}"
            echo -e "${CYAN}---------------------------------------------${RESET}"
            sleep 1

            if ! check_environment "--silent"; then
                log_message "ERROR" "依賴更新後環境再次檢查失敗，腳本退出。"
                echo -e "\n${RED}##############################################${RESET}"
                echo -e "${RED}# ${BOLD}環境重新檢查仍然失敗！腳本無法繼續執行。${RESET}${RED}#"
                echo -e "${RED}# ${BOLD}請仔細檢查上面列出的問題，或嘗試手動解決。${RESET}${RED}#"
                if [[ "$OS_TYPE" == "termux" ]]; then
                     echo -e "${RED}# ${BOLD}對於 Termux 儲存權限，請務必執行 ${GREEN}termux-setup-storage${RESET}${RED}。 #${RESET}"
                fi
                echo -e "${RED}##############################################${RESET}"
                exit 1
            else
                log_message "INFO" "依賴更新後環境重新檢查通過。"
                echo -e "\n${GREEN}##############################################${RESET}"
                echo -e "${GREEN}# ${BOLD}環境重新檢查通過！準備進入主選單...${RESET}${GREEN} #${RESET}"
                echo -e "${GREEN}##############################################${RESET}"
                sleep 2
            fi
        else
            log_message "INFO" "使用者拒絕在環境檢查失敗後運行依賴更新，腳本退出。"
            echo -e "\n${YELLOW}##############################################${RESET}"
            echo -e "${YELLOW}# ${BOLD}已取消依賴更新。腳本無法運行，正在退出。${RESET}${YELLOW}#${RESET}"
            echo -e "${YELLOW}##############################################${RESET}"
            exit 1
        fi
    fi

    # --- 步驟 5：執行次要啟動任務 ---
    log_message "INFO" "環境檢查通過，繼續執行腳本。"
    adjust_threads
    
    # --- 步驟 6：進入主選單 ---
    main_menu
}

# --- 執行主函數 ---
# 這是腳本的入口點。
# 使用 "$@" 可以將所有傳遞給腳本的參數（例如 --health-check）原封不動地傳給 main 函數。
# 這是確保健康檢查等功能正常的關鍵。
main "$@"
