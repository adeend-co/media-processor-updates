#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v1.8                 #
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
SCRIPT_VERSION = "v1.8.22"  # 更新版本：自動檢測與條件應用
SCRIPT_UPDATE_DATE = "2025-07-18"

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
    
    # 處理純數字月份
    if s.replace('.', '', 1).isdigit():
        try:
            # 安全處理浮點數格式
            numeric_val = int(float(s))
            if 1 <= numeric_val <= 12:
                return f"{current_year}-{numeric_val:02d}-01"
        except ValueError:
            pass
    
    # 處理帶連字符的日期
    if '-' in s:
        parts = s.split('-')
        try:
            year = int(float(parts[0])) if len(parts[0]) == 4 else current_year
            month = int(float(parts[1]))
            return f"{year}-{month:02d}-01"
        except (ValueError, IndexError):
            pass
    
    # 處理YYYYMM格式
    if len(s) >= 5 and s[:4].isdigit():
        try:
            year = int(s[:4])
            month = int(float(s[4:]))  # 使用float處理可能的小數
            return f"{year}-{month:02d}-01"
        except ValueError:
            pass
    
    # 處理YYYYMMDD格式
    if s.isdigit() and len(s) == 8:
        try:
            dt = datetime.strptime(s, '%Y%m%d')
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            pass
    
    return None

def process_finance_data_individual(file_path, colors):
    """
    單獨處理每個檔案，提取金額和月份資訊
    """
    encodings_to_try = ['utf-8', 'utf-8-sig', 'cp950', 'big5', 'gb18030']
    df = None
    
    # 嘗試讀取檔案
    for enc in encodings_to_try:
        try:
            df = pd.read_csv(file_path.strip(), encoding=enc, on_bad_lines='skip')
            print(f"{colors.GREEN}成功讀取檔案 '{file_path.strip()}' (編碼: {enc}){colors.RESET}")
            break
        except (UnicodeDecodeError, FileNotFoundError):
            continue
    
    if df is None:
        return None, f"無法讀取檔案 '{file_path.strip()}'"
    
    # 標準化欄位名稱
    df.columns = df.columns.str.strip()
    
    # 辨識欄位
    date_col = find_column_by_synonyms(df.columns, ['日期', '時間', 'Date', 'time', '月份'])
    type_col = find_column_by_synonyms(df.columns, ['類型', 'Type', '收支項目', '收支'])
    amount_col = find_column_by_synonyms(df.columns, ['金額', 'Amount', 'amount', '價格'])
    income_col = find_column_by_synonyms(df.columns, ['收入', 'income'])
    expense_col = find_column_by_synonyms(df.columns, ['支出', 'expense'])
    
    # 提取統一格式的資料：[日期, 金額, 類型]
    extracted_data = []
    file_format_type = "unknown"  # 新增：記錄檔案格式類型
    
    if date_col and income_col and expense_col:
        # 收入支出分離格式
        file_format_type = "income_expense_separate"
        for _, row in df.iterrows():
            date_val = row[date_col]
            if pd.notna(row[income_col]) and pd.to_numeric(row[income_col], errors='coerce') > 0:
                extracted_data.append({
                    'Date': date_val,
                    'Amount': pd.to_numeric(row[income_col], errors='coerce'),
                    'Type': 'income'
                })
            if pd.notna(row[expense_col]) and pd.to_numeric(row[expense_col], errors='coerce') > 0:
                extracted_data.append({
                    'Date': date_val,
                    'Amount': pd.to_numeric(row[expense_col], errors='coerce'),
                    'Type': 'expense'
                })
    
    elif date_col and type_col and amount_col:
        # 標準格式
        file_format_type = "standard"
        for _, row in df.iterrows():
            amount_val = pd.to_numeric(row[amount_col], errors='coerce')
            if pd.notna(amount_val) and amount_val > 0:
                extracted_data.append({
                    'Date': row[date_col],
                    'Amount': amount_val,
                    'Type': row[type_col]
                })
    
    elif date_col and len(df.columns) > 2:
        # 寬格式（假設全為支出）- 需要保留原始邏輯
        file_format_type = "wide_format"
        
        # 清理數值欄位
        for col in df.columns:
            if col != date_col:
                df[col] = df[col].astype(str).str.replace(',', '').str.strip()
                df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0)
        
        # 檢查是否為垂直月份格式
        is_vertical_month = (df[date_col].dropna().astype(str).str.contains('月|Month', na=False).any() or 
                           df[date_col].dropna().astype(str).str.isdigit().all())
        
        if is_vertical_month:
            # 垂直格式：每列是一個月份
            for _, row in df.iterrows():
                date_val = row[date_col]
                total_amount = df.drop(columns=[date_col]).loc[_].sum()
                if total_amount > 0:
                    extracted_data.append({
                        'Date': date_val,
                        'Amount': total_amount,
                        'Type': 'expense'
                    })
        else:
            # 水平格式：欄位名稱是月份
            monthly_amounts = df.drop(columns=[date_col]).sum(axis=0)
            for col_name, amount in monthly_amounts.items():
                if amount > 0:
                    extracted_data.append({
                        'Date': col_name,
                        'Amount': amount,
                        'Type': 'expense'
                    })
    
    else:
        return None, f"檔案 '{file_path}' 格式無法辨識"
    
    return extracted_data, None, file_format_type  # 新增返回格式類型

