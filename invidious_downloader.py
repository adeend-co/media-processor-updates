#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import re
import json
import asyncio # ★★★ 新增：引入 asyncio 來處理異步函數 ★★★

# --- 設定 ---
# (v4.1.0 - 適應 curl_cffi 新版本用法)
PIPED_INSTANCE = "https://pipedapi.kavin.rocks"
SCRIPT_VERSION = "4.1.0"

def log_message(level, message):
    print(f"[{level}] {message}", file=sys.stderr)

# --- 依賴項檢查與延遲導入 ---
try:
    import cloudscraper
except ImportError:
    log_message("ERROR", "缺少 'cloudscraper' 模組。請執行 'pip install cloudscraper'。")
    sys.exit(1)
try:
    # ★★★ 核心修改：使用新的導入方式 ★★★
    from curl_cffi.aio import AsyncSession
    CURL_CFFI_AVAILABLE = True
except ImportError:
    log_message("WARN", "未找到 'curl_cffi' 模組。後備方案將不可用。可執行 'pip install curl_cffi'。")
    CURL_CFFI_AVAILABLE = False


def parse_youtube_url(url):
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'v' in parse_qs(parsed_url.query): return 'video', parse_qs(parsed_url.query)['v'][0]
        if 'youtu.be' in parsed_url.hostname: return 'video', parsed_url.path.strip('/')
    return None, None

def get_data_with_cloudscraper(api_url):
    # ... (此函數邏輯不變) ...
    try:
        log_message("INFO", f"【策略 1: cloudscraper】正在嘗試從 {api_url} 獲取資訊...")
        scraper = cloudscraper.create_scraper(browser={'browser': 'chrome', 'platform': 'windows', 'desktop': True})
        response = scraper.get(api_url, timeout=25)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        log_message("WARN", f"【策略 1: cloudscraper】失敗: {e}")
        return None

# ★★★ 核心修改：重寫 curl_cffi 的用法 ★★★
async def _get_data_with_curl_cffi_async(api_url):
    """異步函數，專門用於執行 curl_cffi 的請求"""
    if not CURL_CFFI_AVAILABLE:
        return None
    try:
        log_message("INFO", f"【策略 2: curl_cffi】正在嘗試從 {api_url} 獲取資訊...")
        async with AsyncSession() as session:
            response = await session.get(api_url, impersonate="chrome110", timeout=25)
            response.raise_for_status()
            return response.json()
    except Exception as e:
        log_message("WARN", f"【策略 2: curl_cffi】失敗: {e}")
        return None

def get_data_with_curl_cffi(api_url):
    """同步包裝器，讓我們可以在普通腳本中調用異步函數"""
    return asyncio.run(_get_data_with_curl_cffi_async(api_url))


def get_best_audio_stream_from_piped(video_id):
    # ... (此函數的策略調用邏輯不變) ...
    api_url = f"{PIPED_INSTANCE}/streams/{video_id}"
    data = get_data_with_cloudscraper(api_url)
    if data is None:
        data = get_data_with_curl_cffi(api_url)
    if data is None:
        log_message("ERROR", "所有策略均告失敗，無法獲取影片資訊。")
        return None, None, None
    try:
        # ... (後續的 JSON 解析邏輯不變) ...
        audio_streams = data.get('audioStreams', [])
        if not audio_streams:
            log_message("ERROR", "成功獲取數據，但在其中未找到 'audioStreams'。")
            return None, None, None
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        stream_url = best_stream.get('url')
        video_title = data.get('title', video_id)
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        extension = best_stream.get('mimeType', 'audio/webm').split('/')[-1]
        if extension == 'mp4' and 'opus' in best_stream.get('codec', '').lower():
            extension = 'm4a'
        return stream_url, safe_title, extension
    except Exception as e:
        log_message("ERROR", f"解析 Piped 數據時發生錯誤: {e}")
        return None, None, None

def download_file(url, output_path):
    # ... (此函數邏輯不變，它使用標準 requests，已在 v4.0.0 中修正) ...
    try:
        import requests # 在函數內部導入，避免與 curl_cffi 衝突
        headers = {'User-Agent': 'Mozilla/5.0'}
        with requests.get(url, stream=True, timeout=90, headers=headers) as r:
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
    # ... (main 函數邏輯不變) ...
    parser = argparse.ArgumentParser(description=f"Piped 音訊下載器 v{SCRIPT_VERSION}")
    parser.add_argument("url", help="YouTube 影片的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    args = parser.parse_args()
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id or url_type != 'video':
        log_message("CRITICAL", "無法從 URL 中解析出有效的 YouTube 影片 ID。")
        sys.exit(1)
    audio_url, title, extension = get_best_audio_stream_from_piped(media_id)
    if audio_url:
        output_path = f"{args.output_dir}/{title} [{media_id}].{extension}"
        if download_file(audio_url, output_path):
            print(output_path)
            sys.exit(0)
    log_message("CRITICAL", "最終下載失敗。")
    sys.exit(1)

if __name__ == "__main__":
    main()
