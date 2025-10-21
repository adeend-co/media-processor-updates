#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import time
import requests
import musicbrainzngs
import mutagen
from mutagen.id3 import ID3, TIT2, TPE1, TALB, TDRC, APIC, TRCK, TCON, TPE2, TYER, COMM
from mutagen.mp4 import MP4, MP4Cover
from mutagen.flac import FLAC, Picture
from mutagen.oggvorbis import OggVorbis
from PIL import Image, UnidentifiedImageError
import io
import re
import os

# --- 設定 (保持不變) ---
APP_NAME = "MediaProcessorMetadataEnricher"
APP_VERSION = "1.0.6"
CONTACT_EMAIL = "boy789543@gmail.com" # 【務必修改】
API_DELAY = 1.1
DURATION_TOLERANCE_MS = 5000
MIN_MB_SCORE = 60

# --- 初始化 MusicBrainz (保持不變) ---
try:
    musicbrainzngs.set_useragent(APP_NAME, APP_VERSION, CONTACT_EMAIL)
except Exception as e:
    print(f"[CRITICAL] Failed to initialize MusicBrainz library: {e}", file=sys.stderr)
    sys.exit(1) # 初始化失敗，直接退出

# --- 全局 Verbose 標誌 (保持不變) ---
VERBOSE = False

# 日誌函數 (保持不變)
def log_message(level, message):
    if level == "DEBUG" and not VERBOSE:
        return
    print(f"[{level}] {message}", file=sys.stderr if level in ["ERROR", "WARN", "CRITICAL"] else sys.stdout)

# clean_title 函數 (使用上次修正的版本)
def clean_title(title):
    log_message("DEBUG", f"開始清理標題: '{title}'")
    cleaned = title
    patterns_in_brackets = [
        r'official\s*(music\s*)?video', r'mv', r'pv', r'lyrics?\s*(video)?',
        r'audio', r'hd', r'hq', r'4k', r'8k', r'\d{3,4}p',
        r'visuali[sz]er', r'sub(title)?s?', r'cc', r'explicit', r'full\s*album',
        r'feat\.?.*', r'ft\.?.*',
        r'off\s*vocal', r'instrumental', r'主題歌', r'アニメ', r'映画',
        r'original', r'ver\.?', r'edit', r'remix', r'live',
    ]
    for pattern in patterns_in_brackets:
        cleaned = re.sub(r'[\(\（\[【][^)\）\]】]*?' + pattern + r'[^)\）\]】]*?[\)\）\]】]', '', cleaned, flags=re.IGNORECASE)
    cleaned = re.sub(r'[\(\（]\s*[\)\）]', '', cleaned)
    cleaned = re.sub(r'[\(【]\s*[\)\]】]', '', cleaned)
    cleaned = re.sub(r'[「『]\s*[」』]', '', cleaned)
    artist_part = None; title_part = cleaned
    separators = [r'\s+-\s+', r'\s+–\s+', r'\s+／\s+']
    for sep in separators:
        parts = re.split(sep, cleaned, maxsplit=1)
        if len(parts) == 2:
            artist_part = parts[0].strip(); title_part = parts[1].strip()
            log_message("DEBUG", f"  檢測到分隔符 '{sep.strip()}'，分離出藝術家: '{artist_part}', 標題: '{title_part}'")
            break
    final_cleaned_title = title_part
    patterns_general = [ r'[\s_-]+$', r'^\s*[\d\s\._-]+', r'\s{2,}' ]
    for pattern in patterns_general: final_cleaned_title = re.sub(pattern, ' ', final_cleaned_title).strip()
    final_cleaned_title = re.sub(r'\s{2,}', ' ', final_cleaned_title).strip()
    if not final_cleaned_title: final_cleaned_title = title
    log_message("DEBUG", f"最終清理標題: '{final_cleaned_title}', 檢測到的藝術家: {artist_part}")
    return final_cleaned_title, artist_part

# get_audio_duration 函數 (保持不變)
def get_audio_duration(file_path):
    try:
        audio = mutagen.File(file_path, easy=False)
        if audio and audio.info and hasattr(audio.info, 'length'):
            return audio.info.length
    except mutagen.MutagenError as e: log_message("WARN", f"無法讀取檔案時長 '{file_path}': {e}")
    return None

