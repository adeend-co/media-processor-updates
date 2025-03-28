#!/bin/bash

# 腳本設定
SCRIPT_VERSION="v1.6.8(Experimental)" # <<< 版本號更新
# DEFAULT_URL, THREADS, MAX_THREADS, MIN_THREADS 保留
DEFAULT_URL="https://www.youtube.com/watch?v=siNFnlqtd8M"
THREADS=4
MAX_THREADS=8
MIN_THREADS=1
COLOR_ENABLED=true
# 自動更新設定保留
REMOTE_VERSION_URL="https://raw.githubusercontent.com/adeend-co/media-processor-updates/refs/heads/main/latest_version.txt" # <<< 請務必修改此 URL
REMOTE_SCRIPT_URL="https://raw.githubusercontent.com/adeend-co/media-processor-updates/refs/heads/main/media_processor.sh"   # <<< 請務必修改此 URL
SCRIPT_INSTALL_PATH="$HOME/scripts/media_processor.sh"

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
    # 與其他選單選項行為一致
    clear
    echo -e "${CYAN}--- 開始檢查腳本更新 ---${RESET}"
    log_message "INFO" "使用者觸發檢查腳本更新。"

    local local_version="$SCRIPT_VERSION"
    local remote_version=""
    local remote_version_raw="" # 用於儲存原始下載內容
    local remote_version_file="$TEMP_DIR/remote_version.txt"
    local temp_script="$TEMP_DIR/media_processor_new.sh"

    # --- 1. 獲取遠程版本號 ---
    echo -e "${YELLOW}正在從 $REMOTE_VERSION_URL 獲取最新版本號...${RESET}"
    if curl -Ls "$REMOTE_VERSION_URL" -o "$remote_version_file" --fail --connect-timeout 5; then
        # 讀取版本號，移除可能的回車換行符
        remote_version_raw=$(tr -d '\r\n' < "$remote_version_file")
        # <<< 新增：移除 UTF-8 BOM (EF BB BF) >>>
        # sed 使用十六進制 \xEF\xBB\xBF 匹配 BOM 並將其替換為空
        remote_version=$(echo "$remote_version_raw" | sed 's/^\xEF\xBB\xBF//')

        # 檢查非空 (現在檢查處理 BOM 之後的 remote_version)
        if [ -z "$remote_version" ]; then
             log_message "ERROR" "無法從遠程文件讀取有效的版本號。"
             echo -e "${RED}錯誤：無法讀取遠程版本號。${RESET}"
             rm -f "$remote_version_file"
             return 1 # 返回到主選單
        fi
        log_message "INFO" "獲取的遠程版本號：$remote_version" # 現在日誌應該不會有 BOM 了
        rm -f "$remote_version_file"
    else
        log_message "ERROR" "無法下載版本文件：$REMOTE_VERSION_URL (Curl failed)"
        echo -e "${RED}錯誤：無法下載版本文件，請檢查網路連線或 URL。${RESET}"
        rm -f "$remote_version_file" # 確保清理
        return 1 # 返回到主選單
    fi

    # --- 2. 比較版本號 ---
    # 清理版本號中的非比較部分，例如 (Experimental)
    local local_version_clean=$(echo "$local_version" | sed 's/([^)]*)//g')
    local remote_version_clean=$(echo "$remote_version" | sed 's/([^)]*)//g') # 現在 remote_version 已無 BOM

    # 使用 sort -V 進行版本比較
    latest_version=$(printf '%s\n' "$remote_version_clean" "$local_version_clean" | sort -V | tail -n 1)

    # 修改判斷條件：如果清理後的版本相同，或本地版本是 sort -V 認為最新的，則認為無需更新
    if [[ "$local_version_clean" == "$remote_version_clean" ]] || [[ "$local_version_clean" == "$latest_version" ]]; then
        log_message "INFO" "腳本已是最新版本 ($local_version)。"
        echo -e "${GREEN}腳本已是最新版本 ($local_version)。${RESET}"
        return 0 # 返回到主選單
    fi

    # --- 3. 確認更新 ---
    echo -e "${YELLOW}發現新版本：$remote_version (當前版本：$local_version)。${RESET}" # 這裡顯示的 remote_version 也無 BOM
    read -p "是否要立即下載並更新腳本？ (y/n): " confirm_update
    if [[ ! "$confirm_update" =~ ^[Yy]$ ]]; then
        log_message "INFO" "使用者取消更新。"
        echo -e "${YELLOW}已取消更新。${RESET}"
        return 0 # 返回到主選單
    fi

    # --- 4. 下載新腳本 ---
    echo -e "${YELLOW}正在從 $REMOTE_SCRIPT_URL 下載新版本腳本...${RESET}"
    if curl -Ls "$REMOTE_SCRIPT_URL" -o "$temp_script" --fail --connect-timeout 30; then
        log_message "INFO" "新版本腳本下載成功：$temp_script"

        # --- 5. 替換舊腳本 ---
        echo -e "${YELLOW}正在替換舊腳本：$SCRIPT_INSTALL_PATH ${RESET}"
        # 賦予新腳本執行權限
        chmod +x "$temp_script"
        
        # <<< 新增：確保目標目錄存在 >>>
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
    else
        log_message "ERROR" "下載新腳本失敗：$REMOTE_SCRIPT_URL (Curl failed)"
        echo -e "${RED}錯誤：下載新腳本失敗。${RESET}"
        rm -f "$temp_script" # 清理下載失敗的檔案
        return 1 # 返回到主選單
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
# 檢查並更新依賴套件
############################################
update_dependencies() {
    local pkg_tools=("ffmpeg" "jq" "curl" "python") # Tools managed by pkg
    local pip_tools=("yt-dlp")                     # Tools managed by pip
    local all_tools=("${pkg_tools[@]}" "${pip_tools[@]}" "ffprobe") # 添加 ffprobe 到驗證列表
    local update_failed=false
    local missing_after_update=()

    clear
    echo -e "${CYAN}--- 開始檢查並更新依賴套件 ---${RESET}"
    log_message "INFO" "使用者觸發依賴套件更新流程。"

    # 1. 更新 Termux 套件列表 (pkg update)
    echo -e "${YELLOW}[1/4] 正在更新 Termux 套件列表 (pkg update)...${RESET}"
    if pkg update -y; then
        log_message "INFO" "pkg update 成功"
        echo -e "${GREEN}  > Termux 套件列表更新成功。${RESET}"
    else
        log_message "WARNING" "pkg update 失敗，可能無法獲取最新套件版本。"
        echo -e "${RED}  > 警告：Termux 套件列表更新失敗，將嘗試使用現有列表。${RESET}"
        update_failed=true # 標記更新過程中有問題
    fi
    echo "" # 空行分隔

    # 2. 安裝/更新 pkg 管理的工具 (ffmpeg, jq, curl, python)
    #    FFmpeg 套件通常會包含 ffprobe，所以不用單獨安裝 ffprobe
    echo -e "${YELLOW}[2/4] 正在安裝/更新 pkg 套件: ${pkg_tools[*]}...${RESET}"
    if pkg install -y "${pkg_tools[@]}"; then
        log_message "INFO" "安裝/更新 ${pkg_tools[*]} 成功"
        echo -e "${GREEN}  > 安裝/更新 ${pkg_tools[*]} 完成。${RESET}"
    else
        log_message "ERROR" "安裝/更新 ${pkg_tools[*]} 失敗！"
        echo -e "${RED}  > 錯誤：安裝/更新 ${pkg_tools[*]} 失敗！${RESET}"
        update_failed=true
    fi
    echo ""

    # 3. 更新 pip 管理的工具 (yt-dlp)
    echo -e "${YELLOW}[3/4] 正在更新 pip 套件: ${pip_tools[*]}...${RESET}"
    # 檢查 Python 是否真的安裝成功
    if command -v python &> /dev/null; then
         if python -m pip install --upgrade "${pip_tools[@]}"; then
             log_message "INFO" "更新 ${pip_tools[*]} 成功"
             echo -e "${GREEN}  > 更新 ${pip_tools[*]} 完成。${RESET}"
         else
             log_message "ERROR" "更新 ${pip_tools[*]} 失敗！"
             echo -e "${RED}  > 錯誤：更新 ${pip_tools[*]} 失敗！${RESET}"
             update_failed=true
         fi
    else
        log_message "ERROR" "找不到 python 命令，無法更新 ${pip_tools[*]}。"
        echo -e "${RED}  > 錯誤：找不到 python 命令，無法更新 ${pip_tools[*]}。請確保步驟 2 已成功安裝 python。${RESET}"
        update_failed=true
    fi
    echo ""

    # 4. 最終驗證所有工具是否都已成功安裝
    echo -e "${YELLOW}[4/4] 正在驗證所有必要工具是否已安裝...${RESET}"
    for tool in "${all_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_after_update+=("$tool")
            echo -e "${RED}  > 驗證失敗：找不到 $tool ${RESET}"
        else
            echo -e "${GREEN}  > 驗證成功：找到 $tool ${RESET}"
        fi
    done
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
    # --- 函數邏輯不變 ---
    local audio_file="$1"
    if [ ! -f "$audio_file" ]; then echo -e "${RED}錯誤：檔案不存在！${RESET}"; return 1; fi
    local temp_dir=$(mktemp -d)
    local base_name=$(basename "$audio_file" | sed 's/\.[^.]*$//')
    local output_audio="$(dirname "$audio_file")/${base_name}_normalized.mp3"
    echo -e "${YELLOW}處理本機音訊檔案：$audio_file${RESET}"
    log_message "INFO" "處理本機音訊檔案：$audio_file"
    normalize_audio "$audio_file" "$output_audio" "$temp_dir" false
    local result=$?
    [ -d "$temp_dir" ] && rmdir "$temp_dir" 2>/dev/null
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}處理完成！音量標準化後的高品質音訊已儲存至：$output_audio${RESET}"
        log_message "SUCCESS" "處理完成！音量標準化後的高品質音訊已儲存至：$output_audio"
    else
        echo -e "${RED}處理失敗！${RESET}"
        log_message "ERROR" "處理失敗：$audio_file"
    fi
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
    # --- 函數邏輯不變 ---
    local input_url=""; local choice_format=""
    read -p "請輸入媒體網址 (單個或播放列表): " input_url; if [ -z "$input_url" ]; then echo -e "${RED}錯誤：未輸入！${RESET}"; return 1; fi
    log_message "INFO" "處理通用媒體/列表：$input_url"; echo -e "${YELLOW}處理通用媒體/列表：$input_url${RESET}"; echo -e "${YELLOW}注意：列表支持為實驗性。${RESET}"
    while true; do read -p "選擇格式 (1: MP3, 2: MP4): " cfn; case $cfn in 1) cf="mp3"; break;; 2) cf="mp4"; break;; *) echo "${RED}無效選項${RESET}";; esac; done; choice_format=$cf; log_message "INFO" "選擇格式: $choice_format"
    echo -e "${YELLOW}檢測是否為列表...${RESET}"; local item_list_json; local yt_dlp_dump_args=(yt-dlp --flat-playlist --dump-json "$input_url")
    item_list_json=$("${yt_dlp_dump_args[@]}" 2>/dev/null); local jec=$?; if [ $jec -ne 0 ]; then log_message "WARNING" "dump-json 失敗..."; fi
    local item_urls=(); local item_count=0
    if [ -n "$item_list_json" ] && command -v jq &> /dev/null; then while IFS= read -r line; do local url=$(echo "$line" | jq -r '.url // empty'); if [ -n "$url" ] && [ "$url" != "null" ]; then item_urls+=("$url"); fi; done <<< "$(echo "$item_list_json" | jq -c '. | select(.url != null)')"; item_count=${#item_urls[@]}; if [ "$item_count" -eq 0 ]; then log_message "WARNING" "未找到 URL 項目。"; fi;
    else if ! command -v jq &> /dev/null; then log_message "WARNING" "未找到 jq..."; fi; fi
    if [ "$item_count" -gt 1 ]; then
        log_message "INFO" "檢測到列表 ($item_count 項)。"; echo -e "${CYAN}檢測到列表 ($item_count 項)。開始批量處理...${RESET}"; local ci=0; local sc=0
        for item_url in "${item_urls[@]}"; do ci=$((ci + 1)); _process_single_other_site "$item_url" "$choice_format" "$ci" "$item_count"; if [ $? -eq 0 ]; then sc=$((sc + 1)); fi; echo ""; done
        echo -e "${GREEN}列表處理完成！共 $ci 項，成功 $sc 項。${RESET}"; log_message "SUCCESS" "列表 $input_url 完成！共 $ci 項，成功 $sc 項。"
    else
        if [ "$item_count" -eq 1 ]; then log_message "INFO" "檢測到 1 項，按單個處理。"; echo -e "${YELLOW}檢測到 1 項，按單個處理...${RESET}"; input_url=${item_urls[0]};
        else log_message "INFO" "未檢測到有效列表，按單個處理原始 URL。"; echo -e "${YELLOW}未檢測到列表，按單個處理...${RESET}"; fi
        _process_single_other_site "$input_url" "$choice_format"
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
    local total_videos=$(_get_playlist_video_count "$playlist_url"); if [ -z "$total_videos" ]; then echo -e "${RED}錯誤：無法獲取播放清單數量${RESET}"; return 1; fi
    echo -e "${CYAN}播放清單共有 $total_videos 個影片${RESET}"
    local playlist_ids_output; local yt_dlp_ids_args=(yt-dlp --flat-playlist -j "$playlist_url")
    playlist_ids_output=$("${yt_dlp_ids_args[@]}" 2>/dev/null); local gec=$?; if [ $gec -ne 0 ] || ! command -v jq &> /dev/null ; then log_message "ERROR" "無法獲取播放清單 IDs..."; echo -e "${RED}錯誤：無法獲取影片 ID 列表${RESET}"; return 1; fi
    local playlist_ids=(); while IFS= read -r id; do if [[ -n "$id" ]]; then playlist_ids+=("$id"); fi; done <<< "$(echo "$playlist_ids_output" | jq -r '.id // empty')"
    if [ ${#playlist_ids[@]} -eq 0 ]; then log_message "ERROR" "未找到影片 ID..."; echo -e "${RED}錯誤：未找到影片 ID${RESET}"; return 1; fi
    if [ ${#playlist_ids[@]} -ne "$total_videos" ]; then log_message "WARNING" "ID 數量與預計不符..."; echo -e "${YELLOW}警告：實際數量與預計不符...${RESET}"; total_videos=${#playlist_ids[@]}; fi
    local count=0; local success_count=0
    for id in "${playlist_ids[@]}"; do
        count=$((count + 1)); local video_url="https://www.youtube.com/watch?v=$id"
        log_message "INFO" "[$count/$total_videos] 處理影片: $video_url"; echo -e "${CYAN}--- 正在處理第 $count/$total_videos 個影片 ---${RESET}"
        if "$single_item_processor_func_name" "$video_url"; then success_count=$((success_count + 1)); else log_message "WARNING" "...處理失敗: $video_url"; fi; echo ""
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
# 動態調整執行緒數量
############################################
adjust_threads() {
    # --- 函數邏輯不變 ---
    local cpu_cores
    if command -v nproc &> /dev/null; then cpu_cores=$(nproc --all); elif [ -f /proc/cpuinfo ]; then cpu_cores=$(grep -c ^processor /proc/cpuinfo); elif command -v sysctl &> /dev/null && sysctl -n hw.ncpu > /dev/null 2>&1; then cpu_cores=$(sysctl -n hw.ncpu); else cpu_cores=4; log_message "WARNING" "無法檢測核心數，預設 4。"; fi
    if ! [[ "$cpu_cores" =~ ^[0-9]+$ ]] || [ "$cpu_cores" -lt 1 ]; then log_message "WARNING" "CPU 核心數 '$cpu_cores' 無效，預設 4。"; cpu_cores=4; fi
    local recommended_threads=$((cpu_cores * 3 / 4)); [ "$recommended_threads" -lt 1 ] && recommended_threads=1
    if [ $recommended_threads -gt $MAX_THREADS ]; then recommended_threads=$MAX_THREADS; elif [ $recommended_threads -lt $MIN_THREADS ]; then recommended_threads=$MIN_THREADS; fi
    THREADS=$recommended_threads; log_message "INFO" "執行緒自動調整為 $THREADS (核心數: $cpu_cores)"; echo -e "${GREEN}執行緒自動調整為 $THREADS${RESET}"
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

    # 再次確認腳本安裝路徑 (與腳本開頭 SCRIPT_INSTALL_PATH 保持一致)
    local target_script_path="$SCRIPT_INSTALL_PATH" 
    # 如果 SCRIPT_INSTALL_PATH 可能是相對路徑，最好轉成絕對路徑
    # 但在這個例子中， $HOME/scripts/... 已經是絕對路徑了

    log_message "INFO" "開始設定 Termux 啟動腳本..."
    echo -e "${YELLOW}正在寫入設定到 ~/.bashrc ...${RESET}"

    # 使用 cat 和 EOF 將配置寫入 .bashrc
    # 注意：EOF 內的 $target_script_path 會被正確解析
cat > "$HOME/.bashrc" << EOF
# ~/.bashrc - 由媒體處理器腳本自動產生

# (可選) 在此處加入您其他的 .bashrc 自訂內容

# --- 媒體處理器啟動設定 ---

# 1. 定義別名，方便手動啟動
alias media='$target_script_path'

# 2. 僅在交互式 Shell 啟動時顯示提示
if [[ \$- == *i* ]]; then
    # 定義顏色代碼
    local C_GREEN='\033[0;32m'
    local C_YELLOW='\033[1;33m'
    local C_RED='\033[0;31m'
    local C_CYAN='\033[0;36m'
    local C_RESET='\033[0m'
    
    echo "" 
    echo -e "\${C_CYAN}歡迎使用 Termux!\${C_RESET}"
    echo -e "\${C_YELLOW}是否要啟動媒體處理器？\${C_RESET}"
    echo -e "1) \${C_GREEN}立即啟動\${C_RESET}"
    echo -e "2) \${C_YELLOW}稍後啟動 (輸入 'media' 命令啟動)\${C_RESET}"
    echo -e "0) \${C_RED}不啟動\${C_RESET}"
    
    read -t 15 -p "請選擇 (0-2) [15秒後自動選 2]: " choice
    choice=\${choice:-2} 

    case \$choice in
        1) 
            echo -e "\n\${C_GREEN}正在啟動媒體處理器...\${C_RESET}"
            # 執行腳本
            "$target_script_path"
            ;;
        2) 
            echo -e "\n\${C_YELLOW}您可以隨時輸入 'media' 命令啟動媒體處理器\${C_RESET}" 
            ;;
        *) 
            echo -e "\n\${C_RED}已取消啟動媒體處理器\${C_RESET}" 
            ;;
    esac
    echo ""
fi

# --- 媒體處理器啟動設定結束 ---

# (可選) 在此處加入您其他的 .bashrc 自訂內容

EOF
    # 檢查寫入是否成功 (基本檢查)
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
    # --- 函數邏輯不變 ---
    read -p "設定執行緒 ($MIN_THREADS-$MAX_THREADS) [當前: $THREADS]: " tt
    if [[ "$tt" =~ ^[0-9]+$ ]] && [ "$tt" -ge "$MIN_THREADS" ] && [ "$tt" -le "$MAX_THREADS" ]; then THREADS=$tt; log_message "INFO" "執行緒設為 $THREADS"; echo -e "${GREEN}執行緒設為 $THREADS${RESET}"; else echo -e "${RED}無效數量...${RESET}"; fi
}

# 設定下載路徑
configure_download_path() {
    # --- 函數邏輯不變 ---
    read -e -p "設定下載路徑 [當前: $DOWNLOAD_PATH]: " tp; eval tp="$tp"
    if [ -n "$tp" ]; then
        if mkdir -p "$tp" 2>/dev/null && [ -w "$tp" ]; then DOWNLOAD_PATH="$tp"; LOG_FILE="$DOWNLOAD_PATH/script_log.txt"; log_message "INFO" "下載路徑更新為：$DOWNLOAD_PATH"; echo -e "${GREEN}下載路徑更新為：$DOWNLOAD_PATH${RESET}";
        else echo -e "${RED}無法設定路徑 '$tp'...${RESET}"; log_message "ERROR" "無法設定路徑 '$tp'"; fi
    else echo -e "${YELLOW}未輸入，保持當前設定。${RESET}"; fi
}

# 切換顏色輸出
toggle_color() {
    # --- 函數邏輯不變 ---
    if [ "$COLOR_ENABLED" = true ]; then COLOR_ENABLED=false; RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; BOLD=''; RESET=''; log_message "INFO" "顏色關閉"; echo "顏色關閉";
    else COLOR_ENABLED=true; RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'; log_message "INFO" "顏色啟用"; echo -e "${GREEN}顏色啟用${RESET}"; fi
}

# 檢視日誌
view_log() {
    # --- 函數邏輯不變 ---
    if [ -f "$LOG_FILE" ]; then less -R "$LOG_FILE"; else echo -e "${RED}日誌不存在: $LOG_FILE ${RESET}"; log_message "WARNING" "日誌不存在: $LOG_FILE"; sleep 2; fi
}

# 關於訊息
show_about() {
    clear
    echo -e "${CYAN}高品質媒體處理器 ${SCRIPT_VERSION}${RESET}"
    echo -e "${GREEN}特色：${RESET}"
    echo -e "- 支援 YouTube 影片與音訊下載 (MP3/MP4)"
    echo -e "- 支援通用網站媒體下載 (實驗性 MP3/MP4, yt-dlp 支持範圍)"
    echo -e "- 專業級音量標準化 (基於 EBU R128)"
    echo -e "- 高品質音訊編碼 (MP3 320k, AAC 256k)"
    echo -e "- 自動嵌入封面圖片與基礎元數據 (MP3)"
    echo -e "- 支援多語言字幕選擇與嵌入 (YouTube MP4)"
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
# 環境檢查 (修改)
############################################
check_environment() {
    # 使用新的跨平台邏輯
    local core_tools=("yt-dlp" "ffmpeg" "ffprobe" "jq" "curl")
    local missing_tools=()
    local python_found=false

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
    if command -v python &> /dev/null || command -v python3 &> /dev/null; then
        python_found=true
    else
        missing_tools+=("python/python3")
        echo -e "${YELLOW}  - 缺少: python 或 python3 ${RESET}"
    fi

    if [ ${#missing_tools[@]} -ne 0 ]; then
        clear
        echo -e "${RED}=== 環境檢查失敗 ===${RESET}"
        echo -e "${YELLOW}缺少以下必要工具或組件：${RESET}"
        for tool in "${missing_tools[@]}"; do echo -e "${RED}  - $tool${RESET}"; done
        echo -e "\n${CYAN}請嘗試運行選項 '6' (檢查並更新依賴套件) 來自動安裝，"
        echo -e "或者根據你的系統手動安裝它們。${RESET}"
        if [[ "$OS_TYPE" == "termux" ]]; then
             echo -e "${GREEN}Termux: pkg install ffmpeg jq curl python python-pip && pip install -U yt-dlp${RESET}"
        elif [[ "$OS_TYPE" == "wsl" && "$PACKAGE_MANAGER" == "apt" ]]; then
             echo -e "${GREEN}WSL (apt): sudo apt install ffmpeg jq curl python3 python3-pip && python3 -m pip install --upgrade --user yt-dlp${RESET}"
        else
             echo -e "${YELLOW}請參考你的 Linux 發行版或系統的文檔來安裝所需套件。${RESET}"
        fi
        echo -e "\n${RED}腳本無法繼續執行，請安裝所需工具後重試。${RESET}"
        log_message "ERROR" "環境檢查失敗，缺少工具: ${missing_tools[*]}"
        exit 1
    fi
    echo -e "${GREEN}  > 必要工具檢查通過。${RESET}"

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
    sleep 1
    return 0
}

############################################
# 主選單 (修改 - 添加 Termux 啟動設定選項)
############################################
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}=== 高品質媒體處理器 ${SCRIPT_VERSION} ===${RESET}"
        echo -e "${YELLOW}請選擇操作：${RESET}"
        echo -e " 1. ${BOLD}MP3 處理${RESET} (YouTube/本機)"
        echo -e " 2. ${BOLD}MP4 處理${RESET} (YouTube/本機)"
        echo -e " 2-1. 下載 MP4 (YouTube / ${BOLD}無${RESET}標準化)"
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
        # <<< 修改：更新選項範圍提示 >>>
        #     根據是否顯示選項 9，動態調整提示
        local prompt_range="0-8"
        if [[ "$OS_TYPE" == "termux" ]]; then
            prompt_range="0-9 或 2-1"
        else
            prompt_range="0-8 或 2-1"
        fi
        read -p "輸入選項 (${prompt_range}): " choice 

        case $choice in
            1) process_mp3 ;;
            2) process_mp4 ;;
            2-1) process_mp4_no_normalize ;;
            7) process_other_site_media_playlist ;;
            3) config_menu ;;
            4) view_log ;;
            6) update_dependencies ;; 
            8) 
               auto_update_script
               read -p "按 Enter 返回主選單..." 
               ;;
            # <<< 新增：處理選項 9 >>>
            9) 
               # 再次檢查是否為 Termux，以防萬一
               if [[ "$OS_TYPE" == "termux" ]]; then
                   setup_termux_autostart
               else
                   # 如果因為某些原因選了 9 但不是 Termux，顯示錯誤
                   echo -e "${RED}錯誤：此選項僅適用於 Termux。${RESET}"
                   sleep 1
               fi
               read -p "按 Enter 返回主選單..." # 提示返回
               ;;
            5) show_about ;;
            0) echo -e "${GREEN}感謝使用，正在退出...${RESET}"; log_message "INFO" "使用者選擇退出。"; sleep 1; exit 0 ;;
            *) echo -e "${RED}無效選項 '$choice'${RESET}"; log_message "WARNING" "主選單輸入無效選項: $choice"; sleep 1 ;;
        esac
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
    # --- 在 main 函數一開始記錄啟動訊息 ---
    log_message "INFO" "腳本啟動 (版本: $SCRIPT_VERSION, OS: $OS_TYPE)"

    # --- 環境檢查 ---
    if ! check_environment; then
        # check_environment 內部會在失敗時 exit
        return 1 # 理論上不會執行到這裡
    fi

    # --- 自動調整執行緒 ---
    adjust_threads
    # sleep 1 # 可選

    # --- 進入主選單 ---
    main_menu
}

# --- 執行主函數 ---
main
