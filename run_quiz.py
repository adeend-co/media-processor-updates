import json
import random
import sys

class Colors:
    def __init__(self, enabled=True):
        if enabled and sys.stdout.isatty():
            self.RED = '\033[0;31m'; self.GREEN = '\033[0;32m'; self.YELLOW = '\033[1;33m'
            self.CYAN = '\033[0;36m'; self.BOLD = '\033[1m'; self.RESET = '\033[0m'
        else:
            self.RED = self.GREEN = self.YELLOW = self.CYAN = self.BOLD = self.RESET = ''

C = Colors()

def load_quiz_data(filename='quiz_data.json'):
    try:
        with open(filename, 'r', encoding='utf-8') as f:
            return json.load(f)
    except FileNotFoundError:
        print(f"{C.RED}錯誤：找不到題庫資料檔 '{filename}'！{C.RESET}")
        print(f"{C.YELLOW}請先執行 build_quiz_data.py 來產生您的題庫。{C.RESET}")
        sys.exit(1)
    except json.JSONDecodeError:
        print(f"{C.RED}錯誤：題庫資料檔 '{filename}' 格式損毀。{C.RESET}")
        print(f"{C.YELLOW}請重新執行 build_quiz_data.py 來修復它。{C.RESET}")
        sys.exit(1)

def get_user_selections(options, prompt):
    while True:
        choice_str = input(prompt).strip().lower()
        if not choice_str or choice_str == 'all':
            return list(range(1, len(options) + 1))
        
        try:
            selected_indices = [int(i.strip()) for i in choice_str.split(',')]
            if all(1 <= i <= len(options) for i in selected_indices):
                return selected_indices
            else:
                print(f"{C.RED}輸入包含無效的編號，請重新輸入。{C.RESET}")
        except ValueError:
            print(f"{C.RED}輸入格式錯誤，請輸入數字編號，並用逗號分隔。{C.RESET}")

def build_candidate_pool(quiz_data, selected_subjects, selected_chapters_map, selected_types):
    candidate_pool = []
    type_map = {1: 'single', 2: 'multi', 3: 'short_answer'}
    active_types = {type_map[i] for i in selected_types}

    for subject in selected_subjects:
        for chapter in selected_chapters_map.get(subject, []):
            chapter_data = quiz_data.get(subject, {}).get(chapter, {})
            for q_type in active_types:
                questions = chapter_data.get(q_type, {})
                if q_type == 'short_answer':
                    for number in questions:
                        candidate_pool.append({'subject': subject, 'chapter': chapter, 'type': q_type, 'number': number, 'answer': None})
                else:
                    for number, answer in questions.items():
                        candidate_pool.append({'subject': subject, 'chapter': chapter, 'type': q_type, 'number': number, 'answer': answer})
    return candidate_pool

def check_multi_choice_answer(user_answer, correct_answer):
    return sorted(user_answer.strip().upper()) == sorted(correct_answer.strip().upper())

def run_quiz(quiz_list):
    random.shuffle(quiz_list)
    score = 0
    wrong_answers = []
    
    print("\n" + "="*20)
    print(f"{C.BOLD}測驗開始！共 {len(quiz_list)} 題。{C.RESET}")
    print("="*20 + "\n")

    for i, q in enumerate(quiz_list, 1):
        type_name = {"single": "單選題", "multi": "多選題", "short_answer": "問答題"}[q['type']]
        print(f"{C.BOLD}第 {i}/{len(quiz_list)} 題 - [{q['subject']} - {q['chapter']}]{C.RESET}")
        
        if q['type'] == 'short_answer':
            input(f"{C.CYAN}【{type_name}】請思考第 {q['number']} 題 (完成後請按 Enter 鍵繼續...){C.RESET}")
            continue

        user_answer = input(f"{C.CYAN}【{type_name}】請回答第 {q['number']} 題： {C.RESET}").strip()
        
        correct = False
        if q['type'] == 'single':
            correct = user_answer.upper() == q['answer'].upper()
        elif q['type'] == 'multi':
            correct = check_multi_choice_answer(user_answer, q['answer'])
        
        if correct:
            score += 1
            print(f"{C.GREEN}答對了！{C.RESET}\n")
        else:
            wrong_answers.append({**q, 'user_answer': user_answer})
            print(f"{C.RED}答錯了！正確答案是：{q['answer']}{C.RESET}\n")
            
    return score, wrong_answers

