#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import csv
import platform
import matplotlib
import matplotlib.pyplot as plt

# 腳本版本
SCRIPT_VERSION = "1.1.0"

def set_chinese_font():
    """
    智能設置中文字體，以解決 matplotlib 中文顯示為方塊的問題。
    """
    system = platform.system()
    try:
        # 在 Termux/Linux 環境下，優先尋找 Noto Sans CJK 字體
        # 這是透過 'pkg install noto-fonts-cjk' 安裝的
        if system == 'Linux' or system == 'Darwin': # Darwin (macOS) 也可能用這個路徑
            font_path = '/data/data/com.termux/files/usr/share/fonts/TTF/NotoSansCJKjp-Regular.otf'
            if platform.system() == 'Darwin': # macOS 的標準路徑
                font_path = '/System/Library/Fonts/STHeiti Medium.ttc'

            # 檢查字體是否存在
            import os
            if os.path.exists(font_path):
                 plt.rcParams['font.sans-serif'] = [matplotlib.font_manager.FontProperties(fname=font_path).get_name()]
                 plt.rcParams['axes.unicode_minus'] = False
                 print(f"INFO: Found and set CJK font: {font_path}", file=sys.stderr)
                 return
            else:
                 # 如果預設路徑找不到，再嘗試通用名稱
                 font_list = ['Noto Sans CJK JP', 'Noto Sans CJK SC', 'WenQuanYi Micro Hei']
                 for font in font_list:
                    try:
                        matplotlib.font_manager.findfont(font)
                        plt.rcParams['font.sans-serif'] = [font]
                        plt.rcParams['axes.unicode_minus'] = False
                        print(f"INFO: Found and set CJK font by name: {font}", file=sys.stderr)
                        return
                    except:
                        continue
        print("WARNING: CJK font not found. Please install a font like 'noto-fonts-cjk'.", file=sys.stderr)
    except Exception as e:
        print(f"WARNING: An error occurred while setting font: {e}", file=sys.stderr)


def create_pie_chart(data_file, output_file, title):
    """
    從 CSV 檔案讀取資料並創建圓餅圖。
    """
    labels = []
    sizes = []
    try:
        with open(data_file, mode='r', encoding='utf-8') as infile:
            reader = csv.reader(infile)
            for row in reader:
                if len(row) == 2:
                    labels.append(row[0])
                    try:
                        sizes.append(float(row[1]))
                    except ValueError:
                        print(f"WARNING: Skipping invalid value in row: {row}", file=sys.stderr)
                        continue
    except FileNotFoundError:
        print(f"ERROR: Input data file not found: {data_file}", file=sys.stderr)
        sys.exit(1)
        
    if not labels or not sizes:
        print("ERROR: No valid data found to generate chart.", file=sys.stderr)
        sys.exit(1)

    # 設置中文字體
    set_chinese_font()

    fig, ax = plt.subplots(figsize=(10, 8), subplot_kw=dict(aspect="equal"))
    
    # --- ▼▼▼ 核心修改：關閉陰影，調整樣式 ▼▼▼ ---
    wedges, texts, autotexts = ax.pie(
        sizes, 
        autopct='%1.1f%%',
        startangle=90,
        shadow=False,  # 關閉陰影效果，得到乾淨的2D圖表
        pctdistance=0.8,
        textprops=dict(color="w") # 將百分比文字預設設為白色
    )
    # --- ▲▲▲ 修改結束 ▲▲▲ ---

    ax.legend(wedges, labels,
              title="支出類別",
              loc="center left",
              bbox_to_anchor=(1, 0, 0.5, 1))

    plt.setp(autotexts, size=10, weight="bold")
    
    ax.set_title(title, size=16, weight="bold")
    
    try:
        # 使用 bbox_inches='tight' 來自動裁剪空白邊緣
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
