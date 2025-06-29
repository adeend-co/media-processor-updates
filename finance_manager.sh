#!/bin/bash

################################################################################
#                                                                              #
#                         個人財務管理器 (PFM) v1.1                               #
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
SCRIPT_VERSION="v1.1.6"
SCRIPT_UPDATE_DATE="2025-06-29"

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
# 顏色與日誌 (v1.2 - 使用正確的 ANSI-C Quoting)
apply_color_settings() {
    if [ "$COLOR_ENABLED" = true ]; then
        export RED=$'\033[0;31m'; export GREEN=$'\033[0;32m'; export YELLOW=$'\033[0;33m'
        export BLUE=$'\033[0;34m'; export PURPLE=$'\033[0;35m'; export CYAN=$'\033[0;36m'
        export WHITE=$'\033[0;37m'; export BOLD=$'\033[1m'; export RESET=$'\033[0m'
    else
        export RED=''; export GREEN=''; export YELLOW=''; export BLUE=''; export PURPLE=''; export CYAN=''; export WHITE=''; export BOLD=''; export RESET=''
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

# 主要的交易新增流程 (v1.3 - 模仿主腳本重繪邏輯，移除tput)
add_transaction() {
    local type="$1"
    local title="支出"
    local categories_str="$EXPENSE_CATEGORIES"
    if [ "$type" == "income" ]; then
        title="收入"
        categories_str="$INCOME_CATEGORIES"
    fi

    # --- ▼▼▼ 核心修改：完全重構輸入流程 ▼▼▼ ---
    # 每個輸入都是一個獨立的步驟，出錯就返回
    
    # 步驟 1: 金額
    clear
    echo -e "${CYAN}--- 新增一筆${title} (步驟 1/4) ---${RESET}"
    read -p "請輸入金額: " amount
    if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! (( $(echo "$amount > 0" | bc -l) )); then
        echo -e "${RED}錯誤：金額無效。操作已取消。${RESET}"
        sleep 2
        return # 出錯即返回，由主選單重繪
    fi

    # 步驟 2: 類別
    local chosen_category=""
    while true; do
        clear
        echo -e "${CYAN}--- 新增一筆${title} (步驟 2/4) ---${RESET}"
        echo -e "金額: ${GREEN}${amount}${RESET}\n"
        echo -e "${YELLOW}請選擇類別：${RESET}"
        IFS=',' read -r -a categories_array <<< "$categories_str"
        local index=1
        for cat in "${categories_array[@]}"; do
            echo -e "  $index) $cat"
            index=$((index + 1))
        done
        echo "-------------------"
        echo -e "  a) 新增自訂類別..."
        echo -e "  0) 取消操作"
        
        read -p "請輸入選項: " cat_choice
        
        if [[ "$cat_choice" =~ ^[0-9]+$ ]] && [ "$cat_choice" -gt 0 ] && [ "$cat_choice" -le "${#categories_array[@]}" ]; then
            chosen_category="${categories_array[$((cat_choice - 1))]}"
            break
        elif [[ "$cat_choice" == "a" ]]; then
            read -p "請輸入新的類別名稱: " new_category_name
            if [ -n "$new_category_name" ]; then
                if echo ",$categories_str," | grep -q ",$new_category_name,"; then
                    echo -e "${YELLOW}警告：類別 '$new_category_name' 已存在。${RESET}"; sleep 2
                    continue
                fi
                chosen_category="$new_category_name"
                if [ "$type" == "expense" ]; then EXPENSE_CATEGORIES="${EXPENSE_CATEGORIES},${new_category_name}"; else INCOME_CATEGORIES="${INCOME_CATEGORIES},${new_category_name}"; fi
                save_config
                echo -e "${GREEN}已新增並選擇 '$new_category_name'。${RESET}"; sleep 1
                break
            else
                echo -e "${RED}類別名稱不能為空。${RESET}"; sleep 1
            fi
        elif [ "$cat_choice" == "0" ]; then
            echo -e "${YELLOW}操作已取消。${RESET}"; sleep 1
            return # 取消操作，返回主選單
        else
            echo -e "${RED}無效選項。${RESET}"; sleep 1
        fi
    done

    # 步驟 3: 日期
    clear
    echo -e "${CYAN}--- 新增一筆${title} (步驟 3/4) ---${RESET}"
    echo -e "金額: ${GREEN}${amount}${RESET}"
    echo -e "類別: ${GREEN}${chosen_category}${RESET}\n"
    read -p "請輸入日期 [預設: 今天 ($(date '+%Y-%m-%d'))]: " date_input
    if [ -z "$date_input" ]; then date_input="today"; fi
    local parsed_date
    parsed_date=$(date -d "$date_input" "+%Y-%m-%d" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}錯誤：無法識別的日期格式。操作已取消。${RESET}"; sleep 2
        return # 出錯即返回
    fi
    date_input="$parsed_date"

    # 步驟 4: 備註
    clear
    echo -e "${CYAN}--- 新增一筆${title} (步驟 4/4) ---${RESET}"
    echo -e "金額: ${GREEN}${amount}${RESET}"
    echo -e "類別: ${GREEN}${chosen_category}${RESET}"
    echo -e "日期: ${GREEN}${date_input}${RESET}\n"
    read -p "請輸入備註 (可選): " description

    # 確認畫面
    clear
    echo -e "${CYAN}--- 請確認紀錄 ---${RESET}"
    echo -e "${WHITE}日期:${RESET} ${GREEN}$date_input${RESET}"
    echo -e "${WHITE}類型:${RESET} ${GREEN}$title${RESET}"
    echo -e "${WHITE}類別:${RESET} ${GREEN}$chosen_category${RESET}"
    echo -e "${WHITE}金額:${RESET} ${GREEN}${CURRENCY}${amount}${RESET}"
    echo -e "${WHITE}備註:${RESET} ${GREEN}${description:-無}${RESET}"
    echo "-------------------"
    read -p "儲存紀錄？ (Y/n): " confirm_save
    
    if [[ ! "$confirm_save" =~ ^[Nn]$ ]]; then
        local id=$(get_next_id)
        local timestamp=$(date -d "$date_input" "+%s")
        local safe_description=$(echo "$description" | sed 's/"/""/g')
        local new_record="$id,$timestamp,$date_input,$type,$chosen_category,$amount,\"$safe_description\""
        echo "$new_record" >> "$DATA_FILE"
        log_message "INFO" "新增紀錄: $new_record"
        echo -e "\n${GREEN}紀錄已儲存！ (ID: $id)${RESET}"
    else
        echo -e "\n${YELLOW}操作已取消。${RESET}"
    fi
    sleep 2 # 增加延遲，讓使用者看到儲存結果
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

# 生成視覺化報告 (v1.3 - 智慧判斷是否旋轉X軸標籤)
generate_visual_report() {
    if ! command -v gnuplot &> /dev/null; then
        echo -e "${RED}錯誤：找不到 'gnuplot' 命令。無法生成圖表。${RESET}"; sleep 3
        return 1
    fi
    
    if [ ! -s "$DATA_FILE" ] || [ $(wc -l < "$DATA_FILE") -le 1 ]; then
        echo -e "${YELLOW}沒有足夠的資料來生成報告。${RESET}"; sleep 2
        return 1
    fi

    local REPORT_DIR="$REPORT_OUTPUT_PATH"
    mkdir -p "$REPORT_DIR"
    if [ ! -d "$REPORT_DIR" ] || [ ! -w "$REPORT_DIR" ]; then
        echo -e "${RED}錯誤：無法創建或寫入報告目錄 '$REPORT_DIR'！${RESET}"
        echo -e "${YELLOW}請檢查 Termux 儲存權限或主腳本的下載路徑設定。${RESET}"
        sleep 3
        return 1
    fi

    local report_file_base="$REPORT_DIR/PFM_Report_$(date +%Y%m%d_%H%M%S)"
    local gnuplot_script="$REPORT_DIR/plot.gp"
    local data_temp_file="$REPORT_DIR/plot_data.tmp"
    
    clear
    echo -e "${CYAN}--- 生成視覺化報告 ---${RESET}"
    echo "1. 本月支出圓餅圖 (長條圖模擬)"
    echo "2. 今年支出長條圖"
    echo "0. 返回"
    read -p "請選擇報告類型: " choice
    
    local report_file=""
    local title_text=""
    local data_source_cmd=""
    local category_count=0

    case $choice in
        1)
            title_text="本月支出分佈 ($(date "+%Y-%m"))"
            report_file="${report_file_base}_monthly_expense.png"
            data_source_cmd="awk -F, -v month=\"$(date "+%Y-%m")\" '\$3 ~ month && \$4 == \"expense\" {expenses[\$5] += \$6} END {for (cat in expenses) print \"\\\"\" cat \"\\\"\", expenses[cat]}' \"$DATA_FILE\" > \"$data_temp_file\""
            ;;
        2)
            title_text="今年總支出 ($(date "+%Y"))"
            report_file="${report_file_base}_yearly_expense.png"
            data_source_cmd="awk -F, -v year=\"$(date "+%Y")\" '\$3 ~ year && \$4 == \"expense\" {expenses[\$5] += \$6} END {for (cat in expenses) print \"\\\"\" cat \"\\\"\", expenses[cat]}' \"$DATA_FILE\" > \"$data_temp_file\""
            ;;
        0) return ;;
        *) echo -e "${RED}無效選項。${RESET}"; sleep 1; return ;;
    esac

    echo -e "${YELLOW}正在準備資料...${RESET}"
    eval "$data_source_cmd" # 執行 awk 命令生成資料檔
    
    if [ ! -s "$data_temp_file" ]; then
        echo -e "${RED}查詢範圍內沒有支出紀錄。${RESET}"; sleep 2; rm -f "$data_temp_file"; return
    fi

    # --- ▼▼▼ 核心修改：智慧判斷是否需要旋轉標籤 ▼▼▼ ---
    category_count=$(wc -l < "$data_temp_file")
    local rotate_option=""
    if [ "$category_count" -gt 4 ]; then
        # 如果類別超過4個，就加入旋轉選項
        rotate_option="set xtics rotate by -45"
        log_message "INFO" "類別數量 ($category_count) > 4，啟用X軸標籤旋轉。"
    else
        log_message "INFO" "類別數量 ($category_count) <= 4，禁用X軸標籤旋轉。"
    fi
    # --- ▲▲▲ 修改結束 ▲▲▲ ---

    echo -e "${YELLOW}正在生成圖表...${RESET}"
    # 生成 gnuplot 腳本
    cat > "$gnuplot_script" <<-EOF
