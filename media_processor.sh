#!/bin/bash

# 腳本設定
SCRIPT_VERSION="v1.6.2(Experimental)" # <<< 版本號更新
# DEFAULT_URL, THREADS, MAX_THREADS, MIN_THREADS 保留
DEFAULT_URL="https://www.youtube.com/watch?v=siNFnlqtd8M"
THREADS=4
MAX_THREADS=8
MIN_THREADS=1
COLOR_ENABLED=true
# 自動更新設定保留
REMOTE_VERSION_URL="https://github.com/adeend-co/media-processor-updates/raw/0ed5dab1d847c8f8a001e64e64c641af35a1c1e3/latest_version.txt" # <<< 請務必修改此 URL
REMOTE_SCRIPT_URL="https://github.com/adeend-co/media-processor-updates/raw/5a1a20d482ef83137eb1b8e74e8dc4ff427452b7/media_processor.sh"   # <<< 請務必修改此 URL
SCRIPT_INSTALL_PATH="$HOME/scripts/media_processor.sh"

# --- 移除舊的路徑直接設定 ---
# DOWNLOAD_PATH="/sdcard/Termux/downloads" # <<< 刪除或註解掉
# LOG_FILE="$DOWNLOAD_PATH/script_log.txt" # <<< 刪除或註解掉
# TEMP_DIR="/data/data/com.termux/files/usr/tmp" # <<< 刪除或註解掉