def process_finance_data_multiple(file_paths, colors):
    """
    處理多個檔案，先分別提取再合併
    """
    all_extracted_data = []
    warnings_report = []
    format_summary = {}
    month_missing_count = 0
    
    # 分別處理每個檔案
    for file_path in file_paths:
        extracted_data, error, file_format = process_finance_data_individual(file_path, colors)
        if error:
            warnings_report.append(f"{colors.RED}錯誤：{error}{colors.RESET}")
        else:
            all_extracted_data.extend(extracted_data)
            warnings_report.append(f"{colors.GREEN}成功提取 {len(extracted_data)} 筆資料從 '{file_path}' (格式：{file_format}){colors.RESET}")
            
            # 統計格式類型
            if file_format in format_summary:
                format_summary[file_format] += 1
            else:
                format_summary[file_format] = 1
    
    if not all_extracted_data:
        return None, None, "沒有成功提取任何資料"
    
    # 合併所有資料
    combined_df = pd.DataFrame(all_extracted_data)
    
    # 修正後的日期處理函數
    def parse_date_enhanced(date_str):
        nonlocal month_missing_count
        if pd.isnull(date_str):
            return pd.NaT
        try:
            return pd.to_datetime(str(date_str), errors='raise')
        except (ValueError, TypeError):
            s_date = str(date_str).strip()
            current_year = datetime.now().year
            
            # 處理缺少年份的日期
            if ('-' in s_date or '/' in s_date or '月' in s_date) and str(current_year) not in s_date:
                try:
                    month_missing_count += 1
                    return pd.to_datetime(f"{current_year}-{s_date.replace('月','-').replace('日','').replace('號','')}")
                except ValueError:
                    # 使用原始的 normalize_date 函數
                    normalized = normalize_date(s_date)
                    if normalized:
                        return pd.to_datetime(normalized, errors='coerce')
                    return pd.NaT
            elif len(s_date) <= 4 and s_date.replace('.', '', 1).isdigit():
                # 修正：安全地處理浮點數格式
                try:
                    # 先轉為浮點數再轉為整數，避免直接int()轉換帶小數點的字符串
                    numeric_val = int(float(s_date))
                    s_date = str(numeric_val)
                    
                    if len(s_date) < 3:
                        s_date = '0' * (3 - len(s_date)) + s_date
                    
                    if len(s_date) >= 3:
                        month_missing_count += 1
                        # 確保有足夠的字符進行切片
                        if len(s_date) == 3:
                            month = int(s_date[0])  # 第一個字符作為月份
                            day = int(s_date[1:])   # 後兩個字符作為日期
                        else:
                            month = int(s_date[:-2])
                            day = int(s_date[-2:])
                        
                        # 驗證月份和日期的合理性
                        if 1 <= month <= 12 and 1 <= day <= 31:
                            return pd.to_datetime(f"{current_year}-{month}-{day}", errors='coerce')
                except (ValueError, IndexError):
                    pass
            elif s_date.isdigit() and 1 <= int(s_date) <= 12:
                month_missing_count += 1
                return pd.to_datetime(f"{current_year}-{int(s_date)}-01", errors='coerce')
            else:
                # 使用原始的 normalize_date 函數作為最後手段
                normalized = normalize_date(s_date)
                if normalized:
                    return pd.to_datetime(normalized, errors='coerce')
            return pd.NaT
    
    combined_df['Parsed_Date'] = combined_df['Date'].apply(parse_date_enhanced)
    combined_df = combined_df.dropna(subset=['Parsed_Date'])
    
    # 轉換金額為數值
    combined_df['Amount'] = pd.to_numeric(combined_df['Amount'], errors='coerce')
    combined_df = combined_df[combined_df['Amount'] > 0]
    
    # 計算月份統計
    unique_months = combined_df['Parsed_Date'].dt.to_period('M').nunique()
    if unique_months > 0:
        warnings_report.append(f"資料時間橫跨 {colors.BOLD}{unique_months}{colors.RESET} 個不同月份。")
    if month_missing_count > 0:
        warnings_report.append(f"{colors.YELLOW}警告：有 {colors.BOLD}{month_missing_count}{colors.RESET} 筆紀錄的日期缺少明確年份，已自動假定為今年。{colors.RESET}")
    
    # 加入格式摘要報告
    if format_summary:
        format_report = "、".join([f"{fmt}({count}個檔案)" for fmt, count in format_summary.items()])
        warnings_report.append(f"{colors.YELLOW}注意：偵測到的檔案格式包括：{format_report}，已為您自動統一處理。{colors.RESET}")
    
    # 生成月度支出摘要
    expense_df = combined_df[combined_df['Type'].str.lower() == 'expense']
    monthly_expenses = None
    if not expense_df.empty:
        monthly_expenses = expense_df.set_index('Parsed_Date').resample('M')['Amount'].sum().reset_index()
        monthly_expenses['Amount'] = monthly_expenses['Amount'].fillna(0)
        monthly_expenses = monthly_expenses[monthly_expenses['Amount'] > 0]
        
        # 確保創建 Real_Amount 欄位
        monthly_expenses['Real_Amount'] = monthly_expenses['Amount']
    
    # 進行通膨調整
    base_year = datetime.now().year
    year_range = set()
    year_cpi_used = {}
    
    if monthly_expenses is not None:
        monthly_expenses['Year'] = monthly_expenses['Parsed_Date'].dt.year
        year_range = set(monthly_expenses['Year'])
        if year_range:
            try:
                cpi_values, cpi_base_year = calculate_cpi_values(year_range, INFLATION_RATES)
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
                monthly_expenses['Real_Amount'] = monthly_expenses['Amount']
    
    return combined_df, monthly_expenses, "\n".join(warnings_report)

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
import numpy as np
import pandas as pd
from scipy.stats import linregress, kurtosis

