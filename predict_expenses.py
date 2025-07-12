#!/usr/bin/env python3

################################################################################
#                                                                              #
#                     財務開銷預測輔助腳本 (Predict Expenses) v1.0                #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本使用 Prophet 模型預測下個月開銷，基於歷史交易數據。                           #
# 支援自動安裝依賴、資料過濾和圖表生成。                                             #
#                                                                              #
################################################################################

import argparse
import sys
import os
import subprocess
import pandas as pd
from prophet import Prophet
import matplotlib.pyplot as plt
from datetime import datetime

# --- 自動安裝依賴函數 ---
def install_dependencies():
    required_packages = ['prophet', 'pandas', 'matplotlib']
    for pkg in required_packages:
        try:
            __import__(pkg)
        except ImportError:
            print(f"安裝缺少的依賴: {pkg}")
            subprocess.check_call([sys.executable, '-m', 'pip', 'install', pkg])

# --- 主要預測函數 ---
def predict_expenses(data_file, periods=1, output_chart=True):
    # 讀取 CSV 資料
    if not os.path.exists(data_file):
        raise FileNotFoundError(f"資料檔案 '{data_file}' 不存在！")
    
    df = pd.read_csv(data_file)
    
    # 過濾支出資料 (假設 CSV 欄位: Date, Type, Amount)
    expenses = df[df['Type'] == 'expense'].copy()
    expenses['Date'] = pd.to_datetime(expenses['Date'])
    
    # 聚合每月總支出
    monthly_expenses = expenses.resample('M', on='Date')['Amount'].sum().reset_index()
    monthly_expenses.columns = ['ds', 'y']  # Prophet 需要 'ds' (日期) 和 'y' (值)
    
    if len(monthly_expenses) < 3:
        raise ValueError("資料不足，至少需要 3 個月歷史資料來進行預測。")
    
    # 訓練 Prophet 模型
    model = Prophet(yearly_seasonality=True, weekly_seasonality=False, daily_seasonality=False)
    model.fit(monthly_expenses)
    
    # 預測未來 periods 個月
    future = model.make_future_dataframe(periods=periods, freq='M')
    forecast = model.predict(future)
    
    # 獲取下個月的預測值
    next_month_pred = forecast['yhat'].iloc[-1]
    next_month_date = forecast['ds'].iloc[-1].strftime('%Y-%m')
    
    print(f"預測 {next_month_date} 的總開銷約為: {next_month_pred:.2f}")
    
    # 生成圖表 (可選)
    if output_chart:
        fig = model.plot(forecast)
        plt.title('每月開銷預測 (使用 Prophet 模型)')
        plt.xlabel('日期')
        plt.ylabel('開銷金額')
        chart_file = f"expenses_forecast_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        plt.savefig(chart_file)
        print(f"圖表已儲存至: {chart_file}")
    
    return next_month_pred

# --- 主程式入口 ---
if __name__ == "__main__":
    # 自動安裝依賴
    install_dependencies()
    
    parser = argparse.ArgumentParser(description="使用 Prophet 模型預測下個月開銷。")
    parser.add_argument('--data_file', required=True, help="交易資料 CSV 檔案路徑")
    parser.add_argument('--periods', type=int, default=1, help="預測的月份數 (預設: 1)")
    parser.add_argument('--no_chart', action='store_true', help="不生成圖表")
    
    args = parser.parse_args()
    
    try:
        predict_expenses(args.data_file, args.periods, not args.no_chart)
    except Exception as e:
        print(f"錯誤: {str(e)}")
        sys.exit(1)
