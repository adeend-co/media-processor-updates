#!/bin/bash

################################################################################
#                                                                              #
#                         個人財務管理器 (PFM) v1.0                               #
#                                                                              #
# 著作權所有 © 2025 adeend-co。保留一切權利。                                        #
# Copyright © 2025 adeend-co. All rights reserved.                             #
#                                                                              #
# 本腳本基於 IAVPP 框架設計，專注於提供一個輕量、快速且功能強大的                          #
# 命令列財務管理體驗。                                                             #
#                                                                              #
################################################################################

############################################
# 腳本設定
############################################
SCRIPT_VERSION="v1.0.2"
SCRIPT_UPDATE_DATE="2025-06-28"

# --- 使用者設定檔與資料檔路徑 ---
CONFIG_FILE="$HOME/.pfm_rc"
DATA_DIR="$HOME/pfm_data" # 將所有資料集中存放
DATA_FILE="$DATA_DIR/transactions.csv"
LOG_FILE="$DATA_DIR/pfm_log.txt"

# --- 預設值 (若設定檔不存在) ---
DEFAULT_CURRENCY="NT$"
DEFAULT_EXPENSE_CATEGORIES="餐飲,交通,娛樂,購物,居家,醫療,學習"
DEFAULT_INCOME_CATEGORIES="薪資,獎金,投資,副業,禮金"
COLOR_ENABLED=true

############################################
# 顏色與日誌 (框架代碼)
############################################
apply_color_settings() {
    if [ "$COLOR_ENABLED" = true ]; then
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
        BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'
        WHITE='\033[0;37m'; BOLD='\033[1m'; RESET='\033[0m'
    else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; PURPLE=''; CYAN=''; WHITE=''; BOLD=''; RESET=''
    fi
}

log_message() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

############################################
# 設定檔管理 (框架代碼)
############################################
load_config() {
    CURRENCY="${DEFAULT_CURRENCY}"
    EXPENSE_CATEGORIES="${DEFAULT_EXPENSE_CATEGORIES}"
    INCOME_CATEGORIES="${DEFAULT_INCOME_CATEGORIES}"

    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
    else
        echo -e "${YELLOW}未找到設定檔，將使用預設值並在首次儲存時創建。${RESET}"
        sleep 1
    fi
    apply_color_settings
}

save_config() {
    (
        echo "# --- Personal Finance Manager (PFM) Config ---"
        echo "COLOR_ENABLED=\"${COLOR_ENABLED:-true}\""
        echo "CURRENCY=\"${CURRENCY:-$DEFAULT_CURRENCY}\""
        echo "EXPENSE_CATEGORIES=\"${EXPENSE_CATEGORIES:-$DEFAULT_EXPENSE_CATEGORIES}\""
        echo "INCOME_CATEGORIES=\"${INCOME_CATEGORIES:-$DEFAULT_INCOME_CATEGORIES}\""
    ) > "$CONFIG_FILE"
    log_message "INFO" "設定已儲存至 $CONFIG_FILE"
}

############################################
# 核心財務功能
############################################

# 獲取下一個唯一的交易ID
get_next_id() {
    if [ ! -s "$DATA_FILE" ]; then
        echo 1
    else
        # 讀取最後一行的第一個欄位(ID)，然後加1
        local last_id=$(tail -n 1 "$DATA_FILE" | cut -d, -f1)
        if [[ "$last_id" =~ ^[0-9]+$ ]]; then
            echo $((last_id + 1))
        else
            # 如果最後一行不是數字 (例如只有標頭)，則從1開始
            echo 1
        fi
    fi
}

# 計算目前餘額
calculate_balance() {
    if [ ! -s "$DATA_FILE" ]; then
        echo "0"
        return
    fi
    # 使用 awk 計算：如果類型是收入則加，是支出則減
    awk -F, 'NR > 1 { if ($4 == "income") sum += $6; else if ($4 == "expense") sum -= $6 } END { print sum+0 }' "$DATA_FILE"
}

