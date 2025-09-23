import json
import re

# ====================================================================================
#
#                               【 您的多科目題庫筆記本 】
#
#  這裏是您唯一需要編輯的區域。請遵循以下格式來新增或修改您的題庫：
#
#  1. 新增科目:
#     - 使用 [SUBJECT: 科目名稱] 來開始一個新的科目。
#     - 範例: [SUBJECT: 化學]
#
#  2. 新增章節:
#     - 在科目下方，使用 [CHAPTER: 章節名稱] 來開始一個新的章節。
#     - 範例: [CHAPTER: 1. 原子結構與週期表]
#
#  3. 新增題型區塊:
#     - 在章節下方，使用 [SINGLE]、[MULTI] 或 [SHORT_ANSWER] 來標示題型。
#
#  4. 新增題目 (最重要！):
#     - 在題型標示下方，一行一題。
#     - 單選與多選格式: 題號<一個或多個空格>答案
#       - 範例: 1 A
#       - 範例: 101 ACDE
#     - 問答題格式: 只有題號
#       - 範例: 201
#
#  5. 註解:
#     - 以 # 開頭的行會被忽略，您可以用來做筆記。
#
# ====================================================================================

RAW_QUIZ_DATA = """
# 您可以刪除或修改這些範例資料，換上您自己的題庫。

[SUBJECT: 化學]

[CHAPTER: 1. 原子結構與週期表]

[SINGLE]
# 題號 答案
1 A
2 D
3 B

[MULTI]
101 AC
102 BDE


[CHAPTER: 2. 化學鍵結]

[SINGLE]
4 C
5 A

[SHORT_ANSWER]
201
202

# =============================================================

[SUBJECT: 生物]

[CHAPTER: 1. 細胞的構造]

[SINGLE]
1 A
2 A
3 C

[MULTI]
51 BC
52 ADE

"""

# ====================================================================================
#                         【 程式碼核心邏輯區，請勿修改 】
# ====================================================================================

def parse_quiz_notebook(raw_text):
    data = {}
    current_subject, current_chapter, current_type = None, None, None

    lines = raw_text.strip().split('\n')

    for line_num, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue

        subject_match = re.match(r'\[SUBJECT:\s*(.+)\]', line, re.IGNORECASE)
        if subject_match:
            current_subject = subject_match.group(1).strip()
            if current_subject not in data:
                data[current_subject] = {}
            current_chapter, current_type = None, None
            continue

        chapter_match = re.match(r'\[CHAPTER:\s*(.+)\]', line, re.IGNORECASE)
        if chapter_match:
            if not current_subject:
                print(f"警告: 第 {line_num} 行發現章節，但尚未定義科目。已忽略。")
                continue
            current_chapter = chapter_match.group(1).strip()
            if current_chapter not in data[current_subject]:
                data[current_subject][current_chapter] = {}
            current_type = None
            continue

        type_match = re.match(r'\[(SINGLE|MULTI|SHORT_ANSWER)\]', line, re.IGNORECASE)
        if type_match:
            if not current_subject or not current_chapter:
                print(f"警告: 第 {line_num} 行發現題型，但尚未定義科目/章節。已忽略。")
                continue
            current_type = type_match.group(1).lower()
            if current_type not in data[current_subject][current_chapter]:
                if current_type == 'short_answer':
                    data[current_subject][current_chapter][current_type] = []
                else:
                    data[current_subject][current_chapter][current_type] = {}
            continue

        if current_subject and current_chapter and current_type:
            parts = line.split(maxsplit=1)
            if current_type in ['single', 'multi']:
                if len(parts) == 2:
                    q_num, q_ans = parts
                    data[current_subject][current_chapter][current_type][q_num] = q_ans
                else:
                    print(f"警告: 第 {line_num} 行格式錯誤 (應為 '題號 答案')。已忽略。")
            elif current_type == 'short_answer':
                if len(parts) == 1:
                    q_num = parts[0]
                    data[current_subject][current_chapter][current_type].append(q_num)
                else:
                     print(f"警告: 第 {line_num} 行格式錯誤 (應只有 '題號')。已忽略。")
        else:
            print(f"警告: 第 {line_num} 行發現題目，但未歸屬任何科目/章節/題型。已忽略。")

    return data

def main():
    print("正在解析您的題庫筆記本...")
    
    question_bank = parse_quiz_notebook(RAW_QUIZ_DATA)
    
    output_filename = 'quiz_data.json'
    try:
        with open(output_filename, 'w', encoding='utf-8') as f:
            json.dump(question_bank, f, ensure_ascii=False, indent=2)
        
        print(f"\n成功！您的題庫已轉換並儲存至 '{output_filename}'")
        print("現在您可以執行 run_quiz.py 來開始測驗了。")
    except Exception as e:
        print(f"\n錯誤：無法寫入檔案。原因：{e}")

if __name__ == "__main__":
    main()
