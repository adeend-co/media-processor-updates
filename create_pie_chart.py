#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import csv
import platform
import matplotlib
import matplotlib.pyplot as plt

# 腳本版本
SCRIPT_VERSION = "1.0.0"

def set_chinese_font():
    """
    智能設置中文字體，以解決 matplotlib 中文顯示為方塊的問題。
    """
    system = platform.system()
    try:
        if system == 'Darwin':  # macOS
            plt.rcParams['font.sans-serif'] = ['Arial Unicode MS']
        elif system == 'Linux':
            # 優先嘗試尋找 Noto Sans CJK，這是 Termux 和許多現代 Linux 的標配
            # 如果您安裝了其他字體，請修改下面的列表
            font_list = ['Noto Sans CJK JP', 'Noto Sans CJK SC', 'WenQuanYi Micro Hei']
            for font in font_list:
                try:
                    matplotlib.font_manager.findfont(font)
                    plt.rcParams['font.sans-serif'] = [font]
                    plt.rcParams['axes.unicode_minus'] = False # 解決負號顯示問題
                    print(f"INFO: Found and set CJK font: {font}", file=sys.stderr)
                    return
                except:
                    continue
            print("WARNING: CJK font not found. Please install a font like 'noto-fonts-cjk' or 'wqy-microhei'.", file=sys.stderr)
        # Windows 的處理可以加在這裡，如果需要的話
        # elif system == 'Windows':
        #     plt.rcParams['font.sans-serif'] = ['Microsoft YaHei']
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

    fig, ax = plt.subplots(figsize=(10, 8))
    
    # 繪製圓餅圖
    wedges, texts, autotexts = ax.pie(
        sizes, 
        autopct='%1.1f%%',  # 顯示百分比，保留一位小數
        startangle=90,      # 從90度角開始繪製
        shadow=True,
        pctdistance=0.85,   # 百分比文字離圓心的距離
    )

    # 調整圖例和標籤
    ax.legend(wedges, labels,
              title="支出類別",
              loc="center left",
              bbox_to_anchor=(1, 0, 0.5, 1))

    plt.setp(autotexts, size=10, weight="bold", color="white")
    
    ax.set_title(title, size=16, weight="bold")
    ax.axis('equal')  # 確保圓餅圖是正圓形

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
