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
SCRIPT_VERSION="v1.3.2"
SCRIPT_UPDATE_DATE="2025-07-12"

PYTHON_PIE_CHART_SCRIPT_PATH="$(dirname "$0")/create_pie_chart.py"

# --- 使用者設定檔與資料檔路徑 ---
CONFIG_FILE="$HOME/.pfm_rc"
DATA_DIR="$HOME/pfm_data" # 將所有資料集中存放
DATA_FILE="$DATA_DIR/transactions.csv"
BUDGET_FILE="$DATA_DIR/budget.csv"           # <<< 新增：預算檔案
RECURRING_FILE="$DATA_DIR/recurring.csv"     # <<< 新增：週期性交易檔案
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

# 主要的交易新增流程 (v2.0 - 使用快捷鍵選擇類別)
add_transaction() {
    local type="$1"
    local title="支出"
    if [ "$type" == "income" ]; then
        title="收入"
    fi
    
    # 步驟 1: 金額 (不變)
    clear
    echo -e "${CYAN}--- 新增一筆${title} (步驟 1/4) ---${RESET}"
    read -p "請輸入金額: " amount
    if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]] || ! (( $(echo "$amount > 0" | bc -l) )); then
        echo -e "${RED}錯誤：金額無效。操作已取消。${RESET}"; sleep 2
        return
    fi

    # 步驟 2: 類別 (核心修改)
    local chosen_category
    chosen_category=$(select_category "$type" "新增${title}：選擇類別")
    
    if [ -z "$chosen_category" ]; then
        echo -e "${YELLOW}操作已取消。${RESET}"; sleep 1
        return
    fi
    
    # 步驟 3: 日期 (不變)
    clear
    echo -e "${CYAN}--- 新增一筆${title} (步驟 3/4) ---${RESET}"
    echo -e "金額: ${GREEN}${amount}${RESET}"
    echo -e "類別: ${GREEN}${chosen_category}${RESET}\n"
    read -p "請輸入日期 [預設: 今天 ($(date '+%Y-%m-%d'))]: " date_input
    local parsed_date=$(date -d "${date_input:-today}" "+%Y-%m-%d" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}錯誤：無法識別的日期格式。操作已取消。${RESET}"; sleep 2
        return
    fi
    date_input="$parsed_date"

    # 步驟 4: 備註與確認 (不變)
    clear
    echo -e "${CYAN}--- 新增一筆${title} (步驟 4/4) ---${RESET}"
    echo -e "金額: ${GREEN}${amount}${RESET}"
    echo -e "類別: ${GREEN}${chosen_category}${RESET}"
    echo -e "日期: ${GREEN}${date_input}${RESET}\n"
    read -p "請輸入備註 (可選): " description

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
    sleep 2
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