# 顏色代碼
if [ "$COLOR_ENABLED" = true ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    PURPLE='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    PURPLE=''
    CYAN=''
    WHITE=''
    BOLD=''
    RESET=''
fi

# 日誌函數
log_message() {
    # --- 日誌函數邏輯不變 ---
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local colored_message=""

    # 確保 LOG_FILE 變數已定義且非空才寫入檔案
    if [ -n "$LOG_FILE" ]; then
        case "$level" in
            "INFO") colored_message="${BLUE}[$timestamp] [${BOLD}$level${RESET}${BLUE}] $message${RESET}" ;;
            "WARNING") colored_message="${YELLOW}[$timestamp] [${BOLD}$level${RESET}${YELLOW}] $message${RESET}" ;;
            "ERROR") colored_message="${RED}[$timestamp] [${BOLD}$level${RESET}${RED}] $message${RESET}" ;;
            "SUCCESS") colored_message="${GREEN}[$timestamp] [${BOLD}$level${RESET}${GREEN}] $message${RESET}" ;;
            *) colored_message="[$timestamp] [$level] $message" ;;
        esac
        # 使用 tee 將訊息同時輸出到螢幕和日誌檔
        echo -e "$colored_message" | tee -a "$LOG_FILE"
    else
        # 如果 LOG_FILE 未定義，只輸出到螢幕
        case "$level" in
            "INFO") colored_message="${BLUE}[$timestamp] [${BOLD}$level${RESET}${BLUE}] $message${RESET}" ;;
            "WARNING") colored_message="${YELLOW}[$timestamp] [${BOLD}$level${RESET}${YELLOW}] $message${RESET}" ;;
            "ERROR") colored_message="${RED}[$timestamp] [${BOLD}$level${RESET}${RED}] $message${RESET}" ;;
            "SUCCESS") colored_message="${GREEN}[$timestamp] [${BOLD}$level${RESET}${GREEN}] $message${RESET}" ;;
            *) colored_message="[$timestamp] [$level] $message" ;;
        esac
        echo -e "$colored_message"
        # 可以加一個警告，說明日誌功能未啟用
        # echo -e "${YELLOW}警告：LOG_FILE 未設定，日誌未寫入檔案。${RESET}" >&2
    fi
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
############################################
auto_update_script() {
    # --- 函數邏輯不變 ---
    clear
    echo -e "${CYAN}--- 開始檢查腳本更新 ---${RESET}"
    log_message "INFO" "使用者觸發檢查腳本更新。"

    local local_version="$SCRIPT_VERSION"
    local remote_version=""
    local remote_version_file="$TEMP_DIR/remote_version.txt"
    local temp_script="$TEMP_DIR/media_processor_new.sh"

    echo -e "${YELLOW}正在從 $REMOTE_VERSION_URL 獲取最新版本號...${RESET}"
    if curl -Ls "$REMOTE_VERSION_URL" -o "$remote_version_file" --fail --connect-timeout 5; then
        remote_version=$(tr -d '\r\n' < "$remote_version_file")
        if [ -z "$remote_version" ]; then
             log_message "ERROR" "無法從遠程文件讀取有效的版本號。"
             echo -e "${RED}錯誤：無法讀取遠程版本號。${RESET}"
             rm -f "$remote_version_file"
             return 1
        fi
        log_message "INFO" "獲取的遠程版本號：$remote_version"
        rm -f "$remote_version_file"
    else
        log_message "ERROR" "無法下載版本文件：$REMOTE_VERSION_URL (Curl failed)"
        echo -e "${RED}錯誤：無法下載版本文件，請檢查網路連線或 URL。${RESET}"
        rm -f "$remote_version_file"
        return 1
    fi

    local local_version_clean=$(echo "$local_version" | sed 's/([^)]*)//g')
    local remote_version_clean=$(echo "$remote_version" | sed 's/([^)]*)//g')
    latest_version=$(printf '%s\n' "$remote_version_clean" "$local_version_clean" | sort -V | tail -n 1)

    if [[ "$local_version_clean" == "$latest_version" ]]; then
        log_message "INFO" "腳本已是最新版本 ($local_version)。"
        echo -e "${GREEN}腳本已是最新版本 ($local_version)。${RESET}"
        return 0
    fi

    echo -e "${YELLOW}發現新版本：$remote_version (當前版本：$local_version)。${RESET}"
    read -p "是否要立即下載並更新腳本？ (y/N): " confirm_update
    if [[ ! "$confirm_update" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消更新。"
        echo -e "${YELLOW}已取消更新。${RESET}"
        return 0
    fi

    echo -e "${YELLOW}正在從 $REMOTE_SCRIPT_URL 下載新版本腳本...${RESET}"
    if curl -Ls "$REMOTE_SCRIPT_URL" -o "$temp_script" --fail --connect-timeout 30; then
        log_message "INFO" "新版本腳本下載成功：$temp_script"
        # --- (可選) 校驗和驗證 ---
        echo -e "${YELLOW}正在替換舊腳本：$SCRIPT_INSTALL_PATH ${RESET}"
        chmod +x "$temp_script"
        if mv "$temp_script" "$SCRIPT_INSTALL_PATH"; then
            log_message "SUCCESS" "腳本已成功更新至版本 $remote_version。"
            echo -e "${GREEN}腳本更新成功！版本：$remote_version ${RESET}"
            echo -e "${CYAN}請重新啟動腳本 ('media' 或執行 '$SCRIPT_INSTALL_PATH') 以載入新版本。${RESET}"
            exit 0
        else
            log_message "ERROR" "無法替換舊腳本 '$SCRIPT_INSTALL_PATH'。請檢查權限。"
            echo -e "${RED}錯誤：無法替換舊腳本。請檢查權限。${RESET}"
            echo -e "${YELLOW}下載的新腳本保留在：$temp_script ${RESET}"
            return 1
        fi
    else
        log_message "ERROR" "下載新腳本失敗：$REMOTE_SCRIPT_URL (Curl failed)"
        echo -e "${RED}錯誤：下載新腳本失敗。${RESET}"
        rm -f "$temp_script"
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
    # --- 函數邏輯不變 ---
    for file in "$@"; do
        if [ -f "$file" ]; then
            echo -e "${YELLOW}清理臨時檔案：$file${RESET}"
            rm -f "$file"
            [ $? -eq 0 ] && log_message "INFO" "已安全刪除：$file" || log_message "WARNING" "無法刪除：$file"
        fi
    done
}


############################################
# 檢查並更新依賴套件 (修改)
############################################
update_dependencies() {
    # 使用新的跨平台邏輯
    local pkg_tools=("ffmpeg" "jq" "curl" "python") # pkg管理的基礎工具名 (python 在不同系統可能不同)
    local pip_tools=("yt-dlp")
    local all_tools=("ffmpeg" "ffprobe" "jq" "curl" "python" "python3" "pip" "pip3" "yt-dlp") # 擴大驗證範圍
    local verify_tools=("ffmpeg" "ffprobe" "jq" "curl" "yt-dlp") # 最終必須存在的工具
    local python_available=false
    local pip_available=false
    local update_failed=false
    local missing_after_update=()

    clear
    echo -e "${CYAN}--- 開始檢查並更新依賴套件 (OS: $OS_TYPE) ---${RESET}"
    log_message "INFO" "使用者觸發依賴套件更新流程 (OS: $OS_TYPE)。"

    # 1. 更新套件列表
    echo -e "${YELLOW}[1/4] 正在更新套件列表...${RESET}"
    local update_cmd=""
    local needs_sudo=false # 標記是否需要 sudo
    if [[ "$PACKAGE_MANAGER" == "pkg" ]]; then
        update_cmd="pkg update -y"
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        update_cmd="sudo apt update -y"
        needs_sudo=true
    elif [[ "$PACKAGE_MANAGER" == "dnf" || "$PACKAGE_MANAGER" == "yum" ]]; then
         update_cmd="sudo $PACKAGE_MANAGER check-update -y"
         needs_sudo=true
    else
        echo -e "${YELLOW}  > 警告：未知的套件管理器 ($PACKAGE_MANAGER)，跳過列表更新。${RESET}"
        log_message "WARNING" "未知套件管理器 ($PACKAGE_MANAGER)，跳過列表更新。"
    fi

    if [ -n "$update_cmd" ]; then
        echo "執行: $update_cmd"
        if eval "$update_cmd"; then
             log_message "INFO" "套件列表更新成功"
             echo -e "${GREEN}  > 套件列表更新成功。${RESET}"
        else
             log_message "WARNING" "套件列表更新失敗。"
             echo -e "${RED}  > 警告：套件列表更新失敗，將嘗試使用現有列表。${RESET}"
             update_failed=true
        fi
    fi
    echo ""

    # 2. 安裝/更新包管理器管理的工具
    echo -e "${YELLOW}[2/4] 正在安裝/更新套件: ${pkg_tools[*]} (以及 pip)...${RESET}"
    local install_cmd=""
    local pkgs_to_install=()
    if [[ "$PACKAGE_MANAGER" == "pkg" ]]; then
        pkgs_to_install=("ffmpeg" "jq" "curl" "python" "python-pip")
        install_cmd="pkg install -y ${pkgs_to_install[*]}"
    elif [[ "$PACKAGE_MANAGER" == "apt" ]]; then
        pkgs_to_install=("ffmpeg" "jq" "curl" "python3" "python3-pip")
        install_cmd="sudo apt install -y ${pkgs_to_install[*]}"
    elif [[ "$PACKAGE_MANAGER" == "dnf" || "$PACKAGE_MANAGER" == "yum" ]]; then
        pkgs_to_install=("ffmpeg" "jq" "curl" "python3" "python3-pip")
        install_cmd="sudo $PACKAGE_MANAGER install -y ${pkgs_to_install[*]}"
    else
         echo -e "${YELLOW}  > 警告：未知的套件管理器，無法自動安裝基礎套件。${RESET}"
         log_message "WARNING" "未知套件管理器，跳過安裝基礎套件"
         missing_after_update+=("ffmpeg" "jq" "curl" "python/python3" "pip/pip3")
    fi

    if [ -n "$install_cmd" ]; then
        echo "執行: $install_cmd"
        if eval "$install_cmd"; then
            log_message "INFO" "安裝/更新 ${pkgs_to_install[*]} 成功 (或已是最新)"
            echo -e "${GREEN}  > 安裝/更新 ${pkgs_to_install[*]} 完成。${RESET}"
        else
             log_message "ERROR" "安裝/更新 ${pkgs_to_install[*]} 失敗！"
             echo -e "${RED}  > 錯誤：安裝/更新 ${pkgs_to_install[*]} 失敗！${RESET}"
             update_failed=true
        fi
    fi
    echo ""

    # 3. 更新 pip 管理的工具 (yt-dlp)
    echo -e "${YELLOW}[3/4] 正在更新 pip 套件: ${pip_tools[*]}...${RESET}"
    local python_cmd=""
    local pip_cmd=""
    if command -v python3 &> /dev/null; then
        python_cmd="python3"
        if command -v pip3 &> /dev/null; then pip_cmd="pip3";
        elif $python_cmd -m pip --version &> /dev/null; then pip_cmd="$python_cmd -m pip"; fi
    elif command -v python &> /dev/null; then
        python_cmd="python"
        if command -v pip &> /dev/null; then pip_cmd="pip";
        elif $python_cmd -m pip --version &> /dev/null; then pip_cmd="$python_cmd -m pip"; fi
    fi

    if [ -z "$pip_cmd" ]; then
        log_message "ERROR" "找不到 pip 或 pip3 命令，無法更新 ${pip_tools[*]}。"
        echo -e "${RED}  > 錯誤：找不到 pip 或 pip3 命令，無法更新 ${pip_tools[*]}。請確保步驟 2 已成功安裝 python 和 pip。${RESET}"
        update_failed=true
    else
        local pip_update_cmd="$pip_cmd install --upgrade ${pip_tools[*]}"
        if [[ "$OS_TYPE" != "termux" ]] && [[ $EUID -ne 0 ]]; then
             pip_update_cmd="$pip_cmd install --upgrade --user ${pip_tools[*]}"
        fi
        echo "執行: $pip_update_cmd"
        if eval "$pip_update_cmd"; then
             log_message "INFO" "更新 ${pip_tools[*]} 成功"
             echo -e "${GREEN}  > 更新 ${pip_tools[*]} 完成。${RESET}"
        else
             if [[ "$needs_sudo" = true ]] && [[ "$pip_update_cmd" == *"--user"* ]]; then
                  echo -e "${RED}  > 錯誤：使用 '--user' 更新 ${pip_tools[*]} 失敗！${RESET}"
                  local sudo_pip_update_cmd="sudo $pip_cmd install --upgrade ${pip_tools[*]}"
                  echo -e "${YELLOW}  > 正在嘗試使用 sudo 執行: $sudo_pip_update_cmd ${RESET}"
                  if eval "$sudo_pip_update_cmd"; then
                       log_message "INFO" "使用 sudo 更新 ${pip_tools[*]} 成功"
                       echo -e "${GREEN}  > 使用 sudo 更新 ${pip_tools[*]} 完成。${RESET}"
                  else
                       log_message "ERROR" "使用 sudo 更新 ${pip_tools[*]} 失敗！"
                       echo -e "${RED}  > 錯誤：使用 sudo 更新 ${pip_tools[*]} 仍然失敗！${RESET}"
                       update_failed=true
                  fi
             else
                  log_message "ERROR" "更新 ${pip_tools[*]} 失敗！"
                  echo -e "${RED}  > 錯誤：更新 ${pip_tools[*]} 失敗！${RESET}"
                  update_failed=true
             fi
        fi
    fi
    echo ""

    # 4. 最終驗證必要工具
    echo -e "${YELLOW}[4/4] 正在驗證必要工具是否已安裝: ${verify_tools[*]}...${RESET}"
    local current_missing=()
    python_available=$(command -v python || command -v python3)
    # pip_available=$(command -v pip || command -v pip3) # 驗證 pip 非必須

    for tool in "${verify_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            current_missing+=("$tool")
            echo -e "${RED}  > 驗證失敗：找不到 $tool ${RESET}"
        else
             echo -e "${GREEN}  > 驗證成功：找到 $tool ${RESET}"
        fi
    done
    if ! $python_available; then current_missing+=("python/python3"); fi

    missing_after_update+=("${current_missing[@]}")
    missing_after_update=($(echo "${missing_after_update[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # 總結結果
    if [ ${#missing_after_update[@]} -ne 0 ]; then
        log_message "ERROR" "更新流程完成後，仍然缺少工具: ${missing_after_update[*]}"
        echo -e "${RED}--- 更新結果：失敗 ---${RESET}"
        echo -e "${RED}更新/安裝後，仍然缺少以下必要工具：${RESET}"
        for tool in "${missing_after_update[@]}"; do echo -e "${YELLOW}  - $tool${RESET}"; done
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
            log_message "ERROR" "
