#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v3.2                 #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。                        #
# 具備自動格式清理、互動式路徑輸入與多種模型預測、信賴區間等功能。                           #
# 更新 v3.2.2：恢復並優化了針對中期數據（6-23個月）的詳細風險因子分析報告，     #
#             以提供更具解釋性的風險評估。                                          #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v3.2.2"  # Fix: Restore and enhance detailed risk factor report
SCRIPT_UPDATE_DATE = "2025-07-26"

# --- 新增：可完全自訂的表格寬度設定 ---
# 說明：您可以直接修改這裡的數字，來調整報告中各表格欄位的寬度，以適應您的終端機字體。
# 'q' 代表分位數, 'loss' 代表損失值, 'interp' 代表解釋, etc.
TABLE_CONFIG = {
    'quantile_loss': {
        'q': 8,         # 「分位數」欄位寬度
        'loss': 12,     # 「損失值」欄位寬度
        'interp': 26    # 「解釋」欄位寬度
    },
    'calibration': {
        'label': 19,    # 「預測分位數」欄位寬度
        'freq': 16,     # 「實際觀測頻率」欄位寬度
        'assess': 16    # 「評估結果」欄位寬度
    },
    'autocorrelation': {
        'lag': 12,      # 「延遲週期」欄位寬度
        'acf': 17,      # 「自相關係數」欄位寬度
        'sig': 12,      # 「是否顯著」欄位寬度
        'meaning': 16   # 「潛在意義」欄位寬度
    }
}

import sys
import os
import subprocess
import warnings
from datetime import datetime
import pandas as pd
import argparse
import numpy as np
from scipy.stats import linregress, t
from scipy.stats import skew, kurtosis, median_abs_deviation, percentileofscore
from scipy.optimize import nnls
from collections import deque, Counter

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

# --- 單檔處理函數 (未變更) ---
def process_finance_data_individual(file_path, colors):
    encodings_to_try = ['utf-8', 'utf-8-sig', 'cp950', 'big5', 'gb18030']
    df = None
    
    for enc in encodings_to_try:
        try:
            df = pd.read_csv(file_path.strip(), encoding=enc, on_bad_lines='skip')
            print(f"{colors.GREEN}成功讀取檔案 '{file_path.strip()}' (編碼: {enc}){colors.RESET}")
            break
        except (UnicodeDecodeError, FileNotFoundError):
            continue
    
    if df is None:
        return None, f"無法讀取檔案 '{file_path.strip()}'"
    
    df.columns = df.columns.str.strip()
    
    date_col = find_column_by_synonyms(df.columns, ['日期', '時間', 'Date', 'time', '月份'])
    type_col = find_column_by_synonyms(df.columns, ['類型', 'Type', '收支項目', '收支'])
    amount_col = find_column_by_synonyms(df.columns, ['金額', 'Amount', 'amount', '價格'])
    income_col = find_column_by_synonyms(df.columns, ['收入', 'income'])
    expense_col = find_column_by_synonyms(df.columns, ['支出', 'expense'])
    
    extracted_data = []
    file_format_type = "unknown"
    
    if date_col and income_col and expense_col:
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
        file_format_type = "wide_format"
        
        for col in df.columns:
            if col != date_col:
                df[col] = df[col].astype(str).str.replace(',', '').str.strip()
                df[col] = pd.to_numeric(df[col], errors='coerce').fillna(0)
        
        is_vertical_month = (df[date_col].dropna().astype(str).str.contains('月|Month', na=False).any() or 
                             df[date_col].dropna().astype(str).str.isdigit().all())
        
        if is_vertical_month:
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
    
    return extracted_data, None, file_format_type

# --- 多檔處理函數 (未變更) ---
def process_finance_data_multiple(file_paths, colors):
    all_extracted_data = []
    warnings_report = []
    format_summary = {}
    month_missing_count = 0
    
    for file_path in file_paths:
        extracted_data, error, file_format = process_finance_data_individual(file_path, colors)
        if error:
            warnings_report.append(f"{colors.RED}錯誤：{error}{colors.RESET}")
        else:
            all_extracted_data.extend(extracted_data)
            warnings_report.append(f"{colors.GREEN}成功提取 {len(extracted_data)} 筆資料從 '{file_path}' (格式：{file_format}){colors.RESET}")
            
            if file_format in format_summary:
                format_summary[file_format] += 1
            else:
                format_summary[file_format] = 1
    
    if not all_extracted_data:
        return None, None, "沒有成功提取任何資料"
    
    combined_df = pd.DataFrame(all_extracted_data)
    
    def parse_date_enhanced(date_str):
        nonlocal month_missing_count
        if pd.isnull(date_str):
            return pd.NaT
        try:
            return pd.to_datetime(str(date_str), errors='raise')
        except (ValueError, TypeError):
            s_date = str(date_str).strip()
            current_year = datetime.now().year
            
            if ('-' in s_date or '/' in s_date or '月' in s_date) and str(current_year) not in s_date:
                try:
                    month_missing_count += 1
                    return pd.to_datetime(f"{current_year}-{s_date.replace('月','-').replace('日','').replace('號','')}")
                except ValueError:
                    normalized = normalize_date(s_date)
                    if normalized:
                        return pd.to_datetime(normalized, errors='coerce')
                    return pd.NaT
            elif len(s_date) <= 4 and s_date.replace('.', '', 1).isdigit():
                try:
                    numeric_val = int(float(s_date))
                    s_date = str(numeric_val)
                    
                    if len(s_date) < 3:
                        s_date = '0' * (3 - len(s_date)) + s_date
                    
                    if len(s_date) >= 3:
                        month_missing_count += 1
                        if len(s_date) == 3:
                            month = int(s_date[0])
                            day = int(s_date[1:])
                        else:
                            month = int(s_date[:-2])
                            day = int(s_date[-2:])
                        
                        if 1 <= month <= 12 and 1 <= day <= 31:
                            return pd.to_datetime(f"{current_year}-{month}-{day}", errors='coerce')
                except (ValueError, IndexError):
                    pass
            elif s_date.isdigit() and 1 <= int(s_date) <= 12:
                month_missing_count += 1
                return pd.to_datetime(f"{current_year}-{int(s_date)}-01", errors='coerce')
            else:
                normalized = normalize_date(s_date)
                if normalized:
                    return pd.to_datetime(normalized, errors='coerce')
            return pd.NaT
    
    combined_df['Parsed_Date'] = combined_df['Date'].apply(parse_date_enhanced)
    combined_df = combined_df.dropna(subset=['Parsed_Date'])
    
    combined_df['Amount'] = pd.to_numeric(combined_df['Amount'], errors='coerce')
    combined_df = combined_df[combined_df['Amount'] > 0]
    
    unique_months = combined_df['Parsed_Date'].dt.to_period('M').nunique()
    if unique_months > 0:
        warnings_report.append(f"資料時間橫跨 {colors.BOLD}{unique_months}{colors.RESET} 個不同月份。")
    if month_missing_count > 0:
        warnings_report.append(f"{colors.YELLOW}警告：有 {colors.BOLD}{month_missing_count}{colors.RESET} 筆紀錄的日期缺少明確年份，已自動假定為今年。{colors.RESET}")
    
    if format_summary:
        format_report = "、".join([f"{fmt}({count}個檔案)" for fmt, count in format_summary.items()])
        warnings_report.append(f"{colors.YELLOW}注意：偵測到的檔案格式包括：{format_report}，已為您自動統一處理。{colors.RESET}")
    
    expense_df = combined_df[combined_df['Type'].str.lower() == 'expense']
    monthly_expenses = None
    if not expense_df.empty:
        monthly_expenses = expense_df.set_index('Parsed_Date').resample('M')['Amount'].sum().reset_index()
        monthly_expenses['Amount'] = monthly_expenses['Amount'].fillna(0)
        monthly_expenses = monthly_expenses[monthly_expenses['Amount'] > 0]
        
        monthly_expenses['Real_Amount'] = monthly_expenses['Amount']
    
    base_year = datetime.now().year
    year_range = set()
    year_cpi_used = {}
    
    if monthly_expenses is not None and not monthly_expenses.empty:
        monthly_expenses['Year'] = monthly_expenses['Parsed_Date'].dt.year
        year_range = set(monthly_expenses['Year'])
        if year_range:
            try:
                cpi_values, cpi_base_year = calculate_cpi_values(year_range, INFLATION_RATES)
                for idx, row in monthly_expenses.iterrows():
                    year = row['Year']
                    monthly_expenses.at[idx, 'Real_Amount'] = adjust_to_real_amount(row['Amount'], year, base_year, cpi_values)
                    year_cpi_used[year] = cpi_values.get(year, '無數據')
                
                warnings_report.append(f"{colors.GREEN}CPI 基準年份：{cpi_base_year} 年（基於輸入數據最早年份，指数設為 100）。計算到目標年：{base_year} 年。{colors.RESET}")
                
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

# --- 季節性分解函數 (未變更) ---
def seasonal_decomposition(monthly_expenses):
    monthly_expenses['Month'] = monthly_expenses['Parsed_Date'].dt.month
    monthly_avg = monthly_expenses.groupby('Month')['Real_Amount'].mean()
    overall_avg = monthly_expenses['Real_Amount'].mean()
    seasonal_indices = monthly_avg / overall_avg
    
    deseasonalized = monthly_expenses.copy()
    deseasonalized['Deseasonalized'] = deseasonalized['Real_Amount'] / deseasonalized['Month'].map(seasonal_indices)
    
    return deseasonalized, seasonal_indices

# --- 優化蒙地卡羅模擬 (未變更) ---
def optimized_monte_carlo(monthly_expenses, predicted_value, num_simulations=10000):
    x = np.arange(len(monthly_expenses))
    slope, intercept, _, _, _ = linregress(x, monthly_expenses['Real_Amount'])
    trend = intercept + slope * x
    residuals = monthly_expenses['Real_Amount'] - trend
    
    simulated = []
    for _ in range(num_simulations):
        sampled_residual = np.random.choice(residuals, size=1)[0]
        sim_value = predicted_value + sampled_residual
        simulated.append(sim_value)
    
    p25, p75, p95 = np.percentile(simulated, [25, 75, 95])
    return p25, p75, p95

# --- 多項式迴歸與信賴區間計算函數 (未變更) ---
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

# --- 蒙地卡羅儀表板函式 (未變更) ---
def monte_carlo_dashboard(monthly_expense_data, num_simulations=10000):
    if len(monthly_expense_data) < 2:
        return None, None, None

    mean_expense = np.mean(monthly_expense_data)
    std_expense = np.std(monthly_expense_data)

    if std_expense == 0:
        std_expense = mean_expense * 0.1

    simulated_monthly_totals = np.random.normal(mean_expense, std_expense, num_simulations)

    p25, p75, p95 = np.percentile(simulated_monthly_totals, [25, 75, 95])

    return p25, p75, p95

# --- 【新增】穩健的移動標準差計算函數 (基於MAD) ---
def robust_moving_std(series, window):
    """
    計算對異常值不敏感的移動標準差。
    使用中位數絕對偏差 (MAD) 並將其縮放，使其與標準差具有可比性。
    """
    # 0.6745 是正態分佈中 Q3 的值，1/0.6745 ≈ 1.4826
    mad_series = series.rolling(window).apply(median_abs_deviation, raw=True)
    robust_std = mad_series / 0.6745
    return robust_std

# --- 動態加權混合演算法核心函數 (【已升級】) ---
def calculate_anomaly_scores(data, window_size=6, k_ma=2.5, k_sigmoid=0.5):
    """
    根據動態加權混合演算法計算異常分數。
    【升級】：使用穩健的移動標準差 (基於MAD) 來避免被極端值影響。
    """
    n_total = len(data)
    if n_total < window_size:
        return pd.DataFrame({
            'Amount': data, 'SIQR': np.zeros(n_total), 'SMA': np.zeros(n_total),
            'W_Local': np.zeros(n_total), 'Final_Score': np.zeros(n_total),
            'Is_Shock': np.zeros(n_total, dtype=bool)
        })

    # 1. 全局衝擊分數 (IQR Score, SIQR) - 未變更
    q1, q3 = np.percentile(data, [25, 75])
    iqr = q3 - q1
    upper_bound_iqr = q3 + 1.5 * iqr
    siqr_denominator = upper_bound_iqr if upper_bound_iqr > 0 else 1
    siqr = np.maximum(0, (data - upper_bound_iqr) / siqr_denominator)

    # 2. 局部行為分數 (Moving Average Score, SMA) - 【核心升級】
    series = pd.Series(data)
    ma = series.rolling(window=window_size).mean()
    # 【替換】使用新的穩健波動性計算，取代原本的 .std()
    robust_std = robust_moving_std(series, window=window_size)
    
    channel_top = ma + (k_ma * robust_std)
    sma_denominator = channel_top.where(channel_top > 0, 1)
    sma = np.maximum(0, (series - channel_top) / sma_denominator).fillna(0).values

    # 3. 動態權重計算 (Local Weight, W_Local) - 未變更
    n_series = np.arange(1, n_total + 1)
    w_local = 1 / (1 + np.exp(-k_sigmoid * (n_series - window_size)))
    w_local[:window_size] = 0.0
    w_global = 1.0

    # 4. 最終綜合異常分數 (Final Anomaly Score) - 未變更
    numerator = (siqr * w_global) + (sma * w_local)
    denominator = w_global + w_local
    final_score = np.nan_to_num((numerator / denominator), nan=0.0)
    
    # 5. 識別全局性衝擊 (用於攤提金計算) - 未變更
    is_shock = (siqr > 0.01) & (sma > 0.01)

    return pd.DataFrame({
        'Amount': data, 'SIQR': siqr, 'SMA': sma, 'W_Local': w_local,
        'Final_Score': final_score, 'Is_Shock': is_shock
    })


