#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v2.20                #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。                        #
# 具備自動格式清理、互動式路徑輸入與多種模型預測、信賴區間等功能。                           #
# 更新：新增 SEAS (堆疊集成準確率) 指標，用以全方位評估模型穩健性、嚴謹性與誠實度。      #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v2.20"  # 更新版本：新增 SEAS 綜合準確率指標
SCRIPT_UPDATE_DATE = "2025-07-22"

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
from scipy.stats import skew, kurtosis, median_abs_deviation
from scipy.optimize import nnls # 【新增】導入非負最小平方法
from collections import deque

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
                
                warnings_report.append(f"{colors.GREEN}CPI 基準年份：{cpi_base_year} 年（基於輸入數據最早年份，指數設為 100）。計算到目標年：{base_year} 年。{colors.RESET}")
                
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


# --- 三層式預算建議核心函數 (未變更) ---
def assess_risk_and_budget_advanced(monthly_expenses, model_error_coefficient, historical_rmse):
    """
    針對超過12個月數據的進階三層式預算計算模型。
    現在會返回包含模式偵測結果的字典。
    """
    data = monthly_expenses['Real_Amount'].values
    n_total = len(data)
    
    anomaly_df = calculate_anomaly_scores(data)
    
    # --- 模式偵測 (使用重構後的函數) ---
    change_point = detect_structural_change_point(monthly_expenses)
    change_date_str = None
    # 只有當偵測到的轉變點不是從頭開始時，才視為一次「轉變」
    if change_point > 0:
        change_date = monthly_expenses['Parsed_Date'].iloc[change_point]
        change_date_str = change_date.strftime('%Y年-%m月')
    
    num_shocks = int(anomaly_df['Is_Shock'].sum())

    # --- 第一層：基礎日常預算 (Base Living Budget) ---
    new_normal_df = anomaly_df.iloc[change_point:].copy()
    # 在計算基礎預算時，應排除真實衝擊點
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
    rmse_clean = historical_rmse if historical_rmse is not None else 0
    if len(clean_new_normal_data) >= 2:
        x_clean = np.arange(len(clean_new_normal_data))
        slope, intercept, _, _, _ = linregress(x_clean, clean_new_normal_data)
        y_pred_clean = intercept + slope * x_clean
        rmse_clean = np.sqrt(np.mean((clean_new_normal_data - y_pred_clean) ** 2))

    model_error_buffer = model_error_coefficient * rmse_clean
    
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

# --- 【★★★ 新增：SEAS 準確率評估套件 ★★★】 ---

def calculate_umbrae(y_true, y_pred, y_benchmark):
    """
    專家：穩健大師 (UMBRAE - Unscaled Mean Bounded Relative Absolute Error)
    評估模型的基礎穩健性，對離群值不敏感。
    """
    # 計算模型誤差和基準誤差
    model_errors = np.abs(y_true - y_pred)
    benchmark_errors = np.abs(y_true - y_benchmark)
    
    # 核心邏輯：計算有界相對誤差 (BRAE)
    # 避免除以零
    denominator = model_errors + benchmark_errors
    brae = np.divide(model_errors, denominator, out=np.zeros_like(model_errors, dtype=float), where=denominator!=0)
    
    # 計算平均有界相對誤差 (MBRAE)
    mbrae = np.mean(brae)
    
    # 轉換為無標度、更易解讀的 UMBRAE
    # 若 mbrae 趨近於1（極差），結果會趨近於無限大
    if mbrae >= 1.0:
        return np.inf
    umbrae = mbrae / (1 - mbrae)
    return umbrae

def calculate_rmsse(y_true, y_pred, y_train_naive_errors):
    """
    專家：懲罰判官 (RMSSE - Root Mean Squared Scaled Error)
    嚴厲懲罰大的預測錯誤。
    """
    # 計算預測的均方誤差 (MSE)
    mse = np.mean(np.square(y_true - y_pred))
    
    # 計算基準模型的縮放因子 (訓練集上的天真預測誤差的均方值)
    scale_factor = np.mean(np.square(y_train_naive_errors))
    
    # 避免除以零
    if scale_factor < 1e-9:
        return np.inf
        
    # 計算 RMSSE
    rmsse = np.sqrt(mse / scale_factor)
    return rmsse

