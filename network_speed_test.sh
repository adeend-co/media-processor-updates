#!/bin/bash

################################################################################
#                                                                              #
#                         獨立網路測速工具 (NST) v1.0                             #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本提供一個獨立的網路測速體驗，支援多伺服器測試、日誌記錄和報告生成。           #
#                                                                              #
################################################################################

############################################
# 腳本設定
############################################
SCRIPT_VERSION="v1.0.1"
SCRIPT_UPDATE_DATE="2025-07-12"

# --- 預設值 ---
COLOR_ENABLED=true
LOG_FILE="$HOME/network_speed_log.txt"
DEFAULT_SERVERS=3  # 預設測試伺服器數量 (1-5)
DEFAULT_REPORT_DIR="$HOME/NST_Reports"

############################################
# 顏色與日誌
############################################
apply_color_settings() {
    if [ "$COLOR_ENABLED" = true ]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
        CYAN='\033[0;36m'; RESET='\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
    fi
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

############################################
# 檢查環境
############################################
check_environment() {
    local missing=()
    if ! command -v speedtest-cli >/dev/null; then missing+=("speedtest-cli"); fi
    if ! command -v jq >/dev/null; then missing+=("jq"); fi
    if ! command -v bc >/dev/null; then missing+=("bc"); fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}錯誤：缺少以下依賴：${missing[*]}${RESET}"
        echo -e "${YELLOW}請安裝：pip install speedtest-cli jq bc${RESET}"
        exit 1
    fi
    mkdir -p "$(dirname "$LOG_FILE")" "$DEFAULT_REPORT_DIR"
}

############################################
# 主測速函數 (支援單一或多伺服器)
############################################
perform_speed_test() {
    local num_servers="$1"
    local results=()
    local total_download=0 total_upload=0 total_ping=0
    local count=0

    echo -e "${YELLOW}開始測試 $num_servers 個伺服器...${RESET}"
    log_message "INFO" "開始測試 $num_servers 個伺服器。"

    for i in $(seq 1 $num_servers); do
        echo -e "${CYAN}測試伺服器 $i/${num_servers}...${RESET}"
        local output=$(speedtest-cli --secure --share --json 2>&1)
        local exit_code=$?

        if [ $exit_code -ne 0 ]; then
            echo -e "${RED}測試失敗！${RESET}"
            log_message "ERROR" "伺服器 $i 測試失敗：$output"
            continue
        fi

        local server=$(echo "$output" | jq -r '.server.host // empty')
        local ping=$(echo "$output" | jq -r '.ping // 0')
        local download=$(echo "$output" | jq -r '.download // 0' | awk '{printf "%.2f", $1 / 1000000}')
        local upload=$(echo "$output" | jq -r '.upload // 0' | awk '{printf "%.2f", $1 / 1000000}')
        local share_url=$(echo "$output" | jq -r '.share // empty')

        results+=("伺服器 $i: $server | 延遲: ${ping}ms | 下載: ${download}Mbps | 上傳: ${upload}Mbps | 連結: $share_url")

        total_ping=$(echo "$total_ping + $ping" | bc)
        total_download=$(echo "$total_download + $download" | bc)
        total_upload=$(echo "$total_upload + $upload" | bc)
        count=$((count + 1))
    done

    if [ $count -eq 0 ]; then
        echo -e "${RED}所有測試均失敗！${RESET}"
        return 1
    fi

    local avg_ping=$(echo "scale=2; $total_ping / $count" | bc)
    local avg_download=$(echo "scale=2; $total_download / $count" | bc)
    local avg_upload=$(echo "scale=2; $total_upload / $count" | bc)

    echo -e "${GREEN}測試結果 (平均值):${RESET}"
    echo -e "  平均延遲: ${avg_ping}ms"
    echo -e "  平均下載: ${avg_download}Mbps"
    echo -e "  平均上傳: ${avg_upload}Mbps"
    echo -e "\n${YELLOW}詳細結果:${RESET}"
    for res in "${results[@]}"; do echo -e "  $res"; done

    log_message "INFO" "平均結果: 延遲 ${avg_ping}ms, 下載 ${avg_download}Mbps, 上傳 ${avg_upload}Mbps"
    return 0
}

