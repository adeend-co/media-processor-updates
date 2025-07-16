#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v1.8.15              #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。                        #
# 具備自動格式清理、互動式路徑輸入與多種模型預測、信賴區間等功能。                           #
# 更新：新增自動檢測月份數，條件應用季節性分解與優化蒙地卡羅模擬，並告知使用者。           #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v1.8.15"  # 更新版本：自動檢測與條件應用
SCRIPT_UPDATE_DATE = "2025-07-16"

import sys
import os
import subprocess
import warnings
from datetime import datetime
import pandas as pd
import argparse
import numpy as np
from scipy.stats import linregress, t
from scipy.stats import skew, kurtosis

# --- 顏色處理類別 ---
class Colors:
    def __init__(self, enabled=True):
        if enabled and sys.stdout.isatty():
            self.RED = '\033[0;31m'; self.GREEN = '\033[0;32m'; self.YELLOW = '\033[1;33m'
            self.CYAN = '\033[0;36m'; self.PURPLE = '\033[0;35m'; self.WHITE = '\033[0;37m'
            self.BOLD = '\033[1m'; self.RESET = '\033[0m'
        else:
            self.RED = self.GREEN = self.YELLOW = self.CYAN = self.PURPLE = self.WHITE = self.BOLD = self.RESET = ''

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

# --- 計算 CPI 指數的輔助函數 (強化版，修正 2019 年問題) ---
def calculate_cpi_values(input_years, inflation_rates):
    if not input_years:
        return {}
    base_year = min(input_years)  # 以輸入數據最早年份作為基準
    years = sorted(set(input_years) | set(inflation_rates.keys()))
    cpi_values = {}
    cpi_values[base_year] = 100.0
    # 向後計算
    for y in range(base_year + 1, max(years) + 1):
        prev_cpi = cpi_values.get(y - 1, 100.0)
        rate = inflation_rates.get(y, 0.0) / 100
        cpi_values[y] = prev_cpi * (1 + rate)
    # 向前計算（如果有更早年份）
    for y in range(base_year - 1, min(years) - 1, -1):
        next_cpi = cpi_values.get(y + 1, 100.0)
        rate = inflation_rates.get(y + 1, 0.0) / 100
        if rate != -1:  # 避免除零
            cpi_values[y] = next_cpi / (1 + rate)
        else:
            cpi_values[y] = next_cpi
    return cpi_values, base_year

# --- 計算實質金額的輔助函數 (強化版) ---
def adjust_to_real_amount(amount, data_year, target_year, cpi_values):
    if data_year not in cpi_values or target_year not in cpi_values:
        return amount  # 無數據時返回原始金額
    return amount * (cpi_values[target_year] / cpi_values[data_year])

# --- 環境檢查函數 ---
def check_environment(colors):
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
def install_dependencies(colors):
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

# --- 資料處理函數 (修正版) ---
def process_finance_data(file_paths, colors):
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
                monthly_expenses['Real_Amount'] = monthly_expenses['Amount']  # 確保 Real_Amount 存在

    return processed_df, monthly_expenses, "\n".join(warnings_report)

# --- 季節性分解函數 (整合說明中的方法) ---
def seasonal_decomposition(monthly_expenses):
    # 計算季節性指數
    monthly_expenses['Month'] = monthly_expenses['Parsed_Date'].dt.month
    monthly_avg = monthly_expenses.groupby('Month')['Real_Amount'].mean()
    overall_avg = monthly_expenses['Real_Amount'].mean()
    seasonal_indices = monthly_avg / overall_avg
    
    # 去季節化
    deseasonalized = monthly_expenses.copy()
    deseasonalized['Deseasonalized'] = deseasonalized['Real_Amount'] / deseasonalized['Month'].map(seasonal_indices)
    
    return deseasonalized, seasonal_indices

# --- 優化蒙地卡羅模擬（自舉法，整合說明中的方法） ---
def optimized_monte_carlo(monthly_expenses, predicted_value, num_simulations=10000):
    # 計算歷史殘差（使用線性迴歸擬合趨勢）
    x = np.arange(len(monthly_expenses))
    slope, intercept, _, _, _ = linregress(x, monthly_expenses['Real_Amount'])
    trend = intercept + slope * x
    residuals = monthly_expenses['Real_Amount'] - trend
    
    # 自舉模擬
    simulated = []
    for _ in range(num_simulations):
        sampled_residual = np.random.choice(residuals, size=1)[0]
        sim_value = predicted_value + sampled_residual
        simulated.append(sim_value)
    
    # 計算百分位
    p25, p75, p95 = np.percentile(simulated, [25, 75, 95])
    return p25, p75, p95

