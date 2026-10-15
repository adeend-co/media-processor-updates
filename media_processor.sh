#!/usr/bin/env bash

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
#                                                                              #
# 二、非商業性利用：被授權人不得為商業目的而利用本著作。所稱商業目的，                       #
#     係指主要目的為獲取商業利益或營利之行為。                                         #
#                                                                              #
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
SCRIPT_VERSION="v2.8.0"

############################################
# 使用者同意書版本號
# 當修改同意書內容時，請增加此版本號 (例如：1.6 -> 1.7)
############################################
AGREEMENT_VERSION="1.6"

############################################
# 腳本更新日期
############################################
SCRIPT_UPDATE_DATE="2026-10-15"

# 預設參數設定
DEFAULT_URL="https://www.youtube.com/watch?v=siNFnlqtd8M"
THREADS=4
MAX_THREADS=8
MIN_THREADS=1
COLOR_ENABLED=true
UPDATE_CHANNEL="stable"         # 腳本自身更新渠道: stable | beta
YTDLP_UPDATE_CHANNEL="nightly"  # yt-dlp 更新渠道: nightly (預設推薦) | stable

# --- 設定檔路徑 ---
CONFIG_FILE="$HOME/.media_processor_rc"

# --- 日誌級別終端顯示設定 (預設值) ---
TERMINAL_LOG_SHOW_INFO="true"
TERMINAL_LOG_SHOW_WARNING="true"
TERMINAL_LOG_SHOW_ERROR="true"
TERMINAL_LOG_SHOW_SUCCESS="true"
TERMINAL_LOG_SHOW_DEBUG="false"
TERMINAL_LOG_SHOW_SECURITY="true"

# --- 路徑設定 (Git 倉庫與模組路徑) ---
SCRIPT_DIR="$HOME/media-processor-updates"
SCRIPT_INSTALL_PATH="$SCRIPT_DIR/media_processor.sh"

# Python 輔助腳本完整路徑（偵測檔案大小）
PYTHON_ESTIMATOR_SCRIPT_PATH="$SCRIPT_DIR/estimate_size.py"

# 智慧型元數據豐富化模組路徑
PYTHON_METADATA_ENRICHER_SCRIPT_PATH="$SCRIPT_DIR/enrich_metadata.py"
BASH_AUDIO_ENRICHER_SCRIPT_PATH="$SCRIPT_DIR/audio_enricher.sh"

# Invidious 後備下載模組路徑
INVIDIOUS_DOWNLOADER_SCRIPT_PATH="$SCRIPT_DIR/invidious_downloader.py"

# 財務分析與支出追蹤模組路徑（保留項目）
FINANCE_CALCULATOR_SCRIPT_PATH="$SCRIPT_DIR/finance_calculator.py"
EXPENSE_TRACKER_SCRIPT_PATH="$SCRIPT_DIR/monthly_expense_tracker.py"

# Python 轉換器基礎版本變數
PYTHON_CONVERTER_VERSION="1.0.0"

# --- 確保腳本安裝目錄存在並檢查 Git 倉庫狀態 ---
if [ ! -d "$SCRIPT_DIR" ]; then
    echo -e "\033[0;33m偵測到腳本目錄 '$SCRIPT_DIR' 不存在，正在創建... \033[0m"
    if mkdir -p "$SCRIPT_DIR"; then
        echo -e "\033[0;32m目錄 '$SCRIPT_DIR' 創建成功。\033[0m"
        sleep 1
    else
        echo -e "\033[0;31m錯誤：無法創建腳本目錄 '$SCRIPT_DIR'！請檢查權限。腳本無法繼續。\033[0m" >&2
        exit 1
    fi
fi

if [ ! -d "$SCRIPT_DIR/.git" ]; then
    echo -e "\033[0;31m[警告] SCRIPT_DIR ('$SCRIPT_DIR') 目前不是有效的 Git 倉庫根目錄。\033[0m" >&2
    echo -e "\033[0;33m[提示] 請確保已透過 'git clone' 獲取專案，否則自動更新功能將無法運作。\033[0m" >&2
fi

# --- 平台偵測相關變數 ---
OS_TYPE="unknown"
DOWNLOAD_PATH_DEFAULT=""
TEMP_DIR_DEFAULT=""
PACKAGE_MANAGER=""

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
    local show_on_terminal=false

    case "$level" in
        "INFO")     [[ "${TERMINAL_LOG_SHOW_INFO:-true}" == "true" ]] && show_on_terminal=true ;;
        "WARNING")  [[ "${TERMINAL_LOG_SHOW_WARNING:-true}" == "true" ]] && show_on_terminal=true ;;
        "ERROR")    [[ "${TERMINAL_LOG_SHOW_ERROR:-true}" == "true" ]] && show_on_terminal=true ;;
        "SUCCESS")  [[ "${TERMINAL_LOG_SHOW_SUCCESS:-true}" == "true" ]] && show_on_terminal=true ;;
        "DEBUG")    [[ "${TERMINAL_LOG_SHOW_DEBUG:-false}" == "true" ]] && show_on_terminal=true ;;
        "SECURITY") [[ "${TERMINAL_LOG_SHOW_SECURITY:-true}" == "true" ]] && show_on_terminal=true ;;
        *)          show_on_terminal=true ;;
    esac

    if $show_on_terminal; then
        case "$level" in
            "INFO")     colored_display_message="${BLUE}${BOLD}[$timestamp] [$level]${RESET}${BLUE} $message${RESET}" ;;
            "WARNING")  colored_display_message="${YELLOW}${BOLD}[$timestamp] [$level]${RESET}${YELLOW} $message${RESET}" ;;
            "ERROR")    colored_display_message="${RED}${BOLD}[$timestamp] [$level]${RESET}${RED} $message${RESET}" ;;
            "SUCCESS")  colored_display_message="${GREEN}${BOLD}[$timestamp] [$level]${RESET}${GREEN} $message${RESET}" ;;
            "DEBUG")    colored_display_message="${PURPLE}${BOLD}[$timestamp] [$level]${RESET}${PURPLE} $message${RESET}" ;;
            "SECURITY") colored_display_message="${WHITE}${BOLD}[$timestamp] [${RED}$level${RESET}${WHITE}] $message${RESET}" ;;
            *)          colored_display_message="$plain_log_message" ;;
        esac
    fi

    if [ -n "$LOG_FILE" ]; then
        if ! mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null; then
            local log_dir_fail_ts
            log_dir_fail_ts=$(date "+%Y-%m-%d %H:%M:%S")
            if $show_on_terminal; then
                echo -e "${RED}${BOLD}[$log_dir_fail_ts] [ERROR]${RESET}${RED} Failed to create directory for LOG_FILE: $(dirname "$LOG_FILE")${RESET}" >&2
            fi
        elif [ ! -w "$(dirname "$LOG_FILE")" ]; then
            local log_write_fail_ts
            log_write_fail_ts=$(date "+%Y-%m-%d %H:%M:%S")
            if $show_on_terminal; then
                echo -e "${RED}${BOLD}[$log_write_fail_ts] [ERROR]${RESET}${RED} Directory for LOG_FILE is not writable: $(dirname "$LOG_FILE")${RESET}" >&2
            fi
        else
            echo "$plain_log_message" >> "$LOG_FILE"
        fi
    fi

    if $show_on_terminal; then
        echo -e "$colored_display_message"
    fi
}

############################################
# 儲存設定檔 (移除無關同步設定，新增 yt-dlp 渠道設定)
############################################
save_config() {
    if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
        log_message "INFO" "準備儲存目前設定到 $CONFIG_FILE ..."
    else
        echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] (Pre-log) 準備儲存目前設定到 $CONFIG_FILE ..."
    fi

    {
        echo "# --- Configuration File for Media Processor ---"
        echo "# Automatically generated by the script. Do not edit manually unless you know what you are doing."
        echo ""
        echo "# --- General Script Settings ---"
        echo "THREADS=\"${THREADS:-4}\""
        echo "DOWNLOAD_PATH=\"${DOWNLOAD_PATH:-$HOME/Downloads}\""
        echo "COLOR_ENABLED=\"${COLOR_ENABLED:-true}\""
        echo "PYTHON_CONVERTER_VERSION=\"${PYTHON_CONVERTER_VERSION:-1.0.0}\""
        echo "UPDATE_CHANNEL=\"${UPDATE_CHANNEL:-stable}\""
        echo "YTDLP_UPDATE_CHANNEL=\"${YTDLP_UPDATE_CHANNEL:-nightly}\""
        echo ""
        echo "# --- Terminal Log Level Display Settings ---"
        echo "TERMINAL_LOG_SHOW_INFO=\"${TERMINAL_LOG_SHOW_INFO:-true}\""
        echo "TERMINAL_LOG_SHOW_WARNING=\"${TERMINAL_LOG_SHOW_WARNING:-true}\""
        echo "TERMINAL_LOG_SHOW_ERROR=\"${TERMINAL_LOG_SHOW_ERROR:-true}\""
        echo "TERMINAL_LOG_SHOW_SUCCESS=\"${TERMINAL_LOG_SHOW_SUCCESS:-true}\""
        echo "TERMINAL_LOG_SHOW_DEBUG=\"${TERMINAL_LOG_SHOW_DEBUG:-false}\""
        echo "TERMINAL_LOG_SHOW_SECURITY=\"${TERMINAL_LOG_SHOW_SECURITY:-true}\""
        echo ""
        echo "# --- User Agreement Status ---"
        echo "AGREED_TERMS_VERSION=\"${AGREED_TERMS_VERSION:-}\""
    } > "$CONFIG_FILE"

    if [ $? -eq 0 ]; then
        if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
            log_message "INFO" "設定已成功儲存到 $CONFIG_FILE"
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [INFO] (Pre-log) 設定已成功儲存到 $CONFIG_FILE"
        fi
    else
        if command -v log_message &> /dev/null && [ -n "$LOG_FILE" ]; then
            log_message "ERROR" "無法寫入設定檔 $CONFIG_FILE！"
        else
            echo "[$(date "+%Y-%m-%d %H:%M:%S")] [ERROR] (Pre-log) 無法寫入設定檔 $CONFIG_FILE！" >&2
        fi
        echo -e "${RED}錯誤：無法儲存完整設定到 $CONFIG_FILE！請檢查權限和磁碟空間。${RESET}" >&2
    fi
}

############################################
# Termux 通知輔助函數
############################################
_send_termux_notification() {
    local result_code="$1"
    local notification_title="$2"
    local msg_content="$3"
    local final_filepath="$4"

    if [[ "$OS_TYPE" != "termux" ]] || ! command -v termux-notification &> /dev/null; then
        if [[ "$OS_TYPE" == "termux" ]] && ! command -v termux-notification &> /dev/null; then
            log_message "INFO" "未找到 termux-notification 命令，跳過通知。"
        fi
        return
    fi

    local notification_content=""
    local is_summary_notification=false

    if [ -z "$final_filepath" ]; then
        is_summary_notification=true
    fi

    if [ "$result_code" -eq 0 ]; then
        if $is_summary_notification; then
            notification_content="✅ 成功：$msg_content"
            log_message "INFO" "準備發送 Termux 成功通知 (總結) for $msg_content"
        else
            local final_basename
            final_basename=$(basename "$final_filepath" 2>/dev/null)
            if [ -n "$final_basename" ] && [ -f "$final_filepath" ]; then
                notification_content="✅ 成功：$msg_content 已儲存為 '$final_basename'。"
                log_message "INFO" "準備發送 Termux 成功通知 (單項) for $final_basename"
            else
                notification_content="⚠️ 完成但未找到最終檔案：$msg_content ('$final_basename')。"
                log_message "WARNING" "準備發送 Termux 通知但檔案未找到 (單項) for $msg_content"
            fi
        fi
    else
        notification_content="❌ 失敗：$msg_content 處理失敗。請查看輸出或日誌。"
        log_message "INFO" "準備發送 Termux 失敗通知 for $msg_content"
    fi

    if [ -n "$notification_content" ]; then
        if ! termux-notification --title "$notification_title" --content "$notification_content"; then
            log_message "WARNING" "執行 termux-notification 命令失敗。"
        else
            log_message "INFO" "Termux 通知已成功發送。"
        fi
    fi
}

################################################################################
# 載入設定檔 (包含所有影音與系統設定，並提供預設值)
################################################################################
load_config() {
    THREADS="${THREADS:-4}"
    local default_dl_path_platform_base="${DOWNLOAD_PATH_DEFAULT:-$HOME/media_processor_downloads_default}"
    DOWNLOAD_PATH="${DOWNLOAD_PATH:-${default_dl_path_platform_base}}"
    COLOR_ENABLED="${COLOR_ENABLED:-true}"
    PYTHON_CONVERTER_VERSION="${PYTHON_CONVERTER_VERSION:-1.0.0}"
    UPDATE_CHANNEL="${UPDATE_CHANNEL:-stable}"
    YTDLP_UPDATE_CHANNEL="${YTDLP_UPDATE_CHANNEL:-nightly}"

    TERMINAL_LOG_SHOW_INFO="${TERMINAL_LOG_SHOW_INFO:-true}"
    TERMINAL_LOG_SHOW_WARNING="${TERMINAL_LOG_SHOW_WARNING:-true}"
    TERMINAL_LOG_SHOW_ERROR="${TERMINAL_LOG_SHOW_ERROR:-true}"
    TERMINAL_LOG_SHOW_SUCCESS="${TERMINAL_LOG_SHOW_SUCCESS:-true}"
    TERMINAL_LOG_SHOW_DEBUG="${TERMINAL_LOG_SHOW_DEBUG:-false}"
    TERMINAL_LOG_SHOW_SECURITY="${TERMINAL_LOG_SHOW_SECURITY:-true}"

    AGREED_TERMS_VERSION=""

    local initial_threads="$THREADS"
    local initial_color="$COLOR_ENABLED"
    local initial_py_ver="$PYTHON_CONVERTER_VERSION"
    local initial_update_channel="$UPDATE_CHANNEL"
    local initial_ytdlp_channel="$YTDLP_UPDATE_CHANNEL"
    local initial_show_info="$TERMINAL_LOG_SHOW_INFO"
    local initial_show_warning="$TERMINAL_LOG_SHOW_WARNING"
    local initial_show_error="$TERMINAL_LOG_SHOW_ERROR"
    local initial_show_success="$TERMINAL_LOG_SHOW_SUCCESS"
    local initial_show_debug="$TERMINAL_LOG_SHOW_DEBUG"
    local initial_show_security="$TERMINAL_LOG_SHOW_SECURITY"

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
                        if [[ "$var_value" =~ ^[0-9]+$ ]] && (( var_value >= ${MIN_THREADS:-1} && var_value <= ${MAX_THREADS:-8} )); then
                            THREADS="$var_value"
                        else
                            echo "載入設定警告: THREADS ('$var_value') 無效或超出範圍，使用預設 '$initial_threads'。" >&2
                            THREADS="$initial_threads"
                        fi
                        ;;
                    "DOWNLOAD_PATH") DOWNLOAD_PATH="$var_value" ;;
                    "COLOR_ENABLED")
                        if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then COLOR_ENABLED="$var_value"; else COLOR_ENABLED="$initial_color"; fi ;;
                    "PYTHON_CONVERTER_VERSION")
                        if [ -n "$var_value" ]; then PYTHON_CONVERTER_VERSION="$var_value"; else PYTHON_CONVERTER_VERSION="$initial_py_ver"; fi ;;
                    "UPDATE_CHANNEL")
                        if [[ "$var_value" == "stable" || "$var_value" == "beta" ]]; then UPDATE_CHANNEL="$var_value"; else UPDATE_CHANNEL="$initial_update_channel"; fi ;;
                    "YTDLP_UPDATE_CHANNEL")
                        if [[ "$var_value" == "nightly" || "$var_value" == "stable" ]]; then YTDLP_UPDATE_CHANNEL="$var_value"; else YTDLP_UPDATE_CHANNEL="$initial_ytdlp_channel"; fi ;;
                    "TERMINAL_LOG_SHOW_INFO")     if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_INFO="$var_value"; else TERMINAL_LOG_SHOW_INFO="$initial_show_info"; fi ;;
                    "TERMINAL_LOG_SHOW_WARNING")  if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_WARNING="$var_value"; else TERMINAL_LOG_SHOW_WARNING="$initial_show_warning"; fi ;;
                    "TERMINAL_LOG_SHOW_ERROR")    if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_ERROR="$var_value"; else TERMINAL_LOG_SHOW_ERROR="$initial_show_error"; fi ;;
                    "TERMINAL_LOG_SHOW_SUCCESS")  if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_SUCCESS="$var_value"; else TERMINAL_LOG_SHOW_SUCCESS="$initial_show_success"; fi ;;
                    "TERMINAL_LOG_SHOW_DEBUG")    if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_DEBUG="$var_value"; else TERMINAL_LOG_SHOW_DEBUG="$initial_show_debug"; fi ;;
                    "TERMINAL_LOG_SHOW_SECURITY") if [[ "$var_value" == "true" || "$var_value" == "false" ]]; then TERMINAL_LOG_SHOW_SECURITY="$var_value"; else TERMINAL_LOG_SHOW_SECURITY="$initial_show_security"; fi ;;
                    "AGREED_TERMS_VERSION")       AGREED_TERMS_VERSION="$var_value" ;;
                    *) ;; # 忽略已移除或未知的歷史設定項目
                esac
            fi
        done < "$CONFIG_FILE"

        echo -e "${GREEN:-}已成功從 $CONFIG_FILE 載入使用者設定。${RESET:-}"
        sleep 0.5
    else
        echo -e "${YELLOW:-}設定檔 $CONFIG_FILE 未找到或不可讀，將使用預設設定。${RESET:-}"
        sleep 1
    fi

    # --- 驗證與清理 DOWNLOAD_PATH ---
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

    if command -v log_message >/dev/null 2>&1; then
        log_message "INFO" "load_config: 設定載入完成，下載路徑: '$DOWNLOAD_PATH'"
        log_message "DEBUG" "load_config: THREADS='$THREADS', UPDATE_CHANNEL='$UPDATE_CHANNEL', YTDLP_UPDATE_CHANNEL='$YTDLP_UPDATE_CHANNEL'"
    fi
}

############################################
# 根據 COLOR_ENABLED 應用顏色設定
############################################
apply_color_settings() {
    if [ "$COLOR_ENABLED" = true ]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
        BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
        WHITE='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; BOLD=''; RESET=''
    fi
}

############################################
# 偵測平台並設定初始變數函數
############################################
detect_platform_and_set_vars() {
    echo -e "${CYAN}正在偵測操作系統類型...${RESET}"
    OS_TYPE="unknown"
    DOWNLOAD_PATH_DEFAULT=""
    TEMP_DIR_DEFAULT=""
    PACKAGE_MANAGER=""

    if [[ -n "$TERMUX_VERSION" ]] || [[ "$PREFIX" == *"/com.termux/"* ]]; then
        OS_TYPE="termux"
        DOWNLOAD_PATH_DEFAULT="/sdcard/Termux/downloads"
        TEMP_DIR_DEFAULT="${TMPDIR:-/data/data/com.termux/files/usr/tmp}"
        PACKAGE_MANAGER="pkg"
        echo -e "${GREEN}  > 檢測到 Android Termux 環境。${RESET}"
    elif [[ "$(uname -r)" == *Microsoft* || "$(uname -r)" == *microsoft* ]]; then
        OS_TYPE="wsl"
        DOWNLOAD_PATH_DEFAULT="$HOME/Downloads_WSL"
        TEMP_DIR_DEFAULT="/tmp"
        if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt"
        elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf"
        elif command -v yum &> /dev/null; then PACKAGE_MANAGER="yum"
        else echo -e "${YELLOW}  > 警告：在 WSL 中找不到 apt/dnf/yum 套件管理器！${RESET}"
        fi
        echo -e "${GREEN}  > 檢測到 Windows (WSL) 環境 (套件管理器: ${PACKAGE_MANAGER:-未找到})。${RESET}"
    elif [[ "$OSTYPE" == "linux-gnu"* || "$OSTYPE" == "linux-android"* ]]; then
        OS_TYPE="linux"
        DOWNLOAD_PATH_DEFAULT="$HOME/Downloads"
        TEMP_DIR_DEFAULT="/tmp"
        if command -v apt &> /dev/null; then PACKAGE_MANAGER="apt"
        elif command -v dnf &> /dev/null; then PACKAGE_MANAGER="dnf"
        elif command -v yum &> /dev/null; then PACKAGE_MANAGER="yum"
        fi
        echo -e "${GREEN}  > 檢測到 Linux 環境 (套件管理器: ${PACKAGE_MANAGER:-未找到})。${RESET}"
    else
        echo -e "${RED}  > 錯誤：無法識別的操作系統類型！${RESET}"
    fi

    if [[ "$OS_TYPE" == "unknown" ]]; then
        echo -e "${RED}無法確定操作系統，腳本無法繼續。${RESET}"
        exit 1
    fi
    echo -e "${CYAN}平台檢測完成。${RESET}"
    sleep 1
}