def percentile_score(value, p25, p50, p75, p90):
    """將數值轉換為0-10的標準分數"""
    if value <= p25:
        return 1
    elif value <= p50:
        return 3
    elif value <= p75:
        return 6
    elif value <= p90:
        return 8
    else:
        return 10

def data_reliability_factor(n, n0=18, k=0.2):
    """計算數據可靠性因子"""
    return 1 / (1 + np.exp(-k * (n - n0)))

def compute_trend_factors(data, x):
    """計算趨勢風險因子"""
    n = len(data)
    half = n // 2
    
    # 趨勢加速度
    if half >= 2 and (n - half) >= 2:
        x_early, y_early = x[:half], data[:half]
        x_late, y_late = x[half:], data[half:]
        slope_early, _, _, _, _ = linregress(x_early, y_early)
        slope_late, _, _, _, _ = linregress(x_late, y_late)
        accel = slope_late - slope_early
    else:
        accel = 0

    # 滾動平均交叉
    window_short = min(3, n)
    window_long = min(6, n)
    if n >= window_short and n >= window_long:
        ma_short = pd.Series(data).rolling(window=window_short).mean().iloc[-1]
        ma_long = pd.Series(data).rolling(window=window_long).mean().iloc[-1]
        crossover = 1 if ma_short > ma_long else 0
    else:
        crossover = 0

    # 殘差自相關性
    if n >= 2:
        slope, intercept, _, _, _ = linregress(x, data)
        trend = intercept + slope * x
        residuals = data - trend
        if n >= 3:
            autocorr = np.corrcoef(residuals[:-1], residuals[1:])[0, 1]
        else:
            autocorr = 0
    else:
        residuals = np.array([0])
        autocorr = 0

    return accel, crossover, autocorr, residuals