# --- 結構性轉變偵測函數 (【已重構】) ---
def detect_structural_change_point(monthly_expenses_df, history_window=12, recent_window=6, c_factor=1.0):
    """
    【重構】偵測最後一個「結構性轉變」時期。
    邏輯：比較近期中位數是否顯著高於歷史中位數+歷史波動。
    """
    data = monthly_expenses_df['Real_Amount'].values
    n = len(data)
    
    # 需要足夠的數據來進行比較
    if n < history_window + recent_window:
        return 0
        
    last_change_point = 0
    # 從後往前掃描，尋找最後一個轉變點
    # 迭代的起點確保歷史數據至少有 history_window 那麼長
    for i in range(n - recent_window, history_window -1, -1):
        history_data = data[:i]
        recent_data = data[i : i + recent_window]
        
        # 計算歷史數據的穩健統計量
        median_history = np.median(history_data)
        q1_history, q3_history = np.percentile(history_data, [25, 75])
        iqr_history = q3_history - q1_history
        
        # 如果歷史波動為零，給一個很小的基礎值避免判斷失效
        if iqr_history == 0 and median_history > 0:
            iqr_history = median_history * 0.05 
        elif iqr_history == 0 and median_history == 0:
            iqr_history = 1 # 避免完全為零的情況
        
        # 計算近期數據的中位數
        median_recent = np.median(recent_data)
        
        # 核心判斷條件：近期中位數是否已突破歷史常態區間
        threshold = median_history + (c_factor * iqr_history)
        if median_recent > threshold:
            last_change_point = i
            break # 從後往前找，第一個找到的就是最後一個
            
    return last_change_point


# --- 三層式預算建議核心函數 (【★★★ 已修正 ★★★】) ---
def assess_risk_and_budget_advanced(monthly_expenses, model_error_coefficient, historical_rmse):
    """
    針對超過12個月數據的進階三層式預算計算模型。
    【v2.31 修正】: 確保模型誤差緩衝總是使用主模型傳入的全局 historical_rmse。
    """
    data = monthly_expenses['Real_Amount'].values
    n_total = len(data)
    
    anomaly_df = calculate_anomaly_scores(data)
    
    # --- 模式偵測 (使用重構後的函數) ---
    change_point = detect_structural_change_point(monthly_expenses)
    change_date_str = None
    if change_point > 0:
        change_date = monthly_expenses['Parsed_Date'].iloc[change_point]
        change_date_str = change_date.strftime('%Y年-%m月')
    
    num_shocks = int(anomaly_df['Is_Shock'].sum())

    # --- 第一層：基礎日常預算 (Base Living Budget) ---
    new_normal_df = anomaly_df.iloc[change_point:].copy()
    clean_new_normal_data = new_normal_df[~new_normal_df['Is_Shock']]['Amount'].values
    
    if len(clean_new_normal_data) < 2:
        clean_new_normal_data = new_normal_df['Amount'].values
    if len(clean_new_normal_data) < 2:
        clean_new_normal_data = data

    _, base_budget_p75, _ = monte_carlo_dashboard(clean_new_normal_data)
    if base_budget_p75 is None:
        base_budget_p75 = np.mean(clean_new_normal_data) * 1.1

    # --- 第二層：巨額衝擊攤提金 (Amortized Shock Fund) ---
    shock_rows = anomaly_df[anomaly_df['Is_Shock']]
    shock_amounts = shock_rows['Amount'].values
    amortized_shock_fund = 0.0
    
    if len(shock_amounts) > 0:
        avg_shock = np.mean(shock_amounts)
        prob_shock = len(shock_amounts) / n_total
        amortized_shock_fund = avg_shock * prob_shock
    
    # --- 第三層：模型誤差緩衝 (Model Error Buffer) ---
    # 【v2.31 核心修正】: 直接使用傳入的全局 historical_rmse，不再重新計算局部 RMSE。
    # 這確保了誤差緩衝能準確反映主預測模型本身的內在不確定性。
    model_error_buffer = model_error_coefficient * (historical_rmse if historical_rmse is not None else 0)
    
    # --- 最終預算 ---
    suggested_budget = base_budget_p75 + amortized_shock_fund + model_error_buffer
    
    status = "進階預算模式 (三層式)"
    description = f"偵測到數據模式複雜，已啟用三層式預算模型以提高準確性。"
    data_reliability = "高度可靠 (進階模型)"

    # --- 打包所有結果 ---
    components = {
        'is_advanced': True,
        'base': base_budget_p75,
        'amortized': amortized_shock_fund,
        'error': model_error_buffer,
        'change_date': change_date_str,
        'num_shocks': num_shocks
    }
    
    return (status, description, suggested_budget, data_reliability, components)


# --- 風險狀態判讀與預算建議函數 (未變更) ---
def percentile_score(value, p25, p50, p75, p90):
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
    return 1 / (1 + np.exp(-k * (n - n0)))

def compute_trend_factors(data, x):
    n = len(data)
    half = n // 2
    
    if half >= 2 and (n - half) >= 2:
        x_early, y_early = x[:half], data[:half]
        x_late, y_late = x[half:], data[half:]
        slope_early, _, _, _, _ = linregress(x_early, y_early)
        slope_late, _, _, _, _ = linregress(x_late, y_late)
        accel = slope_late - slope_early
    else:
        accel = 0

    window_short = min(3, n)
    window_long = min(6, n)
    if n >= window_short and n >= window_long:
        ma_short = pd.Series(data).rolling(window=window_short).mean().iloc[-1]
        ma_long = pd.Series(data).rolling(window=window_long).mean().iloc[-1]
        crossover = 1 if ma_short > ma_long else 0
    else:
        crossover = 0

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
    n = len(data)
    
    if n >= 3:
        rolling_std = pd.Series(data).rolling(window=min(3, n)).std().dropna().values
        vol_of_vol = np.std(rolling_std) if len(rolling_std) > 1 else 0
    else:
        vol_of_vol = 0

    if n >= 2:
        monthly_growth = np.diff(data) / data[:-1]
        positive_growth = monthly_growth[monthly_growth > 0]
        downside_vol = np.std(positive_growth) if len(positive_growth) > 1 else 0
    else:
        downside_vol = 0

    kurt = kurtosis(residuals) if len(residuals) > 1 else 0
    
    return vol_of_vol, downside_vol, kurt

def compute_shock_factors(data, residuals):
    n = len(data)
    
    if n > 0:
        avg_expense = np.mean(data)
        max_shock = np.max(residuals) if len(residuals) > 0 else 0
        max_shock_magnitude = max_shock / avg_expense if avg_expense != 0 else 0
    else:
        max_shock_magnitude = 0

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

def calculate_historical_factors(data, min_months=12):
    n_total = len(data)
    if n_total < min_months:
        return None

    historical_results = {
        'accel': [], 'crossover': [], 'autocorr': [],
        'vol_of_vol': [], 'downside_vol': [], 'kurtosis': [],
        'max_shock_magnitude': [], 'consecutive_shocks': []
    }

    for n in range(min_months, n_total + 1):
        window_data = data[:n]
        x = np.arange(n)
        
        try:
            accel, crossover, autocorr, residuals = compute_trend_factors(window_data, x)
            vol_of_vol, downside_vol, kurt = compute_volatility_factors(window_data, residuals)
            max_shock_magnitude, consecutive_shocks = compute_shock_factors(window_data, residuals)

            historical_results['accel'].append(accel)
            historical_results['crossover'].append(crossover)
            historical_results['autocorr'].append(abs(autocorr))
            historical_results['vol_of_vol'].append(vol_of_vol)
            historical_results['downside_vol'].append(downside_vol)
            historical_results['kurtosis'].append(abs(kurt))
            historical_results['max_shock_magnitude'].append(max_shock_magnitude)
            historical_results['consecutive_shocks'].append(consecutive_shocks)
        except Exception:
            continue
            
    return historical_results

def calculate_dynamic_error_coefficient(calibration_results, acf_results, quantile_spread):
    """
    根據三大診斷維度，動態計算模型誤差係數。
    """
    calibration_errors = [abs(res['observed_freq'] - res['quantile']) for res in calibration_results.values()]
    calibration_penalty = np.mean(calibration_errors) / 100.0 if calibration_errors else 0.0
    autocorrelation_penalty = abs(acf_results.get(1, {}).get('acf', 0))
    uncertainty_factor = quantile_spread
    base_coefficient = 0.25
    w_calib = 1.5
    w_acf = 0.5
    w_unc = 0.25
    dynamic_coefficient = base_coefficient + (w_calib * calibration_penalty) + (w_acf * autocorrelation_penalty) + (w_unc * uncertainty_factor)
    final_coefficient = np.clip(dynamic_coefficient, base_coefficient, 1.2)
    return final_coefficient

def assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse, calibration_results, acf_results, quantile_spread):
    """
    風險與預算評估調度中心。
    - 數據 <= 12個月：使用原始風險評分模型。
    - 數據 > 12個月：使用進階三層式預算模型。
    """
    if monthly_expenses is None or len(monthly_expenses) < 2:
        return ("無法判讀 (資料不足)", "資料過少，無法進行風險評估。", None, None, None, None, None, "極低可靠性", None, None, None, None, None, None, None)

    num_months = len(monthly_expenses)
    
    # 【核心改造】根據數據量選擇不同模型
    if num_months > 12:
        error_coefficient = 0.5
        if calibration_results and acf_results and quantile_spread is not None:
            error_coefficient = calculate_dynamic_error_coefficient(calibration_results, acf_results, quantile_spread)

        status, description, suggested_budget, data_reliability, components = \
            assess_risk_and_budget_advanced(monthly_expenses, error_coefficient, historical_rmse)
        
        error_buffer = components.get('error')

        # 為了保持與主函數的兼容性，將結果打包成原有的16元組格式
        return (status, description, suggested_budget,
                None, None, None, None, # dynamic_risk_coefficient, trend_score, volatility_score, shock_score
                data_reliability, error_coefficient, error_buffer, 
                components, # trend_scores slot is used for breakdown dict
                None, None, None, None) # volatility_scores, shock_scores, overall_score, risk_buffer

    # --- 以下為 num_months <= 12 的原始邏輯 ---
    data = monthly_expenses['Real_Amount'].values
    x = np.arange(num_months)

    if num_months < 6:
        recent_avg = np.mean(data[-3:]) if len(data) >= 3 else np.mean(data)
        buffer_factor = 0.15
        suggested_budget = recent_avg * (1 + buffer_factor)
        risk_buffer = recent_avg * buffer_factor
        status = "數據不足，使用替代公式"
        description = "基於近期平均實質支出加上15%風險緩衝。"
        data_reliability = "低度可靠 - 替代公式"
        return (status, description, suggested_budget, None, None, None, None, data_reliability, None, None, None, None, None, None, risk_buffer)
    
    # 適用於 6 <= num_months <= 12 的原始風險評估
    historical_factors = calculate_historical_factors(data)
    current_accel, current_crossover, current_autocorr, current_residuals = compute_trend_factors(data, x)
    current_vol_of_vol, current_downside_vol, current_kurt = compute_volatility_factors(data, current_residuals)
    current_max_shock, current_consecutive_shocks = compute_shock_factors(data, current_residuals)

    def get_thresholds(factor_name, default_thresholds):
        if historical_factors and historical_factors.get(factor_name) and len(historical_factors[factor_name]) > 4:
            return np.percentile(historical_factors[factor_name], [25, 50, 75, 90])
        return default_thresholds

    trend_scores = {
        'accel': percentile_score(current_accel, *get_thresholds('accel', [-0.5, 0, 0.5, 1])),
        'crossover': percentile_score(current_crossover, 0, 0, 0.5, 1),
        'autocorr': percentile_score(abs(current_autocorr), 0, 0.2, 0.5, 0.8)
    }
    volatility_scores = {
        'vol_of_vol': percentile_score(current_vol_of_vol, *get_thresholds('vol_of_vol', [0, 0.5, 1, 2])),
        'downside_vol': percentile_score(current_downside_vol, *get_thresholds('downside_vol', [0, 0.1, 0.2, 0.5])),
        'kurtosis': percentile_score(abs(current_kurt), *get_thresholds('kurtosis', [0, 1, 3, 5]))
    }
    shock_scores = {
        'max_shock_magnitude': percentile_score(current_max_shock, *get_thresholds('max_shock_magnitude', [0, 0.1, 0.2, 0.5])),
        'consecutive_shocks': percentile_score(current_consecutive_shocks, 0, 2, 4, 6)
    }

    trend_score = np.mean(list(trend_scores.values()))
    volatility_score = np.mean(list(volatility_scores.values()))
    shock_score = np.mean(list(shock_scores.values()))
    weights = (0.4, 0.35, 0.25)
    overall_score = (trend_score * weights[0]) + (volatility_score * weights[1]) + (shock_score * weights[2])

    drf = data_reliability_factor(num_months)
    max_risk_premium = 0.25
    base_premium = 0.10
    risk_score_term = (overall_score / 10) * max_risk_premium * drf
    base_uncertainty_term = base_premium * (1 - drf)
    dynamic_risk_coefficient = risk_score_term + base_uncertainty_term

    if overall_score > 7: status, description = "高風險", "多項風險因子顯示顯著風險，建議立即審視支出模式。"
    elif overall_score > 4: status, description = "中度風險", "風險因子處於中等水平，需持續監控財務狀況。"
    else: status, description = "低風險", "整體風險可控，但仍需保持適度警惕。"
    
    data_reliability = "中度可靠"

    suggested_budget = None
    risk_buffer = None
    error_buffer = None
    error_coefficient = None
    if p95 is not None and p75 is not None and predicted_value is not None:
        risk_buffer = p75 + (dynamic_risk_coefficient * (p95 - p75))
        
        if calibration_results and acf_results and quantile_spread is not None:
            error_coefficient = calculate_dynamic_error_coefficient(calibration_results, acf_results, quantile_spread)
        else:
            error_coefficient = 0.5 
        
        error_buffer = error_coefficient * historical_rmse if historical_rmse else 0
        suggested_budget = risk_buffer + error_buffer

    return (status, description, suggested_budget, dynamic_risk_coefficient, trend_score, volatility_score, shock_score,
            data_reliability, error_coefficient, error_buffer, 
            trend_scores, volatility_scores, shock_scores, overall_score, risk_buffer)

