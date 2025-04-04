#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os
# from datetime import timedelta # 不再需要

# --- Script Configuration ---
# <<< 更新版本號以反映修改 >>>
__version__ = "1.1.4(Fix Structure)"

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
        # <<< 移除 in_style_block 標誌，我們直接判斷 >>>
        last_line_was_cue_related = False

        for line in lines:
            line_strip = line.strip()
            original_line = line # <<< 保留原始行，包含換行符

            # --- 嚴格跳過 Header 和 STYLE ---
            if in_header:
                if line_strip == "WEBVTT":
                    continue
                # <<< 如果遇到 STYLE 或其內容（直到 ##），直接跳過 >>>
                elif line_strip.startswith("STYLE") or line_strip.startswith("::cue") or line_strip == "}" or line_strip == "##":
                     # 簡單粗暴地跳過所有看起來像 STYLE 塊內容的行和 ##
                     # 這裡假設 STYLE 塊內容不會跨越多行且不包含空行，這對於原始文件是成立的
                    continue
                elif line_strip.startswith("NOTE"):
                    continue # 也跳過 NOTE
                elif not line_strip: # 跳過 Header 或 STYLE 塊結束後的空行
                    # 僅當檢測到第一個時間碼或文本後，才認為 Header 結束
                    # 所以在 Header 階段的空行都跳過
                    continue
                elif '-->' in line_strip or line_strip: # 遇到第一個有效 Cue 或 Kind/Language
                    # 如果是 Kind 或 Language，也保留（雖然我們可能不需要它們）
                    if line_strip.startswith("Kind:") or line_strip.startswith("Language:"):
                         output_lines.append(original_line.rstrip() + '\n') # 保留 Kind/Language，確保LF換行
                         continue
                    else: # 否則認為 Header 結束
                         in_header = False
                else:
                     continue # 其他情況跳過

            # --- Header 結束後，處理 Cue 部分 ---
            # <<< 確保這裡是在 in_header 為 False 時才執行 >>>
            if not in_header:
                is_timestamp_line = '-->' in line_strip
                is_text_line = bool(line_strip) and not is_timestamp_line
                is_empty_line = not line_strip

                if is_timestamp_line:
                    if last_line_was_cue_related:
                        if output_lines and output_lines[-1].strip():
                            output_lines.append("\n") # 使用 LF 空行
                    # <<< 寫入時間碼行，確保是 LF 結尾 >>>
                    output_lines.append(original_line.rstrip() + '\n')
                    last_line_was_cue_related = True
                elif is_text_line:
                    # <<< 寫入原始文本行（Test A），確保是 LF 結尾 >>>
                    output_lines.append(original_line.rstrip() + '\n')
                    last_line_was_cue_related = True
                elif is_empty_line:
                    if last_line_was_cue_related:
                        if output_lines and output_lines[-1].strip():
                            output_lines.append("\n") # 使用 LF 空行
                    last_line_was_cue_related = False # 遇到空行重置

        # --- 確保文件末尾有空行 (LF) ---
        while output_lines and not output_lines[-1].strip():
            output_lines.pop()
        output_lines.append("\n")

        # --- 寫入新的 VTT 文件 ---
        with open(output_vtt_path, 'w', encoding='utf-8', newline='\n') as f_out: # <<< 強制 LF 換行 >>>
            f_out.write(''.join(output_lines)) # <<< 使用 ''.join 因為每行已有換行符 >>>

        return 0

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