############################################
# 生成報告 (v1.1 - 使用動態報告路徑)
############################################
generate_report() {
    local num_servers="$1"
    # 使用全域變數 $REPORT_DIR，這個變數可以在 main 函數中被參數覆寫
    local report_file="$REPORT_DIR/NST_Report_$(date +%Y%m%d_%H%M%S).txt"
    
    # 確保報告目錄存在
    mkdir -p "$REPORT_DIR"
    if [ ! -w "$REPORT_DIR" ]; then
        echo -e "${RED}錯誤：報告目錄 '$REPORT_DIR' 不可寫！${RESET}"
        return 1
    fi

    echo -e "${YELLOW}生成報告中...${RESET}"
    # 使用 > 將 perform_speed_test 的輸出重定向到檔案
    # 這裡有個小技巧，用 { ... } 包圍命令，可以將區塊內所有標準輸出都重定向
    {
        echo "網路測速報告 - $(date)"
        echo "===================================="
        echo "測試伺服器數: $num_servers"
        echo ""
        # 直接調用主測速函數，它的輸出會被捕獲
        perform_speed_test "$num_servers"
    } > "$report_file"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}報告已儲存至: $report_file${RESET}"
        log_message "INFO" "報告生成: $report_file"
    else
        echo -e "${RED}報告生成失敗！${RESET}"
    fi
}

############################################
# 主選單
############################################
main_menu() {
    while true; do
        clear
        echo -e "${CYAN}====== 獨立網路測速工具 ${SCRIPT_VERSION} ======${RESET}"
        echo "1. 執行單次測速"
        echo "2. 執行多伺服器測速並生成報告"
        echo "3. 切換顏色輸出 (當前: $(if $COLOR_ENABLED; then echo '啟用'; else echo '關閉'; fi))"
        echo "0. 退出"
        read -p "請選擇: " choice

        case $choice in
            1) perform_speed_test 1; read -p "按 Enter 返回..." ;;
            2)
                read -p "輸入測試伺服器數量 (1-5): " num
                if [[ "$num" =~ ^[1-5]$ ]]; then
                    generate_report "$num"
                else
                    echo -e "${RED}無效輸入！${RESET}"
                fi
                read -p "按 Enter 返回..."
                ;;
            3)
                COLOR_ENABLED=!$COLOR_ENABLED
                apply_color_settings
                echo -e "${GREEN}顏色輸出已 $(if $COLOR_ENABLED; then echo '啟用'; else echo '關閉'; fi)${RESET}"
                read -p "按 Enter 返回..."
                ;;
            0) exit 0 ;;
            *) echo -e "${RED}無效選項${RESET}"; sleep 1 ;;
        esac
    done
}

############################################
# 主程式 (v1.1 - 支援從主框架接收參數)
############################################
main() {
    # --- ▼▼▼ 新增：參數解析邏輯 ▼▼▼ ---
    # 設定一個可以被覆寫的報告目錄變數
    REPORT_DIR="$DEFAULT_REPORT_DIR"

    # 遍歷所有傳入的參數
    for arg in "$@"; do
        case $arg in
            --color=*)
            # 從 "--color=true" 中提取 "true"
            COLOR_ENABLED="${arg#*=}"
            shift # 處理完一個參數後，將其移出參數列表
            ;;
            --report-dir=*)
            # 從 "--report-dir=/path/to/dir" 中提取路徑
            REPORT_DIR="${arg#*=}"
            shift
            ;;
        esac
    done
    # --- ▲▲▲ 修改結束 ▲▲▲ ---

    # 後續邏輯保持不變，但它們現在會使用被參數更新過的變數
    apply_color_settings
    check_environment
    log_message "INFO" "腳本啟動 (版本: $SCRIPT_VERSION, 顏色: $COLOR_ENABLED, 報告路徑: $REPORT_DIR)"
    main_menu
}

main "$@"