def compute_volatility_factors(data, residuals):
    """計算波動風險因子"""
    n = len(data)
    
    # 波動的波動性
    if n >= 3:
        rolling_std = pd.Series(data).rolling(window=min(3, n)).std().dropna().values
        vol_of_vol = np.std(rolling_std) if len(rolling_std) > 1 else 0
    else:
        vol_of_vol = 0

    # 下行波動率
    if n >= 2:
        monthly_growth = np.diff(data) / data[:-1]
        positive_growth = monthly_growth[monthly_growth > 0]
        downside_vol = np.std(positive_growth) if len(positive_growth) > 1 else 0
    else:
        downside_vol = 0

    # 峰態
    kurt = kurtosis(residuals) if len(residuals) > 1 else 0
    
    return vol_of_vol, downside_vol, kurt

def compute_shock_factors(data, residuals):
    """計算衝擊風險因子"""
    n = len(data)
    
    # 最大衝擊幅度
    if n > 0:
        avg_expense = np.mean(data)
        max_shock = np.max(residuals) if len(residuals) > 0 else 0
        max_shock_magnitude = max_shock / avg_expense if avg_expense != 0 else 0
    else:
        max_shock_magnitude = 0

    # 連續正向衝擊
    if n >= 2:
        slope, intercept, _, _, _ = linregress(np.arange(n), data)
        trend = intercept + slope * np.arange(n)
        count = 0
        max_count = 0
        for actual, pred in zip(data, trend):
            if actual > pred:
                count += 1
                max_count = max(max_count, count)
            else:
                count = 0
        consecutive_shocks = max_count
    else:
        consecutive_shocks = 0
    
    return max_shock_magnitude, consecutive_shocks

def assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse):
    """
    升級版風險評估函數 - 整合四階段動態風險評分系統
    """
    # 初始化所有可能返回的變數
    trend_scores = None
    volatility_scores = None  
    shock_scores = None
    overall_score = None
    trend_score = None
    volatility_score = None
    shock_score = None
    
    if monthly_expenses is None or len(monthly_expenses) < 2:
        return ("無法判讀 (資料不足)", "資料過少，無法進行風險評估。", None, None, None, None, 
                "極低可靠性", None, None, None, trend_scores, volatility_scores, shock_scores, overall_score)

    num_months = len(monthly_expenses)
    data = monthly_expenses['Real_Amount'].values
    x = np.arange(num_months)

    # 階段一：深度特徵提取
    accel, crossover, autocorr, residuals = compute_trend_factors(data, x)
    vol_of_vol, downside_vol, kurt = compute_volatility_factors(data, residuals)
    max_shock_magnitude, consecutive_shocks = compute_shock_factors(data, residuals)

    # 階段二：指標標準化與評分（使用示例百分位數）
    trend_scores = {
        'accel': percentile_score(accel, -0.5, 0, 0.5, 1),
        'crossover': percentile_score(crossover, 0, 0, 0.5, 1),
        'autocorr': percentile_score(abs(autocorr), 0, 0.2, 0.5, 0.8)
    }
    volatility_scores = {
        'vol_of_vol': percentile_score(vol_of_vol, 0, 0.5, 1, 2),
        'downside_vol': percentile_score(downside_vol, 0, 0.1, 0.2, 0.5),
        'kurtosis': percentile_score(abs(kurt), 0, 1, 3, 5)
    }
    shock_scores = {
        'max_shock_magnitude': percentile_score(max_shock_magnitude, 0, 0.1, 0.2, 0.5),
        'consecutive_shocks': percentile_score(consecutive_shocks, 0, 2, 4, 6)
    }

    # 階段三：多因子加權聚合
    trend_score = np.mean(list(trend_scores.values()))
    volatility_score = np.mean(list(volatility_scores.values()))
    shock_score = np.mean(list(shock_scores.values()))
    weights = (0.4, 0.35, 0.25)
    overall_score = (trend_score * weights[0]) + (volatility_score * weights[1]) + (shock_score * weights[2])

    # 階段四：數據可靠性校準
    drf = data_reliability_factor(num_months)
    max_risk_premium = 0.25
    base_premium = 0.10
    risk_score_term = (overall_score / 10) * max_risk_premium * drf
    base_uncertainty_term = base_premium * (1 - drf)
    dynamic_risk_coefficient = risk_score_term + base_uncertainty_term

    # 風險狀態判讀
    if overall_score > 7:
        status = "高風險"
        description = "多項風險因子顯示顯著風險，建議立即審視支出模式。"
    elif overall_score > 4:
        status = "中度風險"
        description = "風險因子處於中等水平，需持續監控財務狀況。"
    else:
        status = "低風險"
        description = "整體風險可控，但仍需保持適度警惕。"

    # 預算建議計算
    if p95 and p75 and predicted_value:
        risk_buffer = p75 + (dynamic_risk_coefficient * (p95 - p75))
        error_buffer = 0.5 * historical_rmse if historical_rmse else 0
        suggested_budget = risk_buffer + error_buffer
    else:
        suggested_budget = None
        error_buffer = None

    # 數據可靠性評估
    if drf > 0.8:
        data_reliability = "高度可靠"
    elif drf > 0.4:
        data_reliability = "中度可靠"
    else:
        data_reliability = "低度可靠"

    # 返回與原函數相同的參數數量和順序（新增 volatility_score）
    return (status, description, suggested_budget, dynamic_risk_coefficient, trend_score, volatility_score, shock_score,
            data_reliability, dynamic_risk_coefficient, 0.5, error_buffer, 
            trend_scores, volatility_scores, shock_scores, overall_score)

