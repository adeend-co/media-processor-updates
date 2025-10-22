#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import requests
import re
import random
from urllib.parse import urlparse, parse_qs

# --- 設定 ---# --- 設定 ---
# 一個可靠的 Invidious 公開實例列表。腳本會隨機選取並在失敗時嘗試下一個。
# 您可以自行增減這個列表，尋找響應速度快的實例。
# (v1.1 - 2025-10-22 更新)
INVIDIOUS_INSTANCES = [
    # --- 歐洲區 (通常較穩定) ---
    "https://invidious.protokoll.fi",
    "https://invidious.really-sucks.org",
    "https://iv.ggtyler.dev",
    "https://invidious.privacydev.net",
    # --- 美洲區 ---
    "https://invidious.esmailelbob.xyz",
    "https://iv.nboeck.de",
    "https://invidious.private.coffee",
    # --- 亞洲區 (可以嘗試，速度可能較快) ---
    "https://invidious.tiekoetter.com",
]
SCRIPT_VERSION = "1.0.0"

def log_message(level, message):
    """向 stderr 輸出日誌，以便 Bash 腳本可以捕獲 stdout 的最終檔案路徑。"""
    print(f"[{level}] {message}", file=sys.stderr)

def parse_youtube_url(url):
    """從各種 YouTube URL 格式中提取影片 ID 或播放列表 ID。"""
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'list' in parse_qs(parsed_url.query):
            playlist_id = parse_qs(parsed_url.query)['list'][0]
            return 'playlist', playlist_id
        if 'v' in parse_qs(parsed_url.query):
            video_id = parse_qs(parsed_url.query)['v'][0]
            return 'video', video_id
        if 'youtu.be' in parsed_url.hostname:
            video_id = parsed_url.path.strip('/')
            return 'video', video_id
    return None, None

def get_best_audio_stream(video_id, instance):
    """從 Invidious API 獲取指定影片的最佳音訊流 URL。"""
    try:
        api_url = f"{instance}/api/v1/videos/{video_id}"
        log_message("INFO", f"正在從 {api_url} 查詢影片資訊...")
        response = requests.get(api_url, timeout=10)
        response.raise_for_status()
        video_data = response.json()

        audio_streams = []
        # adaptiveFormats 通常包含獨立的高品質音訊流
        for stream in video_data.get('adaptiveFormats', []):
            if 'audio' in stream.get('type', ''):
                audio_streams.append(stream)
        
        if not audio_streams:
            log_message("WARN", "在 adaptiveFormats 中未找到音訊流，嘗試 formatStreams...")
            # formatStreams 包含影音合一的流，作為備選
            for stream in video_data.get('formatStreams', []):
                 if stream.get('audio_quality'): # 任何有音訊的都可以
                    audio_streams.append(stream)

        if not audio_streams:
            log_message("ERROR", "未找到任何可用的音訊流。")
            return None, None, None

        # 按位元率 (bitrate) 降序排序，找到品質最好的
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        
        video_title = video_data.get('title', video_id)
        # 簡單清理檔名中的非法字元
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        
        return best_stream.get('url'), safe_title, best_stream.get('mimeType', 'audio/webm').split('/')[1]

    except requests.exceptions.RequestException as e:
        log_message("ERROR", f"API 請求失敗: {e}")
        return None, None, None
    except Exception as e:
        log_message("ERROR", f"解析音訊流時發生未知錯誤: {e}")
        return None, None, None

def download_file(url, output_path):
    """下載檔案並顯示進度。"""
    try:
        with requests.get(url, stream=True, timeout=30) as r:
            r.raise_for_status()
            total_size = int(r.headers.get('content-length', 0))
            bytes_downloaded = 0
            log_message("INFO", f"開始下載，總大小: {total_size / 1024 / 1024:.2f} MB")
            with open(output_path, 'wb') as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)
                    bytes_downloaded += len(chunk)
                    # 簡單的進度條
                    progress = int(50 * bytes_downloaded / total_size) if total_size > 0 else 0
                    sys.stderr.write(f"\r[{'=' * progress}{' ' * (50 - progress)}] {bytes_downloaded/1024/1024:.2f} MB")
                    sys.stderr.flush()
        sys.stderr.write('\n')
        log_message("SUCCESS", f"檔案成功下載至: {output_path}")
        return True
    except Exception as e:
        log_message("ERROR", f"下載過程中發生錯誤: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description=f"Invidious 音訊下載器 v{SCRIPT_VERSION}")
    parser.add_argument("url", help="YouTube 影片或播放列表的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    parser.add_argument("--version", action="version", version=f"%(prog)s {SCRIPT_VERSION}")
    args = parser.parse_args()

    url_type, media_id = parse_youtube_url(args.url)

    if not media_id:
        log_message("CRITICAL", "無法從 URL 中解析出有效的 YouTube 影片或播放列表 ID。")
        sys.exit(1)

    # 隨機打亂實例列表以分散負載
    random.shuffle(INVIDIOUS_INSTANCES)
    
    # --- 單一影片處理 ---
    if url_type == 'video':
        for instance in INVIDIOUS_INSTANCES:
            log_message("INFO", f"正在嘗試 Invidious 實例: {instance}")
            audio_url, title, extension = get_best_audio_stream(media_id, instance)
            
            if audio_url:
                output_filename = f"{title} [{media_id}].{extension}"
                output_path = f"{args.output_dir}/{output_filename}"
                
                if download_file(audio_url, output_path):
                    # ★★★ 核心：成功後，將最終的檔案路徑輸出到 stdout ★★★
                    # 主腳本將會讀取這個輸出
                    print(output_path)
                    sys.exit(0)
            
            log_message("WARN", f"實例 {instance} 失敗，嘗試下一個...")
        
        log_message("CRITICAL", "已嘗試所有 Invidious 實例，均無法成功下載。")
        sys.exit(1)

    # --- 播放列表處理 (目前暫不實現，但為未來預留框架) ---
    elif url_type == 'playlist':
        log_message("CRITICAL", "播放列表功能目前在此模組中尚未實現。")
        # 未來可以在此處添加遍歷播放列表並逐一下載的邏輯
        sys.exit(1)

if __name__ == "__main__":
    main()
