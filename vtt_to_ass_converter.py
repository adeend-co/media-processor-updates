#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os
from datetime import timedelta

# --- Script Configuration ---
__version__ = "1.1.1(Experimental)" # 新腳本的版本號

# --- Helper Functions ---
# (parse_vtt_time 和 format_ass_time 可以移除，因為我們處理 VTT 時間)

# --- VTT Enhancement Logic ---

def enhance_vtt(input_vtt_path, output_vtt_path):
    """讀取 VTT 文件，規範化顏色標籤，保留位置信息"""
    try:
        with open(input_vtt_path, 'r', encoding='utf-8') as f_in:
            lines = f_in.readlines()

        output_lines = []
        # 儲存提取到的顏色和對應的 CSS 類名
        color_map = {} 
        css_class_counter = 0
        style_block_needed = False

        # --- 第一遍：掃描並提取顏色 ---
        for line in lines:
            # 查找非標準顏色標籤
            matches = re.findall(r'<c\.color([0-9A-Fa-f]{6})>', line, re.IGNORECASE)
            for hex_color in matches:
                hex_color = hex_color.upper()
                if hex_color not in color_map:
                    # 為每個新顏色創建一個唯一的 CSS 類名
                    css_class_name = f"c{css_class_counter}"
                    color_map[hex_color] = css_class_name
                    css_class_counter += 1
                    style_block_needed = True # 標記需要生成 STYLE 塊

        # --- 寫入處理後的 VTT ---
        output_lines.append("WEBVTT")
        output_lines.append("") # WEBVTT 後需要空行

        # --- 如果檢測到顏色，生成 STYLE 塊 ---
        if style_block_needed:
            output_lines.append("STYLE")
            for hex_color, class_name in color_map.items():
                # 將 RRGGBB 格式的 HEX 轉換為 CSS 的 #RRGGBB
                css_color = f"#{hex_color}"
                # 定義 CSS 類
                output_lines.append(f"::cue(.{class_name}) {{ color: {css_color}; }}")
            output_lines.append("") # STYLE 塊後需要空行

        # --- 第二遍：處理時間碼和文本，替換標籤 ---
        in_header = True # 用於跳過初始的 WEBVTT 和 STYLE 塊（如果自己生成了）
        for line in lines:
            line_strip = line.strip()
            
            # 跳過原始文件的 WEBVTT 行和空行
            if in_header and (line_strip == "WEBVTT" or not line_strip):
                continue
            # 跳過原始文件的 STYLE 塊 (我們自己生成)
            if line_strip == "STYLE":
                 in_header = False # STYLE 塊之後就是正文了
                 while True: # 循環讀取直到 STYLE 塊結束 (遇到空行)
                      try:
                          next_line = next(iter(lines)).strip() # 讀取下一行
                          if not next_line: break # STYLE 塊結束
                      except StopIteration: break # 文件結束
                 continue # 跳過原始 STYLE 塊
            
            # 遇到時間碼行或文本行，就認為 header 結束
            if '-->' in line_strip or line_strip:
                 in_header = False

            # 直接保留時間碼行（包含位置信息）
            if '-->' in line_strip:
                output_lines.append(line_strip)
                continue
                
            # 處理文本行
            processed_line = line_strip
            # 替換非標準顏色標籤為標準 VTT 類標籤 <c.classname>
            for hex_color, class_name in color_map.items():
                 # 使用 re.sub 進行替換，忽略大小寫
                 pattern = re.compile(f'<c\\.color{hex_color}>', re.IGNORECASE)
                 processed_line = pattern.sub(f'<c.{class_name}>', processed_line)
            
            # 保留標準的 </b> 標籤 (粗體) - VTT 也支持 <b>
            # 移除 </c> 標籤，因為標準 VTT 的 <c.classname> 作用於整個 cue 或被下一個覆蓋
            processed_line = processed_line.replace('</c>', '') 

            # 將處理後的行加入輸出列表
            output_lines.append(processed_line)

        # --- 寫入新的 VTT 文件 ---
        with open(output_vtt_path, 'w', encoding='utf-8') as f_out:
            f_out.write('\n'.join(output_lines))
            f_out.write('\n')

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
    # print(f"vtt_enhancer.py version {__version__}")

    if len(sys.argv) != 3:
        print("Usage: python vtt_enhancer.py <input_vtt_file> <output_vtt_file>", file=sys.stderr)
        sys.exit(2)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    exit_code = enhance_vtt(input_file, output_file)
    sys.exit(exit_code)
