#!/bin/bash

# --- 腳本設定 ---
# 這個版本被設計為由主腳本呼叫，故移除了所有互動式選單。
# 它接收一個參數 (URL 或本機路徑) 並直接處理。
SCRIPT_VERSION="v2.1.3_external_module"

# ★★★ 核心路徑修正 ★★★
# 假設此腳本與主腳本、Python腳本在同一個目錄
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DOWNLOAD_PATH="$SCRIPT_DIR/downloads" # 預設下載路徑，主腳本中可能會有更詳細的設定
LOG_FILE="$DOWNLOAD_PATH/audio_enricher_log.txt"
METADATA_ENRICHER_SCRIPT_PATH="$SCRIPT_DIR/enrich_metadata.py"

# 顏色代碼
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'
PURPLE='\033[0;35m'; CYAN='\033[0;36m'; WHITE='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'

# 日誌函數
log_message() {
    local level="$1"; local message="$2"; local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    mkdir -p "$(dirname "$LOG_FILE")"
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    # 外部腳本的終端輸出可以簡化
    case "$level" in
        "INFO")    echo -e "${BLUE}[$level] $message${RESET}" ;;
        "WARNING") echo -e "${YELLOW}[$level] $message${RESET}" ;;
        "ERROR")   echo -e "${RED}[$level] $message${RESET}" ;;
        "SUCCESS") echo -e "${GREEN}[$level] $message${RESET}" ;;
        *)         echo "[$level] $message" ;;
    esac
}

# 高解析度封面圖片下載函數 (保持原樣)
download_high_res_thumbnail() {
    local media_url="$1"; local output_image="$2"; local video_id=""
    echo -e "${YELLOW}取得影片 ID...${RESET}"
    video_id=$(yt-dlp --get-id "$media_url" 2>/dev/null)
    # <<< 修正語法錯誤 >>>
    if [ -z "$video_id" ]; then log_message "WARNING" "無法取得影片 ID，將跳過封面圖片下載。"; return 1; fi
    echo -e "${YELLOW}搜尋最佳解析度縮略圖...${RESET}"
    local thumbnail_sizes=("maxresdefault" "sddefault" "hqdefault" "mqdefault" "default")
    for size in "${thumbnail_sizes[@]}"; do
        echo -e "${YELLOW}嘗試下載 $size 解析度縮略圖...${RESET}"
        local thumbnail_url="https://i.ytimg.com/vi/${video_id}/${size}.jpg"
        local http_status=$(curl -s -o /dev/null -w "%{http_code}" "$thumbnail_url")
        if [ "$http_status" -eq 200 ]; then
            echo -e "${YELLOW}正在下載縮略圖 ($size)...${RESET}"
            if curl -s "$thumbnail_url" -o "$output_image"; then
                # <<< 修正語法錯誤 >>>
                log_message "INFO" "下載封面圖片成功：$thumbnail_url"
                echo -e "${GREEN}封面圖片下載完成！${RESET}"
                return 0
            # <<< 修正語法錯誤 >>>
            else log_message "WARNING" "下載圖片失敗：$thumbnail_url"; fi
        fi
    done
    # <<< 修正語法錯誤 >>>
    log_message "WARNING" "無法下載封面圖片。"; echo -e "${RED}封面圖片下載失敗！${RESET}"; return 1
}

# 檢查並設定執行緒數量 (保持原樣)
set_threads() {
    local temp_threads="$1"
    if [[ "$temp_threads" =~ ^[1-8]$ ]]; then
        THREADS=$temp_threads
        # <<< 修正語法錯誤 >>>
        log_message "INFO" "執行緒數量已更新為 $THREADS"
        echo -e "${GREEN}執行緒數量已設為 $THREADS${RESET}"
        return 0
    else
        # <<< 修正語法錯誤 >>>
        log_message "ERROR" "無效的執行緒數量，必須介於 $MIN_THREADS 和 $MAX_THREADS 之間"
        echo -e "${RED}無效的執行緒數量，必須介於 $MIN_THREADS 和 $MAX_THREADS 之間${RESET}"
        return 1
    fi
}