def calculate_msis(y_true, lower_bound, upper_bound, y_train_naive_errors, alpha=0.05):
    """
    專家：誠實度考官 (MSIS - Mean Scaled Interval Score)
    評估預測區間的品質（寬度與覆蓋率）。
    """
    # 計算區間寬度
    interval_width = upper_bound - lower_bound
    
    # 對未覆蓋真實值的區間進行懲罰
    penalty_lower = (2 / alpha) * np.maximum(0, lower_bound - y_true)
    penalty_upper = (2 / alpha) * np.maximum(0, y_true - upper_bound)
    
    # 總區間分數
    interval_score = interval_width + penalty_lower + penalty_upper
    
    # 計算平均區間分數 (Mean Interval Score, MIS)
    mis = np.mean(interval_score)
    
    # 使用與 MASE 相同的縮放因子
    scale_factor = np.mean(np.abs(y_train_naive_errors))

    # 避免除以零
    if scale_factor < 1e-9:
        return np.inf
        
    # 計算 MSIS
    msis = mis / scale_factor
    return msis

def calculate_seas(y_true, y_pred, lower_bound, upper_bound, y_train):
    """
    主整合函數：SEAS (Stacked Ensemble Accuracy Score)
    匯總三位專家的意見，得出綜合評分。
    """
    # 權重設定
    weights = {'umbrae': 0.5, 'rmsse': 0.2, 'msis': 0.3}

    # 準備基準預測與誤差
    # 驗證期
    benchmark_pred = np.roll(y_true, 1)
    benchmark_pred[0] = y_train[-1] if len(y_train) == len(y_true) else np.full_like(y_true, y_train[-1])
    # 訓練期
    train_naive_errors = y_train[1:] - y_train[:-1]

    if len(train_naive_errors) == 0:
        return np.inf, {'umbrae': np.inf, 'rmsse': np.inf, 'msis': np.inf}

    # 獲取三位專家的評分
    umbrae_score = calculate_umbrae(y_true, y_pred, benchmark_pred)
    rmsse_score = calculate_rmsse(y_true, y_pred, train_naive_errors)
    msis_score = calculate_msis(y_true, lower_bound, upper_bound, train_naive_errors)
    
    scores = {'umbrae': umbrae_score, 'rmsse': rmsse_score, 'msis': msis_score}
    
    # 進行加權集成
    seas_score = (umbrae_score * weights['umbrae'] + 
                  rmsse_score * weights['rmsse'] + 
                  msis_score * weights['msis'])
                  
    return seas_score, scores

# --- 【★★★ 新增結束 ★★★】 ---

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
    if predicted_value == 0 or predicted_value is None:
        return 0.0  # 避免除零
    spread = (p75 - p75) / predicted_value if p75 is not None and p25 is not None else 0.0
    return spread  # 標準化到 0-1 範圍（可根據需要調整）

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
    predicted_value = predicted_values[-1] if len(predicted_values) > 0 else (beta[0] + beta[1] * (len(x) + 1))
    
    # 近似的信賴區間
    dof = len(x) - 2
    if dof <= 0: return predicted_value, historical_pred, final_residuals, None, None
    
    mse_robust = np.sum(final_residuals**2) / dof
    se = np.sqrt(mse_robust * (1 + 1/len(x) + (future_x[-1] - np.mean(x))**2 / np.sum((x - np.mean(x))**2))) if len(future_x) > 0 else np.sqrt(mse_robust)
    t_val = t.ppf(0.975, dof)
    lower = predicted_value - t_val * se
    upper = predicted_value + t_val * se

    return predicted_value, historical_pred, final_residuals, lower, upper