###########################################################
# 輔助函數：顯示旋轉等待游標
###########################################################
spinner() {
    local pid=$1
    local delay=0.1
    local spin_chars="⠏⠋⠙⠹⠸⠼⠴⠦⠧⠇"

    while ps -p "$pid" > /dev/null 2>&1; do
        for (( i=0; i<${#spin_chars}; i++ )); do
            echo -ne "${CYAN}${spin_chars:$i:1}${RESET} "
            sleep "$delay"
            echo -ne "\r"
        done
    done
    echo -ne " \r"
}

###########################################################
# 輔助函數：解析錯誤碼並提供詳細資訊
###########################################################
_get_error_details() {
    local error_code="$1"
    local error_message=""
    case "$error_code" in
        "E_YTDLP_JSON")
            error_message="${RED}原因: yt-dlp 無法獲取影片的元數據 (JSON)。\n      ${YELLOW}建議: 請檢查 URL 是否正確、影片是否為私有，或至工具選單將 yt-dlp 更新至 nightly 最新版本。${RESET}"
            ;;
        "E_YTDLP_FORMAT")
            error_message="${RED}原因: yt-dlp 報告 YouTube 未提供腳本請求的特定影片格式。\n      ${YELLOW}建議: 請嘗試重試，或確認 yt-dlp 已透過 nightly 渠道更新至最新版本。${RESET}"
            ;;
        "E_YTDLP_DL_403")
            error_message="${RED}原因: YouTube 伺服器拒絕存取 (HTTP 403 Forbidden)。\n      ${YELLOW}建議: 請更新 yt-dlp 至 nightly 最新版本、更換網路環境，或改用主選單之 Invidious 後備下載方案。${RESET}"
            ;;
        "E_YTDLP_DL_GENERIC")
            error_message="${RED}原因: yt-dlp 下載時發生通用錯誤。\n      ${YELLOW}建議: 請查看上方顯示的詳細錯誤日誌。${RESET}"
            ;;
        "E_FS_PERM")
            error_message="${RED}原因: 檔案系統權限錯誤 (Operation not permitted)。\n      ${YELLOW}建議: 1. 檢查 Termux 儲存權限 (termux-setup-storage)。 2. 檢查影片標題是否含有特殊字元。${RESET}"
            ;;
        "E_FFPROBE_RES")
            error_message="${RED}原因: 下載後，ffprobe 無法讀取影片的解析度。\n      ${YELLOW}建議: 下載的檔案可能已損壞或格式異常。${RESET}"
            ;;
        "E_NORMALIZE_FAIL")
            error_message="${RED}原因: FFmpeg 音量標準化過程失敗。\n      ${YELLOW}建議: 影片的音訊編碼可能不受支援，或原始音訊已損壞。${RESET}"
            ;;
        "E_FFMPEG_MUX")
            error_message="${RED}原因: FFmpeg 最終封裝失敗 (合併影像/音訊/字幕/封面時出錯)。\n      ${YELLOW}建議: 請查看上方 FFmpeg 錯誤輸出，或嘗試「無標準化」下載選項。${RESET}"
            ;;
        "E_FILE_NOT_FOUND")
            error_message="${RED}原因: 流程顯示成功，但找不到最終產出的檔案。\n      ${YELLOW}建議: 下載可能被意外中斷或遭系統清理機制移除。${RESET}"
            ;;
        *)
            error_message="${RED}原因: 未知的錯誤碼 ($error_code)。${RESET}"
            ;;
    esac
    echo -e "$error_message"
}

###########################################################
# 輔助函數：顯示播放清單處理的最終摘要
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

            if [ -n "$raw_error_b64" ]; then
                local raw_error
                raw_error=$(echo "$raw_error_b64" | base64 -d 2>/dev/null)
                if [ -n "$raw_error" ]; then
                    echo -e "${PURPLE}┌─ 原始錯誤日誌 ───────────────────────────────┐${RESET}"
                    echo "$raw_error" | sed 's/^/  │ /'
                    echo -e "${PURPLE}└──────────────────────────────────────────────┘${RESET}"
                fi
            fi

            echo ""
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
    local char="${1:--}"
    local color="${2:-$CYAN}"
    local width

    if command -v tput &> /dev/null; then
        width=$(tput cols 2>/dev/null || echo 50)
    else
        width=50
    fi

    [[ ! "$width" =~ ^[0-9]+$ || "$width" -lt 10 ]] && width=50

    local line=""
    for ((i=0; i<width; i++)); do line+="$char"; done
    echo -e "${color}${line}${RESET}"
}

