#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os
# from datetime import timedelta # 不再需要

# --- Script Configuration ---
# <<< 更新版本號以反映修改 >>>
__version__ = "1.1.3(Fix Structure)"

# --- VTT Enhancement Logic ---

def enhance_vtt(input_vtt_path, output_vtt_path):
    """讀取 VTT 文件，規範化顏色標籤，保留位置信息，並確保結構正確"""
    try:
        with open(input_vtt_path, 'r', encoding='utf-8') as f_in:
            lines = f_in.readlines()

        output_lines = []
        color_map = {}
        css_class_counter = 0
        style_block_needed = False

        # --- 移除潛在的 BOM (Byte Order Mark) ---
        if lines and lines[0].startswith('\ufeff'):
            lines[0] = lines[0][1:]

        # --- 第一遍：掃描並提取顏色 ---
        # (這部分邏輯不變)
        for line in lines:
            matches = re.findall(r'<c\.color([0-9A-Fa-f]{6})>', line, re.IGNORECASE)
            for hex_color in matches:
                hex_color = hex_color.upper()
                if hex_color not in color_map:
                    css_class_name = f"c{css_class_counter}"
                    color_map[hex_color] = css_class_name
                    css_class_counter += 1
                    style_block_needed = True

        # --- 開始構建輸出 ---
        output_lines.append("WEBVTT")
        output_lines.append("") # WEBVTT 後必須有空行

        # --- 生成 STYLE 塊 (如果需要) ---
        # (這部分邏輯不變)
       # if style_block_needed:
       #     output_lines.append("STYLE")
        #    for hex_color, class_name in color_map.items():
         #       css_color = f"#{hex_color}"
        #        output_lines.append(f"::cue(.{class_name}) {{ color: {css_color}; }}")
        #    output_lines.append("") # STYLE 塊後必須有空行

        # --- 第二遍：處理 Cues (時間碼和文本)，確保結構正確 ---
        in_header = True
        in_style_block = False # 新增標誌，用於跳過原始 STYLE 塊
        last_line_was_cue_related = False # 新增標誌，用於確保 Cue 之間有空行

        for line in lines:
            line_strip = line.strip()

            # --- 簡化頭部和原始 STYLE 塊的跳過邏輯 ---
            if in_header:
                if line_strip == "WEBVTT":
                    continue # 跳過原始 WEBVTT
                # 遇到第一個非空、非 NOTE、非 STYLE 的行，或時間碼，視為 Header 結束
                # 注意：我們自己生成 STYLE，所以要跳過原始的
                elif line_strip.startswith("STYLE"):
                    in_style_block = True
                    continue
                elif in_style_block:
                    if not line_strip: # STYLE 塊以空行結束
                        in_style_block = False
                    continue # 跳過 STYLE 塊內容
                elif line_strip.startswith("NOTE"):
                    # 保留 NOTE (可選，如果原始文件有 NOTE 且想保留)
                    # output_lines.append(line_strip)
                    # output_lines.append("") # NOTE 後面也建議空行
                    last_line_was_cue_related = False # NOTE 不算 Cue
                    continue
                elif '-->' in line_strip or line_strip: # 遇到時間碼或非空文本行
                    in_header = False # Header 結束
                else:
                    # 處理 Header 中的空行（通常應該忽略）
                    continue

            # --- 處理 Cue 部分 ---
            is_timestamp_line = '-->' in line_strip
            is_text_line = bool(line_strip) and not is_timestamp_line
            is_empty_line = not line_strip

            if is_timestamp_line:
                # 在每個 Cue 開始前（即時間碼前），確保與上一個 Cue 有空行
                if last_line_was_cue_related:
                    # 檢查 output_lines 最後一行是否為空，如果不是則添加
                    if output_lines and output_lines[-1].strip():
                         output_lines.append("")
                output_lines.append(line_strip) # 添加時間碼行
                last_line_was_cue_related = True
            elif is_text_line:
                # 處理文本行 (替換顏色標籤，移除 </c>)
                processed_line = line_strip
           #     for hex_color, class_name in color_map.items():
           #         pattern = re.compile(f'<c\\.color{hex_color}>', re.IGNORECASE)
           #         processed_line = pattern.sub(f'<c.{class_name}>', processed_line)
           #     processed_line = processed_line.replace('</c>', '')
                output_lines.append(processed_line) # 添加處理後的文本行
                last_line_was_cue_related = True
            elif is_empty_line:
                # 處理原始文件中的空行
                # 如果上一個相關行也是 Cue 的一部分，則保留這個空行（作為 Cue 的分隔）
                # 否則，忽略多餘的空行
                if last_line_was_cue_related:
                    # 只有當 output_lines 最後一行不是空行時才添加這個空行，避免連續多個空行
                    if output_lines and output_lines[-1].strip():
                         output_lines.append("")
                last_line_was_cue_related = False # 遇到空行，重置標誌

        # --- 確保文件末尾有空行 ---
        # 移除末尾可能的多餘空行，然後確保只有一個
        while output_lines and not output_lines[-1].strip():
             output_lines.pop()
        output_lines.append("") # 添加一個確定的空行在結尾

        # --- 寫入新的 VTT 文件 ---
        with open(output_vtt_path, 'w', encoding='utf-8') as f_out:
            f_out.write('\n'.join(output_lines))
            # f_out.write('\n') # 不再需要額外加換行，因為 join 後面已經確保結尾是空行了

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
if __name__ == "__main__":
    # print(f"vtt_enhancer.py version {__version__}") # 可以在調試時取消註解

    if len(sys.argv) != 3:
        print("Usage: python vtt_enhancer.py <input_vtt_file> <output_vtt_file>", file=sys.stderr)
        sys.exit(2)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    exit_code = enhance_vtt(input_file, output_file)
    sys.exit(exit_code)
