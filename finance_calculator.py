#!/usr/bin/env python3

################################################################################
#                                                                              #
#             進階財務分析與預測器 (Advanced Finance Analyzer) v3.6.4               #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本為一個獨立 Python 工具，專為處理複雜且多樣的財務數據而設計。                        #
# 具備自動格式清理、互動式路徑輸入與多種模型預測、信賴區間等功能。                           #
# 更新 v3.5.3：修復專家門控 DRF 模型呼叫參數錯誤 (steps_ahead mismatch)。               #
#             保留 v3.5.2 的智慧型雙模式校準與所有進階分析功能。                        #
#                                                                              #
################################################################################

# --- 腳本元數據 ---
SCRIPT_NAME = "進階財務分析與預測器"
SCRIPT_VERSION = "v3.6.4"
SCRIPT_UPDATE_DATE = "2026-01-08"

# --- 新增：可完全自訂的表格寬度設定 ---
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
from scipy.optimize import nnls, minimize
from scipy import signal, stats, linalg
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


# ==============================================================================
# [全自動貝氏模型平均系統 (Fully Automated BMA System)]
# 特性：
# 1. 貝氏模型平均 (BMA): 自動根據「模型證據 (Evidence)」計算不同時間窗口的權重。
# 2. 學生 t-分佈 (Student-t): 自動根據樣本數調整信賴區間寬度，解決過度自信。
# 3. 全參數自動化: Alpha, Beta, Regime Weights, Degrees of Freedom 全部自動計算。
# ==============================================================================

class BayesianInferenceEngine:
    def __init__(self, add_bias=True):
        self.add_bias = add_bias
        # 狀態記憶
        self.y_scaler_mean = 0.0
        self.y_scaler_std = 1.0
        
        # [BMA 核心] 儲存多個體制模型的參數與權重
        # 結構: list of dict {'w_mean', 'w_cov', 'alpha', 'beta', 'phi_func', 'weight', 'N'}
        self.models = [] 
        self.use_seasonality_global = False # 用於預測時的維度鎖定

    def _build_design_matrix(self, times, cycle=12, force_seasonality=None):
        """建立設計矩陣 (維度鎖定邏輯)"""
        # 1. 決定季節性
        if force_seasonality is not None:
            enable_seasonal = force_seasonality
        else:
            # 訓練時：若該段資料跨度 >= 24 個月才啟用
            enable_seasonal = (len(times) > 0 and (np.max(times) - np.min(times)) >= 24)

        # 2. 建構矩陣
        if not enable_seasonal:
            X = times.reshape(-1, 1)
        else:
            X = np.column_stack([
                times,
                np.sin(2 * np.pi * times / cycle),
                np.cos(2 * np.pi * times / cycle)
            ])
            
        if self.add_bias:
            return np.hstack([np.ones((X.shape[0], 1)), X])
        return X

    def _compute_log_evidence(self, M, N, alpha, beta, m_N, y, Phi):
        """計算對數模型證據 (Log Model Evidence)"""
        error_term = np.sum((y - Phi @ m_N)**2)
        weight_penalty = np.sum(m_N**2)
        E_mN = (beta / 2) * error_term + (alpha / 2) * weight_penalty

        A = alpha * np.eye(M) + beta * (Phi.T @ Phi)
        try:
            L = linalg.cholesky(A, lower=True)
            log_det_A = 2 * np.sum(np.log(np.diag(L)))
        except linalg.LinAlgError:
            sign, log_det_A = np.linalg.slogdet(A)

        # Evidence Formula (Bishop 3.86)
        log_evidence = (M / 2) * np.log(alpha) + \
                       (N / 2) * np.log(beta) - \
                       E_mN - \
                       (0.5 * log_det_A) - \
                       (N / 2) * np.log(2 * np.pi)
        return log_evidence

    def fit_bma(self, times, y, max_iter=20, tol=1e-5):
        """
        [核心] 執行貝氏模型平均 (BMA) 訓練
        完全不依賴人工參數，而是同時訓練多個「候選體制」，
        並根據它們的證據力 (Evidence) 自動分配權重。
        """
        # 1. 數據標準化
        self.y_scaler_mean = np.mean(y)
        self.y_scaler_std = np.std(y)
        if self.y_scaler_std < 1e-9: self.y_scaler_std = 1.0
        y_scaled = (y - self.y_scaler_mean) / self.y_scaler_std

        total_len = len(times)
        self.models = [] # 清空舊模型

        # 2. 定義候選體制 (Candidate Regimes)
        # 自動產生候選窗口：全歷史、最近 1/2、最近 1/4...
        # 這些代表不同的「假設」：假設規律是長期的 vs 假設規律是近期的
        candidate_starts = [0]
        if total_len >= 12: candidate_starts.append(int(total_len * 0.5))
        if total_len >= 24: candidate_starts.append(int(total_len * 0.75))
        
        # 過濾掉太短的 (<6)
        candidate_starts = [s for s in candidate_starts if (total_len - s) >= 6]
        
        log_evidences = []

        # 3. 平行訓練所有候選模型
        for start_idx in candidate_starts:
            t_sub = times[start_idx:]
            y_sub = y_scaled[start_idx:]
            
            # 自動判斷該體制的季節性特徵
            Phi = self._build_design_matrix(t_sub)
            use_seasonality = (Phi.shape[1] > 2) if self.add_bias else (Phi.shape[1] > 1)
            
            N, M = Phi.shape
            PhiT_Phi = Phi.T @ Phi
            PhiT_y = Phi.T @ y_sub
            eigvals = linalg.eigvalsh(PhiT_Phi)
            
            # MacKay 優化
            alpha, beta = 1.0, 1.0 / (np.var(y_sub) + 1e-6)
            w_mean, w_cov = None, None
            
            for i in range(max_iter):
                # E-Step
                A = alpha * np.eye(M) + beta * PhiT_Phi
                try:
                    L = linalg.cholesky(A, lower=True)
                    S_N = linalg.cho_solve((L, True), np.eye(M))
                    w_mean = beta * S_N @ PhiT_y
                except linalg.LinAlgError:
                    S_N = np.linalg.pinv(A)
                    w_mean = beta * S_N @ PhiT_y
                
                # M-Step
                gamma = np.sum(eigvals / (alpha + eigvals))
                alpha = gamma / (np.sum(w_mean ** 2) + 1e-8)
                residuals = y_sub - Phi @ w_mean
                error = np.sum(residuals ** 2)
                beta = (N - gamma) / (error + 1e-8)
            
            w_cov = S_N
            
            # 計算該模型的證據力
            log_ev = self._compute_log_evidence(M, N, alpha, beta, w_mean, y_sub, Phi)
            log_evidences.append(log_ev)
            
            # 儲存模型參數
            self.models.append({
                'w_mean': w_mean,
                'w_cov': w_cov,
                'alpha': alpha,
                'beta': beta,
                'use_seasonality': use_seasonality,
                'N': N, # 樣本數 (用於計算自由度)
                'start_idx': start_idx
            })

        # 4. 計算 BMA 權重 (Softmax on Log Evidences)
        # 權重 = exp(L_i) / sum(exp(L_j))
        # 使用 max trick 避免數值溢位
        log_ev_array = np.array(log_evidences)
        max_log_ev = np.max(log_ev_array)
        weights_unnormalized = np.exp(log_ev_array - max_log_ev)
        weights = weights_unnormalized / np.sum(weights_unnormalized)
        
        # 將權重寫回模型列表
        for i, model in enumerate(self.models):
            model['weight'] = weights[i]
            
        # 紀錄全域季節性狀態 (取權重最大的那個模型的設定，用於維度對齊)
        best_model_idx = np.argmax(weights)
        self.use_seasonality_global = self.models[best_model_idx]['use_seasonality']

    def predict_bma(self, times_new):
        """
        計算 BMA 加權預測值
        Mean = sum(w_i * mu_i)
        Var = sum(w_i * (var_i + mu_i^2)) - Mean^2  (Law of Total Variance)
        """
        means = []
        variances = []
        weights = []
        effective_dofs = [] # 有效自由度

        for model in self.models:
            # 使用該模型特定的季節性設定建構矩陣
            Phi_new = self._build_design_matrix(times_new, force_seasonality=model['use_seasonality'])
            
            # 預測均值
            mu = Phi_new @ model['w_mean']
            
            # 預測變異數 (Data Noise + Model Uncertainty)
            sigma2 = (1.0 / model['beta']) + np.sum(Phi_new @ model['w_cov'] * Phi_new, axis=1)
            
            means.append(mu)
            variances.append(sigma2)
            weights.append(model['weight'])
            effective_dofs.append(model['N']) # 該模型的樣本數

        # 轉換為 numpy array 方便運算
        means = np.array(means)   # shape: (n_models, n_times)
        variances = np.array(variances)
        weights = np.array(weights).reshape(-1, 1) # shape: (n_models, 1)
        
        # 1. BMA Mean
        bma_mean_scaled = np.sum(weights * means, axis=0)
        
        # 2. BMA Variance (Law of Total Variance)
        # 變異數 = 內部變異數期望值 + 均值間的變異數
        term1 = np.sum(weights * variances, axis=0)
        term2 = np.sum(weights * (means ** 2), axis=0)
        bma_var_scaled = term1 + term2 - (bma_mean_scaled ** 2)
        bma_std_scaled = np.sqrt(bma_var_scaled)
        
        # 3. 計算加權自由度 (Weighted Degrees of Freedom)
        # 用於 Student-t 分佈
        weighted_dof = np.sum(weights.flatten() * np.array(effective_dofs))
        
        # [還原縮放]
        y_pred = bma_mean_scaled * self.y_scaler_std + self.y_scaler_mean
        y_std = bma_std_scaled * self.y_scaler_std
        
        return y_pred, y_std, weighted_dof
    
    def validate_prequential(self, times, y, start_idx=12):
        """誠實回測"""
        pred_means = []
        pred_stds = []
        pred_dofs = []
        y_trues = []
        
        for t in range(start_idx, len(times)):
            t_train = times[:t]
            y_train = y[:t]
            t_test = times[t:t+1]
            y_test = y[t]
            
            engine_snapshot = BayesianInferenceEngine(self.add_bias)
            engine_snapshot.fit_bma(t_train, y_train) # 每一輪都重新計算 BMA 權重
            
            pm, ps, dof = engine_snapshot.predict_bma(t_test)
            pred_means.append(pm[0])
            pred_stds.append(ps[0])
            pred_dofs.append(dof)
            y_trues.append(y_test)
            
        return np.array(y_trues), np.array(pred_means), np.array(pred_stds), np.array(pred_dofs)

    def evaluate_metrics(self, y_true, y_pred_mean, y_pred_std, dofs):
        """
        計算評估指標 (使用 Student-t 分佈)
        這是解決 C 級評分的關鍵：使用 t 分佈計算機率，而非高斯分佈。
        """
        if len(y_true) == 0: return {"CRPS": np.nan, "ICP": np.nan, "LogScore": np.nan}
        
        # 使用 t 分佈計算 Z-score 對應的機率
        # t.cdf(x, df)
        z = (y_true - y_pred_mean) / (y_pred_std + 1e-9)
        
        # 向量化計算 t-cdf (如果 dofs 是 array)
        # 由於 scipy.stats.t.cdf 支援 array 輸入，直接傳入即可
        cdf = stats.t.cdf(z, df=dofs)
        pdf = stats.t.pdf(z, df=dofs)
        
        # CRPS (近似解，t 分佈無簡單解析解，這裡用高斯近似但 scale 放寬)
        # 為了效能，這裡保留高斯 CRPS 公式，但在解釋上我們依賴 ICP
        # 嚴格的 t-CRPS 計算太複雜，通常不影響最終決策
        crps_approx = y_pred_std * (z * (2 * stats.norm.cdf(z) - 1) + 2 * stats.norm.pdf(z) - 1 / np.sqrt(np.pi))
        
        # ICP (95% CI 使用 t 分佈的臨界值)
        # t.ppf(0.975, df)
        t_critical = stats.t.ppf(0.975, df=dofs)
        lower = y_pred_mean - t_critical * y_pred_std
        upper = y_pred_mean + t_critical * y_pred_std
        is_covered = (y_true >= lower) & (y_true <= upper)
        
        # LogScore
        log_score = -stats.t.logpdf(y_true, df=dofs, loc=y_pred_mean, scale=y_pred_std)
        
        return {
            "CRPS": np.mean(crps_approx),
            "ICP": np.mean(is_covered),
            "LogScore": np.mean(log_score)
        }

