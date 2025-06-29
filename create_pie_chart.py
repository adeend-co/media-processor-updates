#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import csv
import os
import matplotlib
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties

# 腳本版本
SCRIPT_VERSION = "1.2.0"

def set_chinese_font():
    """
    智能設置中文字體，優先使用絕對路徑，確保字體能被找到。
    """
    try:
        # --- 核心修改：直接指定我們手動安裝的字體檔案路徑 ---
        # $PREFIX 是 Termux 的環境變數，通常指向 /data/data/com.termux/files/usr
        font_path = os.path.expandvars('$PREFIX/share/fonts/TTF/NotoSansCJK-Regular.otf')

        if os.path.exists(font_path):
            # 使用 FontProperties 直接從檔案路徑加載字體
            # 這是最可靠的方法，繞過了 matplotlib 按名稱搜尋的快取問題
            font_prop = FontProperties(fname=font_path)
            plt.rcParams['font.family'] = 'sans-serif' # 必須設定一個通用家族
            plt.rcParams['font.sans-serif'] = [font_prop.get_name()]
            plt.rcParams['axes.unicode_minus'] = False # 解決負號顯示問題
            print(f"INFO: Successfully set font from path: {font_path}", file=sys.stderr)
            return
        else:
            # 如果指定的檔案路徑不存在，再嘗試按名稱搜尋作為備用方案
            font_list = ['Noto Sans CJK JP', 'Noto Sans CJK SC', 'WenQuanYi Micro Hei']
            for font in font_list:
                try:
                    matplotlib.font_manager.findfont(font, fallback_to_default=False)
                    plt.rcParams['font.sans-serif'] = [font]
                    plt.rcParams['axes.unicode_minus'] = False
                    print(f"INFO: Found and set CJK font by name: {font}", file=sys.stderr)
                    return
                except ValueError:
                    continue
        
        print("WARNING: CJK font not found. Please ensure it is installed correctly.", file=sys.stderr)

    except Exception as e:
        print(f"WARNING: An error occurred while setting font: {e}", file=sys.stderr)

# ... create_pie_chart 和 main 函數保持不變 ...
def create_pie_chart(data_file, output_file, title):
    labels = []
    sizes = []
    try:
        with open(data_file, mode='r', encoding='utf-8') as infile:
            reader = csv.reader(infile)
            for row in reader:
                if len(row) == 2:
                    labels.append(row[0])
                    try: sizes.append(float(row[1]));
                    except ValueError: print(f"WARNING: Skipping invalid value in row: {row}", file=sys.stderr); continue
    except FileNotFoundError: print(f"ERROR: Input data file not found: {data_file}", file=sys.stderr); sys.exit(1)
    if not labels or not sizes: print("ERROR: No valid data found to generate chart.", file=sys.stderr); sys.exit(1)

    set_chinese_font()
    fig, ax = plt.subplots(figsize=(10, 8), subplot_kw=dict(aspect="equal"))
    wedges, texts, autotexts = ax.pie(sizes, autopct='%1.1f%%', startangle=90, shadow=False, pctdistance=0.8, textprops=dict(color="w"))
    ax.legend(wedges, labels, title="支出類別", loc="center left", bbox_to_anchor=(1, 0, 0.5, 1))
    plt.setp(autotexts, size=10, weight="bold")
    ax.set_title(title, size=16, weight="bold")
    try:
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
        print(f"SUCCESS: Chart saved to {output_file}")
    except Exception as e:
        print(f"ERROR: Failed to save chart to {output_file}. Reason: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Create a pie chart from CSV data.")
    parser.add_argument('--version', action='version', version=f'%(prog)s {SCRIPT_VERSION}')
    parser.add_argument('--input', required=True, help='Path to the input CSV data file (Label,Value).')
    parser.add_argument('--output', required=True, help='Path to save the output PNG image.')
    parser.add_argument('--title', required=True, help='Title for the chart.')
    args = parser.parse_args()
    create_pie_chart(args.input, args.output, args.title)