set terminal pngcairo enhanced font "sans,10" size 1024,768
set output '$report_file'
set title "$title_text"
set style data histograms
set style fill solid 1.0 border -1
set boxwidth 0.8
set yrange [0:*]
set ylabel "金額 (${CURRENCY})"
$rotate_option  # 這裡會根據上面的判斷結果，插入旋轉指令或一個空行
set grid y
set tics scale 0
plot '$data_temp_file' using 2:xtic(1) with boxes notitle
EOF

    gnuplot "$gnuplot_script"
    if [ $? -eq 0 ] && [ -f "$report_file" ]; then
        echo -e "${GREEN}報告已生成: $report_file${RESET}"
        echo -e "${CYAN}正在嘗試自動開啟...${RESET}"
        if [[ -n "$TERMUX_VERSION" ]]; then termux-open "$report_file"; elif [[ "$(uname)" == "Darwin" ]]; then open "$report_file"; else xdg-open "$report_file"; fi
    else
        echo -e "${RED}生成報告失敗！請檢查 gnuplot 是否已安裝及資料是否正確。${RESET}"
    fi

    rm -f "$gnuplot_script" "$data_temp_file"
    read -p "按 Enter 返回..."
}

# 檢查環境依賴 (v1.1 - 新增 tput 檢查)
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
        echo -e "${RED}警告：缺少以下工具，部分功能或UI體驗可能受影響：${RESET}"
        for tool in "${missing_tools[@]}"; do
            local reason=""
            if [ "$tool" == "ncurses-utils" ]; then reason="(提供 tput 命令，用於優化輸入介面)"; fi
            if [ "$tool" == "gnuplot" ]; then reason="(用於生成視覺化圖表)"; fi
            if [ "$tool" == "bc" ]; then reason="(用於精確計算金額)"; fi
            echo -e "${YELLOW}  - $tool ${CYAN}${reason}${RESET}"
        done
        echo -e "${CYAN}您可以嘗試使用套件管理器安裝。例如在 Termux 中執行:${RESET}"
        echo -e "${GREEN}  pkg install ${missing_tools[*]}${RESET}"
        read -p "按 Enter 繼續..."
    else
        echo -e "${GREEN}環境依賴檢查通過。${RESET}"
        sleep 1
    fi
}

