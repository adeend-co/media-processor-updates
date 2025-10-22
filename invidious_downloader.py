#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import requests
import re
from urllib.parse import urlparse, parse_qs

# --- 設定 ---
# (v3.1.0 - 修正 main 函數參數解析錯誤)
PIPED_INSTANCE = "https://pipedapi.kavin.rocks"
SCRIPT_VERSION = "3.1.0"

def log_message(level, message):
    print(f"[{level}] {message}", file=sys.stderr)

def parse_youtube_url(url):
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'v' in parse_qs(parsed_url.query): return 'video', parse_qs(parsed_url.query)['v'][0]
        if 'youtu.be' in parsed_url.hostname: return 'video', parsed_url.path.strip('/')
    return None, None

def get_best_audio_stream_from_piped(video_id):
    """從 Piped API 獲取資訊"""
    try:
        api_url = f"{PIPED_INSTANCE}/streams/{video_id}"
        log_message("INFO", f"正在從 Piped API 查詢影片資訊: {api_url}")
        
        headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36'}
        response = requests.get(api_url, timeout=20, headers=headers)
        response.raise_for_status()
        
        data = response.json()
        
        audio_streams = data.get('audioStreams', [])
        if not audio_streams:
            log_message("ERROR", "API 響應成功，但在 JSON 中未找到 'audioStreams'。")
            return None, None, None
            
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        
        stream_url = best_stream.get('url')
        video_title = data.get('title', video_id)
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        extension = best_stream.get('mimeType', 'audio/webm').split('/')[-1]
        
        return stream_url, safe_title, extension

    except Exception as e:
        log_message("ERROR", f"訪問 Piped API 或處理時發生錯誤: {e}")
        return None, None, None

def download_file(url, output_path):
    """下載檔案並顯示進度"""
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        with requests.get(url, stream=True, timeout=90, headers=headers) as r: # 增加超時時間
            r.raise_for_status()
            total_size = int(r.headers.get('content-length', 0)); bytes_downloaded = 0
            log_message("INFO", f"開始下載，總大小: {total_size / 1024 / 1024:.2f} MB")
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk); bytes_downloaded += len(chunk)
                    progress = int(50 * bytes_downloaded / total_size) if total_size > 0 else 0
                    sys.stderr.write(f"\r[{'=' * progress}{' ' * (50 - progress)}] {bytes_downloaded/1024/1024:.2f} MB"); sys.stderr.flush()
            sys.stderr.write('\n')
            log_message("SUCCESS", f"檔案成功下載至: {output_path}")
            return True
    except Exception as e:
        log_message("ERROR", f"下載過程中發生錯誤: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description=f"Piped 音訊下載器 v{SCRIPT_VERSION}")
    
    # ★★★ 核心修正：將遺失的參數定義加回來 ★★★
    parser.add_argument("url", help="YouTube 影片的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    
    args = parser.parse_args()
    
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id or url_type != 'video':
        log_message("CRITICAL", "無法從 URL 中解析出有效的 YouTube 影片 ID，或 URL 為播放列表。")
        sys.exit(1)
    
    audio_url, title, extension = get_best_audio_stream_from_piped(media_id)
    
    if audio_url:
        # Piped API 返回的擴展名可能有問題 (e.g., 'mp4' for an m4a)，手動校正
        if 'mp4' in extension and 'opus' in best_stream.get('codec',''):
             extension = 'm4a'

        output_path = f"{args.output_dir}/{title} [{media_id}].{extension}"
        if download_file(audio_url, output_path):
            print(output_path)
            sys.exit(0)
            
    log_message("CRITICAL", "透過 Piped API 下載失敗。")
    sys.exit(1)

if __name__ == "__main__":
    main()
