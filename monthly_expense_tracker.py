#!/usr/bin/env python3

################################################################################
#                                                                              #
#             月份支出追蹤器 (Monthly Expense Tracker) v10.0                    #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個高度智慧化的獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。     #
# 它具備自動格式清理、互動式路徑輸入、月份項目分析與百分比計算等頂級功能。          #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "月份支出追蹤器"
SCRIPT_VERSION = "v10.1"
SCRIPT_UPDATE_DATE = "2025-07-13"

import sys
import os
import subprocess
import warnings

# --- 顏色處理類別 (提前定義並初始化) ---
class Colors:
    """管理終端機輸出的 ANSI 顏色代碼"""
    def __init__(self, enabled=True):
        if enabled and sys.stdout.isatty():
            self.RED = '\033[0;31m'; self.GREEN = '\033[0;32m'; self.YELLOW = '\033[1;33m'
            self.CYAN = '\033[0;36m'; self.PURPLE = '\033[0;35m'; self.WHITE = '\033[0;37m'
            self.BOLD = '\033[1m'; self.RESET = '\033[0m'
        else:
            self.RED = self.GREEN = self.YELLOW = self.CYAN = self.PURPLE = self.WHITE = self.BOLD = self.RESET = ''

# --- 提前初始化顏色 (腳本啟動時立即載入) ---
colors = Colors(enabled=True)  # 假設預設啟用顏色，您可以根據需要調整

# --- 新增：環境檢查函數 (在啟動前檢查所有依賴工具) ---
def check_environment():
    """檢查所有依賴工具是否存在"""
    print(f"{colors.CYAN}正在進行環境檢查...{colors.RESET}")
    
    # 定義所有依賴工具
    required_packages = ['pandas']
    missing_packages = RosyBrowns = []
    
    for pkg in required_packages:
        try:
            __import__(pkg)
            print(f"{colors.GREEN}  - {pkg} 已安裝。{colors.RESET}")
        except ImportError:
            missing_packages.append(pkg)
            print(f"{colors.RED}  - {pkg} 未安裝！{colors.RESET}")
    
    if missing_packages:
        print(f"\n{colors.RED}環境檢查失敗！缺少以下套件：{', '.join(missing_packages)}{colors.RESET}")
        print(f"{colors.YELLOW}請執行 'pip install {' '.join(missing_packages)}' 安裝缺少的套件。{colors.RESET}")
        sys.exit(1)
    
    print(f"{colors.GREEN}環境檢查通過，所有依賴工具均已安裝。{colors.RESET}")

# --- 自動安裝依賴函數 (調整為適合 Termux) ---
def install_dependencies():
    """檢查並安裝缺少的 Python 庫 (僅 pandas)，適合 Termux 環境"""
    required_packages = ['pandas']
    for pkg in required_packages:
        try:
            __import__(pkg)
        except ImportError:
            print(f"{colors.YELLOW}提示：正在安裝缺少的必要套件: {pkg}...{colors.RESET}")
            try:
                # 先嘗試 pip 安裝
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', pkg])
                print(f"{colors.GREEN}成功安裝 {pkg}。{colors.RESET}")
            except subprocess.CalledProcessError:
                # 若 pip 失敗，建議 Termux 專屬指令
                print(f"{colors.RED}pip 安裝 {pkg} 失敗！{colors.RESET}")
                print(f"{colors.YELLOW}建議：在 Termux 中執行 'pkg install tur-repo' 後再執行 'pkg install python-pandas'，或檢查網路/權限。{colors.RESET}")
                sys.exit(1)