# --- 多項式迴歸與信賴區間計算函數 ---
def polynomial_regression_with_ci(x, y, degree, predict_x, confidence=0.95):
    coeffs = np.polyfit(x, y, degree)
    p = np.poly1d(coeffs)
    y_pred = p(x)
    n = len(x)
    k = degree
    residuals = y - y_pred
    mse = np.sum(residuals**2) / (n - k - 1)
    y_pred_p = p(predict_x)
    x_mean = np.mean(x)
    ssx = np.sum((x - x_mean)**2)
    se = np.sqrt(mse * (1 + 1/n + ((predict_x - x_mean)**2) / ssx))
    t_val = t.ppf((1 + confidence) / 2, n - k - 1)
    lower = y_pred_p - t_val * se
    upper = y_pred_p + t_val * se
    return y_pred_p, lower, upper

# --- 蒙地卡羅儀表板函式 (修正版) ---
def monte_carlo_dashboard(monthly_expense_data, num_simulations=10000):
    """
    執行蒙地卡羅模擬，並計算風險儀表板所需的百分位數。
    """
    if len(monthly_expense_data) < 2:
        return None, None, None

    # 直接基於歷史「月總額」的平均與標準差進行模擬
    mean_expense = np.mean(monthly_expense_data)
    std_expense = np.std(monthly_expense_data)

    # 避免標準差為零或過小導致的錯誤
    if std_expense == 0:
        std_expense = mean_expense * 0.1  # 假設 10% 的波動

    # 產生一萬次下個月總開銷的模擬結果
    simulated_monthly_totals = np.random.normal(mean_expense, std_expense, num_simulations)

    # 計算儀表板所需的百分位數 (25%, 75%, 95%)
    p25, p75, p95 = np.percentile(simulated_monthly_totals, [25, 75, 95])

    return p25, p75, p95