# 顯示常用類別
display_categories() {
    local type="$1"
    local categories_str
    
    if [ "$type" == "expense" ]; then
        categories_str="$EXPENSE_CATEGORIES"
        echo -e "\n${YELLOW}--- 常用支出類別 ---${RESET}"
    else
        categories_str="$INCOME_CATEGORIES"
        echo -e "\n${YELLOW}--- 常用收入類別 ---${RESET}"
    fi

    # 將逗號分隔的字串轉換為陣列並格式化輸出
    IFS=',' read -r -a categories_array <<< "$categories_str"
    local count=0
    for category in "${categories_array[@]}"; do
        printf "  %-10s" "$category"
        count=$((count + 1))
        if (( count % 5 == 0 )); then
            echo ""
        fi
    done
    echo -e "\n----------------------"
}

# 提示使用者是否要將新類別加入常用列表
prompt_add_new_category() {
    local new_category="$1"
    local type="$2"

    read -p "類別 '$new_category' 是新的，是否將其加入常用列表？ (Y/n): " confirm
    if [[ ! "$confirm" =~ ^[Nn]$ ]]; then
        if [ "$type" == "expense" ]; then
            EXPENSE_CATEGORIES="${EXPENSE_CATEGORIES},${new_category}"
        else
            INCOME_CATEGORIES="${INCOME_CATEGORIES},${new_category}"
        fi
        save_config
        echo -e "${GREEN}已將 '$new_category' 加入常用列表。${RESET}"
    fi
}

# 主要的交易新增流程
add_transaction() {
    local type="$1" # "expense" or "income"
    local title="支出"
    if [ "$type" == "income" ]; then title="收入"; fi

    clear
    echo -e "${CYAN}--- 新增一筆${title} (按 Enter 使用預設值或跳過) ---${RESET}"

    local amount category date_input description
    
    # 1. 金額
    while true; do
        read -p "[1/4] 金額: " amount
        if [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] && (( $(echo "$amount > 0" | bc -l) )); then
            break
        else
            echo -e "${RED}錯誤：請輸入有效的正數金額。${RESET}"
        fi
    done

    # 2. 類別
    while true; do
        read -p "[2/4] 類別 (輸入 'ls' 顯示常用列表): " category
        if [ "$category" == "ls" ]; then
            display_categories "$type"
            continue
        elif [ -n "$category" ]; then
            # 檢查是否為新類別
            local categories_str
            if [ "$type" == "expense" ]; then categories_str="$EXPENSE_CATEGORIES"; else categories_str="$INCOME_CATEGORIES"; fi
            if ! echo ",$categories_str," | grep -q ",$category,"; then
                prompt_add_new_category "$category" "$type"
            fi
            break
        else
            echo -e "${RED}錯誤：類別不能為空。${RESET}"
        fi
    done

    # 3. 日期
    while true; do
        read -p "[3/4] 日期 [預設: 今天 ($(date '+%Y-%m-%d'))]: " date_input
        if [ -z "$date_input" ]; then
            date_input="today"
        fi
        
        # 使用 `date -d` 進行強大的日期解析
        local parsed_date
        parsed_date=$(date -d "$date_input" "+%Y-%m-%d" 2>/dev/null)
        if [ $? -eq 0 ]; then
            date_input="$parsed_date"
            break
        else
            echo -e "${RED}錯誤：無法識別的日期格式。請嘗試 YYYY-MM-DD, MM-DD, 或 'yesterday'。${RESET}"
        fi
    done

    # 4. 備註
    read -p "[4/4] 備註 (可選): " description

    # 確認畫面
    clear
    echo -e "${CYAN}--- 請確認紀錄 ---${RESET}"
    echo -e "${WHITE}日期:${RESET} ${GREEN}$date_input${RESET}"
    echo -e "${WHITE}類型:${RESET} ${GREEN}$title${RESET}"
    echo -e "${WHITE}類別:${RESET} ${GREEN}$category${RESET}"
    echo -e "${WHITE}金額:${RESET} ${GREEN}${CURRENCY}${amount}${RESET}"
    echo -e "${WHITE}備註:${RESET} ${GREEN}${description:-無}${RESET}"
    echo "-------------------"
    read -p "儲存紀錄？ (Y/n): " confirm_save
    
    if [[ ! "$confirm_save" =~ ^[Nn]$ ]]; then
        local id=$(get_next_id)
        local timestamp=$(date -d "$date_input" "+%s")
        # 處理備註中的逗號，用引號包起來
        local safe_description=$(echo "$description" | sed 's/"/""/g')

        local new_record="$id,$timestamp,$date_input,$type,$category,$amount,\"$safe_description\""
        echo "$new_record" >> "$DATA_FILE"
        
        log_message "INFO" "新增紀錄: $new_record"
        echo -e "\n${GREEN}紀錄已儲存！ (ID: $id)${RESET}"
    else
        echo -e "\n${YELLOW}操作已取消。${RESET}"
    fi
    sleep 1
}

