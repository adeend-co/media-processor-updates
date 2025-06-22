# 整合式影音處理平台（IAVPP）

腳本下載流程：
-
運行： 
```
git clone https://github.com/adeend-co/media-processor-updates.git
```

安裝流程:
-

1. 請先確保 Termux 擁有手機儲存空間之位置權限，請先運行：
    ```
    termux-setup-storage
    ```
2. 請先安裝 git，運行：
    ```
    pkg install git -y
    ```
3. 請先轉移到 media-processor-updates 資料夾裡面，運行：
    ```
    cd media-processor-updates
    ```
4. 給該腳本運行權限，運行：
    ```
    chmod +x media_processor.sh
    chmod +x estimate_size.py
    ```
5. 最後，運行：
    ```
    ./media_processor.sh
    ```

---

## 授權條款 (License)

### 「專案」之定義
為釐清本授權條款之適用範圍，「本專案」係指 `media-processor-updates` 此一 GitHub 程式庫 (Repository) 內所包含之**全部內容**，包含但不限於：
*   所有 `.sh` 及 `.py` 結尾之**原始程式碼**。
*   所有說明文件，如 `README.md` 及 `LICENSE` 檔案。
*   所有版本控制歷史紀錄 (Git Commits)。
*   未來可能新增之任何相關文件、圖示與材料。

### 授權細則
本專案依據下述創用 CC 授權條款進行發布：

[![創用 CC 授權條款](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

**CC BY-NC-SA 4.0**

這意味著您可以自由分享與修改本專案，但必須**標示原作者 (BY)**、**禁止用於任何商業目的 (NC)**，並且衍生的新專案必須以**相同方式分享 (SA)**。

有關完整的法律條文，請參閱專案根目錄下的 [LICENSE](LICENSE) 檔案。