# --- 診斷儀表板函數 (v1.9.2 - 整合可自訂寬度設定) ---
# --- 新增：CJK 字元填充輔助函數 (用於表格對齊) ---
def pad_cjk(text, total_width, align='left'):
    """Pads a string to a specific display width, accounting for CJK characters."""
    try:
        # 使用 gbk 編碼可以較準確地計算中文字元寬度
        text_width = len(text.encode('gbk'))
    except UnicodeEncodeError:
        # 若 gbk 不支援某些字元，則使用備用方法
        text_width = sum(2 if '\u4e00' <= char <= '\u9fff' else 1 for char in text)
    
    padding = total_width - text_width
    if padding < 0: padding = 0
    
    if align == 'left':
        return text + ' ' * padding
    elif align == 'right':
        return ' ' * padding + text
    else: # center
        left_pad = padding // 2
        right_pad = padding - left_pad
        return ' ' * left_pad + text + ' ' * right_pad

def quantile_loss(y_true, y_pred, quantile):
    """計算分位數損失的核心數學邏輯。"""
    errors = y_true - y_pred
    return np.mean(np.maximum(quantile * errors, (quantile - 1) * errors))

def quantile_loss_report(y_true, quantile_preds, quantiles, colors):
    """產生「分位數損失分析」報告，使用 TABLE_CONFIG 控制排版。"""
    cfg = TABLE_CONFIG['quantile_loss']
    report = [f"{colors.WHITE}>>> 分位數損失分析 (風險情境誤差評估){colors.RESET}"]
    
    # 動態產生分隔線
    header_line = f"|{'-'*cfg['q']}|{'-'*cfg['loss']}|{'-'*cfg['interp']}|"
    report.append(header_line)
    
    # 表頭
    header = f"| {pad_cjk('分位數', cfg['q']-2)} | {pad_cjk('損失值', cfg['loss']-2, 'right')} | {pad_cjk('解釋', cfg['interp']-2)} |"
    report.append(header)
    report.append(header_line)

    for q in quantiles:
        preds = quantile_preds.get(q)
        if preds is None: continue
        
        # 確保 y_true 和 preds 的長度一致
        min_len = min(len(y_true), len(preds))
        loss = quantile_loss(y_true[:min_len], preds[:min_len], q)
        interp = "核心趨勢誤差" if q == 0.5 else ("常規波動誤差" if q in [0.25, 0.75] else "尾部風險誤差")
        label = f"{q*100:.0f}%"
        
        row = f"| {pad_cjk(label, cfg['q']-2)} | {f'{loss:,.2f}'.rjust(cfg['loss']-2)} | {pad_cjk(interp, cfg['interp']-2)} |"
        report.append(row)
        
    report.append(header_line)
    return "\n".join(report)

def model_calibration_analysis(y_true, quantile_preds, quantiles, colors):
    """產生「模型校準分析」報告，使用 TABLE_CONFIG 控制排版。"""
    cfg = TABLE_CONFIG['calibration']
    report = [f"{colors.WHITE}>>> 模型校準分析 (誠實度檢驗){colors.RESET}"]

    header_line = f"|{'-'*cfg['label']}|{'-'*cfg['freq']}|{'-'*cfg['assess']}|"
    report.append(header_line)
    header = f"| {pad_cjk('預測分位數 (信心)', cfg['label']-2)} | {pad_cjk('實際觀測頻率', cfg['freq']-2, 'right')} | {pad_cjk('評估結果', cfg['assess']-2)} |"
    report.append(header)
    report.append(header_line)
    
    for q in quantiles:
        preds = quantile_preds.get(q)
        if preds is None: continue
        
        min_len = min(len(y_true), len(preds))
        observed_freq = np.mean(y_true[:min_len] <= preds[:min_len]) * 100
        assessment = "非常準確" if abs(observed_freq - q*100) < 5 else "基本準確" if abs(observed_freq - q*100) < 10 else "略微高估風險" if observed_freq > q*100 else "明顯過於自信"
        label = f"{q*100:.0f}% (P{q*100:.0f})"
        freq_str = f"{observed_freq:.0f}%"
        
        row = f"| {pad_cjk(label, cfg['label']-2)} | {freq_str.rjust(cfg['freq']-2)} | {pad_cjk(assessment, cfg['assess']-2)} |"
        report.append(row)
        
    report.append(header_line)
    return "\n".join(report)

def residual_autocorrelation_diagnosis(residuals, n, colors):
    """產生「殘差自相關性診斷」報告，使用 TABLE_CONFIG 控制排版。"""
    cfg = TABLE_CONFIG['autocorrelation']
    sig_boundary = 2 / np.sqrt(n)
    report = [f"{colors.WHITE}>>> 殘差診斷 (規律性檢測){colors.RESET}", f"(樣本數 N = {n}, 顯著性邊界 ≈ {sig_boundary:.2f})"]
    
    header_line = f"|{'-'*cfg['lag']}|{'-'*cfg['acf']}|{'-'*cfg['sig']}|{'-'*cfg['meaning']}|"
    report.append(header_line)
    header = f"| {pad_cjk('延遲週期', cfg['lag']-2)} | {pad_cjk('自相關係數(ACF)', cfg['acf']-2, 'right')} | {pad_cjk('是否顯著', cfg['sig']-2, 'center')} | {pad_cjk('潛在意義', cfg['meaning']-2)} |"
    report.append(header)
    report.append(header_line)
    
    for lag in [1, 3, 6, 12]:
        if len(residuals) <= lag: continue
        
        acf = np.corrcoef(residuals[:-lag], residuals[lag:])[0, 1]
        is_significant = "是" if abs(acf) > sig_boundary else "否"
        meaning = ("短期慣性誤差" if lag==1 else "季度性規律" if lag==3 else "半年期規律" if lag==6 else "年度性規律") if is_significant == "是" else "無規律"
        lag_str = f"{lag} 個月"
        
        row = f"| {pad_cjk(lag_str, cfg['lag']-2)} | {f'{acf:.2f}'.rjust(cfg['acf']-2)} | {pad_cjk(is_significant, cfg['sig']-2, 'center')} | {pad_cjk(meaning, cfg['meaning']-2)} |"
        report.append(row)
        
    report.append(header_line)
    return "\n".join(report)

# --- MPI 3.0 評估套件 ---

def calculate_erai(y_true, y_pred_model, quantile_preds_model, wape_robust_model):
    """計算 ERAI (Ensemble Robust-Accuracy Index) 的核心組件分數。"""
    if y_true is None or len(y_true) < 2: return None
    
    model_errors = np.abs(y_true - y_pred_model)
    naive_pred = np.roll(y_true, 1); naive_pred[0] = y_true[0]
    benchmark_errors = np.abs(y_true - naive_pred)
    denominator = model_errors + benchmark_errors
    brae = np.divide(model_errors, denominator, out=np.full_like(model_errors, 0.5, dtype=float), where=denominator!=0)
    mbrae = np.mean(brae)
    umbrae = np.inf if mbrae >= 1.0 else mbrae / (1.0 - mbrae)
    
    quantiles_for_aql = [0.10, 0.25, 0.75, 0.90]
    model_losses = [quantile_loss(y_true, quantile_preds_model[q], q) for q in quantiles_for_aql if q in quantile_preds_model]
    aql_model = np.mean(model_losses) if model_losses else np.inf
    
    naive_residuals = y_true[1:] - y_true[:-1]
    if len(naive_residuals) == 0: naive_residuals = np.array([0])
    naive_quantiles = np.percentile(naive_residuals, [q * 100 for q in quantiles_for_aql])
    naive_losses = [quantile_loss(y_true[1:], (y_true[:-1] + nq), q) for nq, q in zip(naive_quantiles, quantiles_for_aql)]
    aql_naive = np.mean(naive_losses) if naive_losses else np.inf
    
    score_rel = max(0, 1 - umbrae)
    score_prec = 1 - (wape_robust_model / 100.0) if wape_robust_model is not None else 0
    score_risk = max(0, 1 - (aql_model / aql_naive)) if aql_naive > 1e-9 else 0
    
    weights = {'rel': 0.4, 'prec': 0.4, 'risk': 0.2}
    erai_score = (weights['rel'] * score_rel) + (weights['prec'] * score_prec) + (weights['risk'] * score_risk)
    
    return erai_score

# 【新增】MPI 3.0 - 未來穩定性分數 (FSS) 計算
def calculate_fss(prequential_results, mean_expense):
    """
    計算未來穩定性分數 (FSS)，這是 MPI 3.0 的核心支柱。
    FSS 綜合評估模型在前向測試中的偏誤、一致性與預期準確率。
    """
    if prequential_results is None:
        return {'fss_score': 0, 'bias_penalty': 1, 'consistency_score': 0, 'expected_accuracy': 0}
        
    errors = prequential_results["errors"]
    true_values = prequential_results["true_values"]
    
    # 1. 偏誤懲罰 (Bias Penalty, BP)
    cfe = np.sum(errors)
    sum_abs_true = np.sum(np.abs(true_values))
    bias_penalty = min(1, abs(cfe / sum_abs_true) * 5) if sum_abs_true > 0 else 1

    # 2. 一致性分數 (Consistency Score, CS)
    rmse_e = np.std(errors, ddof=1) if len(errors) > 1 else 0
    consistency_score = max(0, 1 - (rmse_e / mean_expense)) if mean_expense > 0 else 0
    
    # 3. 預期準確率 (Expected Accuracy, EA)
    p_wape = 100 * np.sum(np.abs(errors)) / sum_abs_true if sum_abs_true > 0 else 100
    expected_accuracy = max(0, 1 - (p_wape / 100.0))
    
    # 組合 FSS
    fss_score = (0.4 * (1 - bias_penalty)) + (0.3 * consistency_score) + (0.3 * expected_accuracy)

    return {
        'fss_score': fss_score, 
        'bias_penalty': bias_penalty, 
        'consistency_score': consistency_score, 
        'expected_accuracy': expected_accuracy
    }
    
# 【升級】MPI 3.0 雙維度評級系統
def calculate_mpi_3_0_and_rate(y_true, historical_pred, global_wape, erai_score, mpi_percentile_rank, fss_score):
    """
    根據 MPI 3.0 雙維度矩陣計算最終評級。
    此系統同時考量模型的「綜合預測能力 (MPI 3.0 Score)」與「預測穩定性 (P-Rank)」。
    """
    # 1. 計算 AAS (絕對準確度分數)
    wape_score = 1 - (global_wape / 100.0) if global_wape is not None else 0
    ss_res = np.sum((y_true - historical_pred)**2)
    ss_tot = np.sum((y_true - np.mean(y_true))**2)
    r_squared = 1 - (ss_res / ss_tot) if ss_tot > 1e-9 else 0
    r2_score = max(0, r_squared)
    aas = 0.7 * wape_score + 0.3 * r2_score
    
    # 2. 計算 RSS (相對優越性分數)
    rss = erai_score if erai_score is not None else 0
    
    # 3. 組合 MPI 3.0 總分
    mpi_3_0_score = (0.25 * aas) + (0.25 * rss) + (0.50 * fss_score)
    
    rating = "F" # 預設最低評級
    if mpi_percentile_rank is None:
        rating = "N/A"
    else:
        prank = mpi_percentile_rank
        score = mpi_3_0_score

        if prank > 90:
            if score >= 0.85: rating = "A+"
            elif score >= 0.75: rating = "A"
            elif score >= 0.60: rating = "B+"
            elif score >= 0.50: rating = "C"
            else: rating = "D"
        elif prank > 70:
            if score >= 0.85: rating = "A"
            elif score >= 0.75: rating = "A-"
            elif score >= 0.60: rating = "B"
            elif score >= 0.50: rating = "C-"
            else: rating = "D-"
        elif prank > 40:
            if score >= 0.85: rating = "B+"
            elif score >= 0.75: rating = "B-"
            elif score >= 0.60: rating = "C+"
            elif score >= 0.50: rating = "D"
            else: rating = "F"
        else: # < 40%
            if score >= 0.85: rating = "B"
            elif score >= 0.75: rating = "C"
            elif score >= 0.60: rating = "C-"
            elif score >= 0.50: rating = "D-"
            else: rating = "F"
            
    # 評級解釋字典
    suggestions = {
        "A+": "頂級信賴。模型的綜合能力與穩定性均達到最高標準。其預算建議可作為**關鍵長期財務規劃**的核心依據。",
        "A": "高度可靠。模型表現出色且穩定，預測結果值得信賴。非常適合用於設定**常規的月度儲蓄目標與預算**。",
        "A-": "穩健可靠。模型表現良好，且穩定性高。其預算建議是**設定日常開銷管理**的堅實基礎。",
        "B+": "良好且穩定。模型的綜合表現不錯，且穩定性值得肯定。其預算建議具有**很高的參考價值**。",
        "B": "表現良好，但穩定性中等。模型具備不錯的預測能力，但其表現在不同數據週期下可能存在波動。可作為**趨勢判斷的參考**。",
        "B-": "表現尚可，穩定性中等。模型具備基礎預測能力，建議在採納其預算時，結合自身判斷，並**保留一定的彈性**。",
        "C+": "基礎可用。模型的預測結果可作為一個**大致的趨勢方向**，但不建議完全依賴其精確數值。",
        "C": "僅供參考。模型在綜合能力或穩定性上存在短板，其預測可能存在較大誤差或不確定性。",
        "C-": "需謹慎對待。模型的預測能力較弱，建議在採納前，詳細檢視報告中的「前向測試儀表板」，了解其主要缺陷。",
        "D": "存在明顯問題。模型在綜合能力和穩定性上均表現不佳，其預測結果參考價值很低。",
        "D-": "建議停用。模型存在嚴重缺陷，其預測結果可能產生誤導。",
        "F": "完全不可信。模型的預測能力已低於基準水平，繼續使用弊大於利。請檢查原始數據或等待積累更多資料。",
        "N/A": "交叉驗證失敗，無法進行混合評級。"
    }
                
    return {
        'mpi_score': mpi_3_0_score, 
        'rating': rating, 
        'suggestion': suggestions.get(rating, "未知評級。"),
        'components': {'absolute_accuracy': aas, 'relative_superiority': rss, 'future_stability': fss_score}
    }