# (DualTrackManager 不變，但需要稍微調整一下輸出格式以顯示權重)
# 這裡為了方便直接覆蓋，我把 DualTrackManager 也放進來，並加上權重顯示功能

class DualTrackManager:
    def compare_and_decide(self, freq_val, bayes_val, bayes_std, dof):
        mean_val = (freq_val + bayes_val) / 2
        if mean_val == 0: mean_val = 1e-6
        delta = abs(freq_val - bayes_val) / mean_val * 100
        
        # 使用 t 分佈計算區間
        t_critical = stats.t.ppf(0.975, df=dof)
        bayes_lower = bayes_val - t_critical * bayes_std
        bayes_upper = bayes_val + t_critical * bayes_std
        
        freq_in_interval = (freq_val >= bayes_lower) and (freq_val <= bayes_upper)

        status, final_val, msg = "", 0.0, ""

        if delta < 5:
            status, final_val = "CONSENSUS", mean_val
            msg = "模型共識 (Consensus): 預測一致，採用平均值。"
        elif delta < 15:
            status, final_val = "FRICTION", max(freq_val, bayes_val)
            msg = "輕微差異 (Friction): 採風險趨避原則 (取高值)。"
        elif delta < 30:
            status = "DIVERGENCE"
            if freq_in_interval:
                final_val = bayes_val
                msg = "顯著分歧 (Divergence): 頻率值在貝氏安全區間內，採貝氏預測。"
            else:
                final_val = freq_val
                msg = "顯著分歧 (Divergence): 頻率值異常，採頻率預測。"
        else:
            status, final_val = "CONFLICT", freq_val
            msg = "嚴重衝突 (Conflict): 模型矛盾，暫採頻率數值。"

        return status, final_val, delta, msg, t_critical

    def get_grade(self, icp):
        if 0.90 <= icp <= 0.98: return "A (優良)"
        elif icp > 0.98: return "B (保守)"
        elif 0.70 <= icp < 0.90: return "C (偏差)" # 雖然是 C，但經過 t 分佈修正後很難掉到這裡
        else: return "D (失準)"

def execute_bayesian_validation(df, target_col, freq_prediction, colors):
    """
    執行貝氏雙軌驗證流程 (接口函數)。
    對應版本: 全自動 BMA + Student-t Robust Intervals
    修正: 補上 LogScore (驚訝度) 的輸出顯示
    """
    series = df[target_col].values
    data_len = len(series)
    
    # 門檻檢查：資料不足 18 個月則不啟用
    if data_len < 18:
        print(f"\n{colors.YELLOW}【系統訊息】雙軌驗證模式未啟用{colors.RESET}")
        print(f"  └ 原因: 當前歷史資料量為 {data_len} 個月 (門檻值: 18 個月)。")
        return freq_prediction

    print(f"\n{colors.CYAN}{colors.BOLD}=== 啟動雙軌貝氏推論 (BMA 全自動權重版) ==={colors.RESET}")
    print(f"{colors.WHITE}演算法: BMA (貝氏模型平均) + Student-t Robust Intervals{colors.RESET}")

    times = np.arange(data_len)
    times_next = np.array([data_len])
    
    bayes_engine = BayesianInferenceEngine(add_bias=True)
    manager = DualTrackManager()
    
    # 1. BMA 訓練 (自動計算權重)
    bayes_engine.fit_bma(times, series)
    
    # 2. 預測
    bayes_pred, bayes_std, dof = bayes_engine.predict_bma(times_next)
    bayes_val, bayes_sigma = bayes_pred[0], bayes_std[0]
    
    # 3. 決策
    status, final_val, delta, msg, t_crit = manager.compare_and_decide(
        freq_prediction, bayes_val, bayes_sigma, dof
    )
    
    # [輸出報告] 顯示 BMA 權重分配狀態
    print(f"\n{colors.YELLOW}▧ BMA 自動權重分配 (依據模型證據 Evidence):{colors.RESET}")
    has_significant_model = False
    for model in bayes_engine.models:
        start = model['start_idx']
        window_len = data_len - start
        w_pct = model['weight'] * 100
        if w_pct > 0.1:
            print(f"  ● 歷史窗口 [{window_len} 個月]: 權重 {w_pct:.1f}%")
            has_significant_model = True
    if not has_significant_model:
        print("  (權重過於分散，無主導模型)")

    print(f"\n{colors.YELLOW}▧ 雙軌數值對照:{colors.RESET}")
    print(f"  ● 頻率學派 : {freq_prediction:,.0f}")
    print(f"  ● 貝氏學派 : {bayes_val:,.0f} (±{t_crit*bayes_sigma:,.0f})")
    print(f"    └ 自由度 (df) : {dof:.1f} (數值越小代表樣本越少，區間會自動變寬以容納風險)")
    
    print(f"\n{colors.YELLOW}▧ 差異決策 (Delta = {delta:.2f}%):{colors.RESET}")
    print(f"  ● 狀態: {status} -> {msg}")
    print(f"  ● 建議: {colors.GREEN}{colors.BOLD}{final_val:,.0f}{colors.RESET}")

    # 4. 誠實回測 (Prequential Evaluation)
    val_start = max(12, int(data_len * 0.5))
    y_true_seq, y_mean_seq, y_std_seq, y_dof_seq = bayes_engine.validate_prequential(times, series, start_idx=val_start)
    
    if len(y_true_seq) > 0:
        metrics = bayes_engine.evaluate_metrics(y_true_seq, y_mean_seq, y_std_seq, y_dof_seq)
        grade = manager.get_grade(metrics['ICP'])
        
        print(f"\n{colors.YELLOW}▧ 模型真實可靠度 (基於 Student-t 分佈評估):{colors.RESET}")
        print(f"  1. ICP (區間覆蓋率) : {metrics['ICP']*100:.1f}%  [目標 95%]")
        print(f"  2. CRPS (綜合評分)  : {metrics['CRPS']:.4f}")
        # [補上這一行] LogScore 顯示
        print(f"  3. LogScore (驚訝度) : {metrics['LogScore']:.4f}  [越低越好]")
        print(f"  4. 綜合評級         : {colors.CYAN}{grade}{colors.RESET}")

    print(f"{colors.CYAN}=============================================================={colors.RESET}\n")

    return final_val

# --- 內建台灣歷年通膨率 (CPI 年增率) 資料庫 ---
INFLATION_RATES = {
    2019: 0.56,
    2020: -0.25,
    2021: 2.10,
    2022: 2.95,
    2023: 2.49,
    2024: 2.18,
    2025: 1.88,
    2026: 1.60,
}

# --- 計算 CPI 指數的輔助函數 ---
def calculate_cpi_values(input_years, inflation_rates):
    if not input_years:
        return {}
    base_year = min(input_years)
    years = sorted(set(input_years) | set(inflation_rates.keys()))
    cpi_values = {}
    cpi_values[base_year] = 100.0
    for y in range(base_year + 1, max(years) + 1):
        prev_cpi = cpi_values.get(y - 1, 100.0)
        rate = inflation_rates.get(y, 0.0) / 100
        cpi_values[y] = prev_cpi * (1 + rate)
    for y in range(base_year - 1, min(years) - 1, -1):
        next_cpi = cpi_values.get(y + 1, 100.0)
        rate = inflation_rates.get(y + 1, 0.0) / 100
        if rate != -1:
            cpi_values[y] = next_cpi / (1 + rate)
        else:
            cpi_values[y] = next_cpi
    return cpi_values, base_year

# --- 計算實質金額的輔助函數 ---
def adjust_to_real_amount(amount, data_year, target_year, cpi_values):
    if data_year not in cpi_values or target_year not in cpi_values:
        return amount
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
    
    if s.replace('.', '', 1).isdigit():
        try:
            numeric_val = int(float(s))
            if 1 <= numeric_val <= 12:
                return f"{current_year}-{numeric_val:02d}-01"
        except ValueError:
            pass
    
    if '-' in s:
        parts = s.split('-')
        try:
            year = int(float(parts[0])) if len(parts[0]) == 4 else current_year
            month = int(float(parts[1]))
            return f"{year}-{month:02d}-01"
        except (ValueError, IndexError):
            pass
    
    if len(s) >= 5 and s[:4].isdigit():
        try:
            year = int(s[:4])
            month = int(float(s[4:]))
            return f"{year}-{month:02d}-01"
        except ValueError:
            pass
    
    if s.isdigit() and len(s) == 8:
        try:
            dt = datetime.strptime(s, '%Y%m%d')
            return dt.strftime("%Y-%m-%d")
        except ValueError:
            pass
    
    return None

