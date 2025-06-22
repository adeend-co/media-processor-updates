# media-processor-updates
整合式影音處理平台（IAVPP）

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


## 授權條款 (License)

本專案依據下述創用 CC 授權條款進行發布：

[![創用 CC 授權條款](https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png)](http://creativecommons.org/licenses/by-nc-sa/4.0/)

**CC BY-NC-SA 4.0**

這意味著您可以自由分享與修改本作品，但必須**標示原作者 (BY)**、**禁止用於商業目的 (NC)**，並且必須以**相同方式分享 (SA)**。

詳細法律條文請參閱專案中的 [LICENSE](LICENSE) 檔案。
