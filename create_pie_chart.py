#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
import argparse
import csv
import os
import matplotlib.pyplot as plt
from matplotlib.font_manager import FontProperties

# 腳本版本
SCRIPT_VERSION = "1.4.0"

def get_cjk_font_prop():
    """
    獲取指向中文字體的 FontProperties 物件。
    """
    font_path = os.path.expandvars('$PREFIX/share/fonts/TTF/NotoSansCJK-Regular.otf')
    if os.path.exists(font_path):
        print(f"INFO: Font file found at: {font_path}", file=sys.stderr)
        return FontProperties(fname=font_path)
    else:
        print(f"ERROR: Font file not found at: {font_path}", file=sys.stderr)
        return None

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
                    except ValueError: print(f"WARNING: Skipping invalid value: {row}", file=sys.stderr); continue
    except FileNotFoundError: print(f"ERROR: Input data file not found: {data_file}", file=sys.stderr); sys.exit(1)
    if not labels or not sizes: print(f"ERROR: No valid data to generate chart.", file=sys.stderr); sys.exit(1)

    cjk_font_prop = get_cjk_font_prop()
    if cjk_font_prop is None:
        sys.exit(1)

    fig, ax = plt.subplots(figsize=(10, 8), subplot_kw=dict(aspect="equal"))
    
    wedges, texts, autotexts = ax.pie(
        sizes, 
        autopct='%1.1f%%',
        startangle=90,
        shadow=False,
        pctdistance=0.8,
        textprops=dict(color="w")
    )

    # --- ▼▼▼ 核心修改：獲取圖例物件，並單獨設定其標題字體 ▼▼▼ ---
    # 步驟 1: 將 legend 物件存到變數 leg 中
    leg = ax.legend(wedges, labels,
              title="支出類別",
              loc="center left",
              bbox_to_anchor=(1, 0, 0.5, 1),
              prop=cjk_font_prop) # 'prop' 只影響項目，不影響標題

    # 步驟 2: 明確地設定 legend 標題的字體
    plt.setp(leg.get_title(), fontproperties=cjk_font_prop)
    # --- ▲▲▲ 修改結束 ▲▲▲ ---

    plt.setp(autotexts, size=10, weight="bold")
    
    ax.set_title(title, size=16, weight="bold", fontproperties=cjk_font_prop)
    
    try:
        plt.savefig(output_file, dpi=150, bbox_inches='tight')
        print(f"SUCCESS: Chart saved to {output_file}")
    except Exception as e:
        print(f"ERROR: Failed to save chart: {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Create a pie chart from CSV data.")
    parser.add_argument('--version', action='version', version=f'%(prog)s {SCRIPT_VERSION}')
    parser.add_argument('--input', required=True, help='Path to the input CSV data file (Label,Value).')
    parser.add_argument('--output', required=True, help='Path to save the output PNG image.')
    parser.add_argument('--title', required=True, help='Title for the chart.')
    args = parser.parse_args()
    create_pie_chart(args.input, args.output, args.title)