# 檢查環境依賴 (v2.3 - 黃金標準版，動態整合所有安裝指令)
check_environment() {
    local missing_items=()
    local pkg_missing=()
    local python_exec=""
    
    # 預先檢查 Python
    if command -v python3 &> /dev/null; then python_exec="python3"; elif command -v python &> /dev/null; then python_exec="python"; else pkg_missing+=("python"); fi

    # 檢查所有可以透過 pkg 安裝的系統套件
    if ! command -v bc &> /dev/null; then pkg_missing+=("bc"); fi
    if ! command -v gnuplot &> /dev/null; then pkg_missing+=("gnuplot"); fi
    if ! command -v unzip &> /dev/null; then pkg_missing+=("unzip"); fi
    
    # 只有在找到 Python 時，才繼續檢查 Python 相關的依賴
    if [ -n "$python_exec" ]; then
        if ! "$python_exec" -c "import numpy" &> /dev/null; then pkg_missing+=("python-numpy"); fi
        if ! "$python_exec" -c "import PIL" &> /dev/null; then pkg_missing+=("python-pillow"); fi
        if ! "$python_exec" -c "import matplotlib" &> /dev/null; then pkg_missing+=("matplotlib"); fi
    fi
    
    local font_check_path="$PREFIX/share/fonts/TTF/NotoSansCJK-Regular.otf"
    if [ ! -f "$font_check_path" ]; then
        missing_items+=("中文字體 (Noto CJK)")
    fi
    
    # 將 pkg 缺少的套件也加入到總的 missing_items 列表中，以便統一顯示
    missing_items+=("${pkg_missing[@]}")

    if [ ${#missing_items[@]} -gt 0 ]; then
        echo -e "${RED}警告：您的環境缺少以下一或多個必需品：${RESET}"
        for item in "${missing_items[@]}"; do echo -e "${YELLOW}  - $item${RESET}"; done
        
        echo -e "\n${CYAN}--- 請依照以下【客製化安裝指南】完成設定 ---${RESET}"
        
        # --- 指南第一部分：統一安裝所有系統與核心 Python 套件 ---
        if [ ${#pkg_missing[@]} -gt 0 ]; then
            echo -e "\n${BOLD}步驟 1: 安裝核心套件${RESET}"
            echo -e "   請先執行 ${BOLD}pkg update${RESET} 更新列表，然後執行以下【單一完整指令】："
            echo -e "${GREEN}   pkg install ${pkg_missing[*]}${RESET}"
        fi
        
        # --- 指南第二部分：單獨安裝 Matplotlib 的棘手依賴 ---
        if [[ " ${missing_items[*]} " =~ " matplotlib " ]]; then
            echo -e "\n${BOLD}步驟 2: 安裝 Matplotlib 的特殊依賴${RESET}"
            echo -e "   由於相依性問題，請接著執行以下指令："
            echo -e "${GREEN}   pip install contourpy==1.0.7${RESET}"
        fi

        # --- 指南第三部分：手動安裝中文字體 ---
        if [[ " ${missing_items[*]} " =~ " 中文字體 " ]]; then
            echo -e "\n${BOLD}步驟 3: 手動安裝中文字體 (圖表顯示中文的關鍵)${RESET}"
            echo -e "   ${CYAN}a. 下載字體包:${RESET} 從瀏覽器打開以下網址，找到並下載最新的 'NotoSerifCJKtc.zip'。"
            echo -e "      ${PURPLE}https://github.com/notofonts/noto-cjk/releases${RESET}"
            echo -e "   ${CYAN}b. 解壓縮並移動檔案:${RESET} 請【依次】複製並執行以下指令："
            echo -e "      ${GREEN}cd ~/storage/downloads"
            echo -e "      ${GREEN}unzip -o *CJKtc.zip"
            echo -e "      ${GREEN}mkdir -p \$PREFIX/share/fonts/TTF/"
            echo -e "      ${GREEN}cp -f 10_NotoSerifCJKtc/OTF/TraditionalChinese/NotoSerifCJKtc-Regular.otf \$PREFIX/share/fonts/TTF/NotoSansCJK-Regular.otf"
            echo -e "      ${GREEN}cd ~ # 返回家目錄"
        fi
        
        echo -e "\n${RED}完成以上所有步驟後，請重新啟動本腳本。${RESET}"
        read -p "按 Enter 退出..."
        exit 1
    else
        echo -e "${GREEN}環境依賴檢查通過。${RESET}"
        sleep 1
    fi
}

############################################
# 核心財務功能 (完整優化版)
############################################
# (將此全新函數貼到「核心財務功能」區塊)

############################################
# 全新核心輔助函數：類別選擇器 (v2.0 - 支援快捷鍵)
############################################
select_category() {
    local type="$1" # "expense" 或 "income"
    local prompt_message="$2" # 傳入的提示訊息
    
    local categories_str
    if [ "$type" == "expense" ]; then
        categories_str="$EXPENSE_CATEGORIES"
    else
        categories_str="$INCOME_CATEGORIES"
    fi

    # 將逗號分隔的字串轉換為陣列
    IFS=',' read -r -a categories_array <<< "$categories_str"

    while true; do
        clear
        echo -e "${CYAN}--- ${prompt_message} ---${RESET}"
        echo -e "${YELLOW}請選擇類別 (使用數字/字母快捷鍵)：${RESET}"
        
        # --- 動態生成帶有快捷鍵的選項 ---
        local keys="123456789abcdefghijklmnopqrstuvwxyz"
        local key_index=0
        for i in "${!categories_array[@]}"; do
            local key="${keys:$key_index:1}"
            printf "  ${GREEN}%2s)${RESET} %s\n" "$key" "${categories_array[$i]}"
            key_index=$((key_index + 1))
        done
        
        echo "----------------------------------"
        echo -e "  ${GREEN}+) ${RESET} 手動輸入或新增類別"
        echo -e "  ${GREEN}0) ${RESET} 取消操作"
        
        read -p "請輸入您的選擇: " choice
        
        # --- 處理使用者輸入 ---
        if [[ "$choice" == "0" ]]; then
            echo "" # 返回一個空字串表示取消
            return
        elif [[ "$choice" == "+" ]]; then
            read -p "請手動輸入類別名稱: " manual_category
            if [ -n "$manual_category" ]; then
                # 檢查這個新類別是否已經在常用列表中
                if ! echo ",$categories_str," | grep -q ",$manual_category,"; then
                    prompt_add_new_category "$manual_category" "$type"
                fi
                echo "$manual_category" # 返回手動輸入的類別
                return
            else
                echo -e "${RED}類別名稱不能為空。${RESET}"; sleep 1
            fi
        else
            # 遍歷查找對應的快捷鍵
            key_index=0
            for i in "${!categories_array[@]}"; do
                local key="${keys:$key_index:1}"
                if [[ "$choice" == "$key" ]]; then
                    echo "${categories_array[$i]}" # 返回選擇的類別
                    return
                fi
                key_index=$((key_index + 1))
            done
            
            # 如果循環結束都沒找到
            echo -e "${RED}無效的快捷鍵 '$choice'。${RESET}"; sleep 1
        fi
    done
}

# (此函數是 select_category 的輔助，請確保它也在腳本中)
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
        echo -e "${GREEN}已將 '$new_category' 加入常用列表。${RESET}"; sleep 1
    fi
}
# ============================================
# === 全新功能：交易管理 (編輯與刪除) ===
# ============================================

# 刪除一筆交易紀錄
delete_transaction() {
    clear
    read -p "請輸入要刪除的交易 ID (或輸入 0 取消): " target_id

    if [[ "$target_id" == "0" ]] || ! [[ "$target_id" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}操作已取消或輸入無效。${RESET}"; sleep 2
        return
    fi

    local temp_file="$DATA_DIR/temp_transactions.csv"
    if ! grep -q "^${target_id}," "$DATA_FILE"; then
        echo -e "${RED}錯誤：找不到 ID 為 ${target_id} 的紀錄。${RESET}"; sleep 2
        return
    fi
    
    # 顯示要刪除的紀錄供使用者確認
    echo -e "\n${YELLOW}您即將刪除以下紀錄：${RESET}"
    grep "^${target_id}," "$DATA_FILE" | column -t -s,
    echo ""
    read -p "確定要永久刪除嗎？ (y/N): " confirm_delete
    
    if [[ ! "$confirm_delete" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}操作已取消。${RESET}"; sleep 2
        return
    fi

    echo -e "${YELLOW}正在刪除 ID 為 ${target_id} 的紀錄...${RESET}"
    grep -v "^${target_id}," "$DATA_FILE" > "$temp_file"

    if mv "$temp_file" "$DATA_FILE"; then
        log_message "INFO" "刪除紀錄: ID=${target_id}"
        echo -e "${GREEN}ID 為 ${target_id} 的紀錄已成功刪除。${RESET}"
    else
        log_message "ERROR" "刪除紀錄失敗: ID=${target_id}"
        echo -e "${RED}錯誤：刪除失敗！請檢查權限。${RESET}"
    fi
    sleep 2
}

# 編輯一筆交易紀錄
edit_transaction() {
    clear
    read -p "請輸入要編輯的交易 ID (或輸入 0 取消): " target_id
    if [[ "$target_id" == "0" ]] || ! [[ "$target_id" =~ ^[0-9]+$ ]]; then
        echo -e "${YELLOW}操作已取消或輸入無效。${RESET}"; sleep 2
        return
    fi

    local old_record=$(grep "^${target_id}," "$DATA_FILE")
    if [ -z "$old_record" ]; then
        echo -e "${RED}錯誤：找不到 ID 為 ${target_id} 的紀錄。${RESET}"; sleep 2
        return
    fi

    # 從CSV中解析舊的數值
    local old_date=$(echo "$old_record" | cut -d, -f3)
    local old_type=$(echo "$old_record" | cut -d, -f4)
    local old_category=$(echo "$old_record" | cut -d, -f5)
    local old_amount=$(echo "$old_record" | cut -d, -f6)
    local old_description=$(echo "$old_record" | cut -d, -f7 | sed 's/^"//;s/"$//')

    echo -e "${CYAN}--- 正在編輯 ID: $target_id ---${RESET}"
    echo -e "${YELLOW}提示：直接按 Enter 可保留原值。${RESET}"

    read -p "日期 [原: $old_date]: " new_date
    new_date=${new_date:-$old_date}
    local parsed_date=$(date -d "$new_date" "+%Y-%m-%d" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}錯誤：日期格式無效。操作已取消。${RESET}"; sleep 2
        return
    fi
    new_date="$parsed_date"
    
    read -p "類別 [原: $old_category]: " new_category
    new_category=${new_category:-$old_category}
    
    read -p "金額 [原: $old_amount]: " new_amount
    new_amount=${new_amount:-$old_amount}
    if ! [[ "$new_amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo -e "${RED}錯誤：金額無效。操作已取消。${RESET}"; sleep 2
        return
    fi

    read -p "備註 [原: $old_description]: " new_description
    new_description=${new_description:-$old_description}

    # 重新組合紀錄
    local timestamp=$(date -d "$new_date" "+%s")
    local safe_description=$(echo "$new_description" | sed 's/"/""/g')
    local new_record="$target_id,$timestamp,$new_date,$old_type,$new_category,$new_amount,\"$safe_description\""

    echo -e "\n${CYAN}--- 請確認變更 ---${RESET}"
    echo -e "${WHITE}原紀錄:${RESET} $old_record"
    echo -e "${WHITE}新紀錄:${RESET} $new_record"
    read -p "儲存變更？ (Y/n): " confirm_edit

    if [[ ! "$confirm_edit" =~ ^[Nn]$ ]]; then
        # 使用 sed 原地替換行
        sed -i "/^${target_id},/c\\${new_record}" "$DATA_FILE"
        log_message "INFO" "編輯紀錄 ID=$target_id: $new_record"
        echo -e "${GREEN}紀錄已更新！${RESET}"
    else
        echo -e "${YELLOW}操作已取消。${RESET}"
    fi
    sleep 2
}

# ============================================
# === 全新功能：預算管理系統 ===
# ============================================
# 管理每月預算 (v2.1 - 修正變數名稱並強化判斷式)
manage_budget() {
    while true; do
        clear
        echo -e "${CYAN}--- 每月預算管理 ---${RESET}"
        echo -e "目前設定的每月支出預算："
        echo "--------------------------------"
        
        # --- ▼▼▼ 核心修正處 ▼▼▼ ---
        # 1. 變數名 BUGET_FILE -> BUDGET_FILE
        # 2. 為命令替換 $(...) 加上雙引號，使其更穩健
        if [ ! -f "$BUDGET_FILE" ] || [ "$(wc -l < "$BUDGET_FILE")" -le 1 ]; then
            echo -e "${YELLOW}尚未設定任何預算。${RESET}"
        else
            tail -n +2 "$BUDGET_FILE" | column -t -s,
        fi
        # --- ▲▲▲ 修正結束 ▲▲▲ ---

        echo "--------------------------------"
        echo ""
        echo "1. 設定/修改類別預算"
        echo "2. 移除類別預算"
        echo "0. 返回主選單"
        read -p "請選擇操作: " choice

        case $choice in
            1) # 設定/修改
                local budget_cat
                budget_cat=$(select_category "expense" "管理預算：選擇支出類別")
                
                if [ -z "$budget_cat" ]; then
                    echo -e "${YELLOW}操作已取消。${RESET}"; sleep 1
                    continue
                fi

                read -p "請輸入 '$budget_cat' 的每月預算金額: " budget_amount
                if ! [[ "$budget_amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    echo -e "${RED}錯誤：金額無效。${RESET}"; sleep 2; continue
                fi

                local temp_budget_file="$DATA_DIR/temp_budget.csv"
                grep -v "^${budget_cat}," "$BUDGET_FILE" > "$temp_budget_file"
                echo "${budget_cat},${budget_amount}" >> "$temp_budget_file"
                # 使用 sort 確保標頭總是在第一行 (如果檔案變空再新增)
                (head -n 1 "$temp_budget_file" && tail -n +2 "$temp_budget_file" | sort) > "$BUDGET_FILE"
                rm -f "$temp_budget_file"

                log_message "INFO" "設定預算: $budget_cat = $budget_amount"
                echo -e "${GREEN}預算已更新！${RESET}"; sleep 1
                ;;
            2) # 移除
                read -p "請輸入要移除預算的類別名稱: " target_cat
                if [ -z "$target_cat" ]; then continue; fi
                if grep -q "^${target_cat}," "$BUDGET_FILE"; then
                    local temp_budget_file="$DATA_DIR/temp_budget.csv"
                    grep -v "^${target_cat}," "$BUDGET_FILE" > "$temp_budget_file"
                    mv "$temp_budget_file" "$BUDGET_FILE"
                    log_message "INFO" "移除預算: $target_cat"
                    echo -e "${GREEN}已移除 '$target_cat' 的預算。${RESET}"
                else
                    echo -e "${RED}錯誤：找不到該類別的預算設定。${RESET}"
                fi
                sleep 2
                ;;
            0) return ;;
            *) echo -e "${RED}無效選項。${RESET}"; sleep 1 ;;
        esac
    done
}


# ============================================
# === 全新功能：週期性交易 ===
# ============================================
# 管理週期性交易 (v2.0 - 使用快捷鍵選擇類別)
manage_recurring() {
    while true; do
        clear
        echo -e "${CYAN}--- 管理週期性交易 ---${RESET}"
        # (顯示週期性交易的部分不變...)
        echo "週期性交易會在你每次啟動腳本時自動檢查並記錄。"
        echo "--------------------------------"
        if [ $(wc -l < "$RECURRING_FILE") -le 1 ]; then
            echo -e "${YELLOW}尚未設定任何週期性交易。${RESET}"
        else
            tail -n +2 "$RECURRING_FILE" | column -t -s,
        fi
        echo "--------------------------------"
        echo ""
        echo "1. 新增一筆週期性交易"
        echo "2. 刪除一筆週期性交易"
        echo "0. 返回主選單"
        read -p "請選擇操作: " choice

        case $choice in
            1) # 新增
                clear
                echo -e "${CYAN}--- 新增週期性交易 ---${RESET}"
                read -p "請選擇類型 (1: 支出, 2: 收入): " type_choice
                local type="expense" && [[ "$type_choice" == "2" ]] && type="income"
                
                local category
                category=$(select_category "$type" "週期性交易：選擇類別")
                if [ -z "$category" ]; then
                    echo -e "${YELLOW}操作已取消。${RESET}"; sleep 1; continue
                fi

                read -p "請輸入金額: " amount
                if ! [[ "$amount" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then echo "${RED}金額無效${RESET}"; sleep 2; continue; fi
                
                read -p "請輸入備註 (如: Spotify 訂閱): " description
                
                read -p "請選擇頻率 (1: 每月, 2: 每週): " freq_choice
                local freq="monthly" && [[ "$freq_choice" == "2" ]] && freq="weekly"

                read -p "請輸入下次發生的日期 [預設: 今天]: " next_date_input
                local next_date=$(date -d "${next_date_input:-today}" "+%Y-%m-%d" 2>/dev/null)
                if [ $? -ne 0 ]; then echo -e "${RED}日期無效${RESET}"; sleep 2; continue; fi
                
                local rec_id=$(get_next_id)
                local safe_desc=$(echo "$description" | sed 's/"/""/g')
                echo "$rec_id,$type,$category,$amount,\"$safe_desc\",$freq,$next_date" >> "$RECURRING_FILE"
                log_message "INFO" "新增週期性交易: $rec_id,$type,$category,..."
                echo -e "${GREEN}週期性交易已新增！${RESET}"; sleep 2
                ;;
            2) # 刪除 (不變)
                read -p "請輸入要刪除的週期性交易 ID: " target_rec_id
                if ! [[ "$target_rec_id" =~ ^[0-9]+$ ]]; then continue; fi
                if grep -q "^${target_rec_id}," "$RECURRING_FILE"; then
                    grep -v "^${target_rec_id}," "$RECURRING_FILE" > "$DATA_DIR/temp_recurring.csv"
                    mv "$DATA_DIR/temp_recurring.csv" "$RECURRING_FILE"
                    echo -e "${GREEN}ID 為 $target_rec_id 的週期性交易已刪除。${RESET}"
                else
                    echo -e "${RED}錯誤：找不到該 ID。${RESET}"
                fi
                sleep 2
                ;;
            0) return ;;
            *) echo -e "${RED}無效選項。${RESET}"; sleep 1 ;;
        esac
    done
}

# (此函數應在 main 函數啟動時調用)
# 檢查並應用到期的週期性交易
apply_recurring_transactions() {
    local today_ts=$(date -d "today" "+%s")
    local temp_rec_file="$DATA_DIR/temp_recurring.csv"
    
    # 複製標頭
    head -n 1 "$RECURRING_FILE" > "$temp_rec_file"
    
    local needs_update=false
    # 逐行讀取（忽略標頭），檢查是否到期
    tail -n +2 "$RECURRING_FILE" | while IFS= read -r line; do
        local rec_id=$(echo "$line" | cut -d, -f1)
        local type=$(echo "$line" | cut -d, -f2)
        local category=$(echo "$line" | cut -d, -f3)
        local amount=$(echo "$line" | cut -d, -f4)
        local description=$(echo "$line" | cut -d, -f5)
        local freq=$(echo "$line" | cut -d, -f6)
        local next_date=$(echo "$line" | cut -d, -f7)
        
        local next_date_ts=$(date -d "$next_date" "+%s" 2>/dev/null)
        
        if [[ -n "$next_date_ts" && "$next_date_ts" -le "$today_ts" ]]; then
            needs_update=true
            # 已到期，新增一筆交易
            local new_trans_id=$(get_next_id)
            local new_trans_ts=$(date -d "$next_date" "+%s")
            # 描述中加入標記
            local final_desc="${description} (週期性)"
            final_desc=$(echo "$final_desc" | sed 's/"/""/g' | sed 's/^"//;s/"$//')
            
            echo "$new_trans_id,$new_trans_ts,$next_date,$type,$category,$amount,\"$final_desc\"" >> "$DATA_FILE"
            log_message "INFO" "應用週期性交易 ID=$rec_id: $new_trans_id,$next_date,$type..."
            
            # 計算下一個日期
            local interval="+1 month" && [[ "$freq" == "weekly" ]] && interval="+1 week"
            local updated_next_date=$(date -d "$next_date $interval" "+%Y-%m-%d")
            
            # 更新週期性交易紀錄
            echo "$rec_id,$type,$category,$amount,$description,$freq,$updated_next_date" >> "$temp_rec_file"
        else
            # 未到期，將原紀錄寫回
            echo "$line" >> "$temp_rec_file"
        fi
    done

    # 如果有任何更新，則用新檔案覆蓋舊檔案
    if [ "$needs_update" = true ]; then
        mv "$temp_rec_file" "$RECURRING_FILE"
        echo -e "${CYAN}已自動記錄到期的週期性交易。${RESET}"
        sleep 2
    else
        rm -f "$temp_rec_file"
    fi
}

# ============================================
# === 全新功能：進階搜尋與資料管理 ===
# ============================================

# 查詢/篩選交易紀錄
search_transactions() {
    clear
    echo -e "${CYAN}--- 進階搜尋 ---${RESET}"
    echo -e "${YELLOW}提示：所有篩選條件均可留空。${RESET}"
    
    read -p "輸入關鍵字 (搜尋備註): " keyword
    read -p "輸入開始日期 (YYYY-MM-DD): " start_date
    read -p "輸入結束日期 (YYYY-MM-DD): " end_date
    read -p "輸入類別 (可留空): " category_filter
    
    local start_ts=0
    if [ -n "$start_date" ]; then
        start_ts=$(date -d "$start_date" "+%s" 2>/dev/null || echo 0)
    fi
    
    local end_ts=9999999999 # 一個很大的未來時間戳
    if [ -n "$end_date" ]; then
        end_ts=$(date -d "$end_date 23:59:59" "+%s" 2>/dev/null || echo 9999999999)
    fi
    
    echo -e "${YELLOW}正在搜尋...${RESET}"
    
    # 使用 awk 進行多條件篩選
    local temp_results_file="$DATA_DIR/search_results.tmp"
    awk -F, -v kw="$keyword" -v st="$start_ts" -v et="$end_ts" -v cat="$category_filter" '
        BEGIN { count=0 }
        NR > 1 {
            match_kw = (kw == "" || $7 ~ kw)
            match_date = ($2 >= st && $2 <= et)
            match_cat = (cat == "" || $5 == cat)
            
            if (match_kw && match_date && match_cat) {
                print
                count++
            }
        }
        END { print "FOUND:" count > "/dev/stderr" }
    ' "$DATA_FILE" > "$temp_results_file" 2> "$DATA_DIR/search_count.tmp"
    
    local result_count=$(cat "$DATA_DIR/search_count.tmp" | cut -d: -f2)
    rm -f "$DATA_DIR/search_count.tmp"

    clear
    echo -e "${CYAN}--- 搜尋結果 (共 $result_count 筆) ---${RESET}"
    if [ "$result_count" -eq 0 ]; then
        echo -e "${YELLOW}找不到符合條件的紀錄。${RESET}"
    else
        (head -n 1 "$DATA_FILE"; cat "$temp_results_file") | column -t -s, | less -R
    fi
    rm -f "$temp_results_file"
    read -p "按 Enter 返回..."
}

# 資料管理選單 (備份/匯出)
data_management_menu() {
    while true; do
        clear
        echo -e "${CYAN}--- 資料管理 ---${RESET}"
        echo "1. 備份所有資料 (建立 .zip 壓縮檔)"
        echo "2. 匯出交易紀錄 (純 .csv 檔案)"
        echo "0. 返回主選單"
        read -p "請選擇操作: " choice

        case $choice in
            1) # 備份
                local backup_dir="$REPORT_OUTPUT_PATH/PFM_Backups"
                mkdir -p "$backup_dir"
                local backup_zip_file="$backup_dir/pfm_backup_$(date +%Y%m%d_%H%M%S).zip"
                echo -e "${YELLOW}正在建立完整備份...${RESET}"
                if zip -j "$backup_zip_file" "$DATA_FILE" "$BUDGET_FILE" "$RECURRING_FILE" "$CONFIG_FILE"; then
                    log_message "INFO" "資料已備份至 $backup_zip_file"
                    echo -e "${GREEN}備份成功！檔案位於:${RESET} ${CYAN}$backup_zip_file${RESET}"
                else
                    echo -e "${RED}錯誤：備份失敗！請確保 'zip' 命令已安裝。${RESET}"
                fi
                sleep 3
                ;;
            2) # 匯出
                local export_dir="$REPORT_OUTPUT_PATH/PFM_Exports"
                mkdir -p "$export_dir"
                local export_file="$export_dir/transactions_export_$(date +%Y%m%d_%H%M%S).csv"
                echo -e "${YELLOW}正在匯出交易紀錄...${RESET}"
                if cp "$DATA_FILE" "$export_file"; then
                    log_message "INFO" "交易紀錄已匯出至 $export_file"
                    echo -e "${GREEN}匯出成功！檔案位於:${RESET} ${CYAN}$export_file${RESET}"
                else
                    echo -e "${RED}錯誤：匯出失敗！${RESET}"
                fi
                sleep 3
                ;;
            0) return ;;
            *) echo -e "${RED}無效選項。${RESET}"; sleep 1 ;;
        esac
    done
}