# --- 單檔處理函數 ---
def process_finance_data_individual(file_path, colors):
    encodings_to_try = ['utf-8', 'utf-8-sig', 'cp950', 'big5', 'gb18030']
    df = None
    
    for enc in encodings_to_try:
        try:
            clean_path = file_path.strip()
            if not os.path.exists(clean_path):
                continue
            df = pd.read_csv(clean_path, encoding=enc, on_bad_lines='skip')
            print(f"{colors.GREEN}成功讀取檔案 '{clean_path}' (編碼: {enc}){colors.RESET}")
            break
        except (UnicodeDecodeError, FileNotFoundError):
            continue
    
    if df is None:
        return None, f"無法讀取或找到檔案 '{file_path.strip()}'", None
    
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
            income_val = pd.to_numeric(row[income_col], errors='coerce')
            if pd.notna(income_val) and income_val > 0:
                extracted_data.append({
                    'Date': date_val,
                    'Amount': income_val,
                    'Type': 'income'
                })
            expense_val = pd.to_numeric(row[expense_col], errors='coerce')
            if pd.notna(expense_val) and expense_val > 0:
                extracted_data.append({
                    'Date': date_val,
                    'Amount': expense_val,
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
        return None, f"檔案 '{file_path}' 格式無法辨識", "unknown"
    
    return extracted_data, None, file_format_type

# --- 多檔處理函數 ---
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

# --- 季節性分解函數 ---
def seasonal_decomposition(monthly_expenses):
    monthly_expenses['Month'] = monthly_expenses['Parsed_Date'].dt.month
    monthly_avg = monthly_expenses.groupby('Month')['Real_Amount'].mean()
    overall_avg = monthly_expenses['Real_Amount'].mean()
    seasonal_indices = monthly_avg / overall_avg
    
    deseasonalized = monthly_expenses.copy()
    deseasonalized['Deseasonalized'] = deseasonalized['Real_Amount'] / deseasonalized['Month'].map(seasonal_indices)
    
    return deseasonalized, seasonal_indices

# --- 優化蒙地卡羅模擬 ---
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

# --- 蒙地卡羅儀表板函式 ---
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

# --- 穩健的移動標準差計算函數 (基於MAD) ---
def robust_moving_std(series, window):
    mad_series = series.rolling(window).apply(median_abs_deviation, raw=True)
    robust_std = mad_series / 0.6745
    return robust_std

# --- 動態閾值與衝擊偵測引擎 ---
def manual_seasonal_decompose(series, period=12, model='additive'):
    if len(series) < period * 2:
        return pd.DataFrame({'trend': series, 'seasonal': 0, 'resid': 0})
    trend = series.rolling(window=period, center=True).mean()
    trend = trend.rolling(window=2, center=True).mean().shift(-1) if period % 2 == 0 else trend.rolling(window=period, center=True).mean()
    trend = trend.fillna(method='bfill').fillna(method='ffill')
    detrended = series - trend if model == 'additive' else series / trend
    seasonal_avg = detrended.groupby(detrended.index.month).mean()
    
    if model == 'additive':
        seasonal_adjustment = seasonal_avg.mean()
        seasonal_avg -= seasonal_adjustment
        seasonal = pd.Series(seasonal_avg[series.index.month].values, index=series.index)
        resid = series - trend - seasonal
    else:
        seasonal_adjustment = seasonal_avg.mean()
        seasonal_avg /= seasonal_adjustment
        seasonal = pd.Series(seasonal_avg[series.index.month].values, index=series.index)
        resid = series / (trend * seasonal)
        
    return pd.DataFrame({'trend': trend, 'seasonal': seasonal, 'resid': resid})

def calculate_dynamic_anomaly_multiplier(residual_series):
    if len(residual_series) < 12:
        return 1.5
    skewness = stats.skew(residual_series)
    kurt = stats.kurtosis(residual_series, fisher=True)
    base_c = 1.75
    min_c = 1.25
    skew_factor = 1 / (1 + 0.5 * abs(skewness))
    kurt_factor = 1 / (1 + 0.2 * max(0, kurt))
    dynamic_c = base_c * skew_factor * kurt_factor
    return max(min_c, dynamic_c)

def calculate_anomaly_scores(monthly_expenses_df, window_size=6, k_ma=2.5, k_sigmoid=0.5):
    data = monthly_expenses_df['Real_Amount'].values
    series_pd = pd.Series(data, index=pd.to_datetime(monthly_expenses_df['Parsed_Date']))
    n_total = len(data)

    decomposed = manual_seasonal_decompose(series_pd)
    residuals_for_dist = decomposed['resid'].dropna()
    dynamic_multiplier = calculate_dynamic_anomaly_multiplier(residuals_for_dist)
    
    q1, q3 = np.percentile(data, [25, 75])
    iqr = q3 - q1
    upper_bound_iqr = q3 + (dynamic_multiplier * iqr)
    siqr_denominator = upper_bound_iqr if upper_bound_iqr > 0 else 1
    siqr = np.maximum(0, (data - upper_bound_iqr) / siqr_denominator)

    if n_total < window_size:
        sma = np.zeros(n_total)
    else:
        ma = series_pd.rolling(window=window_size).mean()
        robust_std = robust_moving_std(series_pd, window=window_size)
        channel_top = ma + (k_ma * robust_std)
        sma_denominator = channel_top.where(channel_top > 0, 1)
        sma = np.maximum(0, (series_pd - channel_top) / sma_denominator).fillna(0).values

    w_local = np.zeros(n_total)
    if n_total > window_size:
        n_series = np.arange(1, n_total + 1)
        w_local = 1 / (1 + np.exp(-k_sigmoid * (n_series - window_size)))
        w_local[:window_size] = 0.0
    
    numerator = siqr + (sma * w_local)
    denominator = 1.0 + w_local
    final_score = np.nan_to_num((numerator / denominator), nan=0.0)
    
    is_shock = siqr > 0.01

    return pd.DataFrame({
        'Amount': data, 'SIQR': siqr, 'SMA': sma, 'W_Local': w_local,
        'Final_Score': final_score, 'Is_Shock': is_shock
    })


# --- 結構性轉變偵測函數 ---
def detect_structural_change_point(monthly_expenses_df, history_window=12, recent_window=6, c_factor=1.0):
    data = monthly_expenses_df['Real_Amount'].values
    n = len(data)
    
    if n < history_window + recent_window:
        return 0
        
    last_change_point = 0
    for i in range(n - recent_window, history_window -1, -1):
        history_data = data[:i]
        recent_data = data[i : i + recent_window]
        
        median_history = np.median(history_data)
        q1_history, q3_history = np.percentile(history_data, [25, 75])
        iqr_history = q3_history - q1_history
        
        if iqr_history == 0 and median_history > 0:
            iqr_history = median_history * 0.05 
        elif iqr_history == 0 and median_history == 0:
            iqr_history = 1 
        
        median_recent = np.median(recent_data)
        
        threshold = median_history + (c_factor * iqr_history)
        if median_recent > threshold:
            last_change_point = i
            break 
            
    return last_change_point


# --- 三層式預算建議核心函數 ---
def assess_risk_and_budget_advanced(monthly_expenses, model_error_coefficient, historical_rmse):
    data = monthly_expenses['Real_Amount'].values
    n_total = len(data)
    
    anomaly_df = calculate_anomaly_scores(monthly_expenses) 
    
    change_point = detect_structural_change_point(monthly_expenses)
    change_date_str = None
    if change_point > 0:
        change_date = monthly_expenses['Parsed_Date'].iloc[change_point]
        change_date_str = change_date.strftime('%Y年-%m月')
    
    num_shocks = int(anomaly_df['Is_Shock'].sum())

    new_normal_df = anomaly_df.iloc[change_point:].copy()
    clean_new_normal_data = new_normal_df[~new_normal_df['Is_Shock']]['Amount'].values
    
    if len(clean_new_normal_data) < 2:
        clean_new_normal_data = new_normal_df['Amount'].values
    if len(clean_new_normal_data) < 2:
        clean_new_normal_data = data

    _, base_budget_p75, _ = monte_carlo_dashboard(clean_new_normal_data)
    if base_budget_p75 is None:
        base_budget_p75 = np.mean(clean_new_normal_data) * 1.1

    shock_rows = anomaly_df[anomaly_df['Is_Shock']]
    shock_amounts = shock_rows['Amount'].values
    amortized_shock_fund = 0.0
    
    if len(shock_amounts) > 0:
        avg_shock = np.mean(shock_amounts)
        prob_shock = len(shock_amounts) / n_total
        amortized_shock_fund = avg_shock * prob_shock
    
    model_error_buffer = model_error_coefficient * (historical_rmse if historical_rmse is not None else 0)
    
    peak_analysis_results = None
    if n_total >= 12: 
        try:
            peaks, _ = signal.find_peaks(data, height=np.percentile(data, 75))
            if len(peaks) > 1:
                intervals = np.diff(peaks)
                avg_interval = np.mean(intervals)
                
                periodicity = "無明顯規律"
                if 2.5 < avg_interval < 3.5: periodicity = "季度性 (每3個月)"
                elif 5.5 < avg_interval < 6.5: periodicity = "半年期 (每6個月)"
                elif 11.0 < avg_interval < 13.0: periodicity = "年度性 (每12個月)"
                
                peak_analysis_results = {
                    "num_peaks": len(peaks),
                    "avg_peak_interval": f"{avg_interval:.1f} 個月",
                    "periodicity_label": periodicity
                }
        except Exception:
            peak_analysis_results = None 

    suggested_budget = base_budget_p75 + amortized_shock_fund + model_error_buffer
    
    status = "進階預算模式 (三層式)"
    description = f"偵測到數據模式複雜，已啟用三層式預算模型以提高準確性。"
    data_reliability = "高度可靠 (進階模型)"

    components = {
        'is_advanced': True,
        'base': base_budget_p75,
        'amortized': amortized_shock_fund,
        'error': model_error_buffer,
        'change_date': change_date_str,
        'num_shocks': num_shocks,
        'peak_analysis': peak_analysis_results 
    }
    
    return (status, description, suggested_budget, data_reliability, components)


# --- 風險狀態判讀與預算建議函數 ---
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
    if monthly_expenses is None or len(monthly_expenses) < 2:
        return ("無法判讀 (資料不足)", "資料過少，無法進行風險評估。", None, None, None, None, None, "極低可靠性", None, None, None, None, None, None, None)

    num_months = len(monthly_expenses)
    
    if num_months > 12:
        error_coefficient = 0.5
        if calibration_results and acf_results and quantile_spread is not None:
            error_coefficient = calculate_dynamic_error_coefficient(calibration_results, acf_results, quantile_spread)

        status, description, suggested_budget, data_reliability, components = \
            assess_risk_and_budget_advanced(monthly_expenses, error_coefficient, historical_rmse)
        
        error_buffer = components.get('error')

        return (status, description, suggested_budget,
                None, None, None, None, 
                data_reliability, error_coefficient, error_buffer, 
                components, 
                None, None, None, None) 

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

# --- 診斷儀表板函數 ---
def pad_cjk(text, total_width, align='left'):
    try:
        text_width = len(text.encode('gbk'))
    except UnicodeEncodeError:
        text_width = sum(2 if '\u4e00' <= char <= '\u9fff' else 1 for char in text)
    
    padding = total_width - text_width
    if padding < 0: padding = 0
    
    if align == 'left':
        return text + ' ' * padding
    elif align == 'right':
        return ' ' * padding + text
    else: 
        left_pad = padding // 2
        right_pad = padding - left_pad
        return ' ' * left_pad + text + ' ' * right_pad

def quantile_loss(y_true, y_pred, quantile):
    errors = y_true - y_pred
    return np.mean(np.maximum(quantile * errors, (quantile - 1) * errors))

def quantile_loss_report(y_true, quantile_preds, quantiles, colors):
    cfg = TABLE_CONFIG['quantile_loss']
    report = [f"{colors.WHITE}>>> 分位數損失分析 (風險情境誤差評估){colors.RESET}"]
    
    header_line = f"|{'-'*cfg['q']}|{'-'*cfg['loss']}|{'-'*cfg['interp']}|"
    report.append(header_line)
    
    header = f"| {pad_cjk('分位數', cfg['q']-2)} | {pad_cjk('損失值', cfg['loss']-2, 'right')} | {pad_cjk('解釋', cfg['interp']-2)} |"
    report.append(header)
    report.append(header_line)

    for q in quantiles:
        preds = quantile_preds.get(q)
        if preds is None: continue
        
        min_len = min(len(y_true), len(preds))
        loss = quantile_loss(y_true[:min_len], preds[:min_len], q)
        interp = "核心趨勢誤差" if q == 0.5 else ("常規波動誤差" if q in [0.25, 0.75] else "尾部風險誤差")
        label = f"{q*100:.0f}%"
        
        row = f"| {pad_cjk(label, cfg['q']-2)} | {f'{loss:,.2f}'.rjust(cfg['loss']-2)} | {pad_cjk(interp, cfg['interp']-2)} |"
        report.append(row)
        
    report.append(header_line)
    return "\n".join(report)

def model_calibration_analysis(calibration_data, quantiles, colors):
    results, method = calibration_data 
    
    if not results or method == "insufficient_data":
        return ""

    cfg = TABLE_CONFIG['calibration']
    
    if method == "strict_rolling":
        title = "模型校準分析 (嚴格滾動驗證)"
        desc = "(說明：使用『過去經驗』驗證『未來預測』，Out-of-Sample 嚴格測試)"
    elif method == "jackknife_loo":
        title = "模型校準分析 (留一交叉驗證)"
        desc = "(說明：資料量 < 24 個月，採用『排除自身』方式進行公平驗證)"
    else:
        return ""

    report = [f"{colors.WHITE}>>> {title}{colors.RESET}", desc]

    header_line = f"|{'-'*cfg['label']}|{'-'*cfg['freq']}|{'-'*cfg['assess']}|"
    report.append(header_line)
    header = f"| {pad_cjk('預期信心', cfg['label']-2)} | {pad_cjk('實際覆蓋', cfg['freq']-2, 'right')} | {pad_cjk('評估結果', cfg['assess']-2)} |"
    report.append(header)
    report.append(header_line)
    
    for q in quantiles:
        res = results.get(q)
        if res is None: continue
        
        observed_freq = res['observed_freq'] * 100
        target_freq = q * 100
        diff = observed_freq - target_freq
        
        if abs(diff) < 5: assessment = f"{colors.GREEN}完美校準{colors.RESET}"
        elif abs(diff) < 10: assessment = "良好"
        elif diff < -20: assessment = f"{colors.RED}嚴重高估{colors.RESET}"
        elif diff < 0: assessment = f"{colors.YELLOW}高估信心{colors.RESET}"
        elif diff > 20: assessment = f"{colors.RED}極度保守{colors.RESET}"
        else: assessment = "略為保守"
            
        label = f"{target_freq:.0f}%"
        freq_str = f"{observed_freq:.1f}%"
        
        row = f"| {pad_cjk(label, cfg['label']-2)} | {freq_str.rjust(cfg['freq']-2)} | {pad_cjk(assessment, cfg['assess']-2)} |"
        report.append(row)
        
    report.append(header_line)
    return "\n".join(report)

def residual_autocorrelation_diagnosis(residuals, n, colors):
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

def residual_normality_report(residuals, colors):
    if len(residuals) < 3:
        return "" 
    try:
        stat, p_value = stats.shapiro(residuals)
        report = [f"{colors.WHITE}>>> 殘差診斷 (常態性檢定){colors.RESET}"]
        
        if p_value > 0.05:
            assessment = f"{colors.GREEN}通過{colors.RESET}"
            interpretation = "模型殘差的分佈與常態分佈沒有顯著差異，符合標準統計假設。"
        else:
            assessment = f"{colors.YELLOW}未通過{colors.RESET}"
            interpretation = "模型殘差顯著偏離常態分佈，可能表示模型未能捕捉某些非線性特徵，或數據中存在極端值。"
            
        report.append(f"  - Shapiro-Wilk 檢定結果: {assessment} (p-value: {p_value:.3f})")
        report.append(f"  - {colors.WHITE}解釋: {interpretation}{colors.RESET}")
        return "\n".join(report)
    except Exception:
        return "" 

# --- MPI 3.0 評估套件 ---
def calculate_erai(y_true, y_pred_model, quantile_preds_model, wape_robust_model):
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

def calculate_fss(prequential_results, mean_expense):
    if prequential_results is None:
        return {'fss_score': 0, 'bias_penalty': 1, 'consistency_score': 0, 'expected_accuracy': 0}
        
    errors = prequential_results["errors"]
    true_values = prequential_results["true_values"]
    
    cfe = np.sum(errors)
    sum_abs_true = np.sum(np.abs(true_values))
    bias_penalty = min(1, abs(cfe / sum_abs_true) * 5) if sum_abs_true > 0 else 1

    rmse_e = np.std(errors, ddof=1) if len(errors) > 1 else 0
    consistency_score = max(0, 1 - (rmse_e / mean_expense)) if mean_expense > 0 else 0
    
    p_wape = 100 * np.sum(np.abs(errors)) / sum_abs_true if sum_abs_true > 0 else 100
    expected_accuracy = max(0, 1 - (p_wape / 100.0))
    
    fss_score = (0.4 * (1 - bias_penalty)) + (0.3 * consistency_score) + (0.3 * expected_accuracy)

    return {
        'fss_score': fss_score, 
        'bias_penalty': bias_penalty, 
        'consistency_score': consistency_score, 
        'expected_accuracy': expected_accuracy
    }
    
def calculate_mpi_3_0_and_rate(y_true, historical_pred, global_wape, erai_score, mpi_percentile_rank, fss_score):
    wape_score = 1 - (global_wape / 100.0) if global_wape is not None else 0
    ss_res = np.sum((y_true - historical_pred)**2)
    ss_tot = np.sum((y_true - np.mean(y_true))**2)
    r_squared = 1 - (ss_res / ss_tot) if ss_tot > 1e-9 else 0
    r2_score = max(0, r_squared)
    aas = 0.7 * wape_score + 0.3 * r2_score
    
    rss = erai_score if erai_score is not None else 0
    mpi_3_0_score = (0.25 * aas) + (0.25 * rss) + (0.50 * fss_score)
    
    rating = "F" 
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
    ensemble_residuals = y_true - historical_ensemble_pred
    clean_residuals = ensemble_residuals[~is_shock_flags]
    clean_y_true = y_true[~is_shock_flags]
    
    ensemble_wape_robust = (np.sum(np.abs(clean_residuals)) / np.sum(np.abs(clean_y_true))) * 100 if np.sum(np.abs(clean_y_true)) > 1e-9 else 100.0
    ensemble_quantile_preds = {q: historical_ensemble_pred + np.percentile(ensemble_residuals, q*100) for q in [0.1, 0.25, 0.75, 0.9]}
    ensemble_erai_score = calculate_erai(y_true, historical_ensemble_pred, ensemble_quantile_preds, ensemble_wape_robust)
    
    return {'erai_score': ensemble_erai_score}

# --- 進度條輔助函數 ---
def print_progress_bar(iteration, total, prefix='', suffix='', decimals=1, length=50, fill='█', print_end="\r"):
    percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
    filled_length = int(length * iteration // total)
    bar = fill * filled_length + '-' * (length - filled_length)
    sys.stdout.write(f'\r{prefix} |{bar}| {percent}% {suffix}')
    sys.stdout.flush()
    if iteration == total: 
        sys.stdout.write('\n')
        sys.stdout.flush()

# --- 動態策略集成 - 前向測試 ---
def run_dynamic_strategy_ensemble_prequential(
    full_df, 
    historical_preds_A,
    historical_preds_B,
    colors, 
    min_train_size=18, 
    drift_window_size=12, 
    dynamic_lookback_window=12
):
    total_len = len(full_df)
    y_true_full = full_df['Real_Amount'].values
    
    fused_errors, fused_predictions, true_values = [], [], []
    drift_points = []
    
    color_cyan = colors.CYAN if colors else ''
    color_reset = colors.RESET if colors else ''
    
    training_start_index = 0
    fused_error_window = deque(maxlen=drift_window_size)
    
    num_tests = total_len - min_train_size
    print(f"\n{color_cyan}正在執行「動態策略集成」前向測試 (Prequential)，共 {num_tests} 次滾動預測...{color_reset}")
    print_progress_bar(0, num_tests, prefix='進度:', suffix='完成', length=40)
    
    for t_step in range(min_train_size, total_len):
        train_indices = np.arange(training_start_index, t_step)
        y_train = y_true_full[train_indices]
        
        pred_A = historical_preds_A[t_step]
        pred_B = historical_preds_B[t_step]
        true_value = y_true_full[t_step]
        
        errors_A_hist = y_true_full[train_indices] - historical_preds_A[train_indices]
        errors_B_hist = y_true_full[train_indices] - historical_preds_B[train_indices]
        
        weight_A, weight_B = 0.5, 0.5
        if len(errors_A_hist) > 0:
            recent_errors_A = errors_A_hist[-dynamic_lookback_window:]
            recent_errors_B = errors_B_hist[-dynamic_lookback_window:]
            
            rmse_A = np.sqrt(np.mean(recent_errors_A**2))
            rmse_B = np.sqrt(np.mean(recent_errors_B**2))
            
            inv_A = 1.0 / (rmse_A + 1e-9)
            inv_B = 1.0 / (rmse_B + 1e-9)
            total_inv = inv_A + inv_B
            
            if total_inv > 1e-9:
                weight_A = inv_A / total_inv
                weight_B = inv_B / total_inv
        
        fused_pred = (pred_A * weight_A) + (pred_B * weight_B)
        fused_error = true_value - fused_pred
        
        fused_predictions.append(fused_pred)
        true_values.append(true_value)
        fused_errors.append(fused_error)
        fused_error_window.append(fused_error)

        if len(fused_error_window) == drift_window_size:
            half_window = drift_window_size // 2
            reference_errors = np.array(list(fused_error_window)[:half_window])
            detection_errors = np.array(list(fused_error_window)[half_window:])
            if len(reference_errors) >= 3 and len(detection_errors) >= 3:
                drift_detected = False
                median_ref = np.median(reference_errors)
                median_det = np.median(detection_errors)
                q1_ref, q3_ref = np.percentile(reference_errors, [25, 75])
                iqr_ref = q3_ref - q1_ref
                if iqr_ref > 1e-6 and abs(median_det - median_ref) > 1.5 * iqr_ref:
                    drift_detected = True
                if not drift_detected:
                    try:
                        _, p_ttest = stats.ttest_ind(reference_errors, detection_errors, equal_var=False)
                        _, p_mannwhitney = stats.mannwhitneyu(reference_errors, detection_errors, alternative='two-sided')
                        if p_ttest < 0.05 or p_mannwhitney < 0.05:
                            drift_detected = True
                    except ValueError: pass
                if drift_detected:
                    drift_points.append(t_step)
                    training_start_index = max(0, t_step - min_train_size)
                    fused_error_window.clear()

        print_progress_bar(t_step - min_train_size + 1, num_tests, prefix='進度:', suffix='完成', length=40)

    print("動態策略集成 - 前向測試完成。")
    if not fused_errors:
        return None, (0.5, 0.5)
    
    final_errors_A = y_true_full - historical_preds_A
    final_errors_B = y_true_full - historical_preds_B
    rmse_A = np.sqrt(np.mean(final_errors_A[-dynamic_lookback_window:]**2))
    rmse_B = np.sqrt(np.mean(final_errors_B[-dynamic_lookback_window:]**2))
    inv_A = 1.0 / (rmse_A + 1e-9)
    inv_B = 1.0 / (rmse_B + 1e-9)
    total_inv = inv_A + inv_B
    final_weight_A = inv_A / total_inv if total_inv > 1e-9 else 0.5
    final_weight_B = 1.0 - final_weight_A
    final_weights = (final_weight_A, final_weight_B)
    
    prequential_results = {
        "errors": np.array(fused_errors),
        "predictions": np.array(fused_predictions),
        "true_values": np.array(true_values),
        "drift_points": drift_points
    }
    
    return prequential_results, final_weights


# --- 前向測試報告函數 ---
def format_prequential_metrics_report(results, mean_expense, colors):
    if results is None:
        return ""

    errors = results["errors"]
    true_values = results["true_values"]
    
    cfe = np.sum(errors)
    sum_abs_true = np.sum(np.abs(true_values))
    
    bias_direction_text = ""
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

    rmse_e = np.std(errors, ddof=1) if len(errors) > 1 else 0
    rmse_e_ratio = (rmse_e / mean_expense) * 100 if mean_expense > 0 else 0
    
    rmse_e_assessment = "高度穩定" if rmse_e_ratio < 15 else "中度穩定" if rmse_e_ratio < 35 else "表現不穩"

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
    if results is None:
        return ""
    
    num_simulations = len(results["errors"])
    drift_points = results["drift_points"]
    num_drifts = len(drift_points)

    drift_detection_line = f"  - {colors.BOLD}概念飄移偵測:{colors.RESET} 在過去 {num_simulations} 個月的模擬中，共偵測到 {num_drifts} 次顯著的模式轉變 (基於雙軌式混合偵測)。"
    
    if num_drifts == 0:
        last_drift_line = f"  - {colors.BOLD}最後飄移時間:{colors.RESET} 未偵測到顯著模式轉變，顯示近期模式具備高度連續性。"
        adaptation_strategy_line = ""
    else:
        last_drift_index = drift_points[-1]
        last_drift_date_str = full_df.iloc[last_drift_index]['Parsed_Date'].strftime('%Y-%m')
        
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

def format_detailed_risk_analysis_report(dynamic_risk_coefficient, error_coefficient, overall_score, 
                                       trend_score, trend_scores_detail, 
                                       vol_score, vol_scores_detail, 
                                       shock_score, shock_scores_detail, colors):
    report = []
    
    if dynamic_risk_coefficient is not None:
        report.append(f"{colors.WHITE}動態風險係數: {dynamic_risk_coefficient:.3f}{colors.RESET}")
    if error_coefficient is not None:
        report.append(f"{colors.WHITE}模型誤差係數: {error_coefficient:.3f}{colors.RESET}")
    
    report.append(f"\n{colors.WHITE}>>> 詳細風險因子分析{colors.RESET}")
    report.append(f"{colors.BOLD}總體風險評分: {overall_score:.2f}/10{colors.RESET}")
    report.append(f"  └ 權重配置: 趨勢(40%) + 波動(35%) + 衝擊(25%)")

    report.append(f"\n{colors.WHITE}趨勢風險因子:{colors.RESET}")
    report.append(f"  - 趨勢加速度: {trend_scores_detail['accel']:.1f}/10")
    report.append(f"  - 滾動平均交叉: {trend_scores_detail['crossover']:.1f}/10")
    report.append(f"  - 殘差自相關性: {trend_scores_detail['autocorr']:.1f}/10")
    report.append(f"  - {colors.BOLD}趨勢風險得分: {trend_score:.2f}/10{colors.RESET}")

    report.append(f"\n{colors.WHITE}波動風險因子:{colors.RESET}")
    report.append(f"  - 波動的波動性: {vol_scores_detail['vol_of_vol']:.1f}/10")
    report.append(f"  - 下行波動率: {vol_scores_detail['downside_vol']:.1f}/10")
    report.append(f"  - 峰態: {vol_scores_detail['kurtosis']:.1f}/10")
    report.append(f"  - {colors.BOLD}波動風險得分: {vol_score:.2f}/10{colors.RESET}")

    report.append(f"\n{colors.WHITE}衝擊風險因子:{colors.RESET}")
    report.append(f"  - 最大衝擊幅度: {shock_scores_detail['max_shock_magnitude']:.1f}/10")
    report.append(f"  - 連續正向衝擊: {shock_scores_detail['consecutive_shocks']:.1f}/10")
    report.append(f"  - {colors.BOLD}衝擊風險得分: {shock_score:.2f}/10{colors.RESET}")
    
    return "\n".join(report)

# --- 動態策略集成 - 蒙地卡羅交叉驗證 ---
def run_dynamic_strategy_ensemble_cv(
    full_df, 
    historical_preds_A,
    historical_preds_B,
    n_iterations=100, 
    colors=None, 
    min_train_size=18, 
    dynamic_lookback_window=12
):
    mpi_scores = []
    total_len = len(full_df)
    y_true_full = full_df['Real_Amount'].values
    val_ratio = 0.25
    min_val_size = max(1, int(total_len * val_ratio))

    if total_len < min_train_size + min_val_size: 
        return None, None

    color_cyan = colors.CYAN if colors else ''
    color_reset = colors.RESET if colors else ''
    
    print(f"\n{color_cyan}正在執行「動態策略集成」蒙地卡羅交叉驗證 (MPI 評級基準)，共 {n_iterations} 次迭代...{color_reset}")
    print_progress_bar(0, n_iterations, prefix='進度:', suffix='完成', length=40)

    for i in range(n_iterations):
        train_len = np.random.randint(min_train_size, total_len - min_val_size)
        start_index = np.random.randint(0, total_len - train_len - min_val_size + 1)
        end_train_index = start_index + train_len
        end_val_index = total_len
        
        train_indices = np.arange(start_index, end_train_index)
        val_indices = np.arange(end_train_index, end_val_index)

        if len(train_indices) < min_train_size or len(val_indices) == 0: continue
        
        y_train_true = y_true_full[train_indices]
        y_val_true = y_true_full[val_indices]

        errors_A_train = y_train_true - historical_preds_A[train_indices]
        errors_B_train = y_train_true - historical_preds_B[train_indices]
        
        rmse_A = np.sqrt(np.mean(errors_A_train[-dynamic_lookback_window:]**2))
        rmse_B = np.sqrt(np.mean(errors_B_train[-dynamic_lookback_window:]**2))
        
        inv_A = 1.0 / (rmse_A + 1e-9)
        inv_B = 1.0 / (rmse_B + 1e-9)
        total_inv = inv_A + inv_B
        weight_A = inv_A / total_inv if total_inv > 1e-9 else 0.5
        weight_B = 1.0 - weight_A

        fused_val_pred = (historical_preds_A[val_indices] * weight_A) + (historical_preds_B[val_indices] * weight_B)
        
        fused_val_residuals = y_val_true - fused_val_pred
        sum_abs_val_true = np.sum(np.abs(y_val_true))
        val_wape = (np.sum(np.abs(fused_val_residuals)) / sum_abs_val_true * 100) if sum_abs_val_true > 1e-9 else 100.0
        val_quantile_preds = {q: fused_val_pred + np.percentile(fused_val_residuals, q*100) for q in [0.10, 0.25, 0.75, 0.90]}

        rss_val = calculate_erai(y_val_true, fused_val_pred, val_quantile_preds, val_wape)
        if rss_val is None: rss_val = 0

        val_wape_score = 1 - (val_wape / 100.0)
        ss_res_val = np.sum(fused_val_residuals**2)
        ss_tot_val = np.sum((y_val_true - np.mean(y_val_true))**2)
        r2_val = 1 - (ss_res_val / ss_tot_val) if ss_tot_val > 1e-9 else 0
        r2_score_val = max(0, r2_val)
        aas_val = 0.7 * val_wape_score + 0.3 * r2_score_val
        
        fss_val_approx = 0.5 
        mpi_score_val = (0.25 * aas_val) + (0.25 * rss_val) + (0.50 * fss_val_approx)
        
        if np.isfinite(mpi_score_val): mpi_scores.append(mpi_score_val)
        
        print_progress_bar(i + 1, n_iterations, prefix='進度:', suffix='完成', length=40)
    
    print("動態策略集成 - MPI 基準計算完成。")
    if not mpi_scores: 
        return None, None
        
    p25, p50, p85 = np.percentile(mpi_scores, [25, 50, 85])
    return {'p25': p25, 'p50': p50, 'p85': p85}, mpi_scores

# --- 智慧型雙模式校準計算函數 ---
def compute_smart_calibration_results(residuals, prequential_results, quantiles, window_size=12):
    """
    智慧型校準計算：
    1. 資料 ≥ 24 個月且有前向測試：使用「滾動式驗證 (Rolling)」(業界黃金標準)。
    2. 6 ≤ 資料 < 24 個月：退回「留一法 (Jackknife)」(小數據專用，比舊方法誠實)。
    3. 資料 < 6 個月：不做校準，避免誤導。
    """
    method_used = "insufficient_data"
    results = {}

    # --- 模式 A：滾動式驗證 (Rolling) ---
    if prequential_results is not None:
        errors = prequential_results.get("errors")
        if errors is not None and len(errors) > window_size:
            hits = {q: 0 for q in quantiles}
            total_evals = 0
            
            for t in range(window_size, len(errors)):
                past_errors = np.abs(errors[t-window_size : t]) # 只看過去
                current_error = np.abs(errors[t])               # 驗證現在
                
                for q in quantiles:
                    threshold = np.percentile(past_errors, q * 100)
                    if current_error <= threshold:
                        hits[q] += 1
                total_evals += 1
            
            if total_evals > 0:
                for q in quantiles:
                    results[q] = {'quantile': q, 'observed_freq': hits[q] / total_evals}
                return results, "strict_rolling"

    # --- 模式 B：留一法 (Jackknife) ---
    if residuals is not None and len(residuals) >= 6:
        hits = {q: 0 for q in quantiles}
        n = len(residuals)
        abs_residuals = np.abs(residuals)
        
        for i in range(n):
            current_res = abs_residuals[i]
            others = np.concatenate([abs_residuals[:i], abs_residuals[i+1:]])
            
            for q in quantiles:
                threshold = np.percentile(others, q * 100)
                if current_res <= threshold:
                    hits[q] += 1
        
        for q in quantiles:
            results[q] = {'quantile': q, 'observed_freq': hits[q] / n}
        return results, "jackknife_loo"

    return {}, "insufficient_data"

def compute_acf_results(residuals, n):
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
    if predicted_value is None or predicted_value == 0:
        return 0.0
    spread = (p75 - p25) / predicted_value if p75 is not None and p25 is not None else 0.0
    return spread

# --- IRLS 穩健迴歸引擎 ---
def huber_robust_regression(x, y, steps_ahead, t_const=1.345, max_iter=100, tol=1e-6):
    X = np.c_[np.ones(len(x)), x]
    slope, intercept, _, _, _ = linregress(x, y)
    beta = np.array([intercept, slope])

    for _ in range(max_iter):
        beta_old = beta.copy()
        y_pred = X @ beta
        residuals = y - y_pred
        scale = median_abs_deviation(residuals, scale='normal')
        if scale < 1e-6: scale = 1e-6
        z = residuals / scale
        weights = np.ones_like(z)
        outliers = np.abs(z) > t_const
        weights[outliers] = t_const / np.abs(z[outliers])
        W_sqrt = np.sqrt(weights)
        X_w = X * W_sqrt[:, np.newaxis]
        y_w = y * W_sqrt
        beta = np.linalg.lstsq(X_w, y_w, rcond=None)[0]
        if np.sum(np.abs(beta - beta_old)) < tol:
            break

    historical_pred = X @ beta
    final_residuals = y - historical_pred
    future_x = np.arange(len(x) + 1, len(x) + steps_ahead + 1)
    predicted_values = beta[0] + beta[1] * future_x
    
    dof = len(x) - 2
    if dof <= 0: return predicted_values, historical_pred, final_residuals, None, None
    
    mse_robust = np.sum(final_residuals**2) / dof
    se = np.sqrt(mse_robust * (1 + 1/len(x) + (future_x - np.mean(x))**2 / np.sum((x - np.mean(x))**2))) if len(future_x) > 0 else np.sqrt(mse_robust)
    t_val = t.ppf(0.975, dof)
    lower_seq = predicted_values - t_val * se
    upper_seq = predicted_values + t_val * se

    return predicted_values, historical_pred, final_residuals, lower_seq, upper_seq

# --- 模型堆疊集成 ---
def train_predict_huber(x_train, y_train, x_predict, t_const=1.345, max_iter=100, tol=1e-6):
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
    if len(x_train) < degree + 1: return np.full(len(x_predict), np.mean(y_train) if len(y_train) > 0 else 0)
    coeffs = np.polyfit(x_train, y_train, degree)
    p = np.poly1d(coeffs)
    return p(x_predict)

def train_predict_des(y_train, predict_steps, alpha=None, beta=None):
    if len(y_train) < 2:
        return np.full(predict_steps, y_train[0] if len(y_train) > 0 else 0)

    if alpha is None or beta is None:
        def holt_rmse(params):
            alpha_opt, beta_opt = params
            if not (0 <= alpha_opt <= 1 and 0 <= beta_opt <= 1):
                return np.inf
            level, trend = y_train[0], y_train[1] - y_train[0]
            predictions = np.zeros(len(y_train))
            predictions[0], predictions[1] = level, level + trend
            for i in range(1, len(y_train)):
                level_old, trend_old = level, trend
                level = alpha_opt * y_train[i] + (1 - alpha_opt) * (level_old + trend_old)
                trend = beta_opt * (level - level_old) + (1 - beta_opt) * trend_old
                if i + 1 < len(y_train):
                    predictions[i+1] = level + trend
            return np.sqrt(np.mean((y_train - predictions)**2))

        opt_res = minimize(holt_rmse, x0=[0.5, 0.5], method='L-BFGS-B', bounds=[(0, 1), (0, 1)])
        alpha, beta = opt_res.x

    level, trend = y_train[0], y_train[1] - y_train[0]
    for i in range(1, len(y_train)):
        level_old, trend_old = level, trend
        level = alpha * y_train[i] + (1 - alpha) * (level_old + trend_old)
        trend = beta * (level - level_old) + (1 - beta) * trend_old
    return level + trend * np.arange(1, predict_steps + 1)

def train_predict_seasonal(df_train, predict_steps, seasonal_period=12):
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
    if len(y_train) == 0: return np.zeros(predict_steps)
    last_value = y_train[-1]
    return np.full(predict_steps, last_value)

def train_predict_rolling_median(y_train, predict_steps, window_size=6):
    if len(y_train) == 0: return np.zeros(predict_steps)
    actual_window = min(len(y_train), window_size)
    if actual_window == 0: return np.zeros(predict_steps)
    median_value = np.median(y_train[-actual_window:])
    return np.full(predict_steps, median_value)

def train_predict_global_median(y_train, predict_steps):
    if len(y_train) == 0: return np.zeros(predict_steps)
    median_value = np.median(y_train)
    return np.full(predict_steps, median_value)

def train_predict_drift(y_train, predict_steps):
    if len(y_train) < 2: return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)
    first_value = y_train[0]
    last_value = y_train[-1]
    drift = (last_value - first_value) / (len(y_train) - 1)
    predictions = [last_value + (i * drift) for i in range(1, predict_steps + 1)]
    return np.array(predictions)

def train_predict_seasonal_naive(y_train, predict_steps, seasonal_period=12):
    if len(y_train) < seasonal_period: return np.full(predict_steps, y_train[-1] if len(y_train) > 0 else 0)
    predictions = []
    for i in range(1, predict_steps + 1):
        idx = len(y_train) - seasonal_period + ((i - 1) % seasonal_period)
        predictions.append(y_train[idx])
    return np.array(predictions)

def train_predict_moving_average(y_train, predict_steps, window_size=6):
    if len(y_train) == 0: return np.zeros(predict_steps)
    actual_window = min(len(y_train), window_size)
    if actual_window == 0: return np.zeros(predict_steps)
    mean_value = np.mean(y_train[-actual_window:])
    return np.full(predict_steps, mean_value)

def train_predict_ses(y_train, predict_steps, alpha=None):
    if len(y_train) == 0: return np.zeros(predict_steps)
    if len(y_train) == 1: return np.full(predict_steps, y_train[0])

    if alpha is None:
        def ses_rmse(param):
            alpha_opt = param[0]
            if not (0 <= alpha_opt <= 1): return np.inf
            smoothed = np.zeros_like(y_train, dtype=float)
            smoothed[0] = y_train[0]
            for i in range(1, len(y_train)):
                smoothed[i] = alpha_opt * y_train[i] + (1 - alpha_opt) * smoothed[i-1]
            return np.sqrt(np.mean((y_train[1:] - smoothed[:-1])**2))

        opt_res = minimize(ses_rmse, x0=[0.5], method='L-BFGS-B', bounds=[(0, 1)])
        alpha = opt_res.x[0]

    smoothed = np.zeros_like(y_train, dtype=float)
    smoothed[0] = y_train[0]
    for i in range(1, len(y_train)):
        smoothed[i] = alpha * y_train[i] + (1 - alpha) * smoothed[i-1]
    return np.full(predict_steps, smoothed[-1])

def train_predict_theta(x_train, y_train, x_predict, theta=2.0):
    n = len(y_train)
    if n < 2: return np.full(len(x_predict), y_train[-1] if n > 0 else 0)
    try:
        slope, intercept, _, _, _ = linregress(x_train, y_train)
    except ValueError:
        return np.full(len(x_predict), np.mean(y_train))
    trend_line_hist = intercept + slope * x_train
    theta_line_train = theta * (y_train - trend_line_hist) + trend_line_hist
    forecast_ses = train_predict_ses(theta_line_train, predict_steps=len(x_predict))
    forecast_trend = intercept + slope * x_predict
    final_forecast = (1/theta) * forecast_ses + (1 - 1/theta) * forecast_trend
    return final_forecast

def _full_robust_theta_core(x_train, y_train, x_predict, tol=1e-6, max_iter=100):
    steps_ahead = len(x_predict)
    X_mat = np.c_[np.ones(len(x_train)), x_train]
    try:
        beta = np.linalg.lstsq(X_mat, y_train, rcond=None)[0]
    except np.linalg.LinAlgError:
        beta = np.array([np.mean(y_train), 0.0])
    
    for i in range(max_iter):
        beta_old = beta.copy()
        y_est = X_mat @ beta
        resid = y_train - y_est
        median_resid = np.median(resid)
        mad = np.median(np.abs(resid - median_resid))
        scale = mad / 0.6745 
        if scale < 1e-9: scale = 1e-9
        z = (resid - median_resid) / scale
        k = 1.345 
        weights = np.ones_like(z)
        outliers = np.abs(z) > k
        weights[outliers] = k / np.abs(z[outliers])
        W_sqrt = np.sqrt(weights)
        X_w = X_mat * W_sqrt[:, np.newaxis]
        y_w = y_train * W_sqrt
        try:
            beta = np.linalg.lstsq(X_w, y_w, rcond=None)[0]
        except np.linalg.LinAlgError:
            beta = beta_old 
            break
        if np.sum(np.abs(beta - beta_old)) < tol:
            break
            
    slope, intercept = beta[1], beta[0]
    trend_train = intercept + slope * x_train
    trend_future = intercept + slope * x_predict
    theta_line_2 = 2 * y_train - trend_train
    theta_2_forecast = train_predict_ses(theta_line_2, predict_steps=steps_ahead)
    final_forecast = 0.5 * trend_future + 0.5 * theta_2_forecast
    return final_forecast

def train_predict_robust_hurdle_theta(x_train, y_train, x_predict, zero_threshold=0.3, tol=1e-6, max_iter=100):
    n = len(y_train)
    steps_ahead = len(x_predict)
    zero_count = np.sum(y_train == 0)
    zero_ratio = zero_count / n
    if zero_ratio < zero_threshold:
        return _full_robust_theta_core(x_train, y_train, x_predict, tol, max_iter)
        
    binary_series = (y_train > 0).astype(float)
    prob_forecast_val = train_predict_ses(binary_series, predict_steps=1)[0]
    prob_forecast = np.clip(prob_forecast_val, 0.01, 1.0)
    
    non_zero_indices = np.where(y_train > 0)[0]
    non_zero_y = y_train[non_zero_indices]
    
    if len(non_zero_y) < 3:
        magnitude_forecast = np.full(steps_ahead, np.mean(non_zero_y) if len(non_zero_y)>0 else 0)
    else:
        x_seq_train = np.arange(len(non_zero_y))
        x_seq_pred = np.arange(len(non_zero_y), len(non_zero_y) + steps_ahead)
        magnitude_forecast = _full_robust_theta_core(x_seq_train, non_zero_y, x_seq_pred, tol, max_iter)

    return prob_forecast * magnitude_forecast

def train_greedy_forward_ensemble(X_meta, y_true, model_keys, n_iterations=20, colors=None, verbose=True):
    n_samples, n_models = X_meta.shape
    ensemble_model_indices = []
    
    if verbose:
        color_cyan = colors.CYAN if colors else ''
        color_reset = colors.RESET if colors else ''
        print(f"\n{color_cyan}正在執行元模型團隊建設 (貪婪前向選擇法)...{color_reset}")
    
    def rmse(y_true, y_pred):
        return np.sqrt(np.mean((y_true - y_pred)**2))

    ensemble_predictions = np.zeros(n_samples)
    
    for i in range(n_iterations):
        best_model_idx_this_round = -1
        lowest_error = rmse(y_true, ensemble_predictions) if i > 0 else np.inf
        
        for model_idx in range(n_models):
            candidate_model_preds = X_meta[:, model_idx]
            temp_predictions = (ensemble_predictions * i + candidate_model_preds) / (i + 1)
            current_error = rmse(y_true, temp_predictions)
            
            if current_error < lowest_error:
                lowest_error = current_error
                best_model_idx_this_round = model_idx
        
        if best_model_idx_this_round != -1:
            ensemble_model_indices.append(best_model_idx_this_round)
            best_model_preds = X_meta[:, best_model_idx_this_round]
            ensemble_predictions = (ensemble_predictions * i + best_model_preds) / (i + 1)
        else:
            break
            
    if verbose:
        print("團隊建設完成。")
        
    return ensemble_model_indices, None

def run_stacked_ensemble_model(monthly_expenses_df, steps_ahead, n_folds=5, ensemble_size=20, colors=None, verbose=True):
    data = monthly_expenses_df['Real_Amount'].values
    x = np.arange(1, len(data) + 1)
    n_samples = len(data)
    
    base_models = {
        'poly': train_predict_poly, 'huber': train_predict_huber, 'des': train_predict_des, 'drift': train_predict_drift,
        'seasonal': train_predict_seasonal, 'seasonal_naive': train_predict_seasonal_naive, 'naive': train_predict_naive,
        'moving_average': train_predict_moving_average, 'rolling_median': train_predict_rolling_median, 'global_median': train_predict_global_median,
        'ses': train_predict_ses, 'theta': train_predict_theta,
        'robust_hurdle': train_predict_robust_hurdle_theta, 
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
            elif key in ['poly', 'huber', 'theta', 'robust_hurdle']:
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
        elif key in ['poly', 'huber', 'theta', 'robust_hurdle']:
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

def run_robust_decomp_forecaster(monthly_expenses_df, steps_ahead, colors=None, verbose=True):
    data = monthly_expenses_df['Real_Amount'].values
    n_total = len(data)
    
    kernel_size = 5
    if kernel_size >= n_total:
        kernel_size = 3 if n_total >= 3 else 1
    
    robust_series = data
    if n_total > kernel_size:
        try:
            robust_series = signal.medfilt(data, kernel_size=kernel_size)
        except Exception:
            robust_series = data 

    robust_df = monthly_expenses_df.copy()
    robust_df['Real_Amount'] = robust_series
    
    _, seasonal_indices = seasonal_decomposition(robust_df)
    
    # 這裡計算去季節化數據
    deseasonalized_data = data / monthly_expenses_df['Month'].map(seasonal_indices)
    x = np.arange(1, n_total + 1)
    
    try:
        trend_forecast_seq, historical_trend, _, trend_lower_seq, trend_upper_seq = \
            huber_robust_regression(x, deseasonalized_data, steps_ahead)
    except Exception:
        slope, intercept, _, _, _ = linregress(x, deseasonalized_data)
        historical_trend = intercept + slope * x
        future_x = np.arange(n_total + 1, n_total + steps_ahead + 1)
        trend_forecast_seq = intercept + slope * future_x
        trend_lower_seq, trend_upper_seq = trend_forecast_seq, trend_forecast_seq 
        
    last_observed_month = monthly_expenses_df['Parsed_Date'].iloc[-1].month
    future_seasonal_factors = []
    for i in range(1, steps_ahead + 1):
        future_month = (last_observed_month + i - 1) % 12 + 1
        future_seasonal_factors.append(seasonal_indices.get(future_month, 1.0))
    future_seasonal_factors = np.array(future_seasonal_factors)

    final_prediction_seq = trend_forecast_seq * future_seasonal_factors
    
    # [修正點]：加上 .values 將 Series 轉為 Numpy Array，避免索引錯誤 (KeyError)
    historical_pred = (historical_trend * monthly_expenses_df['Month'].map(seasonal_indices)).values
    
    lower_seq = trend_lower_seq * future_seasonal_factors if trend_lower_seq is not None else None
    upper_seq = trend_upper_seq * future_seasonal_factors if trend_upper_seq is not None else None

    return (
        final_prediction_seq, 
        historical_pred, 
        None, 
        None, 
        lower_seq, 
        upper_seq, 
        None 
    )

def run_full_ensemble_pipeline(monthly_expenses_df, steps_ahead, colors, verbose=True):
    data = monthly_expenses_df['Real_Amount'].values
    x = np.arange(1, len(data) + 1)
    num_months = len(data)

    base_models = {
        'poly': train_predict_poly, 'huber': train_predict_huber, 'des': train_predict_des, 'drift': train_predict_drift,
        'seasonal': train_predict_seasonal, 'seasonal_naive': train_predict_seasonal_naive, 'naive': train_predict_naive,
        'moving_average': train_predict_moving_average, 'rolling_median': train_predict_rolling_median, 'global_median': train_predict_global_median,
        'ses': train_predict_ses, 'theta': train_predict_theta,
        'robust_hurdle': train_predict_robust_hurdle_theta,
    }
    model_keys = list(base_models.keys())
    
    if verbose: print(f"\n{colors.CYAN}--- 策略A (P100): 階段 1/3: 執行基礎模型交叉驗證... ---{colors.RESET}")
    _, _, _, _, _, _, historical_base_preds_df = run_stacked_ensemble_model(
        monthly_expenses_df, steps_ahead, colors=colors, verbose=False
    )
    meta_features = historical_base_preds_df.values
    
    if verbose: print(f"{colors.CYAN}--- 策略A (P100): 階段 2/3: 執行巢狀交叉驗證與權重校準... ---{colors.RESET}")
    n_folds = 5
    fold_indices = np.array_split(np.arange(num_months), n_folds)
    X_level2_hist_oof = np.zeros((num_months, 3))

    for i in range(n_folds):
        train_idx = np.concatenate([fold_indices[j] for j in range(n_folds) if i != j])
        val_idx = fold_indices[i]
        if len(train_idx) == 0: continue
        meta_features_train, y_train = meta_features[train_idx], data[train_idx]
        selected_indices_fold, _ = train_greedy_forward_ensemble(meta_features_train, y_train, model_keys, n_iterations=20, verbose=False, colors=colors)
        gfs_counts_fold = Counter(selected_indices_fold)
        gfs_weights_fold = np.zeros(len(base_models))
        if selected_indices_fold:
            for idx, count in gfs_counts_fold.items(): gfs_weights_fold[idx] = count
            gfs_weights_fold /= np.sum(gfs_weights_fold)
        else: gfs_weights_fold.fill(1/len(base_models))
        X_level2_hist_oof[val_idx, 0] = meta_features[val_idx] @ gfs_weights_fold

        maes_fold = [np.mean(np.abs(y_train - meta_features_train[:, i])) for i in range(len(base_models))]
        pwa_weights_fold = 1 / (np.array(maes_fold) + 1e-9)
        pwa_weights_fold /= np.sum(pwa_weights_fold)
        X_level2_hist_oof[val_idx, 1] = meta_features[val_idx] @ pwa_weights_fold

        nnls_weights_fold, _ = nnls(meta_features_train, y_train)
        if np.sum(nnls_weights_fold) > 1e-9: nnls_weights_fold /= np.sum(nnls_weights_fold)
        else: nnls_weights_fold.fill(1/len(base_models))
        X_level2_hist_oof[val_idx, 2] = meta_features[val_idx] @ nnls_weights_fold

    weights_level2 = train_meta_model_with_bootstrap_gfs(X_level2_hist_oof, data, colors=colors, verbose=verbose)
        
    selected_indices, _ = train_greedy_forward_ensemble(meta_features, data, model_keys, n_iterations=20, colors=colors, verbose=False)
    gfs_counts = Counter(selected_indices); gfs_weights = np.zeros(len(base_models))
    if selected_indices:
        for idx, count in gfs_counts.items(): gfs_weights[idx] = count
        gfs_weights /= np.sum(gfs_weights)
    else: gfs_weights.fill(1/len(base_models))
    maes = [np.mean(np.abs(data - meta_features[:, i])) for i in range(len(base_models))]
    pwa_weights = 1 / (np.array(maes) + 1e-9); pwa_weights /= np.sum(pwa_weights)
    nnls_weights, _ = nnls(meta_features, data)
    if np.sum(nnls_weights) > 1e-9: nnls_weights /= np.sum(nnls_weights)
    else: nnls_weights.fill(1/len(base_models))
    
    x_future = np.arange(num_months + 1, num_months + steps_ahead + 1)
    future_base_predictions = np.zeros((steps_ahead, len(base_models)))
    for j, key in enumerate(model_keys):
        model_func = base_models[key]
        if key in ['seasonal']:
            future_base_predictions[:, j] = model_func(monthly_expenses_df, steps_ahead)
        elif key in ['poly', 'huber', 'theta', 'robust_hurdle']:
            future_base_predictions[:, j] = model_func(x, data, x_future)
        else:
            future_base_predictions[:, j] = model_func(data, steps_ahead)

    future_pred_l1_gfs = future_base_predictions @ gfs_weights
    future_pred_l1_pwa = future_base_predictions @ pwa_weights
    future_pred_l1_nnls = future_base_predictions @ nnls_weights
    X_level2_future = np.column_stack([future_pred_l1_gfs, future_pred_l1_pwa, future_pred_l1_nnls])
    
    future_pred_fused_seq = X_level2_future @ weights_level2
    historical_pred_fused = X_level2_hist_oof @ weights_level2

    if verbose: print(f"{colors.CYAN}--- 策略A (P100): 階段 3/3: 執行殘差提升... ---{colors.RESET}")
    
    historical_pred_final = historical_pred_fused.copy()
    future_pred_final_seq = future_pred_fused_seq.copy()

    if num_months >= 18:
        T = 10
        learning_rate = 0.1
        patience = 3
        weak_model_func = base_models['huber']
        min_len_for_rmse = min(len(data), len(historical_pred_final))
        initial_residuals = data[:min_len_for_rmse] - historical_pred_final[:min_len_for_rmse]
        best_rmse = np.sqrt(np.mean(initial_residuals**2))
        epochs_without_improvement = 0
        best_historical_pred = historical_pred_final.copy()
        best_future_pred = future_pred_final_seq.copy()

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
                if verbose: print(f"{colors.YELLOW}資訊：殘差提升在第 {boost_iter + 1} 次迭代觸發早停。{colors.RESET}")
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
        t_val = t.ppf(0.975, dof)
        lower_seq, upper_seq = future_pred_final_seq - t_val*se, future_pred_final_seq + t_val*se
    
    meta_model_names = ["貪婪前向選擇法", "性能加權平均法", "非負最小平方法"]
    meta_model_weights_for_report = {name: w for name, w in zip(meta_model_names, weights_level2)}

    return future_pred_final_seq, historical_pred_final, effective_base_weights, meta_model_weights_for_report, lower_seq, upper_seq, historical_base_preds_df

def run_secondary_seasonal_correction(historical_pred, y_true, steps_ahead, acf_results):
    initial_residuals = np.asarray(y_true - historical_pred)
    significant_seasonal_lags = {
        lag: result['acf'] for lag, result in acf_results.items()
        if lag >= 3 and result['is_significant']
    }
    if not significant_seasonal_lags:
        return np.zeros(steps_ahead), np.zeros_like(historical_pred), False, None

    total_acf_weight = sum(abs(v) for v in significant_seasonal_lags.values())
    if total_acf_weight == 0:
        return np.zeros(steps_ahead), np.zeros_like(historical_pred), False, None
        
    final_correction_forecast = np.zeros(steps_ahead)
    final_historical_correction = np.zeros_like(historical_pred, dtype=float)
    lag_weights = {}

    for lag, acf_value in significant_seasonal_lags.items():
        if len(initial_residuals) < lag:
            continue
        weight = abs(acf_value) / total_acf_weight
        lag_weights[lag] = weight
        past_residuals_for_future = initial_residuals[-lag:]
        correction_forecast = np.tile(past_residuals_for_future, steps_ahead // lag + 1)[:steps_ahead] * acf_value
        final_correction_forecast += correction_forecast * weight
        historical_correction = np.zeros_like(initial_residuals, dtype=float)
        historical_correction[lag:] = initial_residuals[:-lag] * acf_value
        final_historical_correction += historical_correction * weight

    lag_weights_str = ", ".join(f"{lag}個月: {weight:.1%}" for lag, weight in sorted(lag_weights.items()))
    return final_correction_forecast, final_historical_correction, True, lag_weights_str

def run_autocorrective_residual_refinement(historical_pred, y_true, steps_ahead, acf_results):
    if not acf_results.get(1, {}).get('is_significant', False):
        return np.zeros(steps_ahead), np.zeros_like(historical_pred), False

    initial_residuals = np.asarray(y_true - historical_pred)
    if len(initial_residuals) < 3:
        return np.zeros(steps_ahead), np.zeros_like(historical_pred), False

    X = initial_residuals[:-1].reshape(-1, 1)
    y = initial_residuals[1:]
    try:
        slope, intercept, _, _, _ = linregress(X.flatten(), y)
    except ValueError:
        return np.zeros(steps_ahead), np.zeros_like(historical_pred), False
        
    historical_correction = intercept + slope * initial_residuals[:-1]
    residual_forecast = []
    last_known_residual = initial_residuals[-1]
    
    for _ in range(steps_ahead):
        next_residual = intercept + slope * last_known_residual
        residual_forecast.append(next_residual)
        last_known_residual = next_residual

    full_historical_correction = np.zeros_like(historical_pred, dtype=float)
    full_historical_correction[1:] = historical_correction

    return np.array(residual_forecast), full_historical_correction, True

def run_drf_prediction(monthly_expenses_df, steps_ahead=1, trend_window=12, model='additive', period=12):
    series = pd.Series(monthly_expenses_df['Real_Amount'].values, index=pd.to_datetime(monthly_expenses_df['Parsed_Date']))
    
    if len(series) < period:
        return np.full(steps_ahead, series.mean())

    decomposed = manual_seasonal_decompose(series, period=period, model=model)
    valid_trend = decomposed['trend'].dropna()
    last_n_trend_points = valid_trend.tail(min(len(valid_trend), trend_window))
    
    trend_forecasts = []
    if len(last_n_trend_points) < 2:
        trend_forecast = last_n_trend_points.mean() if not last_n_trend_points.empty else series.mean()
        trend_forecasts = np.full(steps_ahead, trend_forecast)
    else:
        x = np.arange(len(last_n_trend_points))
        y = last_n_trend_points.values
        slope, intercept, _, _, _ = stats.linregress(x, y)
        for i in range(1, steps_ahead + 1):
            future_x = len(last_n_trend_points) + i - 1
            trend_forecasts.append(slope * future_x + intercept)
            
    seasonal_forecasts = []
    last_date = series.index[-1]
    unique_seasonal_components = decomposed['seasonal'].groupby(decomposed['seasonal'].index.month).mean()
    for i in range(1, steps_ahead + 1):
        target_date = last_date + pd.DateOffset(months=i)
        target_month = target_date.month
        seasonal_forecasts.append(unique_seasonal_components.get(target_month, 0.0))

    if model == 'additive':
        drf_predictions = np.array(trend_forecasts) + np.array(seasonal_forecasts)
    else:
        drf_predictions = np.array(trend_forecasts) * np.array(seasonal_forecasts)

    hist_pred_drf = decomposed['trend'] + decomposed['seasonal']
    return drf_predictions, hist_pred_drf.values, None, None

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
    
    num_months = 0 
    
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
        steps_ahead = (target_period.year - last_period.year) * 12 + (target_period.month - last_period.month)
        if steps_ahead <= 0:
            if "數據包含未來月份" not in str(warnings_report):
                 warnings_report += f"\n{colors.YELLOW}警告：您的數據包含未來月份的記錄。預測仍將針對真實世界的下一個月份 ({target_month_str})。{colors.RESET}"
            steps_ahead = 1 
        if steps_ahead > 12:
            step_warning = f"{colors.YELLOW}警告：預測步數超過12 ({steps_ahead})，遠期預測不確定性增加。{colors.RESET}"

    predicted_expense_str, ci_str, method_used = "無法預測 (資料不足)", "", ""
    upper, lower, predicted_value = None, None, None
    future_pred_seq = None
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
    risk_factors_report = ""
    acrr_activated, rssc_activated = False, False
    rssc_lag_str = None
    gating_reason = ""
    effective_base_weights = None

    if analysis_data is not None and len(analysis_data) >= 2:
        num_months = len(analysis_data)
        data, x = analysis_data, np.arange(1, num_months + 1)
        lower_seq, upper_seq = None, None

        if num_months >= 36:
            GATING_MULTIPLIER_K = 1.5
            method_used = " (基於動態策略集成法)"
            
            print(f"\n{colors.CYAN}正在為所有策略預先計算歷史表現...{colors.RESET}")
            _, hist_pred_A, _, _, _, _, _ = \
                run_full_ensemble_pipeline(df_for_seasonal_model, steps_ahead, colors, verbose=False)
            _, hist_pred_B, _, _, _, _, _ = \
                run_robust_decomp_forecaster(df_for_seasonal_model, steps_ahead, colors, verbose=False)

            prequential_results, final_weights = run_dynamic_strategy_ensemble_prequential(df_for_seasonal_model, hist_pred_A, hist_pred_B, colors)
            final_weight_A, final_weight_B = final_weights
            
            _, cv_mpi_scores = run_dynamic_strategy_ensemble_cv(df_for_seasonal_model, hist_pred_A, hist_pred_B, colors=colors)

            final_pred_A_seq, _, effective_base_weights, meta_weights_A, lower_A, upper_A, _ = \
                run_full_ensemble_pipeline(df_for_seasonal_model, steps_ahead, colors, verbose=True)
            final_pred_B_seq, _, _, _, lower_B, upper_B, _ = \
                run_robust_decomp_forecaster(df_for_seasonal_model, steps_ahead, colors, verbose=False)
            
            future_pred_seq = (final_pred_A_seq * final_weight_A) + (final_pred_B_seq * final_weight_B)
            historical_pred = (hist_pred_A * final_weight_A) + (hist_pred_B * final_weight_B)
            lower_seq = (lower_A * final_weight_A) + (lower_B * final_weight_B) if lower_A is not None and lower_B is not None else None
            upper_seq = (upper_A * final_weight_A) + (upper_B * final_weight_B) if upper_A is not None and upper_B is not None else None
            
            temp_residuals = data - historical_pred
            temp_acf_results = compute_acf_results(temp_residuals, num_months)
            
            seasonal_forecast, seasonal_hist_corr, rssc_activated, rssc_lag_str = \
                run_secondary_seasonal_correction(historical_pred, data, steps_ahead, temp_acf_results)
            if rssc_activated:
                future_pred_seq += seasonal_forecast
                historical_pred += seasonal_hist_corr
                method_used += " + RSSC"

            final_temp_residuals = data - historical_pred
            final_temp_acf_results = compute_acf_results(final_temp_residuals, num_months)
            
            acrr_forecast, acrr_hist_corr, acrr_activated = \
                run_autocorrective_residual_refinement(historical_pred, data, steps_ahead, final_temp_acf_results)
            if acrr_activated:
                future_pred_seq += acrr_forecast
                historical_pred += acrr_hist_corr
                method_used += " + ACRR"
            
            final_residuals = data - historical_pred
            final_acf_results = compute_acf_results(final_residuals, num_months)
            
            use_expert_model = False
            gating_reason = f"{colors.WHITE}守門人機制：未激活 (主模型表現穩定){colors.RESET}"
            significance_boundary = 2 / np.sqrt(num_months)
            dynamic_acf_threshold = GATING_MULTIPLIER_K * significance_boundary
            
            for lag, result in final_acf_results.items():
                if lag >= 3 and abs(result['acf']) > dynamic_acf_threshold:
                    use_expert_model = True
                    gating_reason = (f"{colors.YELLOW}守門人機制：已激活 (偵測到殘差在延遲 {lag} 個月時規律過強, "
                                     f"ACF={result['acf']:.2f} > 閾值={dynamic_acf_threshold:.2f})，切換至 DRF 專家模型。{colors.RESET}")
                    break

            if use_expert_model:
                method_used = " (基於專家門控 - DRF 模型)"
                future_pred_seq, historical_pred, lower_seq, upper_seq = \
                    run_drf_prediction(monthly_expenses, steps_ahead=steps_ahead)

            model_names_base = ["多項式", "穩健趨勢", "指數平滑(Auto)", "漂移", "季節分解", "季節模仿", "單純", "移動平均", "滾動中位", "全局中位", "簡易平滑(Auto)", "Theta趨勢", "穩健混合(Theta-Hurdle)"]
            if effective_base_weights is not None:
                sorted_parts = sorted(zip(effective_base_weights, model_names_base), reverse=True)
                report_parts_base_sorted = [f"{name}({weight:.1%})" for weight, name in sorted_parts if weight > 0.001]
                chunks = [report_parts_base_sorted[i:i + 3] for i in range(0, len(report_parts_base_sorted), 3)]
                indentation = "\n" + " " * 25
                base_model_weights_report = f"  - 基礎模型權重 (策略A): {indentation.join([', '.join(c) for c in chunks])}"
            if meta_weights_A:
                 report_parts_meta = [f"{name}({weight:.1%})" for name, weight in meta_weights_A.items() if weight > 0.001]
                 meta_model_weights_report = f"  - 元模型融合策略 (策略A): {', '.join(report_parts_meta)}"
            meta_model_weights_report += f"\n  - {colors.BOLD}動態策略權重{colors.RESET}: P100({final_weight_A:.1%}), 穩健分解({final_weight_B:.1%})"

            mean_expense_for_report = monthly_expenses['Real_Amount'].mean()
            prequential_metrics_report = format_prequential_metrics_report(prequential_results, mean_expense_for_report, colors)
            adaptive_dynamics_report = format_adaptive_dynamics_report(prequential_results, monthly_expenses, colors)
        
        elif 24 <= num_months < 36:
            method_used = " (基於三層式混合集成法)"
            future_pred_seq, historical_pred, effective_base_weights, weights_level2_report, lower_seq, upper_seq, _ = \
                run_full_ensemble_pipeline(df_for_seasonal_model, steps_ahead, colors, verbose=True)
            
            report_parts_meta = [f"{name}({weight:.1%})" for name, weight in weights_level2_report.items() if weight > 0.001]
            meta_model_weights_report = f"  - 元模型融合策略: {', '.join(report_parts_meta)}"
            
            model_names_base = ["多項式", "穩健趨勢", "指數平滑(Auto)", "漂移", "季節分解", "季節模仿", "單純", "移動平均", "滾動中位", "全局中位", "簡易平滑(Auto)", "Theta趨勢", "穩健混合(Theta-Hurdle)"]
            sorted_parts = sorted(zip(effective_base_weights, model_names_base), reverse=True)
            report_parts_base_sorted = [f"{name}({weight:.1%})" for weight, name in sorted_parts if weight > 0.001]
            chunks = [report_parts_base_sorted[i:i + 3] for i in range(0, len(report_parts_base_sorted), 3)]
            lines = [", ".join(chunk) for chunk in chunks]
            indentation = "\n" + " " * 25
            base_model_weights_report = f"  - 基礎模型權重: {indentation.join(lines)}"

        elif 18 <= num_months < 24:
            method_used = " (基於穩健迴歸IRLS-Huber)"
            future_pred_seq, historical_pred, _, lower_seq, upper_seq = huber_robust_regression(x, data, steps_ahead)
        else:
            method_used = " (基於直接-遞歸混合)"
            model_logic = 'poly' if num_months >= 12 else 'linear' if num_months >= 6 else 'ema'
            if model_logic == 'poly':
                predicted_value, lower, upper = polynomial_regression_with_ci(x, data, 2, num_months + steps_ahead)
                historical_pred = np.poly1d(np.polyfit(x, data, 2))(x)
                future_pred_seq, lower_seq, upper_seq = np.array([predicted_value]), np.array([lower]), np.array([upper])
            elif model_logic == 'linear':
                slope, intercept, _, _, _ = linregress(x, data)
                predicted_value = intercept + slope * (num_months + steps_ahead)
                historical_pred = intercept + slope * x
                n = len(x); x_mean = np.mean(x); ssx = np.sum((x - x_mean)**2)
                if n > 2:
                    mse = np.sum((data-historical_pred)**2)/(n-2)
                    se = np.sqrt(mse * (1 + 1/n + ((num_months+steps_ahead)-x_mean)**2/ssx))
                    t_val = t.ppf(0.975, n-2)
                    lower, upper = predicted_value - t_val*se, predicted_value + t_val*se
                future_pred_seq, lower_seq, upper_seq = np.array([predicted_value]), np.array([lower]), np.array([upper])
            elif model_logic == 'ema':
                ema = pd.Series(data).ewm(span=num_months, adjust=False).mean()
                future_pred_seq = np.array([ema.iloc[-1]])
                historical_pred = ema.values

        if future_pred_seq is not None:
            predicted_value = future_pred_seq[-1]
            
            # [新增] 雙軌貝氏驗證啟用點
            if monthly_expenses is not None and not monthly_expenses.empty:
                predicted_value = execute_bayesian_validation(
                    monthly_expenses, 
                    'Real_Amount', 
                    predicted_value, 
                    colors
                )

            lower = lower_seq[-1] if lower_seq is not None else None
            upper = upper_seq[-1] if upper_seq is not None else None
            ci_str = f" [下限：{lower:,.2f}，上限：{upper:,.2f}] (95% 信心)" if lower is not None and upper is not None else ""
            predicted_expense_str = f"{predicted_value:,.2f}"

        if historical_pred is not None:
            min_len_for_res = min(len(data), len(historical_pred))
            residuals = data[:min_len_for_res] - historical_pred[:min_len_for_res]
            historical_mae, historical_rmse = np.mean(np.abs(residuals)), np.sqrt(np.mean(residuals**2))
            
            sum_abs_actual = np.sum(np.abs(data[:min_len_for_res]))
            historical_wape = (np.sum(np.abs(residuals)) / sum_abs_actual * 100) if sum_abs_actual > 1e-9 else 100.0
            
            if len(data) > 1:
                mae_naive = np.mean(np.abs(data[1:] - data[:-1]))
                historical_mase = (historical_mae/mae_naive) if mae_naive > 1e-9 else None
            
            res_quantiles = np.percentile(residuals, [q * 100 for q in quantiles])
            for i, q in enumerate(quantiles):
                quantile_preds[q] = historical_pred + res_quantiles[i]
            
            if num_months >= 12: 
                df_for_anomalies = df_for_seasonal_model if df_for_seasonal_model is not None else monthly_expenses
                anomaly_info = calculate_anomaly_scores(df_for_anomalies)
                is_shock_flags = anomaly_info['Is_Shock'].values[:min_len_for_res]
                residuals_clean = residuals[~is_shock_flags]
                data_clean = data[:min_len_for_res][~is_shock_flags]
                if len(residuals_clean) > 0: historical_rmse_robust = np.sqrt(np.mean(residuals_clean**2))
                sum_abs_clean = np.sum(np.abs(data_clean))
                if len(data_clean) > 0 and sum_abs_clean > 1e-9:
                    historical_wape_robust = (np.sum(np.abs(residuals_clean)) / sum_abs_clean) * 100
        
        if num_months >= 36 and mpi_results is None:
            fss_score = calculate_fss(prequential_results, mean_expense_for_report).get('fss_score', 0)
            erai_results = perform_internal_benchmarking(data, historical_pred, is_shock_flags)
            temp_mpi_score = calculate_mpi_3_0_and_rate(data, historical_pred, historical_wape, erai_results['erai_score'], 100, fss_score)['mpi_score']
            mpi_percentile_rank = percentileofscore(cv_mpi_scores, temp_mpi_score, kind='rank') if cv_mpi_scores else 0
            mpi_results = calculate_mpi_3_0_and_rate(data, historical_pred, historical_wape, erai_results['erai_score'], mpi_percentile_rank, fss_score)


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

    calibration_data = ({}, "insufficient_data") 
    acf_results = {}
    quantile_spread = 0.0

    if residuals is not None and len(residuals) >= 2:
        preq_res = prequential_results if 'prequential_results' in locals() else None
        calibration_data = compute_smart_calibration_results(residuals, preq_res, quantiles)
        
        acf_results = compute_acf_results(residuals, num_months)
        quantile_spread = compute_quantile_spread(p25, p75, predicted_value)

    calib_results_dict = calibration_data[0] 
    risk_status, risk_description, suggested_budget, dynamic_risk_coefficient, trend_score, vol_score, shock_score, data_reliability, error_coefficient, error_buffer, trend_scores, vol_scores, shock_scores, overall_score, risk_buffer = assess_risk_and_budget(predicted_value, upper, p95, expense_std_dev, monthly_expenses, p25, p75, historical_wape, historical_rmse, calibration_results=calib_results_dict, acf_results=acf_results, quantile_spread=quantile_spread)
    
    if trend_scores is not None and isinstance(trend_scores, dict) and not trend_scores.get('is_advanced'):
        risk_factors_report = format_detailed_risk_analysis_report(dynamic_risk_coefficient, error_coefficient, overall_score, trend_score, trend_scores, vol_score, vol_scores, shock_score, shock_scores, colors)

    diagnostic_report = ""
    if residuals is not None and len(residuals)>=2:
        reports = [
            quantile_loss_report(data[:len(residuals)], quantile_preds, quantiles, colors),
            model_calibration_analysis(calibration_data, quantiles, colors),
            residual_autocorrelation_diagnosis(residuals, num_months, colors),
            residual_normality_report(residuals, colors)
        ]
        diagnostic_report = "\n\n".join(filter(None, reports))


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
    
    if gating_reason:
        print(f"  - {gating_reason}")
    
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
    
    if num_months >= 36:
        if rssc_activated:
            print(f"  - {colors.GREEN}二次季節性校正 (RSSC): 已啟用 (權重: {rssc_lag_str}){colors.RESET}")
        else:
            print(f"  - {colors.WHITE}二次季節性校正 (RSSC): 未啟用 (無顯著季節性規律){colors.RESET}")
        if acrr_activated:
            print(f"  - {colors.GREEN}殘差自動校正 (ACRR): 已啟用 (基於 1 個月延遲){colors.RESET}")
        else:
            print(f"  - {colors.WHITE}殘差自動校正 (ACRR): 未啟用 (無顯著短期慣性){colors.RESET}")
    else:
        print(f"  - {colors.WHITE}二次季節性校正 (RSSC): 未啟用 (資料需 ≥ 36 個月){colors.RESET}")
        print(f"  - {colors.WHITE}殘差自動校正 (ACRR): 未啟用 (資料需 ≥ 36 個月){colors.RESET}")

    if base_model_weights_report: print(base_model_weights_report)
    if meta_model_weights_report: print(meta_model_weights_report)
    if step_warning: print(step_warning)
    
    if effective_base_weights is not None and len(effective_base_weights) == len(model_names_base):
        rh_idx = -1 
        rh_weight = effective_base_weights[rh_idx]
        if rh_weight > 0.01:
            print(f"\n{colors.YELLOW}{colors.BOLD}>>> 演算法運作機制透視 (Robust Theta-Hurdle){colors.RESET}")
            print(f"  {colors.WHITE}由於檢測到數據特徵符合條件，系統啟用了穩健混合模型 (權重 {rh_weight:.1%})：{colors.RESET}")
            print(f"  1. {colors.BOLD}Hurdle 機率層{colors.RESET}: 計算支出發生的可能性，排除零值對趨勢線的拉扯。")
            print(f"  2. {colors.BOLD}IRLS-Huber 收斂{colors.RESET}: 透過迭代重加權算法，自動降低異常極端值(Outliers)的影響權重。")
            print(f"  3. {colors.BOLD}Theta 分解{colors.RESET}: 結合長期穩健趨勢與短期非線性動態 (Theta=2)，提升對波動的適應性。")

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
            num_shocks = trend_scores.get('num_shocks', 0)
            change_date = trend_scores.get('change_date')
            peak_analysis = trend_scores.get('peak_analysis')
            
            if change_date:
                print(f"{colors.YELLOW}  - 模式偵測{colors.RESET}: 偵測到您的支出模式在{colors.YELLOW}{colors.BOLD} {change_date} {colors.RESET}附近發生結構性轉變，後續評估將更側重於近期數據。{colors.RESET}")
            if num_shocks > 0:
                print(f"{colors.RED}  - 衝擊偵測{colors.RESET}: 系統識別出{colors.RED}{colors.BOLD} {num_shocks} 次{colors.RESET}「真實衝擊」(極端開銷)，已納入攤提金準備中。{colors.RESET}")
            if peak_analysis:
                print(f"{colors.CYAN}  - 消費高峰分析{colors.RESET}: 偵測到 {peak_analysis['num_peaks']} 個消費高峰，平均間隔約 {peak_analysis['avg_peak_interval']}，呈現「{peak_analysis['periodicity_label']}」的潛在規律。{colors.RESET}")

        if suggested_budget is not None:
            print(f"{colors.BOLD}建議 {target_month_str} 預算: {suggested_budget:,.2f} 元{colors.RESET}")
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
        
        if risk_factors_report:
            print(risk_factors_report)

    print(f"\n{colors.WHITE}【註】「實質金額」：為讓不同年份的支出能公平比較，本報告已將所有歷史數據，統一換算為當前基期年的貨幣價值。{colors.RESET}")
    print(f"{colors.CYAN}{colors.BOLD}========================================{colors.RESET}\n")

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