######################################################################
# 腳本自我更新函數 (v4.6 - 強化 Git 分支解析、API 備援與 exec 重載)
######################################################################
auto_update_script() {
    clear
    echo -e "${CYAN}--- 使用 Git 檢查腳本更新 ---${RESET}"
    log_message "INFO" "使用者觸發 Git 腳本更新檢查 (當前渠道: ${UPDATE_CHANNEL:-stable})。"

    if ! command -v git &> /dev/null; then
        log_message "ERROR" "未找到 'git' 命令。"
        echo -e "${RED}錯誤：找不到 'git' 命令！請先執行依賴更新。${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    local repo_dir="$SCRIPT_DIR"
    local original_dir
    original_dir=$(pwd)

    if [ ! -d "$repo_dir/.git" ]; then
        log_message "ERROR" "目錄 '$repo_dir' 非 Git 倉庫。"
        echo -e "${RED}錯誤：目錄 '$repo_dir' 非有效的 Git 倉庫。${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    if ! cd "$repo_dir"; then
        log_message "ERROR" "無法進入倉庫目錄 '$repo_dir'"
        echo -e "${RED}錯誤：無法進入倉庫目錄！${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    local core_filemode_setting
    core_filemode_setting=$(git config --local --get core.filemode)
    if [[ "$core_filemode_setting" != "false" ]]; then
        echo -e "${YELLOW}偵測到 Git 可能在追蹤檔案權限變化，正在自動修正...${RESET}"
        if git config --local core.filemode false; then
            echo -e "${GREEN}  > 設定成功！${RESET}"
        else
            echo -e "${RED}  > 警告：自動設定失敗！${RESET}"
        fi
        sleep 1
    fi

    echo -e "${YELLOW}檢查本地是否有未提交的更改...${RESET}"
    if [ -n "$(git status --porcelain)" ]; then
        echo -e "${RED}警告：檢測到本地有未提交的更改！${RESET}"
        local confirm_force
        read -r -p "是否放棄本地修改並繼續？(輸入 'yes' 確認): " confirm_force
        if [[ "$confirm_force" != "yes" ]]; then
            echo -e "${YELLOW}已取消更新操作。${RESET}"
            cd "$original_dir" || true
            read -p "按 Enter 返回..."
            return 1
        fi
        if ! git reset --hard HEAD --quiet || ! git clean -fd --quiet; then
            echo -e "${RED}錯誤：放棄本地更改失敗！${RESET}"
            cd "$original_dir" || true
            read -p "按 Enter 返回..."
            return 1
        fi
    else
        echo -e "${GREEN}本地無未提交更改。${RESET}"
    fi

    echo -e "${YELLOW}正在從遠端倉庫獲取最新資訊...${RESET}"
    if ! git fetch --all --tags --prune --quiet; then
        log_message "ERROR" "'git fetch' 失敗。"
        echo -e "${RED}錯誤：無法從遠端獲取更新資訊！請檢查網路連線。${RESET}"
        cd "$original_dir" || true
        read -p "按 Enter 返回..."
        return 1
    fi

    local current_commit_hash
    current_commit_hash=$(git rev-parse @)
    local restore_point_hash="$current_commit_hash"
    local current_version_display
    current_version_display=$(git describe --tags --exact-match "$current_commit_hash" 2>/dev/null || git describe --tags --always "$current_commit_hash" 2>/dev/null || echo "${current_commit_hash:0:7}")
    local target_commit_hash=""
    local target_version_display=""
    local channel_display="${UPDATE_CHANNEL:-stable}"

    if [[ "$channel_display" == "beta" ]]; then
        echo -e "${YELLOW}當前為 [預覽版 Beta] 渠道，目標為遠端主分支最新提交...${RESET}"
        # 優先解析上游追蹤分支，若處於 Detached HEAD 則回退至 origin/main 或 origin/HEAD
        target_commit_hash=$(git rev-parse @{u} 2>/dev/null || git rev-parse origin/main 2>/dev/null || git rev-parse origin/HEAD 2>/dev/null)
        if [ -z "$target_commit_hash" ]; then
            echo -e "${RED}錯誤：無法解析遠端分支 (origin/main) 的最新提交！${RESET}"
            cd "$original_dir" || true
            read -p "按 Enter 返回..."
            return 1
        fi
        target_version_display=$(git describe --tags --exact-match "$target_commit_hash" 2>/dev/null || git describe --tags --always "$target_commit_hash" 2>/dev/null || echo "預覽版 (${target_commit_hash:0:7})")
    else
        echo -e "${YELLOW}當前為 [穩定版 Stable] 渠道，目標為最新正式發布...${RESET}"
        if command -v curl &> /dev/null && command -v jq &> /dev/null; then
            local api_url="https://api.github.com/repos/adeend-co/media-processor-updates/releases/latest"
            local latest_release_json
            latest_release_json=$(curl -sL --connect-timeout 10 "$api_url")
            target_version_display=$(echo "$latest_release_json" | jq -r '.tag_name // empty' 2>/dev/null)
        fi

        # 若 GitHub API 因速率限制或網路問題未能回傳標籤，回退使用本地已 fetch 之最新 Git Tag
        if [ -z "$target_version_display" ]; then
            log_message "WARNING" "無法從 GitHub API 獲取最新 Release 標籤，嘗試使用本地已同步之最新 Git 標籤作為備援..."
            echo -e "${YELLOW}提示：無法從 GitHub API 取得回應，改為查詢本地已同步之最新標籤...${RESET}"
            local latest_tag_commit
            latest_tag_commit=$(git rev-list --tags --max-count=1 2>/dev/null)
            if [ -n "$latest_tag_commit" ]; then
                target_version_display=$(git describe --tags "$latest_tag_commit" 2>/dev/null)
            fi
        fi

        if [ -z "$target_version_display" ]; then
            echo -e "${RED}錯誤：無法解析最新穩定版的標籤名稱！${RESET}"
            cd "$original_dir" || true
            read -p "按 Enter 返回..."
            return 1
        fi

        target_commit_hash=$(git rev-parse "$target_version_display^{commit}" 2>/dev/null)
        if [ -z "$target_commit_hash" ]; then
            echo -e "${RED}錯誤：無法將標籤 '$target_version_display' 解析為有效的提交！${RESET}"
            cd "$original_dir" || true
            read -p "按 Enter 返回..."
            return 1
        fi
    fi

    echo -e "\n${CYAN}------------------- 版本狀態 -------------------${RESET}"
    echo -e "${CYAN}  - 當前渠道: ${GREEN}${channel_display}${RESET}"
    echo -e "${CYAN}  - 當前版本: ${WHITE}${current_version_display} (${current_commit_hash:0:7})${RESET}"
    echo -e "${CYAN}  - 目標版本: ${WHITE}${target_version_display} (${target_commit_hash:0:7})${RESET}"
    echo -e "${CYAN}------------------------------------------------${RESET}\n"

    if [ "$current_commit_hash" == "$target_commit_hash" ]; then
        echo -e "${GREEN}您的腳本已是 '${channel_display}' 渠道的最新版本，無需任何操作。${RESET}"
        cd "$original_dir" || true
        read -p "按 Enter 返回..."
        return 0
    fi

    local base_commit
    base_commit=$(git merge-base "$current_commit_hash" "$target_commit_hash" 2>/dev/null)
    local action_description=""
    local confirm_prompt=""
    if [ "$base_commit" == "$current_commit_hash" ]; then
        action_description="${GREEN}檢測到新版本！這是一個標準的向前更新。${RESET}"
        confirm_prompt="是否立即【更新】到版本 '${target_version_display}'？ (y/n): "
    elif [ "$base_commit" == "$target_commit_hash" ]; then
        action_description="${YELLOW}檢測到版本變化！您當前的預覽版比目標穩定版更新。${RESET}"
        confirm_prompt="是否要從當前版本【降級/切換】到穩定的 '${target_version_display}' 版本？ (y/n): "
    else
        action_description="${CYAN}檢測到版本變化！您當前的版本與目標版本處於不同開發分支。${RESET}"
        confirm_prompt="是否要【切換】到 '${target_version_display}' 版本？ (y/n): "
    fi

    echo -e "$action_description"
    local confirm_action
    read -r -p "$confirm_prompt" confirm_action
    if [[ ! "$confirm_action" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了版本變更操作。"
        echo -e "${YELLOW}操作已取消。${RESET}"
        cd "$original_dir" || true
        read -p "按 Enter 返回..."
        return 0
    fi

    echo -e "${YELLOW}正在將腳本重設到目標版本 (${target_commit_hash:0:7})...${RESET}"
    if ! git reset --hard "$target_commit_hash" --quiet; then
        log_message "ERROR" "'git reset --hard' 失敗。"
        echo -e "${RED}錯誤：版本重設操作失敗！${RESET}"
        cd "$original_dir" || true
        read -p "按 Enter 返回..."
        return 1
    fi
    log_message "SUCCESS" "成功重設到目標版本 $target_version_display ($target_commit_hash)"
    echo -e "${GREEN}版本變更完成。${RESET}"

    # --- 校驗所有核心影音與財務分析腳本之執行權限 ---
    echo -e "${CYAN}正在校驗所有核心腳本權限...${RESET}"
    local all_executable_scripts=(
        "$SCRIPT_INSTALL_PATH"                     # 主腳本
        "$PYTHON_ESTIMATOR_SCRIPT_PATH"            # Python 大小預估
        "$FINANCE_CALCULATOR_SCRIPT_PATH"          # 進階財務分析與預測器（保留）
        "$EXPENSE_TRACKER_SCRIPT_PATH"             # 月份支出追蹤器（保留）
        "$BASH_AUDIO_ENRICHER_SCRIPT_PATH"         # 音訊豐富化 Bash 控制器
        "$PYTHON_METADATA_ENRICHER_SCRIPT_PATH"    # 音訊豐富化 Python 核心
        "$INVIDIOUS_DOWNLOADER_SCRIPT_PATH"        # Invidious（下載備用方案）
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

    local goto_restore=false
    local health_check_error_output=""
    echo -e "${CYAN}正在測試新版本腳本...${RESET}"
    echo -n "  - 測試1：語法檢查... "
    local syntax_check_output
    syntax_check_output=$(bash -n "$SCRIPT_INSTALL_PATH" 2>&1)
    if [ $? -ne 0 ]; then
        echo -e "${RED}失敗！${RESET}"
        health_check_error_output="$syntax_check_output"
        goto_restore=true
    else
        echo -e "${GREEN}通過。${RESET}"
    fi

    if ! $goto_restore; then
        echo -n "  - 測試2：健康檢查... "
        local health_check_output
        health_check_output=$(timeout 15s bash "$SCRIPT_INSTALL_PATH" --health-check < /dev/null 2>&1)
        local s=$?
        if [ $s -eq 124 ]; then
            echo -e "${RED}失敗(超時)！${RESET}"
            health_check_error_output="執行超時"
            goto_restore=true
        elif [ $s -ne 0 ]; then
            echo -e "${RED}失敗(錯誤碼:$s)！${RESET}"
            health_check_error_output="$health_check_output"
            goto_restore=true
        else
            echo -e "${GREEN}通過。${RESET}"
        fi
    fi

    if ! $goto_restore; then
        log_message "SUCCESS" "新版本測試通過，準備使用 exec 重新載入腳本。"
        echo -e "${GREEN}新版本測試通過！更新成功！${RESET}"
        echo -e "${CYAN}正在自動重新載入新版本腳本，請稍候...${RESET}"
        sleep 1
        cd "$original_dir" || true
        exec "$SCRIPT_INSTALL_PATH"
    fi

    echo -e "\n${RED}--- 更新測試失敗 ---${RESET}"
    echo -e "${RED}新版本腳本未能通過自動化測試，正在自動還原至先前版本...${RESET}"
    if [ -n "$health_check_error_output" ]; then
        echo -e "${YELLOW}偵測到的錯誤：\n${PURPLE}$health_check_error_output${RESET}"
    fi
    if git reset --hard "$restore_point_hash" --quiet; then
        echo -e "${CYAN}正在還原腳本權限...${RESET}"
        for script_path in "${all_executable_scripts[@]}"; do
            if [ -f "$script_path" ]; then chmod +x "$script_path" 2>/dev/null; fi
        done
        echo -e "${GREEN}還原成功！${RESET}"
        log_message "SUCCESS" "成功還原到舊版本 (commit: ${restore_point_hash:0:7})"
    else
        log_message "ERROR" "自動還原失敗！"
        echo -e "${RED}${BOLD}致命錯誤：自動還原失敗！請手動檢查 Git 倉庫！${RESET}"
    fi

    cd "$original_dir" || true
    read -p "按 Enter 返回..."
    return 1
}

############################################
# 高解析度封面圖片下載函數 (接收 video_id)
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

############################################
# 安全刪除函數
############################################
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

######################################################################
# 檢查並更新依賴套件 (v3.0 - 支援 yt-dlp nightly 渠道與 Termux 相容)
######################################################################
update_dependencies() {
    # 納入腳本實際調用之所有系統級工具 (含 Bilibili 加速所需之 aria2 與更新所需之 git)
    local pkg_tools=("ffmpeg" "jq" "curl" "python" "bc" "aria2" "git")
    local update_failed=false
    local missing_after_update=()

    clear
    echo -e "${CYAN}--- 開始檢查並更新依賴套件 ---${RESET}"
    log_message "INFO" "使用者觸發依賴套件更新流程 (yt-dlp 渠道: ${YTDLP_UPDATE_CHANNEL:-nightly})。"

    # --- 步驟 1: 更新包管理器列表 ---
    echo -e "${YELLOW}[1/4] 正在更新套件列表 (${PACKAGE_MANAGER} update)...${RESET}"
    local update_cmd=""
    if [[ "$PACKAGE_MANAGER" == "pkg" ]]; then
        update_cmd="pkg update -y"
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        update_cmd="sudo apt update -y"
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        update_cmd="sudo dnf check-update"
    elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
        update_cmd="sudo yum check-update"
    else
        echo -e "${RED}  > 錯誤：未知的包管理器 '$PACKAGE_MANAGER'，無法更新列表。${RESET}"
        log_message "ERROR" "未知包管理器 '$PACKAGE_MANAGER'，跳過列表更新。"
        update_failed=true
    fi

    if [[ -n "$update_cmd" ]]; then
        if $update_cmd; then
            log_message "INFO" "$PACKAGE_MANAGER list update succeeded"
            echo -e "${GREEN}  > 套件列表更新成功。${RESET}"
        else
            log_message "WARNING" "$PACKAGE_MANAGER list update failed (exit code $?), proceeding anyway."
            echo -e "${YELLOW}  > 警告：套件列表更新回報非零狀態，將嘗試使用現有列表繼續。${RESET}"
        fi
    fi
    echo ""

    # --- 步驟 2: 安裝/更新包管理器管理的工具 ---
    echo -e "${YELLOW}[2/4] 正在安裝/更新 ${PACKAGE_MANAGER} 套件: ${pkg_tools[*]}...${RESET}"
    local install_cmd=""
    if [[ "$PACKAGE_MANAGER" == "pkg" ]]; then
        install_cmd="pkg install -y ${pkg_tools[*]}"
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        install_cmd="sudo apt install -y ${pkg_tools[*]} python3-pip"
    elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then
        install_cmd="sudo dnf install -y ${pkg_tools[*]} python3-pip"
    elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then
        install_cmd="sudo yum install -y ${pkg_tools[*]} python3-pip"
    else
        echo -e "${RED}  > 錯誤：未知的包管理器 '$PACKAGE_MANAGER'，無法安裝套件。${RESET}"
        log_message "ERROR" "未知包管理器 '$PACKAGE_MANAGER'，跳過套件安裝。"
        update_failed=true
    fi

    if [[ -n "$install_cmd" ]]; then
        if $install_cmd; then
            log_message "INFO" "Installation/update of ${pkg_tools[*]} via $PACKAGE_MANAGER successful."
            echo -e "${GREEN}  > 安裝/更新系統套件完成。${RESET}"
        else
            log_message "ERROR" "Installation/update of ${pkg_tools[*]} via $PACKAGE_MANAGER failed!"
            echo -e "${RED}  > 錯誤：安裝/更新系統套件失敗！${RESET}"
            update_failed=true
        fi
    fi
    echo ""

    # --- 步驟 3: 更新 pip 管理的工具 (yt-dlp 及其預設備援套件) ---
    local ytdlp_channel="${YTDLP_UPDATE_CHANNEL:-nightly}"
    echo -e "${YELLOW}[3/4] 正在透過 pip 更新 yt-dlp (目標管道: ${ytdlp_channel})...${RESET}"
    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    fi

    if [[ -n "$python_cmd" ]]; then
        local pip_args=(-m pip install --upgrade)
        if [[ "$ytdlp_channel" == "nightly" ]]; then
            pip_args+=(--pre "yt-dlp[default]")
        else
            pip_args+=("yt-dlp[default]")
        fi

        # 在 Termux 中可直接執行；若在支援 PEP 668 的 Linux 環境失敗，則嘗試加上 --break-system-packages
        if "$python_cmd" "${pip_args[@]}"; then
            local current_ytdlp_ver
            current_ytdlp_ver=$(yt-dlp --version 2>/dev/null || echo "未知")
            log_message "INFO" "Update of yt-dlp ($ytdlp_channel) via pip succeeded. Version: $current_ytdlp_ver"
            echo -e "${GREEN}  > 更新 yt-dlp (${ytdlp_channel}) 完成！當前版本: ${current_ytdlp_ver}${RESET}"
        elif [[ "$OS_TYPE" != "termux" ]] && "$python_cmd" "${pip_args[@]}" --break-system-packages; then
            local current_ytdlp_ver
            current_ytdlp_ver=$(yt-dlp --version 2>/dev/null || echo "未知")
            log_message "INFO" "Update of yt-dlp ($ytdlp_channel) via pip (with --break-system-packages) succeeded. Version: $current_ytdlp_ver"
            echo -e "${GREEN}  > 更新 yt-dlp (${ytdlp_channel}) 完成！當前版本: ${current_ytdlp_ver}${RESET}"
        else
            log_message "ERROR" "Update of yt-dlp via pip failed!"
            echo -e "${RED}  > 錯誤：透過 pip 更新 yt-dlp 失敗！${RESET}"
            update_failed=true
        fi
    else
        log_message "ERROR" "Python command not found, cannot update yt-dlp."
        echo -e "${RED}  > 錯誤：找不到 python/python3 命令，無法更新 yt-dlp。${RESET}"
        update_failed=true
    fi
    echo ""

    # --- 步驟 4: 最終驗證所有工具 ---
    echo -e "${YELLOW}[4/4] 正在驗證所有必要工具是否已安裝...${RESET}"
    local all_tools=("${pkg_tools[@]}" "yt-dlp" "ffprobe")

    for tool_in_list in "${all_tools[@]}"; do
        local command_to_check=""
        case "$tool_in_list" in
            "aria2")
                command_to_check="aria2c"
                ;;
            "python")
                if command -v python3 &> /dev/null; then
                    command_to_check="python3"
                else
                    command_to_check="python"
                fi
                ;;
            *)
                command_to_check="$tool_in_list"
                ;;
        esac

        if ! command -v "$command_to_check" &> /dev/null; then
            missing_after_update+=("$tool_in_list ($command_to_check)")
            echo -e "${RED}  > 驗證失敗：找不到 $command_to_check (套件: $tool_in_list)${RESET}"
        else
            echo -e "${GREEN}  > 驗證成功：找到 $command_to_check (套件: $tool_in_list)${RESET}"
        fi
    done
    echo ""

    # --- 總結結果 ---
    if [ ${#missing_after_update[@]} -ne 0 ]; then
        log_message "ERROR" "Update process completed, but still missing tools: ${missing_after_update[*]}"
        echo -e "${RED}--- 更新結果：失敗 ---${RESET}"
        echo -e "${RED}更新/安裝後，仍然缺少以下必要工具或其對應命令：${RESET}"
        for tool in "${missing_after_update[@]}"; do
            echo -e "${YELLOW}  - $tool${RESET}"
        done
        echo -e "${CYAN}請檢查網路連線或嘗試在終端機手動安裝。${RESET}"
    elif [ "$update_failed" = true ]; then
        log_message "WARNING" "Update process completed with some errors, but all required binaries exist."
        echo -e "${YELLOW}--- 更新結果：部分成功 ---${RESET}"
        echo -e "${YELLOW}更新過程中出現部分警告或錯誤，但所有必要工具皆已存在於系統中。${RESET}"
    else
        log_message "SUCCESS" "All dependencies checked and successfully updated/installed."
        echo -e "${GREEN}--- 更新結果：成功 ---${RESET}"
        echo -e "${GREEN}所有依賴套件與 yt-dlp 均已成功檢查並更新至最新狀態。${RESET}"
    fi

    echo ""
    read -p "按 Enter 返回選單..."
}

############################################
# 音量標準化共用函數 (v1.7 - 雙模式響度控制)
############################################
normalize_audio() {
    local input_file="$1"
    local output_file="$2"
    local temp_dir="$3"
    local is_video="$4" # true 或 false

    if [ ! -d "$temp_dir" ]; then mkdir -p "$temp_dir"; fi

    local audio_wav="$temp_dir/audio.wav"
    local step1_dyn_wav="$temp_dir/step1_dyn.wav"
    local normalized_wav="$temp_dir/normalized.wav"
    local loudnorm_log="$temp_dir/loudnorm_log.txt"

    # === [Step 1] 準備音訊基底 ===
    echo -e "    ${YELLOW}>> [1/4] 準備音訊基底 (WAV 轉換)...${RESET}"

    ffmpeg -y -i "$input_file" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$audio_wav" > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        log_message "ERROR" "無法將音訊轉換為 WAV 格式: $input_file"
        return 1
    fi

    # === [Step 2] 原始數據分析 ===
    echo -e "    ${YELLOW}>> [2/4] 執行原始數據分析 (Analysis)...${RESET}"

    ffmpeg -y -i "$audio_wav" -af "loudnorm=I=-12:TP=-1.5:LRA=11:print_format=json" -f null - 2> "$loudnorm_log"

    local stats_json
    stats_json=$(awk '
        BEGIN { capture=0 }
        /{/ { capture=1; buffer="" }
        capture { buffer=buffer $0 "\n" }
        /}/ { if(capture && buffer ~ /input_i/) { print buffer; capture=0 } }
    ' "$loudnorm_log")

    if [ -z "$stats_json" ]; then
        stats_json=$(awk '/{/,/}/' "$loudnorm_log" | tail -n 12)
    fi

    local measured_I
    measured_I=$(echo "$stats_json" | jq -r '.input_i // empty')
    local measured_TP
    measured_TP=$(echo "$stats_json" | jq -r '.input_tp // empty')
    local measured_LRA
    measured_LRA=$(echo "$stats_json" | jq -r '.input_lra // empty')
    local measured_thresh
    measured_thresh=$(echo "$stats_json" | jq -r '.input_thresh // empty')
    local offset
    offset=$(echo "$stats_json" | jq -r '.target_offset // empty')

    if [ -z "$measured_I" ] || [ -z "$measured_LRA" ]; then
        log_message "ERROR" "數據分析失敗 (JSON 解析錯誤)"
        rm -f "$audio_wav" "$loudnorm_log"
        return 1
    fi

    # === [Step 3] 策略判定邏輯 ===
    local text_to_check
    text_to_check=$(basename "$input_file")
    local title_source="檔名"

    if [ -n "${video_title:-}" ]; then
        text_to_check="$video_title"
        title_source="變數(video_title)"
    elif [ -n "${item_title:-}" ]; then
        text_to_check="$item_title"
        title_source="變數(item_title)"
    elif [ -n "${media_json:-}" ]; then
        local json_title
        json_title=$(echo "$media_json" | jq -r '.title // empty')
        if [ -n "$json_title" ]; then
            text_to_check="$json_title"
            title_source="變數(media_json)"
        fi
    fi

    local text_lower="${text_to_check,,}"
    local keyword_regex="(piano|nocturne|sonata|etude|recital|solo|variations|concerto|pf|op\.|kv\.|bwv|ピアノ|鋼琴|演奏|弾き|奏)"

    local is_keyword_match=false
    if [[ "$text_lower" =~ $keyword_regex ]]; then
        is_keyword_match=true
    fi

    local strategy_mode=""
    local mode_display_name=""
    local mode_color=""
    local trigger_reason=""
    local target_I=""
    local target_LRA=""
    local target_TP=""

    if (( $(echo "$measured_LRA > 8.5" | bc -l) )) || [ "$is_keyword_match" = true ]; then
        strategy_mode="HIGH_DYNAMIC"
        mode_display_name="高動態保真模式 (High Dynamic)"
        mode_color="${CYAN}"

        if [ "$is_keyword_match" = true ]; then
            trigger_reason="關鍵字匹配 [${BASH_REMATCH[0]}]"
        else
            trigger_reason="高動態偵測 (LRA > 8.5)"
        fi

        target_I="-12 (雙層)"
        target_LRA="自動適應"
        target_TP="-1.5"
    else
        strategy_mode="STANDARD"
        mode_display_name="標準廣播模式 (Standard)"
        mode_color="${GREEN}"
        trigger_reason="一般動態範圍"

        target_I="-12"
        target_LRA="11"
        target_TP="-1.5"
    fi

    echo -e "        |-- 原始數據: I=${measured_I} LUFS | LRA=${measured_LRA} LU"
    echo -e "        |-- 應用策略: ${mode_color}${BOLD}${mode_display_name}${RESET}"
    echo -e "        |-- 判定依據: ${trigger_reason}"

    # === [Step 4] 執行標準化處理 ===
    echo -e "    ${YELLOW}>> [3/4] 執行音訊處理流程...${RESET}"

    if [ "$strategy_mode" == "HIGH_DYNAMIC" ]; then
        echo -e "        [階段 1/2] 正在執行動態標準化 (Dynamic Normalizer)..."
        ffmpeg -y -i "$audio_wav" -af "dynaudnorm=f=200:g=15:p=0.95" -c:a pcm_s16le "$step1_dyn_wav" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_message "ERROR" "階段 1 (dynaudnorm) 處理失敗"
            rm -f "$audio_wav" "$step1_dyn_wav" "$loudnorm_log"
            return 1
        fi

        echo -e "        [階段 2/2] 正在執行目標響度控制 (Loudness Control)..."
        ffmpeg -y -i "$step1_dyn_wav" -af "loudnorm=I=-12:TP=-1.5:LRA=11:print_format=summary" -c:a pcm_s16le "$normalized_wav" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            log_message "ERROR" "階段 2 (loudnorm) 處理失敗"
            rm -f "$audio_wav" "$step1_dyn_wav" "$normalized_wav" "$loudnorm_log"
            return 1
        fi

        rm -f "$step1_dyn_wav"
    else
        echo -e "        [階段 1/1] 正在執行線性響度控制 (Linear Loudnorm)..."
        ffmpeg -y -i "$audio_wav" \
            -af "loudnorm=I=-12:TP=-1.5:LRA=11:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset:linear=true:print_format=summary" \
            -c:a pcm_s16le "$normalized_wav" > /dev/null 2>&1

        if [ $? -ne 0 ]; then
            log_message "ERROR" "標準化處理失敗"
            rm -f "$audio_wav" "$normalized_wav" "$loudnorm_log"
            return 1
        fi
    fi

    # === [Step 5] 最終輸出與報告 ===
    echo -e "    ${YELLOW}>> [4/4] 封裝最終檔案...${RESET}"
    log_message "INFO" "正在寫入最終檔案..."

    if [ "$is_video" = true ]; then
        ffmpeg -y -i "$normalized_wav" -c:a aac -b:a 256k -ar 44100 "$output_file" > /dev/null 2>&1
    else
        ffmpeg -y -i "$normalized_wav" -c:a libmp3lame -b:a 320k "$output_file" > /dev/null 2>&1
    fi

    if [ $? -ne 0 ]; then
        log_message "ERROR" "最終編碼失敗"
        rm -f "$audio_wav" "$normalized_wav" "$loudnorm_log"
        return 1
    fi

    echo -e ""
    echo -e "=========================================================="
    echo -e "                  音訊處理結算報告 (Summary)"
    echo -e "=========================================================="
    printf " %-12s | %s\n" "處理檔案" "$(basename "$input_file" | cut -c 1-35)..."
    printf " %-12s | %s\n" "標題來源" "$title_source"
    echo -e "----------------------------------------------------------"
    printf " %-12s | I: %s LUFS | LRA: %s LU\n" "原始數據" "$measured_I" "$measured_LRA"
    printf " %-12s | %s\n" "應用策略" "$mode_display_name"
    printf " %-12s | %s\n" "觸發原因" "$trigger_reason"
    echo -e "----------------------------------------------------------"
    printf " %-12s | I: %-6s | TP: %-6s | LRA: %s\n" "目標設定" "$target_I" "$target_TP" "$target_LRA"
    printf " %-12s | %s\n" "處理狀態" "✅ 已完成 (Completed)"
    echo -e "=========================================================="
    echo -e ""

    rm -f "$audio_wav" "$normalized_wav" "$loudnorm_log"
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

    [ -d "$temp_dir" ] && rm -rf "$temp_dir" 2>/dev/null
    return $result
}

############################################
# 處理本機 MP4 影片（音量標準化，含基於時長之條件式通知）
############################################
process_local_mp4() {
    local video_file="$1"
    local temp_dir base output_video normalized_audio result duration_secs should_notify_local=false

    if [ ! -f "$video_file" ]; then
        echo -e "${RED}錯誤：檔案不存在！${RESET}"
        log_message "ERROR" "process_local_mp4: 檔案不存在 '$video_file'"
        return 1
    fi

    # --- 獲取時長並判斷是否通知 ---
    echo -e "${YELLOW}正在獲取影片時長以決定是否需要通知...${RESET}"
    local duration_secs_str duration_exit_code
    duration_secs_str=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file")
    duration_exit_code=$?

    if [ $duration_exit_code -eq 0 ] && [[ "$duration_secs_str" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        duration_secs=$(printf "%.0f" "$duration_secs_str")
        local duration_threshold_secs=1260 # 0.35 小時 (21 分鐘)
        log_message "INFO" "本機 MP4：檔案時長 = $duration_secs 秒, 通知閾值 = $duration_threshold_secs 秒 (0.35小時)."

        if [[ "$duration_secs" -gt "$duration_threshold_secs" ]]; then
            log_message "INFO" "本機 MP4：時長超過閾值，啟用通知。"
            should_notify_local=true
            echo -e "${CYAN}提示：影片時長 ($duration_secs 秒) 超過 0.35 小時，處理完成後將發送通知。${RESET}"
            sleep 1
        else
            log_message "INFO" "本機 MP4：時長未超過閾值，禁用通知。"
        fi
    else
        log_message "WARNING" "無法從 ffprobe 獲取有效的時長資訊 (退出碼: $duration_exit_code, 輸出: '$duration_secs_str')。將禁用通知。"
        echo -e "${YELLOW}警告：無法獲取影片時長，將禁用完成通知。${RESET}"
        should_notify_local=false
    fi

    # --- 處理流程開始 ---
    temp_dir=$(mktemp -d)
    base=$(basename "$video_file" | sed 's/\.[^.]*$//')
    output_video="$(dirname "$video_file")/${base}_normalized.mp4"
    normalized_audio="$temp_dir/audio_normalized.m4a"

    echo -e "${YELLOW}處理本機影片檔案：$video_file${RESET}"
    log_message "INFO" "處理本機影片檔案：$video_file (啟用通知: $should_notify_local)"

    normalize_audio "$video_file" "$normalized_audio" "$temp_dir" true
    result=$?

    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}正在混流標準化音訊與影片...${RESET}"
        ffmpeg -y -i "$video_file" -i "$normalized_audio" \
               -c:v copy -c:a aac -b:a 256k -ar 44100 \
               -map 0:v:0 -map 1:a:0 -movflags +faststart \
               "$output_video" > "$temp_dir/ffmpeg_local_mux.log" 2>&1
        local mux_result=$?

        if [ $mux_result -ne 0 ]; then
            echo -e "${RED}錯誤：混流失敗！詳見日誌。${RESET}"
            log_message "ERROR" "本機 MP4 混流失敗！詳見 $temp_dir/ffmpeg_local_mux.log"
            cat "$temp_dir/ffmpeg_local_mux.log"
            result=1
        else
            echo -e "${GREEN}混流完成${RESET}"
            log_message "INFO" "本機 MP4 混流成功。"
        fi
        safe_remove "$normalized_audio"
        rm -f "$temp_dir/ffmpeg_local_mux.log"
    else
        log_message "ERROR" "本機 MP4 音量標準化失敗，跳過混流。"
        safe_remove "$normalized_audio"
    fi

    [ -d "$temp_dir" ] && rm -rf "$temp_dir" 2>/dev/null

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_video" ]; then
            echo -e "${GREEN}處理完成！音量標準化後的影片已儲存至：$output_video${RESET}"
            log_message "SUCCESS" "本機 MP4 處理完成！音量標準化後的影片已儲存至：$output_video"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_video' 未找到！${RESET}"
            log_message "ERROR" "本機 MP4 處理完成但最終檔案未找到！"
            result=1
        fi
    else
        echo -e "${RED}處理失敗！${RESET}"
        log_message "ERROR" "本機 MP4 處理失敗：$video_file"
    fi

    # --- 條件式通知 ---
    if $should_notify_local; then
        local notification_title="媒體處理器：本機 MP4 標準化"
        local base_name_for_notify
        base_name_for_notify=$(basename "$video_file")
        local base_msg_notify="處理本機檔案 '$base_name_for_notify'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_video" ]; then
            final_path_notify="$output_video"
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

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
    local goto_cleanup=false

    # --- UI 變數與設置 ---
    local step_current=0
    local step_total=4

    print_step() {
        step_current=$((step_current + 1))
        echo -e "${BLUE}${BOLD}┌─ [Step ${step_current}/${step_total}] ${1} ${RESET}"
    }

    print_sub() {
        echo -e "${WHITE}│  ${CYAN}➥ ${WHITE}${1}${RESET}"
    }

    ### --- 階段 0: 獲取元數據 --- ###
    local media_json
    echo -e "${YELLOW}⏳ 正在解析媒體資訊...${RESET}"

    media_json=$(yt-dlp --no-warnings --dump-json "$media_url" 2>"$temp_dir/yt-dlp-json-dump.log")

    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: 無法獲取元數據。"
        local raw_err_b64
        raw_err_b64=$(echo "無法獲取元數據" | base64 -w 0)
        final_result_string="FAIL|${media_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id="" artist_name="" album_artist_name="" duration_secs=0
    local output_audio="" temp_audio_file=""
    local sanitized_title="" final_base_name=""

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "audio_default"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_default"')
        artist_name=$(echo "$media_json" | jq -r '.artist // .uploader // "[不明]"')
        album_artist_name=$(echo "$media_json" | jq -r '.uploader // "[不明]"')
        duration_secs=$(echo "$media_json" | jq -r '.duration // 0')

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

        if [[ "$mode" != "playlist_mode" ]]; then
            local duration_int=${duration_secs%.*}
            local duration_threshold_secs=1800
            if [[ "${duration_int:-0}" -gt "$duration_threshold_secs" ]]; then
                should_notify=true
                log_message "INFO" "時長超過閾值，將啟用通知。"
            fi
        fi

        local safe_chars_regex='[^a-zA-Z0-9\u4e00-\u9fff\u3000-\u303f\u3040-\u309f\u30a0-\u30ff\uff00-\uffef _.\[\]()-]'
        if command -v iconv &> /dev/null; then
            sanitized_title=$(echo "${video_title}" | iconv -f UTF-8 -t UTF-8 -c | sed -E "s/${safe_chars_regex}/_/g")
        else
            sanitized_title=$(echo "${video_title}" | sed -E "s/${safe_chars_regex}/_/g")
        fi
        sanitized_title=$(echo "$sanitized_title" | sed 's@[/\\:*?"<>|]@_@g')
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

        echo -e "${WHITE}│${RESET}"
        local yt_dlp_audio_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$media_url" --concurrent-fragments "$THREADS" --newline --progress)

        if ! "${yt_dlp_audio_args[@]}" 2> "$temp_dir/yt-dlp-audio-std.log"; then
            echo -e "${RED}└─ ❌ 下載失敗！${RESET}"
            draw_line "-" "$RED"
            echo -e "${RED}${BOLD} [錯誤日誌] yt-dlp output: ${RESET}"
            cat "$temp_dir/yt-dlp-audio-std.log"
            draw_line "-" "$RED"

            local error_code_to_return="E_YTDLP_DL_GENERIC"
            local raw_err_b64
            raw_err_b64=$(cat "$temp_dir/yt-dlp-audio-std.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|${error_code_to_return}|${raw_err_b64}"
            goto_cleanup=true
        else
            echo -e "${BLUE}└─ ✅ 下載完成${RESET}"
            temp_audio_file=$(find "$temp_dir" -maxdepth 1 -type f \( -name "*.m4a" -o -name "*.opus" -o -name "*.webm" -o -name "*.mp3" \) -print -quit)
            if [ -z "$temp_audio_file" ]; then
                log_message "ERROR" "找不到下載後的檔案。"
                local raw_err_b64
                raw_err_b64=$(echo "下載後在臨時目錄中找不到音訊檔案" | base64 -w 0)
                final_result_string="FAIL|${video_title}|E_FILE_NOT_FOUND|${raw_err_b64}"
                goto_cleanup=true
            fi
        fi
    fi

    if ! $goto_cleanup; then
        ### --- 階段 2: 下載封面 --- ###
        print_step "獲取高解析封面"
        local cover_image="$temp_dir/cover.jpg"
        if download_high_res_thumbnail "$video_id" "$cover_image" > /dev/null 2>&1; then
            print_sub "封面下載成功"
        else
            print_sub "無法獲取封面 (將略過封面嵌入)"
        fi
        echo -e "${BLUE}└─ ✅ 準備就緒${RESET}"

        ### --- 階段 3: 音量標準化 --- ###
        print_step "音量標準化 (Loudnorm)"
        print_sub "分析響度並調整至 -12 LUFS..."

        local normalized_temp="$temp_dir/temp_normalized.mp3"

        if normalize_audio "$temp_audio_file" "$normalized_temp" "$temp_dir" false; then
            echo -e "${BLUE}└─ ✅ 標準化完成${RESET}"
        else
            echo -e "${RED}└─ ❌ 標準化失敗！${RESET}"
            log_message "ERROR" "E_NORMALIZE_FAIL"
            local raw_err_b64
            raw_err_b64=$(echo "normalize_audio 執行失敗" | base64 -w 0)
            final_result_string="FAIL|${video_title}|E_NORMALIZE_FAIL|${raw_err_b64}"
            result=1
            goto_cleanup=true
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

            draw_line "!" "$RED"
            echo -e "${RED}${BOLD} [嚴重錯誤] FFmpeg 封裝失敗 ${RESET}"
            echo -e "${YELLOW} 這通常是因為封面格式不支援或標題編碼問題。${RESET}"
            draw_line "-" "$RED"
            cat "$temp_dir/ffmpeg_embed.log"
            draw_line "!" "$RED"

            local raw_err_b64
            raw_err_b64=$(cat "$temp_dir/ffmpeg_embed.log" | base64 -w 0)
            final_result_string="FAIL|${video_title}|E_FFMPEG_MUX|${raw_err_b64}"
            result=1

            # 救援機制
            echo -e "${YELLOW}🚑 啟動救援程序...${RESET}"
            local rescue_file="${DOWNLOAD_PATH}/${final_base_name}_no_meta.mp3"
            if cp "$normalized_temp" "$rescue_file"; then
                echo -e "${GREEN}   ✅ 已救援純音訊檔 (無封面):${RESET}"
                echo -e "${GREEN}   📂 $rescue_file${RESET}"
            else
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
        echo ""
    fi

    rm -rf "$temp_dir"

    if [[ "$mode" != "playlist_mode" ]] && $should_notify; then
        if [ $result -eq 0 ]; then
            _send_termux_notification 0 "MP3 完成" "處理音訊 '$sanitized_title'" "$output_audio"
        else
            _send_termux_notification 1 "MP3 失敗" "處理音訊 '$sanitized_title' 失敗" ""
        fi
    fi

    if [[ "$mode" == "playlist_mode" ]]; then
        echo "${final_result_string}"
    fi
    return $result
}

######################################################################
# 處理單一 YouTube 音訊（MP3）下載（無標準化）
######################################################################
process_single_mp3_no_normalize() {
    local media_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=1
    local final_result_string=""
    local should_notify=false
    local goto_cleanup=false

    ### --- 通知閥值設定 --- ###
    local size_threshold_gb=0.1

    local media_json
    media_json=$(yt-dlp --no-warnings --dump-json "$media_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: (MP3 無標準化) 無法獲取媒體的 JSON 資訊。"
        local raw_err_b64
        raw_err_b64=$(echo "無法獲取元數據" | base64 -w 0)
        final_result_string="FAIL|${media_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id="" artist_name="" album_artist_name=""
    local output_audio="" temp_audio_file=""
    local sanitized_title=""

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "audio_default"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_default"')
        artist_name=$(echo "$media_json" | jq -r '.artist // .uploader // "[不明]"')
        album_artist_name=$(echo "$media_json" | jq -r '.uploader // "[不明]"')

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
            local raw_err_b64
            raw_err_b64=$(cat "$temp_dir/yt-dlp-audio-std.log" | base64 -w 0)
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
            local actual_size_bytes
            actual_size_bytes=$(stat -c %s "$output_audio" 2>/dev/null)
            local size_threshold_bytes
            size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
            if [[ "${actual_size_bytes:-0}" -gt "$size_threshold_bytes" ]]; then
                should_notify=true
                log_message "INFO" "MP3 無標準化：實際大小 ($actual_size_bytes B) 超過閥值 ($size_threshold_bytes B)，啟用通知。"
            fi
        fi
    fi

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
# 處理單一 YouTube 影片（MP4）下載與處理 (v6.5 - 畫質邏輯修正與標準化)
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
    local goto_cleanup=false

    ### --- 通知閥值設定 --- ###
    local duration_threshold_secs=1260 # 0.35 小時 (21 分鐘)

    local media_json
    media_json=$(yt-dlp --no-warnings --dump-json "$video_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: 無法獲取媒體的 JSON 資訊。URL: $video_url"
        local raw_err_b64
        raw_err_b64=$(echo "無法獲取元數據，無特定日誌檔案。" | base64 -w 0)
        final_result_string="FAIL|${video_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id="" duration_secs=0
    local final_video_file="" output_video=""
    local temp_video_file=""
    local sanitized_title=""

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "video_default"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_default"')
        duration_secs=$(echo "$media_json" | jq -r '.duration // 0')

        if [[ "$mode" != "playlist_mode" ]]; then
            if (( $(echo "$duration_secs > $duration_threshold_secs" | bc -l) )); then
                should_notify=true
                log_message "INFO" "MP4 標準化：時長 ($duration_secs s) 超過閥值 ($duration_threshold_secs s)，啟用通知。"
            fi
        fi

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
        local format_option="bestvideo[height<=1440]+bestaudio/best[height<=1440]/best"

        local yt_dlp_video_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$video_url" --concurrent-fragments "$THREADS")

        if ! "${yt_dlp_video_args[@]}" 2> "$temp_dir/yt-dlp-video-std.log"; then
            log_message "WARNING" "yt-dlp 影片下載時回報錯誤，將進行錯誤分析。"
        fi

        temp_video_file=$(find "$temp_dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) -print -quit)

        if [ -z "$temp_video_file" ]; then
            local error_code_to_return="E_YTDLP_DL_GENERIC"
            if grep -q "Requested format is not available" "$temp_dir/yt-dlp-video-std.log"; then
                error_code_to_return="E_YTDLP_FORMAT"
            elif grep -q "HTTP Error 403" "$temp_dir/yt-dlp-video-std.log"; then
                error_code_to_return="E_YTDLP_DL_403"
            elif grep -q "Operation not permitted" "$temp_dir/yt-dlp-video-std.log"; then
                error_code_to_return="E_FS_PERM"
            else
                error_code_to_return="E_FILE_NOT_FOUND"
            fi

            log_message "ERROR" "$error_code_to_return: 下載失敗，在臨時目錄中找不到任何影片檔案。"
            local raw_err_b64
            raw_err_b64=$(cat "$temp_dir/yt-dlp-video-std.log" | base64 -w 0)
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
                    local raw_err_b64
                    raw_err_b64=$(echo -e "命令: mv \"$temp_video_file\" \"$final_video_file\"\n錯誤: $mv_error" | base64 -w 0)
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
        local resolution=""
        local ffprobe_error=""
        local ffprobe_output
        ffprobe_output=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$final_video_file" 2>&1)
        local ffprobe_exit_code=$?

        if [ $ffprobe_exit_code -ne 0 ] || [ -z "$ffprobe_output" ]; then
            resolution=""
            ffprobe_error="$ffprobe_output"
        else
            resolution="$ffprobe_output"
        fi

        if [ -z "$resolution" ]; then
            log_message "ERROR" "E_FFPROBE_RES: 無法獲取影片解析度: $final_video_file"
            safe_remove "$final_video_file"
            local raw_err_b64
            raw_err_b64=$(echo -e "命令: ffprobe ... \"$final_video_file\"\n錯誤: $ffprobe_error" | base64 -w 0)
            final_result_string="FAIL|${video_title}|E_FFPROBE_RES|${raw_err_b64}"
            goto_cleanup=true
        else
            log_message "INFO" "影片重命名並驗證成功：$final_video_file, 解析度: $resolution"
        fi
    fi

    if ! $goto_cleanup; then
        while IFS= read -r srt_file; do
            local srt_basename
            srt_basename=$(basename "$srt_file")
            local new_srt_path="${DOWNLOAD_PATH}/${final_base_name}.${srt_basename#*.}"
            if mv "$srt_file" "$new_srt_path"; then
                subtitle_files+=("$new_srt_path")
                log_message "INFO" "找到並移動字幕到: $new_srt_path"
            fi
        done < <(find "$temp_dir" -maxdepth 1 -type f -name "${video_id}.*.srt")

        local normalized_audio_temp="$temp_dir/audio_normalized.m4a"
        if normalize_audio "$final_video_file" "$normalized_audio_temp" "$temp_dir" true; then
            local ffmpeg_mux_args=(ffmpeg -y -i "$final_video_file" -i "$normalized_audio_temp")
            for sub_f in "${subtitle_files[@]}"; do
                ffmpeg_mux_args+=("-i" "$sub_f")
            done
            ffmpeg_mux_args+=(-metadata "title=${video_title}")
            ffmpeg_mux_args+=(-map 0:v:0 -map 1:a:0 -c:v copy -c:a aac -b:a 256k -ar 44100)
            if [ ${#subtitle_files[@]} -gt 0 ]; then
                ffmpeg_mux_args+=("-c:s" mov_text)
                for ((i=0; i<${#subtitle_files[@]}; i++)); do
                    ffmpeg_mux_args+=(-map "$((i+2)):0")
                    local sub_lang_code
                    sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
                    local ffmpeg_lang="und"
                    case "$sub_lang_code" in
                        zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                        zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                        zh) ffmpeg_lang="chi" ;;
                    esac
                    ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang")
                done
            fi
            ffmpeg_mux_args+=(-movflags "+faststart" "$output_video")

            if ! "${ffmpeg_mux_args[@]}" > "$temp_dir/ffmpeg_mux.log" 2>&1; then
                log_message "ERROR" "E_FFMPEG_MUX: 混流失敗！"
                local raw_err_b64
                raw_err_b64=$(cat "$temp_dir/ffmpeg_mux.log" | base64 -w 0)
                final_result_string="FAIL|${video_title}|E_FFMPEG_MUX|${raw_err_b64}"
                result=1
            else
                log_message "SUCCESS" "混流成功"
                final_result_string="SUCCESS|${video_title}|${resolution}"
                result=0
            fi
        else
            log_message "ERROR" "E_NORMALIZE_FAIL: 音量標準化失敗！"
            local raw_err_b64
            raw_err_b64=$(echo "normalize_audio 函數執行失敗，請檢查其日誌。" | base64 -w 0)
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
    for sub_f in "${subtitle_files[@]}"; do
        safe_remove "$sub_f"
    done
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
# 處理單一 YouTube 影片（MP4）下載（無標準化）
######################################################################
process_single_mp4_no_normalize() {
    local video_url="$1"
    local mode="$2"
    local temp_dir
    temp_dir=$(mktemp -d)
    local final_result_string=""
    local result=1
    local should_notify=false
    local goto_cleanup=false

    ### --- 通知閥值設定 --- ###
    local size_threshold_gb=1.0

    local media_json
    media_json=$(yt-dlp --no-warnings --dump-json "$video_url" 2>"$temp_dir/yt-dlp-json-dump.log")
    if [ -z "$media_json" ]; then
        log_message "ERROR" "E_YTDLP_JSON: (無標準化) 無法獲取媒體的 JSON 資訊。URL: $video_url"
        local raw_err_b64
        raw_err_b64=$(echo "無法獲取元數據，無特定日誌檔案。" | base64 -w 0)
        final_result_string="FAIL|${video_url}|E_YTDLP_JSON|${raw_err_b64}"
        goto_cleanup=true
    else
        goto_cleanup=false
    fi

    local video_title="" video_id=""
    local final_video_file="" temp_video_file=""
    local sanitized_title=""

    if ! $goto_cleanup; then
        video_title=$(echo "$media_json" | jq -r '.title // "video_default"')
        video_id=$(echo "$media_json" | jq -r '.id // "id_default"')

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
        local format_option="bestvideo[height<=1440]+bestaudio/best[height<=1440]/best"

        local yt_dlp_video_args=(yt-dlp -f "$format_option" -o "$temp_output_template" "$video_url" --concurrent-fragments "$THREADS" --merge-output-format mp4 --write-subs --embed-subs --sub-lang "zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA")

        if ! "${yt_dlp_video_args[@]}" 2> "$temp_dir/yt-dlp-video-std.log"; then
            log_message "WARNING" "(無標準化) yt-dlp 影片下載時回報錯誤，將進行錯誤分析。"
        fi

        temp_video_file=$(find "$temp_dir" -maxdepth 1 -type f \( -name "*.mp4" -o -name "*.mkv" -o -name "*.webm" \) -print -quit)

        if [ -z "$temp_video_file" ]; then
            local error_code_to_return="E_YTDLP_DL_GENERIC"
            if grep -q "Requested format is not available" "$temp_dir/yt-dlp-video-std.log"; then
                error_code_to_return="E_YTDLP_FORMAT"
            elif grep -q "HTTP Error 403" "$temp_dir/yt-dlp-video-std.log"; then
                error_code_to_return="E_YTDLP_DL_403"
            elif grep -q "Operation not permitted" "$temp_dir/yt-dlp-video-std.log"; then
                error_code_to_return="E_FS_PERM"
            else
                error_code_to_return="E_FILE_NOT_FOUND"
            fi

            log_message "ERROR" "$error_code_to_return: (無標準化) 下載失敗。"
            local raw_err_b64
            raw_err_b64=$(cat "$temp_dir/yt-dlp-video-std.log" | base64 -w 0)
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
                    local raw_err_b64
                    raw_err_b64=$(echo -e "命令: mv \"$temp_video_file\" \"$final_video_file\"\n錯誤: $mv_error" | base64 -w 0)
                    final_result_string="FAIL|${video_title}|E_FS_PERM|${raw_err_b64}"
                    goto_cleanup=true
                fi
            fi
        fi
    fi

    if ! $goto_cleanup; then
        local resolution=""
        local ffprobe_output
        ffprobe_output=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 "$final_video_file" 2>&1)
        local ffprobe_exit_code=$?
        if [ $ffprobe_exit_code -ne 0 ] || [ -z "$ffprobe_output" ]; then
            resolution="未知"
        else
            resolution="$ffprobe_output"
        fi

        log_message "INFO" "(無標準化) 影片處理完成：$final_video_file, 解析度: $resolution"
        final_result_string="SUCCESS|${video_title}|${resolution}"
        result=0

        if [[ "$mode" != "playlist_mode" ]] && [ -f "$final_video_file" ]; then
            local actual_size_bytes
            actual_size_bytes=$(stat -c %s "$final_video_file" 2>/dev/null)
            local size_threshold_bytes
            size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
            if [[ "${actual_size_bytes:-0}" -gt "$size_threshold_bytes" ]]; then
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
##############################################################
process_single_mp4_no_normalize_sections() {
    local video_url="$1"
    local start_time="$2"
    local end_time="$3"

    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh,zh-Hant-AAj-uoGhMZA"
    local subtitle_files=()
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=0
    local output_video_file=""
    local video_title="" video_id="" sanitized_title="" base_name_for_output=""
    local base_name_for_subs_dl=""

    echo -e "${YELLOW}處理 YouTube 影片 (無標準化，指定時段 $start_time-$end_time)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube 影片 (無標準化，時段 $start_time-$end_time): $video_url"

    # --- 獲取標題和 ID ---
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video_section_$(date +%s)"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id="id_section_$(date +%s)"
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')

    # --- 構建檔名 ---
    local safe_start_time=${start_time//:/-}
    local safe_end_time=${end_time//:/-}
    base_name_for_output="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]_${safe_start_time}-${safe_end_time}"
    local initial_output_video_file="${base_name_for_output}.mp4"
    output_video_file="$initial_output_video_file"

    base_name_for_subs_dl="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]"

    local format_option="bestvideo[height<=1440][ext=mp4][vcodec^=avc]+bestaudio[ext=m4a]/bestvideo[height<=1440][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1440]+bestaudio/best[height<=1440][ext=mp4]/best[height<=1440]/best"
    log_message "INFO" "使用格式 (無標準化，時段): $format_option"

    mkdir -p "$DOWNLOAD_PATH"
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
            -o "$initial_output_video_file"
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
            if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 "$initial_output_video_file" > /dev/null 2>&1; then
                log_message "ERROR" "驗證失敗：下載的檔案 '$initial_output_video_file' 中似乎沒有視訊流！"
                echo -e "${RED}錯誤：下載完成的檔案似乎缺少視訊流！請檢查格式選擇或合併過程。${RESET}"
                result=1
            else
                log_message "INFO" "驗證成功：下載的檔案 '$initial_output_video_file' 包含視訊流。"
            fi
        fi
    fi

    # --- 下載字幕檔案 (完整字幕) ---
    if [ $result -eq 0 ]; then
        log_message "INFO" "嘗試字幕: $target_sub_langs"
        echo -e "${YELLOW}嘗試下載繁/簡/通用中文字幕 (完整影片字幕)...${RESET}"
        local yt_dlp_sub_args=(
            yt-dlp
            --skip-download
            --write-subs
            --sub-lang "$target_sub_langs"
            --convert-subs srt
            -o "${base_name_for_subs_dl}.%(ext)s"
            "$video_url"
        )
        log_message "INFO" "執行 yt-dlp (僅字幕): ${yt_dlp_sub_args[*]}"
        if ! "${yt_dlp_sub_args[@]}" 2> "$temp_dir/yt-dlp-sections-subs.log"; then
            log_message "WARNING" "下載字幕失敗或無字幕。詳見 $temp_dir/yt-dlp-sections-subs.log"
            echo -e "${YELLOW}警告：下載字幕失敗或影片無字幕。${RESET}"
        fi

        log_message "INFO" "檢查字幕 (基於: ${base_name_for_subs_dl}.*.srt)"
        subtitle_files=()
        local langs_to_check=()
        IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
        for lang in "${langs_to_check[@]}"; do
            local potential_srt_file="${base_name_for_subs_dl}.${lang}.srt"
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
            log_message "INFO" "未找到中文字幕。"
            echo -e "${YELLOW}未找到中文字幕。${RESET}"
        fi
    fi

    # --- 字幕混流 (如果找到字幕且影片下載成功) ---
    if [ $result -eq 0 ] && [ ${#subtitle_files[@]} -gt 0 ]; then
        echo -e "${YELLOW}開始將字幕嵌入影片...${RESET}"
        local temp_video_with_subs="${base_name_for_output}_with_subs_temp.mp4"
        local ffmpeg_mux_args=(ffmpeg -y -i "$initial_output_video_file")

        local sub_input_map_idx=1
        for sub_file_path in "${subtitle_files[@]}"; do
            ffmpeg_mux_args+=("-i" "$sub_file_path")
        done
        ffmpeg_mux_args+=("-map" "0:v" "-map" "0:a" "-c:v" "copy" "-c:a" "copy")

        local output_sub_stream_idx=0
        for ((i=0; i<${#subtitle_files[@]}; i++)); do
            ffmpeg_mux_args+=("-map" "$((sub_input_map_idx + i))")
            local sub_lang_code
            sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
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
            echo -e "${RED}錯誤：字幕混流失敗！${RESET}"
            cat "$temp_dir/ffmpeg_mux_subs.log"
            log_message "WARNING" "字幕混流失敗，保留無字幕版本: $initial_output_video_file"
        else
            echo -e "${GREEN}字幕混流完成：$temp_video_with_subs${RESET}"
            log_message "SUCCESS" "字幕混流成功：$temp_video_with_subs"
            safe_remove "$initial_output_video_file"
            if mv "$temp_video_with_subs" "$initial_output_video_file"; then
                log_message "INFO" "重命名 $temp_video_with_subs 為 $initial_output_video_file"
                output_video_file="$initial_output_video_file"
            else
                log_message "ERROR" "重命名 $temp_video_with_subs 失敗，最終檔案為 $temp_video_with_subs"
                echo -e "${RED}錯誤：重命名最終檔案失敗，請檢查 $temp_video_with_subs ${RESET}"
                output_video_file="$temp_video_with_subs"
            fi
        fi
    else
        output_video_file="$initial_output_video_file"
        if [ $result -eq 0 ]; then
            log_message "INFO" "未找到字幕或未成功下載，無需混流。"
        fi
    fi

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (無標準化，時段)..."
    safe_remove "$temp_dir/yt-dlp-sections-video.log" "$temp_dir/yt-dlp-sections-subs.log" "$temp_dir/ffmpeg_mux_subs.log"
    local langs_to_check_cleanup=()
    IFS=',' read -r -a langs_to_check_cleanup <<< "$target_sub_langs"
    for lang_clean in "${langs_to_check_cleanup[@]}"; do
        safe_remove "${base_name_for_subs_dl}.${lang_clean}.srt"
    done
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 最終結果報告 (控制台) ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_video_file" ]; then
            local final_filename_display
            final_filename_display=$(basename "$output_video_file")
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
    if [[ "$OS_TYPE" == "termux" ]]; then
        local notification_title_msg="媒體處理器：MP4 片段"
        local base_msg_notify="影片 '$sanitized_title' 時段 [$start_time-$end_time]"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_video_file" ]; then
            final_path_notify="$output_video_file"
        fi
        _send_termux_notification "$result" "$notification_title_msg" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

############################################
# 處理單一 YouTube 影片（MKV）下載與處理 (保留 ASS/VTT 字幕樣式)
############################################
process_single_mkv() {
    local video_url="$1"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_format_pref="ass/vtt/best"
    local subtitle_files=()
    local temp_dir
    temp_dir=$(mktemp -d)
    local result=0
    local should_notify=false
    local output_mkv=""
    local video_temp_file="${temp_dir}/video_stream.mp4"
    local audio_temp_file="${temp_dir}/audio_stream.m4a"
    local normalized_audio_m4a="$temp_dir/audio_normalized.m4a"
    local sub_temp_template="${temp_dir}/sub_stream.%(ext)s"
    local video_title video_id sanitized_title output_base_name

    echo -e "${YELLOW}處理 YouTube 影片 (輸出 MKV)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube MKV: $video_url"
    log_message "INFO" "將嘗試請求以下字幕 (格式: $subtitle_format_pref): $target_sub_langs"
    echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕 (保留樣式)...${RESET}"

    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video_$(date +%s)"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id="id_$(date +%s)"
    sanitized_title=$(echo "${video_title}" | sed 's@[/\\:*?"<>|]@_@g')
    output_base_name="$DOWNLOAD_PATH/${sanitized_title} [${video_id}]"
    output_mkv="${output_base_name}_normalized.mkv"

    # --- 使用 Python 估計大小並決定是否通知 ---
    local yt_dlp_format_string_estimate="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio/best[ext=mp4]/best"
    echo -e "${YELLOW}正在預估檔案大小 (使用 Python 腳本)...${RESET}"
    local estimated_size_bytes=0
    local python_estimate_output
    local python_exec=""
    if command -v python3 &> /dev/null; then
        python_exec="python3"
    elif command -v python &> /dev/null; then
        python_exec="python"
    fi

    if [ -n "$python_exec" ] && [ -f "$PYTHON_ESTIMATOR_SCRIPT_PATH" ]; then
        log_message "DEBUG" "Calling Python estimator (MKV): $python_exec \"$PYTHON_ESTIMATOR_SCRIPT_PATH\" \"$video_url\" \"$yt_dlp_format_string_estimate\""
        python_estimate_output=$($python_exec "$PYTHON_ESTIMATOR_SCRIPT_PATH" "$video_url" "$yt_dlp_format_string_estimate" 2> "$temp_dir/py_estimator_mkv_stderr.log")
        local py_exit_code=$?
        if [ $py_exit_code -eq 0 ] && [[ "$python_estimate_output" =~ ^[0-9]+$ ]]; then
            estimated_size_bytes="$python_estimate_output"
            log_message "INFO" "Python 腳本估計大小 (MKV): $estimated_size_bytes bytes"
            [ ! -s "$temp_dir/py_estimator_mkv_stderr.log" ] && rm -f "$temp_dir/py_estimator_mkv_stderr.log"
        else
            log_message "WARNING" "Python 估計腳本執行失敗 (MKV Code: $py_exit_code) 或輸出無效 ('$python_estimate_output')。"
            estimated_size_bytes=0
        fi
    else
        log_message "WARNING" "找不到 Python ('$python_exec') 或估計腳本 '$PYTHON_ESTIMATOR_SCRIPT_PATH' (MKV)，無法估計大小。"
        estimated_size_bytes=0
    fi

    local size_threshold_gb_mkv=0.5
    local size_threshold_bytes_mkv
    size_threshold_bytes_mkv=$(awk "BEGIN {printf \"%d\", $size_threshold_gb_mkv * 1024 * 1024 * 1024}")
    log_message "INFO" "檔案大小預估 (MKV): $estimated_size_bytes bytes, 閾值: $size_threshold_bytes_mkv bytes."
    if [[ "$estimated_size_bytes" -gt "$size_threshold_bytes_mkv" ]]; then
        log_message "INFO" "大小超過閾值 (MKV)，啟用通知。"
        should_notify=true
    else
        log_message "INFO" "大小未超過閾值 (MKV)，禁用通知。"
        should_notify=false
    fi

    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入下載目錄 (MKV): $DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入目錄${RESET}"
        result=1
    fi

    # --- 下載視訊流 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載最佳視訊流...${RESET}"
        if ! yt-dlp -f 'bv[ext=mp4][height<=1440]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video.log"; then
            echo -e "${YELLOW}警告：未找到 <=1440p 的 MP4 視訊流，嘗試下載最佳 MP4 視訊流...${RESET}"
            log_message "WARNING" "未找到 <=1440p 的 MP4 視訊流，嘗試最佳 MP4 for $video_url"
            if ! yt-dlp -f 'bv[ext=mp4]/bestvideo[ext=mp4]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video-fallback.log"; then
                log_message "ERROR" "視訊流下載失敗（包括備選方案）..."
                echo -e "${RED}錯誤：視訊流下載失敗！${RESET}"
                result=1
            fi
        fi
        if [ $result -eq 0 ] && [ ! -f "$video_temp_file" ]; then
            log_message "ERROR" "視訊流下載後未找到檔案！"
            echo -e "${RED}錯誤：視訊流下載失敗！${RESET}"
            result=1
        elif [ $result -eq 0 ]; then
            log_message "INFO" "視訊流下載完成: $video_temp_file"
        fi
    fi

    # --- 下載音訊流 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載最佳音訊流...${RESET}"
        if ! yt-dlp -f 'ba[ext=m4a]' --no-warnings -o "$audio_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-audio.log"; then
            log_message "ERROR" "音訊流下載失敗...查看 $temp_dir/yt-dlp-audio.log"
            echo -e "${RED}錯誤：音訊流下載失敗！${RESET}"
            result=1
        fi
        if [ $result -eq 0 ] && [ ! -f "$audio_temp_file" ]; then
            log_message "ERROR" "音訊流下載後未找到檔案！"
            echo -e "${RED}錯誤：音訊流下載失敗！${RESET}"
            result=1
        elif [ $result -eq 0 ]; then
            log_message "INFO" "音訊流下載完成: $audio_temp_file"
        fi
    fi

    # --- 下載字幕 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始下載字幕 (格式: ${subtitle_format_pref})...${RESET}"
        yt-dlp --write-subs --sub-format "$subtitle_format_pref" --sub-lang "$target_sub_langs" --skip-download -o "$sub_temp_template" "$video_url" > "$temp_dir/yt-dlp-subs.log" 2>&1
        subtitle_files=()
        local potential_sub_file=""
        for lang_code in "zh-Hant" "zh-TW" "zh-Hans" "zh-CN" "zh"; do
            for sub_ext in ass vtt; do
                potential_sub_file="${temp_dir}/sub_stream.${lang_code}.${sub_ext}"
                if [ -f "$potential_sub_file" ]; then
                    local already_added=false
                    for existing_file in "${subtitle_files[@]}"; do
                        if [[ "$existing_file" == "$potential_sub_file" ]]; then
                            already_added=true
                            break
                        fi
                    done
                    if ! $already_added; then
                        subtitle_files+=("$potential_sub_file")
                        log_message "INFO" "找到字幕: $potential_sub_file"
                        echo -e "${GREEN}找到字幕: $(basename "$potential_sub_file")${RESET}"
                    fi
                fi
            done
        done
        if [ ${#subtitle_files[@]} -eq 0 ]; then
            log_message "INFO" "未找到符合條件的中文字幕。"
            echo -e "${YELLOW}未找到 ASS/VTT 格式的中文字幕。${RESET}"
        fi
    fi

    # --- 音量標準化與混流 ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}開始音量標準化...${RESET}"
        if normalize_audio "$audio_temp_file" "$normalized_audio_m4a" "$temp_dir" true; then
            echo -e "${YELLOW}正在混流成 MKV 檔案...${RESET}"
            local ffmpeg_mux_args=(ffmpeg -y -i "$video_temp_file" -i "$normalized_audio_m4a")
            local sub_input_index=2
            for sub_file_path in "${subtitle_files[@]}"; do
                ffmpeg_mux_args+=("-i" "$sub_file_path")
            done

            ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100")
            ffmpeg_mux_args+=("-map" "0:v:0" "-map" "1:a:0")

            if [ ${#subtitle_files[@]} -gt 0 ]; then
                ffmpeg_mux_args+=("-c:s" "copy")
                for ((i=0; i<${#subtitle_files[@]}; i++)); do
                    ffmpeg_mux_args+=("-map" "$sub_input_index:s:0")
                    local sub_lang_code
                    sub_lang_code=$(basename "${subtitle_files[$i]}" | rev | cut -d'.' -f2 | rev)
                    local ffmpeg_lang=""
                    case "$sub_lang_code" in
                        zh-Hant|zh-TW) ffmpeg_lang="zht" ;;
                        zh-Hans|zh-CN) ffmpeg_lang="zhs" ;;
                        zh) ffmpeg_lang="chi" ;;
                        *) ffmpeg_lang=$(echo "$sub_lang_code" | cut -c1-3) ;;
                    esac
                    ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$ffmpeg_lang")
                    ((sub_input_index++))
                done
            fi
            ffmpeg_mux_args+=("$output_mkv")

            log_message "INFO" "MKV 混流命令: ${ffmpeg_mux_args[*]}"
            local ffmpeg_stderr_log="$temp_dir/ffmpeg_mkv_mux_stderr.log"
            if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then
                echo -e "${RED}錯誤：MKV 混流失敗！以下是 FFmpeg 錯誤訊息：${RESET}"
                cat "$ffmpeg_stderr_log"
                log_message "ERROR" "MKV 混流失敗，詳見 $ffmpeg_stderr_log"
                result=1
            else
                echo -e "${GREEN}MKV 混流完成${RESET}"
                rm -f "$ffmpeg_stderr_log"
            fi
        else
            log_message "ERROR" "音量標準化失敗！Input: $audio_temp_file"
            result=1
        fi
    fi

    # --- 清理 ---
    log_message "INFO" "清理臨時檔案 (MKV)..."
    if [ $result -eq 0 ] && [ -f "$output_mkv" ]; then
        safe_remove "$video_temp_file" "$audio_temp_file" "$normalized_audio_m4a"
    else
        log_message "INFO" "MKV 處理失敗，清理中間產物。"
        safe_remove "$normalized_audio_m4a"
    fi

    for sub_f in "${subtitle_files[@]}"; do
        safe_remove "$sub_f"
    done
    safe_remove "$temp_dir/yt-dlp-video.log" "$temp_dir/yt-dlp-video-fallback.log" \
                "$temp_dir/yt-dlp-audio.log" "$temp_dir/yt-dlp-subs.log" \
                "$temp_dir/ffmpeg_mkv_mux_stderr.log" "$temp_dir/py_estimator_mkv_stderr.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台最終報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_mkv" ]; then
            echo -e "${GREEN}處理完成！MKV 影片已儲存至：$output_mkv${RESET}"
            log_message "SUCCESS" "MKV 處理完成！影片已儲存至：$output_mkv"
        else
            echo -e "${RED}處理似乎已完成，但最終檔案 '$output_mkv' 未找到！${RESET}"
            log_message "ERROR" "處理完成但最終檔案未找到 (MKV)"
            result=1
        fi
    else
        echo -e "${RED}處理失敗 (MKV)！${RESET}"
        log_message "ERROR" "MKV 處理失敗：$video_url"
    fi

    # --- 條件式通知 ---
    if $should_notify; then
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
# 支援 Bilibili aria2c 加速與基於實際檔案大小之條件式通知
############################################
_process_single_other_site() {
    local item_url="$1"
    local choice_format="$2"
    local item_index="$3"
    local total_items="$4"
    local mode="$5"
    local output_template_playlist="$6"
    local output_template_single_item="$7"

    local temp_dir
    temp_dir=$(mktemp -d)
    local thumbnail_file=""
    local main_media_file=""
    local result=0
    local output_final_file=""
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local progress_prefix=""
    if [ -n "$item_index" ] && [ -n "$total_items" ]; then
        progress_prefix="[$item_index/$total_items] "
    fi
    local should_notify=false
    local is_playlist=false
    local final_output_template_used=""
    local base_name_calculated_from_file=""

    if [[ "$mode" == "playlist_mode" ]]; then
        is_playlist=true
        log_message "INFO" "通用下載 標準化：播放清單模式。"
    fi

    local item_title sanitized_title video_id
    item_title=$(yt-dlp --get-title "$item_url" 2>/dev/null) || item_title="media_item_$(date +%s)"
    video_id=$(yt-dlp --get-id "$item_url" 2>/dev/null) || video_id="no_id_$(date +%s)"
    sanitized_title=$(echo "${item_title}" | sed 's@[/\\:*?"<>|]@_@g')
    log_message "DEBUG" "基礎標題: '$item_title', ID: '$video_id', 清理後: '$sanitized_title'"

    echo -e "${CYAN}${progress_prefix}處理項目: $item_url (${choice_format})${RESET}"
    log_message "INFO" "${progress_prefix}處理項目: $item_url (格式: $choice_format)"
    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入目錄: $DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入目錄${RESET}"
        rm -rf "$temp_dir"
        return 1
    fi

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
        else
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
        else
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

    actual_yt_dlp_args+=(-o "$chosen_output_template" "$item_url")

    log_message "INFO" "${progress_prefix}執行下載 (標準化流程): ${actual_yt_dlp_args[*]}"
    if "${actual_yt_dlp_args[@]}" 2> "$temp_dir/yt-dlp-other-std.log"; then
        download_success=true
        final_output_template_used="$chosen_output_template"
    else
        log_message "ERROR" "下載失敗 (標準化流程)"
        echo -e "${RED}錯誤：下載失敗！${RESET}"
        cat "$temp_dir/yt-dlp-other-std.log"
        result=1
    fi

    if $download_success; then
        echo -e "${YELLOW}${progress_prefix}定位主檔案...${RESET}"
        local format_for_getfn=""
        if [[ "$item_url" == *"bilibili.com"* ]]; then
            if [ "$choice_format" = "mp4" ]; then
                format_for_getfn="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
            else
                format_for_getfn="bestaudio[ext=m4a]/bestaudio/best"
            fi
        else
            if [ "$choice_format" = "mp4" ]; then
                format_for_getfn="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
            else
                format_for_getfn="bestaudio/best"
            fi
        fi

        local yt_dlp_getfn_args=(yt-dlp --no-warnings --print filename -f "$format_for_getfn" -o "$final_output_template_used" "$item_url")
        local actual_download_path
        actual_download_path=$("${yt_dlp_getfn_args[@]}" | tr -d '\n')
        local getfn_exit_code=$?
        log_message "DEBUG" "獲取檔名命令(標準化流程)退出碼: $getfn_exit_code, 獲取的路徑: '$actual_download_path'"

        if [ $getfn_exit_code -eq 0 ] && [ -n "$actual_download_path" ] && [ -f "$actual_download_path" ]; then
            main_media_file="$actual_download_path"
            log_message "INFO" "${progress_prefix}找到主檔案: $main_media_file"
            base_name_calculated_from_file=$(basename "$main_media_file" | sed 's/\.[^.]*$//')
            log_message "DEBUG" "從檔案計算出的 Base Name: [$base_name_calculated_from_file]"
            result=0

            if ! $is_playlist; then
                echo -e "${YELLOW}正在檢查實際檔案大小以決定是否通知...${RESET}"
                local actual_size_bytes
                actual_size_bytes=$(stat -c %s "$main_media_file" 2>/dev/null)

                if [[ "$actual_size_bytes" =~ ^[0-9]+$ ]]; then
                    local size_threshold_gb=0.12
                    if [ "$choice_format" = "mp4" ]; then
                        size_threshold_gb=0.3
                    fi
                    local size_threshold_bytes
                    size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
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
        else
            log_message "ERROR" "找不到主檔案 (通用 std)"
            echo -e "${RED}錯誤：找不到主檔案！${RESET}"
            result=1
        fi
    else
        log_message "DEBUG" "下載標記為失敗，跳過檔案定位。"
    fi

    # --- 下載縮圖 (僅在定位檔案成功時) ---
    if [ $result -eq 0 ]; then
        echo -e "${YELLOW}${progress_prefix}嘗試下載縮圖...${RESET}"
        if [ -n "$base_name_calculated_from_file" ]; then
            local media_dir
            media_dir=$(dirname "$main_media_file")
            local thumb_dl_template="${media_dir}/${base_name_calculated_from_file}.%(ext)s"
            log_message "DEBUG" "嘗試使用縮圖模板: $thumb_dl_template"

            if ! yt-dlp --no-warnings --skip-download --write-thumbnail -o "$thumb_dl_template" "$item_url" 2> "$temp_dir/yt-dlp-thumb.log"; then
                log_message "WARNING" "下載縮圖指令失敗或無縮圖，詳見 $temp_dir/yt-dlp-thumb.log"
            fi
            thumbnail_file=$(find "$media_dir" -maxdepth 1 -type f -iname "${base_name_calculated_from_file}.*" \
                             \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) \
                             -print -quit)
            if [ -n "$thumbnail_file" ]; then
                log_message "INFO" "找到縮圖: $thumbnail_file"
            else
                log_message "WARNING" "在下載目錄中未找到縮圖檔案匹配基礎名: ${base_name_calculated_from_file}"
            fi
        else
            log_message "WARNING" "Base name 未設定，跳過縮圖下載和查找。"
        fi
    fi

    # --- 處理邏輯 (MP3 或 MP4) ---
    if [ $result -eq 0 ]; then
        local media_output_dir
        media_output_dir=$(dirname "$main_media_file")

        if [ "$choice_format" = "mp3" ]; then
            output_final_file="${media_output_dir}/${base_name_calculated_from_file}_normalized.mp3"
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
                    log_message "ERROR" "生成 MP3 失敗 (通用 std)"
                    echo -e "${RED}錯誤：生成 MP3 失敗！${RESET}"
                    result=1
                else
                    result=0
                    safe_remove "$normalized_temp_audio_for_mp3"
                fi
            else
                result=1
                log_message "ERROR" "標準化失敗 (通用 MP3 std)"
            fi

        elif [ "$choice_format" = "mp4" ]; then
            output_final_file="${media_output_dir}/${base_name_calculated_from_file}_normalized.mp4"
            local normalized_audio_m4a_for_mp4="$temp_dir/audio_normalized_for_mp4.m4a"

            echo -e "${YELLOW}${progress_prefix}開始標準化 (提取音訊為 M4A)...${RESET}"
            if normalize_audio "$main_media_file" "$normalized_audio_m4a_for_mp4" "$temp_dir" true; then
                echo -e "${YELLOW}${progress_prefix}混流影片與標準化音訊...${RESET}"
                local ffmpeg_mux_args=(ffmpeg -y -i "$main_media_file" -i "$normalized_audio_m4a_for_mp4" -c:v copy -c:a aac -b:a 256k -ar 44100 -map 0:v:0 -map 1:a:0 -movflags +faststart "$output_final_file")
                log_message "INFO" "執行 FFmpeg 混流 (通用 std): ${ffmpeg_mux_args[*]}"
                if ! "${ffmpeg_mux_args[@]}" > "$temp_dir/ffmpeg_mux.log" 2>&1; then
                    log_message "ERROR" "混流 MP4 失敗 (通用 std)，詳見 $temp_dir/ffmpeg_mux.log"
                    echo -e "${RED}錯誤：混流 MP4 失敗！${RESET}"
                    cat "$temp_dir/ffmpeg_mux.log"
                    result=1
                else
                    result=0
                    safe_remove "$normalized_audio_m4a_for_mp4"
                    rm -f "$temp_dir/ffmpeg_mux.log"
                fi
            else
                result=1
                log_message "ERROR" "標準化失敗 (通用 MP4 std)"
            fi
        fi
    fi

    # --- 清理 ---
    log_message "INFO" "${progress_prefix}清理 (通用 std)..."
    if [ $result -eq 0 ] && [ -f "$main_media_file" ]; then
        safe_remove "$main_media_file"
    fi
    if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then
        safe_remove "$thumbnail_file"
    fi
    safe_remove "$temp_dir/yt-dlp-other-std.log" "$temp_dir/yt-dlp-thumb.log" "$temp_dir/ffmpeg_mux.log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"

    # --- 控制台報告 ---
    if [ $result -eq 0 ]; then
        if [ -f "$output_final_file" ]; then
            echo -e "${GREEN}${progress_prefix}處理完成！檔案：$output_final_file${RESET}"
            log_message "SUCCESS" "${progress_prefix}處理完成！檔案：$output_final_file"
        else
            echo -e "${RED}${progress_prefix}處理似乎已完成，但最終檔案 '$output_final_file' 未找到！${RESET}"
            log_message "ERROR" "${progress_prefix}處理完成但最終檔案未找到"
            result=1
        fi
    else
        echo -e "${RED}${progress_prefix}處理失敗！${RESET}"
        log_message "ERROR" "${progress_prefix}處理失敗：$item_url"
        if [ -f "$main_media_file" ]; then
            echo -e "${YELLOW}原始下載檔案可能保留在：$main_media_file${RESET}"
        fi
    fi

    # --- 條件式通知 (僅單獨模式) ---
    if ! $is_playlist && $should_notify; then
        local notification_title="媒體處理器：通用 標準化"
        local base_msg_notify="${progress_prefix}處理 '$sanitized_title'"
        local final_path_notify=""
        if [ $result -eq 0 ] && [ -f "$output_final_file" ]; then
            final_path_notify="$output_final_file"
        elif [ -f "$main_media_file" ]; then
            final_path_notify="$main_media_file"
        fi
        _send_termux_notification "$result" "$notification_title" "$base_msg_notify" "$final_path_notify"
    fi

    return $result
}

###########################################################
# 輔助函數：處理單一通用網站媒體項目 (無音量標準化)
###########################################################
_process_single_other_site_no_normalize() {
    local item_url="$1"
    local choice_format="$2"
    local item_index="$3"
    local total_items="$4"
    local mode="$5"
    local output_template_playlist="$6"
    local output_template_single_item="$7"

    local temp_dir
    temp_dir=$(mktemp -d)
    local main_media_file=""
    local result=0
    local progress_prefix=""
    if [ -n "$item_index" ] && [ -n "$total_items" ]; then
        progress_prefix="[$item_index/$total_items] "
    fi
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

    echo -e "${CYAN}${progress_prefix}處理項目 (無標準化): $item_url (${choice_format})${RESET}"
    log_message "INFO" "${progress_prefix}處理項目 (無標準化): $item_url (格式: $choice_format)"

    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入目錄: $DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入目錄${RESET}"
        rm -rf "$temp_dir"
        return 1
    fi

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
        else
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
        else
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

    actual_yt_dlp_args+=(-o "$chosen_output_template" "$item_url")

    log_message "INFO" "${progress_prefix}執行下載 (無標準化): ${actual_yt_dlp_args[*]}"
    if "${actual_yt_dlp_args[@]}" 2> "$temp_dir/yt-dlp-other-nonorm.log"; then
        download_success=true
        final_output_template_used="$chosen_output_template"
    else
        log_message "ERROR" "下載失敗 (無標準化)"
        echo -e "${RED}錯誤：下載失敗！${RESET}"
        cat "$temp_dir/yt-dlp-other-nonorm.log"
        result=1
    fi

    if $download_success; then
        echo -e "${YELLOW}${progress_prefix}定位下載的檔案...${RESET}"
        local format_for_getfn=""
        if [[ "$item_url" == *"bilibili.com"* ]]; then
            if [ "$choice_format" = "mp4" ]; then
                format_for_getfn="bestvideo[height<=1440][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[height<=1080][vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[vcodec^=avc1][ext=mp4]+bestaudio[ext=m4a]/bestvideo[ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"
            else
                format_for_getfn="bestaudio[ext=m4a]/bestaudio/best"
            fi
        else
            if [ "$choice_format" = "mp4" ]; then
                format_for_getfn="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best"
            else
                format_for_getfn="bestaudio/best"
            fi
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
        else
            actual_download_path=$("${yt_dlp_getfn_args[@]}" "$item_url" | tr -d '\n')
            getfn_exit_code=$?
        fi

        log_message "DEBUG" "獲取檔名(格式: $choice_format)命令退出碼: $getfn_exit_code, 推斷/獲取的路徑: '$actual_download_path'"

        if [ $getfn_exit_code -eq 0 ] && [ -n "$actual_download_path" ] && [ -f "$actual_download_path" ]; then
            main_media_file="$actual_download_path"
            log_message "INFO" "${progress_prefix}成功定位到下載檔案: $main_media_file"
            result=0

            if ! $is_playlist; then
                echo -e "${YELLOW}正在檢查實際檔案大小以決定是否通知...${RESET}"
                local actual_size_bytes
                actual_size_bytes=$(stat -c %s "$main_media_file" 2>/dev/null)

                if [[ "$actual_size_bytes" =~ ^[0-9]+$ ]]; then
                    local size_threshold_gb=0.5
                    local size_threshold_bytes
                    size_threshold_bytes=$(awk "BEGIN {printf \"%d\", $size_threshold_gb * 1024 * 1024 * 1024}")
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
        else
            log_message "ERROR" "無法獲取或驗證實際檔案路徑。退出碼: $getfn_exit_code, 路徑: '$actual_download_path'"
            echo -e "${RED}錯誤：下載後無法定位主要檔案！檢查日誌。${RESET}"
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
            echo -e "${GREEN}${progress_prefix}處理完成！檔案已儲存至：$main_media_file${RESET}"
            log_message "SUCCESS" "${progress_prefix}處理完成 (無標準化)！檔案：$main_media_file"
        else
            echo -e "${RED}${progress_prefix}處理似乎已完成，但最終檔案 '$main_media_file' 未找到！${RESET}"
            log_message "ERROR" "${progress_prefix}處理完成但最終檔案未找到 (無標準化)"
            result=1
        fi
    else
        echo -e "${RED}${progress_prefix}處理失敗 (無標準化)！${RESET}"
        log_message "ERROR" "${progress_prefix}處理失敗 (無標準化)：$item_url"
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
# 處理其他網站媒體 (通用 MP3/MP4) - 支持批量下載 (含標準化)
############################################
process_other_site_media_playlist() {
    local input_url=""
    local choice_format=""
    local cf=""

    read -r -p "請輸入媒體網址 (單個或播放列表): " input_url
    if [ -z "$input_url" ]; then
        echo -e "${RED}錯誤：未輸入！${RESET}"
        return 1
    fi

    log_message "INFO" "處理通用媒體/列表：$input_url"
    echo -e "${YELLOW}處理通用媒體/列表：$input_url${RESET}"
    echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"

    while true; do
        local cfn
        read -r -p "選擇格式 (1: MP3, 2: MP4): " cfn
        case $cfn in
            1) cf="mp3"; break ;;
            2) cf="mp4"; break ;;
            *) echo -e "${RED}無效選項${RESET}" ;;
        esac
    done
    choice_format=$cf
    log_message "INFO" "選擇格式: $choice_format"

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

    echo -e "${YELLOW}檢測是否為列表...${RESET}"
    local item_list_json
    local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null)
    local jec=$?
    if [ $jec -ne 0 ]; then
        log_message "WARNING" "dump-json 失敗..."
    fi

    local item_urls=()
    local item_count=0
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url
            while IFS= read -r line; do
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    if [[ "$url" != "http"* ]]; then
                        local domain
                        domain=$(echo "$input_url" | grep -oE 'https?://[^/]+')
                        if [ -n "$domain" ]; then
                            url="${domain}${url}"
                        else
                            url="https://www.bilibili.com${url}"
                            log_message "WARNING" "無法從原始URL推斷域名，預設為 Bilibili 補全相對路徑: $url"
                        fi
                    fi
                    item_urls+=("$url")
                fi
            done <<< "$(echo "$item_list_json" | jq -c '. // empty | select(type == "object" and (.url != null))')"
            item_count=${#item_urls[@]}
            if [ "$item_count" -eq 0 ]; then
                log_message "WARNING" "透過 JQ 解析，未找到有效的 URL 項目。"
            fi
        else
            log_message "WARNING" "dump-json 成功，但輸出為空。"
        fi
    else
        log_message "WARNING" "未找到 jq，無法自動檢測列表項目 URL。將嘗試處理原始 URL。"
        item_count=0
    fi

    if [ "$item_count" -gt 1 ]; then
        log_message "INFO" "檢測到列表 ($item_count 項)。"
        echo -e "${CYAN}檢測到列表 ($item_count 項)。開始批量處理...${RESET}"
        local ci=0
        local success_count=0
        local fail_count=0
        local item_url_from_list
        for item_url_from_list in "${item_urls[@]}"; do
            ci=$((ci + 1))
            if _process_single_other_site "$item_url_from_list" "$choice_format" "$ci" "$item_count" "playlist_mode" "$template_playlist" "$template_single"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
            echo ""
        done
        echo -e "${GREEN}列表處理完成！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。${RESET}"
        log_message "SUCCESS" "列表 $input_url 完成！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。"

        local ovr=0
        if [ "$fail_count" -gt 0 ]; then ovr=1; fi
        local notification_title="媒體處理器：通用列表完成 (標準化)"
        local summary_msg="通用列表處理完成 ($success_count/$ci 成功)"
        _send_termux_notification "$ovr" "$notification_title" "$summary_msg" ""
    else
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理...${RESET}"
            input_url=${item_urls[0]}
        else
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL。"
            echo -e "${YELLOW}未檢測到列表，按單個處理...${RESET}"
        fi
        _process_single_other_site "$input_url" "$choice_format" "" "" "" "$template_playlist" "$template_single"
    fi
}

#######################################################
# 處理其他網站媒體 (無音量標準化) - 支持批量下載
#######################################################
process_other_site_media_playlist_no_normalize() {
    local input_url=""
    local choice_format=""
    local cf=""

    read -r -p "請輸入媒體網址 (單個或播放列表，無標準化): " input_url
    if [ -z "$input_url" ]; then
        echo -e "${RED}錯誤：未輸入！${RESET}"
        return 1
    fi

    log_message "INFO" "處理通用媒體/列表 (無標準化)：$input_url"
    echo -e "${YELLOW}處理通用媒體/列表 (無標準化)：$input_url${RESET}"
    echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"

    while true; do
        local cfn
        read -r -p "選擇下載偏好 (1: 音訊優先MP3, 2: 影片優先MP4): " cfn
        case $cfn in
            1) cf="mp3"; break ;;
            2) cf="mp4"; break ;;
            *) echo -e "${RED}無效選項${RESET}" ;;
        esac
    done
    choice_format=$cf
    log_message "INFO" "選擇格式 (無標準化): $choice_format"

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

    echo -e "${YELLOW}檢測是否為列表...${RESET}"
    local item_list_json
    local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null)
    local jec=$?
    if [ $jec -ne 0 ]; then
        log_message "WARNING" "dump-json 失敗..."
    fi

    local item_urls=()
    local item_count=0
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url
            while IFS= read -r line; do
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    if [[ "$url" != "http"* ]]; then
                        local domain
                        domain=$(echo "$input_url" | grep -oE 'https?://[^/]+')
                        if [ -n "$domain" ]; then
                            url="${domain}${url}"
                        else
                            url="https://www.bilibili.com${url}"
                            log_message "WARNING" "無法從原始URL推斷域名，預設為 Bilibili 補全相對路徑: $url"
                        fi
                    fi
                    item_urls+=("$url")
                fi
            done <<< "$(echo "$item_list_json" | jq -c '. // empty | select(type == "object" and (.url != null))')"
            item_count=${#item_urls[@]}
            if [ "$item_count" -eq 0 ]; then
                log_message "WARNING" "透過 JQ 解析，未找到有效的 URL 項目。"
            fi
        else
            log_message "WARNING" "dump-json 成功，但輸出為空。"
        fi
    else
        log_message "WARNING" "未找到 jq，無法自動檢測列表項目 URL。將嘗試處理原始 URL。"
        item_count=0
    fi

    if [ "$item_count" -gt 1 ]; then
        log_message "INFO" "檢測到列表 ($item_count 項，無標準化)。"
        echo -e "${CYAN}檢測到列表 ($item_count 項)。開始批量處理 (無標準化)...${RESET}"
        local ci=0
        local success_count=0
        local fail_count=0
        local item_url_from_list
        for item_url_from_list in "${item_urls[@]}"; do
            ci=$((ci + 1))
            if _process_single_other_site_no_normalize "$item_url_from_list" "$choice_format" "$ci" "$item_count" "playlist_mode" "$template_playlist" "$template_single"; then
                success_count=$((success_count + 1))
            else
                fail_count=$((fail_count + 1))
            fi
            echo ""
        done
        echo -e "${GREEN}列表處理完成 (無標準化)！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。${RESET}"
        log_message "SUCCESS" "列表 $input_url (無標準化) 完成！共 $ci 項，成功 $success_count 項，失敗 $fail_count 項。"

        local ovr=0
        if [ "$fail_count" -gt 0 ]; then ovr=1; fi
        local notification_title="媒體處理器：通用列表完成 (無標準化)"
        local summary_msg="通用列表處理完成 ($success_count/$ci 成功)"
        _send_termux_notification "$ovr" "$notification_title" "$summary_msg" ""
    else
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理 (無標準化)。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理 (無標準化)...${RESET}"
            input_url=${item_urls[0]}
        else
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL (無標準化)。"
            echo -e "${YELLOW}未檢測到列表，按單個處理 (無標準化)...${RESET}"
        fi
        _process_single_other_site_no_normalize "$input_url" "$choice_format" "" "" "" "$template_playlist" "$template_single"
    fi
}

# ==================================================
# === START REFACTORED YOUTUBE PLAYLIST HANDLING ===
# ==================================================
############################################
# 輔助函數：獲取播放清單影片數量
############################################
_get_playlist_video_count() {
    local url="$1"
    echo -e "${YELLOW}正在獲取播放清單項目總數...${RESET}"

    local count
    count=$(yt-dlp --no-warnings --print '%(playlist_count)s' "$url" 2>/dev/null | head -n 1)

    if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
        log_message "INFO" "透過 --print 成功獲取到 $count 個影片 for $url"
        echo "$count"
        return 0
    fi

    log_message "WARNING" "--print '%(playlist_count)s' 未能獲取數量，嘗試回退到 jq 方法..."
    local json_output
    json_output=$(yt-dlp --flat-playlist --dump-json "$url" 2>/dev/null)

    if [ -n "$json_output" ] && command -v jq &>/dev/null; then
        count=$(echo "$json_output" | jq -s 'length' 2>/dev/null)
        if [[ "$count" =~ ^[0-9]+$ && "$count" -gt 0 ]]; then
            log_message "INFO" "透過 jq 回退方法成功獲取到 $count 個影片 for $url"
            echo "$count"
            return 0
        fi
    fi

    log_message "ERROR" "無法獲取播放清單數量 for $url"
    echo ""
    return 1
}

###################################################################
# 輔助函數：處理 YouTube 播放清單通用流程 (含重試機制)
###################################################################
_process_youtube_playlist() {
    local playlist_url="$1"
    local single_item_processor_func_name="$2"
    log_message "INFO" "處理 YouTube 播放列表: $playlist_url (處理器: $single_item_processor_func_name)"

    echo -e "${YELLOW}正在獲取播放清單的影片 ID 列表 (穩健模式)...${RESET}"

    local id_list=""
    local attempts=3
    for (( i=1; i<=attempts; i++ )); do
        id_list=$(yt-dlp --flat-playlist --print '%(id)s' "$playlist_url" 2>/dev/null)

        if [ -n "$id_list" ]; then
            log_message "INFO" "在第 $i 次嘗試中成功獲取到影片 ID 列表。"
            break
        fi

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
    local line
    while IFS= read -r line; do
        [ -n "$line" ] && video_ids+=("$line")
    done <<< "$id_list"
    local total_videos=${#video_ids[@]}
    if [ "$total_videos" -eq 0 ]; then
        log_message "ERROR" "解析後，影片 ID 列表為空。"
        echo -e "${RED}錯誤：未找到任何有效的影片 ID。${RESET}"
        return 1
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
        processing_result=$("$single_item_processor_func_name" "$video_url" "playlist_mode" | tee /dev/tty | tail -n 1)
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
    local input
    read -p "輸入 YouTube 網址或本機路徑 [預設: $DEFAULT_URL]: " input
    input=${input:-$DEFAULT_URL}
    if [ -f "$input" ]; then
        process_local_mp3 "$input"
    elif [[ "$input" == *"list="* ]]; then
        _process_youtube_playlist "$input" "process_single_mp3"
    else
        process_single_mp3 "$input"
    fi
}

############################################
# 處理 MP3 音訊（無音量標準化，僅網路下載）
############################################
process_mp3_no_normalize() {
    local input
    read -p "輸入 YouTube 網址 [預設: $DEFAULT_URL]: " input
    input=${input:-$DEFAULT_URL}

    if [[ "$input" == *"list="* ]]; then
        _process_youtube_playlist "$input" "process_single_mp3_no_normalize"
    elif [[ "$input" == *"youtube.com"* || "$input" == *"youtu.be"* ]]; then
        process_single_mp3_no_normalize "$input"
    else
        echo -e "${RED}錯誤：此選項僅支援 YouTube 網址。${RESET}"
        log_message "ERROR" "MP3 無標準化：輸入非 YouTube URL 或本機路徑: $input"
        return 1
    fi
}

############################################
# 處理 MP4 影片（支援單一或播放清單、本機檔案）
############################################
process_mp4() {
    local input
    read -p "輸入 YouTube 網址或本機路徑 [預設: $DEFAULT_URL]: " input
    input=${input:-$DEFAULT_URL}

    if [ -f "$input" ]; then
        log_message "INFO" "process_mp4: 檢測到本機檔案 '$input'，將調用本機處理器。"
        process_local_mp4 "$input"
    elif [[ "$input" == *"list="* ]]; then
        log_message "INFO" "process_mp4: 檢測到播放列表 '$input'，將調用播放列表處理器。"
        _process_youtube_playlist "$input" "process_single_mp4"
    elif [[ "$input" == *"youtube.com"* || "$input" == *"youtu.be"* ]]; then
        log_message "INFO" "process_mp4: 檢測到單一 YouTube 影片 '$input'，將調用單項處理器。"
        process_single_mp4 "$input"
    else
        echo -e "${RED}錯誤：輸入的不是有效的 YouTube 網址或本機檔案路徑。${RESET}"
        log_message "ERROR" "process_mp4: 無效的輸入 '$input'"
        return 1
    fi
}

############################################
# 處理 MP4 影片（無音量標準化，僅網路下載）
############################################
process_mp4_no_normalize() {
    local input
    read -p "輸入 YouTube 網址 [預設: $DEFAULT_URL]: " input
    input=${input:-$DEFAULT_URL}
    if [[ "$input" == *"list="* ]]; then
        _process_youtube_playlist "$input" "process_single_mp4_no_normalize"
    elif [[ "$input" == *"youtu"* ]]; then
        process_single_mp4_no_normalize "$input"
    else
        echo -e "${RED}錯誤：僅支援 YouTube 網址。${RESET}"
        log_message "ERROR" "MP4 無標準化：輸入非 YouTube URL: $input"
        return 1
    fi
}

#######################################################
# MP4 無標準化指定時段下載的入口函數
#######################################################
process_mp4_sections_entry() {
    local input
    read -p "輸入 YouTube 影片網址 [預設: $DEFAULT_URL]: " input
    input=${input:-$DEFAULT_URL}

    if [[ "$input" == *"list="* ]]; then
        echo -e "${RED}錯誤：此功能（指定下載時段）目前僅支援單一 YouTube 影片，不支援播放列表。${RESET}"
        log_message "ERROR" "MP4 指定時段：使用者嘗試輸入播放列表 $input"
        return 1
    elif [[ "$input" == *"youtube.com"* || "$input" == *"youtu.be"* ]]; then
        local start_time end_time
        local is_valid_time=false
        while ! $is_valid_time; do
            read -p "輸入開始時間 (HH:MM:SS 或 秒數): " start_time
            if [ -z "$start_time" ]; then
                echo -e "${RED}錯誤：開始時間不能為空。${RESET}"
                continue
            fi
            if [[ "$start_time" =~ ^[0-9]+(:[0-5][0-9]){1,2}$ ]] || [[ "$start_time" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
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
            read -p "輸入結束時間 (HH:MM:SS 或 秒數，留空代表下載至結尾): " end_time
            if [ -z "$end_time" ]; then
                is_valid_time=true
                break
            fi
            if [[ "$end_time" =~ ^[0-9]+(:[0-5][0-9]){1,2}$ ]] || [[ "$end_time" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                if [[ "$end_time" =~ ^[0-9]+:[0-5][0-9]$ ]]; then
                    end_time="00:$end_time"
                fi
                is_valid_time=true
            else
                echo -e "${RED}錯誤：結束時間格式無效，請使用 HH:MM:SS、MM:SS 或純數字秒數，或留空。${RESET}"
            fi
        done

        log_message "INFO" "MP4 指定時段：URL='$input', Start='$start_time', End='$end_time'"
        process_single_mp4_no_normalize_sections "$input" "$start_time" "$end_time"
        return $?
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
    local input
    read -p "輸入 YouTube 網址 [預設: $DEFAULT_URL]: " input
    input=${input:-$DEFAULT_URL}

    if [ -f "$input" ]; then
        echo -e "${RED}錯誤：此功能目前僅支援處理 YouTube 網路影片以保留原始字幕。${RESET}"
        log_message "ERROR" "MKV 處理：使用者嘗試輸入本機檔案 $input"
        return 1
    fi

    if [[ "$input" == *"list="* ]]; then
        _process_youtube_playlist "$input" "process_single_mkv"
    elif [[ "$input" == *"youtu"* ]]; then
        process_single_mkv "$input"
    else
        echo -e "${RED}錯誤：僅支援 YouTube 網址。${RESET}"
        log_message "ERROR" "MKV 處理：輸入非 YouTube URL: $input"
        return 1
    fi
}

############################################
# 動態調整執行緒數量 (基於客觀 CPU 核心數比例計算)
############################################
adjust_threads() {
    local cpu_cores
    if command -v nproc &> /dev/null; then
        cpu_cores=$(nproc --all)
    elif [ -f /proc/cpuinfo ]; then
        cpu_cores=$(grep -c ^processor /proc/cpuinfo)
    elif command -v sysctl &> /dev/null && sysctl -n hw.ncpu > /dev/null 2>&1; then
        cpu_cores=$(sysctl -n hw.ncpu)
    else
        cpu_cores=4
        log_message "WARNING" "無法檢測 CPU 核心數，預設計算基於 4 核心。"
    fi

    if ! [[ "$cpu_cores" =~ ^[0-9]+$ ]] || [ "$cpu_cores" -lt 1 ]; then
        log_message "WARNING" "檢測到的 CPU 核心數 '$cpu_cores' 無效，預設計算基於 4 核心。"
        cpu_cores=4
    fi

    # 採用客觀的 75% 核心數配置執行緒，保留系統流暢度
    local recommended_threads=$(( cpu_cores * 3 / 4 ))

    if [ "$recommended_threads" -lt "$MIN_THREADS" ]; then
        recommended_threads=$MIN_THREADS
    elif [ "$recommended_threads" -gt "$MAX_THREADS" ]; then
        recommended_threads=$MAX_THREADS
    fi

    if [[ "$THREADS" != "$recommended_threads" ]]; then
        log_message "INFO" "執行緒自動調整：從 $THREADS -> $recommended_threads (基於 $cpu_cores 核心計算)"
        THREADS=$recommended_threads
        echo -e "${GREEN}執行緒已自動調整為 $THREADS (基於 CPU 核心數 $cpu_cores)${RESET}"
        save_config
    else
        log_message "INFO" "自動調整執行緒檢查：目前值 ($THREADS) 已是推薦值，無需更改。"
    fi
}

############################################
# 設定 Termux 啟動時詢問 (已修正財務腳本路徑變數定義)
############################################
setup_termux_autostart() {
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
    local confirm_setup
    read -p "您確定要繼續嗎？ (y/n): " confirm_setup
    echo ""

    if [[ ! "$confirm_setup" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消了 Termux 啟動設定。"
        echo -e "${YELLOW}已取消設定。${RESET}"
        return 1
    fi

    # 明確綁定主腳本與兩個財務分析腳本路徑
    local main_script_path="$SCRIPT_INSTALL_PATH"
    local tracker_script_path="$EXPENSE_TRACKER_SCRIPT_PATH"
    local calculator_script_path="$FINANCE_CALCULATOR_SCRIPT_PATH"

    local script_check_ok=true
    for script in "$main_script_path" "$tracker_script_path" "$calculator_script_path"; do
        if [ ! -f "$script" ]; then
            log_message "WARNING" "找不到腳本檔案 '$script'。"
            echo -e "${YELLOW}提示：目前目錄下尚未找到 '$(basename "$script")'，若僅使用主腳本可忽略此提示。${RESET}"
            if [[ "$script" == "$main_script_path" ]]; then
                echo -e "${RED}錯誤：找不到主腳本檔案 '$script'！${RESET}"
                script_check_ok=false
            fi
        elif [ ! -x "$script" ]; then
            echo -e "${YELLOW}正在設定 '$script' 的執行權限...${RESET}"
            if ! chmod +x "$script"; then
                log_message "ERROR" "無法設定 '$script' 的執行權限！"
                echo -e "${RED}錯誤：無法設定 '$script' 的執行權限！${RESET}"
                script_check_ok=false
            else
                log_message "INFO" "成功設定 '$script' 的執行權限。"
                echo -e "${GREEN}  > '$script' 權限設定成功。${RESET}"
            fi
        fi
    done

    if ! $script_check_ok; then
        echo -e "${RED}由於主腳本檔案缺失或權限問題，設定程序中止。${RESET}"
        return 1
    fi

    log_message "INFO" "開始設定 Termux 啟動腳本..."
    echo -e "${YELLOW}正在寫入設定到 ~/.bashrc ...${RESET}"

cat > ~/.bashrc << EOF
# ~/.bashrc - v4.1 (Multi-script Launcher)

# --- 整合式平台啟動設定 ---

# 1. 定義別名 (使用腳本實際安裝路徑)
alias media='$main_script_path'
alias track='python3 $tracker_script_path'
alias analyze='python3 $calculator_script_path'

# 2. 僅在交互式 Shell 啟動時顯示提示
if [[ \$- == *i* ]]; then
    CLR_RESET='\033[0m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[1;33m'
    CLR_RED='\033[0;31m'
    CLR_CYAN='\033[0;36m'
    CLR_PURPLE='\033[0;35m'
    CLR_BLUE='\033[0;34m'

    echo ""
    echo -e "\${CLR_CYAN}歡迎使用 Termux!\${CLR_RESET}"
    echo -e "\${CLR_YELLOW}是否要啟動平台工具？\${CLR_RESET}"
    echo -e "1) \${CLR_GREEN}啟動影音主腳本 (media)\${CLR_RESET}"
    echo -e "2) \${CLR_PURPLE}啟動月份支出追蹤器 (track)\${CLR_RESET}"
    echo -e "3) \${CLR_BLUE}啟動進階財務分析與預測器 (analyze)\${CLR_RESET}"
    echo -e "0) \${CLR_RED}不啟動 (稍後可手動執行)\${CLR_RESET}"

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

    if [ $? -eq 0 ]; then
        log_message "SUCCESS" "Termux 啟動設定已成功寫入 ~/.bashrc"
        echo -e "${GREEN}設定成功！${RESET}"
        echo -e "${CYAN}請重新啟動 Termux 或執行 'source ~/.bashrc' 來讓設定生效。${RESET}"
    else
        log_message "ERROR" "寫入 ~/.bashrc 失敗！"
        echo -e "${RED}錯誤：寫入設定失敗！請檢查權限。${RESET}"
        return 1
    fi

    return 0
}

############################################
# 財務分析與支出追蹤選單（保留之財務分析功能）
############################################
finance_menu() {
    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    fi

    while true; do
        clear
        echo -e "${CYAN}--- 財務分析與支出追蹤工具 ---${RESET}"
        echo -e "${YELLOW}請選擇要啟動的財務模組：${RESET}"
        echo -e " 1. ${PURPLE}啟動月份支出追蹤器${RESET} (monthly_expense_tracker.py)"
        echo -e " 2. ${BLUE}啟動進階財務分析與預測器${RESET} (finance_calculator.py)"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice
        read -rp "輸入選項 (0-2): " choice

        case $choice in
            1)
                if [ -z "$python_cmd" ]; then
                    echo -e "${RED}錯誤：找不到 Python 執行環境！${RESET}"
                elif [ ! -f "$EXPENSE_TRACKER_SCRIPT_PATH" ]; then
                    echo -e "${RED}錯誤：找不到月份支出追蹤器腳本 ($EXPENSE_TRACKER_SCRIPT_PATH)！${RESET}"
                else
                    log_message "INFO" "啟動月份支出追蹤器: $EXPENSE_TRACKER_SCRIPT_PATH"
                    "$python_cmd" "$EXPENSE_TRACKER_SCRIPT_PATH"
                fi
                echo ""; read -p "按 Enter 返回財務選單..."
                ;;
            2)
                if [ -z "$python_cmd" ]; then
                    echo -e "${RED}錯誤：找不到 Python 執行環境！${RESET}"
                elif [ ! -f "$FINANCE_CALCULATOR_SCRIPT_PATH" ]; then
                    echo -e "${RED}錯誤：找不到進階財務分析與預測器腳本 ($FINANCE_CALCULATOR_SCRIPT_PATH)！${RESET}"
                else
                    log_message "INFO" "啟動進階財務分析與預測器: $FINANCE_CALCULATOR_SCRIPT_PATH"
                    "$python_cmd" "$FINANCE_CALCULATOR_SCRIPT_PATH"
                fi
                echo ""; read -p "按 Enter 返回財務選單..."
                ;;
            0)
                return
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1; fi
                ;;
        esac
    done
}

####################################################################
# 觸發外部音訊豐富化模組的橋接函數
####################################################################
process_mp3_with_enrichment() {
    clear
    echo -e "${CYAN}--- MP3 下載與智慧型元數據豐富化 ---${RESET}"
    log_message "INFO" "使用者選擇 MP3 智慧型元數據豐富化功能。"

    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    else
        echo -e "${RED}錯誤：執行此功能需要 Python 環境！${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi

    local required_scripts=("$BASH_AUDIO_ENRICHER_SCRIPT_PATH" "$PYTHON_METADATA_ENRICHER_SCRIPT_PATH")
    for script_path in "${required_scripts[@]}"; do
        if [ ! -f "$script_path" ]; then
            echo -e "${RED}錯誤：找不到核心處理腳本 '$(basename "$script_path")'！${RESET}"
            read -p "按 Enter 返回..."
            return 1
        fi
        [ ! -x "$script_path" ] && chmod +x "$script_path"
    done

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
            echo -e "${RED}錯誤：自動安裝函式庫失敗！${RESET}"
            read -p "按 Enter 返回..."
            return 1
        else
            echo -e "${GREEN}函式庫安裝成功！${RESET}"
            sleep 1
        fi
    else
        echo -e "${GREEN}所有必要的 Python 函式庫均已安裝。${RESET}"
        sleep 0.5
    fi

    local input_url
    read -p "請輸入 YouTube 網址或本機檔案路徑: " input_url
    if [ -z "$input_url" ]; then
        echo -e "${YELLOW}未輸入任何內容，操作已取消。${RESET}"
        return 0
    fi

    echo -e "\n${YELLOW}正在將處理任務交由外部音訊豐富化模組...${RESET}"
    echo -e "${CYAN}-------------------------------------------------${RESET}"

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
# MP3 處理選單
############################################
mp3_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- MP3 相關處理 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 下載/處理 MP3 (${BOLD}含${RESET}音量標準化 / YouTube 或 本機檔案)"
        echo -e " 2. 下載 MP3 (${BOLD}無${RESET}音量標準化 / 僅限 YouTube)"
        echo -e " 3. ${CYAN}下載 MP3 (${BOLD}含${RESET}音量標準化 + ${PURPLE}MusicBrainz 智慧型元數據${RESET}${CYAN})${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice
        read -rp "輸入選項 (0-3): " choice

        case $choice in
            1)
                process_mp3
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            2)
                process_mp3_no_normalize
                echo ""; read -p "按 Enter 返回 MP3 選單..."
                ;;
            3)
                process_mp3_with_enrichment
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
# MP4 / MKV 處理選單
############################################
mp4_mkv_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- MP4 / MKV 相關處理 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 下載/處理 MP4 (${BOLD}含${RESET}音量標準化 / YouTube 或 本機檔案)"
        echo -e " 2. 下載 MP4 (${BOLD}無${RESET}音量標準化 / 僅限 YouTube)"
        echo -e " 3. 下載/處理 MKV (${BOLD}含${RESET}音量標準化 / 僅限 YouTube / 實驗性字幕保留)"
        echo -e " 4. 下載 MP4 (${BOLD}無${RESET}音量標準化 + ${YELLOW}指定時段${RESET} / 僅限單一 YouTube 影片)"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice
        read -rp "輸入選項 (0-4): " choice

        case $choice in
            1)
                process_mp4
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            2)
                process_mp4_no_normalize
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            3)
                process_mkv
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            4)
                process_mp4_sections_entry
                echo ""; read -p "按 Enter 返回 MP4/MKV 選單..."
                ;;
            0)
                return
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "MP4/MKV 選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}

############################################
# 通用媒體下載選單
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

        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice
        read -rp "輸入選項 (0-2): " choice

        case $choice in
            1)
                process_other_site_media_playlist
                echo ""; read -p "按 Enter 返回通用下載選單..."
                ;;
            2)
                process_other_site_media_playlist_no_normalize
                echo ""; read -p "按 Enter 返回通用下載選單..."
                ;;
            0)
                return
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "通用下載選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}

############################################
# 腳本設定與工具選單 (新增 yt-dlp 更新管道切換，移除無關同步設定)
############################################
utilities_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 腳本設定與工具 ---${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. 參數設定 (執行緒, 下載路徑, 顏色)"
        echo -e " 2. 檢視操作日誌"
        echo -e " 3. ${BOLD}檢查並更新依賴套件與 yt-dlp${RESET}"
        echo -e " 4. ${BOLD}檢查主腳本更新${RESET}"
        echo -e " 5. ${BOLD}設定日誌終端顯示級別${RESET}"
        echo -e " 6. ${BOLD}設定腳本自身更新渠道${RESET} (當前: ${GREEN}${UPDATE_CHANNEL:-stable}${RESET})"
        echo -e " 7. ${BOLD}設定 yt-dlp 更新管道${RESET} (當前: ${GREEN}${YTDLP_UPDATE_CHANNEL:-nightly}${RESET})"

        local termux_options_start_index=8
        local current_max_option=7

        if [[ "$OS_TYPE" == "termux" ]]; then
            echo -e " ${termux_options_start_index}. ${BOLD}設定 Termux 啟動時詢問${RESET} (含財務工具快捷啟動)"
            echo -e " $((termux_options_start_index + 1)). ${BOLD}完整更新 Termux 環境${RESET} (pkg update && upgrade)"
            current_max_option=$((termux_options_start_index + 1))
        fi
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回主選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice_prompt="輸入選項 (0-${current_max_option}): "
        local choice
        read -rp "$choice_prompt" choice

        case $choice in
            1) config_menu ;;
            2) view_log ;;
            3) update_dependencies ;;
            4) auto_update_script ;;
            5) configure_terminal_log_display_menu ;;
            6)
                clear
                echo -e "${CYAN}--- 設定腳本自身更新渠道 ---${RESET}"
                echo -e "選擇您希望接收的主腳本更新類型：\n"
                echo -e " 1. ${GREEN}stable (穩定版)${RESET}: 只接收 GitHub Release 標記的正式發布。"
                echo -e " 2. ${YELLOW}beta (預覽版)${RESET}:   接收開發主分支 (main) 的最新提交。"
                echo -e "\n 0. ${CYAN}取消${RESET}"

                local channel_choice
                read -p "請選擇 (當前為: ${UPDATE_CHANNEL:-stable}): " channel_choice

                case $channel_choice in
                    1)
                        UPDATE_CHANNEL="stable"
                        echo -e "${GREEN}腳本更新渠道已設定為 [穩定版 Stable]。${RESET}"
                        log_message "INFO" "腳本更新渠道已設定為 [stable]。"
                        save_config
                        ;;
                    2)
                        UPDATE_CHANNEL="beta"
                        echo -e "${YELLOW}腳本更新渠道已設定為 [預覽版 Beta]。${RESET}"
                        log_message "INFO" "腳本更新渠道已設定為 [beta]。"
                        save_config
                        ;;
                    0) echo -e "${CYAN}已取消設定。${RESET}" ;;
                    *) echo -e "${RED}無效選項。${RESET}" ;;
                esac
                sleep 1.5
                ;;
            7)
                clear
                echo -e "${CYAN}--- 設定 yt-dlp 更新管道 ---${RESET}"
                echo -e "選擇執行「更新依賴套件」時 yt-dlp 所追蹤的官方發布管道：\n"
                echo -e " 1. ${GREEN}nightly (每夜構建版 - 官方推薦)${RESET}: 每日發布，能最快修復 YouTube 等網站改版導致的下載失敗，且具備高穩定性。"
                echo -e " 2. ${YELLOW}stable (預設穩定版)${RESET}:          約每月發布一次，更新較慢，可能因網站改版而暫時失效。"
                echo -e "\n 0. ${CYAN}取消${RESET}"

                local ytdlp_choice
                read -p "請選擇 (當前為: ${YTDLP_UPDATE_CHANNEL:-nightly}): " ytdlp_choice

                case $ytdlp_choice in
                    1)
                        YTDLP_UPDATE_CHANNEL="nightly"
                        echo -e "${GREEN}yt-dlp 更新管道已設定為 [nightly 每夜構建版]。${RESET}"
                        log_message "INFO" "yt-dlp 更新管道已設定為 [nightly]。"
                        save_config
                        ;;
                    2)
                        YTDLP_UPDATE_CHANNEL="stable"
                        echo -e "${YELLOW}yt-dlp 更新管道已設定為 [stable 預設穩定版]。${RESET}"
                        log_message "INFO" "yt-dlp 更新管道已設定為 [stable]。"
                        save_config
                        ;;
                    0) echo -e "${CYAN}已取消設定。${RESET}" ;;
                    *) echo -e "${RED}無效選項。${RESET}" ;;
                esac
                sleep 1.5
                ;;
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
                    local confirm_full_termux_update
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
# 參數設定選單
############################################
config_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 參數設定選單 ---${RESET}"
        echo -e "${YELLOW}選擇項目：${RESET}"
        echo -e " 1. 設定執行緒 (當前: $THREADS)"
        echo -e " 2. 設定下載路徑 (當前: $DOWNLOAD_PATH)"
        echo -e " 3. 啟用/關閉顏色 (當前: $(if [ "$COLOR_ENABLED" = true ]; then echo '啟用'; else echo '關閉'; fi))"
        echo -e " 4. 自動調整執行緒 (依 CPU 核心數計算)"
        echo -e " 0. 返回上一層選單"
        local choice
        read -p "輸入選項 (0-4): " choice
        case $choice in
            1) configure_threads ;;
            2) configure_download_path ;;
            3) toggle_color ;;
            4) adjust_threads ;;
            0) return ;;
            *) echo -e "${RED}無效選項${RESET}"; sleep 1 ;;
        esac
        sleep 1
    done
}