# 安全刪除函數 (保持原樣, 但修正調用)
safe_remove() {
    for file in "$@"; do
        if [ -f "$file" ]; then
            # 保持原樣，每次刪除都輸出訊息
            # echo -e "${YELLOW}清理臨時檔案...${RESET}" # 決定在此函數內不輸出，由調用處控制
            rm -f "$file"
            # <<< 修正語法錯誤 >>>
            if [ $? -eq 0 ]; then
                 log_message "INFO" "已安全刪除：$file"
            else
                 log_message "WARNING" "無法刪除：$file"
            fi
        fi
    done
}

############################################
# <<< 新增：從工作腳本複製過來的 normalize_audio 函數 (修正內部函數調用) >>>
############################################
normalize_audio() {
    local input_file="$1"    # 輸入檔案 (應為 WAV)
    local output_file="$2"   # 輸出檔案 (最終格式，這裡是 MP3)
    local temp_dir="$3"      # 臨時目錄
    local is_video="false"   # 在此腳本中固定為 false
    local audio_wav="$input_file"
    local normalized_wav="$temp_dir/normalized_audio.wav"
    local loudnorm_log="$temp_dir/loudnorm.log"
    local stats_json="$temp_dir/stats.json"
    local ffmpeg_status=0

    echo -e "${YELLOW}執行第一遍音量分析...${RESET}"
    # <<< 修正語法錯誤 >>>
    log_message "INFO" "執行第一遍音量分析: $audio_wav"
    ffmpeg -y -i "$audio_wav" -af loudnorm=I=-12:TP=-1.5:LRA=11:print_format=json -f null - 2> "$loudnorm_log"
    if [ $? -ne 0 ]; then
        # <<< 修正語法錯誤 >>>
        log_message "ERROR" "第一遍音量分析失敗！檢查 $loudnorm_log"
        echo -e "${RED}錯誤：音量分析失敗${RESET}"; cat "$loudnorm_log"; return 1
    fi
    echo -e "${GREEN}第一遍音量分析完成${RESET}"

    echo -e "${YELLOW}解析音量分析結果...${RESET}"
    awk '/^\{/{flag=1}/^\}/{print;flag=0}flag' "$loudnorm_log" > "$stats_json"
    if [ ! -s "$stats_json" ]; then
         # <<< 修正語法錯誤 >>>
         log_message "ERROR" "解析音量分析參數失敗 (awk 未能提取 JSON?)。檢查 $loudnorm_log"
         echo -e "${RED}錯誤：解析音量參數失敗 (JSON 為空)${RESET}"; return 1
    fi
    local measured_I=$(jq -r '.input_i // empty' "$stats_json")
    local measured_TP=$(jq -r '.input_tp // empty' "$stats_json")
    local measured_LRA=$(jq -r '.input_lra // empty' "$stats_json")
    local measured_thresh=$(jq -r '.input_thresh // empty' "$stats_json")
    local offset=$(jq -r '.target_offset // empty' "$stats_json")

    if [ -z "$measured_I" ] || [ -z "$measured_TP" ] || [ -z "$measured_LRA" ] || [ -z "$measured_thresh" ] || [ -z "$offset" ]; then
        # <<< 修正語法錯誤 >>>
        log_message "ERROR" "音量分析參數提取失敗 (jq 未能提取值)。JSON: $(cat "$stats_json")"
        echo -e "${RED}錯誤：音量分析參數提取失敗 (jq 失敗)${RESET}"; return 1
    fi
    # <<< 修正語法錯誤 >>>
    log_message "INFO" "Loudnorm Pass 1 Parsed: I=$measured_I, TP=$measured_TP, LRA=$measured_LRA, Thresh=$measured_thresh, Offset=$offset"

    echo -e "${YELLOW}執行第二遍音量標準化 (WAV)...${RESET}"
    # <<< 修正語法錯誤 >>>
    log_message "INFO" "執行第二遍音量標準化: $audio_wav -> $normalized_wav"
    ffmpeg -y -i "$audio_wav" \
        -af "loudnorm=I=-12:TP=-1.5:LRA=11:measured_I=$measured_I:measured_TP=$measured_TP:measured_LRA=$measured_LRA:measured_thresh=$measured_thresh:offset=$offset:linear=true:print_format=summary" \
        -c:a pcm_s16le "$normalized_wav" > "$temp_dir/ffmpeg_norm_pass2.log" 2>&1
    ffmpeg_status=$?

    if [ "$ffmpeg_status" -ne 0 ] || [ ! -f "$normalized_wav" ]; then
        # <<< 修正語法錯誤 >>>
        log_message "ERROR" "第二遍音量標準化失敗！(ffmpeg exit code: $ffmpeg_status)。詳見 $temp_dir/ffmpeg_norm_pass2.log"
        echo -e "${RED}錯誤：音量標準化失敗${RESET}"; cat "$temp_dir/ffmpeg_norm_pass2.log"; return 1
    fi
    echo -e "${GREEN}第二遍音量標準化 (WAV) 完成${RESET}"

    echo -e "${YELLOW}正在轉換為 MP3 格式...${RESET}"
    # <<< 修正語法錯誤 >>>
    log_message "INFO" "轉換標準化 WAV 為初步 MP3: $normalized_wav -> $output_file"
    ffmpeg -y -i "$normalized_wav" -c:a libmp3lame -b:a 320k "$output_file" > "$temp_dir/ffmpeg_final_mp3.log" 2>&1
    if [ $? -ne 0 ] || [ ! -f "$output_file" ]; then
         # <<< 修正語法錯誤 >>>
         log_message "ERROR" "轉換為 MP3 失敗！詳見 $temp_dir/ffmpeg_final_mp3.log"
         echo -e "${RED}錯誤：MP3 轉換失敗${RESET}"; cat "$temp_dir/ffmpeg_final_mp3.log";
         # <<< 修正語法錯誤 >>>
         safe_remove "$normalized_wav" # 即使失敗也清理標準化 WAV
         return 1
    fi
    echo -e "${GREEN}MP3 轉換完成${RESET}"

    echo -e "${YELLOW}清理函數內部臨時檔案...${RESET}" # 添加清理提示
    # <<< 修正語法錯誤 >>>
    safe_remove "$normalized_wav" "$loudnorm_log" "$stats_json" \
                "$temp_dir/ffmpeg_norm_pass2.log" "$temp_dir/ffmpeg_final_mp3.log"
    return 0 # 返回成功
}