def main():
    quiz_data = load_quiz_data()
    if not quiz_data:
        print(f"{C.RED}題庫為空，無法開始測驗。{C.RESET}")
        return

    print(f"\n{C.BOLD}歡迎使用您的個人化學習系統！{C.RESET}")
    
    # 步驟 1: 選擇科目
    subjects = list(quiz_data.keys())
    print("\n偵測到以下科目，請選擇您想練習的範圍：")
    for i, subject in enumerate(subjects, 1):
        print(f"  {i}. {subject}")
    subject_indices = get_user_selections(subjects, f"\n請輸入編號 (可多選, 如 1,2), 或輸入 'all' 選擇全部： ")
    selected_subjects = [subjects[i-1] for i in subject_indices]

    # 步驟 2: 選擇章節
    selected_chapters_map = {}
    for subject in selected_subjects:
        chapters = list(quiz_data[subject].keys())
        print(f"\n--- 現在設定【{subject}】的範圍 ---")
        for i, chapter in enumerate(chapters, 1):
            print(f"  {i}. {chapter}")
        chapter_indices = get_user_selections(chapters, f"\n請選擇章節編號 (可多選, 如 1,2), 或輸入 'all' 選擇全部章節： ")
        selected_chapters_map[subject] = [chapters[i-1] for i in chapter_indices]
        
    # 步驟 3: 選擇題型
    print("\n--- 最後，請選擇要練習的題型 ---")
    types = ["單選題", "多選題", "問答題"]
    for i, t in enumerate(types, 1):
        print(f"  {i}. {t}")
    selected_types = get_user_selections(types, f"\n請輸入題型編號 (可多選, 如 1,2), 或輸入 'all' 選擇全部題型： ")

    # 步驟 4: 建立候選題庫池並決定題數
    candidate_pool = build_candidate_pool(quiz_data, selected_subjects, selected_chapters_map, selected_types)
    if not candidate_pool:
        print(f"\n{C.YELLOW}根據您的選擇，找不到任何對應的題目。程式結束。{C.RESET}")
        return
        
    print(f"\n篩選完成！根據您的選擇，候選題庫池中共有 {C.BOLD}{len(candidate_pool)}{C.RESET} 道題目。")
    
    num_to_ask_str = input(f"請問您想從中隨機抽取幾題進行測驗？ (直接按 Enter 表示全部練習): ").strip()
    
    if not num_to_ask_str:
        num_to_ask = len(candidate_pool)
    else:
        try:
            num_to_ask = int(num_to_ask_str)
            if not 0 < num_to_ask <= len(candidate_pool):
                print(f"{C.YELLOW}輸入數字超出範圍，將自動設為最大值 {len(candidate_pool)} 題。{C.RESET}")
                num_to_ask = len(candidate_pool)
        except ValueError:
            print(f"{C.YELLOW}輸入無效，將預設為練習全部 {len(candidate_pool)} 題。{C.RESET}")
            num_to_ask = len(candidate_pool)

    final_quiz_list = random.sample(candidate_pool, num_to_ask)

    # 開始測驗
    score, wrong_answers = run_quiz(final_quiz_list)
    
    # 顯示結果報告
    num_answered = len([q for q in final_quiz_list if q['type'] != 'short_answer'])
    print("\n" + "="*20)
    print(f"{C.BOLD}測驗結束！成績報告{C.RESET}")
    print("="*20)
    if num_answered > 0:
        percentage = (score / num_answered) * 100
        print(f"\n{C.CYAN}您的得分: {score} / {num_answered} (答對率: {percentage:.1f}%){C.RESET}")
    else:
        print(f"\n{C.CYAN}您本次練習的皆為問答題，無計分項目。{C.RESET}")

    if wrong_answers:
        print(f"\n{C.YELLOW}--- 錯題回顧 ---{C.RESET}")
        for wrong in wrong_answers:
            print(f"  - [{wrong['subject']} - {wrong['chapter']}]")
            print(f"    - 題號: {wrong['number']}")
            print(f"    - {C.RED}您的答案: {wrong['user_answer']}{C.RESET}")
            print(f"    - {C.GREEN}正確答案: {wrong['answer']}{C.RESET}")
    print("\n感謝使用！\n")

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n\n{C.YELLOW}使用者中斷操作。程式結束。{C.RESET}")
        sys.exit(0)