# search_musicbrainz 函數 (使用上次的多策略版本)
def search_musicbrainz(title, artist=None, limit=5):
    """在 MusicBrainz 上搜索錄音 - 嘗試不同藝術家名變體"""
    recordings = None
    cleaned_title, detected_artist = clean_title(title) # 使用分離結果

    # 確定要嘗試的藝術家名列表
    artists_to_try = []
    if detected_artist:
        artists_to_try.append(detected_artist) # 優先用檢測到的 (可能帶空格)
        # <<< 新增：嘗試移除空格的版本 >>>
        artist_no_space = re.sub(r'\s+', '', detected_artist)
        if artist_no_space != detected_artist: # 只有不同時才添加
            artists_to_try.append(artist_no_space)
            log_message("DEBUG", f"添加無空格藝術家變體: '{artist_no_space}'")
        # <<< 結束新增 >>>
    if artist and artist not in artists_to_try: # 如果傳入了原始 artist 且不在列表中
         artists_to_try.append(artist)

    log_message("DEBUG", f"將用於搜索的標題: '{cleaned_title}', 嘗試的藝術家列表: {artists_to_try}")

    # --- 策略 1: 嘗試清理後的標題 + 藝術家列表中的每個名字 ---
    #    只要找到結果就停止嘗試
    if artists_to_try:
        for i, artist_try in enumerate(artists_to_try):
            query_parts = [f'recording:"{cleaned_title}"', f'artistname:"{artist_try}"']
            query = " AND ".join(query_parts)
            log_message("INFO", f"策略 1.{i+1}: 正在搜索 (清理標題+'{artist_try}'): {query}")
            try:
                time.sleep(API_DELAY)
                result = musicbrainzngs.search_recordings(query=query, limit=limit)
                recordings = result.get('recording-list', [])
                log_message("INFO", f"策略 1.{i+1} 返回 {len(recordings)} 個結果。")
                if recordings: # 只要找到結果就跳出藝術家嘗試循環
                    break
            except Exception as e:
                log_message("ERROR", f"策略 1.{i+1} 搜索出錯: {e}")
        # 循環結束後檢查 recordings 是否有值

    # --- 策略 2: 如果策略 1 所有嘗試都失敗，僅用清理後的標題 ---
    if not recordings:
        query = f'recording:"{cleaned_title}"'
        log_message("INFO", f"策略 2: 正在搜索 (僅清理標題): {query}")
        try:
            time.sleep(API_DELAY)
            result = musicbrainzngs.search_recordings(query=query, limit=limit)
            recordings = result.get('recording-list', [])
            log_message("INFO", f"策略 2 返回 {len(recordings)} 個結果。")
        except Exception as e: log_message("ERROR", f"策略 2 搜索出錯: {e}")

    # --- 策略 3: 如果還失敗，使用原始標題和藝術家列表 (備份) ---
    if not recordings and artists_to_try:
        for i, artist_try in enumerate(artists_to_try):
             query_parts = [f'recording:"{title}"', f'artistname:"{artist_try}"'] # 使用原始標題
             query = " AND ".join(query_parts)
             log_message("INFO", f"策略 3.{i+1}: 正在搜索 (原始標題+'{artist_try}'): {query}")
             try:
                 time.sleep(API_DELAY)
                 result = musicbrainzngs.search_recordings(query=query, limit=limit)
                 recordings = result.get('recording-list', [])
                 log_message("INFO", f"策略 3.{i+1} 返回 {len(recordings)} 個結果。")
                 if recordings: break # 找到即停止
             except Exception as e: log_message("ERROR", f"策略 3.{i+1} 搜索出錯: {e}")


    # --- 策略 4: 最後嘗試通用模糊搜索 (使用清理後的標題和檢測到的/傳入的藝術家) ---
    if not recordings:
        artist_for_generic = detected_artist if detected_artist else artist # 優先用檢測到的
        search_term = f"{cleaned_title} {artist_for_generic if artist_for_generic else ''}".strip()
        if search_term:
            log_message("INFO", f"策略 4: 正在進行通用模糊搜索: {search_term}")
            try:
                time.sleep(API_DELAY)
                result = musicbrainzngs.search_recordings(query=search_term, limit=limit)
                recordings = result.get('recording-list', [])
                log_message("INFO", f"策略 4 返回 {len(recordings)} 個結果。")
            except Exception as e: log_message("ERROR", f"策略 4 搜索出錯: {e}")
        else: log_message("WARN", "無法構造通用搜索詞")

    return recordings if recordings else []