############################################
# 設定執行緒數量
############################################
configure_threads() {
    local tt current_threads=$THREADS
    read -p "設定執行緒 ($MIN_THREADS-$MAX_THREADS) [當前: $current_threads]: " tt
    if [[ "$tt" =~ ^[0-9]+$ ]] && [ "$tt" -ge "$MIN_THREADS" ] && [ "$tt" -le "$MAX_THREADS" ]; then
        THREADS=$tt
        log_message "INFO" "使用者手動設定執行緒為 $THREADS"
        echo -e "${GREEN}執行緒設為 $THREADS${RESET}"
        save_config
    else
        echo -e "${RED}輸入無效或超出範圍 ($MIN_THREADS-$MAX_THREADS)。未作更改。${RESET}"
        log_message "WARNING" "使用者嘗試設定無效執行緒: $tt"
    fi
}

############################################
# 設定下載路徑 (安全性增強版)
############################################
configure_download_path() {
    local sanitized_path=""
    local user_path current_path=$DOWNLOAD_PATH

    read -e -p "設定下載路徑 [當前: $current_path]: " user_path
    user_path="${user_path:-$current_path}"

    if [[ "$user_path" == "$current_path" ]]; then
        echo -e "${YELLOW}路徑未更改。${RESET}"
        return 0
    fi

    sanitized_path=$(realpath -m "$user_path" 2>/dev/null | sed 's/[;|&<>()$`{}]//g')

    if [[ "$sanitized_path" =~ ^(/storage/emulated/0|/sdcard|$HOME|/data/data/com.termux/files/home) ]]; then
        if mkdir -p "$sanitized_path" 2>/dev/null && [ -w "$sanitized_path" ]; then
            DOWNLOAD_PATH="$sanitized_path"
            LOG_FILE="$DOWNLOAD_PATH/script_log.txt"
            log_message "INFO" "使用者手動設定下載路徑為：$sanitized_path"
            echo -e "${GREEN}下載路徑已成功更新為：$sanitized_path${RESET}"
            save_config
        else
            log_message "ERROR" "嘗試設定的路徑 '$sanitized_path' 無法創建或不可寫。"
            echo -e "${RED}錯誤：路徑 '$sanitized_path' 無法創建或不可寫！未作更改。${RESET}"
        fi
    else
        log_message "SECURITY" "使用者嘗試設定越界路徑 (原始: '$user_path', 清理後: '$sanitized_path')。已阻止。"
        echo -e "${RED}安全性錯誤：路徑必須在 Termux 儲存、用戶家目錄或 Termux 私有目錄範圍內！未作更改。${RESET}"
    fi
}