############################################
# 主選單與主程式 (v1.4 - 最終顏色穩定版)
############################################
main_menu() {
    while true; do
        clear
        local balance
        balance=$(calculate_balance)
        
        # 直接使用全域的顏色變數，無需在迴圈內做任何處理
        echo -e "${CYAN}====== ${BOLD}個人財務管理器 ${SCRIPT_VERSION}${RESET}${CYAN} ======${RESET}"
        printf "${WHITE}當前餘額: ${GREEN}${CURRENCY} %.2f${RESET}\n\n" "$balance"
        
        echo -e "${YELLOW}[ 主要操作 ]${RESET}"
        echo "  1. 新增一筆支出"
        echo "  2. 新增一筆收入"
        echo ""
        echo -e "${YELLOW}[ 查詢與報告 ]${RESET}"
        echo "  3. 查詢最近紀錄"
        echo "  4. ${PURPLE}生成視覺化報告 (需 gnuplot)${RESET}"
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
                # 清理螢幕再退出，介面更乾淨
                clear
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
    # --- ▼▼▼ 在此處新增修改 ▼▼▼ ---
    # 為報告輸出路徑設定一個預設值（當獨立運行時使用）
    REPORT_OUTPUT_PATH="/sdcard/PFM_Reports_Default"

    # 解析從主腳本傳來的參數
    for arg in "$@"; do
        case $arg in
            --color=*)
            COLOR_ENABLED="${arg#*=}"
            shift
            ;;
            --output-path=*)
            # 如果收到了主腳本傳來的路徑，就使用它
            REPORT_OUTPUT_PATH="${arg#*=}"
            shift
            ;;
        esac
    done
    # --- ▲▲▲ 修改結束 ▲▲▲ ---
    
    apply_color_settings
    
    mkdir -p "$DATA_DIR"
    if [ ! -f "$DATA_FILE" ]; then
        echo "ID,Timestamp,Date,Type,Category,Amount,Description" > "$DATA_FILE"
        log_message "INFO" "資料檔不存在，已創建: $DATA_FILE"
    fi
    
    mkdir -p "$(dirname "$LOG_FILE")"

    log_message "INFO" "PFM 腳本啟動 (版本: $SCRIPT_VERSION, 顏色: $COLOR_ENABLED, 報告路徑: $REPORT_OUTPUT_PATH)"
    
    load_config
    apply_color_settings
    
    check_environment
    main_menu
}

# --- 執行主函數 ---
main "$@"