# 在 enrich_metadata.py 中修改 calculate_match_score 函數
def calculate_match_score(recording, target_duration_sec, original_artist):
    """計算單個錄音的匹配得分（自訂邏輯）"""
    score = int(recording.get('ext:score', 0)) # MusicBrainz 基礎分
    recording_duration_ms = int(recording.get('length', 0)) if recording.get('length') else None

    # <<< 開始修正藝術家提取 >>>
    recording_artists = [] # 初始化為空列表
    artist_credit_list = recording.get('artist-credit', [])
    if isinstance(artist_credit_list, list): # 確保 artist-credit 是列表
        for credit in artist_credit_list:
            # 檢查 credit 是否為字典，並且包含 'artist' 鍵
            if isinstance(credit, dict) and 'artist' in credit:
                artist_info = credit['artist']
                # 檢查 artist_info 是否為字典，並且包含 'name' 鍵
                if isinstance(artist_info, dict) and 'name' in artist_info:
                    artist_name = artist_info.get('name', '')
                    if artist_name: # 確保名字不是空的
                        recording_artists.append(artist_name.lower())
                # 有時 credit 可能直接是藝術家名？(雖然不常見)
                # elif isinstance(artist_info, str):
                #     recording_artists.append(artist_info.lower())
            # 有時 credit 本身就是藝術家名字典？
            elif isinstance(credit, dict) and 'name' in credit:
                 artist_name = credit.get('name', '')
                 if artist_name: recording_artists.append(artist_name.lower())

    if not recording_artists: # 如果無法提取到任何藝術家名字
        log_message("DEBUG", "      未能從 MusicBrainz 結果中提取有效的藝術家名字。")
    # <<< 結束修正藝術家提取 >>>


    log_message("DEBUG", f"  - 計算得分: '{recording.get('title','')}' (MB Score: {score}, Artists: {recording_artists})") # 日誌中顯示提取到的藝術家

    # ... (後續的時長匹配和藝術家匹配邏輯保持不變) ...
    # ... (它們會使用修正後的 recording_artists 列表) ...
    if score < MIN_MB_SCORE: log_message("DEBUG", "      基礎分過低，得分設為 -1。"); return -1
    if target_duration_sec and recording_duration_ms:
        duration_diff_sec = abs(target_duration_sec - (recording_duration_ms / 1000.0))
        if duration_diff_sec > (DURATION_TOLERANCE_MS / 1000.0):
            penalty = int((duration_diff_sec - (DURATION_TOLERANCE_MS / 1000.0)) * 5)
            score -= penalty; log_message("DEBUG", f"      時長差異過大，減分 {penalty} -> 新得分: {score}")
        else:
            bonus = max(0, 5 - int(duration_diff_sec))
            score += bonus; log_message("DEBUG", f"      時長差異在容忍範圍內，加分 {bonus} -> 新得分: {score}")
    elif target_duration_sec and not recording_duration_ms:
        score -= 15; log_message("DEBUG", f"      MusicBrainz 條目缺少時長，減分 15 -> 新得分: {score}")
    if original_artist and recording_artists: # 使用修正後的 recording_artists
        original_artist_lower = original_artist.lower()
        if original_artist_lower in recording_artists: score += 15; log_message("DEBUG", f"      藝術家 '{original_artist}' 精確匹配，加分 15 -> 新得分: {score}")
    if original_artist and "various artists" in recording_artists: score -= 20; log_message("DEBUG", f"      匹配到 'Various Artists' 但提供了原始藝術家，減分 20 -> 新得分: {score}")
    score = max(0, score); log_message("DEBUG", f"      最終得分: {score}"); return score

# select_best_match 函數 (保持不變)
def select_best_match(recordings, target_duration_sec, original_artist):
    if not recordings: return None
    scored_matches = []
    for recording in recordings:
        score = calculate_match_score(recording, target_duration_sec, original_artist)
        if score >= 0: scored_matches.append({'score': score, 'recording': recording})
    if not scored_matches: log_message("WARN", "所有結果得分均過低或不符條件。"); return None
    scored_matches.sort(key=lambda x: x['score'], reverse=True)
    if VERBOSE: # ... (打印排序結果) ...
        log_message("DEBUG", "得分排序結果:")
        for match in scored_matches[:3]: rec = match['recording']; arts = " & ".join([c['artist'].get('name', '') for c in rec.get('artist-credit', [])]); log_message("DEBUG", f"  - 得分: {match['score']}, 標題: '{rec.get('title')}', 藝術家: {arts}, ID: {rec.get('id')}")
    best_match = scored_matches[0]['recording']
    log_message("INFO", f"選擇的最佳匹配: '{best_match['title']}' (得分: {scored_matches[0]['score']}, ID: {best_match['id']})")
    return best_match

# get_recording_details 函數 (保持不變)
def get_recording_details(recording_id):
    log_message("INFO", f"正在獲取 Recording ID 的詳細資訊: {recording_id}")
    try:
        time.sleep(API_DELAY)
        recording_info = musicbrainzngs.get_recording_by_id(recording_id, includes=['releases', 'artist-credits'])['recording']
        metadata = {'recording_id': recording_id}; metadata['title'] = recording_info.get('title')
        artist_credits = recording_info.get('artist-credit', [])
        if artist_credits: metadata['artist'] = " & ".join([ac.get('name', ac['artist'].get('name', '')) for ac in artist_credits]); metadata['albumartist'] = artist_credits[0]['artist'].get('name', '')
        releases = recording_info.get('release-list', [])
        first_release = None
        if releases:
            first_release = releases[0]; metadata['album'] = first_release.get('title'); release_date = first_release.get('date')
            if release_date: metadata['date'] = release_date; metadata['year'] = release_date.split('-')[0]
            metadata['release_id'] = first_release.get('id'); metadata['release_group_id'] = first_release.get('release-group', {}).get('id')
            try: # 獲取 Album Artist
                 time.sleep(API_DELAY); release_details_for_aa = musicbrainzngs.get_release_by_id(metadata['release_id'], includes=['artist-credits'])['release']
                 release_artist_credits = release_details_for_aa.get('artist-credit', []);
                 if release_artist_credits: metadata['albumartist'] = " & ".join([ac.get('name', ac['artist'].get('name', '')) for ac in release_artist_credits]); log_message("DEBUG", f"從 Release 獲取 Album Artist: {metadata['albumartist']}")
            except Exception as aa_exc: log_message("WARN", f"無法獲取 Release 的 Album Artist: {aa_exc}")
            track_num, total_tracks = get_track_number(metadata['release_id'], recording_id)
            if track_num: metadata['tracknumber'] = track_num
            if total_tracks: metadata['totaltracks'] = total_tracks
        else: metadata['album'] = None; metadata['date'] = None; metadata['year'] = None; metadata['release_id'] = None; metadata['release_group_id'] = None
        return metadata
    except musicbrainzngs.WebServiceError as exc: log_message("ERROR", f"獲取 Recording 詳細資訊時出錯: {exc}")
    except Exception as e: log_message("ERROR", f"解析 Recording 詳細資訊時發生未知錯誤: {e}")
    return None