def perform_internal_benchmarking(y_true, historical_ensemble_pred, is_shock_flags):
    """
    執行內部基準化，評估集成模型並給予業界標準評級。
    """
    ensemble_residuals = y_true - historical_ensemble_pred
    clean_residuals = ensemble_residuals[~is_shock_flags]
    clean_y_true = y_true[~is_shock_flags]
    
    ensemble_wape_robust = (np.sum(np.abs(clean_residuals)) / np.sum(np.abs(clean_y_true))) * 100 if np.sum(np.abs(clean_y_true)) > 1e-9 else 100.0
    ensemble_quantile_preds = {q: historical_ensemble_pred + np.percentile(ensemble_residuals, q*100) for q in [0.1, 0.25, 0.75, 0.9]}
    ensemble_erai_score = calculate_erai(y_true, historical_ensemble_pred, ensemble_quantile_preds, ensemble_wape_robust)
    
    return {'erai_score': ensemble_erai_score}

# --- 【新增】進度條輔助函數 ---
def print_progress_bar(iteration, total, prefix='', suffix='', decimals=1, length=50, fill='█', print_end="\r"):
    """
    為長時間執行的迴圈打印一個文字進度條。
    """
    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filled_length = int(length * iteration // total)
    bar = fill * filled_length + '-' * (length - filled_length)
    sys.stdout.write(f'\r{prefix} |{bar}| {percent}% {suffix}')
    sys.stdout.flush()
    if iteration == total: 
        sys.stdout.write('\n')
        sys.stdout.flush()

# --- 【升級】增強型前向測試 (Prequential Analysis) 框架 ---
def run_prequential_evaluation(full_df, colors, min_train_size=18, drift_window_size=12):
    """
    執行增強型前向測試，內建概念飄移偵測與自適應遺忘機制。
    """
    total_len = len(full_df)
    errors, predictions, true_values = [], [], []
    drift_points = []
    
    color_cyan = colors.CYAN if colors else ''
    color_reset = colors.RESET if colors else ''
    
    training_start_index = 0
    error_window = deque(maxlen=drift_window_size)
    
    num_tests = total_len - min_train_size
    print(f"\n{color_cyan}正在執行增強型前向測試 (含概念飄移偵測)，共 {num_tests} 次滾動預測...{color_reset}")
    print_progress_bar(0, num_tests, prefix='進度:', suffix='完成', length=40)
    
    for t_step in range(min_train_size, total_len):
        # 動態調整訓練窗口
        train_df = full_df.iloc[training_start_index:t_step]
        true_value = full_df.iloc[t_step]['Real_Amount']
        
        pred_seq, _, _, _, _, _, _ = run_full_ensemble_pipeline(
            train_df, steps_ahead=1, colors=colors, verbose=False
        )
        
        if pred_seq is not None and len(pred_seq) > 0:
            pred = pred_seq[0]
            error = true_value - pred
            predictions.append(pred)
            true_values.append(true_value)
            errors.append(error)
            error_window.append(error)
            
            # 概念飄移偵測
            if len(error_window) == drift_window_size:
                half_window = drift_window_size // 2
                reference_errors = np.array(list(error_window)[:half_window])
                detection_errors = np.array(list(error_window)[half_window:])
                
                ref_mean, ref_std = np.mean(reference_errors), np.std(reference_errors)
                detect_mean = np.mean(detection_errors)
                
                # 如果近期誤差均值偏離歷史誤差2個標準差以上，則認為發生飄移
                if ref_std > 1e-6 and abs(detect_mean - ref_mean) > 2 * ref_std:
                    drift_points.append(t_step)
                    # 觸發遺忘機制：更新下一次訓練的起點
                    training_start_index = max(0, t_step - min_train_size)
                    error_window.clear() # 清空窗口以重新建立基準

        print_progress_bar(t_step - min_train_size + 1, num_tests, prefix='進度:', suffix='完成', length=40)

    print("增強型前向測試完成。")
    if not errors:
        return None
    
    return {
        "errors": np.array(errors),
        "predictions": np.array(predictions),
        "true_values": np.array(true_values),
        "drift_points": drift_points
    }

# --- 【升級】將前向測試報告拆分為兩個獨立函數 ---
def format_prequential_metrics_report(results, mean_expense, colors):
    """
    格式化前向測試的量化指標部分。
    """
    if results is None:
        return ""

    errors = results["errors"]
    true_values = results["true_values"]
    
    # 1. 系統性偏誤 (Bias)
    cfe = np.sum(errors)
    sum_abs_true = np.sum(np.abs(true_values))
    
    bias_direction_text = ""
    # 【錯誤修正】使用 cfe 而非未定義的 final_cfe
    if cfe > (mean_expense * 0.05):
        bias_direction_text = "，持續性地低估實際支出"
    elif cfe < -(mean_expense * 0.05):
        bias_direction_text = "，持續性地高估實際支出"

    cfe_ratio = cfe / sum_abs_true if sum_abs_true > 0 else 0
    mid_point = len(errors) // 2
    drift_ratio = 0
    if mid_point > 1:
        drift = np.mean(errors[mid_point:]) - np.mean(errors[:mid_point])
        drift_ratio = drift / mean_expense if mean_expense > 0 else 0

    if abs(cfe_ratio) < 0.1 and abs(drift_ratio) < 0.1:
        cfe_assessment = "低 (模型預測的高估與低估能有效自我校正)"
    elif abs(cfe_ratio) < 0.3 and abs(drift_ratio) < 0.25:
        cfe_assessment = f"中 (模型存在輕微的單向預測漂移{bias_direction_text})"
    else:
        cfe_assessment = f"高 (模型存在顯著的系統性偏誤{bias_direction_text})"

    # 2. 預測一致性 (Consistency)
    rmse_e = np.std(errors, ddof=1) if len(errors) > 1 else 0
    rmse_e_ratio = (rmse_e / mean_expense) * 100 if mean_expense > 0 else 0
    
    rmse_e_assessment = "高度穩定" if rmse_e_ratio < 15 else "中度穩定" if rmse_e_ratio < 35 else "表現不穩"

    # 3. 預期未來誤差 (P-WAPE)
    p_wape = 100 * np.sum(np.abs(errors)) / sum_abs_true if sum_abs_true > 0 else 0
    p_wape_assessment = "優秀" if p_wape < 15 else "良好" if p_wape < 30 else "待改進"

    report = [
        f"\n{colors.CYAN}{colors.BOLD}>>> 前向測試儀表板 (動態效能指標){colors.RESET}",
        f"  - {colors.BOLD}系統性偏誤 (Bias):{colors.RESET} {cfe_assessment}",
        f"  - {colors.BOLD}預測一致性 (Consistency):{colors.RESET} {rmse_e_assessment} (誤差標準差: {rmse_e:,.2f})",
        f"  - {colors.BOLD}預期未來誤差 (P-WAPE):{colors.RESET} {p_wape:.2f}% ({p_wape_assessment})",
    ]
    return "\n".join(report)

def format_adaptive_dynamics_report(results, full_df, colors):
    """
    格式化動態適應性評估的質化分析部分。
    """
    if results is None:
        return ""
    
    num_simulations = len(results["errors"])
    drift_points = results["drift_points"]
    num_drifts = len(drift_points)

    drift_detection_line = f"  - {colors.BOLD}概念飄移偵測:{colors.RESET} 在過去 {num_simulations} 個月的模擬中，共偵測到 {num_drifts} 次顯著的模式轉變。"
    
    if num_drifts == 0:
        last_drift_line = f"  - {colors.BOLD}最後飄移時間:{colors.RESET} 未偵測到顯著模式轉變，顯示近期模式具備高度連續性。"
        adaptation_strategy_line = ""
    else:
        last_drift_index = drift_points[-1]
        last_drift_date_str = full_df.iloc[last_drift_index]['Parsed_Date'].strftime('%Y-%m')
        
        # 評估近期穩定性：如果最後一次飄移發生在超過6個測試步之前
        steps_since_last_drift = (len(full_df) - 1) - last_drift_index
        if steps_since_last_drift > 6:
            stability_comment = "(近期模式相對穩定)"
        else:
            stability_comment = f"({colors.YELLOW}近期模式處於變動期{colors.RESET})"
        
        last_drift_line = f"  - {colors.BOLD}最後飄移時間:{colors.RESET} 約在 {last_drift_date_str} {stability_comment}"
        adaptation_strategy_line = f"  - {colors.BOLD}模型適應策略:{colors.RESET} 已啟用「動態遺忘機制」，在偵測到飄移後自動聚焦於近期數據進行學習。"

    report = [
        f"\n{colors.CYAN}{colors.BOLD}>>> 動態適應性評估 (基於增強型前向測試){colors.RESET}",
        drift_detection_line,
        last_drift_line,
    ]
    if adaptation_strategy_line:
        report.append(adaptation_strategy_line)
        
    return "\n".join(report)

# 【升級】格式化詳細風險因子報告的輔助函數
def format_detailed_risk_analysis_report(dynamic_risk_coefficient, error_coefficient, overall_score, 
                                       trend_score, trend_scores_detail, 
                                       vol_score, vol_scores_detail, 
                                       shock_score, shock_scores_detail, colors):
    """
    將風險因子的詳細分數格式化為一個多區塊的詳細報告。
    """
    report = []
    
    if dynamic_risk_coefficient is not None:
        report.append(f"{colors.WHITE}動態風險係數: {dynamic_risk_coefficient:.3f}{colors.RESET}")
    if error_coefficient is not None:
        report.append(f"{colors.WHITE}模型誤差係數: {error_coefficient:.3f}{colors.RESET}")
    
    report.append(f"\n{colors.WHITE}>>> 詳細風險因子分析{colors.RESET}")
    report.append(f"{colors.BOLD}總體風險評分: {overall_score:.2f}/10{colors.RESET}")
    report.append(f"  └ 權重配置: 趨勢(40%) + 波動(35%) + 衝擊(25%)")

    # 趨勢風險
    report.append(f"\n{colors.WHITE}趨勢風險因子:{colors.RESET}")
    report.append(f"  - 趨勢加速度: {trend_scores_detail['accel']:.1f}/10")
    report.append(f"  - 滾動平均交叉: {trend_scores_detail['crossover']:.1f}/10")
    report.append(f"  - 殘差自相關性: {trend_scores_detail['autocorr']:.1f}/10")
    report.append(f"  - {colors.BOLD}趨勢風險得分: {trend_score:.2f}/10{colors.RESET}")

    # 波動風險
    report.append(f"\n{colors.WHITE}波動風險因子:{colors.RESET}")
    report.append(f"  - 波動的波動性: {vol_scores_detail['vol_of_vol']:.1f}/10")
    report.append(f"  - 下行波動率: {vol_scores_detail['downside_vol']:.1f}/10")
    report.append(f"  - 峰態: {vol_scores_detail['kurtosis']:.1f}/10")
    report.append(f"  - {colors.BOLD}波動風險得分: {vol_score:.2f}/10{colors.RESET}")

    # 衝擊風險
    report.append(f"\n{colors.WHITE}衝擊風險因子:{colors.RESET}")
    report.append(f"  - 最大衝擊幅度: {shock_scores_detail['max_shock_magnitude']:.1f}/10")
    report.append(f"  - 連續正向衝擊: {shock_scores_detail['consecutive_shocks']:.1f}/10")
    report.append(f"  - {colors.BOLD}衝擊風險得分: {shock_score:.2f}/10{colors.RESET}")
    
    return "\n".join(report)

# --- 【★★★ 此處為核心修正 ★★★】 ---
def run_monte_carlo_cv(full_df, base_models, n_iterations=100, colors=None):
    """執行蒙地卡羅交叉驗證以生成動態MPI評級基準。"""
    mpi_scores = []
    total_len = len(full_df)
    min_train_size = 18
    val_ratio = 0.25
    min_val_size = max(1, int(total_len * val_ratio))

    if total_len < min_train_size + min_val_size: 
        return None, None

    color_cyan = colors.CYAN if colors else ''
    color_reset = colors.RESET if colors else ''
    
    print(f"\n{color_cyan}正在執行蒙地卡羅交叉驗證以建立動態評級基準 (共 {n_iterations} 次迭代)...{color_reset}")
    print_progress_bar(0, n_iterations, prefix='進度:', suffix='完成', length=40)

    for i in range(n_iterations):
        train_len = int(total_len * (1 - val_ratio))
        start_index = np.random.randint(0, total_len - train_len - min_val_size + 1)
        end_train_index = start_index + train_len
        
        train_df = full_df.iloc[start_index:end_train_index].reset_index(drop=True)
        val_df = full_df.iloc[end_train_index:].reset_index(drop=True)

        if len(train_df) < min_train_size or len(val_df) == 0: continue
        
        y_train_true = train_df['Real_Amount'].values
        y_val_true = val_df['Real_Amount'].values
        
        # 1. 在訓練集上運行完整的集成流程（但禁用內部打印）來獲取預測
        val_pred_seq, _, _, _, _, _, _ = \
            run_full_ensemble_pipeline(train_df, steps_ahead=len(val_df), colors=colors, verbose=False)
        
        if val_pred_seq is None or len(val_pred_seq) != len(y_val_true):
            continue
            
        # 2. 【核心修正】計算此次迭代「真實」的MPI分數
        val_pred = np.array(val_pred_seq)
        val_residuals = y_val_true - val_pred
        sum_abs_val_true = np.sum(np.abs(y_val_true))
        val_wape = (np.sum(np.abs(val_residuals)) / sum_abs_val_true * 100) if sum_abs_val_true > 1e-9 else 100.0

        val_wape_robust = val_wape 
        val_quantile_preds = {q: val_pred + np.percentile(val_residuals, q*100) for q in [0.10, 0.25, 0.75, 0.90]}

        rss_val = calculate_erai(y_val_true, val_pred, val_quantile_preds, val_wape_robust)
        if rss_val is None: rss_val = 0

        val_wape_score = 1 - (val_wape / 100.0)
        ss_res_val = np.sum(val_residuals**2)
        ss_tot_val = np.sum((y_val_true - np.mean(y_val_true))**2)
        r2_val = 1 - (ss_res_val / ss_tot_val) if ss_tot_val > 1e-9 else 0
        r2_score_val = max(0, r2_val)
        aas_val = 0.7 * val_wape_score + 0.3 * r2_score_val
        
        # 在CV中，我們無法執行前向測試，因此FSS設為中性值0.5進行近似
        fss_val_approx = 0.5
        mpi_score_val = (0.25 * aas_val) + (0.25 * rss_val) + (0.50 * fss_val_approx)
        
        if np.isfinite(mpi_score_val): mpi_scores.append(mpi_score_val)
        
        print_progress_bar(i + 1, n_iterations, prefix='進度:', suffix='完成', length=40)
    
    print("動態基準計算完成。")
    if not mpi_scores: 
        return None, None
        
    p25, p50, p85 = np.percentile(mpi_scores, [25, 50, 85])
    return {'p25': p25, 'p50': p50, 'p85': p85}, mpi_scores

def compute_calibration_results(y_true, quantile_preds, quantiles):
    """計算模型校準結果，返回字典形式。"""
    calibration_results = {}
    for q in quantiles:
        preds = quantile_preds.get(q)
        if preds is None:
            continue
        min_len = min(len(y_true), len(preds))
        observed_freq = np.mean(y_true[:min_len] <= preds[:min_len])
        calibration_results[q] = {'quantile': q, 'observed_freq': observed_freq}
    return calibration_results

def compute_acf_results(residuals, n):
    """計算殘差自相關性結果，返回字典形式。"""
    sig_boundary = 2 / np.sqrt(n)
    acf_results = {}
    for lag in [1, 3, 6, 12]:
        if len(residuals) <= lag:
            continue
        acf = np.corrcoef(residuals[:-lag], residuals[lag:])[0, 1]
        is_significant = abs(acf) > sig_boundary
        acf_results[lag] = {'acf': acf, 'is_significant': is_significant}
    return acf_results

def compute_quantile_spread(p25, p75, predicted_value):
    """計算標準化的分位數範圍（例如 (P75 - P25) / predicted_value）。"""
    if predicted_value is None or predicted_value == 0:
        return 0.0  # 避免除零
    spread = (p75 - p25) / predicted_value if p75 is not None and p25 is not None else 0.0
    return spread

# --- 【新增】IRLS 穩健迴歸引擎 ---
def huber_robust_regression(x, y, steps_ahead, t_const=1.345, max_iter=100, tol=1e-6):
    """
    使用迭代重加權最小平方法 (IRLS) 和 Huber 權重進行穩健迴歸。
    """
    X = np.c_[np.ones(len(x)), x]
    # Step 1: 初始擬合
    slope, intercept, _, _, _ = linregress(x, y)
    beta = np.array([intercept, slope])

    for _ in range(max_iter):
        beta_old = beta.copy()
        
        # 計算殘差
        y_pred = X @ beta
        residuals = y - y_pred
        
        # Step 2: 估計誤差尺度 (MAD)
        scale = median_abs_deviation(residuals, scale='normal')
        if scale < 1e-6: scale = 1e-6  # 避免除零

        # Step 3: 標準化殘差
        z = residuals / scale
        
        # Step 4: 計算 Huber 權重
        weights = np.ones_like(z)
        outliers = np.abs(z) > t_const
        weights[outliers] = t_const / np.abs(z[outliers])
        
        # Step 5: 執行加權最小平方法 (WLS)
        W_sqrt = np.sqrt(weights)
        X_w = X * W_sqrt[:, np.newaxis]
        y_w = y * W_sqrt
        beta = np.linalg.lstsq(X_w, y_w, rcond=None)[0]
        
        # Step 6: 檢查收斂
        if np.sum(np.abs(beta - beta_old)) < tol:
            break

    # 使用最終的穩健係數進行預測和計算
    historical_pred = X @ beta
    final_residuals = y - historical_pred
    
    # 預測未來值
    future_x = np.arange(len(x) + 1, len(x) + steps_ahead + 1)
    predicted_values = beta[0] + beta[1] * future_x
    
    # 近似的信賴區間
    dof = len(x) - 2
    if dof <= 0: return predicted_values, historical_pred, final_residuals, None, None
    
    mse_robust = np.sum(final_residuals**2) / dof
    se = np.sqrt(mse_robust * (1 + 1/len(x) + (future_x - np.mean(x))**2 / np.sum((x - np.mean(x))**2))) if len(future_x) > 0 else np.sqrt(mse_robust)
    t_val = t.ppf(0.975, dof)
    lower_seq = predicted_values - t_val * se
    upper_seq = predicted_values + t_val * se

    return predicted_values, historical_pred, final_residuals, lower_seq, upper_seq

# --- 模型堆疊集成 (Stacking Ensemble) 總引擎 ---

# Level 0 基礎模型 (Base Models)
def train_predict_huber(x_train, y_train, x_predict, t_const=1.345, max_iter=100, tol=1e-6):
    """
    Huber 穩健迴歸 (Huber Robust Regression)。
    """
    if len(x_train) < 2:
        return np.full(len(x_predict), np.mean(y_train) if len(y_train) > 0 else 0)

    X_train_b = np.c_[np.ones(len(x_train)), x_train]
    
    try:
        slope, intercept, _, _, _ = linregress(x_train, y_train)
        beta = np.array([intercept, slope])
    except ValueError:
        beta = np.array([np.mean(y_train), 0])

    for _ in range(max_iter):
        beta_old = beta.copy()
        residuals = y_train - (X_train_b @ beta)
        scale = median_abs_deviation(residuals, scale='normal')
        if scale < 1e-6: scale = 1e-6
        z = residuals / scale
        weights = np.ones_like(z)
        outliers = np.abs(z) > t_const
        weights[outliers] = t_const / np.abs(z[outliers])
        W_sqrt = np.sqrt(weights)
        X_w = X_train_b * W_sqrt[:, np.newaxis]
        y_w = y_train * W_sqrt
        
        try:
            beta = np.linalg.lstsq(X_w, y_w, rcond=None)[0]
        except np.linalg.LinAlgError:
            beta = beta_old
            break
            
        if np.sum(np.abs(beta - beta_old)) < tol:
            break
            
    X_predict_b = np.c_[np.ones(len(x_predict)), x_predict]
    return X_predict_b @ beta

def train_predict_poly(x_train, y_train, x_predict, degree=2):
    """多項式迴歸 (Polynomial Regression)。"""
    if len(x_train) < degree + 1: return np.full(len(x_predict), np.mean(y_train) if len(y_train) > 0 else 0)
    coeffs = np.polyfit(x_train, y_train, degree)
    p = np.poly1d(coeffs)
    return p(x_predict)

def train_predict_des(y_train, predict_steps, alpha=0.5, beta=0.5):
    """霍爾特線性趨勢模型 (Holt's Linear Trend Method)。"""
    if len(y_train) < 2: return np.full(predict_steps, y_train[0] if len(y_train) > 0 else 0)
    level, trend = y_train[0], y_train[1] - y_train[0]
    for i in range(1, len(y_train)):
        level_old, trend_old = level, trend
        level = alpha * y_train[i] + (1 - alpha) * (level_old + trend_old)
        trend = beta * (level - level_old) + (1 - beta) * trend_old
    return level + trend * np.arange(1, predict_steps + 1)

def train_predict_seasonal(df_train, predict_steps, seasonal_period=12):
    """時間序列分解法 (Classical Time Series Decomposition)。"""
    if len(df_train) < 2 * seasonal_period:
        return np.full(predict_steps, np.mean(df_train['Real_Amount']))

    deseasonalized_data, seasonal_indices = seasonal_decomposition(df_train)
    trend_component = deseasonalized_data['Deseasonalized'].values
    
    x_trend = np.arange(len(trend_component))
    if len(x_trend) < 2: return np.full(predict_steps, np.mean(df_train['Real_Amount']))

    slope, intercept, _, _, _ = linregress(x_trend, trend_component)
    future_x = np.arange(len(x_trend), len(x_trend) + predict_steps)
    trend_forecast = intercept + slope * future_x
    
    last_observed_month = df_train['Parsed_Date'].iloc[-1].month
    seasonal_forecast = []
    for i in range(1, predict_steps + 1):
        future_month = (last_observed_month + i -1) % 12 + 1
        seasonal_forecast.append(seasonal_indices.get(future_month, 1.0))

    return trend_forecast * np.array(seasonal_forecast)

def train_predict_naive(y_train, predict_steps):
    """單純預測法 (Naive Method)。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    last_value = y_train[-1]
    return np.full(predict_steps, last_value)

def train_predict_rolling_median(y_train, predict_steps, window_size=6):
    """滾動中位數預測 (Rolling Median Forecast)。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    actual_window = min(len(y_train), window_size)
    if actual_window == 0:
        return np.zeros(predict_steps)
    median_value = np.median(y_train[-actual_window:])
    return np.full(predict_steps, median_value)

def train_predict_global_median(y_train, predict_steps):
    """全局中位數預測 (Global Median Forecast)。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    median_value = np.median(y_train)
    return np.full(predict_steps, median_value)

def train_predict_drift(y_train, predict_steps):
    """漂移法 (Drift Method)。"""
    if len(y_train) < 2:
        return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)
    
    first_value = y_train[0]
    last_value = y_train[-1]
    drift = (last_value - first_value) / (len(y_train) - 1)
    
    predictions = [last_value + (i * drift) for i in range(1, predict_steps + 1)]
    return np.array(predictions)

def train_predict_seasonal_naive(y_train, predict_steps, seasonal_period=12):
    """季節性單純預測法 (Seasonal Naive Method)。"""
    if len(y_train) < seasonal_period:
        return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)

    predictions = []
    for i in range(1, predict_steps + 1):
        idx = len(y_train) - seasonal_period + ((i - 1) % seasonal_period)
        predictions.append(y_train[idx])
    
    return np.array(predictions)

def train_predict_moving_average(y_train, predict_steps, window_size=6):
    """移動平均預測 (Moving Average Forecast)。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    
    actual_window = min(len(y_train), window_size)
    if actual_window == 0:
        return np.zeros(predict_steps)
    
    mean_value = np.mean(y_train[-actual_window:])
    return np.full(predict_steps, mean_value)

# 【方法一 新增模型】
def train_predict_ses(y_train, predict_steps, alpha=0.5):
    """
    簡易指數平滑法 (Simple Exponential Smoothing, SES)。
    適用於無明顯趨勢或季節性的數據序列。
    """
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    
    smoothed = np.zeros_like(y_train, dtype=float)
    smoothed[0] = y_train[0]
    for i in range(1, len(y_train)):
        smoothed[i] = alpha * y_train[i] + (1 - alpha) * smoothed[i-1]
        
    # 對於無趨勢模型，未來預測值等於最後一個平滑值
    return np.full(predict_steps, smoothed[-1])

# 【方法一 新增模型與錯誤修正】
def train_predict_theta(x_train, y_train, x_predict, theta=2.0):
    """
    Theta 趨勢法。
    一種結合線性趨勢外推與指數平滑的穩健預測模型。
    """
    n = len(y_train)
    if n < 2:
        return np.full(len(x_predict), y_train[-1] if n > 0 else 0)

    # 1. 使用提供的 x_train 和 y_train 擬合長期趨勢線
    try:
        slope, intercept, _, _, _ = linregress(x_train, y_train)
    except ValueError:
        return np.full(len(x_predict), np.mean(y_train))
    
    # 計算歷史數據的趨勢線
    trend_line_hist = intercept + slope * x_train

    # 2. 構建並平滑Theta線
    theta_line_train = theta * (y_train - trend_line_hist) + trend_line_hist
    
    # 3. 對Theta線進行簡易指數平滑 (SES) 預測
    forecast_ses = train_predict_ses(theta_line_train, predict_steps=len(x_predict))

    # 4. 預測未來的趨勢線
    forecast_trend = intercept + slope * x_predict
    
    # 5. 組合預測結果
    final_forecast = (1/theta) * forecast_ses + (1 - 1/theta) * forecast_trend
    return final_forecast

# --- 【★★★ 此處為已修正的函數 ★★★】 ---
def train_greedy_forward_ensemble(X_meta, y_true, model_keys, n_iterations=20, colors=None, verbose=True):
    """
    使用 Caruana 的貪婪前向選擇法訓練元模型 (已修正為允許重複選擇的穩健版本)。
    """
    n_samples, n_models = X_meta.shape
    ensemble_model_indices = []
    
    # 確保 verbose 關閉時不打印
    if verbose:
        color_cyan = colors.CYAN if colors else ''
        color_reset = colors.RESET if colors else ''
        print(f"\n{color_cyan}正在執行元模型團隊建設 (貪婪前向選擇法)...{color_reset}")
    
    def rmse(y_true, y_pred):
        return np.sqrt(np.mean((y_true - y_pred)**2))

    # 初始化時，集成模型是空的，預測為0
    ensemble_predictions = np.zeros(n_samples)
    
    for i in range(n_iterations):
        best_model_idx_this_round = -1
        # 初始最低誤差設為當前集成模型的誤差
        lowest_error = rmse(y_true, ensemble_predictions) if i > 0 else np.inf
        
        for model_idx in range(n_models):
            candidate_model_preds = X_meta[:, model_idx]
            # 測試將下一個模型加入團隊後的效果
            temp_predictions = (ensemble_predictions * i + candidate_model_preds) / (i + 1)
            current_error = rmse(y_true, temp_predictions)
            
            if current_error < lowest_error:
                lowest_error = current_error
                best_model_idx_this_round = model_idx
        
        # 如果找到了能改善模型的選擇，就將其加入團隊
        if best_model_idx_this_round != -1:
            ensemble_model_indices.append(best_model_idx_this_round)
            best_model_preds = X_meta[:, best_model_idx_this_round]
            ensemble_predictions = (ensemble_predictions * i + best_model_preds) / (i + 1)
        else:
            # 如果遍歷所有模型都無法改善結果，就提前停止
            break
            
    if verbose:
        print("團隊建設完成。")
        
    return ensemble_model_indices, None

def run_stacked_ensemble_model(monthly_expenses_df, steps_ahead, n_folds=5, ensemble_size=20, colors=None, verbose=True):
    data = monthly_expenses_df['Real_Amount'].values
    x = np.arange(1, len(data) + 1)
    n_samples = len(data)
    
    # 【方法一整合點】將新模型加入基礎模型庫
    base_models = {
        'poly': train_predict_poly, 'huber': train_predict_huber, 'des': train_predict_des, 'drift': train_predict_drift,
        'seasonal': train_predict_seasonal, 'seasonal_naive': train_predict_seasonal_naive, 'naive': train_predict_naive,
        'moving_average': train_predict_moving_average, 'rolling_median': train_predict_rolling_median, 'global_median': train_predict_global_median,
        'ses': train_predict_ses, 'theta': train_predict_theta,
    }
    
    model_keys = list(base_models.keys())
    
    meta_features = np.zeros((n_samples, len(base_models)))
    fold_indices = np.array_split(np.arange(n_samples), n_folds)
    
    for i in range(n_folds):
        train_idx = np.concatenate([fold_indices[j] for j in range(n_folds) if i != j])
        val_idx = fold_indices[i]
        
        if len(train_idx) == 0: continue

        x_train, y_train, df_train = x[train_idx], data[train_idx], monthly_expenses_df.iloc[train_idx]
        x_val = x[val_idx]
        
        for j, key in enumerate(model_keys):
            model_func = base_models[key]
            if key in ['seasonal']:
                 meta_features[val_idx, j] = model_func(df_train, len(x_val))
            elif key in ['poly', 'huber', 'theta']: # 【錯誤修正】確保 theta 使用正確的呼叫方式
                 meta_features[val_idx, j] = model_func(x_train, y_train, x_val)
            else:
                 meta_features[val_idx, j] = model_func(y_train, len(x_val))

    selected_indices, _ = train_greedy_forward_ensemble(meta_features, data, model_keys, n_iterations=ensemble_size, colors=colors, verbose=verbose)

    model_counts = Counter(selected_indices)
    model_weights = np.zeros(len(base_models))
    if selected_indices:
        total_selections = len(selected_indices)
        for idx, count in model_counts.items():
            model_weights[idx] = count / total_selections
    else:
        model_weights = np.full(len(base_models), 1 / len(base_models))

    x_future = np.arange(n_samples + 1, n_samples + steps_ahead + 1)
    final_base_predictions = np.zeros((steps_ahead, len(base_models)))

    for j, key in enumerate(model_keys):
        model_func = base_models[key]
        if key in ['seasonal']:
            final_base_predictions[:, j] = model_func(monthly_expenses_df, steps_ahead)
        elif key in ['poly', 'huber', 'theta']: # 【錯誤修正】確保 theta 使用正確的呼叫方式
            final_base_predictions[:, j] = model_func(x, data, x_future)
        else:
            final_base_predictions[:, j] = model_func(data, steps_ahead)
    
    final_prediction_sequence = final_base_predictions @ model_weights
    
    historical_pred = meta_features @ model_weights
    residuals = data - historical_pred
    
    dof = n_samples - len(model_counts) - 1
    if dof <= 0: return final_prediction_sequence, historical_pred, residuals, None, None, model_weights, pd.DataFrame(meta_features, columns=model_keys)
    
    mse = np.sum(residuals**2) / dof
    se = np.sqrt(mse)
    t_val = t.ppf(0.975, dof)
    lower_seq = final_prediction_sequence - t_val * se
    upper_seq = final_prediction_sequence + t_val * se
    
    historical_base_preds_df = pd.DataFrame(meta_features, columns=model_keys)
    
    return final_prediction_sequence, historical_pred, residuals, lower_seq, upper_seq, model_weights, historical_base_preds_df

def train_meta_model_with_bootstrap_gfs(X_level2_hist, y_true, n_bootstrap=100, colors=None, verbose=True):
    """
    【您的核心創新】使用自舉法模擬和GFS，為第一層的集成模型們計算公平的權重。
    """
    color_cyan = colors.CYAN if colors else ''
    color_reset = colors.RESET if colors else ''
    n_samples, n_models = X_level2_hist.shape

    if verbose:
        print(f"{color_cyan}--- 階段 2/3: 執行元模型權重校準 (共 {n_bootstrap} 次模擬)... ---{color_reset}")
    
    base_predictions = np.mean(X_level2_hist, axis=1)
    residuals = y_true - base_predictions
    
    q1, q3 = np.percentile(residuals, [25, 75])
    iqr = q3 - q1
    lower_bound = q1 - 1.5 * iqr
    upper_bound = q3 + 1.5 * iqr
    clean_residuals = residuals[(residuals >= lower_bound) & (residuals <= upper_bound)]

    if len(clean_residuals) == 0:
        clean_residuals = residuals

    ensemble_selection_counts = Counter()
    
    if verbose:
        print_progress_bar(0, n_bootstrap, prefix='進度:', suffix='完成', length=40)

    for i in range(n_bootstrap):
        bootstrap_res = np.random.choice(clean_residuals, size=n_samples, replace=True)
        y_bootstrap = base_predictions + bootstrap_res
        
        # 在此模擬數據上，尋找 L1 模型的最佳組合
        selected_indices_for_iter, _ = train_greedy_forward_ensemble(
            X_level2_hist, y_bootstrap, list(range(n_models)), n_iterations=n_models, colors=colors, verbose=False
        )
        
        ensemble_selection_counts.update(selected_indices_for_iter)
        
        if verbose:
            print_progress_bar(i + 1, n_bootstrap, prefix='進度:', suffix='完成', length=40)

    if verbose:
        print("權重校準完成。")

    if not ensemble_selection_counts:
        final_weights = np.full(n_models, 1/n_models)
    else:
        total_selections = sum(ensemble_selection_counts.values())
        final_weights = np.array([ensemble_selection_counts.get(i, 0) for i in range(n_models)])
        if total_selections > 0:
            final_weights = final_weights / total_selections
        else:
            final_weights = np.full(n_models, 1/n_models)
    
    return final_weights

def run_full_ensemble_pipeline(monthly_expenses_df, steps_ahead, colors, verbose=True):
    """
    【已重構】執行完整的三層式集成模型流程。
    """
    data = monthly_expenses_df['Real_Amount'].values
    x = np.arange(1, len(data) + 1)
    num_months = len(data)

    # 【方法一整合點】將新模型加入基礎模型庫
    base_models = {
        'poly': train_predict_poly, 'huber': train_predict_huber, 'des': train_predict_des, 'drift': train_predict_drift,
        'seasonal': train_predict_seasonal, 'seasonal_naive': train_predict_seasonal_naive, 'naive': train_predict_naive,
        'moving_average': train_predict_moving_average, 'rolling_median': train_predict_rolling_median, 'global_median': train_predict_global_median,
        'ses': train_predict_ses, 'theta': train_predict_theta,
    }
    model_keys = list(base_models.keys())
    
    # --- 階段 0: 生成基礎模型對歷史數據的預測 (元特徵) ---
    if verbose: print(f"\n{colors.CYAN}--- 階段 0/3: 執行基礎模型交叉驗證 (生成元特徵)... ---{colors.RESET}")
    _, _, _, _, _, _, historical_base_preds_df = run_stacked_ensemble_model(
        monthly_expenses_df, steps_ahead, colors=colors, verbose=False
    )
    meta_features = historical_base_preds_df.values
    
    # --- 階段 1: 訓練第一層集成模型並產生公平的歷史預測 (OOF) ---
    if verbose: print(f"{colors.CYAN}--- 階段 1/3: 執行巢狀交叉驗證以訓練第一層集成模型... ---{colors.RESET}")
    n_folds = 5
    fold_indices = np.array_split(np.arange(num_months), n_folds)
    X_level2_hist_oof = np.zeros((num_months, 3)) # 用於儲存 L1 模型的公平預測

    for i in range(n_folds):
        train_idx = np.concatenate([fold_indices[j] for j in range(n_folds) if i != j])
        val_idx = fold_indices[i]
        
        if len(train_idx) == 0: continue

        meta_features_train, y_train = meta_features[train_idx], data[train_idx]
        
        # 1. GFS
        selected_indices_fold, _ = train_greedy_forward_ensemble(meta_features_train, y_train, model_keys, n_iterations=20, verbose=False, colors=colors)
        gfs_counts_fold = Counter(selected_indices_fold)
        gfs_weights_fold = np.zeros(len(base_models))
        if selected_indices_fold:
            for idx, count in gfs_counts_fold.items(): gfs_weights_fold[idx] = count
            gfs_weights_fold /= np.sum(gfs_weights_fold)
        else: gfs_weights_fold.fill(1/len(base_models))
        X_level2_hist_oof[val_idx, 0] = meta_features[val_idx] @ gfs_weights_fold

        # 2. PWA
        maes_fold = [np.mean(np.abs(y_train - meta_features_train[:, i])) for i in range(len(base_models))]
        pwa_weights_fold = 1 / (np.array(maes_fold) + 1e-9)
        pwa_weights_fold /= np.sum(pwa_weights_fold)
        X_level2_hist_oof[val_idx, 1] = meta_features[val_idx] @ pwa_weights_fold

        # 3. NNLS
        nnls_weights_fold, _ = nnls(meta_features_train, y_train)
        if np.sum(nnls_weights_fold) > 1e-9: nnls_weights_fold /= np.sum(nnls_weights_fold)
        else: nnls_weights_fold.fill(1/len(base_models))
        X_level2_hist_oof[val_idx, 2] = meta_features[val_idx] @ nnls_weights_fold

    # --- 階段 2: 使用自舉法模擬，為第一層的集成模型計算最終權重 ---
    weights_level2 = train_meta_model_with_bootstrap_gfs(X_level2_hist_oof, data, colors=colors, verbose=verbose)
        
    # --- 重新在全部數據上訓練 L1 模型以預測未來 ---
    # GFS
    selected_indices, _ = train_greedy_forward_ensemble(meta_features, data, model_keys, n_iterations=20, colors=colors, verbose=False)
    gfs_counts = Counter(selected_indices); gfs_weights = np.zeros(len(base_models))
    if selected_indices:
        for idx, count in gfs_counts.items(): gfs_weights[idx] = count
        gfs_weights /= np.sum(gfs_weights)
    else: gfs_weights.fill(1/len(base_models))
    # PWA
    maes = [np.mean(np.abs(data - meta_features[:, i])) for i in range(len(base_models))]
    pwa_weights = 1 / (np.array(maes) + 1e-9); pwa_weights /= np.sum(pwa_weights)
    # NNLS
    nnls_weights, _ = nnls(meta_features, data)
    if np.sum(nnls_weights) > 1e-9: nnls_weights /= np.sum(nnls_weights)
    else: nnls_weights.fill(1/len(base_models))
    
    # 計算未來基礎模型預測
    x_future = np.arange(num_months + 1, num_months + steps_ahead + 1)
    future_base_predictions = np.zeros((steps_ahead, len(base_models)))
    for j, key in enumerate(model_keys):
        model_func = base_models[key]
        if key in ['seasonal']:
            future_base_predictions[:, j] = model_func(monthly_expenses_df, steps_ahead)
        elif key in ['poly', 'huber', 'theta']: # 【錯誤修正】確保 theta 使用正確的呼叫方式
            future_base_predictions[:, j] = model_func(x, data, x_future)
        else:
            future_base_predictions[:, j] = model_func(data, steps_ahead)

    # 組合未來預測
    future_pred_l1_gfs = future_base_predictions @ gfs_weights
    future_pred_l1_pwa = future_base_predictions @ pwa_weights
    future_pred_l1_nnls = future_base_predictions @ nnls_weights
    X_level2_future = np.column_stack([future_pred_l1_gfs, future_pred_l1_pwa, future_pred_l1_nnls])
    
    future_pred_fused_seq = X_level2_future @ weights_level2
    historical_pred_fused = X_level2_hist_oof @ weights_level2

    # --- 階段 3: 殘差提升 ---
    # 【方法三整合點與錯誤修正】引入自適應早停機制的殘差提升，並修復變數覆蓋問題
    if verbose: print(f"{colors.CYAN}--- 階段 3/3: 執行具備早停機制的殘差提升 (Boosting) ... ---{colors.RESET}")
    T = 10 # 最大迭代次數
    learning_rate = 0.1
    patience = 3 # 連續3次無改善則停止
    
    historical_pred_final = historical_pred_fused.copy()
    future_pred_final_seq = future_pred_fused_seq.copy()
    weak_model_func = base_models['huber']
    
    # 初始化早停機制所需變量
    min_len_for_rmse = min(len(data), len(historical_pred_final))
    initial_residuals = data[:min_len_for_rmse] - historical_pred_final[:min_len_for_rmse]
    best_rmse = np.sqrt(np.mean(initial_residuals**2))
    
    epochs_without_improvement = 0
    best_historical_pred = historical_pred_final.copy()
    best_future_pred = future_pred_final_seq.copy()

    # 【錯誤修正】將迴圈變數從 't' 改為 'boost_iter' 以避免覆蓋 scipy.stats.t
    for boost_iter in range(T):
        residuals_boost = data - historical_pred_final
        
        res_pred_hist = weak_model_func(x, residuals_boost, x)
        res_pred_future_seq = weak_model_func(x, residuals_boost, x_future)
        
        historical_pred_final += learning_rate * res_pred_hist
        future_pred_final_seq += learning_rate * res_pred_future_seq
        
        current_rmse = np.sqrt(np.mean((data - historical_pred_final)**2))
        if current_rmse < best_rmse:
            best_rmse = current_rmse
            epochs_without_improvement = 0
            best_historical_pred = historical_pred_final.copy()
            best_future_pred = future_pred_final_seq.copy()
        else:
            epochs_without_improvement += 1
        
        if epochs_without_improvement >= patience:
            if verbose: print(f"{colors.YELLOW}資訊：殘差提升在第 {boost_iter + 1} 次迭代觸發早停機制以防止過擬合。{colors.RESET}")
            break
            
    historical_pred_final = best_historical_pred
    future_pred_final_seq = best_future_pred
    
    effective_base_weights = (gfs_weights * weights_level2[0]) + (pwa_weights * weights_level2[1]) + (nnls_weights * weights_level2[2])
    
    dof = num_months - X_level2_hist_oof.shape[1] - 1
    lower_seq, upper_seq = None, None
    if dof > 0:
        residuals_final = data - historical_pred_final
        mse = np.sum(residuals_final**2) / dof
        se = np.sqrt(mse) * np.sqrt(1 + 1/num_months)
        t_val = t.ppf(0.975, dof) # 此處的 't' 現在可以正確引用 scipy.stats.t
        lower_seq, upper_seq = future_pred_final_seq - t_val*se, future_pred_final_seq + t_val*se
    
    meta_model_names = ["貪婪前向選擇法", "性能加權平均法", "非負最小平方法"]
    meta_model_weights_for_report = {name: w for name, w in zip(meta_model_names, weights_level2)}

    return future_pred_final_seq, historical_pred_final, effective_base_weights, meta_model_weights_for_report, lower_seq, upper_seq, historical_base_preds_df


# --- 主要分析與預測函數 ---
def analyze_and_predict(file_paths_str: str, no_color: bool):
    colors = Colors(enabled=not no_color)
    file_paths = [path.strip() for path in file_paths_str.split(';')]

    master_df, monthly_expenses, warnings_report = process_finance_data_multiple(file_paths, colors)

    if monthly_expenses is None:
        if master_df is None:
            print(f"\n{colors.RED}資料處理失敗：{warnings_report}{colors.RESET}\n")
            return
        else:
             monthly_expenses = pd.DataFrame(columns=['Parsed_Date', 'Amount', 'Real_Amount'])

    if warnings_report:
        print(f"\n{colors.YELLOW}--- 資料品質摘要 ---{colors.RESET}")
        print(warnings_report)
        print(f"{colors.YELLOW}--------------------{colors.RESET}")

    num_unique_months = monthly_expenses['Parsed_Date'].dt.to_period('M').nunique() if not monthly_expenses.empty else 0

    seasonal_note = "未使用季節性分解（資料月份不足 24 個月）。"
    analysis_data = None
    df_for_seasonal_model = None
    if not monthly_expenses.empty:
        if num_unique_months >= 24:
            analysis_data = monthly_expenses['Real_Amount'].values
            df_for_seasonal_model = monthly_expenses.copy() 
            seasonal_note = "集成模型已內建季節性分析。"
        else:
            analysis_data = monthly_expenses['Real_Amount'].values

    total_income, total_expense, total_real_expense = 0, 0, 0
    is_wide_format_expense_only = (master_df is None and not monthly_expenses.empty)
    
    if master_df is not None:
        master_df['Amount'] = pd.to_numeric(master_df['Amount'], errors='coerce')
        master_df.dropna(subset=['Type', 'Amount'], inplace=True)
        income_df = master_df[master_df['Type'].str.lower() == 'income']
        expense_df = master_df[master_df['Type'].str.lower() == 'expense']
        total_income, total_expense = income_df['Amount'].sum(), expense_df['Amount'].sum()
        if not monthly_expenses.empty: total_real_expense = monthly_expenses['Real_Amount'].sum()
    elif not monthly_expenses.empty:
        total_expense, total_real_expense = monthly_expenses['Amount'].sum(), monthly_expenses['Real_Amount'].sum()

    net_balance = total_income - total_expense

    # 【錯誤修正】目標月份邏輯重構
    now = datetime.now()
    current_year, current_month = now.year, now.month
    if current_month == 12:
        target_year, target_month = current_year + 1, 1
    else:
        target_year, target_month = current_year, current_month + 1
    target_month_str = f"{target_year}-{target_month:02d}"
    target_period = pd.Period(target_month_str, freq='M')
    
    steps_ahead, step_warning = 1, ""
    if not monthly_expenses.empty:
        last_date = monthly_expenses['Parsed_Date'].max()
        last_period = last_date.to_period('M')
        
        # 始終以真實世界的下一個月為目標，計算距離數據末端的步數
        steps_ahead = (target_period.year - last_period.year) * 12 + (target_period.month - last_period.month)
        
        if steps_ahead <= 0:
            if "數據包含未來月份" not in str(warnings_report): # 避免重複打印
                 warnings_report += f"\n{colors.YELLOW}警告：您的數據包含未來月份的記錄。預測仍將針對真實世界的下一個月份 ({target_month_str})。{colors.RESET}"
            steps_ahead = 1 
        
        if steps_ahead > 12:
            step_warning = f"{colors.YELLOW}警告：預測步數超過12 ({steps_ahead})，遠期預測不確定性增加。{colors.RESET}"

    predicted_expense_str, ci_str, method_used = "無法預測 (資料不足)", "", ""
    upper, lower, predicted_value = None, None, None
    historical_mae, historical_rmse, historical_wape, historical_mase = None, None, None, None
    historical_rmse_robust, historical_wape_robust = None, None
    quantile_preds, historical_pred, residuals = {}, None, None
    quantiles = [0.10, 0.25, 0.50, 0.75, 0.90]
    base_model_weights_report = ""
    meta_model_weights_report = ""
    mpi_results = None
    cv_mpi_scores = None
    prequential_metrics_report = "" 
    adaptive_dynamics_report = ""
    risk_factors_report = "" # 【新增】初始化風險因子報告變數

    if analysis_data is not None and len(analysis_data) >= 2:
        num_months = len(analysis_data)
        data, x = analysis_data, np.arange(1, num_months + 1)
        
        base_models = {
            'poly': train_predict_poly, 'huber': train_predict_huber, 'des': train_predict_des, 'drift': train_predict_drift,
            'seasonal': train_predict_seasonal, 'seasonal_naive': train_predict_seasonal_naive, 'naive': train_predict_naive,
            'moving_average': train_predict_moving_average, 'rolling_median': train_predict_rolling_median, 'global_median': train_predict_global_median,
            'ses': train_predict_ses, 'theta': train_predict_theta,
        }
        
        if num_months >= 24:
            method_used = " (基於三層式混合集成法 - 自舉法校準)"
            
            future_pred_final_seq, historical_pred, effective_base_weights, weights_level2_report, lower_seq, upper_seq, _ = \
                run_full_ensemble_pipeline(df_for_seasonal_model, steps_ahead, colors, verbose=True)

            predicted_value = future_pred_final_seq[-1]
            lower = lower_seq[-1] if lower_seq is not None else None
            upper = upper_seq[-1] if upper_seq is not None else None
            
            report_parts_meta = [f"{name}({weight:.1%})" for name, weight in weights_level2_report.items() if weight > 0.001]
            meta_model_weights_report = f"  - 元模型融合策略: {', '.join(report_parts_meta)}"
            
            model_names_base = ["多項式", "穩健趨勢", "指數平滑", "漂移", "季節分解", "季節模仿", "單純", "移動平均", "滾動中位", "全局中位", "簡易平滑", "Theta趨勢"]
            sorted_parts = sorted(zip(effective_base_weights, model_names_base), reverse=True)
            report_parts_base_sorted = [f"{name}({weight:.1%})" for weight, name in sorted_parts if weight > 0.001]
            chunk_size = 3
            chunks = [report_parts_base_sorted[i:i + chunk_size] for i in range(0, len(report_parts_base_sorted), chunk_size)]
            lines = [", ".join(chunk) for chunk in chunks]
            indentation = "\n" + " " * 16
            base_model_weights_report = f"  - 基礎模型權重: {indentation.join(lines)}"

            prequential_results = run_prequential_evaluation(df_for_seasonal_model, colors)
            mean_expense_for_report = monthly_expenses['Real_Amount'].mean() if not monthly_expenses.empty else 0
            prequential_metrics_report = format_prequential_metrics_report(prequential_results, mean_expense_for_report, colors)
            adaptive_dynamics_report = format_adaptive_dynamics_report(prequential_results, df_for_seasonal_model, colors)

        elif 18 <= num_months < 24:
            method_used = " (基於穩健迴歸IRLS-Huber)"
            pred_seq, historical_pred, _, lower_seq, upper_seq = huber_robust_regression(x, data, steps_ahead)
            predicted_value = pred_seq[-1]
            lower = lower_seq[-1] if lower_seq is not None else None
            upper = upper_seq[-1] if upper_seq is not None else None
        else:
            method_used = " (基於直接-遞歸混合)"
            model_logic = 'poly' if num_months >= 12 else 'linear' if num_months >= 6 else 'ema'
            if model_logic == 'poly':
                predicted_value, lower, upper = polynomial_regression_with_ci(x, data, 2, num_months + steps_ahead)
                historical_pred = np.poly1d(np.polyfit(x, data, 2))(x)
            elif model_logic == 'linear':
                slope, intercept, _, _, _ = linregress(x, data)
                predicted_value = intercept + slope * (num_months + steps_ahead)
                historical_pred = intercept + slope * x
                
                # 【錯誤修正】拆分多重賦值以避免 UnboundLocalError
                n = len(x)
                x_mean = np.mean(x)
                ssx = np.sum((x - x_mean)**2)
                
                if n > 2:
                    mse = np.sum((data-historical_pred)**2)/(n-2)
                    se = np.sqrt(mse * (1 + 1/n + ((num_months+steps_ahead)-x_mean)**2/ssx))
                    t_val = t.ppf(0.975, n-2)
                    lower, upper = predicted_value - t_val*se, predicted_value + t_val*se
            elif model_logic == 'ema':
                ema = pd.Series(data).ewm(span=num_months, adjust=False).mean()
                predicted_value, historical_pred = ema.iloc[-1], ema.values
            
        if historical_pred is not None:
            min_len_for_res = min(len(data), len(historical_pred))
            residuals = data[:min_len_for_res] - historical_pred[:min_len_for_res]
            
            ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)" if lower is not None and upper is not None else ""
            predicted_expense_str = f"{predicted_value:,.2f}"
            historical_mae, historical_rmse = np.mean(np.abs(residuals)), np.sqrt(np.mean(residuals**2))
            
            sum_abs_actual = np.sum(np.abs(data[:min_len_for_res]))
            historical_wape = (np.sum(np.abs(residuals)) / sum_abs_actual * 100) if sum_abs_actual > 1e-9 else 100.0
            
            if len(data) > 1:
                mae_naive = np.mean(np.abs(data[1:] - data[:-1]))
                historical_mase = (historical_mae/mae_naive) if mae_naive and mae_naive>0 else None
            else:
                historical_mase = None

            res_quantiles = np.percentile(residuals, [q * 100 for q in quantiles])
            for i, q in enumerate(quantiles):
                quantile_preds[q] = historical_pred + res_quantiles[i]
                
            if num_months >= 12: 
                anomaly_info = calculate_anomaly_scores(data)
                is_shock_flags = anomaly_info['Is_Shock'].values[:min_len_for_res]
                residuals_clean = residuals[~is_shock_flags]
                data_clean = data[:min_len_for_res][~is_shock_flags]
                if len(residuals_clean) > 0:
                    historical_rmse_robust = np.sqrt(np.mean(residuals_clean**2))
                
                sum_abs_clean = np.sum(np.abs(data_clean))
                if len(data_clean) > 0 and sum_abs_clean > 1e-9:
                    historical_wape_robust = (np.sum(np.abs(residuals_clean)) / sum_abs_clean) * 100
            
            if num_months >= 24:
                _, cv_mpi_scores = run_monte_carlo_cv(df_for_seasonal_model, base_models, n_iterations=100, colors=colors)

                erai_results = perform_internal_benchmarking(data, historical_pred, is_shock_flags)
                
                fss_results = calculate_fss(prequential_results, mean_expense_for_report)
                fss_score = fss_results.get('fss_score', 0)

                temp_mpi_score = calculate_mpi_3_0_and_rate(data, historical_pred, historical_wape, erai_results['erai_score'], 100, fss_score)['mpi_score']

                mpi_percentile_rank = None
                if cv_mpi_scores and len(cv_mpi_scores) > 0:
                    mpi_percentile_rank = percentileofscore(cv_mpi_scores, temp_mpi_score, kind='rank')

                mpi_results = calculate_mpi_3_0_and_rate(
                    y_true=data,
                    historical_pred=historical_pred,
                    global_wape=historical_wape,
                    erai_score=erai_results['erai_score'],
                    mpi_percentile_rank=mpi_percentile_rank,
                    fss_score=fss_score
                )

    expense_std_dev, volatility_report, color = None, "", colors.WHITE
    if not monthly_expenses.empty and len(monthly_expenses)>=2:
        expense_values = monthly_expenses['Real_Amount']
        expense_std_dev, expense_mean = expense_values.std(), expense_values.mean()
        if expense_mean > 0:
            expense_cv = (expense_std_dev/expense_mean)*100
            if expense_cv < 20: level, color = "低波動", colors.GREEN
            elif expense_cv < 45: level, color = "中度波動", colors.WHITE
            elif expense_cv < 70: level, color = "高波動", colors.YELLOW
            else: level, color = "極高波動", colors.RED
            volatility_report = f" ({expense_cv:.1f}%, {level})"

    p25, p75, p95 = None, None, None
    mc_note = "未使用蒙地卡羅（數據不足24月）。"
    if not monthly_expenses.empty and len(monthly_expenses)>=2:
        if num_unique_months >= 24 and predicted_value is not None:
            p25, p75, p95 = optimized_monte_carlo(monthly_expenses, predicted_value)
            mc_note = "已使用優化蒙地卡羅模擬。"
        else:
            p25, p75, p95 = monte_carlo_dashboard(monthly_expenses['Real_Amount'].values)

    calibration_results, acf_results, quantile_spread = {}, {}, 0.0
    if residuals is not None and len(residuals)>=2:
        min_len_diag = len(residuals)
        data_diag = data[:min_len_diag]
        quantile_preds_diag = {q: p[:min_len_diag] for q, p in quantile_preds.items()}
        
        calibration_results = compute_calibration_results(data_diag, quantile_preds_diag, quantiles)
        acf_results = compute_acf_results(residuals, num_months)
        quantile_spread = compute_quantile_spread(p25, p75, predicted_value)

    # 【錯誤修正】完整接收風險評估的返回元組
    risk_status, risk_description, suggested_budget, dynamic_risk_coefficient, trend_score, vol_score, shock_score, data_reliability, error_coefficient, error_buffer, trend_scores, vol_scores, shock_scores, overall_score, risk_buffer = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse, calibration_results=calibration_results, acf_results=acf_results, quantile_spread=quantile_spread)
    
    # 【新增】調用風險因子報告生成函數
    if trend_scores is not None and isinstance(trend_scores, dict) and not trend_scores.get('is_advanced'):
        risk_factors_report = format_detailed_risk_analysis_report(dynamic_risk_coefficient, error_coefficient, overall_score, trend_score, trend_scores, vol_score, vol_scores, shock_score, shock_scores, colors)

    diagnostic_report = ""
    if residuals is not None and len(residuals)>=2:
        diagnostic_report = f"{quantile_loss_report(data_diag, quantile_preds_diag, quantiles, colors)}\n\n{model_calibration_analysis(data_diag, quantile_preds_diag, quantiles, colors)}\n\n{residual_autocorrelation_diagnosis(residuals, num_months, colors)}"

    print(f"\n{colors.CYAN}{colors.BOLD}========== 財務分析與預測報告 =========={colors.RESET}")
    if not is_wide_format_expense_only: print(f"{colors.BOLD}總收入: {colors.GREEN}{total_income:,.2f}{colors.RESET}")
    print(f"{colors.BOLD}總支出 (名目): {colors.RED}{total_expense:,.2f}{colors.RESET}")
    if not monthly_expenses.empty: print(f"{colors.BOLD}總支出 (實質，經通膨調整): {colors.RED}{total_real_expense:,.2f}{colors.RESET}")
    if expense_std_dev is not None: print(f"{colors.BOLD}歷史月均支出波動 (實質): {color}{expense_std_dev:,.2f}{volatility_report}{colors.RESET}")
    if not is_wide_format_expense_only:
        print("------------------------------------------")
        balance_color = colors.GREEN if net_balance>=0 else colors.RED
        print(f"{colors.BOLD}淨餘額（名目）: {balance_color}{colors.BOLD}{net_balance:,.2f}{colors.RESET}")

    print(f"\n{colors.PURPLE}{colors.BOLD}>>> {target_month_str} 趨勢預測{method_used}: {predicted_expense_str}{ci_str}{colors.RESET}")
    
    if historical_mae is not None:
        print(f"\n{colors.WHITE}>>> 模型表現評估 (基於歷史回測){colors.RESET}")
        
        print(f"  - MAE (平均絕對誤差): {historical_mae:,.2f} 元")
        print(f"  - RMSE (全局): {historical_rmse:,.2f} 元 (含極端值，評估總體風險)")
        if historical_rmse_robust is not None:
            print(f"  - RMSE (排除衝擊後): {colors.GREEN}{historical_rmse_robust:,.2f} 元 (反映日常預測誤差){colors.RESET}")
        if historical_wape is not None: 
            print(f"  - WAPE (全局): {historical_wape:.2f}% (含極端值，評估總體誤差比例)")
        if historical_wape_robust is not None:
            print(f"  - WAPE (排除衝擊後): {colors.GREEN}{historical_wape_robust:,.2f}% (反映日常預測誤差比例){colors.RESET}")
        if historical_mase is not None: 
            print(f"  - MASE (平均絕對標度誤差): {historical_mase:.2f} (小於1優於天真預測)")

        if mpi_results is not None:
            mpi_score = mpi_results['mpi_score']
            rating = mpi_results['rating']
            suggestion = mpi_results['suggestion']
            components = mpi_results['components']
            
            mpi_display_str = f"{mpi_score:.3f} ({mpi_score:.1%})"
            if 'mpi_percentile_rank' in locals() and mpi_percentile_rank is not None:
                 mpi_display_str += f" | {colors.BOLD}百分位等級: P{mpi_percentile_rank:.1f}{colors.RESET}{colors.PURPLE}{colors.BOLD}"

            print(f"{colors.PURPLE}{colors.BOLD}  ---")
            print(f"{colors.PURPLE}{colors.BOLD}  - MPI 3.0 (綜合效能指數): {mpi_display_str}  評級: {rating}{colors.RESET}")
            print(f"{colors.WHITE}    └─ 絕對準確度: {components['absolute_accuracy']:.3f} | 相對優越性: {components['relative_superiority']:.3f} | 未來穩定性: {components['future_stability']:.3f}{colors.RESET}")
            print(f"{colors.WHITE}    └─ {suggestion}{colors.RESET}")

    if prequential_metrics_report:
        print(prequential_metrics_report)
    
    if adaptive_dynamics_report:
        print(adaptive_dynamics_report)

    if diagnostic_report:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 模型診斷儀表板 (進階誤差評估){colors.RESET}")
        print(diagnostic_report)

    print(f"\n{colors.CYAN}{colors.BOLD}>>> 預測方法摘要{colors.RESET}")
    print(f"  - 資料月份數: {num_unique_months}")
    print(f"  - {seasonal_note}")
    print(f"  - {mc_note}")
    print(f"  - 預測目標月份: {target_month_str} (距離資料 {steps_ahead} 個月)")
    if base_model_weights_report: print(base_model_weights_report)
    if meta_model_weights_report: print(meta_model_weights_report)
    if step_warning: print(step_warning)

    if p25 is not None:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 個人財務風險儀表板 (基於 10,000 次模擬，實質金額){colors.RESET}")
        print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")
        print(f"{colors.GREEN}  [安全區] {p25:,.0f} ~ {p75:,.0f} 元 (50% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 核心開銷範圍，可作為常規預算。{colors.RESET}")
        print(f"{colors.YELLOW}  [警戒區] {p75:,.0f} ~ {p95:,.0f} 元 (20% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 計畫外消費，需注意非必要支出。{colors.RESET}")
        print(f"{colors.RED}  [應急動用區] > {p95:,.0f} 元 (5% 機率){colors.RESET}")
        print(f"{colors.WHITE}    └ 重大財務衝擊，應動用緊急預備金。{colors.RESET}")
        print(f"{colors.GREEN}--------------------------------------------------{colors.RESET}")

    if risk_status and "無法判讀" not in risk_status:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 月份保守預算建議{colors.RESET}")
        print(f"{colors.BOLD}風險狀態: {risk_status}{colors.RESET}")
        print(f"{colors.WHITE}{risk_description}{colors.RESET}")
        if data_reliability: print(f"{colors.BOLD}數據可靠性: {data_reliability}{colors.RESET}")
        
        is_advanced_model = isinstance(trend_scores, dict) and trend_scores.get('is_advanced')
        
        # <<< START: 已加入您指定的提示訊息 >>>
        if is_advanced_model:
            num_shocks = trend_scores.get('num_shocks', 0)
            change_date = trend_scores.get('change_date')
            
            if change_date:
                print(f"{colors.WHITE}  - 模式偵測: 偵測到您的支出模式在 {change_date} 附近發生結構性轉變，後續評估將更側重於近期數據。{colors.RESET}")
            
            if num_shocks > 0:
                print(f"{colors.WHITE}  - 衝擊偵測: 系統識別出 {num_shocks} 次「真實衝擊」(極端開銷)，已納入攤提金準備中。{colors.RESET}")
        # <<< END: 提示訊息結束 >>>
        
        if suggested_budget is not None:
            print(f"{colors.BOLD}建議 {target_month_str} 預算: {suggested_budget:,.2f} 元{colors.RESET}")
            # 【錯誤修正】補全預算說明的 else 邏輯
            if is_advanced_model:
                print(f"{colors.WHITE}    └ 計算依據 (三層式模型):{colors.RESET}")
                print(f"{colors.GREEN}      - 基礎日常預算 (P75): {trend_scores.get('base', 0):,.2f}{colors.RESET}")
                print(f"{colors.YELLOW}      - 巨額衝擊攤提金: {trend_scores.get('amortized', 0):,.2f}{colors.RESET}")
                print(f"{colors.RED}      - 模型誤差緩衝: {trend_scores.get('error', 0):,.2f}{colors.RESET}")
                if error_coefficient is not None: print(f"\n{colors.BOLD}模型誤差係數: {error_coefficient:.2f}{colors.RESET}")
            else:
                if error_buffer is not None and risk_buffer is not None:
                    print(f"{colors.WHITE}    └ 計算依據：風險緩衝 ({risk_buffer:,.2f}) + 模型誤差緩衝 ({error_buffer:,.2f}){colors.RESET}")
                elif "替代公式" in data_reliability:
                    print(f"{colors.WHITE}    └ 計算依據：近期平均支出 + 15% 固定緩衝。{colors.RESET}")
        
        # 【新增】在預算建議下方打印詳細的風險因子報告
        if risk_factors_report:
            print(risk_factors_report)

    print(f"\n{colors.WHITE}【註】「實質金額」：為讓不同年份的支出能公平比較，本報告已將所有歷史數據，統一換算為當前基期年的貨幣價值。{colors.RESET}")
    print(f"{colors.CYAN}{colors.BOLD}========================================{colors.RESET}\n")