# --- 【新增】適應性加權集成模型引擎 ---
def run_adaptive_ensemble_model(x, y, steps_ahead, error_window=6):
    """
    執行適應性加權集成模型。
    """
    # --- 模型 A (穩健先生): IRLS-Huber ---
    pred_A, hist_fit_A, residuals_A, lower_A, upper_A = huber_robust_regression(x, y, steps_ahead)
    
    # --- 模型 B (敏感先生): 原始模型 (SARIMA-like) ---
    slope_B, intercept_B, _, _, _ = linregress(x, y)
    hist_fit_B = intercept_B + slope_B * x
    residuals_B = y - hist_fit_B
    
    # 遞歸預測
    predictions_B = []
    prev_pred_B = y[-1]
    last_hist_pred_B = hist_fit_B[-1]
    for step in range(1, steps_ahead + 1):
        predict_x_B = len(x) + step
        trend_pred_B = intercept_B + slope_B * predict_x_B
        feedback = 0.5 * (prev_pred_B - last_hist_pred_B)
        current_pred_B = trend_pred_B + feedback
        predictions_B.append(current_pred_B)
        prev_pred_B = current_pred_B
        last_hist_pred_B = trend_pred_B
    pred_B = predictions_B[-1]
    
    # 信賴區間
    dof_B = len(x) - 2
    mse_B = np.sum(residuals_B**2) / dof_B
    se_B = np.sqrt(mse_B) * np.sqrt(steps_ahead)
    t_val_B = t.ppf(0.975, dof_B)
    lower_B, upper_B = pred_B - t_val_B * se_B, pred_B + t_val_B * se_B

    # --- 計算動態權重 ---
    if len(x) < error_window: # 冷啟動
        weight_A, weight_B = 0.5, 0.5
    else:
        error_A = np.mean(np.abs(residuals_A[-error_window:]))
        error_B = np.mean(np.abs(residuals_B[-error_window:]))
        
        if error_A + error_B < 1e-6: # 避免除零
            weight_A, weight_B = 0.5, 0.5
        else:
            weight_A = error_B / (error_A + error_B)
            weight_B = 1.0 - weight_A

    # --- 集成最終結果 ---
    final_prediction = (pred_A * weight_A) + (pred_B * weight_B)
    final_historical_pred = (hist_fit_A * weight_A) + (hist_fit_B * weight_B)
    final_residuals = y - final_historical_pred
    final_lower = (lower_A * weight_A) + (lower_B * weight_B) if lower_A is not None and lower_B is not None else None
    final_upper = (upper_A * weight_A) + (upper_B * weight_B) if upper_A is not None and upper_B is not None else None


    return final_prediction, final_historical_pred, final_residuals, final_lower, final_upper, weight_A, weight_B
    
# --- 【★★★ 核心修改：更新註解為學術性名詞 ★★★】 ---
# --- 模型堆疊集成 (Stacking Ensemble) 總引擎 ---

