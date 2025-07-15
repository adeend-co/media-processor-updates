#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v1.6                #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。                        #
# 具備自動格式清理、互動式路徑輸入與多種模型預測、信賴區間等功能。                           #
# 新增：季節性分解與優化蒙地卡羅模擬（自舉法）。                                      #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v1.6.0"  # 更新版本：加入季節性分解與優化蒙地卡羅
SCRIPT_UPDATE_DATE = "2025-07-15"

import sys
import os
import subprocess
import warnings
from datetime import datetime
import pandas as pd
import argparse
import numpy as np
from scipy.stats import linregress, t

# --- 顏色處理類別 ---
class Colors:
    def __init__(self, enabled=True):
        if enabled and sys.stdout.isatty():
            self.RED = '\033[0;31m'; self.GREEN = '\033[0;32m'; self.YELLOW = '\033[1;33m'
            self.CYAN = '\033[0;36m'; self.PURPLE = '\033[0;35m'; self.WHITE = '\033[0;37m'
            self.BOLD = '\033[1m'; self.RESET = '\033[0m'
        else:
            self.RED = self.GREEN = self.YELLOW = self.CYAN = self.PURPLE = self.WHITE = self.BOLD = self.RESET = ''

colors = Colors(enabled=True)

# --- 內建台灣歷年通膨率 (CPI 年增率) 資料庫 ---
INFLATION_RATES = {
    2019: 0.56,
    2020: -0.25,
    2021: 2.10,
    2022: 2.95,
    2023: 2.49,
    2024: 2.18,
    2025: 1.88,
}

# --- 計算 CPI 指數的輔助函數 ---
def calculate_cpi_values(input_years, inflation_rates):
    if not input_years:
        return {}
    base_year = min(input_years)
    years = sorted(set(input_years) | set(inflation_rates.keys()))
    cpi_values = {}
    cpi_values[base_year] = 100.0
    for i in range(1, len(years)):
        prev_year = years[i-1]
        curr_year = years[i]
        rate = inflation_rates.get(curr_year, 0.0) / 100
        cpi_values[curr_year] = cpi_values[prev_year] * (1 + rate)
    return cpi_values, base_year

# --- 計算實質金額的輔助函數 ---
def adjust_to_real_amount(amount, data_year, target_year, cpi_values):
    if data_year not in cpi_values or target_year not in cpi_values:
        return amount
    return amount * (cpi_values[target_year] / cpi_values[data_year])

# --- 環境檢查函數 ---
def check_environment():
    print(f"{colors.CYAN}正在進行環境檢查...{colors.RESET}")
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

# --- 自動安裝依賴函數 ---
def install_dependencies():
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
                sys.exit(1)

