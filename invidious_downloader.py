#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import cloudscraper  # 確保我們導入了正確的工具
import re
import json
from urllib.parse import urlparse, parse_qs

# --- 設定 ---
# (v3.2.0 - 正確實現 Piped + CloudScraper)
PIPED_INSTANCE = "https://pipedapi.kavin.rocks"
SCRIPT_VERSION = "3.2.0"

def log_message(level, message):
    print(f"[{level}] {message}", file=sys.stderr)

def parse_youtube_url(url):
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'v' in parse_qs(parsed_url.query): return 'video', parse_qs(parsed_url.query)['v'][0]
        if 'youtu.be' in parsed_url.hostname: return 'video', parsed_url.path.strip('/')
    return None, None

def get_best_audio_stream_from_piped(video_id, scraper):
    """★★★ 使用 cloudscraper 從 Piped API 獲取資訊 ★★★"""
    try:
        api_url = f"{PIPED_INSTANCE}/streams/{video_id}"
        log_message("INFO", f"正在使用 cloudscraper 從 Piped API 查詢: {api_url}")
        
        # ★★★ 核心：使用 scraper 物件發送 GET 請求，它會自動處理反爬蟲驗證 ★★★
        response = scraper.get(api_url, timeout=30)
        
        log_message("DEBUG", f"Piped API 狀態碼: {response.status_code}")
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
        
        # Piped API 的 m4a 流有時被錯誤標記為 mp4，手動校正
        if extension == 'mp4' and best_stream.get('format') == 'M4A':
            log_message("DEBUG", "檢測到 M4A 流被標記為 mp4，自動校正為 m4a。")
            extension = 'm4a'
            
        return stream_url, safe_title, extension

    except Exception as e:
        log_message("ERROR", f"訪問 Piped API 或處理時發生錯誤: {e}")
        return None, None, None

def download_file(url, output_path, scraper):
    """使用 cloudscraper 下載檔案"""
    try:
        log_message("INFO", "開始下載音訊流...")
        with scraper.get(url, stream=True, timeout=90) as r:
            r.raise_for_status()
            total_size = int(r.headers.get('content-length', 0)); bytes_downloaded = 0
            log_message("INFO", f"檔案總大小: {total_size / 1024 / 1024:.2f} MB")
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk); bytes_downloaded += len(chunk)
                    if total_size > 0:
                        progress = int(50 * bytes_downloaded / total_size)
                        sys.stderr.write(f"\r[{'=' * progress}{' ' * (50 - progress)}] {bytes_downloaded/1024/1024:.2f} MB")
                        sys.stderr.flush()
            sys.stderr.write('\n')
            log_message("SUCCESS", f"檔案成功下載至: {output_path}")
            return True
    except Exception as e:
        log_message("ERROR", f"下載過程中發生錯誤: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description=f"Piped 音訊下載器 v{SCRIPT_VERSION}")
    parser.add_argument("url", help="YouTube 影片的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    args = parser.parse_args()
    
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id or url_type != 'video':
        log_message("CRITICAL", "無法從 URL 中解析出有效的 YouTube 影片 ID。此模組暫不支援播放列表。")
        sys.exit(1)
    
    # ★★★ 核心：在主函數開頭創建一個 scraper 物件 ★★★
    # 這個物件就是我們的「裝甲車」，它會處理所有後續的請求
    try:
        scraper = cloudscraper.create_scraper()
    except Exception as e:
        log_message("CRITICAL", f"創建 cloudscraper 實例失敗: {e}")
        log_message("CRITICAL", "這可能意味著 Node.js 依賴項未正確安裝。請嘗試執行 'pkg install nodejs-lts'。")
        sys.exit(1)

    audio_url, title, extension = get_best_audio_stream_from_piped(media_id, scraper)
    
    if audio_url:
        output_path = f"{args.output_dir}/{title} [{media_id}].{extension}"
        if download_file(audio_url, output_path, scraper):
            print(output_path)
            sys.exit(0)
            
    log_message("CRITICAL", "透過 Piped API 下載失敗。請檢查上方的錯誤日誌。")
    sys.exit(1)

if __name__ == "__main__":
    main()
