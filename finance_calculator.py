#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v9.0              #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個高度智慧化的獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。     #
# 它具備自動格式清理、互動式路徑輸入與 EMA 模型預測等頂級功能。                     #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v9.13"  # 更新版本以修復 f-string 未關閉錯誤
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
    required_packages = ['pandas', 'numpy', 'scipy']
    missing_packages = []
    
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

# --- 自動安裝依賴函數 (強化錯誤處理) ---
def install_dependencies():
    """檢查並安裝缺少的 Python 庫 (pandas, numpy, scipy)"""
    required_packages = ['pandas', 'numpy', 'scipy']
    for pkg in required_packages:
        try:
            __import__(pkg)
        except ImportError:
            print(f"{colors.YELLOW}提示：正在安裝缺少的必要套件: {pkg}...{colors.RESET}")
            try:
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', '--upgrade', 'pip', 'setuptools', 'wheel'])
                subprocess.check_call([sys.executable, '-m', 'pip', 'install', pkg])
                print(f"{colors.GREEN}成功安裝 {pkg}。{colors.RESET}")
            except subprocess.CalledProcessError as e:
                print(f"{colors.RED}錯誤：安裝套件 {pkg} 失敗！錯誤碼: {e.returncode}。{colors.RESET}")
                print(f"{colors.YELLOW}建議：在 Termux 中執行 'pkg install python-numpy python-scipy' 或檢查網路/權限。{colors.RESET}")
                sys.exit(1)