def main():
    # --- 腳本啟動時立即檢查環境 (顏色已載入) ---
    check_environment()
    
    # --- 載入所有依賴 (檢查通過後) ---
    import pandas as pd
    from datetime import datetime
    import argparse

    # --- 智慧欄位辨識與資料處理 ---
    def find_column_by_synonyms(df_columns, synonyms):
        """根據同義詞列表查找欄位名稱"""
        for col in df_columns:
            if str(col).strip().lower() in [s.lower() for s in synonyms]:
                return col
        return None

    def normalize_date(date_str):
        """標準化日期為年月格式 (e.g., 2025-01)，支援年月日格式"""
        s = str(date_str).strip()
        current_year = datetime.now().year
        # 嘗試解析完整年月日格式 (e.g., 20250713)
        if s.isdigit() and len(s) == 8:
            try:
                dt = datetime.strptime(s, '%Y%m%d')
                return f"{dt.year}-{dt.month:02d}"
            except ValueError:
                pass
        # 處理像701, 702這種格式
        if s.isdigit() and len(s) <= 4:
            s = s.zfill(4)  # 補足4位數
            month = int(s[:-2])
            return f"{current_year}-{month:02d}"
        # 處理像202501、2025年01、2025年01月
        s = s.replace('年', '-').replace('月', '').replace(' ', '')
        if len(s) == 6 and s.isdigit():  # 202501
            year = s[:4]
            month = s[4:6]
            return f"{year}-{month}"
        parts = s.split('-')
        if len(parts) >= 2:
            year = parts[0]
            month = parts[1].zfill(2)
            return f"{year}-{month}"
        return None  # 無效日期

    def process_finance_data(file_paths: list, colors: Colors):
        """
        讀取、合併、清理並分析來自多個 CSV 檔案的財務資料。
        專注於支出，忽略收入，按月份分組項目。
        """
        all_dfs = []
        for file_path in file_paths:
            try:
                df = pd.read_csv(file_path.strip())
                all_dfs.append(df)
            except FileNotFoundError:
                print(f"{colors.RED}錯誤：找不到檔案 '{file_path.strip()}'！將跳過此檔案。{colors.RESET}")
                continue
        
        if not all_dfs:
            return None, None, "沒有成功讀取任何資料檔案。"

        master_df = pd.concat(all_dfs, ignore_index=True)
        master_df.columns = master_df.columns.str.strip()

        # 智慧欄位名稱辨識
        date_col = find_column_by_synonyms(master_df.columns, ['日期', '時間', 'Date', 'time'])
        item_col = find_column_by_synonyms(master_df.columns, ['項目', '類型', 'Type', '收支項目', '收支'])
        amount_col = find_column_by_synonyms(master_df.columns, ['金額', 'Amount', 'amount', '價格', '支出', 'expense'])
        
        if not (date_col and item_col and amount_col):
            missing = [c for c, v in zip(['日期', '項目', '金額/支出'], [date_col, item_col, amount_col]) if not v]
            return None, None, f"無法辨識的表格結構。缺少必要的欄位：{missing}"

        # 只保留相關欄位，並標準化日期
        processed_df = master_df[[date_col, item_col, amount_col]].copy()
        processed_df.rename(columns={date_col: 'Date', item_col: 'Item', amount_col: 'Amount'}, inplace=True)
        processed_df['YearMonth'] = processed_df['Date'].apply(normalize_date)
        processed_df = processed_df.dropna(subset=['YearMonth', 'Item', 'Amount'])
        processed_df['Amount'] = pd.to_numeric(processed_df['Amount'], errors='coerce').fillna(0)
        processed_df = processed_df[processed_df['Amount'] > 0]

        # 按年月和項目分組，計算支出總和
        monthly_item_expense = processed_df.groupby(['YearMonth', 'Item'])['Amount'].sum().reset_index()

        # 計算每個月份總支出
        monthly_total = monthly_item_expense.groupby('YearMonth')['Amount'].sum().reset_index()
        monthly_total.rename(columns={'Amount': 'MonthlyTotal'}, inplace=True)

        # 合併並計算月份百分比
        merged = pd.merge(monthly_item_expense, monthly_total, on='YearMonth')
        merged['MonthlyPercent'] = (merged['Amount'] / merged['MonthlyTotal'] * 100).round(2)

        # 計算每個項目整體總和與百分比
        total_expense_by_item = monthly_item_expense.groupby('Item')['Amount'].sum().reset_index()
        total_expense = total_expense_by_item['Amount'].sum()
        total_expense_by_item['OverallPercent'] = (total_expense_by_item['Amount'] / total_expense * 100).round(2)

        return merged, total_expense_by_item, ""

    # --- 主要分析函數 ---
    def analyze_and_predict(file_paths_str: str, no_color: bool):
        colors = Colors(enabled=not no_color)
        file_paths = [path.strip() for path in file_paths_str.split(';')]

        monthly_data, item_summary, warnings_report = process_finance_data(file_paths, colors)

        if monthly_data is None:
            print(f"\n{colors.RED}資料處理失敗：{warnings_report}{colors.RESET}\n")
            return

        if warnings_report:
            print(f"\n{colors.YELLOW}--- 資料品質摘要 ---{colors.RESET}")
            print(warnings_report)
            print(f"{colors.YELLOW}--------------------{colors.RESET}")

        # 輸出報告
        print(f"\n{colors.CYAN}{colors.BOLD}========== 月份項目支出分析報告 =========={colors.RESET}")
        
        # 新增：計算並顯示總金額
        total_amount = monthly_data['Amount'].sum()
        print(f"\n{colors.BOLD}總金額: {colors.GREEN}{total_amount:,.2f}{colors.RESET}")
        
        print(f"\n{colors.BOLD}每月項目支出與百分比：{colors.RESET}")
        for ym in sorted(monthly_data['YearMonth'].unique()):
            ym_data = monthly_data[monthly_data['YearMonth'] == ym]
            print(f"{colors.YELLOW}- {ym} (總支出: {ym_data['MonthlyTotal'].iloc[0]:,.2f}){colors.RESET}")
            for _, row in ym_data.iterrows():
                print(f"  {row['Item']}: {row['Amount']:,.2f} ({row['MonthlyPercent']}%)")

        print(f"\n{colors.BOLD}整體項目摘要：{colors.RESET}")
        for _, row in item_summary.iterrows():
            print(f"- {row['Item']}: 總額 {row['Amount']:,.2f} ({row['OverallPercent']}%)")

        print(f"{colors.CYAN}{colors.BOLD}========================================{colors.RESET}\n")

    # --- 腳本入口 ---
    warnings.simplefilter("ignore")
    install_dependencies()
    
    parser = argparse.ArgumentParser(description="月份支出追蹤器")
    parser.add_argument('--no-color', action='store_true', help="禁用彩色輸出。")
    args = parser.parse_args()
    
    colors = Colors(enabled=not args.no_color)

    print(f"{colors.CYAN}====== {colors.BOLD}{SCRIPT_NAME} {SCRIPT_VERSION}{colors.RESET}{colors.CYAN} ======{colors.RESET}")
    print(f"{colors.WHITE}更新日期: {SCRIPT_UPDATE_DATE}{colors.RESET}")
    
    try:
        file_paths_str = input(f"\n{colors.YELLOW}請貼上一個或多個以分號(;)區隔的 CSV 檔案路徑: {colors.RESET}")
        if not file_paths_str.strip():
            print(f"\n{colors.RED}錯誤：未提供任何檔案路徑。腳本終止。{colors.RESET}")
            sys.exit(1)
        
        analyze_and_predict(file_paths_str, args.no_color)

    except KeyboardInterrupt:
        print(f"\n{colors.YELLOW}使用者中斷操作。腳本終止。{colors.RESET}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{colors.RED}腳本執行時發生未預期的錯誤: {e}{colors.RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()
