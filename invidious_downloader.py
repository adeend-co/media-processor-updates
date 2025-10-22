#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import cloudscraper  # 使用 cloudscraper 替代 requests
import re
import random
from urllib.parse import urlparse, parse_qs
from requests.exceptions import ConnectionError # 仍然需要導入此類型用於判斷

# --- 設定 ---
# (v1.3 - 2025-10-22 最新穩定實例列表)
INVIDIOUS_INSTANCES = [
    "https://yewtu.be", "https://vid.puffyan.us", "https://invidious.kavin.rocks",
    "https://inv.id.is", "https://invidious.projectsegfau.lt", "https://invidious.protokoll.fi",
    "https://invidious.nerdvpn.de", "https://invidious.slipfox.xyz",
]
SCRIPT_VERSION = "1.4.1" # 版本更新，修正遺漏的 DNS 錯誤提示

def log_message(level, message, to_stderr=True):
    """向指定輸出流打印日誌。"""
    stream = sys.stderr if to_stderr else sys.stdout
    print(f"[{level}] {message}", file=stream)

def parse_youtube_url(url):
    """從各種 YouTube URL 格式中提取影片 ID 或播放列表 ID。"""
    parsed_url = urlparse(url)
    if 'youtube.com' in parsed_url.hostname or 'youtu.be' in parsed_url.hostname:
        if 'list' in parse_qs(parsed_url.query): return 'playlist', parse_qs(parsed_url.query)['list'][0]
        if 'v' in parse_qs(parsed_url.query): return 'video', parse_qs(parsed_url.query)['v'][0]
        if 'youtu.be' in parsed_url.hostname: return 'video', parsed_url.path.strip('/')
    return None, None

def get_best_audio_stream(video_id, instance, scraper):
    """從 Invidious API 獲取影片的最佳音訊流 URL。"""
    try:
        api_url = f"{instance}/api/v1/videos/{video_id}"
        log_message("INFO", f"正在使用 cloudscraper 從 {api_url} 查詢影片資訊...")
        
        # 使用 scraper 物件發送 GET 請求，它會自動處理瀏覽器偽裝
        response = scraper.get(api_url, timeout=20)
        response.raise_for_status()
        
        video_data = response.json()
        audio_streams = [s for s in video_data.get('adaptiveFormats', []) if 'audio' in s.get('type', '')]
        if not audio_streams: audio_streams = [s for s in video_data.get('formatStreams', []) if s.get('audio_quality')]
        if not audio_streams:
            log_message("ERROR", "API 響應成功，但在 JSON 中未找到任何可用的音訊流。")
            return None, None, None
            
        best_stream = sorted(audio_streams, key=lambda x: x.get('bitrate', 0), reverse=True)[0]
        video_title = video_data.get('title', video_id)
        safe_title = re.sub(r'[\\/*?:"<>|]', "_", video_title)
        return best_stream.get('url'), safe_title, best_stream.get('mimeType', 'audio/webm').split('/')[1]

    # ★★★ 核心修正：恢復 v1.2.0 版本中完整的、人性化的錯誤提示邏輯 ★★★
    except ConnectionError as e:
        # 智慧判斷錯誤的根本原因是否為 DNS 解析失敗
        if 'Failed to resolve' in str(e) or 'Name or service not known' in str(e):
            # 將詳細的解決方案提示打印到 stdout，讓主腳本的使用者能直接看到
            log_message("ERROR", f"DNS 解析失敗: 無法找到伺服器 '{instance}' 的地址。", to_stderr=False)
            log_message("HINT", "-------------------------------------------------------------", to_stderr=False)
            log_message("HINT", "這通常是您當前的網路 DNS 設定問題，而非腳本錯誤。", to_stderr=False)
            log_message("HINT", "請嘗試切換網路 (例如從 Wi-Fi 切換到行動數據)，或", to_stderr=False)
            log_message("HINT", "在 Termux 中執行以下命令來設定一個更可靠的 DNS:", to_stderr=False)
            log_message("HINT", "  pkg install resolv-conf && termux-resolv-conf -s 1.1.1.1", to_stderr=False)
            log_message("HINT", "-------------------------------------------------------------", to_stderr=False)
        else:
            # 如果是其他網路連線錯誤，則正常記錄
            log_message("ERROR", f"網路連線錯誤: {e}")
        return None, None, None
    except Exception as e:
        # 捕捉其他所有可能的錯誤，例如 JSON 解析錯誤、伺服器錯誤 (404, 502 等)
        log_message("ERROR", f"處理時發生錯誤: {e}")
        return None, None, None
    # ★★★ 修正結束 ★★★

def download_file(url, output_path, scraper):
    """下載檔案並顯示進度。"""
    try:
        # 下載時也使用 scraper 物件
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
    """主執行函數。"""
    parser = argparse.ArgumentParser(description=f"Invidious 音訊下載器 v{SCRIPT_VERSION}")
    parser.add_argument("url", help="YouTube 影片或播放列表的 URL")
    parser.add_argument("output_dir", help="儲存下載檔案的目錄")
    args = parser.parse_args()
    url_type, media_id = parse_youtube_url(args.url)
    if not media_id:
        log_message("CRITICAL", "無法從 URL 中解析出有效的 ID。"); sys.exit(1)
    
    # 創建一個 scraper 物件，它將在整個腳本運行期間被重用
    try:
        scraper = cloudscraper.create_scraper()
    except Exception as e:
        log_message("CRITICAL", f"初始化 cloudscraper 失敗: {e}")
        log_message("HINT", "請確保您已執行 'pip install cloudscraper'。")
        log_message("HINT", "如果安裝後仍然失敗，可能需要安裝 'nodejs-lts' (pkg install nodejs-lts)。")
        sys.exit(1)
    
    random.shuffle(INVIDIOUS_INSTANCES)
    
    if url_type == 'video':
        for instance in INVIDIOUS_INSTANCES:
            log_message("INFO", f"正在嘗試 Invidious 實例: {instance}")
            # 將 scraper 物件傳遞給處理函數
            audio_url, title, extension = get_best_audio_stream(media_id, instance, scraper)
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
