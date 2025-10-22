#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import requests
import re
from urllib.parse import urlparse, parse_qs

# --- 設定 ---
# (v3.0.0 - 終極嘗試，切換到 Piped API)
# Piped 的官方實例，通常比 Invidious 公開實例更穩定
PIPED_INSTANCE = "https://pipedapi.kavin.rocks"
SCRIPT_VERSION = "3.0.0"

def log_message(level, message):
    print(f"[{level}] {message}", file=sys.stderr)

def parse_youtube_url(url):
    # ... (此函數邏輯不變) ...
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'v' in parse_qs(parsed_url.query): return 'video', parse_qs(parsed_url.query)['v'][0]
        if 'youtu.be' in parsed_url.hostname: return 'video', parsed_url.path.strip('/')
    return None, None

def get_best_audio_stream_from_piped(video_id):
    """★★★ 全新核心邏輯：從 Piped API 獲取資訊 ★★★"""
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
            
        # Piped API 的結構不同，直接按 bitrate 排序
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        
        stream_url = best_stream.get('url')
        video_title = data.get('title', video_id)
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        
        # 從 mimeType 推斷擴展名
        extension = best_stream.get('mimeType', 'audio/webm').split('/')[-1]
        
        return stream_url, safe_title, extension

    except Exception as e:
        log_message("ERROR", f"訪問 Piped API 或處理時發生錯誤: {e}")
        return None, None, None

def download_file(url, output_path):
    # ... (此函數邏輯不變) ...
    try:
        headers = {'User-Agent': 'Mozilla/5.0'}
        with requests.get(url, stream=True, timeout=60, headers=headers) as r:
            r.raise_for_status()
            total_size = int(r.headers.get('content-length', 0)); bytes_downloaded = 0
            # ... (進度條邏輯) ...
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192): f.write(chunk)
        return True
    except Exception as e:
        return False

def main():
    parser = argparse.ArgumentParser(description=f"Piped/Invidious 音訊下載器 v{SCRIPT_VERSION}")
    # ... (main 函數邏輯簡化，因為只用 Piped) ...
    args = parser.parse_args()
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id: sys.exit(1)
    
    audio_url, title, extension = get_best_audio_stream_from_piped(media_id)
    if audio_url:
        output_path = f"{args.output_dir}/{title} [{media_id}].{extension}"
        if download_file(audio_url, output_path):
            print(output_path); sys.exit(0)
            
    log_message("CRITICAL", "透過 Piped API 下載失敗。")
    sys.exit(1)

if __name__ == "__main__":
    main()
