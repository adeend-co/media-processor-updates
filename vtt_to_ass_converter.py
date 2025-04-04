#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os

# --- Script Configuration ---
__version__ = "1.1.7(Final - Remove Old Style, Gen New, Convert Color)"

# --- VTT Enhancement Logic ---

def enhance_vtt(input_vtt_path, output_vtt_path):
    """讀取 VTT，移除舊 Header/Style，生成新 Style，替換 Cue 顏色"""
    try:
        with open(input_vtt_path, 'r', encoding='utf-8') as f_in:
            lines = f_in.readlines()

        output_lines = []
        color_map = {}
        css_class_counter = 0
        style_block_needed = False # 是否需要生成新的 STYLE 塊

        # --- 第一遍：掃描顏色，建立映射 ---
        temp_in_cue_section = False # 臨時標誌，只在 Cue 部分掃描
        for line in lines:
            # --- 僅在 Cue 文本行中掃描顏色 ---
            if '-->' in line:
                 temp_in_cue_section = True
                 continue # 跳過時間碼行
            elif not temp_in_cue_section:
                 continue # 跳過 Header/Style/## 等

            # 進入 Cue 區段後處理文本行或空行
            line_strip = line.strip()
            if line_strip and not '-->' in line_strip: # 是 Cue 文本行
                 matches = re.findall(r'<c\.color([0-9A-Fa-f]{6})>', line, re.IGNORECASE)
                 for hex_color in matches:
                     hex_color = hex_color.upper()
                     if hex_color not in color_map:
                         css_class_name = f"c{css_class_counter}"
                         color_map[hex_color] = css_class_name
                         css_class_counter += 1
                         style_block_needed = True # 標記需要生成

        # --- 開始構建輸出 ---
        output_lines.append("WEBVTT\n")
        output_lines.append("\n")

        # --- 生成新的 STYLE 塊 (如果掃描到顏色) ---
        if style_block_needed:
            output_lines.append("STYLE\n")
            for hex_color, class_name in color_map.items():
                css_color = f"#{hex_color}"
                output_lines.append(f"::cue(.{class_name}) {{ color: {css_color}; }}\n")
            output_lines.append("\n") # STYLE 塊後必須有空行

        # --- 第二遍：跳過舊 Header/Style，處理並輸出 Cues ---
        in_cue_section = False

        for line in lines:
            # --- 處理 BOM 和換行符 ---
            if output_lines[0] == "WEBVTT\n" and line.startswith('\ufeff'):
                 line = line[1:]
            original_line_content = line.rstrip()
            line_with_lf = original_line_content + "\n"

            # --- 狀態機：尋找第一個時間碼行 ---
            if not in_cue_section:
                if '-->' in original_line_content:
                    in_cue_section = True
                    # 輸出第一個時間碼行
                    output_lines.append(line_with_lf)
                else:
                    # 忽略所有 Header/Style/## 等內容
                    continue
            else:
                # --- 處理 Cue 區段 ---
                is_timestamp_line = '-->' in original_line_content
                is_text_line = bool(original_line_content) and not is_timestamp_line
                is_empty_line = not original_line_content

                if is_timestamp_line:
                    output_lines.append(line_with_lf) # 原樣輸出時間碼行
                elif is_text_line:
                    # <<< 啟用顏色替換 >>>
                    processed_line = original_line_content
                    for hex_color, class_name in color_map.items():
                        pattern = re.compile(f'<c\\.color{hex_color}>', re.IGNORECASE)
                        processed_line = pattern.sub(f'<c.{class_name}>', processed_line)
                    processed_line = processed_line.replace('</c>', '')
                    output_lines.append(processed_line + "\n") # 輸出處理後的文本行
                elif is_empty_line:
                    output_lines.append("\n") # 原樣輸出空行

        # --- 確保文件末尾是空行 ---
        while len(output_lines) > 2 and output_lines[-1] == "\n" and output_lines[-2] == "\n":
            output_lines.pop()
        if output_lines and output_lines[-1] != "\n":
            output_lines.append("\n")

        # --- 寫入新的 VTT 文件 ---
        with open(output_vtt_path, 'w', encoding='utf-8', newline='\n') as f_out:
            f_out.write(''.join(output_lines))

        print(f"Info: Generated enhanced VTT (v{__version__}, Final Version) to {output_vtt_path}", file=sys.stderr)
        return 0 # 成功

    except FileNotFoundError:
        print(f"Error: Input VTT file not found: {input_vtt_path}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"An unexpected error occurred during VTT enhancement: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return 1

# --- Main Execution ---
# (保持不變)
if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python vtt_enhancer.py <input_vtt_file> <output_vtt_file>", file=sys.stderr)
        sys.exit(2)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    exit_code = enhance_vtt(input_file, output_file)
    sys.exit(exit_code)
