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
SCRIPT_VERSION="v1.2.3"
SCRIPT_UPDATE_DATE="2025-06-29"

PYTHON_PIE_CHART_SCRIPT_PATH="$(dirname "$0")/create_pie_chart.py"

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

# 生成視覺化報告 (v1.6 - 使用 Python 繪製真實圓餅圖)
generate_visual_report() {
    local REPORT_DIR="$REPORT_OUTPUT_PATH"
    mkdir -p "$REPORT_DIR"
    if [ ! -d "$REPORT_DIR" ] || [ ! -w "$REPORT_DIR" ]; then
        echo -e "${RED}錯誤：無法創建或寫入報告目錄 '$REPORT_DIR'！${RESET}"; sleep 3
        return 1
    fi

    local report_file_base="$REPORT_DIR/PFM_Report_$(date +%Y%m%d_%H%M%S)"
    local raw_data_file="$REPORT_DIR/plot_data_raw.csv" # 改為csv後綴
    
    clear
    echo -e "${CYAN}--- 生成視覺化報告 ---${RESET}"
    echo "1. 本月支出圓餅圖 (由 Python 生成)"
    echo "2. 今年總支出長條圖 (由 gnuplot 生成)"
    echo "0. 返回"
    read -p "請選擇報告類型: " choice
    
    case $choice in
        1) # 使用 Python 繪製圓餅圖
            local python_exec=""
            if command -v python3 &> /dev/null; then python_exec="python3"; elif command -v python &> /dev/null; then python_exec="python"; fi

            if [ -z "$python_exec" ] || [ ! -f "$PYTHON_PIE_CHART_SCRIPT_PATH" ]; then
                echo -e "${RED}錯誤：找不到 Python 或 'create_pie_chart.py' 腳本！${RESET}"; sleep 3; return 1
            fi
            if ! "$python_exec" -c "import matplotlib" &> /dev/null; then
                 echo -e "${RED}錯誤：缺少 'matplotlib' 庫！${RESET}"; echo -e "${YELLOW}請執行 'pip install matplotlib'。${RESET}"; sleep 3; return 1
            fi

            local current_month=$(date "+%Y-%m")
            local title_text="本月支出分佈 ($current_month)"
            local report_file="${report_file_base}_monthly_pie.png"

            echo -e "${YELLOW}正在準備資料...${RESET}"
            # awk 的輸出格式改為 "Label,Value"，以符合CSV標準
            awk -F, -v month="$current_month" '
                BEGIN {OFS=","}
                $3 ~ month && $4 == "expense" {
                    expenses[$5] += $6
                }
                END {
                    for (cat in expenses) {
                        # 處理標籤中的引號
                        gsub(/"/, "\"\"", cat);
                        print "\"" cat "\"", expenses[cat]
                    }
                }
            ' "$DATA_FILE" > "$raw_data_file"

            if [ ! -s "$raw_data_file" ]; then
                echo -e "${RED}本月沒有支出紀錄。${RESET}"; sleep 2; rm -f "$raw_data_file"; return
            fi

            echo -e "${YELLOW}正在呼叫 Python 腳本生成圓餅圖...${RESET}"
            local py_cmd_output
            py_cmd_output=$("$python_exec" "$PYTHON_PIE_CHART_SCRIPT_PATH" --input "$raw_data_file" --output "$report_file" --title "$title_text")
            
            if [ $? -eq 0 ] && [ -f "$report_file" ]; then
                echo -e "${GREEN}${py_cmd_output}${RESET}"
                echo -e "${CYAN}正在嘗試自動開啟...${RESET}"
                if [[ -n "$TERMUX_VERSION" ]]; then termux-open "$report_file"; else xdg-open "$report_file"; fi
            else
                echo -e "${RED}Python 腳本執行失敗！請查看錯誤訊息。${RESET}"
            fi
            ;;

        2) # 使用 gnuplot 繪製長條圖 (保留原有功能)
            if ! command -v gnuplot &> /dev/null; then echo -e "${RED}錯誤：找不到 'gnuplot'。${RESET}"; sleep 3; return 1; fi
            local final_data_file="$REPORT_DIR/plot_data_final.tmp"
            local gnuplot_script="$REPORT_DIR/plot.gp"
            
            local current_year=$(date "+%Y")
            local title_text="今年總支出 ($current_year)"
            local report_file="${report_file_base}_yearly_expense.png"

            echo -e "${YELLOW}正在準備資料...${RESET}"
            awk -F, -v year="$current_year" '$3 ~ year && $4 == "expense" {expenses[$5] += $6} END {for (cat in expenses) print cat, expenses[cat]}' "$DATA_FILE" > "$raw_data_file"

            if [ ! -s "$raw_data_file" ]; then echo -e "${RED}今年沒有支出紀錄。${RESET}"; sleep 2; rm -f "$raw_data_file"; return; fi
            
            > "$final_data_file"
            while IFS= read -r line; do
                local label=$(echo "$line" | awk '{print $1}'); local value=$(echo "$line" | awk '{print $2}'); local label_len=$(echo "$label" | awk '{print length($0)}'); local new_label
                if [ "$label_len" -gt 6 ]; then new_label=$(echo "$label" | awk '{ half = int(length($0)/2); print substr($0, 1, half) "\\n" substr($0, half+1); }'); else new_label="$label"; fi
                echo "\"$new_label\" $value" >> "$final_data_file"
            done < "$raw_data_file"
            
            local category_count=$(wc -l < "$final_data_file"); local rotate_option=""; local dynamic_width=$((400 + category_count * 80)); if [ "$dynamic_width" -gt 2048 ]; then dynamic_width=2048; fi; if [ "$category_count" -gt 4 ]; then rotate_option="set xtics rotate by -45"; fi

            echo -e "${YELLOW}正在生成長條圖...${RESET}"
            cat > "$gnuplot_script" <<-EOF