# get_track_number 函數 (保持不變)
def get_track_number(release_id, recording_id):
     if not release_id or not recording_id: return None, None
     log_message("DEBUG", f"正在查詢 Release ID {release_id} 以獲取曲目號...")
     try:
         time.sleep(API_DELAY); release_details = musicbrainzngs.get_release_by_id(release_id, includes=['media', 'recordings'])['release']
         for medium in release_details.get('medium-list', []):
             track_count = medium.get('track-count', 0)
             for track in medium.get('track-list', []):
                 if track.get('recording', {}).get('id') == recording_id:
                     track_num = track.get('number'); log_message("DEBUG", f"找到曲目號: {track_num}, 總數: {track_count}"); return str(track_num) if track_num else None, str(track_count) if track_count else None
     except musicbrainzngs.WebServiceError as exc: log_message("WARN", f"查詢曲目號時出錯: {exc}")
     except Exception as e: log_message("WARN", f"解析曲目號時發生未知錯誤: {e}")
     return None, None

# get_cover_art 函數 (保持上次包含回退邏輯的版本)
def get_cover_art(release_id=None, release_group_id=None, youtube_cover_path=None):
    """從 Cover Art Archive 獲取封面，失敗則嘗試使用 YouTube 備份封面"""
    image_data = None
    mime_type = None

    # --- 優先嘗試 Cover Art Archive ---
    if release_id or release_group_id:
        target_id = release_group_id if release_group_id else release_id
        id_type = "release-group" if release_group_id else "release"
        cover_api_url = f"http://coverartarchive.org/{id_type}/{target_id}"
        log_message("INFO", f"正在從 Cover Art Archive 查詢封面: {cover_api_url}")
        try:
            time.sleep(API_DELAY)
            response = requests.get(cover_api_url, headers={'Accept': 'application/json'}, timeout=15)
            response.raise_for_status()

            json_data = response.json()
            images = json_data.get('images', [])
            front_image_url = None
            for img in images: # 找 Front
                if img.get('front', False) or ('Front' in img.get('types', [])):
                    front_image_url = img.get('image') # 直接獲取原始大圖 URL
                    if front_image_url: log_message("INFO", "找到 'Front' 封面 URL。"); break
            if not front_image_url and images: # 回退到第一張
                 log_message("WARN", "未找到 'Front' 封面，使用第一張圖片。"); front_image_url = images[0].get('image')

            if front_image_url:
                log_message("INFO", f"正在下載封面: {front_image_url}")
                time.sleep(API_DELAY)
                img_response = requests.get(front_image_url, stream=True, timeout=30)
                img_response.raise_for_status()
                image_data_candidate = img_response.content # 先存到臨時變數

                # <<< 開始修正：將圖片驗證放入獨立的 try...except 塊 >>>
                try:
                    log_message("DEBUG", "正在驗證下載的 Cover Art Archive 圖片...")
                    img = Image.open(io.BytesIO(image_data_candidate))
                    img.verify() # 驗證數據完整性
                    # 需要重新打開才能讀取格式信息
                    img = Image.open(io.BytesIO(image_data_candidate))
                    real_mime = Image.MIME.get(img.format)
                    if not real_mime:
                        # 如果 Pillow 無法識別，拋出錯誤以便被捕獲
                        raise ValueError(f"Pillow 無法識別圖片格式: {img.format}")

                    # 驗證成功，賦值給最終變數並返回
                    image_data = image_data_candidate
                    mime_type = real_mime
                    log_message("INFO", f"Cover Art Archive 封面下載並驗證成功 (類型: {mime_type})。")
                    return image_data, mime_type # <<< 驗證成功，直接返回 >>>

                except (UnidentifiedImageError, ValueError, Exception) as img_e:
                    # 圖片驗證或格式識別失敗
                    log_message("ERROR", f"下載的 Cover Art Archive 封面無效或處理失敗: {img_e}")
                    # 不返回，讓流程繼續嘗試 YouTube 封面
                    image_data = None # 確保 image_data 在此路徑下為 None
                    mime_type = None
                # <<< 結束修正：圖片驗證的 try...except 塊 >>>

            else: # if front_image_url:
                log_message("INFO", "在 Cover Art Archive 響應中未找到有效的圖片 URL。")

        # --- 處理 HTTP 或其他網路錯誤 ---
        except requests.exceptions.HTTPError as http_err:
            if http_err.response.status_code == 404:
                log_message("INFO", f"Cover Art Archive 未找到 ID: {target_id} 的封面。")
                # 遞歸嘗試 group_id (保持不變)
                if id_type == "release" and release_group_id:
                     log_message("INFO", "嘗試使用 Release Group ID 重新查詢封面...")
                     return get_cover_art(release_group_id=release_group_id, youtube_cover_path=youtube_cover_path)
            else:
                log_message("ERROR", f"訪問 Cover Art Archive API 時發生 HTTP 錯誤: {http_err}")
        except requests.exceptions.RequestException as req_err:
            log_message("ERROR", f"下載 Cover Art Archive 封面時發生網路錯誤: {req_err}")
        except Exception as e:
             log_message("ERROR", f"處理 Cover Art Archive 封面時發生未知錯誤: {e}")
        # <<< 如果 try 塊中途出錯，或者圖片驗證失敗，或者沒找到 URL，都會來到這裡 >>>

    # --- Cover Art Archive 失敗或未執行，嘗試使用 YouTube 備份封面 ---
    # (這部分邏輯保持不變)
    log_message("INFO", "未從 Cover Art Archive 獲取到有效封面或處理失敗。")
    if youtube_cover_path and os.path.exists(youtube_cover_path) and os.access(youtube_cover_path, os.R_OK):
        log_message("INFO", f"嘗試使用 YouTube 備份封面: {youtube_cover_path}")
        try:
            with open(youtube_cover_path, 'rb') as f: image_data_youtube = f.read()
            # 驗證 YouTube 封面
            img = Image.open(io.BytesIO(image_data_youtube)); img.verify()
            img = Image.open(io.BytesIO(image_data_youtube)); mime_type_youtube = Image.MIME.get(img.format)
            if not mime_type_youtube: raise ValueError("無法識別 YouTube 封面格式")
            log_message("INFO", f"成功加載 YouTube 備份封面 (類型: {mime_type_youtube})。")
            # 返回 YouTube 封面數據
            return image_data_youtube, mime_type_youtube
        except Exception as e:
            log_message("ERROR", f"讀取或驗證 YouTube 備份封面失敗: {e}")
            return None, None # 出錯則返回 None
    else:
        if youtube_cover_path and youtube_cover_path != "": log_message("WARN", f"提供的 YouTube 封面路徑無效或不可讀: '{youtube_cover_path}'")
        else: log_message("INFO", "未提供 YouTube 備份封面路徑。")
        return None, None # 無有效備份，返回 None

