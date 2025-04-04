#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os
from datetime import timedelta

# --- Script Configuration ---
# <<< 新增：Python 腳本自身的版本號 >>>
__version__ = "1.0.0" 

# --- Helper Functions ---

def parse_vtt_time(time_str):
    """將 VTT 時間字符串 (HH:MM:SS.ms) 解析為 timedelta 對象"""
    parts = time_str.split('.')
    hms = parts[0]
    ms = parts[1] if len(parts) > 1 else "0"
    h, m, s = map(int, hms.split(':'))
    milliseconds = int(ms.ljust(3, '0'))
    return timedelta(hours=h, minutes=m, seconds=s, milliseconds=milliseconds)

def format_ass_time(td):
    """將 timedelta 對象格式化為 ASS 時間字符串 (H:MM:SS.cs)"""
    total_seconds = td.total_seconds()
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
    # 可以添加對標準 VTT 顏色 <c.red> 等的轉換 (可選)
    # elif vtt_color_tag.lower() == '<c.red>': return '{\\c&H0000FF&}' 
    return None # 無法識別的標籤

def process_vtt_line(line):
    """處理單行 VTT 文本，轉換標籤為 ASS 格式"""
    # 1. 處理顏色標籤
    processed_line = ""
    # 使用正則表達式分割文本和標籤
    # Pattern breakdown:
    # (<c\.color[0-9A-Fa-f]{6}>) : Capture group 1: Opening color tag
    # |                            : OR
    # (</c>)                       : Capture group 2: Closing color tag
    # |                            : OR
    # (<b>)                        : Capture group 3: Opening bold tag
    # |                            : OR
    # (</b>)                       : Capture group 4: Closing bold tag
    # (?:...) means non-capturing group, so the whole tag is matched but not captured separately
    # We capture the content *between* tags implicitly by splitting
    
    parts = re.split(r'(<c\.color[0-9A-Fa-f]{6}>|</c>|<b>|</b>)', line, flags=re.IGNORECASE)
    
    in_color = False
    in_bold = False

    for part in filter(None, parts): # filter(None,...) removes empty strings from split
        color_tag = vtt_color_to_ass(part)
        
        if color_tag: # 如果是顏色開始標籤
            processed_line += color_tag
            in_color = True
        elif part.lower() == '</c>': # 如果是顏色結束標籤
            # ASS 顏色標籤通常不需要顯式關閉，下一個顏色標籤會覆蓋
            # 或者可以在下一個非標籤部分之前添加 {\c&HFFFFFF&} (默認白色)
            # 為了簡單起見，暫時不加顯式關閉
             in_color = False
        elif part.lower() == '<b>': # 如果是粗體開始標籤
            processed_line += '{\\b1}'
            in_bold = True
        elif part.lower() == '</b>': # 如果是粗體結束標籤
            processed_line += '{\\b0}'
            in_bold = False
        else: # 普通文本內容
            # 將 VTT 換行符 (\n) 替換為 ASS 換行符 (\N)
            processed_part = part.replace('\n', '\\N')
            processed_line += processed_part
            
    # 清理可能殘留的原始 VTT 標籤 (以防萬一正則沒匹配到) - 可選強化
     processed_line = re.sub(r'<[^>]+>', '', processed_line) 

    return processed_line.strip()


# --- Main Conversion Logic ---