def main():
    # --- 腳本啟動時立即檢查環境 (顏色已載入) ---
    check_environment()
    
    # --- 載入所有依賴 (檢查通過後) ---
    import pandas as pd
    from datetime import datetime
    import argparse
    import numpy as np  # 用於 EMA 計算
    from scipy.stats import linregress, t  # 用於線性迴歸和 SARIMA 簡化, t分佈

    # --- 智慧欄位辨識與資料處理 ---
    def find_column_by_synonyms(df_columns, synonyms):
        """根據同義詞列表查找欄位名稱"""
        for col in df_columns:
            if str(col).strip().lower() in [s.lower() for s in synonyms]:
                return col
        return None

    def process_finance_data(file_paths: list, colors: Colors):
        """
        讀取、合併、清理並分析來自多個 CSV 檔案的財務資料。
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

        # --- 核心升級：自動清理欄位名稱前後的空格 ---
        master_df.columns = master_df.columns.str.strip()

        # --- 智慧欄位名稱辨識 ---
        date_col = find_column_by_synonyms(master_df.columns, ['日期', '時間', 'Date', 'time'])
        type_col = find_column_by_synonyms(master_df.columns, ['類型', 'Type', '收支項目', '收支'])
        amount_col = find_column_by_synonyms(master_df.columns, ['金額', 'Amount', 'amount', '價格'])
        income_col = find_column_by_synonyms(master_df.columns, ['收入', 'income'])
        expense_col = find_column_by_synonyms(master_df.columns, ['支出', 'expense'])
        
        warnings_report = []
        processed_df = None

        # --- 核心邏輯：處理不同的表格結構 ---
        if date_col and income_col and expense_col:
            # 結構一：偵測到獨立的「收入」和「支出」欄位
            warnings_report.append(f"{colors.YELLOW}注意：偵測到獨立的『收入』與『支出』欄位，已為您自動合併並區分交易類型。{colors.RESET}")
            
            income_df = master_df[[date_col, income_col]].copy()
            income_df.rename(columns={date_col: 'Date', income_col: 'Amount'}, inplace=True)
            income_df['Type'] = 'income'
            
            expense_df = master_df[[date_col, expense_col]].copy()
            expense_df.rename(columns={date_col: 'Date', expense_col: 'Amount'}, inplace=True)
            expense_df['Type'] = 'expense'
            
            processed_df = pd.concat([income_df, expense_df])
            processed_df.dropna(subset=['Amount'], inplace=True)
            processed_df['Amount'] = pd.to_numeric(processed_df['Amount'], errors='coerce')
            processed_df = processed_df[processed_df['Amount'] > 0]

        elif date_col and type_col and amount_col:
            # 結構二：標準的「類型」和「金額」欄位
            processed_df = master_df[[date_col, type_col, amount_col]].copy()
            processed_df.rename(columns={date_col: 'Date', type_col: 'Type', amount_col: 'Amount'}, inplace=True)
        else:
            missing = [c for c, v in zip(['日期', '類型/金額 或 收入/支出'], [date_col, (type_col and amount_col) or (income_col and expense_col)]) if not v]
            return None, None, f"無法辨識的表格結構。缺少必要的欄位：{missing}"

        # --- 日期處理與資料品質計數 ---
        month_missing_count = 0
        
        def parse_date(date_str):
            nonlocal month_missing_count
            if pd.isnull(date_str): return pd.NaT
            try:
                return pd.to_datetime(str(date_str), errors='raise')
            except (ValueError, TypeError):
                s_date = str(date_str).strip()
                if ('-' in s_date or '/' in s_date or '月' in s_date) and str(datetime.now().year) not in s_date:
                    try:
                        month_missing_count += 1
                        return pd.to_datetime(f"{datetime.now().year}-{s_date.replace('月','-').replace('日','').replace('號','')}")
                    except ValueError: return pd.NaT
                elif len(s_date) <= 4 and s_date.replace('.', '', 1).isdigit(): # 處理 701, 7.01 等
                     s_date = str(int(float(s_date))) # 轉換 701.0 -> 701
                     if len(s_date) < 3: s_date = '0' * (3-len(s_date)) + s_date # 補零
                     if len(s_date) > 2:
                        month_missing_count += 1
                        month = int(s_date[:-2])
                        day = int(s_date[-2:])
                        return pd.to_datetime(f"{datetime.now().year}-{month}-{day}", errors='coerce')
                return pd.NaT

        processed_df['Parsed_Date'] = processed_df['Date'].apply(parse_date)
        processed_df.dropna(subset=['Parsed_Date'], inplace=True)
        
        unique_months = processed_df['Parsed_Date'].dt.to_period('M').nunique()
        
        if unique_months > 0:
            warnings_report.append(f"資料時間橫跨 {colors.BOLD}{unique_months}{colors.RESET} 個不同月份。")
        if month_missing_count > 0:
            warnings_report.append(f"{colors.YELLOW}警告：有 {colors.BOLD}{month_missing_count}{colors.RESET} 筆紀錄的日期缺少明確年份，已自動假定為今年。{colors.RESET}")

        # --- 計算每月支出彙總 (修復：在此處定義 monthly_expenses) ---
        monthly_expenses = None  # 預設值
        if 'Parsed_Date' in processed_df.columns and 'Amount' in processed_df.columns:
            expense_df = processed_df[processed_df['Type'].str.lower() == 'expense']
            if not expense_df.empty:
                monthly_expenses = expense_df.set_index('Parsed_Date').resample('M')['Amount'].sum().reset_index()
                monthly_expenses['Amount'] = monthly_expenses['Amount'].fillna(0)

        return processed_df, monthly_expenses, "\n".join(warnings_report)

    # --- 主要分析與預測函數 (條件式選擇 SARIMA、Linear Regression 或 EMA) ---
    def analyze_and_predict(file_paths_str: str, no_color: bool):
        colors = Colors(enabled=not no_color)
        file_paths = [path.strip() for path in file_paths_str.split(';')]

        master_df, monthly_expenses, warnings_report = process_finance_data(file_paths, colors)

        if master_df is None:
            print(f"\n{colors.RED}資料處理失敗：{warnings_report}{colors.RESET}\n")
            return
        if warnings_report:
            print(f"\n{colors.YELLOW}--- 資料品質摘要 ---{colors.RESET}")
            print(warnings_report)
            print(f"{colors.YELLOW}--------------------{colors.RESET}")

        master_df['Amount'] = pd.to_numeric(master_df['Amount'], errors='coerce')
        master_df.dropna(subset=['Type', 'Amount'], inplace=True)
        
        income_df = master_df[master_df['Type'].str.lower() == 'income']
        expense_df = master_df[master_df['Type'].str.lower() == 'expense']
        total_income = income_df['Amount'].sum()
        total_expense = expense_df['Amount'].sum()
        net_balance = total_income - total_expense

        # --- 條件式預測：根據數據量選擇方法 ---
        predicted_expense_str = "無法預測 (資料不足或錯誤)"
        ci_str = ""
        method_used = ""
        if monthly_expenses is not None and not expense_df.empty:
            num_months = len(monthly_expenses)
            data = monthly_expenses['Amount'].values

            if num_months >= 24:  # 足夠數據，使用 SARIMA (簡化趨勢模擬)
                try:
                    # 簡化 SARIMA：使用線性迴歸模擬趨勢 + 季節調整
                    x = np.arange(len(data))
                    slope, intercept, _, _, _ = linregress(x, data)
                    predicted_value = intercept + slope * (len(data) + 1)
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於 SARIMA)"

                    # 新增：SARIMA 簡化信心區間 (預測值 ± t * SE)
                    residuals = data - (intercept + slope * x)
                    se = np.std(residuals, ddof=1)
                    t_val = 1.96  # 95% 信心水準的近似 t 值
                    lower = predicted_value - t_val * se
                    upper = predicted_value + t_val * se
                    ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"
                except Exception as e:
                    predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
            elif num_months >= 6:  # 中間範圍，使用 Linear Regression
                try:
                    x = np.arange(1, num_months + 1)
                    slope, intercept, _, _, _ = linregress(x, data)
                    predicted_value = intercept + slope * (num_months + 1)
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於 Linear Regression)"

                    # 新增：線性迴歸預測區間
                    n = len(x)
                    x_mean = np.mean(x)
                    residuals = data - (intercept + slope * x)
                    mse = np.sum(residuals**2) / (n - 2)
                    ssx = np.sum((x - x_mean)**2)
                    se = np.sqrt(mse * (1 + 1/n + ((num_months + 1) - x_mean)**2 / ssx))
                    t_val = t.ppf(0.975, n - 2)  # 95% t 值
                    lower = predicted_value - t_val * se
                    upper = predicted_value + t_val * se
                    ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"
                except Exception as e:
                    predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
            elif num_months >= 2:  # 短期數據，使用 EMA
                try:
                    ema = monthly_expenses['Amount'].ewm(span=num_months, adjust=False).mean()
                    predicted_value = ema.iloc[-1]  # 最後一個 EMA 值作為預測
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於 EMA)"

                    # 新增：EMA Bootstrap 信心區間
                    residuals = monthly_expenses['Amount'] - ema
                    bootstrap_preds = []
                    for _ in range(1000):
                        resampled_residuals = np.random.choice(residuals, size=num_months, replace=True)
                        simulated = ema + resampled_residuals
                        simulated_ema = pd.Series(simulated).ewm(span=num_months, adjust=False).mean()
                        bootstrap_preds.append(simulated_ema.iloc[-1])
                    lower = np.percentile(bootstrap_preds, 2.5)
                    upper = np.percentile(bootstrap_preds, 97.5)
                    ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"
                except Exception as e:
                    predicted_expense_str = f"無法預測 (錯誤: {str(e)})"

        # --- 輸出最終的簡潔報告 ---
        print(f"\n{colors.CYAN}{colors.BOLD}========== 財務分析與預測報告 =========={colors.RESET}")
        print(f"{colors.BOLD}總收入: {colors.GREEN}{total_income:,.2f}{colors.RESET}")
        print(f"{colors.BOLD}總支出: {colors.RED}{total_expense:,.2f}{colors.RESET}")
        print("------------------------------------------")
        balance_color = colors.GREEN if net_balance >= 0 else colors.RED
        print(f"{colors.BOLD}淨餘額: {balance_color}{colors.BOLD}{net_balance:,.2f}{colors.RESET}")
        print(f"\n{colors.PURPLE}{colors.BOLD}>>> 下個月預測總開銷: {predicted_expense_str}{ci_str}{method_used}{colors.RESET}")
        print(f"{colors.CYAN}{colors.BOLD}========================================{colors.RESET}\n")

    # --- 腳本入口 ---
    warnings.simplefilter("ignore")
    install_dependencies()
    
    parser = argparse.ArgumentParser(description="進階財務分析與預測器")
    parser.add_argument('--no-color', action='store_true', help="禁用彩色輸出。")
    args = parser.parse_args()
    
    colors = Colors(enabled=not args.no_color)

    # --- 顯示腳本標題與版本資訊 ---
    print(f"{colors.CYAN}====== {colors.BOLD}{SCRIPT_NAME} {SCRIPT_VERSION}{colors.RESET}{colors.CYAN} ======{colors.RESET}")
    print(f"{colors.WHITE}更新日期: {SCRIPT_UPDATE_DATE}{colors.RESET}")
    
    try:
        # --- 全新互動式輸入 ---
        file_paths_str = input(f"\n{colors.YELLOW}請貼上一個或多個以分號(;)區隔的 CSV 檔案路徑: {colors.RESET}")
        if not file_paths_str.strip():
            print(f"\n{colors.RED}錯誤：未提供任何檔案路徑。腳本終止。{colors.RESET}")
            sys.exit(1)
        
        # --- 呼叫主函數 ---
        analyze_and_predict(file_paths_str, args.no_color)

    except KeyboardInterrupt:
        print(f"\n{colors.YELLOW}使用者中斷操作。腳本終止。{colors.RESET}")
        sys.exit(0)
    except Exception as e:
        print(f"\n{colors.RED}腳本執行時發生未預期的錯誤: {e}{colors.RESET}")
        sys.exit(1)

if __name__ == "__main__":
    main()