# write_metadata_to_file 函數 (使用上次包含詳細日誌的版本)
def write_metadata_to_file(file_path, metadata, image_data, mime_type, no_overwrite=False):
    """將元數據和封面寫入音頻檔案，修正 FLAC/OGG 封面尺寸獲取處的 try...except"""
    log_message("INFO", f"正在嘗試將元數據和封面寫入檔案: {file_path}")
    if image_data:
        log_message("INFO", f"準備嵌入封面數據 (類型: {mime_type}, 大小: {len(image_data)} 字節)")
    else:
        log_message("INFO", "沒有封面數據需要嵌入。")

    try:
        audio = mutagen.File(file_path, easy=False)
        if audio is None:
            log_message("ERROR", "無法加載音頻檔案以寫入標籤。")
            return False

        tag_updated = False

        # --- MP3 (ID3) ---
        if isinstance(audio, mutagen.id3.ID3FileType):
            # ... (ID3 處理邏輯保持不變) ...
             log_message("DEBUG", "處理 ID3 標籤 (MP3)。")
             if audio.tags is None: log_message("DEBUG", "無現有 ID3 標籤，添加新標籤。"); audio.add_tags()
             tags = audio.tags; id3_map = { TIT2: 'title', TPE1: 'artist', TALB: 'album', TPE2: 'albumartist', TRCK: 'tracknumber', TDRC: 'date', TYER: 'year', TCON: 'genre',}
             if not no_overwrite:
                  tags_changed_by_clear = False
                  for frame_class in id3_map.keys(): frame_id = frame_class.__name__;
                  if frame_id in tags: log_message("DEBUG", f"清除舊 ID3 標籤: {frame_id}"); del tags[frame_id]; tags_changed_by_clear = True
                  if 'APIC:' in tags: log_message("DEBUG", "清除舊 ID3 封面 (APIC)。"); del tags['APIC:']; tags_changed_by_clear = True
                  if tags_changed_by_clear: tag_updated = True
             for frame_class, meta_key in id3_map.items():
                  value = metadata.get(meta_key)
                  if value:
                       frame_id = frame_class.__name__; log_message("DEBUG", f"寫入 ID3 標籤: {frame_id} = {value}")
                       if frame_class == TRCK and metadata.get('totaltracks'): text = f"{value}/{metadata['totaltracks']}"; tags.add(frame_class(encoding=3, text=text))
                       elif frame_class == TDRC:
                            try: tags.add(frame_class(encoding=3, text=str(value)))
                            except:
                                 if metadata.get('year'): tags.add(TYER(encoding=3, text=metadata['year']))
                       elif frame_class != TYER: tags.add(frame_class(encoding=3, text=str(value)))
                       tag_updated = True
             if image_data and mime_type:
                  log_message("INFO", "正在嘗試添加 APIC 封面標籤...")
                  try: tags.add(APIC(encoding=3, mime=mime_type, type=3, desc='Cover', data=image_data)); log_message("INFO", "APIC 封面標籤添加成功 (待保存)。"); tag_updated = True
                  except Exception as apic_e: log_message("ERROR", f"添加 APIC 標籤時發生錯誤: {apic_e}")


        # --- M4A (MP4) ---
        elif isinstance(audio, MP4):
            # ... (M4A 處理邏輯保持不變) ...
             log_message("DEBUG", "處理 MP4 標籤 (M4A)。"); tags = audio.tags; mp4_map = {'\xa9nam': 'title','\xa9ART': 'artist','\xa9alb': 'album','aART': 'albumartist','\xa9day': 'date','trkn': 'tracknumber',}
             if not no_overwrite:
                 tags_changed_by_clear = False
                 for key in mp4_map.keys():
                      if key in tags: log_message("DEBUG", f"清除舊 MP4 標籤: {key}"); del tags[key]; tags_changed_by_clear = True
                 if 'covr' in tags: log_message("DEBUG", "清除舊 MP4 封面 (covr)。"); del tags['covr']; tags_changed_by_clear = True
                 if tags_changed_by_clear: tag_updated = True
             for key, meta_key in mp4_map.items():
                  value = metadata.get(meta_key)
                  if value:
                       log_message("DEBUG", f"寫入 MP4 標籤: {key} = {value}")
                       if key == 'trkn': track_num = int(value) if value else 0; total_num = int(metadata.get('totaltracks', 0)) if metadata.get('totaltracks') else 0; tags[key] = [(track_num, total_num)]
                       else: tags[key] = [str(value)];
                       tag_updated = True
             if image_data and mime_type:
                 try: fmt = MP4Cover.FORMAT_JPEG if 'jpeg' in mime_type else MP4Cover.FORMAT_PNG; log_message("INFO", f"正在嘗試添加 covr 封面標籤 (格式: {fmt})..."); tags['covr'] = [MP4Cover(image_data, imageformat=fmt)]; log_message("INFO", "covr 封面標籤添加成功 (待保存)。"); tag_updated = True
                 except Exception as covr_e: log_message("ERROR", f"添加 covr 標籤時發生錯誤: {covr_e}")


        # --- FLAC ---
        elif isinstance(audio, FLAC):
             log_message("DEBUG", "處理 FLAC 標籤 (Vorbis Comment)。")
             tags = audio.tags
             vc_map = {'TITLE': 'title', 'ARTIST': 'artist', 'ALBUM': 'album', 'ALBUMARTIST': 'albumartist', 'DATE': 'date', 'TRACKNUMBER': 'tracknumber', 'TRACKTOTAL': 'totaltracks',}
             if not no_overwrite: # 清除舊標籤
                 tags_changed_by_clear = False; keys_to_remove = list(vc_map.keys()) + ['METADATA_BLOCK_PICTURE']; new_tags = [];
                 for key, value in tags:
                     if key.upper() not in keys_to_remove: new_tags.append((key, value))
                     else: log_message("DEBUG", f"清除舊 FLAC 標籤: {key.upper()}"); tags_changed_by_clear = True
                 audio.tags = new_tags; tags = audio.tags;
                 if tags_changed_by_clear: tag_updated = True
             for key, meta_key in vc_map.items(): # 寫入新標籤
                  value = metadata.get(meta_key);
                  if value: log_message("DEBUG", f"寫入 FLAC 標籤: {key} = {value}"); audio[key] = str(value); tag_updated = True
             # 寫入封面
             if image_data and mime_type:
                 log_message("INFO", "正在嘗試添加 FLAC 封面圖片...")
                 try:
                     pic = Picture(); pic.data = image_data; pic.mime = mime_type; pic.type = 3; pic.desc = 'Cover'
                     # <<< 開始修正：為獲取尺寸添加 try...except >>>
                     try:
                         img = Image.open(io.BytesIO(image_data))
                         pic.width, pic.height = img.size
                     except Exception as img_e:
                         log_message("WARN", f"無法獲取 FLAC 封面圖片尺寸: {img_e}")
                     # <<< 結束修正 >>>
                     if not no_overwrite: audio.clear_pictures()
                     audio.add_picture(pic)
                     log_message("INFO", "FLAC 封面圖片添加成功 (待保存)。")
                     tag_updated = True
                 except Exception as flac_pic_e:
                     log_message("ERROR", f"添加 FLAC 封面時出錯: {flac_pic_e}")
             elif not no_overwrite and audio.pictures: # 清除舊封面
                 log_message("DEBUG", "無新封面，清除舊 FLAC 封面。"); audio.clear_pictures(); tag_updated = True


        # --- OGG Vorbis ---
        elif isinstance(audio, OggVorbis):
             log_message("DEBUG", "處理 OGG Vorbis 標籤。")
             tags = audio.tags
             vc_map_ogg = {'TITLE': 'title', 'ARTIST': 'artist', 'ALBUM': 'album', 'ALBUMARTIST': 'albumartist', 'DATE': 'date', 'TRACKNUMBER': 'tracknumber',}
             if not no_overwrite: # 清除舊標籤
                 tags_changed_by_clear = False; keys_to_remove = list(vc_map_ogg.keys()) + ['METADATA_BLOCK_PICTURE']; new_tags = [];
                 for key, value in tags:
                     if key.upper() not in keys_to_remove: new_tags.append((key, value))
                     else: log_message("DEBUG", f"清除舊 OGG 標籤: {key.upper()}"); tags_changed_by_clear = True
                 audio.tags = new_tags; tags = audio.tags;
                 if tags_changed_by_clear: tag_updated = True
             for key, meta_key in vc_map_ogg.items(): # 寫入新標籤
                  value = metadata.get(meta_key);
                  if value: log_message("DEBUG", f"寫入 OGG 標籤: {key} = {value}"); audio[key] = str(value); tag_updated = True
             # 寫入封面
             if image_data and mime_type:
                 import base64; log_message("INFO", "正在嘗試添加 OGG 封面圖片...")
                 try:
                     pic = Picture(); pic.data = image_data; pic.mime = mime_type; pic.type = 3; pic.desc = 'Cover'
                     # <<< 開始修正：為獲取尺寸添加 try...except >>>
                     try:
                         img = Image.open(io.BytesIO(image_data))
                         pic.width, pic.height = img.size
                     except Exception as img_e:
                          log_message("WARN", f"無法獲取 OGG 封面圖片尺寸: {img_e}")
                     # <<< 結束修正 >>>
                     if not no_overwrite and 'metadata_block_picture' in audio.tags: log_message("DEBUG", "清除舊 OGG 封面。"); del audio.tags['metadata_block_picture']
                     audio['metadata_block_picture'] = [base64.b64encode(pic.write()).decode('ascii')]
                     log_message("INFO", "OGG 封面圖片添加成功 (待保存)。")
                     tag_updated = True
                 except Exception as ogg_pic_e:
                      log_message("ERROR", f"添加 OGG 封面時出錯: {ogg_pic_e}")
             elif not no_overwrite and 'metadata_block_picture' in audio.tags: # 清除舊封面
                  log_message("DEBUG", "無新封面，清除舊 OGG 封面。"); del audio.tags['metadata_block_picture']; tag_updated = True

        else:
            log_message("WARN", f"不支持的檔案格式或標籤類型: {type(audio)}")

        # --- 保存 ---
        if tag_updated:
            log_message("INFO", "檢測到標籤已更新，正在嘗試保存檔案...")
            try:
                audio.save()
                log_message("SUCCESS", "元數據成功寫入並保存檔案！")
            except Exception as save_e:
                 log_message("ERROR", f"保存檔案時發生錯誤: {save_e}")
                 return False # 保存失敗是嚴重錯誤
        else:
            log_message("INFO", "沒有元數據或封面需要更新或保存。")

        return True # 只要沒在保存時出錯就認為成功

    except mutagen.MutagenError as e:
        log_message("ERROR", f"處理音頻檔案標籤時發生 Mutagen 錯誤: {e}")
    except Exception as e:
        log_message("ERROR", f"寫入元數據過程中發生未知錯誤: {e}")

    return False # 發生錯誤，返回 False