# 查詢最近紀錄
list_recent() {
    clear
    echo -e "${CYAN}--- 最近 15 筆交易紀錄 ---${RESET}"
    if [ ! -s "$DATA_FILE" ] || [ $(wc -l < "$DATA_FILE") -le 1 ]; then
        echo -e "${YELLOW}沒有任何紀錄。${RESET}"
    else
        # 顯示標頭和最近15筆紀錄
        (head -n 1 "$DATA_FILE" && tail -n 15 "$DATA_FILE" | tac) | column -t -s, | less -R
    fi
    read -p "按 Enter 返回..."
}

# 生成視覺化報告
generate_visual_report() {
    if ! command -v gnuplot &> /dev/null; then
        echo -e "${RED}錯誤：找不到 'gnuplot' 命令。無法生成圖表。${RESET}"
        echo -e "${YELLOW}請先安裝它 (例如：pkg install gnuplot 或 sudo apt install gnuplot)。${RESET}"
        sleep 3
        return 1
    fi
    
    if [ ! -s "$DATA_FILE" ] || [ $(wc -l < "$DATA_FILE") -le 1 ]; then
        echo -e "${YELLOW}沒有足夠的資料來生成報告。${RESET}"
        sleep 2
        return 1
    fi

    clear
    echo -e "${CYAN}--- 生成視覺化報告 ---${RESET}"
    echo "1. 本月支出圓餅圖"
    echo "2. 今年支出長條圖"
    echo "0. 返回"
    read -p "請選擇報告類型: " choice
    
    local report_file="$DATA_DIR/report.png"
    local gnuplot_script="$DATA_DIR/plot.gp"
    local data_temp_file="$DATA_DIR/plot_data.tmp"

    case $choice in
        1)
            echo -e "${YELLOW}正在生成本月支出圓餅圖...${RESET}"
            local current_month=$(date "+%Y-%m")
            # 使用 awk 提取本月的支出數據並加總
            awk -F, -v month="$current_month" '$3 ~ month && $4 == "expense" {expenses[$5] += $6} END {for (cat in expenses) print "\"" cat "\"", expenses[cat]}' "$DATA_FILE" > "$data_temp_file"
            
            if [ ! -s "$data_temp_file" ]; then
                 echo -e "${RED}本月沒有支出紀錄。${RESET}"; sleep 2; rm -f "$data_temp_file"; return
            fi

            # 生成 gnuplot 腳本來畫圓餅圖 (這是一個簡化版，用長條圖代替)
            cat > "$gnuplot_script" << EOF
set terminal pngcairo enhanced font "sans,10" size 800,600
set output '$report_file'
set title "本月支出分佈 ($current_month)"
set style data histograms
set style fill solid 1.0
set boxwidth 0.8
set yrange [0:*]
set ylabel "金額 (${CURRENCY})"
set xtics rotate by -45
set grid y
plot '$data_temp_file' using 2:xtic(1) with boxes notitle
EOF
            ;;
        2)
            echo -e "${YELLOW}正在生成今年支出長條圖...${RESET}"
            local current_year=$(date "+%Y")
            # 提取今年的支出數據
            awk -F, -v year="$current_year" '$3 ~ year && $4 == "expense" {expenses[$5] += $6} END {for (cat in expenses) print "\"" cat "\"", expenses[cat]}' "$DATA_FILE" > "$data_temp_file"
            
            if [ ! -s "$data_temp_file" ]; then
                 echo -e "${RED}今年沒有支出紀錄。${RESET}"; sleep 2; rm -f "$data_temp_file"; return
            fi

            # 生成 gnuplot 腳本
            cat > "$gnuplot_script" << EOF
