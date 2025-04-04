#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os
from datetime import timedelta
import webvtt # 需要 pip install webvtt-py

# --- Script Configuration ---
__version__ = "1.1.0(Experimental)" # 版本號更新，加入了基礎位置處理

# --- Helper Functions ---

def parse_vtt_time(time_str):
    """將 VTT 時間字符串 (HH:MM:SS.ms) 解析為 timedelta 對象"""
    try:
        parts = time_str.split('.')
        hms = parts[0]
        ms = parts[1] if len(parts) > 1 else "0"
        h, m, s = map(int, hms.split(':'))
        milliseconds = int(ms.ljust(3, '0'))
        return timedelta(hours=h, minutes=m, seconds=s, milliseconds=milliseconds)
    except ValueError:
         # 添加錯誤處理，如果時間格式不對，返回 None
         print(f"Warning: Could not parse VTT time '{time_str}'", file=sys.stderr)
         return None


def format_ass_time(td):
    """將 timedelta 對象格式化為 ASS 時間字符串 (H:MM:SS.cs)"""
    if td is None: return "0:00:00.00" # 處理無效時間
    total_seconds = td.total_seconds()
    # 確保秒數不為負
    if total_seconds < 0: total_seconds = 0 
    hours = int(total_seconds // 3600)
    minutes = int((total_seconds % 3600) // 60)
    seconds = int(total_seconds % 60)
    centiseconds = int((total_seconds * 100) % 100)
    return f"{hours}:{minutes:02}:{seconds:02}.{centiseconds:02}"

def vtt_color_to_ass(vtt_color_tag):
    """將非標準 VTT 顏色標籤 <c.colorHEX> 轉換為 ASS 顏色標籤 {\c&HBBGGRR&}"""
    match = re.match(r'<c\.color([0-9A-Fa-f]{6})>', vtt_color_tag, re.IGNORECASE)
    if match:
        hex_color = match.group(1).upper()
        # VTT/HTML 的 HEX 通常是 RRGGBB
        r = hex_color[0:2]
        g = hex_color[2:4]
        b = hex_color[4:6]
        # ASS 的顏色是 &HBBGGRR&
        return f"{{\\c&H{b}{g}{r}&}}"
    return None # 無法識別的標籤

def guess_ass_alignment(vtt_cue):
    """根據 VTT cue 的 line 和 align 屬性猜測 ASS 的 {\anX} 對齊標籤"""
    alignment = 2 # 默認底部居中 (\an2)
    
    # 嘗試從 webvtt-py 解析出的 cue 對象獲取屬性
    # 注意：webvtt-py 對位置屬性的解析可能不完整或與預期不同
    line_pos = 50 # 假設默認中間行 (百分比)
    align_mode = 'middle' # 假設默認居中對齊

    # 檢查並獲取 line 屬性 (通常是行號或百分比)
    if hasattr(vtt_cue, 'line'):
        try:
            # 嘗試將 line 解析為數字 (去掉可能的 '%')
            line_val_str = str(vtt_cue.line).replace('%', '')
            line_pos = float(line_val_str)
        except (ValueError, TypeError):
            # 如果解析失敗，保持默認值
             pass 
             # print(f"Warning: Could not parse line attribute: {vtt_cue.line}", file=sys.stderr)


    # 檢查並獲取 align 屬性
    if hasattr(vtt_cue, 'align') and isinstance(vtt_cue.align, str):
        align_mode = vtt_cue.align.lower()

    # --- 根據 line 和 align 映射到 ASS 的 \an 值 ---
    # 頂部 (line < 30%)
    if line_pos < 30: 
        if 'start' in align_mode: alignment = 7 # 左上
        elif 'end' in align_mode: alignment = 9 # 右上
        else: alignment = 8                 # 中上
    # 底部 (line > 70%)
    elif line_pos > 70: 
        if 'start' in align_mode: alignment = 1 # 左下
        elif 'end' in align_mode: alignment = 3 # 右下
        else: alignment = 2                 # 中下 (默認)
    # 中間 (30% <= line <= 70%)
    else: 
        if 'start' in align_mode: alignment = 4 # 左中
        elif 'end' in align_mode: alignment = 6 # 右中
        else: alignment = 5                 # 中中

    return f"{{\\an{alignment}}}"

def process_vtt_line_text(line):
    """處理單行 VTT 文本，轉換 *文本內* 的標籤為 ASS 格式 (顏色, 粗體等)"""
    processed_line = ""
    parts = re.split(r'(<c\.color[0-9A-Fa-f]{6}>|</c>|<b>|</b>)', line, flags=re.IGNORECASE)
    
    for part in filter(None, parts): 
        color_tag = vtt_color_to_ass(part)
        
        if color_tag:
            processed_line += color_tag
        elif part.lower() == '</c>':
             # ASS 顏色會持續到下一個顏色標籤或行尾，一般無需顯式關閉
             # 可選: 在這裡加 {\c&HFFFFFF&} 重置為默認樣式顏色
             pass
        elif part.lower() == '<b>':
            processed_line += '{\\b1}'
        elif part.lower() == '</b>':
            processed_line += '{\\b0}'
        else: # 普通文本內容
            processed_part = part.replace('\n', '\\N') # 替換換行符
            processed_line += processed_part
            
    return processed_line.strip()


# --- Main Conversion Logic ---

def convert_vtt_to_ass(input_vtt_path, output_ass_path):
    """讀取 VTT 文件，轉換為 ASS 文件 (包含基礎顏色、粗體和近似位置)"""
    try:
        # 使用 webvtt-py 讀取和解析 VTT 文件
        try:
            vtt = webvtt.read(input_vtt_path)
        except Exception as parse_error:
            print(f"Error parsing VTT file with webvtt-py: {parse_error}", file=sys.stderr)
            # 嘗試用簡單模式讀取，僅獲取時間和文本
            print("Attempting simple text extraction...", file=sys.stderr)
            vtt = []
            with open(input_vtt_path, 'r', encoding='utf-8') as f_vtt:
                 lines = f_vtt.readlines()
            current_caption_simple = None
            text_buffer_simple = []
            for line in lines:
                 line = line.strip()
                 if '-->' in line:
                     if current_caption_simple and text_buffer_simple:
                         current_caption_simple.text = '\n'.join(text_buffer_simple)
                         vtt.append(current_caption_simple)
                     try:
                         start_str, end_str = line.split(' --> ')
                         end_str = end_str.split(' ')[0]
                         start_td = parse_vtt_time(start_str)
                         end_td = parse_vtt_time(end_str)
                         if start_td is None or end_td is None or end_td <= start_td:
                             current_caption_simple = None; continue
                         # 創建一個簡單的模擬 Caption 對象
                         current_caption_simple = type('obj', (object,), {
                             'start': start_str, 
                             'end': end_str, 
                             'text': '', 
                             'line': 50, # 賦予默認值
                             'align': 'middle' # 賦予默認值
                         })() 
                         text_buffer_simple = []
                     except:
                         current_caption_simple = None; text_buffer_simple = []
                 elif line and current_caption_simple:
                     text_buffer_simple.append(line)
                 elif not line and current_caption_simple and text_buffer_simple:
                     current_caption_simple.text = '\n'.join(text_buffer_simple)
                     vtt.append(current_caption_simple)
                     current_caption_simple = None; text_buffer_simple = []
            if current_caption_simple and text_buffer_simple: # 文件末尾
                 current_caption_simple.text = '\n'.join(text_buffer_simple)
                 vtt.append(current_caption_simple)
            if not vtt: # 如果簡單模式也失敗
                 raise parse_error # 重新拋出原始錯誤


        ass_content = [
            "[Script Info]",
            f"; Script generated by vtt_to_ass_converter.py v{__version__}",
            f"; Input VTT: {os.path.basename(input_vtt_path)}",
            "Title: Converted Subtitles",
            "ScriptType: v4.00+",
            "WrapStyle: 0", 
            "ScaledBorderAndShadow: yes",
            "YCbCr Matrix: None", 
            "",
            "[V4+ Styles]",
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
            # 增加了邊框和陰影以提高可讀性
            "Style: Default,Arial,24,&H00FFFFFF,&H0000FFFF,&H00000000,&H60000000,0,0,0,0,100,100,0,0,1,1.5,0.5,2,10,10,15,1", # MarginV 設為 15
            "",
            "[Events]",
            "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
        ]
                
        for caption in vtt:
            # 解析時間戳
            start_td = parse_vtt_time(caption.start)
            end_td = parse_vtt_time(caption.end)
            
            # 跳過無效時間戳的條目
            if start_td is None or end_td is None or end_td <= start_td:
                 print(f"Warning: Skipping invalid caption entry with time {caption.start} --> {caption.end}", file=sys.stderr)
                 continue

            start_time = format_ass_time(start_td)
            end_time = format_ass_time(end_td)
            
            # --- 核心轉換邏輯 ---
            # 1. 猜測位置標籤 {\anX}
            alignment_tag = guess_ass_alignment(caption) 
            
            # 2. 處理文本內的樣式標籤 (顏色, 粗體)
            style_processed_text = process_vtt_line_text(caption.text) 
            
            # 組合最終文本，將位置標籤放在最前面
            final_text = alignment_tag + style_processed_text
            
            # 添加到 ASS 事件列表
            if final_text.strip(): # 確保處理後還有內容
                ass_content.append(f"Dialogue: 0,{start_time},{end_time},Default,,0,0,0,,{final_text}")

        # 寫入 ASS 文件
        with open(output_ass_path, 'w', encoding='utf-8') as f_ass:
            f_ass.write('\n'.join(ass_content))
            f_ass.write('\n') 

        return 0 # 成功

    except FileNotFoundError:
        print(f"Error: Input VTT file not found: {input_vtt_path}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"An unexpected error occurred during conversion: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc() # 打印詳細錯誤追溯
        return 1

# --- Main Execution ---

if __name__ == "__main__":
    # print(f"vtt_to_ass_converter.py version {__version__}") # 可以在調試時取消註解

    if len(sys.argv) != 3:
        print("Usage: python vtt_to_ass_converter.py <input_vtt_file> <output_ass_file>", file=sys.stderr)
        # 修改退出碼，避免與文件未找到或轉換錯誤衝突
        sys.exit(2) 

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    exit_code = convert_vtt_to_ass(input_file, output_file)
    sys.exit(exit_code)