############################################
# 切換顏色輸出
############################################
toggle_color() {
    if [ "$COLOR_ENABLED" = true ]; then
        COLOR_ENABLED=false
        log_message "INFO" "使用者禁用顏色輸出"
        apply_color_settings
        echo "顏色輸出已禁用"
    else
        COLOR_ENABLED=true
        log_message "INFO" "使用者啟用顏色輸出"
        apply_color_settings
        echo -e "${GREEN}顏色輸出已啟用${RESET}"
    fi
    save_config
}

############################################
# 設定日誌終端顯示級別選單
############################################
configure_terminal_log_display_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 設定日誌終端顯示級別 ---${RESET}"
        echo -e "${YELLOW}選擇要切換顯示狀態的日誌級別：${RESET}"
        get_display_status() {
            if [[ "$1" == "true" ]]; then echo -e "${GREEN}顯示${RESET}"; else echo -e "${RED}隱藏${RESET}"; fi
        }

        echo -e " 1. INFO     級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_INFO")"
        echo -e " 2. WARNING  級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_WARNING")"
        echo -e " 3. ERROR    級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_ERROR")"
        echo -e " 4. SUCCESS  級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_SUCCESS")"
        echo -e " 5. DEBUG    級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_DEBUG")"
        echo -e " 6. SECURITY 級別終端顯示: $(get_display_status "$TERMINAL_LOG_SHOW_SECURITY")"
        echo -e "---------------------------------------------"
        echo -e " 7. ${GREEN}全部設定為顯示${RESET}"
        echo -e " 8. ${YELLOW}全部設定為隱藏 (除 ERROR 和 SECURITY 外)${RESET}"
        echo -e " 9. ${BLUE}恢復預設設定${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 0. ${YELLOW}返回上一層選單${RESET}"
        echo -e "---------------------------------------------"

        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice
        read -rp "輸入選項 (0-9): " choice

        case $choice in
            1) toggle_terminal_log_level "INFO" ;;
            2) toggle_terminal_log_level "WARNING" ;;
            3) toggle_terminal_log_level "ERROR" ;;
            4) toggle_terminal_log_level "SUCCESS" ;;
            5) toggle_terminal_log_level "DEBUG" ;;
            6) toggle_terminal_log_level "SECURITY" ;;
            7)
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
            8)
                TERMINAL_LOG_SHOW_INFO="false"
                TERMINAL_LOG_SHOW_WARNING="false"
                TERMINAL_LOG_SHOW_ERROR="true"
                TERMINAL_LOG_SHOW_SUCCESS="false"
                TERMINAL_LOG_SHOW_DEBUG="false"
                TERMINAL_LOG_SHOW_SECURITY="true"
                log_message "INFO" "大部分日誌級別的終端顯示已設為：隱藏 (ERROR, SECURITY 除外)"
                save_config
                echo -e "${YELLOW}大部分日誌級別的終端顯示已設為：隱藏 (ERROR, SECURITY 除外)${RESET}"; sleep 1
                ;;
            9)
                TERMINAL_LOG_SHOW_INFO="true"
                TERMINAL_LOG_SHOW_WARNING="true"
                TERMINAL_LOG_SHOW_ERROR="true"
                TERMINAL_LOG_SHOW_SUCCESS="true"
                TERMINAL_LOG_SHOW_DEBUG="false"
                TERMINAL_LOG_SHOW_SECURITY="true"
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
    local level_name="$1"
    local var_name="TERMINAL_LOG_SHOW_${level_name}"
    local current_status
    eval "current_status=\"\$$var_name\""

    if [[ "$current_status" == "true" ]]; then
        eval "$var_name=\"false\""
        echo -e "${level_name} 級別日誌終端顯示已切換為：${RED}隱藏${RESET}"
    else
        eval "$var_name=\"true\""
        echo -e "${level_name} 級別日誌終端顯示已切換為：${GREEN}顯示${RESET}"
    fi
    log_message "INFO" "${level_name} 級別日誌終端顯示切換為: ${!var_name}"
    save_config
    sleep 1
}

