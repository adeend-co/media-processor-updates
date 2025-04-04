#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os

# --- Script Configuration ---
__version__ = "1.1.5(Fix Header & Style Skip)"

# --- VTT Enhancement Logic ---

def enhance_vtt(input_vtt_path, output_vtt_path):
    """讀取 VTT 文件，確保結構正確，強制移除原始 Style/##（測試點 A 狀態）"""
    try:
        with open(input_vtt_path, 'r', encoding='utf-8') as f_in:
            lines = f_in.readlines()

        output_content = [] # 改用 list 存儲最終要輸出的行

        # --- 確保開頭正確 ---
        output_content.append("WEBVTT\n") # 第一行只有 WEBVTT + 換行符
        output_content.append("\n")       # 第二行是空行

        in_header = True
        in_original_style_block = False # 標誌是否在原始 STYLE 塊內

        for line in lines:
            # --- 移除潛在的 BOM 和處理換行符 ---
            if line.startswith('\ufeff'):
                line = line[1:]
            line = line.rstrip() # 移除行尾空白和換行符

            # --- 跳過原始 WEBVTT 和其後的空行 ---
            if in_header and (line == "WEBVTT" or not line):
                continue

            # --- 判斷是否進入或跳過原始 STYLE 塊 ---
            if line.startswith("STYLE"):
                in_original_style_block = True
                continue # 跳過 "STYLE" 行
            if line == "##": # 遇到 ## 也標記 STYLE 結束並跳過
                in_original_style_block = False
                continue # 跳過 "##" 行

            if in_original_style_block:
                 # 如果在 STYLE 塊內（且不是 ##），則跳過該行
                 # 檢查是否是 STYLE 塊結束的空行
                 if not line:
                     in_original_style_block = False
                 continue # 跳過 STYLE 內容或結束的空行

            # --- 跳過 Kind, Language, NOTE (因為我們不需要它們，且它們可能干擾) ---
            if line.startswith("Kind:") or line.startswith("Language:") or line.startswith("NOTE"):
                in_header = False # 遇到這些也認為 Header 結束
                continue

            # --- 遇到第一個非空、非上述標頭的行，認為 Header 結束 ---
            if in_header and line:
                 in_header = False

            # --- Header 結束後，處理時間碼和文本行 ---
            if not in_header:
                is_timestamp_line = '-->' in line
                is_text_line = bool(line) and not is_timestamp_line
                is_empty_line = not line

                if is_timestamp_line:
                    # 在 Cue 開始前確保有空行
                    if output_content and output_content[-1] != "\n":
                        output_content.append("\n")
                    output_content.append(line + "\n") # 添加時間碼行 + LF
                elif is_text_line:
                    # 測試點 A：添加原始文本行 + LF
                    output_content.append(line + "\n")
                elif is_empty_line:
                    # 確保 Cue 之間只有一個空行
                    if output_content and output_content[-1] != "\n":
                        output_content.append("\n")

        # --- 確保文件末尾有且只有一個空行 ---
        while len(output_content) > 2 and output_content[-1] == "\n" and output_content[-2] == "\n":
             output_content.pop() # 移除多餘的結尾空行

        # 如果結尾不是空行，則添加一個
        if output_content and output_content[-1] != "\n":
             output_content.append("\n")

        # --- 寫入新的 VTT 文件 ---
        with open(output_vtt_path, 'w', encoding='utf-8', newline='\n') as f_out:
            f_out.write(''.join(output_content))

        print(f"Info: Generated enhanced VTT (v{__version__}, Test A state) to {output_vtt_path}", file=sys.stderr)
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
    if len(sys.argv) != 3:
        print("Usage: python vtt_enhancer.py <input_vtt_file> <output_vtt_file>", file=sys.stderr)
        sys.exit(2)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    exit_code = enhance_vtt(input_file, output_file)
    sys.exit(exit_code)