set terminal pngcairo enhanced font "sans,10" size 1024,768
set output '$report_file'
set title "今年總支出 ($current_year)"
set style data histograms
set style fill solid 1.0
set boxwidth 0.8
set yrange [0:*]
set ylabel "金額 (${CURRENCY})"
set xtics rotate by -45
set grid y
plot '$data_temp_file' using 2:xtic(1) with boxes notitle
EOF
            ;;
        0) return ;;
        *) echo -e "${RED}無效選項。${RESET}"; sleep 1; return ;;
    esac

    # 執行 gnuplot 並開啟報告
    gnuplot "$gnuplot_script"
    if [ $? -eq 0 ] && [ -f "$report_file" ]; then
        echo -e "${GREEN}報告已生成: $report_file${RESET}"
        echo -e "${CYAN}正在嘗試自動開啟...${RESET}"
        # 跨平台開啟命令
        if [[ -n "$TERMUX_VERSION" ]]; then
            termux-open "$report_file"
        elif [[ "$(uname)" == "Darwin" ]]; then
            open "$report_file"
        else
            xdg-open "$report_file"
        fi
    else
        echo -e "${RED}生成報告失敗！請檢查 gnuplot 是否已安裝及資料是否正確。${RESET}"
    fi

    # 清理臨時檔案
    rm -f "$gnuplot_script" "$data_temp_file"
    read -p "按 Enter 返回..."
}

# 檢查環境依賴
check_environment() {
    local missing_tools=()
    echo -e "${CYAN}正在檢查環境依賴...${RESET}"
    
    # 檢查 gnuplot (視覺化報告需要)
    if ! command -v gnuplot &> /dev/null; then
        missing_tools+=("gnuplot")
    fi
    # 檢查 bc (金額計算需要)
    if ! command -v bc &> /dev/null; then
        missing_tools+=("bc")
    fi
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo -e "${RED}警告：缺少以下工具，部分功能可能無法使用：${RESET}"
        for tool in "${missing_tools[@]}"; do
            echo -e "${YELLOW}  - $tool${RESET}"
        done
        echo -e "${CYAN}您可以嘗試使用套件管理器安裝 (如: pkg install ${missing_tools[*]})。${RESET}"
        sleep 3
    else
        echo -e "${GREEN}環境依賴檢查通過。${RESET}"
        sleep 1
    fi
}

############################################
# 主選單與主程式
############################################
main_menu() {
    while true; do
        # --- ▼▼▼ 在此處新增修改 ▼▼▼ ---
        # 在每次迴圈開始時強制應用顏色設定，確保顏色變數總是有效的
        apply_color_settings
        # --- ▲▲▲ 修改結束 ▲▲▲ ---

        clear
        local balance
        balance=$(calculate_balance)
        echo -e "${CYAN}====== ${BOLD}個人財務管理器 ${SCRIPT_VERSION}${RESET}${CYAN} ======${RESET}"
        printf "${WHITE}當前餘額: ${GREEN}${CURRENCY} %.2f${RESET}\n\n" "$balance"
        
        echo -e "${YELLOW}[ 主要操作 ]${RESET}"
        echo "  1. 新增一筆支出"
        echo "  2. 新增一筆收入"
        echo ""
        echo -e "${YELLOW}[ 查詢與報告 ]${RESET}"
        echo "  3. 查詢最近紀錄"
        echo "  4. ${PURPLE}生成視覺化報告 (需 gnuplot)${RESET}"
        # echo "  5. 自訂條件搜尋" # 預留功能
        echo ""
        echo "  0. ${RED}退出並返回主啟動器${RESET}"
        echo "----------------------------------"
        read -p "請選擇操作: " choice

        case $choice in
            1) add_transaction "expense" ;;
            2) add_transaction "income" ;;
            3) list_recent ;;
            4) generate_visual_report ;;
            0)
                echo -e "${GREEN}感謝使用，正在返回...${RESET}"
                sleep 1
                exit 0
                ;;
            *)
                echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1 ;;
        esac
    done
}

main() {
    # 確保資料目錄和檔案存在
    mkdir -p "$DATA_DIR"
    if [ ! -f "$DATA_FILE" ]; then
        echo "ID,Timestamp,Date,Type,Category,Amount,Description" > "$DATA_FILE"
        log_message "INFO" "資料檔不存在，已創建: $DATA_FILE"
    fi
    
    # 確保日誌目錄存在
    mkdir -p "$(dirname "$LOG_FILE")"

    log_message "INFO" "PFM 腳本啟動 (版本: $SCRIPT_VERSION)"
    
    load_config
    check_environment
    main_menu
}

# --- 執行主函數 ---
main "$@"
