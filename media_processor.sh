#!/bin/bash

# 腳本設定
SCRIPT_VERSION="v2.0.6(Experimental)" # <<< 版本號更新
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
# <<< 修改：載入設定檔 (加入 Python 版本) >>>
############################################
load_config() {
    # <<< 新增：先設定 Python 腳本的預設版本 >>>
    PYTHON_CONVERTER_VERSION="0.0.0" # 確保即使設定檔不存在也有預設值

    if [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ]; then
        log_message "INFO" "正在從 $CONFIG_FILE 載入設定..."
        source "$CONFIG_FILE"
        # 檢查 THREADS (不變)
        if [[ -n "$THREADS" && (! "$THREADS" =~ ^[0-9]+$ || "$THREADS" -lt "$MIN_THREADS" || "$THREADS" -gt "$MAX_THREADS") ]]; then
             log_message "WARNING" "從設定檔載入的 THREADS ($THREADS) 無效，將使用預設值或重新自動調整。"
             THREADS=$MIN_THREADS 
        fi
        # <<< 新增：檢查載入的 Python 版本 (基礎檢查) >>>
        if [ -z "$PYTHON_CONVERTER_VERSION" ]; then
            log_message "WARNING" "設定檔中未找到 Python 轉換器版本，將使用預設值 0.0.0"
            PYTHON_CONVERTER_VERSION="0.0.0"
        fi
        log_message "INFO" "設定檔載入完成。 Python Converter Version: $PYTHON_CONVERTER_VERSION"
        echo -e "${GREEN}已從 $CONFIG_FILE 載入使用者設定。${RESET}"
        sleep 1
    else
        log_message "INFO" "設定檔 $CONFIG_FILE 未找到或不可讀，將使用預設設定。"
        # 即使設定檔不存在，也要確保 Python 版本有初始值
        PYTHON_CONVERTER_VERSION="0.0.0"
    fi

    # <<< 重要：在載入 DOWNLOAD_PATH 後，重新設定 LOG_FILE 路徑 >>>
    # 無論是從設定檔載入還是使用預設值，都要確保 LOG_FILE 路徑正確
    LOG_FILE="$DOWNLOAD_PATH/script_log.txt"
    # 同樣，需要重新確保目錄存在
    if ! mkdir -p "$DOWNLOAD_PATH" 2>/dev/null; then
        echo -e "${RED}錯誤：無法創建最終確定的下載目錄 '$DOWNLOAD_PATH'！腳本無法啟動。${RESET}" >&2
        log_message "ERROR" "無法創建最終下載目錄：$DOWNLOAD_PATH"
        exit 1
    fi
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
# <<< 修改：檢查並更新依賴套件 (加入 Python 轉換器更新) >>>
############################################
update_dependencies() {
    local pkg_tools=("ffmpeg" "jq" "curl" "python" "mkvtoolnix") # <<< 新增 mkvtoolnix
    local pip_tools=("yt-dlp" "webvtt-py")                 # <<< 新增 webvtt-py
    # <<< 修改：加入 python 和 webvtt-py 到驗證列表 >>>
    local all_tools=("${pkg_tools[@]}" "${pip_tools[@]}" "ffprobe" "mkvextract" "python") 
    local update_failed=false
    local missing_after_update=()

    clear
    echo -e "${CYAN}--- 開始檢查並更新依賴套件 ---${RESET}"
    log_message "INFO" "使用者觸發依賴套件更新流程。"

    # 1. 更新系統套件列表 (根據檢測到的管理器)
    echo -e "${YELLOW}[1/5] 正在更新系統套件列表 ($PACKAGE_MANAGER update)...${RESET}"
    if sudo "$PACKAGE_MANAGER" update -y; then # 假設需要 sudo (WSL/Linux)
        log_message "INFO" "$PACKAGE_MANAGER update 成功"
        echo -e "${GREEN}  > 系統套件列表更新成功。${RESET}"
    else
        # Termux 通常不需要 sudo，嘗試不用 sudo
         if "$PACKAGE_MANAGER" update -y; then
             log_message "INFO" "$PACKAGE_MANAGER update 成功 (無需 sudo)"
             echo -e "${GREEN}  > 系統套件列表更新成功。${RESET}"
         else
            log_message "WARNING" "$PACKAGE_MANAGER update 失敗，可能無法獲取最新套件版本。"
            echo -e "${RED}  > 警告：系統套件列表更新失敗，將嘗試使用現有列表。${RESET}"
            update_failed=true 
         fi
    fi
    echo "" 

    # 2. 安裝/更新系統套件
    echo -e "${YELLOW}[2/5] 正在安裝/更新系統套件: ${pkg_tools[*]}...${RESET}"
    if sudo "$PACKAGE_MANAGER" install -y "${pkg_tools[@]}"; then
        log_message "INFO" "安裝/更新 ${pkg_tools[*]} 成功"
        echo -e "${GREEN}  > 安裝/更新 ${pkg_tools[*]} 完成。${RESET}"
    else
         if "$PACKAGE_MANAGER" install -y "${pkg_tools[@]}"; then
              log_message "INFO" "安裝/更新 ${pkg_tools[*]} 成功 (無需 sudo)"
              echo -e "${GREEN}  > 安裝/更新 ${pkg_tools[*]} 完成。${RESET}"
         else
            log_message "ERROR" "安裝/更新 ${pkg_tools[*]} 失敗！"
            echo -e "${RED}  > 錯誤：安裝/更新 ${pkg_tools[*]} 失敗！${RESET}"
            update_failed=true
         fi
    fi
    echo ""

    # 3. 更新 pip 和 Python 套件
    echo -e "${YELLOW}[3/5] 正在更新 pip 及 Python 套件: ${pip_tools[*]}...${RESET}"
    local python_cmd pip_cmd
    if command -v python3 &> /dev/null; then python_cmd="python3"; else python_cmd="python"; fi
    
    if command -v $python_cmd &> /dev/null; then
         pip_cmd="$python_cmd -m pip"
         # 嘗試升級 pip 本身
         echo -e "${YELLOW}  > 正在嘗試更新 pip...${RESET}"
         if $pip_cmd install --upgrade pip &> /dev/null; then
             log_message "INFO" "pip 更新成功"
             echo -e "${GREEN}    > pip 更新成功。${RESET}"
         else
             log_message "WARNING" "pip 更新可能失敗，繼續嘗試安裝套件。"
             echo -e "${YELLOW}    > pip 更新可能失敗，繼續...${RESET}"
         fi

         # 安裝/更新指定的 pip 套件
         echo -e "${YELLOW}  > 正在安裝/更新 ${pip_tools[*]}...${RESET}"
         # 可能需要 --user (WSL/Linux) 或不需要 (Termux)
         if $pip_cmd install --upgrade --user "${pip_tools[@]}"; then 
             log_message "INFO" "更新 ${pip_tools[*]} 成功 (--user)"
             echo -e "${GREEN}    > 更新 ${pip_tools[*]} 完成。${RESET}"
         elif $pip_cmd install --upgrade "${pip_tools[@]}"; then
             log_message "INFO" "更新 ${pip_tools[*]} 成功 (無需 --user)"
             echo -e "${GREEN}    > 更新 ${pip_tools[*]} 完成。${RESET}"
         else
             log_message "ERROR" "更新 ${pip_tools[*]} 失敗！"
             echo -e "${RED}    > 錯誤：更新 ${pip_tools[*]} 失敗！${RESET}"
             update_failed=true
         fi
    else
        log_message "ERROR" "找不到 $python_cmd 命令，無法更新 ${pip_tools[*]}。"
        echo -e "${RED}  > 錯誤：找不到 Python 命令，無法更新 ${pip_tools[*]}。請確保步驟 2 已成功安裝 python。${RESET}"
        update_failed=true
    fi
    echo ""

    # <<< 新增：4. 更新 Python 字幕轉換器 >>>
    echo -e "${YELLOW}[4/5] 正在檢查並更新 Python 字幕轉換器...${RESET}"
    if ! update_python_converter; then
        log_message "WARNING" "Python 字幕轉換器更新失敗或未完成。"
        # 不將此標記為致命錯誤 (update_failed=true)，因為主腳本仍可運行
    fi
    echo ""

# 5. 最終驗證所有工具
    echo -e "${YELLOW}[5/5] 正在驗證所有必要工具是否已安裝...${RESET}"
    local python_cmd # 確保 python_cmd 在循環外定義
    if command -v python3 &> /dev/null; then python_cmd="python3"; elif command -v python &> /dev/null; then python_cmd="python"; else python_cmd=""; fi

    for tool in "${all_tools[@]}"; do
        # --- 修正後的條件判斷 ---
        if ! command -v "$tool" &> /dev/null; then
            # 如果工具命令找不到
            if [[ "$tool" == "python" ]]; then
                 # 特殊處理 python: 如果 'python' 命令本身找不到，
                 # 並且之前檢測到的 python_cmd (python3 或 python) 也為空，
                 # 才報告缺少 python/python3
                 if [ -z "$python_cmd" ]; then 
                      missing_after_update+=("python/python3")
                      echo -e "${RED}  > 驗證失敗：找不到 python 或 python3 ${RESET}"
                 else
                     # 雖然 'python' 命令找不到，但找到了 python3，所以 Python 環境是 OK 的
                     # 避免重複報告找到 python3，這裡可以不輸出或輸出找到 python_cmd
                      : # Do nothing, or echo "${GREEN} > 驗證成功：找到 $python_cmd ${RESET}" (可能會重複)
                 fi
            else
                 # 其他工具找不到，直接報告缺少
                 missing_after_update+=("$tool")
                 echo -e "${RED}  > 驗證失敗：找不到 $tool ${RESET}"
            fi
        else
             # 如果工具命令找到了
             if [[ "$tool" == "python" && -n "$python_cmd" && "$tool" != "$python_cmd" ]]; then
                  # 如果當前檢查的是 'python' 但我們實際用的是 'python3'，
                  # 可以選擇性跳過 'python' 的成功輸出，避免混淆
                  : # Do nothing
             else
                  # 正常輸出找到工具 (包括找到 python3 或 python)
                  echo -e "${GREEN}  > 驗證成功：找到 $tool ${RESET}"
             fi
        fi
        # --- 結束修正 ---
    done
    
    # 檢查 webvtt-py 庫 (這部分邏輯不變)
    if [ -n "$python_cmd" ]; then # 確保 python_cmd 不是空的
        if $python_cmd -c "import webvtt" &> /dev/null; then
             echo -e "${GREEN}  > 驗證成功：找到 Python 庫 webvtt-py ${RESET}"
        else
             missing_after_update+=("Python 庫: webvtt-py")
             echo -e "${RED}  > 驗證失敗：找不到 Python 庫 webvtt-py (請執行: pip install webvtt-py) ${RESET}"
        fi
    # else # 如果 python_cmd 為空（即 python/python3 都沒找到），上面已經報錯了，這裡不用再處理庫
    #    missing_after_update+=("Python 庫: webvtt-py (因缺少Python)")
    #    echo -e "${RED}  > 驗證失敗：因缺少 Python，無法檢查 webvtt-py 庫 ${RESET}"
    fi
    echo ""


    # 總結結果
    if [ ${#missing_after_update[@]} -ne 0 ]; then
        log_message "ERROR" "更新流程完成後，仍然缺少工具: ${missing_after_update[*]}"
        echo -e "${RED}--- 更新結果：失敗 ---${RESET}"
        echo -e "${RED}更新/安裝後，仍然缺少以下必要工具：${RESET}"
        for tool in "${missing_after_update[@]}"; do
            echo -e "${YELLOW}  - $tool${RESET}"
        done
        echo -e "${CYAN}請檢查網路連線或嘗試手動安裝。${RESET}"
    elif [ "$update_failed" = true ]; then
        log_message "WARNING" "更新流程完成，但過程中出現錯誤。工具似乎已存在，可能不是最新版本。"
        echo -e "${YELLOW}--- 更新結果：部分成功 ---${RESET}"
        echo -e "${YELLOW}更新過程中出現一些錯誤，但所有必要工具似乎都已安裝。${RESET}"
        echo -e "${YELLOW}可能部分工具未能更新到最新版本。${RESET}"
    else
        log_message "SUCCESS" "所有依賴套件均已成功檢查並更新/安裝。"
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
############################################
process_single_mp3() {
    # --- 函數邏輯不變 ---
    local media_url="$1"
    local temp_dir=$(mktemp -d)
    local audio_file=""
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local base_name=""
    local result=0
    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH"; echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${YELLOW}處理 YouTube 媒體：$media_url${RESET}"
    log_message "INFO" "處理 YouTube 媒體：$media_url"
    echo -e "${YELLOW}正在分析媒體資訊...${RESET}"
    local video_title=$(yt-dlp --get-title "$media_url" 2>/dev/null)
    if [ -z "$video_title" ]; then log_message "ERROR" "無法獲取媒體標題"; echo -e "${RED}錯誤：無法獲取媒體標題，請檢查網址是否正確${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${YELLOW}開始下載：$video_title${RESET}"
    local output_template="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    local yt_dlp_dl_args=(yt-dlp -f bestaudio -o "$output_template" "$media_url" --newline --progress --concurrent-fragments "$THREADS")
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp.log"; then log_message "ERROR" "音訊下載失敗，詳見 $temp_dir/yt-dlp.log"; echo -e "${RED}錯誤：音訊下載失敗${RESET}"; cat "$temp_dir/yt-dlp.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    local yt_dlp_fn_args=(yt-dlp --get-filename -f bestaudio -o "$output_template" "$media_url")
    audio_file=$("${yt_dlp_fn_args[@]}")
    if [ ! -f "$audio_file" ]; then log_message "ERROR" "音訊下載失敗！找不到檔案 '$audio_file'"; echo -e "${RED}錯誤：找不到下載的檔案${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    base_name=$(basename "$audio_file" | sed 's/\.[^.]*$//')
    local metadata_json=$(yt-dlp --dump-json "$media_url" 2>/dev/null)
    if [ -n "$metadata_json" ]; then artist_name=$(echo "$metadata_json" | jq -r '.artist // .uploader // "[不明]"'); album_artist_name=$(echo "$metadata_json" | jq -r '.uploader // "[不明]"'); fi
    [[ "$artist_name" == "null" ]] && artist_name="[不明]"
    [[ "$album_artist_name" == "null" ]] && album_artist_name="[不明]"
    local cover_image="$temp_dir/${base_name}_cover.png"
    echo -e "${YELLOW}下載封面圖片...${RESET}"
    if ! download_high_res_thumbnail "$media_url" "$cover_image"; then cover_image=""; fi
    local output_audio="$DOWNLOAD_PATH/${base_name}_normalized.mp3"
    local normalized_temp="$temp_dir/temp_normalized.mp3"
    echo -e "${YELLOW}開始音量標準化...${RESET}"
    if normalize_audio "$audio_file" "$normalized_temp" "$temp_dir" false; then
        echo -e "${YELLOW}正在加入封面和元數據...${RESET}"
        local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_temp")
        if [ -n "$cover_image" ] && [ -f "$cover_image" ]; then
            ffmpeg_embed_args+=(-i "$cover_image" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic)
        else
            ffmpeg_embed_args+=(-c copy -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name")
        fi
        ffmpeg_embed_args+=("$output_audio")
        if ! "${ffmpeg_embed_args[@]}" > /dev/null 2>&1; then log_message "ERROR" "加入封面和元數據失敗！"; echo -e "${RED}錯誤：加入封面和元數據失敗${RESET}"; result=1;
        else echo -e "${GREEN}封面和元數據加入完成${RESET}"; result=0; fi
    else log_message "ERROR" "音量標準化失敗！"; result=1; fi
    [ -f "$audio_file" ] && safe_remove "$audio_file"; safe_remove "${audio_file%.*}".*; safe_remove "$normalized_temp"
    [ -n "$cover_image" ] && [ -f "$cover_image" ] && safe_remove "$cover_image"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    if [ $result -eq 0 ]; then echo -e "${GREEN}處理完成！音量標準化後的高品質音訊已儲存至：$output_audio${RESET}"; log_message "SUCCESS" "處理完成！音量標準化後的高品質音訊已儲存至：$output_audio";
    else echo -e "${RED}處理失敗！${RESET}"; log_message "ERROR" "處理失敗：$media_url"; fi
    return $result
}

############################################
# 處理單一 YouTube 影片（MP4）下載與處理
############################################
process_single_mp4() {
    # --- 函數邏輯不變 ---
    local video_url="$1"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt"
    local subtitle_files=()
    local temp_dir=$(mktemp -d)
    local result=0
    echo -e "${YELLOW}處理 YouTube 影片：$video_url${RESET}"
    log_message "INFO" "處理 YouTube 影片: $video_url"; log_message "INFO" "將嘗試請求以下字幕: $target_sub_langs"
    echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕...${RESET}"
    local format_option="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/best[ext=mp4]"
    if [[ "$video_url" != *"youtube.com"* && "$video_url" != *"youtu.be"* ]]; then
        format_option="best"; log_message "WARNING" "...非 YouTube URL..."; subtitle_options=""; echo -e "${YELLOW}非 YouTube URL...${RESET}";
    fi
    log_message "INFO" "使用格式: $format_option"
    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${YELLOW}開始下載影片及字幕...${RESET}"
    local output_template="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    local yt_dlp_dl_args=(yt-dlp -f "$format_option")
    IFS=' ' read -r -a sub_opts_array <<< "$subtitle_options"; if [ ${#sub_opts_array[@]} -gt 0 ]; then yt_dlp_dl_args+=("${sub_opts_array[@]}"); fi
    yt_dlp_dl_args+=(-o "$output_template" "$video_url" --newline --progress --concurrent-fragments "$THREADS")
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-video.log"; then log_message "ERROR" "影片下載失敗..."; echo -e "${RED}錯誤：影片下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-video.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    local yt_dlp_fn_args=(yt-dlp --get-filename -f "$format_option" -o "$output_template" "$video_url")
    local video_file=$("${yt_dlp_fn_args[@]}" 2>/dev/null)
    if [ ! -f "$video_file" ]; then log_message "ERROR" "找不到下載的影片檔案..."; echo -e "${RED}錯誤：找不到下載的影片檔案！${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${GREEN}影片下載完成：$video_file${RESET}"; log_message "INFO" "影片下載完成：$video_file"
    local base="${video_file%.*}"; subtitle_files=()
    log_message "INFO" "檢查字幕 (基於: $base.*.srt)"
    IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
    for lang in "${langs_to_check[@]}"; do local potential_srt_file="${base}.${lang}.srt"; if [ -f "$potential_srt_file" ]; then local already_added=false; for existing_file in "${subtitle_files[@]}"; do [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }; done; if ! $already_added; then subtitle_files+=("$potential_srt_file"); log_message "INFO" "找到字幕: $potential_srt_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}"; fi; fi; done
    if [ ${#subtitle_files[@]} -eq 0 ]; then log_message "INFO" "未找到中文字幕。"; echo -e "${YELLOW}未找到中文字幕。${RESET}"; fi
    local output_video="${base}_normalized.mp4"; local normalized_audio="$temp_dir/audio_normalized.m4a"
    echo -e "${YELLOW}開始音量標準化...${RESET}"
    if normalize_audio "$video_file" "$normalized_audio" "$temp_dir" true; then
        echo -e "${YELLOW}正在混流...${RESET}"
        local ffmpeg_mux_args=(ffmpeg -y -i "$video_file" -i "$normalized_audio")
        for sub_file in "${subtitle_files[@]}"; do ffmpeg_mux_args+=("-sub_charenc" "UTF-8" -i "$sub_file"); done
        ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100" "-map" "0:v:0" "-map" "1:a:0")
        local sub_stream_index=2
        if [ ${#subtitle_files[@]} -gt 0 ]; then for ((i=0; i<${#subtitle_files[@]}; i++)); do ffmpeg_mux_args+=("-map" "$sub_stream_index:0"); ((sub_stream_index++)); done; ffmpeg_mux_args+=("-c:s" "mov_text"); fi
        ffmpeg_mux_args+=("-movflags" "+faststart" "$output_video")
        log_message "INFO" "混流命令: ${ffmpeg_mux_args[*]}"
        local ffmpeg_stderr_log="$temp_dir/ffmpeg_mux_stderr.log"
        if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then echo -e "${RED}錯誤：混流失敗！...${RESET}"; cat "$ffmpeg_stderr_log"; log_message "ERROR" "混流失敗..."; result=1;
        else echo -e "${GREEN}混流完成${RESET}"; result=0; rm -f "$ffmpeg_stderr_log"; fi
    else log_message "ERROR" "音量標準化失敗！"; result=1; fi
    [ -f "$video_file" ] && safe_remove "$video_file"; for sub_file in "${subtitle_files[@]}"; do safe_remove "$sub_file"; done; safe_remove "$normalized_audio"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    if [ $result -eq 0 ]; then echo -e "${GREEN}處理完成！影片已儲存至：$output_video${RESET}"; log_message "SUCCESS" "處理完成！影片已儲存至：$output_video";
    else echo -e "${RED}處理失敗！${RESET}"; log_message "ERROR" "處理失敗：$video_url"; fi
    return $result
}


#######################################################
# 處理單一 YouTube 影片（MP4）下載與處理（無音量標準化）
#######################################################
process_single_mp4_no_normalize() {
    # --- 函數邏輯不變 ---
    local video_url="$1"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_options="--write-subs --sub-lang $target_sub_langs --convert-subs srt"
    local subtitle_files=()
    local temp_dir=$(mktemp -d)
    local result=0
    echo -e "${YELLOW}處理 YouTube 影片 (無標準化)：$video_url${RESET}"; log_message "INFO" "處理 YouTube 影片 (無標準化): $video_url"; log_message "INFO" "嘗試字幕: $target_sub_langs"
    echo -e "${YELLOW}嘗試下載繁/簡/通用中文字幕...${RESET}"
    local format_option="bestvideo[ext=mp4][height<=1440]+bestaudio[ext=flac]/bestvideo[ext=mp4][height<=1440]+bestaudio[ext=wav]/bestvideo[ext=mp4][height<=1440]+bestaudio[ext=m4a]/best[ext=mp4][height<=1440]/best[height<=1440]/best"
    if [[ "$video_url" != *"youtube.com"* && "$video_url" != *"youtu.be"* ]]; then format_option="best"; log_message "WARNING" "...非 YouTube URL..."; subtitle_options=""; echo -e "${YELLOW}非 YouTube URL...${RESET}"; fi
    log_message "INFO" "使用格式 (無標準化): $format_option"
    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${YELLOW}開始下載影片及字幕（高品質音質）...${RESET}"
    local output_template="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    local yt_dlp_dl_args=(yt-dlp -f "$format_option")
    IFS=' ' read -r -a sub_opts_array <<< "$subtitle_options"; if [ ${#sub_opts_array[@]} -gt 0 ]; then yt_dlp_dl_args+=("${sub_opts_array[@]}"); fi
    yt_dlp_dl_args+=(-o "$output_template" "$video_url" --newline --progress --concurrent-fragments "$THREADS")
    if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-nonorm.log"; then log_message "ERROR" "影片(無標準化)下載失敗..."; echo -e "${RED}錯誤：影片下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-nonorm.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    local yt_dlp_fn_args=(yt-dlp --get-filename -f "$format_option" -o "$output_template" "$video_url")
    local video_file=$("${yt_dlp_fn_args[@]}" 2>/dev/null)
    if [ ! -f "$video_file" ]; then log_message "ERROR" "找不到下載的影片檔案..."; echo -e "${RED}錯誤：找不到下載的影片檔案！${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    echo -e "${GREEN}影片下載完成：$video_file${RESET}"; log_message "INFO" "影片(無標準化)下載完成：$video_file"
    local base="${video_file%.*}"; subtitle_files=()
    log_message "INFO" "檢查字幕 (基於: $base.*.srt)"
    IFS=',' read -r -a langs_to_check <<< "$target_sub_langs"
    for lang in "${langs_to_check[@]}"; do local potential_srt_file="${base}.${lang}.srt"; if [ -f "$potential_srt_file" ]; then local already_added=false; for existing_file in "${subtitle_files[@]}"; do [[ "$existing_file" == "$potential_srt_file" ]] && { already_added=true; break; }; done; if ! $already_added; then subtitle_files+=("$potential_srt_file"); log_message "INFO" "找到字幕: $potential_srt_file"; echo -e "${GREEN}找到字幕: $(basename "$potential_srt_file")${RESET}"; fi; fi; done
    if [ ${#subtitle_files[@]} -eq 0 ]; then log_message "INFO" "未找到中文字幕。"; echo -e "${YELLOW}未找到中文字幕。${RESET}"; fi
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
    if ! "${ffmpeg_args[@]}" 2> "$ffmpeg_stderr_log"; then echo -e "${RED}錯誤：影片後處理失敗！...${RESET}"; cat "$ffmpeg_stderr_log"; log_message "ERROR" "影片後處理失敗..."; result=1;
    else echo -e "${GREEN}影片後處理完成：$final_video${RESET}"; log_message "SUCCESS" "影片(無標準化)處理完成：$final_video"; result=0; rm -f "$ffmpeg_stderr_log"; fi
    if [ $result -eq 0 ]; then echo -e "${YELLOW}清理臨時檔案...${RESET}"; rm -f "$video_file"; log_message "INFO" "刪除原始影片：$video_file"; for sub_file in "${subtitle_files[@]}"; do rm -f "$sub_file"; log_message "INFO" "刪除字幕：$sub_file"; done; echo -e "${GREEN}清理完成，最終檔案：$final_video${RESET}";
    else echo -e "${YELLOW}處理失敗，保留原始檔案以便檢查。${RESET}"; fi
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    return $result
}

############################################
# 處理單一 YouTube 影片（MKV）下載與處理 (修正版 v2.0.5+)
############################################
process_single_mkv() {
    local video_url="$1"
    local target_sub_langs="zh-Hant,zh-TW,zh-Hans,zh-CN,zh"
    local subtitle_format_pref="vtt/best" # 仍然優先 VTT
    local downloaded_vtt_files=()
    local enhanced_vtt_files=() # 存儲增強後的 VTT 文件
    local fallback_subtitle_files=() # 原始 VTT 作為備選
    local temp_dir=$(mktemp -d)
    local result=0

    # --- <<< 修改：直接使用設定檔中定義的 Python 腳本路徑 >>> ---
    #     這個變數 ($PYTHON_CONVERTER_INSTALL_PATH) 是在腳本啟動時
    #     根據預設值或從 $CONFIG_FILE 載入的。
    #     它指向 $HOME/scripts/vtt_to_ass_converter.py (根據你的設定)
    local VTT_ENHANCER_PY="$PYTHON_CONVERTER_INSTALL_PATH"
    # --- <<< 結束路徑修改 >>> ---
    # 注意：雖然你的 Python 腳本內容是 'enhancer'，但 Bash 腳本配置
    # 和下載邏輯目前指向的是 'vtt_to_ass_converter.py' 這個檔名。
    # 我們在這裡保持與配置一致，假設下載/更新的檔案是這個名稱。

    echo -e "${YELLOW}處理 YouTube 影片 (輸出 MKV)：$video_url${RESET}"
    log_message "INFO" "處理 YouTube MKV: $video_url"; log_message "INFO" "將嘗試請求以下字幕 (格式: $subtitle_format_pref): $target_sub_langs"
    echo -e "${YELLOW}將嘗試下載繁/簡/通用中文字幕 (優先 VTT)...${RESET}"

    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi

    # --- 檔名清理 (沿用 v1.8.4 的邏輯) ---
    local video_title video_id sanitized_title_id
    video_title=$(yt-dlp --get-title "$video_url" 2>/dev/null) || video_title="video"
    video_id=$(yt-dlp --get-id "$video_url" 2>/dev/null) || video_id=$(date +%s)
    sanitized_title_id=$(echo "${video_title}_${video_id}" | sed 's@[/\\:*?"<>|]@_@g')
    local output_base_name="$DOWNLOAD_PATH/$sanitized_title_id"
    # --- 結束檔名處理 ---

    local video_temp_file="${temp_dir}/video_stream.mp4"
    local audio_temp_file="${temp_dir}/audio_stream.m4a"
    local sub_temp_template="${temp_dir}/sub_stream.%(ext)s"

    echo -e "${YELLOW}開始下載最佳視訊流 (<=1440p)...${RESET}"
    # --- 下載視訊流 (邏輯不變) ---
    if ! yt-dlp -f 'bv[ext=mp4][height<=1440]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video.log"; then
        echo -e "${YELLOW}警告：未找到 <=1440p 的 MP4 視訊流，嘗試下載最佳 MP4 視訊流...${RESET}"
        log_message "WARNING" "未找到 <=1440p 的 MP4 視訊流，嘗試最佳 MP4 for $video_url"
        if ! yt-dlp -f 'bv[ext=mp4]/bestvideo[ext=mp4]' --no-warnings -o "$video_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-video.log"; then
            log_message "ERROR" "視訊流下載失敗（包括備選方案）..."; echo -e "${RED}錯誤：視訊流下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-video.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1;
        fi
    fi
    log_message "INFO" "視訊流下載完成: $video_temp_file"
    # --- 結束下載視訊流 ---

    echo -e "${YELLOW}開始下載最佳音訊流 (m4a)...${RESET}"
    # --- 下載音訊流 (邏輯不變) ---
     if ! yt-dlp -f 'ba[ext=m4a]' --no-warnings -o "$audio_temp_file" "$video_url" 2> "$temp_dir/yt-dlp-audio.log"; then
             log_message "ERROR" "音訊流下載失敗..."; echo -e "${RED}錯誤：音訊流下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-audio.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1;
        fi
    log_message "INFO" "音訊流下載完成: $audio_temp_file"
    # --- 結束下載音訊流 ---

    echo -e "${YELLOW}開始下載字幕 (格式: ${subtitle_format_pref})...${RESET}"
    yt-dlp --write-subs --sub-format "$subtitle_format_pref" --sub-lang "$target_sub_langs" --skip-download -o "$sub_temp_template" "$video_url" > "$temp_dir/yt-dlp-subs.log" 2>&1

    local found_sub=false
    # --- 查找 VTT 邏輯 (不變) ---
    for lang_code in "zh-Hant" "zh-TW" "zh-Hans" "zh-CN" "zh"; do
        potential_sub_file="${temp_dir}/sub_stream.${lang_code}.vtt"
        if [ -f "$potential_sub_file" ]; then
            downloaded_vtt_files+=("$potential_sub_file") # 存儲 VTT 路徑
            log_message "INFO" "找到 VTT 字幕: $potential_sub_file"; echo -e "${GREEN}找到 VTT 字幕: $(basename "$potential_sub_file")${RESET}";
            found_sub=true;
            break; # 找到一個就停止 (如果需要合併多語言則移除 break)
        fi
    done
    if [ ${#downloaded_vtt_files[@]} -eq 0 ]; then log_message "INFO" "未找到符合條件的中文字幕。"; echo -e "${YELLOW}未找到 VTT 格式的中文字幕。${RESET}"; fi
    # --- 結束 VTT 查找 ---

    # --- <<< 調用 VTT 增強器 (現在使用正確的路徑變數 $VTT_ENHANCER_PY) >>> ---
    if [ ${#downloaded_vtt_files[@]} -gt 0 ]; then
        if command -v python &> /dev/null || command -v python3 &> /dev/null; then
            local python_cmd; if command -v python3 &> /dev/null; then python_cmd="python3"; else python_cmd="python"; fi

            # <<< 檢查現在應該使用正確的檔案路徑 >>>
            if [ -f "$VTT_ENHANCER_PY" ] && [ -r "$VTT_ENHANCER_PY" ]; then
                echo -e "${YELLOW}嘗試增強 VTT 字幕樣式 (使用 $VTT_ENHANCER_PY)...${RESET}"
                for vtt_file in "${downloaded_vtt_files[@]}"; do
                    enhanced_file="${vtt_file%.vtt}.enhanced.vtt" # 增強後的檔名

                    log_message "INFO" "調用增強器: $python_cmd \"$VTT_ENHANCER_PY\" \"$vtt_file\" \"$enhanced_file\""
                    enhancer_output=$($python_cmd "$VTT_ENHANCER_PY" "$vtt_file" "$enhanced_file" 2>&1)
                    enhancer_exit_code=$?

                    if [ $enhancer_exit_code -eq 0 ]; then
                        log_message "INFO" "VTT 增強成功: $vtt_file -> $enhanced_file"
                        echo -e "${GREEN}字幕增強成功: $(basename "$enhanced_file")${RESET}"
                        enhanced_vtt_files+=("$enhanced_file") # 添加增強後的文件
                    else
                        # 錯誤處理邏輯不變
                        log_message "ERROR" "VTT 增強失敗 (Exit Code: $enhancer_exit_code): $vtt_file"
                        log_message "ERROR" "增強器輸出: $enhancer_output"
                        echo -e "${RED}錯誤：增強字幕 $(basename "$vtt_file") 失敗。將嘗試使用原始 VTT。${RESET}"
                        echo -e "${RED}增強器錯誤訊息:\n$enhancer_output ${RESET}" # 換行顯示可能更清晰
                        fallback_subtitle_files+=("$vtt_file") # 增強失敗，記錄原始 VTT
                    fi
                done
            else
                # 如果 VTT_ENHANCER_PY 指向的檔案仍然找不到或不可讀，會執行這裡
                log_message "WARNING" "未找到或無法讀取字幕增強器: $VTT_ENHANCER_PY。將直接使用下載的 VTT。"
                echo -e "${YELLOW}警告：未找到字幕增強器 ($VTT_ENHANCER_PY)。將嘗試使用原始 VTT。${RESET}"
                echo -e "${YELLOW}請檢查檔案是否存在於該路徑，以及是否有讀取權限。${RESET}" # 增加提示
                fallback_subtitle_files+=("${downloaded_vtt_files[@]}")
            fi
        else
            # Python 環境未找到的處理 (不變)
            log_message "WARNING" "未找到 Python 環境，無法執行字幕增強。將直接使用下載的 VTT。"
            echo -e "${YELLOW}警告：未找到 Python。將嘗試使用原始 VTT。${RESET}"
            fallback_subtitle_files+=("${downloaded_vtt_files[@]}")
        fi
    fi
    # --- 結束調用增強器 ---

    # --- 音量標準化 (邏輯不變) ---
    local normalized_audio_m4a="$temp_dir/audio_normalized.m4a"
    echo -e "${YELLOW}開始音量標準化...${RESET}"
    if normalize_audio "$audio_temp_file" "$normalized_audio_m4a" "$temp_dir" true; then
        echo -e "${YELLOW}正在混流成 MKV 檔案...${RESET}"
        local output_mkv="${output_base_name}_normalized.mkv"

        local ffmpeg_mux_args=(ffmpeg -y -i "$video_temp_file" -i "$normalized_audio_m4a")
        local sub_input_index=2

        # --- 優先使用增強後的 VTT，然後使用 fallback 的原始 VTT (邏輯不變) ---
        local subtitles_to_mux=("${enhanced_vtt_files[@]}" "${fallback_subtitle_files[@]}")

        # 添加字幕輸入 (邏輯不變)
        for sub_file in "${subtitles_to_mux[@]}"; do
            ffmpeg_mux_args+=("-i" "$sub_file")
        done

        ffmpeg_mux_args+=("-c:v" "copy" "-c:a" "aac" "-b:a" "256k" "-ar" "44100")
        ffmpeg_mux_args+=("-map" "0:v:0" "-map" "1:a:0")

        if [ ${#subtitles_to_mux[@]} -gt 0 ]; then
            ffmpeg_mux_args+=("-c:s" "webvtt") # 指定字幕編解碼器為 webvtt
            for ((i=0; i<${#subtitles_to_mux[@]}; i++)); do
                local current_sub_map_index="$sub_input_index" # 記錄當前字幕輸入流的索引
                ffmpeg_mux_args+=("-map" "${current_sub_map_index}:s:0") # 使用記錄的索引進行映射

                # --- <<< 新增：為第一個字幕軌道設定 Default 標誌 >>> ---
                if [ "$i" -eq 0 ]; then
                    # :s:$i 指的是輸出文件中的第 i 個字幕流 (從 0 開始)
                    ffmpeg_mux_args+=("-disposition:s:$i" "default")
                    log_message "INFO" "Setting subtitle stream $i as default."
                fi
                # --- <<< 結束新增 >>> ---

                # 添加語言標籤 (使用輸出的字幕流索引 $i)
                local sub_basename=$(basename "${subtitles_to_mux[$i]}")
                local lang_tag="und";
                if [[ "$sub_basename" =~ \.(zh-Hant|zh-TW)\. ]]; then lang_tag="zht";
                elif [[ "$sub_basename" =~ \.(zh-Hans|zh-CN)\. ]]; then lang_tag="zhs";
                elif [[ "$sub_basename" =~ \.zh\. ]]; then lang_tag="chi";
                fi
                # 使用 :s:$i 定位輸出的字幕流
                ffmpeg_mux_args+=("-metadata:s:s:$i" "language=$lang_tag")

                ((sub_input_index++)) # 更新下一個輸入文件的索引
            done
        fi
        ffmpeg_mux_args+=("$output_mkv")
        # --- 結束字幕輸入 ---

        log_message "INFO" "MKV 混流命令: ${ffmpeg_mux_args[*]}"
        local ffmpeg_stderr_log="$temp_dir/ffmpeg_mkv_mux_stderr.log"
        # --- ffmpeg 執行和錯誤處理邏輯 (不變) ---
         if ! "${ffmpeg_mux_args[@]}" 2> "$ffmpeg_stderr_log"; then
            echo -e "${RED}錯誤：MKV 混流失敗！以下是 FFmpeg 錯誤訊息：${RESET}"
            # 顯示錯誤日誌內容，幫助診斷
            if [ -s "$ffmpeg_stderr_log" ]; then
                 cat "$ffmpeg_stderr_log"
            else
                 echo "(FFmpeg 未產生錯誤輸出)"
            fi
            log_message "ERROR" "MKV 混流失敗，詳見 $ffmpeg_stderr_log (錯誤內容已輸出)";
            result=1;
        else
            echo -e "${GREEN}MKV 混流完成${RESET}";
            result=0;
            rm -f "$ffmpeg_stderr_log"; # 成功後刪除日誌
        fi
    else
        log_message "ERROR" "音量標準化失敗！";
        result=1;
    fi

    log_message "INFO" "清理臨時檔案..."
    # --- 清理邏輯 (不變) ---
    safe_remove "$video_temp_file" "$audio_temp_file" "$normalized_audio_m4a"
    for sub_file in "${enhanced_vtt_files[@]}"; do safe_remove "$sub_file"; done # 清理增強後的 VTT
    for sub_file in "${downloaded_vtt_files[@]}"; do safe_remove "$sub_file"; done # 清理原始 VTT (如果增強失敗會用到)
    safe_remove "$temp_dir/yt-dlp-video.log" "$temp_dir/yt-dlp-audio.log" "$temp_dir/yt-dlp-subs.log"
    # 確保即使混流失敗，錯誤日誌也會被嘗試清理
    [ -f "$ffmpeg_stderr_log" ] && safe_remove "$ffmpeg_stderr_log"
    [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    # --- 結束清理 ---

    # --- 處理結果輸出 (不變) ---
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}處理完成！MKV 影片已儲存至：$output_mkv${RESET}";
        log_message "SUCCESS" "MKV 處理完成！影片已儲存至：$output_mkv";
    else
        echo -e "${RED}處理失敗！${RESET}";
        log_message "ERROR" "MKV 處理失敗：$video_url";
    fi
    return $result
    # --- 結束處理結果輸出 ---
}

############################################
# 輔助函數：處理單一通用網站媒體項目
############################################
_process_single_other_site() {
    # --- 函數邏輯不變 ---
    local item_url="$1"; local choice_format="$2"; local item_index="$3"; local total_items="$4"
    local temp_dir=$(mktemp -d); local thumbnail_file=""; local main_media_file=""; local base_name=""
    local result=0; local output_final_file=""; local artist_name="[不明]"; local album_artist_name="[不明]"
    local progress_prefix=""; if [ -n "$item_index" ] && [ -n "$total_items" ]; then progress_prefix="[$item_index/$total_items] "; fi
    echo -e "${CYAN}${progress_prefix}處理項目: $item_url (${choice_format})${RESET}"; log_message "INFO" "${progress_prefix}處理項目: $item_url (格式: $choice_format)"
    mkdir -p "$DOWNLOAD_PATH"; if [ ! -w "$DOWNLOAD_PATH" ]; then log_message "ERROR" "...無法寫入目錄..."; echo -e "${RED}錯誤：無法寫入目錄${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    local yt_dlp_format_string=""; local yt_dlp_extra_args=()
    if [ "$choice_format" = "mp4" ]; then yt_dlp_format_string="bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best[ext=mp4]/best";
    else yt_dlp_format_string="bestaudio/best"; fi
    yt_dlp_extra_args+=(--write-thumbnail --newline --progress --concurrent-fragments "$THREADS")
    local output_template="$DOWNLOAD_PATH/%(playlist_index)s-%(title)s [%(id)s].%(ext)s"
    local output_template_single="$DOWNLOAD_PATH/%(title)s [%(id)s].%(ext)s"
    echo -e "${YELLOW}${progress_prefix}開始下載...${RESET}"
    local yt_dlp_cmd_args=(yt-dlp -f "$yt_dlp_format_string" "${yt_dlp_extra_args[@]}" -o "$output_template" "$item_url")
    log_message "INFO" "${progress_prefix}執行下載 (模板1): ${yt_dlp_cmd_args[*]}"
    if ! "${yt_dlp_cmd_args[@]}" 2> "$temp_dir/yt-dlp-other1.log"; then
        echo -e "${YELLOW}${progress_prefix}模板1下載失敗，嘗試模板2...${RESET}"
        local yt_dlp_cmd_args_single=(yt-dlp -f "$yt_dlp_format_string" "${yt_dlp_extra_args[@]}" -o "$output_template_single" "$item_url")
        log_message "INFO" "${progress_prefix}執行下載 (模板2): ${yt_dlp_cmd_args_single[*]}"
        if ! "${yt_dlp_cmd_args_single[@]}" 2> "$temp_dir/yt-dlp-other2.log"; then log_message "ERROR" "...下載失敗..."; echo -e "${RED}錯誤：下載失敗！${RESET}"; cat "$temp_dir/yt-dlp-other2.log"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    fi
    echo -e "${YELLOW}${progress_prefix}定位檔案...${RESET}"
    local get_filename_args1=(yt-dlp --get-filename -f "$yt_dlp_format_string" -o "$output_template" "$item_url")
    main_media_file=$("${get_filename_args1[@]}" 2>/dev/null)
    if [ ! -f "$main_media_file" ]; then local get_filename_args2=(yt-dlp --get-filename -f "$yt_dlp_format_string" -o "$output_template_single" "$item_url"); main_media_file=$("${get_filename_args2[@]}" 2>/dev/null); fi
    if [ ! -f "$main_media_file" ]; then log_message "ERROR" "...找不到主檔案..."; echo -e "${RED}錯誤：找不到主檔案！${RESET}"; [ -d "$temp_dir" ] && rm -rf "$temp_dir"; return 1; fi
    log_message "INFO" "${progress_prefix}找到主檔案: $main_media_file"; base_name="${main_media_file%.*}"
    for ext in jpg png webp jpeg; do local potential_thumb="${base_name}.${ext}"; if [ -f "$potential_thumb" ]; then thumbnail_file="$potential_thumb"; log_message "INFO" "...找到縮圖..."; break; fi; done
    if [ -z "$thumbnail_file" ]; then log_message "WARNING" "...未找到縮圖..."; fi
    if [ "$choice_format" = "mp3" ]; then
        output_final_file="${base_name}_normalized.mp3"; local normalized_temp="$temp_dir/temp_normalized.mp3"
        echo -e "${YELLOW}${progress_prefix}開始標準化 (MP3)...${RESET}"
        if normalize_audio "$main_media_file" "$normalized_temp" "$temp_dir" false; then
            echo -e "${YELLOW}${progress_prefix}處理最終 MP3...${RESET}"
            local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_temp")
            if [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ]; then ffmpeg_embed_args+=(-i "$thumbnail_file" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic);
            else ffmpeg_embed_args+=(-c copy -metadata "artist=$artist_name" -metadata "album_artist=$album_artist_name"); fi
            ffmpeg_embed_args+=("$output_final_file")
            if ! "${ffmpeg_embed_args[@]}" > /dev/null 2>&1; then log_message "ERROR" "...生成 MP3 失敗..."; echo -e "${RED}錯誤：生成 MP3 失敗！${RESET}"; result=1; fi
            safe_remove "$normalized_temp"
        else result=1; fi
    elif [ "$choice_format" = "mp4" ]; then
        output_final_file="${base_name}_normalized.mp4"; local normalized_audio_m4a="$temp_dir/audio_normalized.m4a"
        echo -e "${YELLOW}${progress_prefix}開始標準化 (提取音訊)...${RESET}"
        if normalize_audio "$main_media_file" "$normalized_audio_m4a" "$temp_dir" true; then
            echo -e "${YELLOW}${progress_prefix}混流影片與音訊...${RESET}"
            local ffmpeg_mux_args=(ffmpeg -y -i "$main_media_file" -i "$normalized_audio_m4a" -c:v copy -c:a aac -b:a 256k -ar 44100 -map 0:v:0 -map 1:a:0 -movflags +faststart "$output_final_file")
            if ! "${ffmpeg_mux_args[@]}" > /dev/null 2>&1; then log_message "ERROR" "...混流 MP4 失敗..."; echo -e "${RED}錯誤：混流 MP4 失敗！${RESET}"; result=1; fi
            safe_remove "$normalized_audio_m4a"
        else result=1; fi
    fi
    log_message "INFO" "${progress_prefix}清理..."; safe_remove "$main_media_file"; [ -n "$thumbnail_file" ] && [ -f "$thumbnail_file" ] && safe_remove "$thumbnail_file"; safe_remove "${base_name}".*; [ -d "$temp_dir" ] && rm -rf "$temp_dir"
    if [ $result -eq 0 ]; then echo -e "${GREEN}${progress_prefix}處理完成！檔案：$output_final_file${RESET}"; log_message "SUCCESS" "${progress_prefix}處理完成！檔案：$output_final_file";
    else echo -e "${RED}${progress_prefix}處理失敗！${RESET}"; log_message "ERROR" "${progress_prefix}處理失敗：$item_url"; fi
    return $result
}

############################################
# 處理其他網站媒體 (通用 MP3/MP4) - 支持實驗性批量下載
############################################
process_other_site_media_playlist() {
    local input_url=""; local choice_format=""
    local cf # Declare cf for case statement scope

    # SC2162: Added -r to read
    read -r -p "請輸入媒體網址 (單個或播放列表): " input_url; if [ -z "$input_url" ]; then echo -e "${RED}錯誤：未輸入！${RESET}"; return 1; fi

    log_message "INFO" "處理通用媒體/列表：$input_url"; echo -e "${YELLOW}處理通用媒體/列表：$input_url${RESET}"; echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"

    while true; do
        local cfn # Declare cfn for loop scope
        # SC2162: Added -r to read
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
    # Check jq exists before trying to use it in the loop
    if command -v jq &> /dev/null; then
        if [ -n "$item_list_json" ]; then
            local line url # Declare loop variables
            while IFS= read -r line; do
                # SC2155: Declare and assign separately (though jq is not command substitution)
                # Let's keep it simple here, as it's not command substitution.
                # url=$(echo "$line" | jq -r '.url // empty')
                # Refined jq parsing to handle potential errors better
                url=$(echo "$line" | jq -r '.url // empty' 2>/dev/null)
                if [ $? -eq 0 ] && [ -n "$url" ] && [ "$url" != "null" ]; then
                    item_urls+=("$url");
                fi;
            # Original jq command was fine, but let's ensure it processes line by line if input is multiline JSON
            done <<< "$(echo "$item_list_json" | jq -c '. // empty | select(type == "object" and (.url != null))')" # Ensure only objects with URL are processed

            item_count=${#item_urls[@]};
            if [ "$item_count" -eq 0 ]; then
                log_message "WARNING" "透過 JQ 解析，未找到有效的 URL 項目。"
            fi
        else
             log_message "WARNING" "dump-json 成功，但輸出為空。"
        fi
    # SC1075: Replaced 'else if' with 'elif'
    elif ! command -v jq &> /dev/null; then
        log_message "WARNING" "未找到 jq，無法自動檢測列表項目 URL。將嘗試處理原始 URL。"
        item_count=0 # Force single item processing if jq is missing
    fi

    if [ "$item_count" -gt 1 ]; then
        log_message "INFO" "檢測到列表 ($item_count 項)。"; echo -e "${CYAN}檢測到列表 ($item_count 項)。開始批量處理...${RESET}";
        local ci=0; local sc=0; local item_url # Declare loop variable
        for item_url in "${item_urls[@]}"; do
            ci=$((ci + 1));
            # SC2181: Check exit code directly
            if _process_single_other_site "$item_url" "$choice_format" "$ci" "$item_count"; then
                sc=$((sc + 1));
            fi
            echo ""; # Add newline between items
        done
        echo -e "${GREEN}列表處理完成！共 $ci 項，成功 $sc 項。${RESET}"; log_message "SUCCESS" "列表 $input_url 完成！共 $ci 項，成功 $sc 項。"
    else
        if [ "$item_count" -eq 1 ]; then
            log_message "INFO" "檢測到 1 項，按單個處理。"
            echo -e "${YELLOW}檢測到 1 項，按單個處理...${RESET}";
            input_url=${item_urls[0]}; # Use the single URL found
        else
            # This case handles item_count=0 (either jq failed/missing, or no URLs found)
            log_message "INFO" "未檢測到有效列表或無法解析，按單個處理原始 URL。"
            echo -e "${YELLOW}未檢測到列表，按單個處理...${RESET}";
            # input_url remains the original URL passed to the function
        fi
        _process_single_other_site "$input_url" "$choice_format" # No index/total needed
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
        if "$single_item_processor_func_name" "$video_url"; then 
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

# 關於訊息
show_about() {
    clear
    echo -e "${CYAN}整合式影音處理平台 ${SCRIPT_VERSION}${RESET}"
    echo -e "${GREEN}特色：${RESET}"
    echo -e "- 支援 YouTube 影片與音訊下載 (MP3/MP4)"
    echo -e "- 支援通用網站媒體下載 (實驗性 MP3/MP4, yt-dlp 支持範圍)"
    echo -e "- 支援 YouTube 影片下載 (實驗性 MKV檔)（v1.8.0+）"
    echo -e "- 雙重音量標準化 (基於 EBU R128)"
    echo -e "- 純音訊編碼規格 (MP3 320k)"
    echo -e "- MP4音訊編碼規格 (AAC 256k)"
    echo -e "- 自動嵌入封面圖片與基礎元數據 (MP3)"
    echo -e "- 支援中文字幕選擇與嵌入 (YouTube MP4)"
    echo -e "- 支援播放清單批量下載 (YouTube 及部分通用網站)"
    echo -e "- 支援本機 MP3/MP4 檔案音量標準化"
    echo -e "- 提供無音量標準化下載選項 (MP4)"
    echo -e "- 自動調整下載執行緒數量 (基於 CPU 核心)"
    echo -e "- 提供依賴檢查與更新功能 (跨平台支援 Termux/WSL/Linux)" # <<< 可更新描述
    echo -e "- 提供手動觸發的腳本自我更新功能" # <<< 新增描述
    echo -e "- 文字選單介面，彩色輸出"
    echo -e "- Termux 啟動整合與別名設置"
    echo -e "- ${BOLD}移除 eval，提高安全性 (v1.4.4+)${RESET}"
    echo -e "- ${BOLD}重構播放清單處理邏輯 (v1.5.0+)${RESET}"
    echo -e "\n${YELLOW}使用須知：${RESET}"
    echo -e "本工具僅供個人學習與合法使用，請尊重版權並遵守當地法律法規。"
    echo -e "下載受版權保護的內容可能違法，請自行承擔風險。"
    echo -e "\n${CYAN}日誌檔案位於: ${LOG_FILE}${RESET}"
    echo -e "\n"
    read -p "按 Enter 返回主選單..."
}

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
# 主選單 (修改 - 在處理任務後添加延遲)
############################################
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 整合式影音處理平台 ${SCRIPT_VERSION} ===${RESET}"
        # <<< 新增：在這裡呼叫顯示倒數計時的函數 >>>
        display_countdown
        # <<< 結束新增 >>>
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. ${BOLD}MP3 處理${RESET} (YouTube/本機)"
        echo -e " 2. ${BOLD}MP4 處理${RESET} (YouTube/本機)"
        echo -e " 2-1. 下載 MP4 (YouTube / ${BOLD}無${RESET}標準化)"
        # <<< 新增 MKV 選項 >>>
        echo -e " 2-2. ${BOLD}MKV 處理 (YouTube / 含標準化 / 實驗性字幕保留)${RESET}"
        echo -e " ${BOLD}7. 通用媒體處理 (其他網站 / ${YELLOW}實驗性${RESET})"
        echo -e "---------------------------------------------"
        echo -e " 3. 設定參數"
        echo -e " 4. 檢視操作日誌"
        echo -e " 6. ${BOLD}檢查並更新依賴套件${RESET}"
        echo -e " ${BOLD}8. 檢查腳本更新${RESET}"
        # <<< 新增：僅在 Termux 環境下顯示選項 9 >>>
        if [[ "$OS_TYPE" == "termux" ]]; then
            echo -e " ${BOLD}9. 設定 Termux 啟動時詢問${RESET}"
        fi
        echo -e "---------------------------------------------"
        echo -e " 5. 關於此工具"
        echo -e " 0. ${RED}退出腳本${RESET}"
        echo -e "---------------------------------------------"

        # 依然保留之前的緩衝區清理嘗試，作為額外保險
        read -t 0.1 -N 10000 discard

        local prompt_range="0-8"
        if [[ "$OS_TYPE" == "termux" ]]; then
            prompt_range="0-9 或 2-1 ,2-2"
        else
            prompt_range="0-8 或 2-1 ,2-2"
        fi
        local choice
        read -rp "輸入選項 (${prompt_range}): " choice

        case $choice in
            1)
                process_mp3
                sleep 1 # <<< 在 MP3 處理後暫停 1 秒
                ;;
            2)
                process_mp4
                sleep 1 # <<< 在 MP4 處理後暫停 1 秒
                ;;
            2-1)
                process_mp4_no_normalize
                sleep 1 # <<< 在 MP4 (無標準化) 處理後暫停 1 秒
                ;;
            2-2) 
                process_mkv;
                sleep 1 
                ;;
            7)
                process_other_site_media_playlist
                sleep 1 # <<< 在通用媒體處理後暫停 1 秒
                ;;
            3) config_menu ;; # 設定選單本身有循環，返回時不需要額外暫停
            4) view_log ;;    # 檢視日誌通常很快，不需要強制暫停
            6)
                update_dependencies
                # update_dependencies 內部已有 read prompt，不需要再加 sleep
                ;;
            8)
               auto_update_script
               echo ""
               read -p "按 Enter 返回主選單..."
               # sleep 1 # 可選：如果希望按 Enter 後再停1秒
               ;;
            9)
               if [[ "$OS_TYPE" == "termux" ]]; then
                   setup_termux_autostart
               else
                   echo -e "${RED}錯誤：此選項僅適用於 Termux。${RESET}"
                   sleep 1 # 顯示錯誤後暫停一下
               fi
               echo ""
               read -p "按 Enter 返回主選單..."
               # sleep 1 # 可選：如果希望按 Enter 後再停1秒
               ;;
            5)
                show_about
                # show_about 內部已有 read prompt，不需要再加 sleep
                ;;
            0) echo -e "${GREEN}感謝使用，正在退出...${RESET}"; log_message "INFO" "使用者選擇退出。"; sleep 1; exit 0 ;;
            *)
               if [[ -z "$choice" ]]; then
                   continue
               else
                   echo -e "${RED}無效選項 '$choice'${RESET}";
                   log_message "WARNING" "主選單輸入無效選項: $choice";
                   sleep 1 # 無效選項後原本就有暫停
               fi
               ;;
        esac
        # <<< 注意：這裡不再有全局的 read prompt 或 sleep >>>
    done
}

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
    sleep 2

    # --- 進入主選單 ---
    main_menu
}

# --- 執行主函數 ---
main