# --- 風險狀態判讀與預算建議函數 (升級版，基於實質金額) ---
def assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse):
    """
    根據多因子框架判讀風險狀態，並計算結合風險與模型誤差的動態預算建議。
    - 數據 < 12 個月：回歸使用較基礎、穩健的公式。
    - 數據 ≥ 12 個月：啟用基於風險儀表板與模型表現的進階預算公式。
    """
    num_months = len(monthly_expenses) if monthly_expenses is not None else 0
    num_unique_months = monthly_expenses['Parsed_Date'].dt.to_period('M').nunique() if monthly_expenses is not None else 0

    # --- 數據嚴重不足 (< 6 個月) 的處理 ---
    if num_months < 6:
        if num_months < 2:
            return "無法判讀 (資料不足2個月)", "資料過少，無法進行風險評估。", None, None, None, None, "極低可靠性", None, None, None
        
        # 使用近期平均 + 固定緩衝
        recent_months = min(3, num_months)
        recent_avg = np.mean(monthly_expenses['Real_Amount'].values[-recent_months:])
        buffer_factor = 0.15
        suggested_budget = recent_avg * (1 + buffer_factor)
        status = "數據不足，使用替代公式"
        description = "基於近期平均實質支出加上15%風險緩衝。"
        return status, description, suggested_budget, buffer_factor, None, None, "低度可靠 - 使用替代公式", None, None, None

    # --- 關鍵數據缺失的處理 ---
    if p95 is None or expense_std_dev is None or predicted_value is None or upper is None or p75 is None:
        return "無法判讀 (資料不足)", "關鍵模擬數據缺失，無法進行風險評估。", None, None, None, None, "無法判讀", None, None, None

    # --- 多因子計分系統 ---
    # 1. 計算殘差以分析偏態與峰態
    x = np.arange(num_months)
    slope, intercept, _, _, _ = linregress(x, monthly_expenses['Real_Amount'].values)
    residuals = monthly_expenses['Real_Amount'].values - (intercept + slope * x)
    res_skew = skew(residuals)
    res_kurt = kurtosis(residuals)
    
    # 2. 分析波動性趨勢
    half_point = num_months // 2
    mean_early = np.mean(monthly_expenses['Real_Amount'].values[:half_point])
    mean_late = np.mean(monthly_expenses['Real_Amount'].values[half_point:])
    early_cv = (np.std(monthly_expenses['Real_Amount'].values[:half_point]) / mean_early) if mean_early != 0 else 0
    late_cv = (np.std(monthly_expenses['Real_Amount'].values[half_point:]) / mean_late) if mean_late != 0 else 0
    cv_increase = late_cv > early_cv * 1.2

    # 3. 計算趨勢與衝擊風險得分
    trend_score, shock_score = 0, 0
    if upper > p95 * 1.075: trend_score += 2
    elif p95 > upper: shock_score += 2
    if res_skew > 1: shock_score += 1
    if cv_increase: trend_score += 1
    if res_kurt > 3: shock_score += 1

    # --- 風險狀態與描述 ---
    if trend_score > shock_score + 1:
        status, description = "風險顯著升溫", "支出趨勢顯著加速，您的潛在風險可能已超越歷史經驗，需要高度警惕。"
    elif shock_score > trend_score + 1:
        status, description = "偶發衝擊主導", "您的主要風險並非來自支出趨勢增長，而是偶發性的大額開銷，建議確保預備金充足。"
    else:
        status, description = "趨勢與衝擊混合", "您的財務狀況同時面臨增長趨勢與偶發事件的影響，建議平衡預算規劃與緊急預備金。"

    # --- 動態風險係數矩陣 (應對未來不確定性) ---
    risk_matrix = {'low': {'low': 0.30, 'medium': 0.50, 'high': 0.75}, 'medium': {'low': 0.50, 'medium': 0.75, 'high': 1.00}, 'high': {'low': 0.75, 'medium': 1.00, 'high': 1.25}}
    trend_level = 'low' if trend_score <= 1 else ('medium' if trend_score == 2 else 'high')
    shock_level = 'low' if shock_score <= 1 else ('medium' if shock_score <= 3 else 'high')
    risk_coefficient = risk_matrix[trend_level][shock_level]

    # --- 模型誤差係數 (彌補過去模型準確度) ---
    error_coefficient = 0.5 # 預設值
    if historical_wape is not None:
        if historical_wape < 10: error_coefficient = 0.25
        elif historical_wape <= 25: error_coefficient = 0.50
        else: error_coefficient = 0.75

    # --- 最終預算計算 (根據數據長度決定公式) ---
    error_buffer = None
    prudence_factor = None
    if num_unique_months >= 12:
        data_reliability = "高度可靠" if num_unique_months >= 24 else "中度可靠"
        # 數據越可靠，可適度調降誤差係數以減少過度保守
        if num_unique_months >= 24:
            error_coefficient = max(0.1, error_coefficient - 0.15)
        
        # 進階公式 = 風險緩衝 + 模型誤差緩衝
        risk_buffer = p75 + (risk_coefficient * (p95 - p75))
        error_buffer = error_coefficient * historical_rmse if historical_rmse is not None else 0
        suggested_budget = risk_buffer + error_buffer
    else: # 數據不足12個月，回歸原始公式
        data_reliability = "低度可靠 - 使用原始公式"
        prudence_factor = 0.5 # 設定一個固定的審慎係數
        suggested_budget = predicted_value + (prudence_factor * expense_std_dev)
        risk_coefficient, error_coefficient = None, None # 這些係數不適用於原始公式

    return status, description, suggested_budget, prudence_factor, trend_score, shock_score, data_reliability, risk_coefficient, error_coefficient, error_buffer

