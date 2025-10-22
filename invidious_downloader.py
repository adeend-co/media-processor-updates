#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import cloudscraper
import requests  # ★★★ 核心修正：將 import requests 加回來 ★★★
import re
import json
import random
from urllib.parse import urlparse, parse_qs, urljoin
from requests.exceptions import ConnectionError

# --- 設定 ---
INVIDIOUS_INSTANCES = [
    "https://yewtu.be", "https://vid.puffyan.us", "https://invidious.kavin.rocks",
    "https://inv.id.is", "https://invidious.projectsegfau.lt", "https://invidious.protokoll.fi",
    "https://invidious.nerdvpn.de", "https://invidious.slipfox.xyz",
]
SCRIPT_VERSION = "2.1.0" # 版本更新，修正 NameError

def log_message(level, message):
    print(f"[{level}] {message}", file=sys.stderr)

def parse_youtube_url(url):
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'list' in parse_qs(parsed_url.query): return 'playlist', parse_qs(parsed_url.query)['list'][0]
        if 'v' in parse_qs(parsed_url.query): return 'video', parse_qs(parsed_url.query)['v'][0]
        if 'youtu.be' in parsed_url.hostname: return 'video', parsed_url.path.strip('/')
    return None, None

def get_best_audio_stream_from_page(video_id, instance, scraper):
    """從網頁原始碼中解析影片資訊"""
    try:
        watch_url = f"{instance}/watch?v={video_id}"
        log_message("INFO", f"正在模擬瀏覽器訪問觀看頁面: {watch_url}")
        
        response = scraper.get(watch_url, timeout=25)
        response.raise_for_status()
        
        html_content = response.text
        
        match = re.search(r'player_data\s*=\s*JSON\.parse\(\'(.*?)\'\);', html_content)
        if not match:
            match = re.search(r'window\.player_data\s*=\s*({.*?});', html_content)
            if not match:
                log_message("ERROR", "在網頁原始碼中找不到 'player_data' JSON 區塊。")
                return None, None, None

        try:
            # 根據正則表達式的不同捕獲組來解析
            json_str = match.group(1)
            # 處理可能存在的 JS 八進制轉義 (\xxx)
            if "JSON.parse" in match.group(0):
                json_str = json_str.encode().decode('unicode_escape')

            video_data = json.loads(json_str)

        except json.JSONDecodeError as e:
            log_message("ERROR", f"成功提取但解析 JSON 失敗: {e}")
            return None, None, None

        audio_streams = [s for s in video_data.get('adaptiveFormats', []) if 'audio' in s.get('type', '')]
        if not audio_streams:
            audio_streams = [s for s in video_data.get('formatStreams', []) if s.get('audio_quality')]
        
        if not audio_streams:
            log_message("ERROR", "成功解析 JSON，但在其中未找到任何可用的音訊流。")
            return None, None, None
            
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        
        stream_url = best_stream.get('url')
        if not stream_url.startswith('http'):
            stream_url = urljoin(instance, stream_url)

        video_title = video_data.get('title', video_id)
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        
        return stream_url, safe_title, best_stream.get('mimeType', 'audio/webm').split('/')[1]

    # ★★★ 核心修正：使用更通用的異常捕獲 ★★★
    # cloudscraper 的錯誤繼承自 requests，所以捕獲 RequestException 是安全的
    except requests.exceptions.RequestException as e:
        if isinstance(getattr(e, '__cause__', None), ConnectionError) and ('Failed to resolve' in str(e) or 'Name or service not known' in str(e)):
            log_message("ERROR", f"DNS 解析失敗 for '{instance}'")
        else:
            log_message("ERROR", f"訪問網頁失敗: {e}")
        return None, None, None
    except Exception as e:
        log_message("ERROR", f"處理網頁時發生未知錯誤: {e}")
        return None, None, None

def download_file(url, output_path, scraper):
    try:
        with scraper.get(url, stream=True, timeout=60) as r:
            r.raise_for_status()
            total_size = int(r.headers.get('content-length', 0)); bytes_downloaded = 0
            log_message("INFO", f"開始下載，總大小: {total_size / 1024 / 1024:.2f} MB")
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk); bytes_downloaded += len(chunk)
                    progress = int(50 * bytes_downloaded / total_size) if total_size > 0 else 0
                    sys.stderr.write(f"\r[{'=' * progress}{' ' * (50 - progress)}] {bytes_downloaded/1024/1024:.2f} MB"); sys.stderr.flush()
        sys.stderr.write('\n'); log_message("SUCCESS", f"檔案成功下載至: {output_path}"); return True
    except Exception as e:
        log_message("ERROR", f"下載過程中發生錯誤: {e}"); return False

def main():
    parser = argparse.ArgumentParser(description=f"Invidious 音訊下載器 v{SCRIPT_VERSION}")
    parser.add_argument("url", help="YouTube 影片或播放列表的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    args = parser.parse_args()
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id:
        log_message("CRITICAL", "無法從 URL 中解析出有效的 ID。"); sys.exit(1)
    
    scraper = cloudscraper.create_scraper()
    random.shuffle(INVIDIOUS_INSTANCES)
    
    if url_type == 'video':
        for instance in INVIDIOUS_INSTANCES:
            log_message("INFO", f"正在嘗試 Invidious 實例: {instance}")
            audio_url, title, extension = get_best_audio_stream_from_page(media_id, instance, scraper)
            if audio_url:
                output_path = f"{args.output_dir}/{title} [{media_id}].{extension}"
                if download_file(audio_url, output_path, scraper):
                    print(output_path); sys.exit(0)
            log_message("WARN", f"實例 {instance} 失敗，嘗試下一個...")
        log_message("CRITICAL", "已嘗試所有 Invidious 實例，均無法成功下載。")
        sys.exit(1)
    elif url_type == 'playlist':
        log_message("CRITICAL", "播放列表功能目前在此模組中尚未實現。"); sys.exit(1)

if __name__ == "__main__":
    main()
