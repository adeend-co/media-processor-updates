#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import cloudscraper  # ★★★ 核心修正：重新引入 cloudscraper ★★★
import re
from urllib.parse import urlparse, parse_qs

# --- 設定 ---
# (v3.2.0 - 重新整合 cloudscraper 用於 Piped)
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
    """★★★ 核心修正：使用 scraper 物件訪問 Piped API ★★★"""
    try:
        api_url = f"{PIPED_INSTANCE}/streams/{video_id}"
        log_message("INFO", f"正在使用 cloudscraper 從 Piped API 查詢影片資訊: {api_url}")
        
        # 使用 scraper 物件發送請求，它會自動處理反機器人挑戰
        response = scraper.get(api_url, timeout=25)
        response.raise_for_status()
        
        data = response.json()
        
        audio_streams = data.get('audioStreams', [])
        if not audio_streams:
            log_message("ERROR", "API 響應成功，但在 JSON 中未找到 'audioStreams'。")
            return None, None, None, None
            
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        
        stream_url = best_stream.get('url')
        video_title = data.get('title', video_id)
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        extension = best_stream.get('mimeType', 'audio/webm').split('/')[-1]
        
        return stream_url, safe_title, extension, best_stream

    except Exception as e:
        log_message("ERROR", f"訪問 Piped API 或處理時發生錯誤: {e}")
        return None, None, None, None

def download_file(url, output_path, scraper):
    """下載時也使用 scraper"""
    try:
        with scraper.get(url, stream=True, timeout=90) as r:
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
    parser = argparse.ArgumentParser(description=f"Piped (with Cloudscraper) 音訊下載器 v{SCRIPT_VERSION}")
    parser.add_argument("url", help="YouTube 影片的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    args = parser.parse_args()
    
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id or url_type != 'video':
        log_message("CRITICAL", "無法從 URL 中解析出有效的 YouTube 影片 ID。")
        sys.exit(1)
    
    # ★★★ 核心修正：在 main 函數中創建並傳遞 scraper 物件 ★★★
    scraper = cloudscraper.create_scraper()
    
    audio_url, title, extension, best_stream = get_best_audio_stream_from_piped(media_id, scraper)
    
    if audio_url:
        # Piped API 返回的擴展名可能有問題 (e.g., 'mp4' for an m4a)，手動校正
        if 'mp4' in extension and best_stream and 'opus' in best_stream.get('codec',''):
             extension = 'm4a'
             log_message("DEBUG", "檢測到 Opus in MP4 容器，將擴展名校正為 .m4a")

        output_path = f"{args.output_dir}/{title} [{media_id}].{extension}"
        if download_file(audio_url, output_path, scraper):
            print(output_path)
            sys.exit(0)
            
    log_message("CRITICAL", "透過 Piped API (with Cloudscraper) 下載失敗。")
    sys.exit(1)

if __name__ == "__main__":
    # 確保依賴已安裝
    try:
        import cloudscraper
    except ImportError:
        log_message("CRITICAL", "缺少 'cloudscraper' 模組。請執行 'pip install cloudscraper'。")
        sys.exit(1)
    main()