def main():
    check_environment()
    install_dependencies()

    # --- 智慧欄位辨識 ---
    def find_column_by_synonyms(df_columns, synonyms):
        for col in df_columns:
            if str(col).strip().lower() in [s.lower() for s in synonyms]:
                return col
        return None

    # --- 日期標準化 ---
    def normalize_date(date_str):
        s = str(date_str).strip().replace('月', '').replace('年', '-').replace(' ', '')
        current_year = datetime.now().year
        if s.isdigit() and len(s) <= 2:
            month = int(s)
            return f"{current_year}-{month:02d}-01"
        if '-' in s:
            parts = s.split('-')
            year = int(parts[0]) if len(parts[0]) == 4 else current_year
            month = int(parts[1])
            return f"{year}-{month:02d}-01"
        if len(s) >= 5 and s[:4].isdigit():
            year = int(s[:4])
            month = int(s[4:])
            return f"{year}-{month:02d}-01"
        if s.isdigit() and len(s) == 8:
            try:
                dt = datetime.strptime(s, '%Y%m%d')
                return dt.strftime("%Y-%m-%d")
            except ValueError:
                pass
        return None

    # --- 資料處理函數 ---
    def process_finance_data(file_paths: list, colors: Colors):
        all_dfs = []
        encodings_to_try = ['utf-8', 'utf-8-sig', 'cp950', 'big5', 'gb18030']
        for file_path in file_paths:
            loaded = False
            for enc in encodings_to_try:
                try:
                    df = pd.read_csv(file_path.strip(), encoding=enc, on_bad_lines='skip')
                    all_dfs.append(df)
                    print(f"{colors.GREEN}成功使用編碼 '{enc}' 讀取檔案 '{file_path.strip()}'。{colors.RESET}")
                    loaded = True
                    break
                except UnicodeDecodeError:
                    print(f"{colors.YELLOW}嘗試編碼 '{enc}' 失敗，正在試下一個...{colors.RESET}")
                except FileNotFoundError:
                    print(f"{colors.RED}錯誤：找不到檔案 '{file_path.strip()}'！將跳過此檔案。{colors.RESET}")
                    break
            if not loaded:
                print(f"{colors.RED}錯誤：無法讀取檔案 '{file_path.strip()}'！所有編碼嘗試失敗。{colors.RESET}")
        
        if not all_dfs:
            return None, None, "沒有成功讀取任何資料檔案。"

        master_df = pd.concat(all_dfs, ignore_index=True)
        master_df.columns = master_df.columns.str.strip()

        date_col = find_column_by_synonyms(master_df.columns, ['日期', '時間', 'Date', 'time', '月份'])
        type_col = find_column_by_synonyms(master_df.columns, ['類型', 'Type', '收支項目', '收支'])
        amount_col = find_column_by_synonyms(master_df.columns, ['金額', 'Amount', 'amount', '價格'])
        income_col = find_column_by_synonyms(master_df.columns, ['收入', 'income'])
        expense_col = find_column_by_synonyms(master_df.columns, ['支出', 'expense'])
        
        warnings_report = []
        processed_df = None
        monthly_expenses = None
        is_wide_format_expense_only = False

        if date_col and income_col and expense_col:
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
            processed_df = master_df[[date_col, type_col, amount_col]].copy()
            processed_df.rename(columns={date_col: 'Date', type_col: 'Type', amount_col: 'Amount'}, inplace=True)

        elif date_col and len(master_df.columns) > 2:
            warnings_report.append(f"{colors.YELLOW}注意：偵測到寬格式（僅月份與項目），已假設全為支出並計算月總額。{colors.RESET}")
            is_wide_format_expense_only = True
            is_vertical_month = master_df[date_col].dropna().astype(str).str.contains('月|Month', na=False).any() or master_df[date_col].dropna().astype(str).str.isdigit().all()
            for col in master_df.columns:
                if col != date_col:
                    master_df[col] = master_df[col].astype(str).str.replace(',', '').str.strip()
                    master_df[col] = pd.to_numeric(master_df[col], errors='coerce').fillna(0)
            if is_vertical_month:
                master_df['MonthlyAmount'] = master_df.drop(columns=[date_col]).sum(axis=1)
                monthly_expenses = master_df[[date_col, 'MonthlyAmount']].copy()
                monthly_expenses.rename(columns={date_col: 'Parsed_Date', 'MonthlyAmount': 'Amount'}, inplace=True)
            else:
                monthly_amounts = master_df.drop(columns=[date_col]).sum(axis=0)
                monthly_expenses = pd.DataFrame({'Parsed_Date': master_df.columns[1:], 'Amount': monthly_amounts.values})
            monthly_expenses['Parsed_Date'] = monthly_expenses['Parsed_Date'].apply(normalize_date)
            monthly_expenses['Parsed_Date'] = pd.to_datetime(monthly_expenses['Parsed_Date'], errors='coerce')
            monthly_expenses = monthly_expenses.dropna(subset=['Parsed_Date'])
            monthly_expenses = monthly_expenses[monthly_expenses['Amount'] > 0]
            monthly_expenses.sort_values('Parsed_Date', inplace=True)
        
        else:
            missing = [c for c, v in zip(['日期/月份', '類型/金額 或 收入/支出'], [date_col, (type_col and amount_col) or (income_col and expense_col)]) if not v]
            return None, None, f"無法辨識的表格結構。缺少必要的欄位：{missing}"

        month_missing_count = 0
        if processed_df is not None:
            def parse_date(date_str):
                nonlocal month_missing_count
                if pd.isnull(date_str): return pd.NaT
                try:
                    return pd.to_datetime(str(date_str), errors='raise')
                except (ValueError, TypeError):
                    s_date = str(date_str).strip()
                    current_year = datetime.now().year
                    if ('-' in s_date or '/' in s_date or '月' in s_date) and str(current_year) not in s_date:
                        try:
                            month_missing_count += 1
                            return pd.to_datetime(f"{current_year}-{s_date.replace('月','-').replace('日','').replace('號','')}")
                        except ValueError: return pd.NaT
                    elif len(s_date) <= 4 and s_date.replace('.', '', 1).isdigit():
                         s_date = str(int(float(s_date)))
                         if len(s_date) < 3: s_date = '0' * (3-len(s_date)) + s_date
                         if len(s_date) > 2:
                            month_missing_count += 1
                            month = int(s_date[:-2])
                            day = int(s_date[-2:])
                            return pd.to_datetime(f"{current_year}-{month}-{day}", errors='coerce')
                    elif s_date.isdigit() and 1 <= int(s_date) <= 12:
                        month_missing_count += 1
                        return pd.to_datetime(f"{current_year}-{int(s_date)}-01", errors='coerce')
                    return pd.NaT

            processed_df['Parsed_Date'] = processed_df['Date'].apply(parse_date)
            processed_df.dropna(subset=['Parsed_Date'], inplace=True)
            
            unique_months = processed_df['Parsed_Date'].dt.to_period('M').nunique()
            
            if unique_months > 0:
                warnings_report.append(f"資料時間橫跨 {colors.BOLD}{unique_months}{colors.RESET} 個不同月份。")
            if month_missing_count > 0:
                warnings_report.append(f"{colors.YELLOW}警告：有 {colors.BOLD}{month_missing_count}{colors.RESET} 筆紀錄的日期缺少明確年份，已自動假定為今年。{colors.RESET}")

            if 'Parsed_Date' in processed_df.columns and 'Amount' in processed_df.columns:
                expense_df = processed_df[processed_df['Type'].str.lower() == 'expense']
                if not expense_df.empty:
                    monthly_expenses = expense_df.set_index('Parsed_Date').resample('M')['Amount'].sum().reset_index()
                    monthly_expenses['Amount'] = monthly_expenses['Amount'].fillna(0)

        # --- 通膨調整與年份偵測 (修正版) ---
        base_year = datetime.now().year  # 目標基期年
        year_range = set()
        year_cpi_used = {}
        if monthly_expenses is not None:
            monthly_expenses['Year'] = monthly_expenses['Parsed_Date'].dt.year
            year_range = set(monthly_expenses['Year'])
            if year_range:
                try:
                    cpi_values, cpi_base_year = calculate_cpi_values(year_range, INFLATION_RATES)
                    monthly_expenses['Real_Amount'] = 0.0
                    for idx, row in monthly_expenses.iterrows():
                        year = row['Year']
                        monthly_expenses.at[idx, 'Real_Amount'] = adjust_to_real_amount(row['Amount'], year, base_year, cpi_values)
                        year_cpi_used[year] = cpi_values.get(year, '無數據')

                    # CPI 基準告知
                    warnings_report.append(f"{colors.GREEN}CPI 基準年份：{cpi_base_year} 年（基於輸入數據最早年份，指數設為 100）。計算到目標年：{base_year} 年。{colors.RESET}")

                    # 年份偵測報告
                    min_year = min(year_range)
                    max_year = max(year_range)
                    cross_years = len(year_range) > 1
                    warnings_report.append(f"{colors.GREEN}偵測到年份範圍：{min_year} - {max_year} (是否有跨年份：{'是' if cross_years else '否'})。{colors.RESET}")
                    for y in sorted(year_range):
                        cpi_val = year_cpi_used[y]
                        warnings_report.append(f"  - 年份 {y} 使用 CPI：{cpi_val:.2f}" if isinstance(cpi_val, float) else f"  - 年份 {y} 使用 CPI：{cpi_val}")
                except Exception as e:
                    warnings_report.append(f"{colors.RED}通膨調整錯誤：{str(e)}。使用原始金額繼續分析。{colors.RESET}")

        return processed_df, monthly_expenses, "\n".join(warnings_report)

    # --- 季節性分解函數 ---
    def seasonal_decomposition(monthly_expenses):
        if len(monthly_expenses) < 24:
            return None, "數據不足 24 個月，无法进行季节性分解。"
        monthly_expenses['Month'] = monthly_expenses['Parsed_Date'].dt.month
        monthly_avg = monthly_expenses.groupby('Month')['Amount'].mean()
        overall_avg = monthly_expenses['Amount'].mean()
        seasonal_indices = monthly_avg / overall_avg
        deseasonalized = monthly_expenses.copy()
        deseasonalized['Deseasonalized_Amount'] = deseasonalized.apply(lambda row: row['Amount'] / seasonal_indices[row['Month']], axis=1)
        return deseasonalized, seasonal_indices

    # --- 優化蒙地卡羅模擬 (使用自舉法) ---
    def optimized_monte_carlo(monthly_expenses, predicted_value, num_simulations=10000):
        if len(monthly_expenses) < 24:
            return None, None, None, "數據不足 24 個月，无法进行优化蒙地卡罗模拟。"
        # 計算歷史殘差
        x = np.arange(1, len(monthly_expenses) + 1)
        slope, intercept, _, _, _ = linregress(x, monthly_expenses['Amount'])
        trend = intercept + slope * x
        residuals = monthly_expenses['Amount'] - trend
        # 自舉抽樣
        simulated = []
        for _ in range(num_simulations):
            sampled_residual = np.random.choice(residuals, size=1)[0]
            simulated.append(predicted_value + sampled_residual)
        p25, p75, p95 = np.percentile(simulated, [25, 75, 95])
        return p25, p75, p95

    # --- 主要分析與預測函數 ---
    def analyze_and_predict(file_paths_str: str, no_color: bool):
        colors = Colors(enabled=not no_color)
        file_paths = [path.strip() for path in file_paths_str.split(';')]

        master_df, monthly_expenses, warnings_report = process_finance_data(file_paths, colors)

        if master_df is None and monthly_expenses is None:
            print(f"\n{colors.RED}資料處理失敗：{warnings_report}{colors.RESET}\n")
            return
        if warnings_report:
            print(f"\n{colors.YELLOW}--- 資料品質摘要 ---{colors.RESET}")
            print(warnings_report)
            print(f"{colors.YELLOW}--------------------{colors.RESET}")

        # 計算總支出
        total_income = 0
        total_expense = 0
        total_real_expense = 0
        is_wide_format_expense_only = (master_df is None and monthly_expenses is not None)
        if master_df is not None:
            master_df['Amount'] = pd.to_numeric(master_df['Amount'], errors='coerce')
            master_df.dropna(subset=['Type', 'Amount'], inplace=True)
            income_df = master_df[master_df['Type'].str.lower() == 'income']
            expense_df = master_df[master_df['Type'].str.lower() == 'expense']
            total_income = income_df['Amount'].sum()
            total_expense = expense_df['Amount'].sum()
        elif monthly_expenses is not None:
            total_expense = monthly_expenses['Amount'].sum()
            total_real_expense = monthly_expenses['Real_Amount'].sum()

        net_balance = total_income - total_expense

        # --- 季節性分解 ---
        deseasonalized, seasonal_indices = seasonal_decomposition(monthly_expenses)
        if deseasonalized is None:
            warnings_report.append(f"{colors.YELLOW}{seasonal_indices}{colors.RESET}")
            data_for_prediction = monthly_expenses['Amount'].values if monthly_expenses is not None else []
        else:
            data_for_prediction = deseasonalized['Deseasonalized_Amount'].values

        # --- 四階段預測：根據數據量選擇方法 (基於去季節化數據) ---
        predicted_expense_str = "無法預測 (資料不足或錯誤)"
        ci_str = ""
        method_used = ""
        upper = None
        predicted_value = None
        if monthly_expenses is not None and len(monthly_expenses) >= 2:
            num_months = len(monthly_expenses)
            data = data_for_prediction  # 使用去季節化數據

            if num_months >= 24:  # ≥24 個月，使用簡化 SARIMA
                try:
                    x = np.arange(len(data))
                    slope, intercept, _, _, _ = linregress(x, data)
                    predicted_value = intercept + slope * (len(data) + 1)
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於簡化 SARIMA)"

                    # 基於標準誤差的信心區間
                    residuals = data - (intercept + slope * x)
                    se = np.std(residuals, ddof=1)
                    t_val = 1.96  # 95% 信心水準的近似 t 值
                    lower = predicted_value - t_val * se
                    upper = predicted_value + t_val * se
                    ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"
                except Exception as e:
                    predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
            elif num_months >= 12:  # 12–23 個月，使用多項式迴歸 (2階)
                try:
                    x = np.arange(1, num_months + 1)
                    degree = 2  # 固定2階避免過擬合
                    predicted_value, lower, upper = polynomial_regression_with_ci(x, data, degree, num_months + 1)
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於多項式迴歸)"
                    ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"
                except Exception as e:
                    predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
            elif num_months >= 6:  # 6–11 個月，使用線性迴歸
                try:
                    x = np.arange(1, num_months + 1)
                    slope, intercept, _, _, _ = linregress(x, data)
                    predicted_value = intercept + slope * (num_months + 1)
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於線性迴歸)"

                    # 基於t分佈的預測區間
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
            elif num_months >= 2:  # 2–5 個月，使用 EMA
                try:
                    ema = pd.Series(data).ewm(span=num_months, adjust=False).mean()
                    predicted_value = ema.iloc[-1]  # 最後一個 EMA 值作為預測
                    predicted_expense_str = f"{predicted_value:,.2f}"
                    method_used = " (基於 EMA)"

                    # EMA Bootstrap 信心區間
                    residuals = data - ema
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

            # 還原季節性（如果適用）
            if seasonal_indices is not None:
                next_month = (monthly_expenses['Parsed_Date'].dt.month.iloc[-1] % 12) + 1
                seasonal_factor = seasonal_indices.get(next_month, 1.0)
                predicted_value *= seasonal_factor
                lower *= seasonal_factor
                upper *= seasonal_factor
                predicted_expense_str = f"{predicted_value:,.2f}"
                ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心，已還原季節性)"

        # --- 歷史支出波動性分析 (基於實質金額) ---
        expense_std_dev = None
        if monthly_expenses is not None and len(monthly_expenses) >= 2:
            expense_values = monthly_expenses['Real_Amount']
            expense_std_dev = expense_values.std()
            expense_mean = expense_values.mean()
            
            volatility_report = ""
            if expense_mean > 0:
                expense_cv = (expense_std_dev / expense_mean) * 100
                if expense_cv < 20: level, color = "低波動 (高度穩定)", colors.GREEN
                elif 20 <= expense_cv < 45: level, color = "中度波動 (正常範圍)", colors.WHITE
                elif 45 <= expense_cv < 70: level, color = "高波動 (值得注意)", colors.YELLOW
                else: level, color = "極高波動 (警示訊號)", colors.RED
                volatility_report = f" ({expense_cv:.1f}%, {level})"

        # --- 優化蒙地卡羅模擬 (使用自舉法) ---
        p25 = None
        p75 = None
        p95 = None
        if monthly_expenses is not None and len(monthly_expenses) >= 2:
            p25, p75, p95, sim_message = optimized_monte_carlo(monthly_expenses, predicted_value)
            if sim_message:
                warnings_report.append(f"{colors.YELLOW}{sim_message}{colors.RESET}")
            else:
                p25, p75, p95 = monte_carlo_dashboard(monthly_expenses['Real_Amount'].values)  # 回退基本模式

        # --- 新增：風險狀態與預算建議 (基於實質金額) ---
        risk_status, risk_description, suggested_budget, prudence_factor = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses)

        # --- 輸出最終的簡潔報告 ---
        print(f"\n{colors.CYAN}{colors.BOLD}========== 財務分析與預測報告 =========={colors.RESET}")
        
        # 處理非寬格式（有收入/支出的情況）
        if not is_wide_format_expense_only:
            print(f"{colors.BOLD}總收入: {colors.GREEN}{total_income:,.2f}{colors.RESET}")
        
        # 顯示總支出（名目與實質）
        print(f"{colors.BOLD}總支出 (名目): {colors.RED}{total_expense:,.2f}{colors.RESET}")
        if total_real_expense > 0:
            print(f"{colors.BOLD}總支出 (實質，經通膨調整): {colors.RED}{total_real_expense:,.2f}{colors.RESET}")
        
        # 顯示歷史波動
        if expense_std_dev is not None:
            print(f"{colors.BOLD}歷史月均支出波動 (基於實質金額): {color}{expense_std_dev:,.2f}{volatility_report}{colors.RESET}")
        
        # 處理淨餘額
        if not is_wide_format_expense_only:
            print("------------------------------------------")
            balance_color = colors.GREEN if net_balance >= 0 else colors.RED
            print(f"{colors.BOLD}淨餘額: {balance_color}{colors.BOLD}{net_balance:,.2f}{colors.RESET}")
        
        # 顯示傳統預測結果 (基於實質金額)
        print(f"\n{colors.PURPLE}{colors.BOLD}>>> 下個月趨勢預測 (基於實質金額): {predicted_expense_str}{ci_str}{method_used}{colors.RESET}")

        # 顯示蒙地卡羅儀表板
        if p25 is not None:
            print(f"\n{colors.CYAN}{colors.BOLD}>>> 個人財務風險儀表板 (基於 10,000 次模擬){colors.RESET}")
            print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")
            print(f"{colors.GREEN}  [安全區] {p25:,.0f} ~ {p75:,.0f} 元 (50% 機率){colors.RESET}")
            print(f"{colors.WHITE}    └ 這是您最可能的核心開銷範圍，可作為常規預算。{colors.RESET}")
            
            print(f"{colors.YELLOW}  [警戒區] {p75:,.0f} ~ {p95:,.0f} 元 (20% 機率){colors.RESET}")
            print(f"{colors.WHITE}    └ 發生計畫外消費，提醒您需開始注意非必要支出。{colors.RESET}")

            print(f"{colors.RED}  [風險區] > {p95:,.0f} 元 (5% 機率){colors.RESET}")
            print(f"{colors.WHITE}    └ 發生極端高額事件，此數值可作為緊急預備金的參考。{colors.RESET}")
            print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")

        # 新增：綜合預算建議區塊
        if risk_status != "無法判讀 (資料不足)":
            print(f"\n{colors.CYAN}{colors.BOLD}>>> 綜合預算建議{colors.RESET}")
            print(f"{colors.BOLD}風險狀態: {risk_status}{colors.RESET}")
            print(f"{colors.WHITE}{risk_description}{colors.RESET}")
            print(f"{colors.BOLD}建議下個月預算: {suggested_budget:,.2f} 元{colors.RESET}")
            print(f"{colors.WHITE}    └ 計算依據：趨勢預測中心值 ({predicted_value:,.2f}) + 審慎緩衝區 ({prudence_factor} * {expense_std_dev:,.2f}){colors.RESET}")

        # 通膨調整說明
        print(f"\n{colors.WHITE}【註】關於「實質金額」：為了讓不同年份的支出能被公平比較，本報告已將所有歷史數據，統一換算為當前基期年的貨幣價值。這能幫助您在扣除物價上漲的影響後，看清自己真實的消費習慣變化。{colors.RESET}")
        
        print(f"{colors.CYAN}{colors.BOLD}========================================{colors.RESET}\n")

    # --- 腳本入口 ---
    warnings.simplefilter("ignore")
    
    parser = argparse.ArgumentParser(description="進階財務分析與預測器")
    parser.add_argument('--no-color', action='store_true', help="禁用彩色輸出。")
    args = parser.parse_args()
    
    colors = Colors(enabled=not args.no_color)

    # --- 顯示腳本標題與版本資訊 ---
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