############################################
# 檢視日誌
############################################
view_log() {
    if [ -f "$LOG_FILE" ]; then
        less -R "$LOG_FILE"
    else
        echo -e "${RED}日誌不存在: $LOG_FILE ${RESET}"
        log_message "WARNING" "日誌不存在: $LOG_FILE"
        sleep 2
    fi
}

############################################
# 關於訊息 (顯示影音與財務模組組件狀態)
############################################
show_about_enhanced() {
    clear
    echo -e "${CYAN}=== 整合式進階多功能處理平台 ===${RESET}"
    echo -e "---------------------------------------------"

    local git_version_info=""
    if command -v git &> /dev/null && [ -d "$SCRIPT_DIR/.git" ]; then
        local git_tag
        git_tag=$(git -C "$SCRIPT_DIR" describe --tags --abbrev=0 2>/dev/null)
        local git_commit_hash
        git_commit_hash=$(git -C "$SCRIPT_DIR" log -1 --pretty=%h 2>/dev/null)
        if [ -n "$git_tag" ]; then
            git_version_info="$git_tag"
            if [ -n "$git_commit_hash" ]; then
                local commit_for_tag
                commit_for_tag=$(git -C "$SCRIPT_DIR" rev-list -n 1 "$git_tag" 2>/dev/null)
                local current_head
                current_head=$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)
                if [[ "$commit_for_tag" != "$current_head" ]]; then
                    git_version_info+=" (+${git_commit_hash})"
                fi
            fi
        elif [ -n "$git_commit_hash" ]; then
            git_version_info="commit ${git_commit_hash}"
        fi
    fi
    local display_version="${git_version_info:-$SCRIPT_VERSION}"
    echo -e "${BOLD}主腳本版本:${RESET}      ${GREEN}${display_version}${RESET}"
    if [ -n "$SCRIPT_UPDATE_DATE" ]; then
        echo -e "${BOLD}更新日期:${RESET}        ${GREEN}${SCRIPT_UPDATE_DATE}${RESET}"
    fi
    echo -e "${BOLD}腳本更新渠道:${RESET}    ${GREEN}${UPDATE_CHANNEL:-stable}${RESET}"
    echo -e "${BOLD}yt-dlp 更新管道:${RESET} ${GREEN}${YTDLP_UPDATE_CHANNEL:-nightly}${RESET}"
    echo -e "---------------------------------------------"

    echo -e "${CYAN}--- 腳本組件與環境狀態 ---${RESET}"

    display_status() {
        local item_name="$1"
        local status_ok="$2"
        local detail="$3"
        local name_field_width=32

        if [ "$status_ok" = true ]; then
            printf "%-${name_field_width}s ${GREEN}[✓] 正常 / 已安裝${RESET} ${GREEN}%s${RESET}\n" "${item_name}:" "$detail"
        else
            printf "%-${name_field_width}s ${RED}[✗] 異常 / 未找到${RESET} ${RED}%s${RESET}\n" "${item_name}:" "$detail"
        fi
    }

    echo -e "${YELLOW}核心輔助與財務腳本:${RESET}"
    local python_exec=""
    if command -v python3 &> /dev/null; then
        python_exec="python3"
    elif command -v python &> /dev/null; then
        python_exec="python"
    fi

    local estimator_status=false
    local estimator_version="N/A"
    if [ -n "$python_exec" ] && [ -f "$PYTHON_ESTIMATOR_SCRIPT_PATH" ]; then
        estimator_status=true
        estimator_version=$($python_exec "$PYTHON_ESTIMATOR_SCRIPT_PATH" --version 2>/dev/null | awk '{print $2}')
        [ -z "$estimator_version" ] && estimator_version="(已就緒)"
    fi
    display_status "  大小預估 (estimate_size.py)" "$estimator_status" "$estimator_version"

    local enricher_status=false
    [ -f "$BASH_AUDIO_ENRICHER_SCRIPT_PATH" ] && [ -f "$PYTHON_METADATA_ENRICHER_SCRIPT_PATH" ] && enricher_status=true
    display_status "  元數據豐富化模組" "$enricher_status" ""

    local invidious_status=false
    [ -f "$INVIDIOUS_DOWNLOADER_SCRIPT_PATH" ] && invidious_status=true
    display_status "  Invidious 後備下載模組" "$invidious_status" ""

    local tracker_status=false
    [ -f "$EXPENSE_TRACKER_SCRIPT_PATH" ] && tracker_status=true
    display_status "  月份支出追蹤器" "$tracker_status" ""

    local finance_status=false
    [ -f "$FINANCE_CALCULATOR_SCRIPT_PATH" ] && finance_status=true
    display_status "  進階財務分析與預測器" "$finance_status" ""

    echo -e "\n${YELLOW}外部核心工具:${RESET}"
    for tool in ffmpeg ffprobe jq curl bc aria2c git; do
        local tool_status=false
        local detail_text=""
        command -v "$tool" &> /dev/null && tool_status=true

        case "$tool" in
            "aria2c") detail_text="(用於 Bilibili 加速)" ;;
            "git")    detail_text="(用於版本更新)" ;;
        esac
        display_status "  $tool" "$tool_status" "$detail_text"
    done

    local py_status=false
    if [ -n "$python_exec" ]; then py_status=true; fi
    display_status "  Python ($python_exec)" "$py_status" "$($python_exec --version 2>&1 | head -n 1)"

    local ytdlp_status=false
    local ytdlp_version="N/A"
    if command -v yt-dlp &> /dev/null; then
        ytdlp_status=true
        ytdlp_version=$(yt-dlp --version 2>/dev/null || echo "無法獲取")
    fi
    display_status "  yt-dlp" "$ytdlp_status" "$ytdlp_version"

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
    if [ -n "$DOWNLOAD_PATH" ] && [ -d "$DOWNLOAD_PATH" ] && [ -w "$DOWNLOAD_PATH" ]; then
        dl_path_ok=true
    fi
    display_status "  下載目錄可寫" "$dl_path_ok" "$DOWNLOAD_PATH"

    echo -e "---------------------------------------------"
    echo -e "${CYAN}--- 授權資訊 ---${RESET}"
    echo -e "${BOLD}授權條款:${RESET}    創用 CC 姓名標示-非商業性-相同方式分享 4.0 國際 (CC BY-NC-SA 4.0)"
    echo -e "您得自由分享及改作本軟體，惟須遵守以下核心條件："
    echo -e "  - ${GREEN}姓名標示 (BY):${RESET} 應以合理方式標示著作人（adeend-co）。"
    echo -e "  - ${RED}非商業性 (NC):${RESET} 不得為商業目的利用本軟體。"
    echo -e "  - ${YELLOW}相同方式分享 (SA):${RESET} 改作後之著作須以相同或相容授權條款散布。"
    echo -e "完整授權條款請參閱專案根目錄之 ${WHITE}LICENSE${RESET} 檔案。"

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
# 環境檢查
############################################
check_environment() {
    local core_tools=("yt-dlp" "ffmpeg" "ffprobe" "jq" "curl" "bc")
    local missing_tools=()
    local python_cmd=""
    local check_failed=false

    echo -e "${CYAN}正在進行環境檢查...${RESET}"
    log_message "INFO" "開始環境檢查 (OS: $OS_TYPE)..."

    for tool in "${core_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
            echo -e "${YELLOW}  - 缺少: $tool ${RESET}"
            check_failed=true
        fi
    done

    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    else
        missing_tools+=("python/python3")
        echo -e "${YELLOW}  - 缺少: python 或 python3 ${RESET}"
        check_failed=true
    fi

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

    echo -e "${CYAN}正在檢查目錄權限...${RESET}"
    if [ -z "$DOWNLOAD_PATH" ]; then
        echo -e "${RED}錯誤：下載目錄路徑未設定！${RESET}"
        log_message "ERROR" "環境檢查失敗：下載目錄未設定。"
        check_failed=true
    elif ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建下載目錄：$DOWNLOAD_PATH ${RESET}"
        log_message "ERROR" "環境檢查失敗：無法創建下載目錄 $DOWNLOAD_PATH"
        check_failed=true
    elif [ ! -w "$DOWNLOAD_PATH" ]; then
        echo -e "${RED}錯誤：下載目錄不可寫：$DOWNLOAD_PATH ${RESET}"
        log_message "ERROR" "環境檢查失敗：下載目錄不可寫 $DOWNLOAD_PATH"
        check_failed=true
    else
        echo -e "${GREEN}  > 下載目錄 '$DOWNLOAD_PATH' 可寫。${RESET}"
    fi

    if [ -z "$TEMP_DIR" ]; then
        echo -e "${RED}錯誤：臨時目錄路徑未設定！${RESET}"
        log_message "ERROR" "環境檢查失敗：臨時目錄未設定。"
        check_failed=true
    elif ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建臨時目錄：$TEMP_DIR ${RESET}"
        log_message "ERROR" "環境檢查失敗：無法創建臨時目錄 $TEMP_DIR"
        check_failed=true
    elif [ ! -w "$TEMP_DIR" ]; then
        echo -e "${RED}錯誤：臨時目錄不可寫：$TEMP_DIR ${RESET}"
        log_message "ERROR" "環境檢查失敗：臨時目錄不可寫 $TEMP_DIR"
        check_failed=true
    else
        echo -e "${GREEN}  > 臨時目錄 '$TEMP_DIR' 可寫。${RESET}"
    fi

    if [ "$check_failed" = true ]; then
        log_message "ERROR" "環境檢查檢測到問題。"
        if [ ${#missing_tools[@]} -ne 0 ]; then
            echo -e "\n${YELLOW}檢測到缺少以下工具或庫：${RESET}"
            for tool in "${missing_tools[@]}"; do echo -e "${RED}  - $tool${RESET}"; done
            echo -e "\n${CYAN}安裝提示:${RESET}"
            if [[ "$OS_TYPE" == "termux" ]]; then
                echo -e "${GREEN}Termux: pkg install ffmpeg jq curl python bc aria2 git && pip install -U --pre \"yt-dlp[default]\"${RESET}"
            elif [[ "$OS_TYPE" == "wsl" || "$OS_TYPE" == "linux" ]]; then
                local install_cmd=""
                if [[ "$PACKAGE_MANAGER" == "apt" ]]; then install_cmd="sudo apt install -y ffmpeg jq curl bc aria2 git python3 python3-pip"
                elif [[ "$PACKAGE_MANAGER" == "dnf" ]]; then install_cmd="sudo dnf install -y ffmpeg jq curl bc aria2 git python3 python3-pip"
                elif [[ "$PACKAGE_MANAGER" == "yum" ]]; then install_cmd="sudo yum install -y ffmpeg jq curl bc aria2 git python3 python3-pip"
                fi

                if [ -n "$install_cmd" ]; then
                    echo -e "${GREEN}WSL/Linux ($PACKAGE_MANAGER): $install_cmd ; ${python_cmd:-python3} -m pip install --upgrade --pre \"yt-dlp[default]\"${RESET}"
                else
                    echo -e "${YELLOW}請參考您的 Linux 發行版文檔安裝 ffmpeg, jq, curl, bc, aria2, git, python3, pip，然後執行 pip install -U --pre \"yt-dlp[default]\"${RESET}"
                fi
            fi
        fi
        return 1
    fi

    log_message "INFO" "環境檢查通過。"
    echo -e "${GREEN}環境檢查通過。${RESET}"
    sleep 1
    return 0
}

####################################################################
# Invidious 後備方案入口 (整合智慧型元數據豐富化)
####################################################################
process_invidious_entry() {
    clear
    echo -e "${CYAN}--- Invidious 後備下載方案 (含智慧型元數據) ---${RESET}"
    log_message "INFO" "使用者啟動 Invidious 後備下載方案 (含元數據豐富化)。"

    local python_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
    elif command -v python &> /dev/null; then
        python_cmd="python"
    fi
    if [ -z "$python_cmd" ]; then
        echo -e "${RED}錯誤：此功能需要 Python！${RESET}"
        read -p "按 Enter 返回..."
        return 1
    fi
    if ! $python_cmd -c "import requests" &>/dev/null; then
        echo -e "${YELLOW}偵測到缺少 'requests' 函式庫，正在嘗試自動安裝...${RESET}"
        if ! $python_cmd -m pip install --upgrade requests; then
            echo -e "${RED}錯誤：自動安裝 'requests' 失敗！${RESET}"
            read -p "按 Enter 返回..."
            return 1
        fi
    fi

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
        [ ! -x "$script_path" ] && chmod +x "$script_path"
    done

    local input_url
    read -p "請輸入 YouTube 影片網址: " input_url
    if [ -z "$input_url" ]; then
        echo -e "${YELLOW}已取消。${RESET}"
        return 0
    fi

    echo -e "\n${CYAN}>>> 階段一：呼叫 Invidious 下載器獲取原始音訊...${RESET}"
    local temp_dir_invidious
    temp_dir_invidious=$(mktemp -d)
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

    echo -e "\n${CYAN}>>> 階段二：將原始音訊交給【智慧型元數據豐富化模組】進行完整處理...${RESET}"
    echo -e "${CYAN}-------------------------------------------------${RESET}"

    DOWNLOAD_PATH="$DOWNLOAD_PATH" \
    "$BASH_AUDIO_ENRICHER_SCRIPT_PATH" "$raw_audio_file"

    local enricher_exit_code=$?

    echo -e "${CYAN}-------------------------------------------------${RESET}"

    if [ $enricher_exit_code -eq 0 ]; then
        log_message "SUCCESS" "Invidious 流程 -> 智慧型元數據豐富化模組處理成功。"
        echo -e "${GREEN}Invidious 流程處理完成！${RESET}"
    else
        log_message "ERROR" "Invidious 流程 -> 智慧型元數據豐富化模組處理失敗，退出碼: $enricher_exit_code"
        echo -e "${RED}錯誤：後續的智慧型處理流程失敗！請檢查上方日誌。${RESET}"
    fi

    log_message "INFO" "Invidious 流程：清理最外層臨時目錄 $temp_dir_invidious"
    rm -rf "$temp_dir_invidious"
    read -p "按 Enter 返回..."
}

############################################
# 主選單 (移除倒數計時、同步與彩蛋，整合財務分析選單)
############################################
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 整合式進階多功能處理平台(IAVPP) ${SCRIPT_VERSION} ===${RESET}"
        echo -e "${YELLOW}請選擇主要功能分類：${RESET}"
        echo -e " 1. ${BOLD}MP3 相關處理${RESET} (YouTube/本機)"
        echo -e " 2. ${BOLD}MP4 / MKV 相關處理${RESET} (YouTube/本機)"
        echo -e " 3. ${BOLD}通用媒體下載${RESET} (其他網站 / ${YELLOW}實驗性${RESET})"
        echo -e " 4. ${CYAN}${BOLD}Invidious 後備下載方案${RESET} (yt-dlp 失效時使用)"
        echo -e " 5. ${PURPLE}${BOLD}財務分析與支出追蹤工具${RESET}"
        echo -e "---------------------------------------------"
        echo -e " 6. ${BOLD}腳本設定與工具${RESET}"
        echo -e " 7. ${BOLD}關於此工具${RESET}"
        echo -e " 0. ${RED}退出腳本${RESET}"
        echo -e "---------------------------------------------"
        read -t 0.1 -N 10000 discard 2>/dev/null || true
        local choice
        read -rp "輸入選項 (0-7): " choice

        case $choice in
            1) mp3_menu ;;
            2) mp4_mkv_menu ;;
            3) general_download_menu ;;
            4) process_invidious_entry ;;
            5) finance_menu ;;
            6) utilities_menu ;;
            7) show_about_enhanced ;;
            0)
                echo -e "${GREEN}感謝使用，正在退出...${RESET}"
                log_message "INFO" "使用者選擇退出。"
                sleep 1
                exit 0
                ;;
            *)
                if [[ -z "$choice" ]]; then continue; else echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "主選單輸入無效選項: $choice"; sleep 1; fi
                ;;
        esac
    done
}