# 優化後的 list_recent
list_recent() {
    clear
    echo -e "${CYAN}--- 最近 30 筆交易紀錄 ---${RESET}"
    if [ ! -s "$DATA_FILE" ] || [ $(wc -l < "$DATA_FILE") -le 1 ]; then
        echo -e "${YELLOW}沒有任何紀錄。${RESET}"
    else
        # 顯示標頭和最近30筆紀錄，並反向排序
        (head -n 1 "$DATA_FILE" && tail -n 30 "$DATA_FILE" | tac) | column -t -s, | less -R
    fi
    read -p "按 Enter 返回..."
}

# ============================================
# === 全新主選單與主程式 ===
# ============================================

main_menu() {
    while true; do
        clear
        local balance=$(calculate_balance)
        
        echo -e "${CYAN}====== ${BOLD}個人財務管理器 ${SCRIPT_VERSION}${RESET}${CYAN} ======${RESET}"
        printf "${WHITE}當前餘額: ${GREEN}${CURRENCY} %.2f${RESET}\n" "$balance"
        
        # --- 顯示本月預算追蹤 ---
        echo -e "${CYAN}--- 本月預算追蹤 (${YELLOW}$(date '+%Y-%m')${RESET}${CYAN}) ---${RESET}"
        local current_month=$(date "+%Y-%m")
        awk -F, -v month="$current_month" -v currency="$CURRENCY" '
            function color(p) {
                if (p > 100) return "\033[0;31m"; # red
                if (p > 80) return "\033[0;33m";  # yellow
                return "\033[0;32m";             # green
            }
            FNR==NR && NR > 1 { budgets[$1] = $2; next }
            FNR!=NR && $3 ~ month && $4 == "expense" { expenses[$5] += $6 }
            END {
                for (cat in budgets) {
                    spent = expenses[cat]+0; budget = budgets[cat];
                    percent = (budget > 0) ? (spent / budget * 100) : 0;
                    bar_len = 20; filled_len = int(percent / 100 * bar_len);
                    if (filled_len > bar_len) filled_len = bar_len;
                    bar = ""; for (i=0; i<filled_len; i++) bar = bar "■"; for (i=filled_len; i<bar_len; i++) bar = bar "□";
                    printf "%-10s: %s[%s]\033[0m %3.0f%% (%s%s / %s%s)\n", cat, color(percent), bar, percent, currency, spent, currency, budget;
                }
            }
        ' "$BUDGET_FILE" "$DATA_FILE"
        echo "----------------------------------"
        
        echo -e "${YELLOW}[ 交易管理 ]${RESET}"
        echo "  1. 新增一筆支出"
        echo "  2. 新增一筆收入"
        echo "  3. ${CYAN}編輯一筆交易${RESET}"
        echo "  4. ${RED}刪除一筆交易${RESET}"
        echo ""
        echo -e "${YELLOW}[ 分析與自動化 ]${RESET}"
        echo "  5. ${BLUE}進階搜尋紀錄${RESET}"
        echo "  6. ${PURPLE}生成視覺化報告${RESET}"
        echo "  7. ${GREEN}管理每月預算${RESET}"
        echo "  8. ${GREEN}管理週期性交易${RESET}"
        echo ""
        echo -e "${YELLOW}[ 系統 ]${RESET}"
        echo "  9. 資料管理 (備份/匯出)"
        echo ""
        echo "  0. ${RED}退出並返回主啟動器${RESET}"
        echo "----------------------------------"
        read -p "請選擇操作: " choice

        case $choice in
            1) add_transaction "expense" ;;
            2) add_transaction "income" ;;
            3) edit_transaction ;;
            4) delete_transaction ;;
            5) search_transactions ;;
            6) generate_visual_report ;;
            7) manage_budget ;;
            8) manage_recurring ;;
            9) data_management_menu ;;
            0)
                clear; echo -e "${GREEN}感謝使用，正在返回...${RESET}"; sleep 1; exit 0 ;;
            *)
                echo -e "${RED}無效選項 '$choice'${RESET}"; sleep 1 ;;
        esac
    done
}