# --- 腳本入口 (未變更) ---
def main():
    warnings.simplefilter("ignore")

    parser = argparse.ArgumentParser(description="進階財務分析與預測器")
    parser.add_argument('--no-color', action='store_true', help="禁用彩色輸出。")
    args = parser.parse_args()

    colors = Colors(enabled=not args.no_color)

    print(f"{colors.CYAN}====== {colors.BOLD}{SCRIPT_NAME} {SCRIPT_VERSION}{colors.RESET}{colors.CYAN} ======{colors.RESET}")
    print(f"{colors.WHITE}更新日期: {SCRIPT_UPDATE_DATE}{colors.RESET}")

    try:
        install_dependencies(colors)
        file_paths_str = input(f"\n{colors.YELLOW}請貼上一個或多個以分號(;)區隔的 CSV 檔案路徑: {colors.RESET}")
        if not file_paths_str.strip():
            print(f"\n{colors.RED}錯誤：未提供任何檔案路徑。腳本終止。{colors.RESET}")
            sys.exit(1)
        
        analyze_and_predict(file_paths_str, args.no_color)

    except KeyboardInterrupt:
        print(f"\n{colors.YELLOW}使用者中斷操作。腳本終止。{colors.RESET}")
        sys.exit(0)
    except Exception as e:
        import traceback
        print(f"\n{colors.RED}腳本執行時發生未預期的錯誤: {e}{colors.RESET}")
        traceback.print_exc()
        sys.exit(1)

if __name__ == "__main__":
    main()