# Level 0 基礎模型 (Base Models)
def train_predict_huber(x_train, y_train, x_predict, t_const=1.345, max_iter=100, tol=1e-6):
    """
    Huber 穩健迴歸 (Huber Robust Regression)。
    專為交叉驗證設計，只學習訓練數據的穩健趨勢規則(beta)，並將該規則應用於預測數據。
    對數據中的異常值不敏感。
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
    """多項式迴歸 (Polynomial Regression)。用 n 次多項式函數捕捉數據中的非線性曲線趨勢。"""
    if len(x_train) < degree + 1: return np.full(len(x_predict), np.mean(y_train) if len(y_train) > 0 else 0)
    coeffs = np.polyfit(x_train, y_train, degree)
    p = np.poly1d(coeffs)
    return p(x_predict)

def train_predict_des(y_train, predict_steps, alpha=0.5, beta=0.5):
    """霍爾特線性趨勢模型 (Holt's Linear Trend Method) 或稱二次指數平滑法。能預測同時包含水平(level)與趨勢(trend)的序列。"""
    if len(y_train) < 2: return np.full(predict_steps, y_train[0] if len(y_train) > 0 else 0)
    level, trend = y_train[0], y_train[1] - y_train[0]
    for i in range(1, len(y_train)):
        level_old, trend_old = level, trend
        level = alpha * y_train[i] + (1 - alpha) * (level_old + trend_old)
        trend = beta * (level - level_old) + (1 - beta) * trend_old
    return level + trend * np.arange(1, predict_steps + 1)

def train_predict_seasonal(df_train, predict_steps, seasonal_period=12):
    """時間序列分解法 (Classical Time Series Decomposition)。將數據拆解為趨勢、季節性與殘差項進行預測。"""
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
    """單純預測法 (Naive Method)。預測值等於最後一個觀測值。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    last_value = y_train[-1]
    return np.full(predict_steps, last_value)

def train_predict_rolling_median(y_train, predict_steps, window_size=6):
    """滾動中位數預測 (Rolling Median Forecast)。預測值是近期(e.g. 6個月)開銷的中位數，能抵抗近期異常值。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    actual_window = min(len(y_train), window_size)
    if actual_window == 0:
        return np.zeros(predict_steps)
    median_value = np.median(y_train[-actual_window:])
    return np.full(predict_steps, median_value)

def train_predict_global_median(y_train, predict_steps):
    """全局中位數預測 (Global Median Forecast)。預測值是全部歷史開銷的中位數。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    median_value = np.median(y_train)
    return np.full(predict_steps, median_value)

def train_predict_drift(y_train, predict_steps):
    """漂移法 (Drift Method)。預測未來值會依循歷史的平均變化率（從起點到終點的斜率）。"""
    if len(y_train) < 2:
        return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)
    
    first_value = y_train[0]
    last_value = y_train[-1]
    drift = (last_value - first_value) / (len(y_train) - 1)
    
    predictions = [last_value + (i * drift) for i in range(1, predict_steps + 1)]
    return np.array(predictions)

def train_predict_seasonal_naive(y_train, predict_steps, seasonal_period=12):
    """季節性單純預測法 (Seasonal Naive Method)。預測值等於上一個週期同一時間點的實際值。"""
    if len(y_train) < seasonal_period:
        return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)

    predictions = []
    for i in range(1, predict_steps + 1):
        idx = len(y_train) - seasonal_period + ((i - 1) % seasonal_period)
        predictions.append(y_train[idx])
    
    return np.array(predictions)

def train_predict_moving_average(y_train, predict_steps, window_size=6):
    """移動平均預測 (Moving Average Forecast)。預測值是近期(e.g. 6個月)開銷的算術平均值。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    
    actual_window = min(len(y_train), window_size)
    if actual_window == 0:
        return np.zeros(predict_steps)
    
    mean_value = np.mean(y_train[-actual_window:])
    return np.full(predict_steps, mean_value)

# Level 1 元模型 (Meta-Model)
def train_and_predict_meta_model(X_meta_train, y_meta_train, X_meta_predict):
    """使用非負最小平方法(NNLS)訓練元模型並進行預測，確保權重合理。"""
    weights, _ = nnls(X_meta_train, y_meta_train)
    
    total_weight = np.sum(weights)
    if total_weight > 1e-6:
        normalized_weights = weights / total_weight
    else:
        num_models = X_meta_train.shape[1]
        normalized_weights = np.full(num_models, 1 / num_models)
        
    final_prediction = X_meta_predict @ normalized_weights
    
    return final_prediction, normalized_weights


# --- 【★★★ 核心修改：重排模型順序並擴充至10個 ★★★】 ---
def run_stacked_ensemble_model(monthly_expenses_df, steps_ahead, n_folds=5):
    data = monthly_expenses_df['Real_Amount'].values
    x = np.arange(1, len(data) + 1)
    
    # 將基礎模型按功能分組排序，以提升報告可讀性
    base_models = {
        # 趨勢組
        'poly': train_predict_poly,
        'huber': train_predict_huber,
        'des': train_predict_des,
        'drift': train_predict_drift,
        # 季節性組
        'seasonal': train_predict_seasonal,
        'seasonal_naive': train_predict_seasonal_naive,
        # 基線/平均組
        'naive': train_predict_naive,
        'moving_average': train_predict_moving_average,
        'rolling_median': train_predict_rolling_median,
        'global_median': train_predict_global_median,
    }
    
    model_keys = list(base_models.keys())
    meta_features = np.zeros((len(data), len(base_models)))
    
    fold_indices = np.array_split(np.arange(len(data)), n_folds)
    
    for i in range(n_folds):
        train_idx = np.concatenate([fold_indices[j] for j in range(n_folds) if i != j])
        val_idx = fold_indices[i]
        
        if len(train_idx) == 0: continue

        x_train, y_train, df_train = x[train_idx], data[train_idx], monthly_expenses_df.iloc[train_idx]
        x_val = x[val_idx]
        
        # 動態地讓所有基礎模型進行預測
        for j, key in enumerate(model_keys):
            model_func = base_models[key]
            if key in ['seasonal']:
                 meta_features[val_idx, j] = model_func(df_train, len(x_val))
            elif key in ['poly', 'huber']:
                 meta_features[val_idx, j] = model_func(x_train, y_train, x_val)
            else: # 其餘模型
                 meta_features[val_idx, j] = model_func(y_train, len(x_val))

    # 最終預測階段
    x_future = np.arange(len(x) + 1, len(x) + steps_ahead + 1)
    final_base_predictions = np.zeros((steps_ahead, len(base_models)))

    for j, key in enumerate(model_keys):
        model_func = base_models[key]
        if key in ['seasonal']:
            final_base_predictions[:, j] = model_func(monthly_expenses_df, steps_ahead)
        elif key in ['poly', 'huber']:
            final_base_predictions[:, j] = model_func(x, data, x_future)
        else:
            final_base_predictions[:, j] = model_func(data, steps_ahead)
    
    # 使用元模型進行訓練和預測
    final_prediction_sequence, model_weights = train_and_predict_meta_model(meta_features, data, final_base_predictions)
    final_prediction = final_prediction_sequence[-1]
    
    historical_pred, _ = train_and_predict_meta_model(meta_features, data, meta_features)
    residuals = data - historical_pred
    
    dof = len(data) - len(base_models) - 1
    if dof <= 0: return final_prediction, historical_pred, residuals, None, None, model_weights
    
    mse = np.sum(residuals**2) / dof
    se = np.sqrt(mse)
    t_val = t.ppf(0.975, dof)
    lower, upper = final_prediction - t_val * se, final_prediction + t_val * se
    
    return final_prediction, historical_pred, residuals, lower, upper, model_weights


# --- 主要分析與預測函數 (【已升級】) ---
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

    used_seasonal = False
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

    now = datetime.now()
    current_year, current_month = now.year, now.month
    if current_month == 12: target_month, target_year = 1, current_year + 1
    else: target_month, target_year = current_month + 1, current_year
    target_month_str = f"{target_year}-{target_month:02d}"

    steps_ahead, step_warning = 1, ""
    if not monthly_expenses.empty:
        last_date = monthly_expenses['Parsed_Date'].max()
        last_period = last_date.to_period('M')
        target_period = pd.Period(target_month_str, freq='M')
        steps_ahead = (target_period.to_timestamp().year - last_period.to_timestamp().year) * 12 + (target_period.to_timestamp().month - last_period.to_timestamp().month)
        if steps_ahead <= 0:
            target_period_dt = last_period.to_timestamp() + pd.DateOffset(months=1)
            target_month_str, target_month, target_year = target_period_dt.strftime('%Y-%m'), target_period_dt.month, target_period_dt.year
            steps_ahead = 1
            if "預測將順延" not in str(warnings_report):
                 warnings_report += f"\n{colors.YELLOW}警告：目標月份已過期，預測將自動順延至 ({target_month_str})。{colors.RESET}"
        if steps_ahead > 12:
            step_warning = f"{colors.YELLOW}警告：預測步數超過12 ({steps_ahead})，遠期預測不確定性增加。{colors.RESET}"

    predicted_expense_str, ci_str, method_used = "無法預測 (資料不足)", "", ""
    upper, lower, predicted_value = None, None, None
    historical_mae, historical_rmse, historical_wape, historical_mase = None, None, None, None
    historical_rmse_robust, historical_wape_robust = None, None
    quantile_preds, historical_pred, residuals = {}, None, None
    quantiles = [0.10, 0.25, 0.50, 0.75, 0.90]
    model_weights_report = ""
    seas_score, seas_components = None, None

    if analysis_data is not None and len(analysis_data) >= 2:
        num_months = len(analysis_data)
        data, x = analysis_data, np.arange(1, num_months + 1)

        if num_months >= 24:
            method_used = " (基於模型堆疊集成)"
            predicted_value, historical_pred, residuals, lower, upper, model_weights = run_stacked_ensemble_model(df_for_seasonal_model, steps_ahead)
            
            # --- 【★★★ 核心修改：修正報告排版 ★★★】 ---
            model_names = [
                "趨勢", "穩健", "慣性", "長期趨勢",
                "週期", "週期模仿",
                "天真", "近期平均", "近期中位", "歷史中位"
            ]
            
            # 1. 產生不含填充的報告片段
            report_parts = [f"{name}({weight:.1%})" for name, weight in zip(model_names, model_weights)]
            
            # 2. 將報告片段分組成每行最多3個
            chunk_size = 3
            chunks = [report_parts[i:i + chunk_size] for i in range(0, len(report_parts), chunk_size)]
            
            # 3. 將每個分組用 ", " 連接起來
            lines = [", ".join(chunk) for chunk in chunks]
            
            # 4. 用換行符和正確的縮排，將所有行組合成最終報告
            indentation = "\n" + " " * 14 # 換行符 + 與 "  - 專家權重: " 對齊的空白
            model_weights_report = f"  - 專家權重: {indentation.join(lines)}"
            
            # --- 【新增】計算 SEAS 綜合準確率評分 ---
            if historical_pred is not None and lower is not None and upper is not None:
                # 為了評估歷史回測的準確度，我們需要將預測值和區間對齊歷史數據
                # 這裡的 y_true 是 data, y_pred 是 historical_pred
                # 區間也需要是歷史回測期間的，而非對未來的預測
                # 腳本目前主要生成未來區間，此處為簡化演示，使用與未來預測相同的不確定性寬度
                uncertainty_width = (upper - lower) / 2
                hist_lower = historical_pred - uncertainty_width
                hist_upper = historical_pred + uncertainty_width

                seas_score, seas_components = calculate_seas(
                    y_true=data, 
                    y_pred=historical_pred, 
                    lower_bound=hist_lower, 
                    upper_bound=hist_upper, 
                    y_train=data # 使用自身作為訓練集來計算naive error
                )

        elif 18 <= num_months < 24:
            method_used = " (基於穩健迴歸IRLS-Huber)"
            predicted_value, historical_pred, residuals, lower, upper = huber_robust_regression(x, data, steps_ahead)
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
                n, x_mean, ssx = len(x), np.mean(x), np.sum((x-x_mean)**2)
                mse = np.sum((data-historical_pred)**2)/(n-2)
                se = np.sqrt(mse * (1 + 1/n + ((num_months+steps_ahead)-x_mean)**2/ssx))
                t_val = t.ppf(0.975, n-2)
                lower, upper = predicted_value - t_val*se, predicted_value + t_val*se
            elif model_logic == 'ema':
                ema = pd.Series(data).ewm(span=num_months, adjust=False).mean()
                predicted_value, historical_pred = ema.iloc[-1], ema.values
                residuals_ema = data - historical_pred
                bootstrap_preds = [ema.iloc[-1] + np.random.choice(residuals_ema,1)[0] for _ in range(1000)]
                lower, upper = np.percentile(bootstrap_preds, [2.5, 97.5])
            residuals = data - historical_pred

        ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)" if lower is not None and upper is not None else ""
        predicted_expense_str = f"{predicted_value:,.2f}"
        historical_mae, historical_rmse = np.mean(np.abs(residuals)), np.sqrt(np.mean(residuals**2))
        denominator = np.sum(np.abs(data))
        historical_wape = (np.sum(np.abs(residuals))/denominator*100) if denominator!=0 else None
        mae_naive = np.mean(np.abs(data[1:] - data[:-1])) if len(data)>1 else None
        historical_mase = (historical_mae/mae_naive) if mae_naive and mae_naive>0 else None
        res_quantiles = np.percentile(residuals, [q * 100 for q in quantiles])
        for i, q in enumerate(quantiles):
            quantile_preds[q] = historical_pred + res_quantiles[i]
            
        if num_months >= 12: 
            anomaly_info = calculate_anomaly_scores(data)
            is_shock = anomaly_info['Is_Shock'].values
            residuals_clean = residuals[~is_shock]
            data_clean = data[~is_shock]
            if len(residuals_clean) > 0:
                historical_rmse_robust = np.sqrt(np.mean(residuals_clean**2))
            if len(data_clean) > 0 and np.sum(np.abs(data_clean)) > 0:
                historical_wape_robust = (np.sum(np.abs(residuals_clean)) / np.sum(np.abs(data_clean))) * 100

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
        if num_unique_months >= 24:
            p25, p75, p95 = optimized_monte_carlo(monthly_expenses, predicted_value)
            mc_note = "已使用優化蒙地卡羅模擬。"
        else:
            p25, p75, p95 = monte_carlo_dashboard(monthly_expenses['Real_Amount'].values)

    calibration_results, acf_results, quantile_spread = {}, {}, 0.0
    if residuals is not None and len(residuals)>=2:
        calibration_results = compute_calibration_results(data, quantile_preds, quantiles)
        acf_results = compute_acf_results(residuals, num_months)
        quantile_spread = compute_quantile_spread(p25, p75, predicted_value)

    risk_status, risk_description, suggested_budget, _, _, _, _, data_reliability, error_coefficient, error_buffer, trend_scores, _, _, _, _ = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse, calibration_results=calibration_results, acf_results=acf_results, quantile_spread=quantile_spread)

    diagnostic_report = ""
    if residuals is not None and len(residuals)>=2:
        diagnostic_report = f"{quantile_loss_report(data, quantile_preds, quantiles, colors)}\n\n{model_calibration_analysis(data, quantile_preds, quantiles, colors)}\n\n{residual_autocorrelation_diagnosis(residuals, num_months, colors)}"

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
            print(f"  - WAPE (排除衝擊後): {colors.GREEN}{historical_wape_robust:.2f}% (反映日常預測誤差比例){colors.RESET}")
        
        # --- 【核心修改】根據是否有 SEAS 分數，切換顯示的準確率指標 ---
        if seas_score is not None:
            print(f"{colors.PURPLE}{colors.BOLD}  - SEAS (綜合準確率): {seas_score:.3f} (越低越好，全方位評估){colors.RESET}")
            print(f"{colors.WHITE}    └─ 穩健性 (UMBRAE): {seas_components['umbrae']:.3f} | 懲罰性 (RMSSE): {seas_components['rmsse']:.3f} | 誠實度 (MSIS): {seas_components['msis']:.3f}{colors.RESET}")
        elif historical_mase is not None: 
            print(f"  - MASE (平均絕對標度誤差): {historical_mase:.2f} (小於1優於天真預測)")


    if diagnostic_report:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 模型診斷儀表板 (進階誤差評估){colors.RESET}")
        print(diagnostic_report)

    print(f"\n{colors.CYAN}{colors.BOLD}>>> 預測方法摘要{colors.RESET}")
    print(f"  - 資料月份數: {num_unique_months}")
    print(f"  - {seasonal_note}")
    print(f"  - {mc_note}")
    print(f"  - 預測目標月份: {target_month_str} (距離資料 {steps_ahead} 個月)")
    if model_weights_report: print(model_weights_report)
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
        
        if is_advanced_model:
            change_date, num_shocks = trend_scores.get('change_date'), trend_scores.get('num_shocks', 0)
            if change_date: print(f"{colors.YELLOW}模式偵測: 偵測到您的支出模式在 {colors.BOLD}{change_date}{colors.RESET}{colors.YELLOW} 附近發生結構性轉變，後續評估將更側重於近期數據。{colors.RESET}")
            if num_shocks > 0: print(f"{colors.RED}衝擊偵測: 系統識別出 {colors.BOLD}{num_shocks} 次「真實衝擊」{colors.RESET}{colors.RED} (極端開銷)，已納入攤提金準備中。{colors.RESET}")

        if suggested_budget is not None:
            print(f"{colors.BOLD}建議 {target_month_str} 預算: {suggested_budget:,.2f} 元{colors.RESET}")
            if is_advanced_model:
                print(f"{colors.WHITE}    └ 計算依據 (三層式模型):{colors.RESET}")
                print(f"{colors.GREEN}      - 基礎日常預算 (P75): {trend_scores.get('base', 0):,.2f}{colors.RESET}")
                print(f"{colors.YELLOW}      - 巨額衝擊攤提金: {trend_scores.get('amortized', 0):,.2f}{colors.RESET}")
                print(f"{colors.RED}      - 模型誤差緩衝: {trend_scores.get('error', 0):,.2f}{colors.RESET}")
                if error_coefficient is not None: print(f"\n{colors.BOLD}模型誤差係數: {error_coefficient:.2f}{colors.RESET}")
            else:
                if error_buffer is not None and risk_buffer is not None: print(f"{colors.WHITE}    └ 計算依據：風險緩衝 ({risk_buffer:,.2f}) + 模型誤差緩衝 ({error_buffer:,.2f}){colors.RESET}")
                elif "替代公式" in data_reliability: print(f"{colors.WHITE}    └ 計算依據：近期平均支出 + 15% 固定緩衝。{colors.RESET}")

        if not is_advanced_model and trend_scores is not None and not isinstance(trend_scores, dict):
            print(f"\n{colors.BOLD}動態風險係數: {trend_scores:.3f}{colors.RESET}")
            if error_coefficient is not None: print(f"{colors.BOLD}模型誤差係數: {error_coefficient:.2f}{colors.RESET}")
            # Detailed risk factor printing logic...

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