# --- 主要分析與預測函數 (升級為四階段模型 + 蒙地卡羅 + 風險預算建議 + 通膨調整) ---
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

    # --- 自動檢測月份數 ---
    num_unique_months = 0
    if monthly_expenses is not None:
        num_unique_months = monthly_expenses['Parsed_Date'].dt.to_period('M').nunique()

    # --- 季節性分解整合 (條件應用) ---
    used_seasonal = False
    seasonal_note = "未使用季節性分解（資料月份不足 24 個月）。"
    if monthly_expenses is not None and num_unique_months >= 24:
        deseasonalized, seasonal_indices = seasonal_decomposition(monthly_expenses)
        # 使用去季節化數據進行後續分析
        analysis_data = deseasonalized['Deseasonalized'].values
        used_seasonal = True
        seasonal_note = "已使用季節性分解（資料月份足夠）。"
    else:
        analysis_data = monthly_expenses['Real_Amount'].values if monthly_expenses is not None else None

    # 計算總支出（如果有processed_df）
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
        total_expense = monthly_expenses['Amount'].sum()  # 名目總額
        total_real_expense = monthly_expenses['Real_Amount'].sum()  # 實質總額

    net_balance = total_income - total_expense

    # --- 取得目前時間的下一個月（目標預測月份） ---
    from datetime import datetime
    now = datetime.now()
    current_year = now.year
    current_month = now.month
    if current_month == 12:
        target_month = 1
        target_year = current_year + 1
    else:
        target_month = current_month + 1
        target_year = current_year
    target_month_str = f"{target_year}-{target_month:02d}"

    # --- 計算從資料最後月份到目標月份的步數 ---
    steps_ahead = 1  # 預設為下一步
    step_warning = ""
    if monthly_expenses is not None and not monthly_expenses.empty:
        last_date = monthly_expenses['Parsed_Date'].max()
        last_period = last_date.to_period('M')
        target_period = pd.Period(target_month_str, freq='M')
        steps_ahead = (target_period - last_period).n + 1  # +1 因為是預測下一步
        if steps_ahead <= 0:
            warnings_report += f"\n{colors.YELLOW}警告：目標月份 {target_month_str} 已過期或已在資料中，預測可能不準確。{colors.RESET}"
            steps_ahead = 1  # 強制預測下一步
        if steps_ahead > 12:
            step_warning = f"{colors.YELLOW}警告：預測步數超過12 ({steps_ahead})，遠期預測不確定性增加，但計算繼續進行。{colors.RESET}"

    # --- 四階段預測：根據數據量選擇方法 (基於實質金額，調整為直接-遞歸混合多步預測) ---
    predicted_expense_str = "無法預測 (資料不足或錯誤)"
    ci_str = ""
    method_used = " (基於直接-遞歸混合)"
    upper = None  # 用於風險判讀
    predicted_value = None
    historical_mae = None
    historical_rmse = None
    historical_wape = None
    historical_mase = None
    if monthly_expenses is not None and len(monthly_expenses) >= 2:
        num_months = len(monthly_expenses)
        data = analysis_data  # 使用去季節化或原始數據

        if num_months >= 24:  # ≥24 個月，使用簡化 SARIMA 作為基底，應用直接-遞歸混合
            try:
                x = np.arange(len(data))
                slope, intercept, _, _, _ = linregress(x, data)
                # 遞歸部分：初始化預測
                predictions = []
                prev_pred = data[-1]  # 最後觀測值作為起點
                for step in range(1, steps_ahead + 1):
                    # 直接部分：為每個步驟計算獨立預測，納入先前預測
                    current_x = len(data) + step - 1
                    pred = intercept + slope * current_x + (0.5 * (prev_pred - data[-1]))  # 混合調整
                    predictions.append(pred)
                    prev_pred = pred
                predicted_value = predictions[-1]  # 最後一步作為中心值
                predicted_expense_str = f"{predicted_value:,.2f}"

                # 基於標準誤差的信心區間（簡化多步，強制下限為0）
                residuals = data - (intercept + slope * x)
                se = np.std(residuals, ddof=1) * np.sqrt(steps_ahead)  # 粗略調整多步不確定性
                t_val = 1.96  # 95% 信心水準的近似 t 值
                lower = max(0, predicted_value - t_val * se)  # 避免負值
                upper = predicted_value + t_val * se
                ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"

                # 新增：計算歷史指標（使用線性迴歸回測）
                historical_pred = intercept + slope * x
                historical_mae = np.mean(np.abs(data - historical_pred))
                historical_rmse = np.sqrt(np.mean((data - historical_pred) ** 2))
                numerator = np.sum(np.abs(data - historical_pred))
                denominator = np.sum(np.abs(data))
                historical_wape = (numerator / denominator * 100) if denominator != 0 else None
                naive_forecast = data[:-1]
                actual = data[1:]
                mae_naive = np.mean(np.abs(actual - naive_forecast)) if len(actual) > 0 else None
                mae_model = np.mean(np.abs(data - historical_pred))
                historical_mase = (mae_model / mae_naive) if mae_naive and mae_naive != 0 else None
            except Exception as e:
                predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
        elif num_months >= 12:  # 12–23 個月，使用多項式迴歸 (2階)，應用混合
            try:
                x = np.arange(1, num_months + 1)
                degree = 2  # 固定2階避免過擬合
                coeffs = np.polyfit(x, data, degree)
                p = np.poly1d(coeffs)
                # 遞歸部分：初始化預測
                predictions = []
                prev_pred = data[-1]
                for step in range(1, steps_ahead + 1):
                    predict_x = num_months + step
                    pred = p(predict_x) + (0.3 * (prev_pred - data[-1]))  # 混合調整
                    predictions.append(pred)
                    prev_pred = pred
                predicted_value = predictions[-1]
                predicted_expense_str = f"{predicted_value:,.2f}"

                # 信心區間（強制下限為0）
                y_pred = p(x)
                n = len(x)
                residuals = data - y_pred
                mse = np.sum(residuals**2) / (n - degree - 1)
                se = np.sqrt(mse * (1 + 1/n)) * np.sqrt(steps_ahead)
                t_val = t.ppf(0.975, n - degree - 1)
                lower = max(0, predicted_value - t_val * se)
                upper = predicted_value + t_val * se
                ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"

                # 新增：計算歷史指標（使用多項式迴歸回測）
                historical_pred = p(x)
                historical_mae = np.mean(np.abs(data - historical_pred))
                historical_rmse = np.sqrt(np.mean((data - historical_pred) ** 2))
                numerator = np.sum(np.abs(data - historical_pred))
                denominator = np.sum(np.abs(data))
                historical_wape = (numerator / denominator * 100) if denominator != 0 else None
                naive_forecast = data[:-1]
                actual = data[1:]
                mae_naive = np.mean(np.abs(actual - naive_forecast)) if len(actual) > 0 else None
                mae_model = np.mean(np.abs(data - historical_pred))
                historical_mase = (mae_model / mae_naive) if mae_naive and mae_naive != 0 else None
            except Exception as e:
                predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
        elif num_months >= 6:  # 6–11 個月，使用線性迴歸，應用混合
            try:
                x = np.arange(1, num_months + 1)
                slope, intercept, _, _, _ = linregress(x, data)
                # 遞歸部分：初始化預測
                predictions = []
                prev_pred = data[-1]
                for step in range(1, steps_ahead + 1):
                    predict_x = num_months + step
                    pred = intercept + slope * predict_x + (0.4 * (prev_pred - data[-1]))  # 混合調整
                    predictions.append(pred)
                    prev_pred = pred
                predicted_value = predictions[-1]
                predicted_expense_str = f"{predicted_value:,.2f}"

                # 信心區間（強制下限為0）
                n = len(x)
                x_mean = np.mean(x)
                residuals = data - (intercept + slope * x)
                mse = np.sum(residuals**2) / (n - 2)
                ssx = np.sum((x - x_mean)**2)
                se = np.sqrt(mse * (1 + 1/n + ((num_months + steps_ahead) - x_mean)**2 / ssx)) * np.sqrt(steps_ahead)
                t_val = t.ppf(0.975, n - 2)
                lower = max(0, predicted_value - t_val * se)
                upper = predicted_value + t_val * se
                ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"

                # 新增：計算歷史指標（使用線性迴歸回測）
                historical_pred = intercept + slope * x
                historical_mae = np.mean(np.abs(data - historical_pred))
                historical_rmse = np.sqrt(np.mean((data - historical_pred) ** 2))
                numerator = np.sum(np.abs(data - historical_pred))
                denominator = np.sum(np.abs(data))
                historical_wape = (numerator / denominator * 100) if denominator != 0 else None
                naive_forecast = data[:-1]
                actual = data[1:]
                mae_naive = np.mean(np.abs(actual - naive_forecast)) if len(actual) > 0 else None
                mae_model = np.mean(np.abs(data - historical_pred))
                historical_mase = (mae_model / mae_naive) if mae_naive and mae_naive != 0 else None
            except Exception as e:
                predicted_expense_str = f"無法預測 (錯誤: {str(e)})"
        elif num_months >= 2:  # 2–5 個月，使用 EMA，應用混合
            try:
                ema = monthly_expenses['Real_Amount'].ewm(span=num_months, adjust=False).mean()
                # 遞歸部分：初始化預測
                predictions = []
                prev_pred = ema.iloc[-1]
                for step in range(1, steps_ahead + 1):
                    pred = prev_pred  # EMA 簡易延伸
                    predictions.append(pred)
                    prev_pred = pred
                predicted_value = predictions[-1]
                predicted_expense_str = f"{predicted_value:,.2f}"

                # EMA Bootstrap 信心區間（強制下限為0）
                residuals = monthly_expenses['Real_Amount'] - ema
                bootstrap_preds = []
                for _ in range(1000):
                    resampled_residuals = np.random.choice(residuals, size=num_months, replace=True)
                    simulated = ema + resampled_residuals
                    simulated_ema = pd.Series(simulated).ewm(span=num_months, adjust=False).mean()
                    bootstrap_preds.append(simulated_ema.iloc[-1])
                lower = max(0, np.percentile(bootstrap_preds, 2.5))
                upper = np.percentile(bootstrap_preds, 97.5)
                ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"

                # 新增：計算歷史指標（使用 EMA 回測）
                historical_pred = ema.values
                historical_mae = np.mean(np.abs(monthly_expenses['Real_Amount'].values - historical_pred))
                historical_rmse = np.sqrt(np.mean((monthly_expenses['Real_Amount'].values - historical_pred) ** 2))
                numerator = np.sum(np.abs(monthly_expenses['Real_Amount'].values - historical_pred))
                denominator = np.sum(np.abs(monthly_expenses['Real_Amount'].values))
                historical_wape = (numerator / denominator * 100) if denominator != 0 else None
                naive_forecast = monthly_expenses['Real_Amount'].values[:-1]
                actual = monthly_expenses['Real_Amount'].values[1:]
                mae_naive = np.mean(np.abs(actual - naive_forecast)) if len(actual) > 0 else None
                mae_model = np.mean(np.abs(monthly_expenses['Real_Amount'].values - historical_pred))
                historical_mase = (mae_model / mae_naive) if mae_naive and mae_naive != 0 else None
            except Exception as e:
                predicted_expense_str = f"無法預測 (錯誤: {str(e)})"

    # 還原季節性（如果有，使用目標月份）
    if used_seasonal and predicted_value is not None:
        seasonal_factor = seasonal_indices.get(target_month, 1.0)
        predicted_value *= seasonal_factor
        predicted_expense_str = f"{predicted_value:,.2f} (已還原季節性)"

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

    # --- 全新：個人財務風險儀表板 (基於蒙地卡羅，使用實質金額) ---
    p25 = None
    p75 = None
    p95 = None
    used_optimized_mc = False
    mc_note = "未使用優化蒙地卡羅模擬（資料月份不足 24 個月，使用標準版）。"
    if monthly_expenses is not None and len(monthly_expenses) >= 2:
        if num_unique_months >= 24:
            p25, p75, p95 = optimized_monte_carlo(monthly_expenses, predicted_value)
            used_optimized_mc = True
            mc_note = "已使用優化蒙地卡羅模擬（自舉法，資料月份足夠）。"
        else:
            p25, p75, p95 = monte_carlo_dashboard(monthly_expenses['Real_Amount'].values)

    # --- 新增：風險狀態與預算建議 (基於實質金額) ---
    risk_status, risk_description, suggested_budget, prudence_factor, trend_score, shock_score, data_reliability, risk_coefficient, error_coefficient, error_buffer = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse)

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
    print(f"\n{colors.PURPLE}{colors.BOLD}>>> {target_month_str} 趨勢預測 (基於實質金額): {predicted_expense_str}{ci_str}{method_used}{colors.RESET}")
    if historical_mae is not None:
        print(f"\n{colors.WHITE}>>> 模型表現評估 (基於歷史回測){colors.RESET}")
        print(f"  - MAE (平均絕對誤差): {historical_mae:,.2f} 元 (平均預測誤差金額)")
        print(f"  - RMSE (均方根誤差): {historical_rmse:,.2f} 元 (放大突發大額誤差)")
        if historical_wape is not None:
            print(f"  - WAPE (加權絕對百分比誤差): {historical_wape:.2f}% (總誤差佔總支出的比例)")
        if historical_mase is not None:
            print(f"  - MASE (平均絕對標度誤差): {historical_mase:.2f} (與天真預測的比較，小於1表示優於基準)")

    # 新增：預測方法摘要（告知使用者進階功能使用情況）
    print(f"\n{colors.CYAN}{colors.BOLD}>>> 預測方法摘要{colors.RESET}")
    print(f"  - 資料月份數: {num_unique_months}")
    print(f"  - {seasonal_note}")
    print(f"  - {mc_note}")
    print(f"  - 預測目標月份: {target_month_str} (基於目前時間，距離資料最後月份 {steps_ahead - 1} 個月)")
    print(f"  - 使用策略: 直接-遞歸混合 (結合獨立模型與先前預測輸入)")
    if step_warning:
        print(step_warning)

    # 顯示蒙地卡羅儀表板 (基於實質金額)
    if p25 is not None:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 個人財務風險儀表板 (基於 10,000 次模擬，實質金額){colors.RESET}")
        print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")
        print(f"{colors.GREEN}  [安全區] {p25:,.0f} ~ {p75:,.0f} 元 (50% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 這是您最可能的核心開銷範圍，可作為常規預算。{colors.RESET}")
        
        print(f"{colors.YELLOW}  [警戒區] {p75:,.0f} ~ {p95:,.0f} 元 (20% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 發生計畫外消費，提醒您需開始注意非必要支出。{colors.RESET}")
        
        print(f"{colors.RED}  [風險區] > {p95:,.0f} 元 (5% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 發生極端高額事件，此數值可作為緊急預備金的參考。{colors.RESET}")
        print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")

    # 新增：綜合預算建議區塊 (基於實質金額)
    if risk_status and "無法判讀" not in risk_status:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 綜合預算建議{colors.RESET}")
        print(f"{colors.BOLD}風險狀態: {risk_status}{colors.RESET}")
        print(f"{colors.WHITE}{description}{colors.RESET}")
        if data_reliability: print(f"{colors.BOLD}數據可靠性: {data_reliability}{colors.RESET}")
        
        # 顯示動態係數 (僅在適用時)
        if risk_coefficient is not None: print(f"{colors.BOLD}動態風險係數: {risk_coefficient:.2f}{colors.RESET}")
        if error_coefficient is not None: print(f"{colors.BOLD}模型誤差係數: {error_coefficient:.2f}{colors.RESET}")
        
        if suggested_budget is not None:
            print(f"{colors.BOLD}建議 {target_month_str} 預算: {suggested_budget:,.2f} 元{colors.RESET}")

            # 修正：根據數據可靠性顯示正確的三種計算依據之一
            if data_reliability and ("高度可靠" in data_reliability or "中度可靠" in data_reliability):
                if error_buffer is not None:
                    risk_buffer_val = suggested_budget - error_buffer
                    print(f"{colors.WHITE}    └ 計算依據：風險緩衝 ({risk_buffer_val:,.2f}) + 模型誤差緩衝 ({error_buffer:,.2f}){colors.RESET}")
            elif data_reliability and "原始公式" in data_reliability:
                if predicted_value is not None and expense_std_dev is not None and prudence_factor is not None:
                     print(f"{colors.WHITE}    └ 計算依據：趨勢預測 ({predicted_value:,.2f}) + 審慎緩衝 ({prudence_factor * expense_std_dev:,.2f}){colors.RESET}")
            elif data_reliability and "替代公式" in data_reliability:
                 print(f"{colors.WHITE}    └ 計算依據：近期平均支出 + 15% 固定緩衝。{colors.RESET}")


        if trend_score is not None and shock_score is not None:
            print(f"\n{colors.WHITE}>>> 多因子計分細節（透明度說明）{colors.RESET}")
            print(f"  - 趨勢風險得分: {trend_score}")
            print(f"  - 衝擊風險得分: {shock_score}")
            print(f"  - 解釋: 得分最高者決定主要狀態；若接近，視為混合狀態。")

    # 通膨調整說明
    print(f"\n{colors.WHITE}【註】關於「實質金額」：為了讓不同年份的支出能被公平比較，本報告已將所有歷史數據，統一換算為當前基期年的貨幣價值。這能幫助您在扣除物價上漲的影響後，看清自己真實的消費習慣變化。{colors.RESET}")

    print(f"{colors.CYAN}{colors.BOLD}========================================{colors.RESET}\n")
                                                                           
# --- 腳本入口 ---
def main():
    warnings.simplefilter("ignore")

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
                                                                         
