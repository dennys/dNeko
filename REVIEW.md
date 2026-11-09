# dNeko 專案審查報告（2026-11-08）

> 純審查，未改動任何程式碼。對照 `TODO.md` 後，已記錄且處理中的項目只簡短引用，重點放在**新發現**與**仍未閉合的缺口**。

## 一、潛在問題

### A. 中高優先

1. **README 宣稱的「App 內模式」不存在**
   README 寫「動物可以在 app 畫面內漫遊互動」「短按＝撫摸、雙擊＝餵食（app 內與 overlay 相同）」，
   但主 app 沒有任何寵物畫面：`PetControllerFactory` / `AnimalAnimator` 只在 `overlay_main.dart` 被使用，
   原本的 `pet_stage.dart` 片段已在 commit `85c3e36` 刪除（見 TODO.md）。
   → 要補實作（預覽舞台），或改 README 只講 overlay 模式。

2. **`main()` 沒有啟動防護，DB 出錯 app 直接開不起來**
   `main.dart:15-25`：`seedBuiltIns()` 與 `settingsRepository.load()` 都在 `runApp()` 之前、沒有任何 try/catch，
   也沒有 `runZonedGuarded` 全域錯誤處理。DB 損毀或首次開檔失敗＝白屏崩潰。
   overlay 端有 `_readOr` 防呆，主 app 卻沒有，防護不對稱。

3. **橫向轉屏不會通知 overlay**
   `overlay_main.dart` 收到新 metrics 時會作廢漫遊校準（`_onData`），但**沒有人會推**：
   `HomePage` 只监听 `resumed`（`didChangeAppLifecycleState`），沒實作 `didChangeMetrics`。
   轉屏後 overlay 繼續用舊的螢幕尺寸校準範圍，宠物會卡在半邊螢幕，直到使用者手動開關一次。

4. **`pubspec.yaml` 的 `dependency_overrides` 與 TODO 記錄矛盾**
   TODO（第二輪）寫「`path_provider_android` 的本機 pin 已從 `pubspec.yaml` 移到 `pubspec_overrides.yaml`（不進 git）」，
   但 `pubspec.yaml:28-32` 仍然commit著這個 override，而且本機根本沒有 `pubspec_overrides.yaml`。
   結果：這台機器（dgx1/aarch64）的建構問題被強加給所有其他開發者和 CI。
   → 二選一：真的移過去，或更新 TODO 承認它就是全域 pin。

5. **overlay 讀不到 DB 時餓度直接歸零**
   `overlay_main.dart:313`：`saved == null → hunger = 0`。`_readOr` 把「DB 異常」和「真的沒存過」混為一事，
   讀取失敗等于餵飽宠物一次。疊加「sqflite 在 overlay isolate 可用性未驗」（TODO B-3），
   餓度持久化可能整個是假象。→ 真機驗收單該項優先跑。

### B. 低優先 / 小問題

6. **商店鏈路仍是空殼**（TODO 已記錄，此處只列缺口清單）：
   `_baseUrl` 佔位符、manifest 無 `INTERNET`、`_AnimalPicker` 的 `late final _animals` 不會在下载後刷新、
   商店頁沒有「使用這隻」入口、overlay 執行中重下載同 id 不會即時換圖。
7. **啟動時 payload 連送 4 次**（`OverlayService._shareStartupData`）：
   同一份 payload 觸發 3 次多餘的 `_applySettings`，且每次可能重跑 `_roamFor` 校準
   （視窗被搬到極端再搬回來）——宠物剛出現時可能可見地抖動。overlay 已載入同一隻後應可直接忽略重複 payload。
8. **`--no-tree-shake-icons`** 讓 release APK 多帶整套 Material 字型；若只是某個圖示需要，值得查能不能拿掉。
9. **`ios/` 目錄是死重量**：fork 的 `flutter_overlay_window` 只有 Android 實作、launcher icons 也關了 iOS，
   iOS runner 永远跑不起來，留著只誤導人。
10. **最複雜的檔案沒有測試**：`overlay_main.dart`（680 行、並發/順序號/計時器邏輯最密）全靠真機手測；
    既有 76 條測試都集中在 domain/data 層。真機驗收單（TODO A 節 6 項）一項都還沒跑過。