# 在 enrich_metadata.py 中替換舊的 main 函數
def main():
    global VERBOSE
    # <<< 【修正關鍵】確保 parser 的定義和參數添加在這裡 >>>
    parser = argparse.ArgumentParser(description="從 MusicBrainz 和 Cover Art Archive 獲取元數據並嵌入音頻檔案。")
    parser.add_argument("file_path", help="需要處理的音頻檔案路徑")
    parser.add_argument("title", help="從 yt-dlp 獲取的基礎標題")
    parser.add_argument("artist", nargs='?', default=None, help="(可選) 從 yt-dlp 獲取的藝術家/上傳者名稱")
    parser.add_argument("--youtube-cover", default=None, help="(可選) 從 YouTube 下載的備份封面圖片路徑")
    parser.add_argument("-v", "--verbose", action="store_true", help="啟用詳細日誌輸出")
    parser.add_argument("--no-overwrite", action="store_true", help="不覆蓋音頻檔案中已存在的標籤 (封面仍會嘗試更新)")
    # <<< 結束 parser 定義 >>>

    MIN_ACCEPTABLE_SCORE = 75 # 最低分數閾值

    args = None # 初始化 args
    try:
        log_message("DEBUG", "--- Before parsing arguments ---")
        args = parser.parse_args() # <<< 現在 parser 應該已定義 >>>
        log_message("DEBUG", "--- After parsing arguments ---")
    except SystemExit as e:
        log_message("ERROR", f"--- Argparse exited with code: {e.code} ---")
        sys.exit(e.code) # 保持退出碼
    except Exception as e:
        # 將錯誤訊息打印到 stderr，更容易被看到
        print(f"[CRITICAL] --- Error during argument parsing: {e} ---", file=sys.stderr)
        import traceback
        traceback.print_exc(file=sys.stderr) # 打印詳細錯誤堆棧
        sys.exit(1) # 以錯誤碼 1 退出

    if args is None: # 再次檢查，雖然理論上不會到這裡
        log_message("CRITICAL", "--- Argument parsing failed silently? Exiting. ---")
        sys.exit(1)

    if args.verbose: VERBOSE = True; log_message("DEBUG", "啟用詳細日誌模式。")

    # --- 檔案檢查 ---
    log_message("DEBUG", f"--- Checking file path: {args.file_path} ---")
    if not os.path.exists(args.file_path): log_message("ERROR", f"輸入的音頻檔案不存在: {args.file_path}"); sys.exit(1)
    if not os.access(args.file_path, os.R_OK | os.W_OK): log_message("ERROR", f"檔案權限不足: {args.file_path}"); sys.exit(1)
    log_message("DEBUG", "--- File check passed ---")

    # --- 後續主邏輯 (保持不變) ---
    log_message("INFO", f"開始處理檔案: {args.file_path}")
    log_message("INFO", f"基礎標題: {args.title}")
    if args.artist: log_message("INFO", f"基礎藝術家: {args.artist}")

    target_duration = get_audio_duration(args.file_path)
    if target_duration: log_message("INFO", f"本地檔案時長: {target_duration:.2f} 秒")

    recordings = search_musicbrainz(args.title, args.artist)
    best_match = None; highest_score_found = -1
    if recordings:
        log_message("DEBUG", "評估搜索結果分數...")
        scored_matches = []
        for recording in recordings:
            score = calculate_match_score(recording, target_duration, args.artist)
            if score >= 0: scored_matches.append({'score': score, 'recording': recording});
            if score > highest_score_found: highest_score_found = score
        if scored_matches:
            scored_matches.sort(key=lambda x: x['score'], reverse=True);
            log_message("DEBUG", f"找到的最高分數: {highest_score_found}")
            if highest_score_found >= MIN_ACCEPTABLE_SCORE:
                log_message("INFO", f"最高分 {highest_score_found} >= 閾值 {MIN_ACCEPTABLE_SCORE}，接受匹配。")
                best_match = scored_matches[0]['recording']
                log_message("INFO", f"選擇的最佳匹配: '{best_match['title']}' (得分: {highest_score_found}, ID: {best_match['id']})")
            else: log_message("WARN", f"找到匹配項，但最高分 {highest_score_found} < 閾值 {MIN_ACCEPTABLE_SCORE}，拒絕匹配。")
        else: log_message("WARN", "所有搜索結果計算得分後均無效。")
    else: log_message("WARN", "所有搜索策略均未找到任何結果。")

    if not best_match:
        log_message("WARN", "未能找到或選擇可接受的匹配項，元數據豐富化終止。")
        sys.exit(2) # <<< 返回 2 表示未匹配

    metadata = get_recording_details(best_match['id'])
    if not metadata: log_message("ERROR", "無法獲取詳細元數據，處理終止。"); sys.exit(1)

    log_message("INFO", "獲取的初步元數據:")
    for key, value in metadata.items(): log_message("INFO", f"  - {key}: {value}")

    image_data, mime_type = get_cover_art(
        release_id=metadata.get('release_id'),
        release_group_id=metadata.get('release_group_id'),
        youtube_cover_path=args.youtube_cover
    )
    if image_data: log_message("INFO", f"最終確定使用的封面類型: {mime_type}")
    else: log_message("INFO", "最終未能獲取到任何封面。")

    success = write_metadata_to_file(args.file_path, metadata, image_data, mime_type, args.no_overwrite)

    if success: log_message("SUCCESS", "元數據處理完成！"); sys.exit(0) # <<< 返回 0 表示成功
    else: log_message("ERROR", "元數據處理失敗。"); sys.exit(1) # <<< 返回 1 表示處理中錯誤

# <<< if __name__ == "__main__": 部分保持不變 >>>

if __name__ == "__main__":
    # <<< 添加一個頂層的 try...except 來捕獲 main 函數中未被捕獲的異常 >>>
    try:
        main()
    except Exception as main_e:
         # 使用 print 直接輸出到 stderr，避免 log_message 本身出問題
         print(f"[CRITICAL] Unhandled exception in main: {main_e}", file=sys.stderr)
         import traceback
         traceback.print_exc(file=sys.stderr) # 打印完整的 Traceback
         sys.exit(1) # 以錯誤碼退出