# --- 主要分析與預測函數 (升級為四階段模型 + 蒙地卡羅 + 風險預算建議 + 通膨調整) ---
def analyze_and_predict(file_paths_str: str, no_color: bool):
    colors = Colors(enabled=not no_color)
    file_paths = [path.strip() for path in file_paths_str.split(';')]

    master_df, monthly_expenses, warnings_report = process_finance_data_multiple(file_paths, colors)

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

    # --- 計算總支出與淨餘額 (修正區塊) ---
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
        
        # 從 monthly_expenses 回填實質總支出
        if monthly_expenses is not None:
            total_real_expense = monthly_expenses['Real_Amount'].sum()
            
    elif monthly_expenses is not None:
        total_expense = monthly_expenses['Amount'].sum()  # 名目總額
        total_real_expense = monthly_expenses['Real_Amount'].sum()  # 實質總額

    # 將 net_balance 的計算放在 if/elif 區塊之外
    # 這樣無論是哪種檔案格式，它都一定會被計算
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
    risk_status, risk_description, suggested_budget, prudence_factor, trend_score, shock_score, data_reliability, risk_coefficient, error_coefficient, error_buffer, trend_scores, volatility_scores, shock_scores, overall_score = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse)

    # --- 輸出最終的簡潔報告 ---
    print(f"\n{colors.CYAN}{colors.BOLD}========== 財務分析與預測報告 =========={colors.RESET}")
    
    # 處理非寬格式（有收入/支出的情況）
    if not is_wide_format_expense_only:
        print(f"{colors.BOLD}總收入: {colors.GREEN}{total_income:,.2f}{colors.RESET}")
    
    # 顯示總支出（名目與實質）
    print(f"{colors.BOLD}總支出 (名目): {colors.RED}{total_expense:,.2f}{colors.RESET}")
    # 修正：改為 monthly_expenses 存在就顯示，而不是 total_real_expense > 0
    if monthly_expenses is not None and len(monthly_expenses) > 0:
        print(f"{colors.BOLD}總支出 (實質，經通膨調整): {colors.RED}{total_real_expense:,.2f}{colors.RESET}")

    # 顯示歷史波動
    if expense_std_dev is not None:
        print(f"{colors.BOLD}歷史月均支出波動 (基於實質金額): {color}{expense_std_dev:,.2f}{volatility_report}{colors.RESET}")
    
    # 處理淨餘額
    if not is_wide_format_expense_only:
        print("------------------------------------------")
        balance_color = colors.GREEN if net_balance >= 0 else colors.RED
        print(f"{colors.BOLD}淨餘額（基於名目金額）: {balance_color}{colors.BOLD}{net_balance:,.2f}{colors.RESET}")

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
        
        print(f"{colors.RED}  [應急動用區] > {p95:,.0f} 元 (5% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 當單月支出超過此金額，代表發生僅靠月度預算無法應對的重大財務衝擊，應考慮「動用」您另外儲備的緊急預備金。{colors.RESET}")
        print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")

    # 新增：月份保守預算建議區塊 (基於實質金額)
    if risk_status and "無法判讀" not in risk_status:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 月份保守預算建議{colors.RESET}")
        print(f"{colors.BOLD}風險狀態: {risk_status}{colors.RESET}")
        print(f"{colors.WHITE}{risk_description}{colors.RESET}")
        if data_reliability: print(f"{colors.BOLD}數據可靠性: {data_reliability}{colors.RESET}")
        
        # 顯示動態係數 (僅在適用時)
        if risk_coefficient is not None: print(f"{colors.BOLD}動態風險係數: {risk_coefficient:.2f}{colors.RESET}")
        if error_coefficient is not None: print(f"{colors.BOLD}模型誤差係數: {error_coefficient:.2f}{colors.RESET}")
        

        if suggested_budget is not None:
            print(f"{colors.BOLD}建議 {target_month_str} 預算: {suggested_budget:,.2f} 元{colors.RESET}")

            # 根據數據可靠性顯示正確的三種計算依據之一
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

        # 新增：詳細風險因子分析報告
        if trend_scores is not None and volatility_scores is not None and shock_scores is not None:
            print(f"\n{colors.WHITE}>>> 詳細風險因子分析{colors.RESET}")
            print(f"{colors.BOLD}總體風險評分: {overall_score:.2f}/10{colors.RESET}")
            print(f"\n{colors.CYAN}趨勢風險因子:{colors.RESET}")
            print(f"  - 趨勢加速度: {trend_scores['accel']:.1f}/10")
            print(f"  - 滾動平均交叉: {trend_scores['crossover']:.1f}/10")
            print(f"  - 殘差自相關性: {trend_scores['autocorr']:.1f}/10")
            print(f"  - 趨勢風險得分: {trend_score:.2f}/10")
            
            print(f"\n{colors.YELLOW}波動風險因子:{colors.RESET}")
            print(f"  - 波動的波動性: {volatility_scores['vol_of_vol']:.1f}/10")
            print(f"  - 下行波動率: {volatility_scores['downside_vol']:.1f}/10")
            print(f"  - 峰態: {volatility_scores['kurtosis']:.1f}/10")
            print(f"  - 波動風險得分: {volatility_score:.2f}/10")
            
            print(f"\n{colors.RED}衝擊風險因子:{colors.RESET}")
            print(f"  - 最大衝擊幅度: {shock_scores['max_shock_magnitude']:.1f}/10")
            print(f"  - 連續正向衝擊: {shock_scores['consecutive_shocks']:.1f}/10")
            print(f"  - 衝擊風險得分: {shock_score:.2f}/10")
            
            print(f"\n{colors.PURPLE}動態風險係數: {risk_coefficient:.3f}{colors.RESET}")
            print(f"{colors.WHITE}  └ 權重配置: 趨勢(40%) + 波動(35%) + 衝擊(25%){colors.RESET}")

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
                                                                         
