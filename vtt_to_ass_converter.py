#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import re
import os

# --- Script Configuration ---
__version__ = "1.1.6(Precise Copy & Header Skip)"

# --- VTT Enhancement Logic ---

def enhance_vtt(input_vtt_path, output_vtt_path):
    """讀取 VTT 文件，精確跳過 Header/Style/##，原樣複製 Cues（測試點 A 狀態）"""
    try:
        with open(input_vtt_path, 'r', encoding='utf-8') as f_in:
            lines = f_in.readlines()

        output_lines = []
        output_lines.append("WEBVTT\n") # 強制正確開頭
        output_lines.append("\n")       # 強制空行

        in_cue_section = False # 標誌是否已進入 Cue 部分

        for line in lines:
            # --- 移除 BOM 和處理換行符 ---
            if output_lines[-2] == "WEBVTT\n" and line.startswith('\ufeff'): # 僅檢查文件首行 BOM
                 line = line[1:]
            original_line_content = line.rstrip() # 獲取去除尾部空白的行內容
            original_line_ending = line[len(original_line_content):] # 獲取原始換行符 (或空)

            # 確保我們使用的是 LF 換行符
            if not original_line_ending:
                 line_with_lf = original_line_content + "\n"
            elif original_line_ending == "\n":
                 line_with_lf = line
            else: # 其他情況（如 \r\n 或只有 \r）強制改為 \n
                 line_with_lf = original_line_content + "\n"


            # --- 狀態機：尋找第一個時間碼行 ---
            if not in_cue_section:
                # 只要包含 '-->' 就認為是第一個時間碼，開始進入 Cue 區段
                if '-->' in original_line_content:
                    in_cue_section = True
                    # 將這個第一個時間碼行加入輸出
                    output_lines.append(line_with_lf)
                else:
                    # 在找到第一個時間碼之前，所有行（包括 WEBVTT, Kind, Lang, Style, ##, NOTE, 空行）都忽略
                    continue
            else:
                # --- 進入 Cue 區段後，原樣複製所有行（包括空行） ---
                # 我們假設原始 VTT 的 Cue 結構（包括空行）是 FFmpeg 可以接受的
                # 所以不再嘗試自己判斷和插入空行，直接複製原始文件的行（確保是 LF 結尾）
                output_lines.append(line_with_lf)


        # --- 確保文件末尾是空行（如果原始文件不是） ---
        if output_lines and output_lines[-1].strip():
            output_lines.append("\n")
        # --- 如果末尾已經是空行或多個空行，只保留一個 ---
        while len(output_lines) > 2 and output_lines[-1] == "\n" and output_lines[-2] == "\n":
            output_lines.pop()


        # --- 寫入新的 VTT 文件 ---
        with open(output_vtt_path, 'w', encoding='utf-8', newline='\n') as f_out:
            f_out.write(''.join(output_lines))

        print(f"Info: Generated enhanced VTT (v{__version__}, Test A state - Precise Copy) to {output_vtt_path}", file=sys.stderr)
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