def convert_vtt_to_ass(input_vtt_path, output_ass_path):
    """讀取 VTT 文件，轉換為 ASS 文件"""
    try:
        with open(input_vtt_path, 'r', encoding='utf-8') as f_vtt:
            lines = f_vtt.readlines()

        ass_content = [
            "[Script Info]",
            f"; Script generated by vtt_to_ass_converter.py v{__version__}",
            f"; Input VTT: {os.path.basename(input_vtt_path)}",
            "Title: Converted Subtitles",
            "ScriptType: v4.00+",
            "WrapStyle: 0", # 智能換行，保持原樣
            "ScaledBorderAndShadow: yes",
            "YCbCr Matrix: None", # 通常不需要
            "",
            "[V4+ Styles]",
            # Format 行定義了樣式字段
            "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding",
            # 定義一個基礎的 Default 樣式。ASS 播放器會使用這個，除非被行內樣式覆蓋。
            # &H<alpha><blue><green><red> - AABBGGRR
            # Primary: White (&H00FFFFFF), Secondary: Yellow (&H0000FFFF), Outline: Black (&H00000000), Shadow: Black (&H00000000)
            # Alignment: 2 (底部居中)
            "Style: Default,Arial,24,&H00FFFFFF,&H0000FFFF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,1.5,0.5,2,10,10,10,1",
            "",
            "[Events]",
            # Format 行定義了事件字段
            "Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text"
        ]

        current_caption = None
        text_buffer = []

        for line in lines:
            line = line.strip()
            if '-->' in line: # 時間碼行
                # 如果 buffer 中有上一條字幕的文本，先處理
                if current_caption and text_buffer:
                   processed_text = process_vtt_line('\n'.join(text_buffer))
                   if processed_text: # 只有在處理後還有文本才加入
                       ass_content.append(f"Dialogue: 0,{current_caption['start']},{current_caption['end']},Default,,0,0,0,,{processed_text}")
                   text_buffer = [] # 清空 buffer

                # 解析新的時間碼
                try:
                    start_str, end_str = line.split(' --> ')
                    # 忽略時間碼後面的額外參數 (如 position, line)
                    end_str = end_str.split(' ')[0] 
                    
                    start_td = parse_vtt_time(start_str)
                    end_td = parse_vtt_time(end_str)
                    
                    # 基本的時間碼有效性檢查 (可選)
                    if end_td <= start_td:
                       print(f"Warning: Invalid timestamp order in line: {line}", file=sys.stderr)
                       current_caption = None # 忽略此條目
                       continue

                    current_caption = {
                        "start": format_ass_time(start_td),
                        "end": format_ass_time(end_td)
                    }
                except ValueError as e:
                    print(f"Error parsing timestamp line: {line} - {e}", file=sys.stderr)
                    current_caption = None # 解析失敗，跳過此條目
                    text_buffer = []
                    
            elif line and current_caption: # 如果是文本行且時間碼有效
                text_buffer.append(line)
            elif not line and current_caption and text_buffer: # 空行表示一個 caption 結束
                processed_text = process_vtt_line('\n'.join(text_buffer))
                if processed_text:
                    ass_content.append(f"Dialogue: 0,{current_caption['start']},{current_caption['end']},Default,,0,0,0,,{processed_text}")
                text_buffer = []
                current_caption = None # 重置

        # 處理文件末尾可能剩餘的最後一條字幕
        if current_caption and text_buffer:
            processed_text = process_vtt_line('\n'.join(text_buffer))
            if processed_text:
                 ass_content.append(f"Dialogue: 0,{current_caption['start']},{current_caption['end']},Default,,0,0,0,,{processed_text}")

        # 寫入 ASS 文件
        with open(output_ass_path, 'w', encoding='utf-8') as f_ass:
            f_ass.write('\n'.join(ass_content))
            f_ass.write('\n') # 確保文件末尾有換行符

        return 0 # 成功

    except FileNotFoundError:
        print(f"Error: Input VTT file not found: {input_vtt_path}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"An unexpected error occurred: {e}", file=sys.stderr)
        # 可以在這裡加入更詳細的錯誤追溯 (import traceback; traceback.print_exc())
        return 1

# --- Main Execution ---

if __name__ == "__main__":
    # --- <<< 新增：簡單的更新檢查 placeholder >>> ---
    # 這個檢查非常基礎，只是示意。實際的檢查和下載應該由 Bash 腳本處理。
    # print(f"vtt_to_ass_converter.py version {__version__}") 
    # --- 結束更新檢查 placeholder ---

    if len(sys.argv) != 3:
        print("Usage: python vtt_to_ass_converter.py <input_vtt_file> <output_ass_file>", file=sys.stderr)
        sys.exit(2) # 使用不同的退出碼

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    exit_code = convert_vtt_to_ass(input_file, output_file)
    sys.exit(exit_code)