######################################################################
# 處理首次運行同意條款 (分層式條款與二次確認)
######################################################################
handle_first_run_agreement() {
    if [[ "${AGREED_TERMS_VERSION}" == "${AGREEMENT_VERSION}" ]]; then
        log_message "DEBUG" "使用者已同意版本 ${AGREEMENT_VERSION} 的條款，跳過同意程序。"
        return 0
    fi

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
請使用方向鍵閱讀全文。閱讀完畢後，請按 'q' 鍵退出。
${RESET}
" | less -R
        read -p "您已閱讀完畢詳細條款，按 Enter 鍵返回主同意畫面..."
    }

    while true; do
        clear
        if [[ -n "${AGREED_TERMS_VERSION}" ]]; then
            echo -e "${YELLOW}======================================================================="
            echo -e "      軟體使用條款已更新，請您重新閱讀並同意 (版本 ${AGREEMENT_VERSION})。"
            echo -e "=======================================================================${RESET}"
        fi

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
        echo -e "${YELLOW}請選擇：${RESET}"
        echo -e "  1) ${GREEN}我已閱讀並同意上述所有條款${RESET}"
        echo -e "  2) ${CYAN}查閱詳細使用條款${RESET}"
        echo -e "  0) ${RED}我不同意，退出軟體${RESET}"

        local choice
        read -p "請輸入您的選擇 (0-2)：" choice

        case "$choice" in
            1)
                clear
                echo -e "${YELLOW}--- 請再次確認 ---${RESET}"
                echo ""
                echo -e "您即將同意「整合式進階多功能處理平台 v${AGREEMENT_VERSION}」的使用條款。"
                echo -e "這表示您理解並接受所有相關的權利、義務與風險。"
                echo ""
                local confirm
                read -p "確定要同意並繼續使用嗎？ (y/n): " confirm

                if [[ "$(echo "$confirm" | tr '[:upper:]' '[:lower:]')" == "y" ]]; then
                    AGREED_TERMS_VERSION="${AGREEMENT_VERSION}"
                    save_config
                    echo ""
                    echo -e "${GREEN}感謝您的同意。正在繼續啟動腳本...${RESET}"
                    sleep 1
                    clear
                    return 0
                else
                    echo ""
                    echo -e "${YELLOW}已取消同意。返回上一層選項...${RESET}"
                    sleep 2
                fi
                ;;
            2)
                _display_full_terms
                ;;
            0)
                echo ""
                echo -e "${RED}您選擇了不同意條款。軟體即將退出...${RESET}"
                sleep 2
                exit 0
                ;;
            *)
                echo ""
                echo -e "${RED}無效的選項，請重新輸入。${RESET}"
                sleep 1.5
                ;;
        esac
    done
}