11. **舊安裝的 `cat` 顯示名仍是 `'ねこ'`**（`ConflictAlgorithm.ignore`，TODO 已接受不寫 migration）——
    對外發布前若改主意，記得更名要連 DB 一起。
12. **拖曳判定靠 50ms 輪詢 + 400ms 靜止**：拖曳中停頓超過 400ms 會被誤判放手（代碼註解與 TODO 皆已承認）。
    根治要 fork 插件補 `ACTION_UP` 回調（方案的 b），目前可接受。

### C. 做對了、不用動（審查確認）

- 簽名金鑰從未進過版控歷史（`git log --diff-filter=A` 查證為空），CI 用 secrets 還原，正確。
- `_safeName` 路徑穿越防護、`animation.json` 不可信輸入驗證、`allowBackup=false`，信任邊界處理到位。
- `PetStats` / `PetController` 的通知節流、`AnimationLoader` 的 provider 快取與指紋失效、
  `_loadSeq` 順序號防舊載入覆寫，都有對應回歸測試。

## 二、可做的功能（按建議優先序）

1. **App 內預覽模式**：主頁加一塊小舞台跑同一套 `PetController`，改速度/大小/範圍時即時預覽
   —— 同時把 README 兌現，也让沒有 overlay 權限的使用者有東西可玩。
2. **開放商店**：真 catalog URL + `INTERNET` 權限 + 「使用這隻」按鈕 + 返回主頁重刷動物清單
   （TODO 已寫好全開關點，純收尾工作）。
3. **水平走素材**：補 `walk_l/r` 四張圖或直接 `Transform.scale` 鏡射，刪掉 `_missingFrameAlias` 借用表
   （左右走現在看起來像在往下走，是最顯眼的素材債）。
4. **開機自動啟動 / 快速設定磚**：`RECEIVE_BOOT_COMPLETED` + Quick Settings Tile，
   免開 app 就能開關懸浮（已有桌面捷徑，這是補通知欄入口）。
5. **觸控穿透模式**：選單加「穿透」開關，宠物不擋操作只观赏（ANeko 系的招牌需求）。
6. **心情／感情系統**：在 `PetStats` 加 affection 值，常摸常餵親密度上升、影響 `PetBrain` 決策權重
   —— domain 層已把 stats/brain 拆開，加值不用動架構。
7. **多食物與硬幣經濟**：餵食選單改多項食物（飽食度/效果不同），硬幣由互動累積，接回商店當貨幣。
8. **夜間／離場智慧**：偵測深夜或久無互動→降低 tick 頻率或睡眠為主，省電；
   順便重新設計「關掉三天回來餓透」的缺席補算（睡覺可以免餓）。
9. **多寵物**（TODO 已評估路線 D2，估 2.5–3 天）：原生多視窗當純顯示器、行為邏輯留 Dart。
10. **本地素材匯入**：直接匯入 zip 素材包（跳過網路），比撘下載伺服器便宜，先用現成的
    `AnimalDownloadService._verifyAssets` 驗完整性。
11. **設定備份／還原**：`allowBackup=false` 加上 DB 存一切，目前換機＝重來；
    導出/導入一個 JSON 就夠（含設定＋餓度＋已下載清單）。
12. **音效與觸覺回饋**：摸/餵/睡小额 `Haptics` + 音效（可關），桌寵的「活着感」CP 值很高。
13. **成就／統計**：走過里程、餵食次數、存活天數，給長期使用者回頭的理由。

## 三、結論

核心（domain/data 層）品質相当好：防呆、節流、資源釋放與回歸測試都到位，
`TODO.md` 的債務追蹤也誠實。真正的缺口集中在三處：
**README 與現況不符（App 內模式）**、**三個未閉合的整合缺口（轉屏推送、DB 啟動防護、pin 位置）**、
以及**從未被真機驗證過的事實（sqflite-in-isolate、驗收單 6 項）**。
功能面性價比最高的三件：App 內預覽、水平走素材、開機自動啟動。