############################################
# <<< 替換：完整的 process_media 函數 (Bash 程式碼) >>>
# 使用 normalize_audio 函數，整合 Python 調用並根據退出碼判斷
############################################
process_media() {
    local input="$1"
    local is_local=false
    local audio_file=""         # 原始下載/本地檔案
    local video_title=""        # 基礎標題
    local artist_name="[不明]"
    local album_artist_name="[不明]"
    local base_name=""
    local media_url=""          # 僅用於網路資源
    local result=0
    local python_enricher_success=false # 標記 Python 是否成功處理並寫入
    local cover_image=""        # YouTube 封面路徑

    # --- 初始化 ---
    log_message "INFO" "開始處理輸入: $input" # Bash 函數調用
    echo -e "${YELLOW}初始化處理...${RESET}"
    # 創建臨時目錄
    local temp_dir=$(mktemp -d)
    # 檢查 mktemp 是否成功
    if [ -z "$temp_dir" ] || [ ! -d "$temp_dir" ]; then
        log_message "ERROR" "無法創建臨時目錄！"
        echo -e "${RED}錯誤：無法創建臨時目錄！${RESET}"
        return 1
    fi
    log_message "DEBUG" "臨時目錄已創建: $temp_dir"
    local wav_audio=""          # 轉換後的 WAV 路徑
    local normalized_mp3="$temp_dir/normalized_audio.mp3" # normalize_audio 的輸出路徑

    # --- 檢查下載目錄 ---
    echo -e "${YELLOW}檢查下載目錄...${RESET}"
    mkdir -p "$DOWNLOAD_PATH"
    if [ ! -w "$DOWNLOAD_PATH" ]; then
        log_message "ERROR" "無法寫入下載目錄：$DOWNLOAD_PATH"
        echo -e "${RED}錯誤：無法寫入下載目錄${RESET}"
        rm -rf "$temp_dir" # 清理已創建的臨時目錄
        return 1
    fi

    # --- 1. 處理輸入 (區分本地/網路，獲取資訊，下載音頻) ---
    if [ -f "$input" ]; then
        is_local=true
        audio_file="$input"
        base_name="$(basename "$audio_file" | sed 's/\.[^.]*$//')"
        wav_audio="$temp_dir/${base_name}.wav"
        log_message "INFO" "處理本機音訊檔案：$audio_file" # Bash 函數調用
        echo -e "${YELLOW}處理本機音訊檔案: $base_name ${RESET}"
        video_title="$base_name" # 使用檔名作為基礎標題
        artist_name="[不明]" # 本地檔案無藝術家信息
        album_artist_name="[不明]"
        # 本地檔案無 cover_image
    else # 網路 URL
        is_local=false
        media_url="$input"
        log_message "INFO" "處理網路媒體：$media_url" # Bash 函數調用
        echo -e "${YELLOW}處理 YouTube 媒體...${RESET}"

        # --- 分析媒體資訊 ---
        echo -e "${YELLOW}分析媒體資訊...${RESET}"
        local metadata_json=$(yt-dlp --dump-json "$media_url" 2> "$temp_dir/yt-dlp-json.log")
        if [ -z "$metadata_json" ]; then
            log_message "ERROR" "無法獲取媒體 JSON 資訊 (詳見 $temp_dir/yt-dlp-json.log)" # Bash 函數調用
            echo -e "${RED}錯誤：無法分析媒體資訊。${RESET}"; cat "$temp_dir/yt-dlp-json.log"; rm -rf "$temp_dir"; return 1
        fi
        video_title=$(echo "$metadata_json" | jq -r '.title // "Untitled"')
        local possible_artist=$(echo "$metadata_json" | jq -r '.artist // empty'); local uploader=$(echo "$metadata_json" | jq -r '.uploader // "[不明]"'); local video_id=$(echo "$metadata_json" | jq -r '.id // "NO_ID"')
        if [[ -n "$possible_artist" && "$possible_artist" != "null" ]]; then artist_name="$possible_artist"; else artist_name="$uploader"; fi; album_artist_name="$uploader"
        log_message "INFO" "獲取到標題: $video_title, 基礎藝術家: $artist_name" # Bash 函數調用

        # --- 下載音頻 ---
        echo -e "${YELLOW}開始下載音頻：$video_title${RESET}"
        local safe_title=$(echo "$video_title" | sed 's@[/\\:*?"<>|]@_@g'); local output_template="$DOWNLOAD_PATH/${safe_title} [${video_id}].%(ext)s"
        # 注意：原腳本的 THREADS 變數未在此函數中使用，如果需要多線程下載，應加入 --concurrent-fragments "$THREADS"
        local yt_dlp_dl_args=(yt-dlp -f bestaudio -o "$output_template" "$media_url" --newline --progress)
        if ! "${yt_dlp_dl_args[@]}" 2> "$temp_dir/yt-dlp-dl.log"; then
            log_message "ERROR" "音訊下載失敗 (詳見 $temp_dir/yt-dlp-dl.log)"; echo -e "${RED}錯誤：音訊下載失敗${RESET}"; cat "$temp_dir/yt-dlp-dl.log"; rm -rf "$temp_dir"; return 1 # Bash 函數調用
        fi
        local yt_dlp_fn_args=(yt-dlp --get-filename -f bestaudio -o "$output_template" "$media_url"); audio_file=$("${yt_dlp_fn_args[@]}" 2>/dev/null)
        if [ ! -f "$audio_file" ]; then
             log_message "ERROR" "找不到下載的音頻檔案 '$audio_file'"; echo -e "${RED}錯誤：找不到下載的音頻檔案${RESET}"; rm -rf "$temp_dir"; return 1 # Bash 函數調用
        fi
        log_message "INFO" "音頻下載完成: $audio_file" # Bash 函數調用
        base_name="$(basename "$audio_file" | sed 's/\.[^.]*$//')"
        wav_audio="$temp_dir/${base_name}.wav"

        # --- 下載 YouTube 封面 (始終執行) ---
        echo -e "${YELLOW}下載 YouTube 封面 (備份)...${RESET}"
        cover_image="$temp_dir/${base_name}_youtube_cover.png"
        if ! download_high_res_thumbnail "$media_url" "$cover_image"; then # Bash 函數調用
             cover_image=""; log_message "WARNING" "基礎封面圖片下載失敗。" # Bash 函數調用
        else
             log_message "INFO" "YouTube 備份封面已下載到: $cover_image" # Bash 函數調用
        fi
    fi

    # --- 2. 轉換為 WAV ---
    echo -e "${YELLOW}轉換音訊為 WAV 格式進行處理...${RESET}"
    log_message "INFO" "轉換 '$audio_file' 為 WAV: $wav_audio" # Bash 函數調用
    if ! ffmpeg -y -i "$audio_file" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$wav_audio" > "$temp_dir/ffmpeg_wav.log" 2>&1; then
        log_message "ERROR" "轉換為 WAV 失敗！詳見 $temp_dir/ffmpeg_wav.log"; echo -e "${RED}錯誤：無法轉換為 WAV 格式${RESET}"; cat "$temp_dir/ffmpeg_wav.log"; # Bash 函數調用
        [ "$is_local" = false ] && safe_remove "$audio_file"; rm -rf "$temp_dir"; return 1 # Bash 函數調用
    fi
    log_message "INFO" "轉換為 WAV 成功。" # Bash 函數調用
    [ "$is_local" = false ] && safe_remove "$audio_file" # Bash 函數調用

    # --- 3. 調用 normalize_audio 函數 (輸出初步 MP3) ---
    echo -e "${YELLOW}開始音量標準化並轉換為 MP3...${RESET}"
    # 假設 normalize_audio 函數已正確添加到此腳本中
    if normalize_audio "$wav_audio" "$normalized_mp3" "$temp_dir" false; then # Bash 函數調用
        log_message "INFO" "音量標準化並轉換為初步 MP3 成功: $normalized_mp3" # Bash 函數調用
        safe_remove "$wav_audio" # 清理 WAV # Bash 函數調用

        # --- 4. 嘗試調用 Python 元數據豐富器 ---
        local python_cmd=""; if command -v python3 &> /dev/null; then python_cmd="python3"; elif command -v python &> /dev/null; then python_cmd="python"; fi
        local enricher_script="$METADATA_ENRICHER_SCRIPT_PATH"
        local python_exit_code=1 # 預設為失敗

        if [[ -n "$python_cmd" && -f "$enricher_script" ]]; then
            # 預覽將要執行的命令
            local python_call_cmd=("$python_cmd" "$enricher_script" "$normalized_mp3" "$video_title" "$artist_name" --youtube-cover "$cover_image" -v)

            # --- 暫停點 (保持不變) ---
            # --- 結束暫停點 ---

            # --- 正式調用 Python 並捕獲退出碼 ---
            echo -e "\n${YELLOW}繼續執行，正在調用 Python 元數據豐富器...${RESET}"
            log_message "INFO" "調用元數據豐富器: ${python_call_cmd[*]}" # Bash 函數調用

            "${python_call_cmd[@]}" # 執行 Python
            python_exit_code=$?     # 捕獲退出碼

            # --- 根據退出碼判斷結果 ---
            if [ $python_exit_code -eq 0 ]; then
                log_message "INFO" "Python 腳本成功完成並應用了元數據。" # Bash 函數調用
                echo -e "${GREEN}元數據豐富化成功。${RESET}"
                python_enricher_success=true
            elif [ $python_exit_code -eq 2 ]; then
                log_message "WARN" "Python 腳本正常結束，但未找到可接受的匹配。" # Bash 函數調用
                echo -e "${YELLOW}未找到匹配的元數據，將使用基礎信息。${RESET}"
                python_enricher_success=false
            else # 其他非零退出碼
                log_message "ERROR" "Python 腳本執行時發生錯誤 (退出碼 $python_exit_code)。" # Bash 函數調用
                echo -e "${RED}錯誤：元數據豐富化過程中發生錯誤。將回退。${RESET}"
                python_enricher_success=false
            fi
        else # Python 或腳本未找到
             if [ ! -f "$enricher_script" ]; then log_message "WARNING" "未找到元數據豐富器腳本: $enricher_script"; echo -e "${YELLOW}警告：未找到元數據豐富器腳本。${RESET}"; # Bash 函數調用
             else log_message "WARNING" "未找到 Python 環境。"; echo -e "${YELLOW}警告：未找到 Python 環境。${RESET}"; fi # Bash 函數調用
             echo -e "${YELLOW}無法執行元數據豐富化，將使用基礎元數據。${RESET}"
             python_enricher_success=false
        fi

        # --- 5. 生成最終輸出檔案 ---
        local output_audio="$DOWNLOAD_PATH/${base_name}_final.mp3"
        echo -e "${YELLOW}正在生成最終 MP3 檔案...${RESET}"

        if $python_enricher_success; then
            # Python 成功，直接移動
            log_message "INFO" "移動已處理的檔案到最終位置: $normalized_mp3 -> $output_audio" # Bash 函數調用
            if mv "$normalized_mp3" "$output_audio"; then
                 log_message "SUCCESS" "最終檔案生成成功。"; result=0 # Bash 函數調用
            else
                 log_message "ERROR" "無法移動 '$normalized_mp3' 到 '$output_audio'！"; echo -e "${RED}錯誤：無法生成最終檔案！${RESET}"; result=1 # Bash 函數調用
            fi
        else
            # Python 未處理或失敗，執行回退
            log_message "INFO" "回退：使用基礎元數據和封面處理 MP3: $normalized_mp3 -> $output_audio" # Bash 函數調用
            # 檢查臨時 MP3 是否存在
            if [ ! -f "$normalized_mp3" ]; then
                 log_message "ERROR" "回退失敗：找不到用於回退處理的臨時 MP3 檔案 '$normalized_mp3'!" # Bash 函數調用
                 echo -e "${RED}錯誤：回退處理失敗，臨時檔案丟失！${RESET}"
                 result=1
            else
                # 執行 ffmpeg 嵌入
                local ffmpeg_embed_args=(ffmpeg -y -i "$normalized_mp3")
                log_message "DEBUG" "回退處理使用的信息：Cover='$cover_image', Artist='$artist_name', AlbumArtist='$album_artist_name', Title='$video_title'" # Bash 函數調用
                if [[ "$is_local" = false && -n "$cover_image" && -f "$cover_image" ]]; then
                    log_message "INFO" "嵌入基礎元數據和 YouTube 備份封面..." # Bash 函數調用
                    ffmpeg_embed_args+=(-i "$cover_image" -map 0:a -map 1:v -c copy -id3v2_version 3 -metadata title="$video_title" -metadata artist="$artist_name" -metadata album_artist="$album_artist_name" -metadata:s:v title="Album cover" -metadata:s:v comment="Cover (front)" -disposition:v attached_pic)
                else
                     log_message "INFO" "僅嵌入基礎元數據..." # Bash 函數調用
                     ffmpeg_embed_args+=(-c copy -id3v2_version 3 -metadata title="$video_title" -metadata artist="$artist_name" -metadata album_artist="$album_artist_name")
                fi
                ffmpeg_embed_args+=("$output_audio")

                log_message "INFO" "執行 FFmpeg 回退處理命令: ${ffmpeg_embed_args[*]}" # Bash 函數調用
                if ! "${ffmpeg_embed_args[@]}" > "$temp_dir/ffmpeg_fallback.log" 2>&1; then
                    log_message "ERROR" "回退處理失敗！詳見 $temp_dir/ffmpeg_fallback.log"; echo -e "${RED}錯誤：基礎元數據處理失敗！${RESET}"; cat "$temp_dir/ffmpeg_fallback.log"; result=1 # Bash 函數調用
                else
                     log_message "INFO" "基礎元數據處理完成。"; echo -e "${GREEN}基礎元數據處理完成。${RESET}"; result=0 # Bash 函數調用
                fi
                safe_remove "$normalized_mp3" # 回退處理完畢，刪除臨時 MP3 # Bash 函數調用
            fi # 結束 if [ ! -f "$normalized_mp3" ]
        fi # 結束 if $python_enricher_success

    else # normalize_audio 函數失敗
        log_message "ERROR" "音量標準化或初步 MP3 轉換失敗！" # Bash 函數調用
        safe_remove "$wav_audio"; result=1 # Bash 函數調用
    fi # 結束 normalize_audio 的 if

    # --- 6. 清理 ---
    log_message "INFO" "執行最終清理..." # Bash 函數調用
    [ -n "$cover_image" ] && [ -f "$cover_image" ] && safe_remove "$cover_image" # Bash 函數調用
    # 清理主要日誌
    safe_remove "$temp_dir/yt-dlp-json.log" "$temp_dir/yt-dlp-dl.log" \
                "$temp_dir/ffmpeg_wav.log" "$temp_dir/ffmpeg_fallback.log" # Bash 函數調用
    # normalize_audio 函數會清理它自己的臨時檔案
    # 清理 Python 日誌（如果之前有重定向的話）
    # safe_remove "$temp_dir/python_enricher.log"

    if [ -d "$temp_dir" ]; then
         if rmdir "$temp_dir" 2>/dev/null; then log_message "INFO" "臨時目錄已移除: $temp_dir"; # Bash 函數調用
         else log_message "WARN" "無法移除臨時目錄: $temp_dir"; fi # Bash 函數調用
    fi

    # --- 7. 最終結果 ---
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}處理完成！最終檔案已儲存至：$output_audio${RESET}"
        log_message "SUCCESS" "處理完成！最終檔案：$output_audio" # Bash 函數調用
    else
        echo -e "${RED}處理失敗！請檢查日誌獲取更多資訊。${RESET}"
        log_message "ERROR" "處理失敗：$input" # Bash 函數調用
    fi
    return $result
} # <<< 確保這個 } 是函數的結尾

# --- 主執行邏輯 ---
main() {
    # 檢查是否提供了輸入參數
    if [ -z "$1" ]; then
        log_message "ERROR" "啟動失敗：未提供任何輸入 (URL 或檔案路徑)。"
        echo -e "${RED}錯誤：此腳本需要一個 URL 或檔案路徑作為參數來執行。${RESET}"
        exit 1
    fi

    local input="$1"
    log_message "INFO" "音訊豐富化模組啟動，處理目標：$input"
    
    # 直接調用核心處理函數
    process_media "$input"
    local exit_code=$? # 捕獲 process_media 的退出碼

    if [ $exit_code -eq 0 ]; then
        log_message "SUCCESS" "音訊豐富化模組處理成功。"
    else
        log_message "ERROR" "音訊豐富化模組處理失敗，退出碼: $exit_code"
    fi

    exit $exit_code # 將處理結果作為腳本的最終退出碼返回
}

# 執行主函數，並將腳本的第一個參數 ($1) 傳遞給它
main "$@"