####################################################################
# 主程式 (啟動初始化、環境檢查與進入主選單)
####################################################################
main() {
    # --- 步驟 1：處理特殊健康檢查模式 ---
    if [[ "$1" == "--health-check" ]]; then
        exit 0
    fi

    # --- 步驟 2：核心變數與路徑初始化 ---
    detect_platform_and_set_vars

    DOWNLOAD_PATH="$DOWNLOAD_PATH_DEFAULT"
    TEMP_DIR="$TEMP_DIR_DEFAULT"

    load_config

    LOG_FILE="$DOWNLOAD_PATH/script_log.txt"

    apply_color_settings

    # --- 步驟 3：處理首次運行同意程序 ---
    handle_first_run_agreement

    if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null || ! mkdir -p "$TEMP_DIR" 2>/dev/null; then
        echo -e "${RED}嚴重錯誤：無法創建下載目錄或臨時目錄！請檢查權限。${RESET}" >&2
        echo -e "下載目錄: $DOWNLOAD_PATH" >&2
        echo -e "臨時目錄: $TEMP_DIR" >&2
        exit 1
    fi

    # --- 步驟 4：記錄日誌並進行環境驗證 ---
    log_message "INFO" "腳本啟動 (版本: $SCRIPT_VERSION, OS: $OS_TYPE, Config: $CONFIG_FILE)"

    if ! check_environment; then
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

            if ! check_environment; then
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
main "$@"