main() {
    REPORT_OUTPUT_PATH="/sdcard/PFM_Reports_Default"

    for arg in "$@"; do
        case $arg in
            --color=*) COLOR_ENABLED="${arg#*=}"; shift ;;
            --output-path=*) REPORT_OUTPUT_PATH="${arg#*=}"; shift ;;
        esac
    done
    
    apply_color_settings
    
    mkdir -p "$DATA_DIR"
    # 檢查並初始化所有資料檔
    if [ ! -f "$DATA_FILE" ]; then
        echo "ID,Timestamp,Date,Type,Category,Amount,Description" > "$DATA_FILE"
        log_message "INFO" "資料檔不存在，已創建: $DATA_FILE"
    fi
    if [ ! -f "$BUDGET_FILE" ]; then
        echo "Category,Amount" > "$BUDGET_FILE"
        echo "餐飲,6000" >> "$BUDGET_FILE"; echo "交通,1500" >> "$BUDGET_FILE"
        log_message "INFO" "預算檔不存在，已創建: $BUDGET_FILE"
    fi
    if [ ! -f "$RECURRING_FILE" ]; then
        echo "RecurringID,Type,Category,Amount,Description,Frequency,NextDate" > "$RECURRING_FILE"
        log_message "INFO" "週期性交易檔不存在，已創建: $RECURRING_FILE"
    fi
    
    mkdir -p "$(dirname "$LOG_FILE")"

    log_message "INFO" "PFM 腳本啟動 (版本: $SCRIPT_VERSION)"
    
    load_config
    apply_color_settings
    
    # 啟動時自動檢查環境與應用週期性交易
    check_environment
    apply_recurring_transactions
    
    main_menu
}

# --- 執行主函數 ---
main "$@"
