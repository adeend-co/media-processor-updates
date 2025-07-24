#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v2.81                #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。                        #
# 具備自動格式清理、互動式路徑輸入與多種模型預測、信賴區間等功能。                           #
# 更新 v2.81：修正 NameError，調整 expense_std_dev 的計算順序，確保           #
#             在呼叫預算評估函數前該變數已被定義，恢復腳本正常執行流程。            #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v2.81"  # Variable Definition Order Fix
SCRIPT_UPDATE_DATE = "2025-07-24"

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

# --- 【★★★ 新增：可自訂的季節性分析設定 ★★★】 ---
# 說明：此處設定模型要分析的季節性週期與其複雜度。
# 'periods': 您想分析的週期長度列表 (例如, [12, 6] 代表年度和學期)。
# 'k_terms': 每個週期的傅立葉階數 K (K 值越高，擬合的季節性曲線越複雜)。
SEASONALITY_CONFIG = {
    'periods': [12, 6],  # 年度週期 (12個月), 學期週期 (6個月)
    'k_terms': {
        12: 4,          # 使用 4 對 sin/cos 波來擬合年度模式
        6: 2            # 使用 2 對 sin/cos 波來擬合學期模式
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
from scipy.optimize import nnls, minimize
from collections import deque, Counter
from functools import partial

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

# --- 【★★★ 新增：傅立葉特徵生成函數 ★★★】 ---
def generate_fourier_features(time_index, config):
    """根據時間索引和設定生成傅立葉特徵。"""
    features = pd.DataFrame()
    for p in config['periods']:
        k_max = config['k_terms'].get(p)
        if k_max:
            for k in range(1, k_max + 1):
                sin_feat = np.sin(2 * np.pi * k * time_index / p)
                cos_feat = np.cos(2 * np.pi * k * time_index / p)
                features[f'sin_{k}_{p}'] = sin_feat
                features[f'cos_{k}_{p}'] = cos_feat
    return features

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

# --- 【★★★ v2.80 核心升級：智能事件插補法 ★★★】 ---
def detect_and_impute_recurring_events(monthly_expenses_df, colors):
    """
    自動偵測週期性高額事件，並使用周邊月份的中位數對其進行插補，
    以產生乾淨的基線序列用於模型訓練。
    """
    if len(monthly_expenses_df) < 24:
        # 資料不足，返回原始數據且不進行任何操作
        original_series = monthly_expenses_df['Real_Amount']
        return original_series.copy(), pd.Series(0.0, index=original_series.index), {}, ""

    df = monthly_expenses_df.copy().reset_index(drop=True)
    df['Month'] = df['Parsed_Date'].dt.month
    
    threshold = df['Real_Amount'].quantile(0.90)
    potential_events = df[df['Real_Amount'] > threshold]
    event_month_counts = potential_events['Month'].value_counts()
    recurring_event_months = event_month_counts[event_month_counts > 1].index.tolist()
    
    detected_events_avg = {}
    report_lines = []
    
    # 初始化基線序列為原始序列
    baseline_series = df['Real_Amount'].copy()
    
    if not recurring_event_months:
        return baseline_series, pd.Series(0.0, index=df.index), {}, ""

    # 標記所有非事件月份
    is_non_event_month = ~df['Month'].isin(recurring_event_months)

    for month in recurring_event_months:
        event_indices = df.index[df['Month'] == month].tolist()
        
        # 計算此月份的平均事件金額（僅用於報告）
        avg_event_amount = potential_events[potential_events['Month'] == month]['Real_Amount'].mean()
        detected_events_avg[month] = avg_event_amount
        report_lines.append(f"    - {colors.YELLOW}偵測到 {month} 月份的週期性高額事件{colors.RESET} (平均金額: {avg_event_amount:,.0f})")

        # 對每個事件實例進行插補
        for idx in event_indices:
            # 尋找前後最近的非事件月份的數據
            window = 2
            local_indices = df.index[
                (df.index >= idx - window) & (df.index <= idx + window) & (is_non_event_month)
            ]
            
            if not local_indices.empty:
                imputed_value = df.loc[local_indices, 'Real_Amount'].median()
            else:
                # 如果局部找不到，則使用全局非事件月份的中位數
                imputed_value = df.loc[is_non_event_month, 'Real_Amount'].median()
            
            # 在基線序列中用插補值替換原始值
            baseline_series.at[idx] = imputed_value

    # 事件序列 = 原始序列 - 清理後的基線序列
    events_series = df['Real_Amount'] - baseline_series
    events_series[events_series < 0] = 0 # 確保事件金額非負
    
    full_report = "\n".join(report_lines)
    
    return baseline_series, events_series, detected_events_avg, full_report


# --- 季節性分解函數 (未變更) ---
def seasonal_decomposition(monthly_expenses):
    monthly_expenses['Month'] = monthly_expenses['Parsed_Date'].dt.month
    monthly_avg = monthly_expenses.groupby('Month')['Real_Amount'].mean()
    overall_avg = monthly_expenses['Real_Amount'].mean()
    seasonal_indices = monthly_avg / overall_avg
    
    deseasonalized = monthly_expenses.copy()
    deseasonalized['Deseasonalized'] = deseasonalized['Real_Amount'] / deseasonalized['Month'].map(seasonal_indices)
    
    return deseasonalized, seasonal_indices

# --- 【v2.80 核心修正】優化蒙地卡羅模擬 ---
def optimized_monte_carlo(baseline_df, predicted_baseline, num_simulations=10000):
    """
    現在基於乾淨的「基線」數據進行模擬，以產生合理的日常波動範圍。
    """
    baseline_data = baseline_df['Real_Amount'].values
    x = np.arange(len(baseline_data))
    
    # 從基線數據中提取趨勢和殘差
    slope, intercept, _, _, _ = linregress(x, baseline_data)
    trend = intercept + slope * x
    residuals = baseline_data - trend
    
    # 如果殘差標準差為0，給予一個小的基礎波動
    if np.std(residuals) == 0 and np.mean(baseline_data) > 0:
        residuals = np.random.normal(0, np.mean(baseline_data) * 0.05, len(residuals))

    simulated = []
    for _ in range(num_simulations):
        sampled_residual = np.random.choice(residuals, size=1)[0]
        # 將波動加到「預測的基線」上
        sim_value = predicted_baseline + sampled_residual
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

# --- MPI 2.0 評估套件 ---
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

# --- 【★★★ 核心升級：MPI 2.0 雙重門檻混合評級系統 ★★★】 ---
def calculate_mpi_and_rate(y_true, historical_pred, global_wape, erai_score, mpi_percentile_rank):
    """
    根據 MPI 2.0 雙重門檻混合系統計算最終評級。
    此系統同時考量模型的「絕對效能 (MPI Score)」與「相對穩定性 (P-Rank)」。
    """
    wape_score = 1 - (global_wape / 100.0) if global_wape is not None else 0
    ss_res = np.sum((y_true - historical_pred)**2)
    ss_tot = np.sum((y_true - np.mean(y_true))**2)
    r_squared = 1 - (ss_res / ss_tot) if ss_tot > 1e-9 else 0
    r2_score = max(0, r_squared)
    
    aas = 0.7 * wape_score + 0.3 * r2_score
    rss = erai_score if erai_score is not None else 0
    mpi_score = 0.8 * aas + 0.2 * rss
    
    rating = "D-"
    suggestion = "請立即停止使用此模型的預測。建議檢查您的原始數據是否存在格式錯誤，或考慮更換其他分析方法。"

    if mpi_percentile_rank is None:
        rating = "N/A"
        suggestion = "交叉驗證失敗，無法進行混合評級。"
    else:
        # 絕對效能門檻 (Absolute Performance Gate)
        if mpi_score > 0.75:  # 卓越
            if mpi_percentile_rank > 85:
                rating = "A+ (行業頂尖)"
                suggestion = "卓越的典範。此模型不僅在您個人數據的回測中展現出頂尖的穩定性，其絕對預測能力也達到了業界公認的最高標準。它不僅能精準捕捉您消費模式的細微之處，更對潛在的財務風險有著深刻的洞察力。\n    └─ 建議行動: 此模型的預測結果**高度可信賴**，可作為您進行**關鍵長期財務規劃**（如年度預算、儲蓄目標、投資決策）的核心依據。"
            elif mpi_percentile_rank > 50:
                rating = "A (高效能)"
                suggestion = "極度可靠的財務夥伴。模型的綜合表現非常出色，在預測準確度和趨勢吻合度上均達到業界的優良標準，且在您的歷史數據上表現穩定。\n    └─ 建議行動: 您可以**充滿信心地採納**此模型的預算建議，它足以應對多數財務決策場景。"
            elif mpi_percentile_rank > 25:
                rating = "B (偶有佳作)"
                suggestion = "表現尚可，偶有亮點。此模型在絕對效能上達到卓越水準，但在穩定性上略有不足。總體而言，它具備基礎的預測能力。\n    └─ 建議行動: 可作為**趨勢判斷的輔助性參考**。採納其建議時，建議結合您自身的判斷。"
            else:
                rating = "C (曇花一現)"
                suggestion = "需要審慎對待。模型在「絕對效能」或「穩定性」兩個維度中，至少有一項存在明顯的短板。它可能對您的消費模式有著片面的理解，或其預測結果波動較大。\n    └─ 建議行動: **建議謹慎使用**其預測結果。在採納前，請務必詳細檢視報告中的「模型診斷儀表板」，了解其誤差主要來源。"
        elif mpi_score > 0.65:  # 良好
            if mpi_percentile_rank > 85:
                rating = "A- (穩健主力)"
                suggestion = "堅實可靠的主力模型。模型的絕對預測能力良好，且在您的數據上展現出高度的穩定性。這代表它不僅理解您的核心消費習慣，而且這種理解是經得起時間考驗的。\n    └─ 建議行動: 這是非常理想的**常規月度預算設定**參考，其預測結果穩健且值得信賴。"
            elif mpi_percentile_rank > 50:
                rating = "B+ (可靠)"
                suggestion = "值得信賴的分析師。模型的預測能力良好，且在您的數據上表現穩定。它能準確捕捉您大部分的消費趨勢，是一個可靠的日常財務助手。\n    └─ 建議行動: 預算建議**具有很高的參考價值**，適合用於多數日常財務管理。"
            elif mpi_percentile_rank > 25:
                rating = "C+ (差強人意)"
                suggestion = "需要審慎對待。模型在「絕對效能」或「穩定性」兩個維度中，至少有一項存在明顯的短板。它可能對您的消費模式有著片面的理解，或其預測結果波動較大。\n    └─ 建議行動: **建議謹慎使用**其預測結果。在採納前，請務必詳細檢視報告中的「模型診斷儀表板」，了解其誤差主要來源。"
            else:
                rating = "D+ (表現不穩)"
                suggestion = "存在明顯問題。此模型在絕對效能和穩定性上均表現不佳。它可能未能正確理解您消費模式的核心規律，或者其預測結果與簡單的基準模型相差無幾，甚至更差。\n    └─ 建議行動: **不建議採納**其預測結果。這通常意味著您的歷史數據過短、波動過於劇烈，或存在模型無法捕捉的複雜模式。"
        elif mpi_score > 0.50:  # 可接受
            if mpi_percentile_rank > 85:
                rating = "B (潛力股)"
                suggestion = "表現尚可，偶有亮點。此模型在穩定性上表現優異，但在絕對效能上略有不足。總體而言，它具備基礎的預測能力。\n    └─ 建議行動: 可作為**趨勢判斷的輔助性參考**。採納其建議時，建議結合您自身的判斷。"
            elif mpi_percentile_rank > 50:
                rating = "B- (基礎可用)"
                suggestion = "基礎的趨勢指標。模型的絕對預測能力尚可，穩定性也處於中等水平。它能大致反映您的消費方向，但可能無法捕捉到所有細節。\n    └─ 建議行動: 預算建議**僅供參考**，可作為您制定初步預算的起點。"
            elif mpi_percentile_rank > 25:
                rating = "C (僅供參考)"
                suggestion = "需要審慎對待。模型在「絕對效能」或「穩定性」兩個維度中，至少有一項存在明顯的短板。它可能對您的消費模式有著片面的理解，或其預測結果波動較大。\n    └─ 建議行動: **建議謹慎使用**其預測結果。在採納前，請務必詳細檢視報告中的「模型診斷儀表板」，了解其誤差主要來源。"
            else:
                rating = "D (有缺陷)"
                suggestion = "存在明顯問題。此模型在絕對效能和穩定性上均表現不佳。它可能未能正確理解您消費模式的核心規律，或者其預測結果與簡單的基準模型相差無幾，甚至更差。\n    └─ 建議行動: **不建議採納**其預測結果。這通常意味著您的歷史數據過短、波動過於劇烈，或存在模型無法捕捉的複雜模式。"
        else:  # < 0.50 (待觀察)
            if mpi_percentile_rank > 85:
                rating = "C (穩定但平庸)"
                suggestion = "需要審慎對待。模型在「絕對效能」或「穩定性」兩個維度中，至少有一項存在明顯的短板。它可能對您的消費模式有著片面的理解，或其預測結果波動較大。\n    └─ 建議行動: **建議謹慎使用**其預測結果。在採納前，請務必詳細檢視報告中的「模型診斷儀表板」，了解其誤差主要來源。"
            elif mpi_percentile_rank > 50:
                rating = "D+ (不可靠)"
                suggestion = "存在明顯問題。此模型在絕對效能和穩定性上均表現不佳。它可能未能正確理解您消費模式的核心規律，或者其預測結果與簡單的基準模型相差無幾，甚至更差。\n    └─ 建議行動: **不建議採納**其預測結果。這通常意味著您的歷史數據過短、波動過於劇烈，或存在模型無法捕捉的複雜模式。"
            elif mpi_percentile_rank > 25:
                rating = "D (有嚴重問題)"
                suggestion = "存在明顯問題。此模型在絕對效能和穩定性上均表現不佳。它可能未能正確理解您消費模式的核心規律，或者其預測結果與簡單的基準模型相差無幾，甚至更差。\n    └─ 建議行動: **不建議採納**其預測結果。這通常意味著您的歷史數據過短、波動過於劇烈，或存在模型無法捕捉的複雜模式。"
            else: # D- (完全不可信賴)
                pass # 使用預設的 D- 評級和建議
                
    return {
        'mpi_score': mpi_score, 'rating': rating, 'suggestion': suggestion,
        'components': {'absolute_accuracy': aas, 'relative_superiority': rss}
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
        
        # 【修正】在CV中也應用事件分解
        baseline_train, _, _, _ = detect_and_impute_recurring_events(train_df, colors)
        train_df_baseline = train_df.copy()
        train_df_baseline['Real_Amount'] = baseline_train
        
        _, _, detected_events_val, _ = detect_and_impute_recurring_events(val_df, colors)
        y_val_true = val_df['Real_Amount'].values # 真實值仍是原始總金額
        
        # 1. 在訓練集上運行完整的集成流程（但禁用內部打印）來獲取預測
        val_pred_seq, _, _, _, _, _, _ = \
            run_full_ensemble_pipeline(train_df_baseline, steps_ahead=len(val_df), colors=colors, verbose=False)
        
        if val_pred_seq is None or len(val_pred_seq) != len(y_val_true):
            continue
        
        # 重組預測
        val_df['Month'] = val_df['Parsed_Date'].dt.month
        predicted_events_val = val_df['Month'].map(detected_events_val).fillna(0).values
        val_pred = np.array(val_pred_seq) + predicted_events_val
            
        # 2. 【核心修正】計算此次迭代「真實」的MPI分數
        val_residuals = y_val_true - val_pred
        sum_abs_val_true = np.sum(np.abs(y_val_true))
        val_wape = (np.sum(np.abs(val_residuals)) / sum_abs_val_true * 100) if sum_abs_val_true > 1e-9 else 100.0

        # 計算ERAI所需的分位數預測和穩健WAPE
        # 在CV中，我們無法知道真實的衝擊，因此 robust wape 就等於全局 wape
        val_wape_robust = val_wape 
        # 殘差是相對於預測值計算的，不是相對於歷史擬合值
        val_quantile_preds = {q: val_pred + np.percentile(val_residuals, q*100) for q in [0.10, 0.25, 0.75, 0.90]}

        # 計算真實的相對優越性分數 (ERAI)
        rss_val = calculate_erai(y_val_true, val_pred, val_quantile_preds, val_wape_robust)
        if rss_val is None: rss_val = 0 # 如果計算失敗，給予中性分數

        # 計算絕對準確度分數
        val_wape_score = 1 - (val_wape / 100.0)
        ss_res_val = np.sum(val_residuals**2)
        ss_tot_val = np.sum((y_val_true - np.mean(y_val_true))**2)
        r2_val = 1 - (ss_res_val / ss_tot_val) if ss_tot_val > 1e-9 else 0
        r2_score_val = max(0, r2_val)
        aas_val = 0.7 * val_wape_score + 0.3 * r2_score_val
        
        # 組合最終的MPI分數
        mpi_score_val = 0.8 * aas_val + 0.2 * rss_val
        
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
# --- 【修正】此處為真正實作並整合霍特-溫特斯模型與傅立葉特徵的部分 ---

def train_predict_seasonal_naive(y_train, predict_steps, seasonal_period=12):
    """季節性單純預測法 (Seasonal Naive Method)。"""
    if len(y_train) < seasonal_period:
        return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)

    predictions = []
    for i in range(1, predict_steps + 1):
        idx = len(y_train) - seasonal_period + ((i - 1) % seasonal_period)
        predictions.append(y_train[idx])
    
    return np.array(predictions)

def train_predict_holt_winters(y_train, predict_steps, seasonal_period, model_type='add'):
    """
    霍特-溫特斯季節性模型 (包含自動參數尋優)。
    """
    if len(y_train) < 2 * seasonal_period:
        # 資料不足，退回為季節性單純預測法
        return train_predict_seasonal_naive(y_train, predict_steps, seasonal_period)

    y = np.array(y_train)

    def sse(params):
        alpha, beta, gamma = params
        if not (0 <= alpha <= 1 and 0 <= beta <= 1 and 0 <= gamma <= 1):
            return np.inf

        level = np.zeros_like(y)
        trend = np.zeros_like(y)
        season = np.zeros_like(y)
        
        # 初始化
        level[0] = y[0]
        trend[0] = (y[seasonal_period] - y[0]) / seasonal_period if len(y) > seasonal_period else 0
        
        initial_seasonals = [y[i] - np.mean(y[:seasonal_period]) for i in range(seasonal_period)]
        season[:seasonal_period] = initial_seasonals

        # 迭代計算
        for i in range(1, len(y)):
            level_old, trend_old = level[i-1], trend[i-1]
            season_idx = i - seasonal_period
            
            if model_type == 'add':
                level[i] = alpha * (y[i] - season[season_idx]) + (1 - alpha) * (level_old + trend_old)
                trend[i] = beta * (level[i] - level_old) + (1 - beta) * trend_old
                season[i] = gamma * (y[i] - level[i]) + (1 - gamma) * season[season_idx]
            else: # mul
                level_val = y[i] / season[season_idx] if season[season_idx] != 0 else y[i]
                level[i] = alpha * level_val + (1 - alpha) * (level_old + trend_old)
                trend[i] = beta * (level[i] - level_old) + (1 - beta) * trend_old
                season_val = y[i] / level[i] if level[i] != 0 else y[i]
                season[i] = gamma * season_val + (1 - gamma) * season[season_idx]
        
        # 計算擬合值和誤差
        if model_type == 'add':
            fitted = level + trend + season
        else:
            fitted = (level + trend) * season

        return np.sum((y - fitted)**2)

    # 尋找最佳參數
    initial_params = [0.3, 0.1, 0.1]
    bounds = [(0, 1), (0, 1), (0, 1)]
    result = minimize(sse, initial_params, bounds=bounds, method='L-BFGS-B')
    alpha_opt, beta_opt, gamma_opt = result.x

    # 使用最佳參數進行預測
    level_final = np.zeros(len(y) + predict_steps)
    trend_final = np.zeros(len(y) + predict_steps)
    season_final = np.zeros(len(y) + predict_steps)

    # 重新初始化
    level_final[0] = y[0]
    trend_final[0] = (y[seasonal_period] - y[0]) / seasonal_period if len(y) > seasonal_period else 0
    initial_seasonals_final = [y[i] - np.mean(y[:seasonal_period]) for i in range(seasonal_period)]
    season_final[:seasonal_period] = initial_seasonals_final

    # 重新迭代計算歷史數據
    for i in range(1, len(y)):
        level_old, trend_old = level_final[i-1], trend_final[i-1]
        season_idx = i - seasonal_period
        if model_type == 'add':
            level_final[i] = alpha_opt * (y[i] - season_final[season_idx]) + (1 - alpha_opt) * (level_old + trend_old)
            trend_final[i] = beta_opt * (level_final[i] - level_old) + (1 - beta_opt) * trend_old
            season_final[i] = gamma_opt * (y[i] - level_final[i]) + (1 - gamma_opt) * season_final[season_idx]
        else: # mul
            level_val = y[i] / season_final[season_idx] if season_final[season_idx] != 0 else y[i]
            level_final[i] = alpha_opt * level_val + (1 - alpha_opt) * (level_old + trend_old)
            trend_final[i] = beta_opt * (level_final[i] - level_old) + (1 - beta_opt) * trend_old
            season_val = y[i] / level_final[i] if level_final[i] != 0 else y[i]
            season_final[i] = gamma_opt * season_val + (1 - gamma_opt) * season_final[season_idx]

    # 預測未來
    predictions = []
    for i in range(len(y), len(y) + predict_steps):
        h = i - len(y) + 1
        season_idx = i - seasonal_period
        
        if model_type == 'add':
            pred = level_final[len(y)-1] + h * trend_final[len(y)-1] + season_final[season_idx]
        else: # mul
            pred = (level_final[len(y)-1] + h * trend_final[len(y)-1]) * season_final[season_idx]
        predictions.append(pred)
        
    return np.array(predictions)

def train_predict_huber(X_train, y_train, X_predict, t_const=1.345, max_iter=100, tol=1e-6):
    """
    Huber 穩健迴歸 (現已升級為可處理傅立葉特徵的多元穩健迴歸)。
    """
    if len(y_train) < 2:
        return np.full(len(X_predict), np.mean(y_train) if len(y_train) > 0 else 0)

    X_train_b = np.c_[np.ones(len(y_train)), X_train]
    
    try:
        # 初始係數來自普通最小平方法
        beta = np.linalg.lstsq(X_train_b, y_train, rcond=None)[0]
    except (np.linalg.LinAlgError, ValueError):
        # 如果失敗，使用一個基礎的猜測
        beta = np.zeros(X_train_b.shape[1])
        if len(y_train) > 0: beta[0] = np.mean(y_train)

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
            
    X_predict_b = np.c_[np.ones(len(X_predict)), X_predict]
    return X_predict_b @ beta

def train_predict_poly(X_train, y_train, X_predict, degree=2):
    """多項式迴歸 (現已升級為可處理傅立葉特徵的多元線性迴歸)。"""
    if len(y_train) < X_train.shape[1] + 1:
        return np.full(len(X_predict), np.mean(y_train) if len(y_train) > 0 else 0)

    # 為特徵矩陣加上截距項
    X_train_b = np.c_[np.ones(len(y_train)), X_train]
    X_predict_b = np.c_[np.ones(len(X_predict)), X_predict]
    
    try:
        # 使用最小平方法求解係數
        coeffs = np.linalg.lstsq(X_train_b, y_train, rcond=None)[0]
    except np.linalg.LinAlgError:
        # 如果求解失敗，退回為平均值
        return np.full(len(X_predict), np.mean(y_train) if len(y_train) > 0 else 0)
    
    return X_predict_b @ coeffs

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

def train_predict_moving_average(y_train, predict_steps, window_size=6):
    """移動平均預測 (Moving Average Forecast)。"""
    if len(y_train) == 0:
        return np.zeros(predict_steps)
    
    actual_window = min(len(y_train), window_size)
    if actual_window == 0:
        return np.zeros(predict_steps)
    
    mean_value = np.mean(y_train[-actual_window:])
    return np.full(predict_steps, mean_value)

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
    
    # 【修正】更新基礎模型團隊，加入新的季節性專家
    base_models = {
        'seasonal_poly': train_predict_poly,
        'seasonal_huber': train_predict_huber,
        'des': train_predict_des,
        'drift': train_predict_drift,
        'seasonal': train_predict_seasonal,
        'holt_winters_annual': partial(train_predict_holt_winters, seasonal_period=12, model_type='add'),
        'holt_winters_semester': partial(train_predict_holt_winters, seasonal_period=6, model_type='add'),
        'seasonal_naive': train_predict_seasonal_naive,
        'naive': train_predict_naive,
        'moving_average': train_predict_moving_average,
        'rolling_median': train_predict_rolling_median,
        'global_median': train_predict_global_median,
    }
    model_keys = list(base_models.keys())
    
    # 【修正】為整個數據集生成傅立葉特徵
    time_index_full = np.arange(1, n_samples + 1)
    fourier_features_full = generate_fourier_features(time_index_full, SEASONALITY_CONFIG)
    # 將趨勢項（時間索引）和傅立葉特徵結合成一個特徵矩陣
    X_features_full = pd.concat([pd.Series(x, name='trend'), fourier_features_full], axis=1).values

    meta_features = np.zeros((n_samples, len(base_models)))
    fold_indices = np.array_split(np.arange(n_samples), n_folds)
    
    for i in range(n_folds):
        train_idx = np.concatenate([fold_indices[j] for j in range(n_folds) if i != j])
        val_idx = fold_indices[i]
        
        if len(train_idx) == 0: continue

        y_train, df_train = data[train_idx], monthly_expenses_df.iloc[train_idx]
        x_val = x[val_idx]
        
        # 【修正】為訓練集和驗證集準備對應的特徵矩陣
        X_features_train = X_features_full[train_idx]
        X_features_val = X_features_full[val_idx]
        
        for j, key in enumerate(model_keys):
            model_func = base_models[key]
            # 【修正】根據模型類型傳遞正確的輸入
            if key in ['seasonal_poly', 'seasonal_huber']:
                 prediction_result = model_func(X_features_train, y_train, X_features_val)
            elif key in ['seasonal']:
                 prediction_result = model_func(df_train, len(x_val))
            else: # 所有其他模型 (des, drift, holt_winters, naives, MAs, medians)
                 prediction_result = model_func(y_train, len(x_val))

            # --- 【v2.71 核心修正】注入穩定性層 ---
            if not np.all(np.isfinite(prediction_result)):
                safe_fallback = np.median(y_train) if len(y_train) > 0 else 0
                prediction_result = np.nan_to_num(prediction_result, nan=safe_fallback, posinf=safe_fallback, neginf=safe_fallback)
            
            meta_features[val_idx, j] = prediction_result

    selected_indices, _ = train_greedy_forward_ensemble(meta_features, data, model_keys, n_iterations=ensemble_size, colors=colors, verbose=verbose)

    model_counts = Counter(selected_indices)
    model_weights = np.zeros(len(base_models))
    if selected_indices:
        total_selections = len(selected_indices)
        for idx, count in model_counts.items():
            model_weights[idx] = count / total_selections
    else:
        model_weights = np.full(len(base_models), 1 / len(base_models))

    # 【修正】為未來預測生成特徵矩陣
    x_future = np.arange(n_samples + 1, n_samples + steps_ahead + 1)
    time_index_future = np.arange(n_samples + 1, n_samples + steps_ahead + 1)
    fourier_features_future = generate_fourier_features(time_index_future, SEASONALITY_CONFIG)
    X_features_future = pd.concat([pd.Series(x_future, name='trend'), fourier_features_future], axis=1).values
    
    final_base_predictions = np.zeros((steps_ahead, len(base_models)))

    for j, key in enumerate(model_keys):
        model_func = base_models[key]
        # 【修正】為最終預測傳遞正確的輸入
        if key in ['seasonal_poly', 'seasonal_huber']:
            prediction_result = model_func(X_features_full, data, X_features_future)
        elif key in ['seasonal']:
            prediction_result = model_func(monthly_expenses_df, steps_ahead)
        else:
            prediction_result = model_func(data, steps_ahead)
            
        # --- 【v2.71 核心修正】注入穩定性層 ---
        if not np.all(np.isfinite(prediction_result)):
            safe_fallback = np.median(data) if len(data) > 0 else 0
            prediction_result = np.nan_to_num(prediction_result, nan=safe_fallback, posinf=safe_fallback, neginf=safe_fallback)
        
        final_base_predictions[:, j] = prediction_result
    
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
        print_progress_bar(0, n_bootstrap, prefix='權重校準進度:', suffix='完成', length=40)

    for i in range(n_bootstrap):
        bootstrap_res = np.random.choice(clean_residuals, size=n_samples, replace=True)
        y_bootstrap = base_predictions + bootstrap_res
        
        # 在此模擬數據上，尋找 L1 模型的最佳組合
        selected_indices_for_iter, _ = train_greedy_forward_ensemble(
            X_level2_hist, y_bootstrap, list(range(n_models)), n_iterations=n_models, colors=colors, verbose=False
        )
        
        ensemble_selection_counts.update(selected_indices_for_iter)
        
        if verbose:
            print_progress_bar(i + 1, n_bootstrap, prefix='權重校準進度:', suffix='完成', length=40)

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

    # 【修正】定義包含新模型的團隊
    base_models = {
        'seasonal_poly': train_predict_poly,
        'seasonal_huber': train_predict_huber,
        'des': train_predict_des,
        'drift': train_predict_drift,
        'seasonal': train_predict_seasonal,
        'holt_winters_annual': partial(train_predict_holt_winters, seasonal_period=12, model_type='add'),
        'holt_winters_semester': partial(train_predict_holt_winters, seasonal_period=6, model_type='add'),
        'seasonal_naive': train_predict_seasonal_naive,
        'naive': train_predict_naive,
        'moving_average': train_predict_moving_average,
        'rolling_median': train_predict_rolling_median,
        'global_median': train_predict_global_median,
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
    
    # 【修正】為未來預測生成特徵矩陣
    x_future = np.arange(num_months + 1, num_months + steps_ahead + 1)
    time_index_future = np.arange(num_months + 1, num_months + steps_ahead + 1)
    fourier_features_future = generate_fourier_features(time_index_future, SEASONALITY_CONFIG)
    X_features_future = pd.concat([pd.Series(x_future, name='trend'), fourier_features_future], axis=1).values
    
    # 【修正】為完整歷史數據生成特徵矩陣
    time_index_full = np.arange(1, num_months + 1)
    fourier_features_full = generate_fourier_features(time_index_full, SEASONALITY_CONFIG)
    X_features_full = pd.concat([pd.Series(x, name='trend'), fourier_features_full], axis=1).values
    
    future_base_predictions = np.zeros((steps_ahead, len(base_models)))
    for j, key in enumerate(model_keys):
        model_func = base_models[key]
        # 【修正】根據模型類型傳遞正確的輸入
        if key in ['seasonal_poly', 'seasonal_huber']:
            future_base_predictions[:, j] = model_func(X_features_full, data, X_features_future)
        elif key in ['seasonal']:
            future_base_predictions[:, j] = model_func(monthly_expenses_df, steps_ahead)
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
    if verbose: print(f"{colors.CYAN}--- 階段 3/3: 執行殘差提升 (Boosting) 最終修正... ---{colors.RESET}")
    T = 10
    learning_rate = 0.1
    historical_pred_final = historical_pred_fused.copy()
    future_pred_final_seq = future_pred_fused_seq.copy()
    
    # 使用帶有傅立葉特徵的 Huber 模型進行殘差擬合
    weak_model_func = base_models['seasonal_huber']

    for _ in range(T):
        residuals_boost = data - historical_pred_final
        res_pred_hist = weak_model_func(X_features_full, residuals_boost, X_features_full)
        res_pred_future_seq = weak_model_func(X_features_full, residuals_boost, X_features_future)
        historical_pred_final += learning_rate * res_pred_hist
        future_pred_final_seq += learning_rate * res_pred_future_seq

    effective_base_weights = (gfs_weights * weights_level2[0]) + (pwa_weights * weights_level2[1]) + (nnls_weights * weights_level2[2])
    
    dof = num_months - X_level2_hist_oof.shape[1] - 1
    lower_seq, upper_seq = None, None
    if dof > 0:
        residuals_final = data - historical_pred_final
        mse = np.sum(residuals_final**2) / dof
        se = np.sqrt(mse) * np.sqrt(1 + 1/num_months)
        t_val = t.ppf(0.975, dof)
        lower_seq, upper_seq = future_pred_final_seq - t_val*se, future_pred_final_seq + t_val*se
    
    meta_model_names = ["貪婪前向選擇法", "性能加權平均法", "非負最小平方法"]
    meta_model_weights_for_report = {name: w for name, w in zip(meta_model_names, weights_level2)}

    return future_pred_final_seq, historical_pred_final, effective_base_weights, meta_model_weights_for_report, lower_seq, upper_seq, historical_base_preds_df


# --- 主要分析與預測函數 ---
def analyze_and_predict(file_paths_str: str, no_color: bool):
    colors = Colors(enabled=not no_color)
    file_paths = [path.strip() for path in file_paths_str.split(';')]

    master_df, monthly_expenses, warnings_report = process_finance_data_multiple(file_paths, colors)

    if monthly_expenses is None or monthly_expenses.empty:
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

    # --- 【v2.80 核心修正】事件導向分解 ---
    event_decomposition_report = ""
    detected_events = {}
    if not monthly_expenses.empty:
        baseline_amount, events_amount, detected_events, event_decomposition_report = \
            detect_and_impute_recurring_events(monthly_expenses, colors)
        
        # 創建一個專門用於建模的 DataFrame
        df_for_modeling = monthly_expenses.copy()
        # **關鍵**：用插補後的基線數據替換原始數據，作為模型的訓練目標
        df_for_modeling['Real_Amount'] = baseline_amount.values
    else:
        df_for_modeling = pd.DataFrame(columns=['Parsed_Date', 'Amount', 'Real_Amount'])

    seasonal_note = "未使用季節性分解（資料月份不足 24 個月）。"
    analysis_data = None
    if not df_for_modeling.empty:
        if num_unique_months >= 24:
            analysis_data = df_for_modeling['Real_Amount'].values
            seasonal_note = "集成模型已內建季節性分析。"
        else:
            analysis_data = df_for_modeling['Real_Amount'].values

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
    
    # --- 【v2.81 核心修正】將 expense_std_dev 的計算提前 ---
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
    base_model_weights_report = ""
    meta_model_weights_report = ""
    mpi_results = None
    cv_mpi_scores = None

    if analysis_data is not None and len(analysis_data) >= 2:
        num_months = len(analysis_data)
        data = analysis_data # `data` is now baseline data if decomposition happened
        x = np.arange(1, num_months + 1)
        
        predicted_baseline = None
        lower_baseline, upper_baseline = None, None

        if num_months >= 24:
            method_used = " (基於事件分解 + 混合集成法)"
            
            future_pred_final_seq, historical_pred, effective_base_weights, weights_level2_report, lower_seq, upper_seq, _ = \
                run_full_ensemble_pipeline(df_for_modeling, steps_ahead, colors, verbose=True)

            predicted_baseline = future_pred_final_seq[-1]
            lower_baseline = lower_seq[-1] if lower_seq is not None else None
            upper_baseline = upper_seq[-1] if upper_seq is not None else None
            
            report_parts_meta = [f"{name}({weight:.1%})" for name, weight in weights_level2_report.items() if weight > 0.001]
            meta_model_weights_report = f"  - 元模型融合策略: {', '.join(report_parts_meta)}"
            
            model_names_base = ["季節性多項式", "季節性穩健趨勢", "指數平滑", "漂移", "季節分解", "霍特-溫特斯(年)", "霍特-溫特斯(學期)", "季節模仿", "單純", "移動平均", "滾動中位", "全局中位"]
            sorted_parts = sorted(zip(effective_base_weights, model_names_base), reverse=True)
            report_parts_base_sorted = [f"{name}({weight:.1%})" for weight, name in sorted_parts if weight > 0.001]
            chunk_size = 3
            chunks = [report_parts_base_sorted[i:i + chunk_size] for i in range(0, len(report_parts_base_sorted), chunk_size)]
            lines = [", ".join(chunk) for chunk in chunks]
            indentation = "\n" + " " * 16
            base_model_weights_report = f"  - 基礎模型權重: {indentation.join(lines)}"
        
        elif 18 <= num_months < 24:
            method_used = " (基於穩健迴歸IRLS-Huber)"
            pred_seq, historical_pred, _, lower_seq, upper_seq = huber_robust_regression(x, data, steps_ahead)
            predicted_baseline = pred_seq[-1]
            lower_baseline = lower_seq[-1] if lower_seq is not None else None
            upper_baseline = upper_seq[-1] if upper_seq is not None else None
        else:
            method_used = " (基於直接-遞歸混合)"
            model_logic = 'poly' if num_months >= 12 else 'linear' if num_months >= 6 else 'ema'
            if model_logic == 'poly':
                predicted_baseline, lower_baseline, upper_baseline = polynomial_regression_with_ci(x, data, 2, num_months + steps_ahead)
                historical_pred = np.poly1d(np.polyfit(x, data, 2))(x)
            elif model_logic == 'linear':
                slope, intercept, _, _, _ = linregress(x, data)
                predicted_baseline = intercept + slope * (num_months + steps_ahead)
                historical_pred = intercept + slope * x
                n, x_mean, ssx = len(x), np.mean(x), np.sum((x-x_mean)**2)
                if n > 2:
                    mse = np.sum((data-historical_pred)**2)/(n-2)
                    se = np.sqrt(mse * (1 + 1/n + ((num_months+steps_ahead)-x_mean)**2/ssx))
                    t_val = t.ppf(0.975, n-2)
                    lower_baseline, upper_baseline = predicted_baseline - t_val*se, predicted_baseline + t_val*se
            elif model_logic == 'ema':
                ema = pd.Series(data).ewm(span=num_months, adjust=False).mean()
                predicted_baseline, historical_pred = ema.iloc[-1], ema.values

        # --- 【v2.80 核心修正】結果重組 ---
        predicted_event = detected_events.get(target_month, 0)
        predicted_value = predicted_baseline + predicted_event
        lower = lower_baseline + predicted_event if lower_baseline is not None else None
        upper = upper_baseline + predicted_event if upper_baseline is not None else None
        
        y_true_original = monthly_expenses['Real_Amount'].values
        historical_pred_events = events_amount.values
        historical_pred_final = historical_pred + historical_pred_events
        
        if historical_pred_final is not None:
            residuals = y_true_original - historical_pred_final
            ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)"
            if predicted_event > 0:
                ci_str += f" (基線 {predicted_baseline:,.0f} + 事件 {predicted_event:,.0f})"
            predicted_expense_str = f"{predicted_value:,.2f}"

            historical_mae, historical_rmse = np.mean(np.abs(residuals)), np.sqrt(np.mean(residuals**2))
            
            sum_abs_actual = np.sum(np.abs(y_true_original))
            historical_wape = (np.sum(np.abs(residuals)) / sum_abs_actual * 100) if sum_abs_actual > 1e-9 else 100.0
            
            if len(y_true_original) > 1:
                mae_naive = np.mean(np.abs(y_true_original[1:] - y_true_original[:-1]))
                historical_mase = (historical_mae/mae_naive) if mae_naive and mae_naive>0 else None
            else:
                historical_mase = None

            res_quantiles = np.percentile(residuals, [q * 100 for q in quantiles])
            for i, q in enumerate(quantiles):
                quantile_preds[q] = historical_pred_final + res_quantiles[i]
                
            if num_months >= 12: 
                anomaly_info = calculate_anomaly_scores(y_true_original)
                is_shock_flags = anomaly_info['Is_Shock'].values
                residuals_clean = residuals[~is_shock_flags]
                data_clean = y_true_original[~is_shock_flags]
                if len(residuals_clean) > 0:
                    historical_rmse_robust = np.sqrt(np.mean(residuals_clean**2))
                
                sum_abs_clean = np.sum(np.abs(data_clean))
                if len(data_clean) > 0 and sum_abs_clean > 1e-9:
                    historical_wape_robust = (np.sum(np.abs(residuals_clean)) / sum_abs_clean) * 100
            
            if num_months >= 24:
                base_models_cv = {
                    'seasonal_poly': train_predict_poly, 'seasonal_huber': train_predict_huber, 'des': train_predict_des,
                    'drift': train_predict_drift, 'seasonal': train_predict_seasonal,
                    'holt_winters_annual': partial(train_predict_holt_winters, seasonal_period=12, model_type='add'),
                    'holt_winters_semester': partial(train_predict_holt_winters, seasonal_period=6, model_type='add'),
                    'seasonal_naive': train_predict_seasonal_naive, 'naive': train_predict_naive,
                    'moving_average': train_predict_moving_average, 'rolling_median': train_predict_rolling_median,
                    'global_median': train_predict_global_median,
                }
                _, cv_mpi_scores = run_monte_carlo_cv(monthly_expenses, base_models_cv, n_iterations=100, colors=colors)

                erai_results = perform_internal_benchmarking(y_true_original, historical_pred_final, is_shock_flags)
                
                backtest_mpi_score = calculate_mpi_and_rate(y_true_original, historical_pred_final, historical_wape, erai_results['erai_score'], 100)['mpi_score']
                mpi_percentile_rank = None
                if cv_mpi_scores and len(cv_mpi_scores) > 0:
                    mpi_percentile_rank = percentileofscore(cv_mpi_scores, backtest_mpi_score, kind='rank')

                mpi_results = calculate_mpi_and_rate(
                    y_true=y_true_original,
                    historical_pred=historical_pred_final,
                    global_wape=historical_wape,
                    erai_score=erai_results['erai_score'],
                    mpi_percentile_rank=mpi_percentile_rank
                )

    p25, p75, p95 = None, None, None
    mc_note = "未使用蒙地卡羅（數據不足24月）。"
    if not monthly_expenses.empty and len(monthly_expenses)>=2:
        if num_unique_months >= 24 and predicted_value is not None:
            # --- 【v2.80 核心修正】統一蒙地卡羅數據源 ---
            p25_base, p75_base, p95_base = optimized_monte_carlo(df_for_modeling, predicted_baseline)
            predicted_event_mc = detected_events.get(target_month, 0)
            p25 = p25_base + predicted_event_mc
            p75 = p75_base + predicted_event_mc
            p95 = p95_base + predicted_event_mc
            mc_note = "已使用基於事件分解的優化蒙地卡羅模擬。"
        else:
            p25, p75, p95 = monte_carlo_dashboard(monthly_expenses['Real_Amount'].values)

    calibration_results, acf_results, quantile_spread = {}, {}, 0.0
    if residuals is not None and len(residuals)>=2:
        calibration_results = compute_calibration_results(y_true_original, quantile_preds, quantiles)
        acf_results = compute_acf_results(residuals, num_months)
        quantile_spread = compute_quantile_spread(p25, p75, predicted_value)

    risk_status, risk_description, suggested_budget, _, _, _, _, data_reliability, error_coefficient, error_buffer, trend_scores, _, _, _, _ = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse, calibration_results=calibration_results, acf_results=acf_results, quantile_spread=quantile_spread)

    diagnostic_report = ""
    if residuals is not None and len(residuals)>=2:
        diagnostic_report = f"{quantile_loss_report(y_true_original, quantile_preds, quantiles, colors)}\n\n{model_calibration_analysis(y_true_original, quantile_preds, quantiles, colors)}\n\n{residual_autocorrelation_diagnosis(residuals, num_months, colors)}"

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
            print(f"{colors.PURPLE}{colors.BOLD}  - MPI 2.0 (綜合效能指數): {mpi_display_str}  評級: {rating}{colors.RESET}")
            print(f"{colors.WHITE}    └─ 絕對準確度: {components['absolute_accuracy']:.3f} | 相對優越性 (ERAI): {components['relative_superiority']:.3f}{colors.RESET}")
            print(f"{colors.WHITE}    └─ {suggestion}{colors.RESET}")


    if diagnostic_report:
        print(f"\n{colors.CYAN}{colors.BOLD}>>> 模型診斷儀表板 (進階誤差評估){colors.RESET}")
        print(diagnostic_report)

    print(f"\n{colors.CYAN}{colors.BOLD}>>> 預測方法摘要{colors.RESET}")
    print(f"  - 資料月份數: {num_unique_months}")
    if event_decomposition_report:
        print(f"{colors.CYAN}  - 自動事件偵測與分解:{colors.RESET}")
        print(event_decomposition_report)
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
                if error_buffer is not None and 'risk_buffer' in locals() and risk_buffer is not None: print(f"{colors.WHITE}    └ 計算依據：風險緩衝 ({risk_buffer:,.2f}) + 模型誤差緩衝 ({error_buffer:,.2f}){colors.RESET}")
                elif "替代公式" in data_reliability: print(f"{colors.WHITE}    └ 計算依據：近期平均支出 + 15% 固定緩衝。{colors.RESET}")

        if not is_advanced_model and trend_scores is not None and not isinstance(trend_scores, dict):
            pass

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