set terminal pngcairo enhanced font "sans,10" size ${dynamic_width},600; set output '$report_file'; set title "$title_text"; set style data histograms; set style fill solid 1.0 border -1; set boxwidth 0.8; set yrange [0:*]; set ylabel "金額 (${CURRENCY})"; $rotate_option; set grid y; set tics scale 0; set bmargin at screen 0.15; plot '$final_data_file' using 2:xtic(1) with boxes notitle
EOF
            gnuplot "$gnuplot_script"; if [ $? -eq 0 ] && [ -f "$report_file" ]; then echo -e "${GREEN}報告已生成: $report_file${RESET}"; echo -e "${CYAN}正在嘗試自動開啟...${RESET}"; if [[ -n "$TERMUX_VERSION" ]]; then termux-open "$report_file"; else xdg-open "$report_file"; fi; else echo -e "${RED}生成報告失敗！${RESET}"; fi
            rm -f "$final_data_file" "$gnuplot_script"
            ;;

        0) return ;;
        *) echo -e "${RED}無效選項。${RESET}"; sleep 1; return ;;
    esac

    rm -f "$raw_data_file"
    read -p "按 Enter 返回..."
}

# 檢查環境依賴 (v1.5 - 修正 matplotlib 套件名稱)
check_environment() {
    local pkg_missing=()
    local python_exec=""
    echo -e "${CYAN}正在檢查環境依賴...${RESET}"
    
    # 檢查系統套件: bc (用於金額計算)
    if ! command -v bc &> /dev/null; then
        pkg_missing+=("bc")
    fi
    
    # 檢查系統套件: gnuplot (用於長條圖)
    if ! command -v gnuplot &> /dev/null; then
        pkg_missing+=("gnuplot")
    fi
    
    # 檢查 Python 主程式
    if command -v python3 &> /dev/null; then
        python_exec="python3"
    elif command -v python &> /dev/null; then
        python_exec="python"
    else
        pkg_missing+=("python")
    fi

    # 只有在找到 Python 的情況下，才檢查 matplotlib 的存在
    if [ -n "$python_exec" ]; then
        if ! "$python_exec" -c "import matplotlib" &> /dev/null; then
            # --- ▼▼▼ 核心修改：使用正確的套件名稱 'matplotlib' ▼▼▼ ---
            pkg_missing+=("matplotlib")
        fi
    fi

    if [ ${#pkg_missing[@]} -gt 0 ]; then
        echo -e "${RED}警告：缺少以下核心套件，部分功能可能無法使用：${RESET}"
        
        for item in "${pkg_missing[@]}"; do
            echo -e "${YELLOW}  - $item${RESET}"
        done

        echo -e "\n${CYAN}您可以執行以下【單一完整指令】來安裝所有必需品：${RESET}"

        # 生成一個統一的、適用於 Termux 的安裝指令
        echo -e "${GREEN}  pkg install ${pkg_missing[*]}${RESET}"
        
        if [[ " ${pkg_missing[*]} " =~ " matplotlib " ]]; then
            echo -e "\n${YELLOW}提示：'matplotlib' 套件較大，且會安裝大量依賴，請耐心等候。${RESET}"
        fi
        
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
