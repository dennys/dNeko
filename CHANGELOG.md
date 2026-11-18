# dNeko CHANGELOG

已完成事项的归档区（把 TODO.md 瘦成「只剩還沒做的事」）。
**`git log` 才是權威**，這裡只是保留當時的判斷與驗收數字，方便日後回溯「為什麼现在是這樣」。
新的完成紀錄加在最上面。

> **2026-11-16 校訂（讀下面之前先講好）**
> 1. 跨案的真機驗收單 `../DEVICE_TEST.md` **已刪除**：它從頭到尾沒有一項打勾或填日期，留著只會
>    讓人以為「都驗過了」。因此下面所有「真機已驗／P0~P2 全過／餓度還在」之類的話，**都是口頭回報，
>    沒有書面證據**。下次上機請照該條的項目臨時開單、當場填 ✅／✗＋日期。
> 2. 舊 entry 裡「本機沒有 JDK 17+、`flutter build apk` 跑不了」是 2026-11-06 的狀態；現在這台
>    Linux/aarch64 開發機出得了 debug APK，release（AOT）仍只能在 x86-64 機器或 CI（見 README 建置表）。
> 3. 舊 entry 的「狗的 13 張素材缺」「小企鵝在商店清單裡」「本地 fork 的 `flutter_overlay_window`」
>    都已過時：八隻內建動物素材齊全（各 15 張），商店只剩 `fox`，插件改回 pub.dev 1.0.2。

---
---
---
---
## 2026-11-18 第八輪：餓昏鬧騰補聲與拉長（beg / faint 第二版）

**做了什麼**：討食／裝死從「無聲的 1.1/1.3 秒借用幀」變成「有叫聲的 5 秒演出」。

| | |
| ---- | ---- |
| 叫聲 | `PetController.onHungerCry`（在 `_enter` 發，摸／選單／PetBrain 三條路一次接齊）→ `overlay_main._playHungerCry` 播**同一聲叫聲降倍速**（`hungerCryRate`：討食 0.75、裝死 0.6）。**沒新增任何音效檔**，`assets/` 仍然只有 meow/bark |
| 時長 | `_begHold` 1100ms、`_faintHold` 1300ms → 都 **5 秒** |
| 看得見 | 八隻動物都沒畫 `Beg`/`Faint` 的幀 → 借 sit 的兩格原本**與坐著完全一樣**（faint 借 sleep 更像在午睡）。現在由 `AnimalAnimator._motionFor` 疊程式化作動：討食一伏一伏地拜、裝死從站姿倒下後攤著。`faint` 的借幀從 `sleep` 改 `sit`（已經躺平的幀看不出在「倒」） |

**為什麼不做成「持續到餵食為止」**（人類問的點）：餓昏的**持續**訊號已經是頭頂那顆求助氣泡（`HungerBubble` 只要在餓昏區就一直顯示），動作再釘死就會讓牠五秒、三十秒都不動 —— 讀起來像壞掉，而且可憐。AGENTS.md 把調性釘在「滑稽優先、不可憐、沒有死亡機制」，所以改成**短循環 + brain 高頻重抽**（餓昏時 beg 35%／faint 25%）。真要更誇張：把 `_begHold`/`_faintHold` 調大就好，一行的事。

**為什麼不另做音效檔**：只有 cat2 有 beg/faint 的圖（還是 512×512、與其餘素材不同尺寸，見下），八隻裡有七隻連動畫都是借的 —— 為借來的演出配專屬叫聲是投資錯地方。降倍速是既有 `ISoundPlayer.play(rate:)` 就能做的事，零新資產、零 pubspec 改動。

**素材那邊（未解，本次沒動）**：`assets/animals/cat2/` 的 `beg1-3.png`／`faint1-3.png` 是**孤兒圖** —— 512×512（其餘 256×256）、~310KB/張、`animation.json` 从沒宣告 `Beg`/`Faint`。所以 `test/asset_frames_test.dart` 有**兩條從這輪之前就紅**的：孤兒圖、各幀畫布尺寸不一致。要接就得重出 256 的圖（含腳底基線對齊 sit 的 y=223；beg 的內容高 205 vs sit 163、faint 三幀底部差 16px），**這是眼睛該判的事，不是盲改的**，所以留著。

**驗收（本機 Linux/aarch64）**：`flutter analyze` 無警告；`flutter test` 297 條，除上面那兩條既有素材紅燈外全綠。
新增/改寫測試：`onHungerCry` 三條路都響、不餓昏的動作不響；討食/裝死 3 秒還在演、5.2 秒收；借幀的討食會一直伏身、借幀的裝死倒下後姿勢不變、有專屬素材時不疊加；音效檔存在性改為**逐個內建動物掃**（以前寫死 `['cat','dog']`，新增一行音效卻忘放 mp3 不會紅）。
**上機零次**：叫聲聽感（0.75/0.6 倍速要「低沉委屈」不是「卡帶」）、倒下的角度與落點（`_faintAngle`/`_faintDropFraction` 是盲調的）、以及 5 秒會不會太長 —— 這三件只有真機看得出來。

**刻意沒做**：Windows 那側 `onTap` 寫死 `assets/sounds/touch.mp3`（檔案不存在、目錄沒進 pubspec、沒查 `soundEnabled`、沒查表 → 每次點擊靜默失敗）是**另一件事**，人類指示先放著；`WINDOWS.md` 第 68 行仍宣稱「單擊=摸（有音效）」，那行是錯的。

---
## 2026-11-17 第七輪：Windows 桌寵版（第一版，**盲寫**）

`flutter create --platforms=windows` 生出 runner，加 `lib/platform/`（平台開關 + Windows shell），
`main()` 只認 `PetPlatform.current.isWindowsPet` 一個分岔。驗收與上機流程全在 **`WINDOWS.md`**。

**為什麼長這樣（當時的判斷）**

- **整個 exe 就是那顆懸浮視窗**：Android 那边「主 app 設定頁 + 插件懸浮視窗 + 獨立 isolate」在
  Windows 沒有對應物（`flutter_overlay_window` 是 Android only，Windows 連 plugin 註冊都沒有）。
  第一版因此 = 寵物 + 系統匣，設定頁留给下一層（能調的先進系統匣：大小／活動範圍／穿透／顯示隱藏／結束）。
- **選單疊在同一顆視窗**：Windows 沒有 `FlutterTextureView` 的 resize 拉伸 bug，不需要第二顆
  FlutterEngine；`MenuDirector` 本來就是純狀態機（平台動作是注入的回調），所以直接重用，
  兩側仍走同一條 `{"action": ...}` 協定，不會分岔。
- **不抽 shell 公共父層**：兩邊視窗模型差太多（一個要問插件肯不肯搬、一個是自己家的視窗），
  硬抽會變一堆 `if (isWindows)`。共用的是承重的 `PetController`／`MenuDirector`／`ScreenMetrics`／
  `SettingsRepository`／`AnimalAnimator`／`FeedingMenu`。
- **視窗樣式在 C++ 建立時給**（`WS_EX_LAYERED|TOOLWINDOW|NOACTIVATE` + `WS_POPUP`）：
  「點牠不搶焦點」window_manager 0.5.x 沒有 API（0.6+ 才有 focusability），而且已顯示的視窗改
  ex-style 不可靠。順手拿掉 runner 的「第一幀就 Show()」，否則會先閃一塊 1280×720 白盤。
- **套件停在 `window_manager 0.5.2` / `tray_manager 0.5.2`**：新版（0.6/0.7）換了整套 API、
  要 Flutter 3.47+/Dart 3.13+ 並拖 `nativeapi` C++ 核心；這一版自帶 C++，裝機只要 VS 的 C++
  工作負載。**別順手升**（升版注意事項屆時補進 AGENTS.md）。
- **DB**：`sqflite` 沒有 Windows 實作 → 桌面用 `sqflite_common_ffi`，切換點只有
  `pet_database.databaseDirectory()` 一處，DDL 仍一份（這是那個檔頂端寫著的鐵律）。
  順帶把資料目錄從 `getDatabasesPath()`（ffi 後端下會退回 temp → 重開機資料丟光）換成
  `getApplicationSupportDirectory()`。

**驗證**：`flutter analyze` 0 issue、`flutter test` **292** 全綠（新增 `test/windows_pet_window_geometry_test.dart`
6 條：開選單時寵物不得跳位、選單不得出界、視窗必須是兩者並集）、Android 側 `build apk --debug` 照常。
**螢幕上會發生的事一項都沒驗證過** —— 開發機是 Linux/aarch64，編不了 Windows 目標，這是 `WINDOWS.md`
那份 ladder 存在的原因。

**已知的未做/取捨**（詳細表格在 WINDOWS.md）：沒扣工作列、Windows 沒有設定頁、商店與下載未接
（`getExternalStorageDirectory()` 是 Android only）、開機自啟沒有、系統匣沿用 PNG 圖示（可能要 .ico）。

## 2026-11-17 第六輪：各養各的（per-animal 餓度與位置）

人類的決定：「各養各的」＋「收起來的寵物不餓」。v1 是八隻共用一份餓度與位置，換寵物時
牠帶著上一隻的飽食度與座標走，等於「換皮」而不是「換宠物」。

- **鍵空間**：`pet_hunger_<id>` / `pet_position_<id>` / `pet_bond_<id>`（bond 早就是 per-animal，
  這輪把餓度與位置補齊）。三個鍵名做成 `static` 讓測試能鎖住 —— 它們是 **on-disk 格式**，
  改等於資料搬家。範圍守死：只有餓度／位置／親密度 per-animal，**大小／速度／活動範圍／
  語系／主題是全域偏好**（人類的決定，不做各養各的）。
- **「收起來不餓」的實作是一個旗標，不是時間戳**：`HungerRecord.wasDisplayed`。
  正常關懸浮／換寵物 → 存盤時標 `false` → 重開**不補算**；當掉／被系統殺（沒來得關）→
  維持 `true` → 依 `savedAt` 補算（跟舊版一樣）。舊資料沒有這個欄位一律讀成 `true`
  （不懲罰舊安裝）。規則本身抽成純函式 [hungerOnWake] 并留 4 條測試 —— 寫在呼叫端的話改了沒人會紅。
- **三個「收起來」時機**：換寵物（`_loadAnimal` 於新 controller 就緒後）、選單按結束（`_quitApp`）、
  以及**懸浮被關掉但這個 isolate 還活著**的時候 —— 後者是新增 `OverlayPetDriver(onStopped:)`
  才接得到的（插件 `closeOverlay` 只 stopService，平台只回 false；driver 停機那一刻才是真相）。
  回呼由呼叫端**捕獲 animalId + controller** 傳入，不讀欄位：換寵物的空檔讀欄位會寫到別隻的鍵上。
- **存盤要寫誰**：新增 `_controllerAnimalId`，不用 `_resource` —— 換動物時 `_resource` 會先被換成
  新那隻，非同步的存盤就會寫到別隻頭上（這類競態本檔已有 `stale()`/`identical()` 的先例）。
- **遷移**：首次碰 per-animal 狀態時把 v1 的全域餓度/位置搬給「當前那隻」（`pet_settings.animalId`），
  寫 `pet_state_migrated_v2` 完成標記，**舊鍵保留不刪**（可回退）。遷移失敗的 Future 不留欄位上
  （跟 `DatabaseHandle` 同一個教訓），下次呼叫重試。
- **沒資料的新寵物**：餓度 0（飽的出場）、位置用中央（人類的決定）。
- **刪寵物**：`deleteBond` → `deletePetState`，親密度／餓度／位置三把鍵一起清。
- 連帶修一個會立刻被看見的顯示問題：主頁那行餓度在**換寵物後會繼續顯示上一隻的數字**
  （20 秒輪詢才跟上）→ `_apply` 偵測到 animalId 換了就立刻重讀。
- 測試 275 → **286**（新增 `pet_state_per_animal_test`：鍵名契約、hungerOnWake 四條、
  編解碼含旗標與兩代舊格式；driver 的 onStopped 兩條），`flutter analyze` 無警告。
- **可預期的行為變化（上機別誤判成 bug）**：換到一隻很久沒玩的動物，牠會**一出場就餓昏闹騰**，
  因為那隻的計時從「上次收起來」開始算。

## 2026-11-17 第五輪：「僅下方」那條帶改成**可見帶高 ÷ 螢幕高**，並做成設定

- **舊定義的實際數字**（人類的體感回報「感覺像螢幕下 40% 都能跑」是對的）：帶厚寫死
  `petSize × zoneSizeFactor(2)`，而 `zoneBounds` 回的是**視窗左上角**的可行域，所以可見帶高
  = 厚度 + 一個寵物高 = **3 × petSize**。預設 120 在 800 高的螢幕上是 **45%**，調到最大 180 是
  **67%** —— 名叫「不擋視線」卻隨寵物大小膨到半屏以上。
- **新定義**：設定值 = **可見帶高 ÷ 螢幕高**（預設 0.22、可調 0.10~1.00）。厚度 =
  `螢幕高 × fraction − petSize`（夾在 `0 ~ roam.height`）。選這個定義而不是「厚度 ÷ 螢幕高」，
  因為給使用者調的數字必須是他看得到的那個東西。
- **帶比寵物還矮時厚度收 0** → 牠貼在最底部坐著（`fraction` 拉到底、或寵物調到比那條帶還高時）。
  這是可預期的退化，不會出現負 Rect 或跑出邊界（測試有掃 petSize=900 的那條守住）。
- **四角（`topLeft` 等）刻意不跟著改**：那幾個的語意是「寵物大小的一塊」，改成螢幕比例會變成
  怪長方形。`zoneSizeFactor` 只留給它们。
- `zoneBounds` 從 top-level 函式**收進 `ScreenMetrics`**（要拿 `logicalSize.height`），
  呼叫端兩處（`overlay_main`）與測試一起換。不是為架構，是它本來就需要螢幕高這個資訊。
- 設定頁 slider **常駐顯示**（不隨 zone 選擇藏起來）：藏起來會讓設定頁跳動，而且使用者是
  「先看到範圍不對」才想來調它。拖完才 `_apply`（沿用 hunger slider 的 preview/apply 兩段式）。
- l10n 新增 `settingsBottomBand` × 4 語系（`l10n_arb_test` 會紅的那個門禁）。
- 測試 267 → **275**，`flutter analyze` 無警告，debug APK 仍編得過。
- **未驗**：真機上拖 slider 活動範圍是否即時變、22% 這個預設在實機上是否夠「不擋視線」
  （`updateBounds` 的即時生效路徑是舊的，本輪只換了算出來的 Rect）。

## 2026-11-17 第四輪：餓昏鬧騰（`beg` 討食拜拜 / `faint` 餓昏裝死）

調性由人類拍板：**9 歲小孩、滑稽優先、fun 為先**（不是「可憐求助」）。

- **餓昏線不新設門檻**：`PetStats.starvingThresholdAt(t) = t + (100 - t) × 0.6`，預設門檻 60 →
  **不餵 84 分鐘**開始鬧。為什麼不用 `門檻 × 1.6`：hunger 封頂 100，slider 拉到 70 以上就
  **永遠到不了餓昏**，等於那個設定把功能關掉（`test/pet_stats_test.dart` 那輪 `[5,30,60,90,99]`
  鎖住「一定到得了」）。門檻拉到 100（永不餓）時餓昏也不會出現，語意一致。
- **`PetBrain` 多一個 `isStarving`**（不靠 isHungry 猜）：餓昏時 35% 討食、25% 裝死、15% 搖擺、
  15% 還去走、10% 原地喘氣；**絕不睡覺、絕不撒嬌**。只傳 isHungry 無法區分「到處找吃的」與
  「癱在鬧」，所以這個參數是必要的，不是裝飾。
- **摸牠：餓昏時播討食而不是撒嬌**，而且討食後面不接 `hop`（跳跳會把「牠餓到在拜」的氣氛破掉）。
  不餓時行為與之前完全相同（`test/pet_controller_test.dart` 有鎖）。
- **選單六格 → 八格**：`beg`/`faint` 進 `kFlourishBehaviors`，**不分狀態永遠可按**。
  這是人類的要求：「小孩不會傻等 84 分鐘」——沒有這兩格，整個功能等於不存在。
  `FeedingMenu._gridRows` 3 → 4（視窗高度由 `contentHeight` 自動長 52px），四語系各加
  `menuActionBeg`/`menuActionFaint`。
- **餓度條變成報信器**：過餓昏線換橘色 + 火苗圖示，軌道上画一條餓昏線刻痕 —— 讓小孩看得出
  「再一下下就能看到牠裝死」，而不是乾等。位置與顏色同一個 `PetStats.starvingThresholdAt` 來源。
- **求助氣泡不依賴新素材**：`HungerBubble` 缺 `assets/images/hunger_bubble.png` 時由
  `_BubblePainter` 現畫一顆（空碗＋抖動線，沿用素材規格的配色）。人類會用 `ASSET_PROMPT.md`
  第 9 節的 prompt 去別的 AI 出圖，放進去就自動換成那張，代碼不用動。
  氣泡畫在**框內**右上角（懸浮視窗只有寵物大小，框外會被裁），素材上方本來留了約 23% 空白頭部。
- **叫聲**：餓昏時 `setPlaybackRate(0.85)`（低沉但不會聽成另一種動物）；倍速每次播放都設，
  不做「事後還原」（`play()` 只等到開始播放，馬上還原會把這聲的倍速抵銷）。
- **素材缺不缺都不卡**：`_missingFrameAlias` 加 `beg→sit`、`faint→sleep`，沒畫的動物照樣演；
  宣告了幀卻少圖由 `asset_frames_test` 在測試階段擋。所以順序是「先做完 code → 先只做貓試水溫 →
  好笑再補其余七隻」，不好笑只改 prompt 不改代碼。
- 測試 243 → **267 全綠**，`flutter analyze` 無警告。新增：`hunger_bubble_test`、`hunger_bar_test`、
  餓昏線/餓昏決策/餓昏互動/借幀各一組。
- **未驗**：真機上八隻的餓昏觀感（借 sit/sleep 的動物差別很小，氣泡是主要訊號）、
  選單 8 格在實機窄屏的實際高度、`setPlaybackRate` 在真機的效果。

## 2026-11-17 第三輪：寵物視窗改成注入、觸控模型拍板、清掉第二塊死代碼

- **`overlay_main.dart` 的寵物視窗改成注入**：九處自己 new `OverlayWindow()` 全部改走
  `_OverlayApp.window`（`IOverlayWindow`），實作由 `runOverlayApp()` 這個組合根給。
  這是桌面版與「自己開 N 顆原生視窗」那條路的共同前置 —— 現在有兩個未來使用者，不是預留開關。
  訊息通道（`overlayListener` ／ `shareData` 三處）仍直接打插件：沒有第二個實作者之前不先造介面。
- **觸控模型拍板：預設可觸控**（人類的決定）。「為什麼不做閒時穿透」寫進 TODO 的「多寵物」那節 ——
  摸／餵／開選單全掛在寵物視窗的 `GestureDetector` 上，而穿透的視窗收不到任何事件，
  所以那個功能的全部成本都在「喚醒入口」；抱怨擋到東西時的第一解是既有的 `PetZone`，不是穿透。
  附帶記下做多寵物時要還的債：`touchable` 必須 per-animal（逐窗是唯一粒度）。
- **刪掉 `android/.../com/dneko/app/OverlayService.kt`（177 行 + `NekoView`）**：它不是 Service 子類別、
  不在 Manifest、沒有任何引用，連它要載入的 `assets/dneko.png` 都不存在（早期遺留）。
  活著的只有插件那個 `flutter.overlay.window.flutter_overlay_window.OverlayService`。

---
## 2026-11-17 第二輪審查的後續修復（DB 開檔會毒化整個程序、幽靈選單、商店換版不能回滾、fork 死檔）

對上面那 9 支 commit 的另一份獨立審查（讀 diff **與周圍代碼**，驗證是自己跑的，不是沿用上面那欄數字）。
`flutter analyze` 0、`flutter test` 235 → **243** 全過。

- **DB 開檔失敗會永久毒化（本輪唯一的真回歸）**：上一輪把 `Future<Database> get _database async =>
  _db ??= await openPetDatabase()` 改成 `_db ??= openPetDatabase()`。差一個 `await`，語意從「失敗後下次
  重試」變成「把一顆失敗的 Future 存在欄位裡，之後每次呼叫都拿到同一顆炸彈」，直到程序結束。
  後果：位置與餓度再也存不進去（只留 log）、`loadPosition()` 回 null → 每次開懸浮寵物都在 (48,96)、
  下載過的動物永久畫佔位圓（內建八隻有 `resolveResource` 的 fallback 保護，不受影響）。
  而 overlay isolate 的 DB 路徑正是 TODO 上那條「無書面記錄」的路，最不脆的就是它。
  修：`pet_database.dart` 新增 `DatabaseHandle`（只快取成功、同時到來的呼叫仍共用一次開檔），
  兩個 repository 改用它；`test/pet_database_handle_test.dart` 4 題鎖住。
  保留上一輪的 WAL（是對的決定）；只是現在會有 `-wal`/`-shm`，**手動備份只拷 `.db` 會丟最後幾筆**。
- **幽靈選單**：`_loadAnimal` 叫 `MenuDirector.abort()` 時若 `open()` 還卡在 `await showWindow()`，回來的
  選單沒人收 —— 畫面上留一張舊動物的選單六秒，而且 `onCommand` 因為 `_open` 已是 false 會把每一格
  點擊都丟掉（看起來像壞掉）。修：MenuDirector 加世代計數，`open()` 回來時世代對不上就自己 `close()`
  並回 false；補 1 題。
- **商店換版（入口仍是關的，但先把洞補好）**：
  1. 同一隻動物被同時下載兩次會共用 `<id>.tmp`，第二趟開頭的「先清舊暫存」把第一趟正在寫的整包砍掉
     → 入口加 `_inFlight` 擋掉第二趟（`finally` 歸還，失敗後仍可直接重試）。
  2. `promoteDownloaded` 從「先刪 target 再 rename」改成「改名讓位 → 換上 → 才真的刪舊的」，中途失敗
     把舊的改名回原位；上次死在兩個 rename 之間留下的 `.old` 先歸位，而不是當成垃圾刪掉。
     `rename` 參數是測試縫隙（真檔案系統沒辦法造出「換到一半失敗」）。已知限制：兩個 rename
     之間被殺進程仍會失去那個素材目錄（視窗極小）；要真的免疫得用符號連結間接層。
  補 3 題。
- **`overlay_main._onData` 的 `_driver?.restart()` 補上語意註解**：它是「收到任何 payload 就喚醒」
  （含 `_shareStartupData` 那四次延遲重送與每次 `pushSettings`），只在「`stop()` 只有一個原因：視窗
  不在」時成立。哪天要加另一種停止理由（省電、使用者暫停），得另開開關，不能再拿這條當喚醒入口。
- **清掉本地 fork 死檔**：`packages/flutter_overlay_window/`（23 支檔，含那兩記 `ACTION_OUTSIDE` 補丁）。
  它從 2026-11-16 起就不被 `pubspec.yaml` 引用（惰性、不參與編譯），但 AGENTS.md 早就寫成「已經刪掉了」——
  本輪真的 `git rm` 並更正那句話。`analysis_options.yaml` 的 `packages/**` exclude 留著（再次 fork 時用得到），
  註解改成條件式。

---
## 2026-11-17 兩份代碼審查合併修復（isolate 關不掉、選單會凍死寵物、定格卡幀…）

兩份獨立審查合併成一張 18 條的單，逐條查證後修掉 15 條、
撤銷 2 條（查下去發現是我自己看錯）、掛起來 1 條（商店解凍時再修）。`flutter analyze` 0、
`flutter test` 205 → **235** 全過。

### 修掉的（按嚴重度）

- **關掉懸浮之後，寵物的 isolate 還在跑（真機已證實）**：插件 1.0.2 的 `closeOverlay` 只有
  `stopService`，`OverlayService.onDestroy()` 不移除 `FlutterEngineCache` 裡那顆 engine、也不 dispose
  Dart widget tree —— 於是 16ms 定時器一直跳、寵物在看不見的狀態下繼續散步，`_rememberPosition`
  每 5 秒把新位置寫進 DB，**下次開懸浮牠就出現在別的地方**（使用者實測：不用等幾分鐘，幾秒就跑到別處）。
  另一半是代碼自己的問題：`OverlayWindow.moveTo` 宣告 `Future<void>`，把平台回的 `false`
  （`OverlayService.moveOverlay` 在 service 沒了的時候不擲例外、只回 false）丟掉，所以
  `OverlayPetDriver` 的失敗計數永遠是 0，logcat 一片乾淨。
  修：`moveTo`/`resize` 把 bool 傳上來 → driver 連續 3 次拒絕就 `PetController.stop()`（新）；
  重開懸浮時 `overlay_main._onData` 呼叫新的 `OverlayPetDriver.restart()` 喚醒。
  **这两邊必須成對**：定時器一停就不會再 notify，driver 等不到「下次位置變動」來重試，
  忘了 restart 的症狀會比原本的 bug 更難查（關一次之後寵物永遠站著）—— `restart()` 裡直接叫
  `controller.start()` 就是為了讓人沒機會只接一半。
  `test/overlay_pet_driver_test.dart` +4 題、`test/pet_controller_test.dart` 新增 `stop()/start()` 一題。
- **開選單失敗一次，寵物永久不會走路**：`_openMenu` 的 `setPaused(true)` 在 try 之前，
  `_menuOpen = true` 卻在 `await currentPosition()` 之後，而 `_closeMenu()` 第一行是
  `if (!_menuOpen) return` —— 那一步丟例外就沒人還原凍結，且 engine 是 cached 的，關掉重開也不救。
  檔首註解本來就寫「上面任何一步失敗都要把牠解開」，但代碼做不到，也沒有任何測試。
  修：整組開／關／6 秒逾時／指令派工抽成 `presentation/controllers/menu_director.dart`
  （不吃 Flutter 與平台，凍結與視窗動作由呼叫端注入回調），`close()` 改成**冪等且永遠還原**，
  `open()` 失敗時先還原再把例外丟回呼叫端報 log。新增 `test/menu_director_test.dart` 11 題，
  其中「開到一半失敗也要有 resume」那條就是這次那個 bug 的鎖。
  順手把 `if (!mounted) return` 改成丟例外 —— 它以前也留著凍住的寵物，而「isolate 馬上就沒了」
  這個假設在上一條被查出來之後已經不成立了。
- **定格會卡在動作最後一幀**：`_tickFrozenPet` 只倒數撒嬌，正在吃／跳跳／搖擺／打盹時被定格，
  `_hold` 永不結束。改用現成的 `_isTimed(_behavior)`（`test/pet_controller_test.dart` 鎖住）。
- **桌面捷徑關寵物不收選單、不釋放第二顆 FlutterEngine**：捷徑那條路不啟動 MainActivity，
  因此 Dart 的 `OverlayService.close()`（全案唯一呼叫 `hideMenu`/`disposeMenu` 的地方）不會跑。
  修：`ToggleShortcutActivity` 在 `stopService` 之前自己叫 `MenuOverlay.hideMenu()` + `disposeMenu()`。
- **主頁那排動物每選一次就閃一下空白**：`_AnimalPicker` 的 key 裡塞了 `settings.animalId`，
  點一顆 chip 就重建 State → 重查一次 DB → FutureBuilder 回到 `snap.data == null` 那個
  `SizedBox(height: 38)`。選中哪隻是 `selected` 參數傳進去就夠了，key 只留 `_pickerRefresh`。
- **內建 `cat2` 在四種語系都顯示中文本名「阿咪」**：`l10n/animal_names.dart` 的 switch 漏了它、
  四份 arb 也沒有 `animalCat2`。補名字之外，`test/l10n_arb_test.dart` 多加一條「每一隻內建動物
  在每個語系都有名字」（用 sentinel 當 fallback 去驗「有沒有掉進 default 那格」）——
  舊的兩條只查「鍵集合齊不齊」與「素材有沒有註冊進 builtIns」，查不到這種「某一隻漏一格」。
  變異檢查做過：把 switch 那行拿掉測試就紅。
- **商店解凍前的三條**（入口仍是關的，先修好才敢開）：
  ①下載改成「先進 `<id>.tmp/` → 全部驗完 → 才換上」，**不再先刪掉舊資料夾**（舊版網路在第 3 張圖
  斷線時，舊素材已刪、新的不完整、`upsert` 也不會跑 → 那隻動物從此只能畫佔位圓）；
  ②`_verifyAssets` 除了「檔名都在」也要「不是 0 bytes」（對端回 200 給空檔也會混過去）；
  ③正在使用的那隻不准刪（`StoreController` 注入 `currentAnimalId`，刪了 overlay 會永久畫佔位圓）；
  ④`StoreController.load()` 補 try/finally（DB 一丟例外就永久轉圈）。
  `AnimalDownloadService` 新增 `dio` 與 `documentsDirectory` 兩個注入點，因此這四條都有真測試
  （`test/animal_download_service_test.dart` 8 題，用假 HttpClientAdapter + 暫建目錄，不碰網路）。
- **DB 開 WAL**（`pet_database.dart` 的 `onOpen`）：主 app 與 overlay isolate 各開一條連線寫同一個檔，
  預設 rollback journal 下會互鎖到 SQLITE_BUSY；overlay 那邊的重試是補救，WAL 才是解。
- **l10n 產物進版控卻沒人檢查它和 .arb 同不同步** → CI 增加 `flutter gen-l10n` + `git diff --exit-code lib/l10n`。
  以前改了 arb 忘了 gen：analyze 綠、測試綠（arb 那支只比對 arb 彼此），出貨的還是舊文字。
- **`_resizePetWindow` 不再無聲**（TODO 2026-11-16 第 2 條結案）：resize 被擋掉只影響視窗尺寸、
  畫面不會消失，以前連一條 log 都沒有。
- **`OverlayPetDriver` 的 log 改成可注入**（TODO 2026-11-16 第 1 條結案）：現在有測試斷言
  「失敗要留一條、而且不能每 16ms 洗一行」—— 那條 log 就是這樣從 `appError` 漂到 `print` 的。
- 兩個 repository 的 `_database` 從 `async` getter（await 完才賦值 → 兩個同時到來的呼叫各開一次檔）
  改成快取 Future。

### 順手抓到的舊脆口：`pet_controller_test` 偶爾紅

`通知節流 原地發呆不會每幀都通知` 大約每 6 次全量跑會紅 1 次（本輪實測過）。原因不在通知節流：
`PetController` 沒注入時用的是 `FlourishScheduler()`（**沒 seed 的 `Random()`**），那些測試一 pump
就是兩三百幀，就有約 2% 的機率自己跳出一個 hop/wobble/doze —— 位置與「通知次數」的斷言就這樣被
吹翻，而且只在平行跑、機器吃滿的時候比較常出現。修法是在測試裡注入 `FlourishScheduler(chancePerMinute: 0)`
（`make()` 的預設，3 條直接建立 idle 控制器的也補上）：要播動作的測試本來就是直接叫 `playFlourish`，
不靠那個排程器，所以預設關掉不損任何覆蓋。改完連跑 10 次全綠（之前 6 次紅 1）。
**產碼一行沒動** —— 隨機性是要的，只是不該由被測對象自己擲骰子。

### 本輪的互動變更：定格時那 6 個動作格不再變灰

人類的決定：**按選單是明確的互動，所以照樣按得下去，按了先解除定格再播**（與 `feedAt` 同一套語意）。
實作上 `playFlourish` 直接清 `_frozen`（不走 `setFrozen`，因為它解凍時會請 brain 重新決定、
把使用者剛點的動作蓋掉）。順手清掉兩件因此變成死東西的：`MenuPayload.frozen` 與
`FeedingMenuTile.enabled`（再也沒有人會把格子設成不可按）。
摸牠**仍然不**解除定格（摸一下不等於「我要開始動了」）—— 這個差別 `test/pet_controller_test.dart`
兩條測試分開鎖住。

### 查下去之後撤銷的兩條（記下來免得下次再報一次）

- 「兩份像素貓幾乎複製，留一份」：`_FallbackPetPainter`（animal_animator，深色剪影 + 走路彈跳 +
  睡覺閉眼 + 撒嬌腮紅）與 `_OverlayFallbackPainter`（overlay_main，彩色貓 + 失敗時那條橙色底線）
  差的是**語意**（一個是「素材壞了」的占位、一個是「這個動作沒有幀」的占位），不是複製。合併會把
  失敗狀態的顏色與動作差異抹掉 → 不動。
- 「`PetStats.feed({double? amount})` 的 `amount` 是死參數」：它不是死碼，是測試用來走進
  「半飽」這種中間態的縫隙（4 條測試靠它驗 `_setHunger` 的 early-return 與跨門檻通知）。
  刪了它得先想辦法用 1500 次 `tick()` 湊出同樣的狀態，純虧 → 留著。

### 沒動的部分

`OverlayService`（主 app 側）與 `home_page` 的狀態機仍無測試 —— 這輪補的是選單那組與驅動器；
主頁開／關懸浮那條要抽掉 `MethodChannel` 依賴才好測，留給下一輪。真機驗證項目全部列在
TODO 2026-11-17 那節（含 isolate 那條的四項驗收與 `adb` 指令）。

## 2026-11-16 三條 log／載入路徑的補丁（文件校訂時順手查出來的）

- **內建動物不再被 DB 拖下水**：`AnimalRepository.resolveResource()` 之前是
  `await getById() ?? builtIn()` —— DB 讀不到（sqflite 在 overlay isolate 不可用、檔損毀）時整個丟例外，
  `_loadAnimal` 的 catch 直接把畫面打成佔位圓，**連隨 app 打包的貓都開不出來**，而 AGENTS/README
  一直宣稱「內建動物直接從 assets 載入、不依賴 SQLite plugin」。改成 DB 優先但**讀失敗就退回
  `builtIn()`**（下載的動物救不了：本地資料夾路徑只能問 DB）。
  新增 `test/animal_repository_test.dart` 2 題；两条都是**把舊代碼塞回去會紅**的那種（第二條舊代碼
  會抛例外而不是回 null）。
- **載入失敗不再無聲**：`_loadAnimal` 的 `catch (_)` 與 `resource == null` 兩條路徑原本一句 log 都沒有
  ——「id 沒註冊進 builtIns」與「素材壞了」在外面的表現都是那顆圓。現改走 `appError`（tag `dneko.error`）。
- **`OverlayPetDriver` 的 moveTo 失敗**從 `print()` 改回 `appError`（連 StackTrace 一起帶）：
  `print` 落在 logcat 的 `flutter` tag，而除錯指令是 `adb logcat -s dneko.error`，等於那條註解保證的
  「一定要留痕」在實際用的 filter 下看不見；同時拿掉 `// ignore: avoid_print`。
  ⚠️ 這條**沒有測試保護**（`overlay_pet_driver_test` 只鎖「失敗後會重試」），所以下次還會再漂。
- 驗收：`flutter analyze` 0 問題、`flutter test` 203 → **205** 全過。**真機未測**（這三条都是
  只在 DB/平台出錯時才走得到的路徑，本機造不出條件）。

## 2026-11-13 清死碼：那四支「已被宣稱刪掉四次」的檔與 `placeMenu`

- **第四次宣稱也還是假的，這次是真的**：`DELETED.txt`、`assets/dneko.png`（261 KB）、
  `lib/domain/pet_display_mode.dart` 三支 `git rm`（第 4 支 app 模組 `OverlayService.kt` 已在選單
  改寫時刪掉）。之前幾次之所以「宣稱刪了卻還在」：刪除做在**另一台機器**的 bundle commit
  （`7648c91`，本機 `git cat-file -t` 查無此物、`git log --all --diff-filter=D -- DELETED.txt`
  一直是空的）—— **跨機交付的刪除要嘛在同一條血線上做，要嘛交付後立刻在另一端驗證
  `git ls-files`。**
  （`pubspec.yaml` 的 assets 只列 `assets/animals/*/`，`dneko.png` 本來就沒進包，刪它零風險。）
- **選單改寫長出的新死碼**：`placeMenu()`（選單搬到第二個視窗後改用 `placeMenuWindow()`，
  lib 內零呼叫者）連它的測試組一起刪；`MenuPlacement.above` **留著** —— 生產代碼不讀它，
  但 `placeMenuWindow` 的測試靠它鎖住「優先開下方、放不下才往上」，註解已標明別當死欄位刪。
- `REVIEW.md`（2026-11-11 那份報告）**一併刪除**：15 條的結算本來就在下面「2026-11-11 REVIEW
  修復」那條 entry（含反駁報告自己講錯的 #9 keystore、#13 `copyWith`、#2 的修法），真機清單在
  `../DEVICE_TEST.md`（2026-11-16 已刪，且從未填過），剩下的只有 11-11 當時的行號與敘述 —— 選單改寫之後 `檔案:行號` 全部漂移
  （測試 132→198、`overlay_main.dart` 792→921 行），留著只會變成沒人對得上的敘述。
  準則跟 `POPUP_TRANSITION.md` 一樣：**報告是快照，結算與教訓進 CHANGELOG，快照不留。**
- 驗收：`flutter analyze` 0 問題、`flutter test` 198（刪掉 6 題死測試）。

---
## 2026-11-13 選單續修：餵食語意、定格變灰、原生三條保險

**使用者會以為是 bug 的三個（都改掉了）**
- **餵食量寫死 40 → 改成餵到飽**（`PetStats.feed()` 預設 `amount == null` 時 hunger 歸零）。
  舊行為讓設定頁那個「多久變餓」slider（1~100 分鐘）完全是裝飾：衰減 1 點/分鐘＋固定贖回 40
  ⇒ 不管門檻設幾都是每 40 分鐘餵一次。現在「餵完能安靜多久」＝門檻值。
  為什麼不是 `amount ?? hungryThreshold`：門檻設 20 時從餓透餵一次只到 80、還是餓，要連按
  5 次才脫餓 —— 又變回「餵了沒反應」。`pet_stats_test` 鎖住門檻 20/60/90 的「餵完撐多久」。
- **定格時按選單那 6 個動作格「沒反應」**：`playFlourish` 本來就在 `_frozen` 時靜默丟掉，
  現在選單把那 6 格**變灰＋按不下去**（`FeedingMenuTile.enabled`，`menu_main` 用
  `!payload.frozen`）。按不下去也不會誤重置 6 秒自動關的計時器。
- **餵食會偷偷解除定格**（`feedAt()` 的 `_frozen = false`，是明確互動所以保留）：選單網格下方
  加一行小字講清楚（l10n 新 key `menuFeedUnfreezes`，四語系）。視窗高度由
  `FeedingMenu.contentHeight` 算，加了那行就同步加高，並用 widget 測試鎖住不 overflow。

**原生三條保險（機率極低，但都是「看起來像壞掉」）**
- `MenuOverlay`：選單 isolate 的 handler 可能還沒註冊就推 payload（剛 preWarm 就長按）→
  延後 250 ms **補打一次**（`_loadPayload` 冪等）。
- `forwardToPet` 發現寵物那側 engine 不在時，原本只 log 丟掉 —— 連 `ACTION_OUTSIDE` 都會被丟，
  等於沒東西關得掉那顆視窗 → 改成**自己 `removeViewNow()`**。
- `addView` 失敗（post 之後才發生，Dart 那側早已收到 success）→ 補送 `{"action":"close"}`，
  否則寵物會白白凍到 6 秒逾時、期間長按也沒反應。

驗收：`flutter analyze` 0 問題、`flutter test` 204（新增 `test/feeding_menu_test.dart` 4 題、
`pet_stats_test` 餵食那幾題重寫）、debug APK 編得過。**真機待重測**：選單高度（加了小字那行）、
定格開選單看那 6 格變灰、餵食後多久又餓。

---
## 2026-11-13 選單改成第二個懸浮視窗（真機已驗，**勝出**）

- 開／關選單動物**完全不動**：選單搬到第二個 `WindowManager` 視窗 + 第二顆 FlutterEngine
  （原生 `MenuOverlay.kt`、Dart `lib/menu_main.dart`），寵物視窗從頭到尾不 resize、不搬移。
  上下半螢幕也不再是兩條路。為什麼只能這樣：`AGENTS.md`「選單是另一個視窗」。
- **另一條落選**：`fix/overlay-menu-keep-pet-visible`（同一視窗、把舊幀「預先畫成被拉伸後剛好對」）
  真機實測**與改動前體感相同**。教訓 —— 把體驗押在 `FlutterTextureView`「舊 buffer 等比拉伸填滿
  新邊框」這個**未文件化**行為上是死路；要「動物不能被碰」就只能另開視窗。別再回来試第二遍。
- 行為（使用者拍板）：選單開著時凍住牠、拖曳寵物＝關選單、選單不可拖／不貼邊、6 秒自動關、
  選單裡那隻預覽動物刪掉（牠本來就一直顯示在螢幕上）。
- 選單那顆 engine 跟著懸浮開關：`OverlayService.close()` → `hideMenu` + `disposeMenu`
  （桌面寵物開一整天，懸浮關了就不該還佔記憶體）；下次開懸浮 `preWarmMenu` 重建。
- 指令走「選單 isolate → 原生 → 寵物 isolate」，**不繞主 app**：劃掉 app 介面後寵物還在跑。
- 清掉的過場機器約 150 行（`_WindowState`／`_resizeHidden`／`_reveal`／`_expectedHeight`／
  `_moveSettle`／`OverflowBox`／共用 GlobalKey…），`_menuOpen` 一個 bool 取代。
- 驗收：`flutter analyze` 0 問題、`flutter test` 198、`flutter build apk --debug`（含新 Kotlin）過；
  **上機回報：P0~P2 共 15 項通過**（當時那張 `../DEVICE_TEST.md` A-13 沒填就打掉了，**無書面記錄**）—— 四條關閉路徑都會
  解凍、11 格功能、第二次開選單內容會更新、四角與貼邊、劃掉 app 介面後仍可用、關懸浮再開、
  餵食後殺 app 重開餓度還在、深色／中／日／英、連開 20 次、`NOT_TOUCH_MODAL` 穿透。
  只剩量化兩項沒做：多一顆 engine 的記憶體差、第一次開選單的預熱效果（都不影響可用性）。
- 收尾：兩條分支已砍（own-window `cf2a96a` 已在主線；落選那條 `1f26574` 沒 merge，
  記錄留在本節與 `AGENTS.md`）。

---
## 2026-11-12 選單動作格、定格可摸、選單過場修正

- **6 個新小動作**（左右張望／打盹／搖擺／跳跳／伸懶腰／轉圈追尾），全部用既有素材借幀
  （`AnimationDefinition._missingFrameAlias`）。選單加 2 欄動作格（`FeedingMenuTile`）。
  隨機觸發由 `FlourishScheduler`（純邏輯、可注入 Random；每分鐘約 25%、冷卻 30 秒）；
  跳跳排在撫摸／進食之後（`_queued`）。6 條 l10n（en／ja／zh／zh_TW）。
- **選單開關動物不再閃一下**：選單裡的動物寫死 `affectionate`，`AnimalAnimator.didUpdateWidget`
  會重建 controller；改用 `controller.action`。
- **定格時摸牠改為有效**（取代 2026-11-11 ①「定格時摸牠無效」）：播撒嬌後回到摸之前的動作、
  **仍維持定格**。`playFlourish` 在定格時仍靜默無效。`feedAt` 仍會解凍（走不過去吃）。
- **選單過場**：開／關選單先藏內容、等視窗穩定才顯示；`_openMenu` 不再校準（`_roamFor`）。
  下半螢幕（選單往上長）多藏 380 ms。**體驗仍不理想**（下半螢幕約 0.4 秒空白），
  根因（TextureView 拉伸舊幀）與「別改回同視窗」的理由已併進 `AGENTS.md`「選單是另一個視窗」；
  當時評估過的三條路（第二個視窗／原生 PopupWindow／原生控制 alpha）最後走了第一條 ——
  因為它不用動 fork。
- **誤診紀錄**：「拖到下半螢幕放手後動物往上跑」不是 bug，是設定頁「區域」選了右上角。
- 驗收：`flutter analyze` 無問題、`flutter test` 185 項全過。**尚未跑完整的真機驗收單**；
  動作的手感、中文標籤是否塞得進 92 dp、ja／zh 翻譯都還沒有人確認。

## 2026-11-11 第三輪：親密度（摸牠終於有意義了）

先回答 18 個問題再寫程式（人類的條件：B 組「能換到什麼」與 D 組「每隻各一份／不遷移舊檔」）。
規格：**0~100、只漲不跌、不衰減、無等級**；唯一的**後果**是 `PetBrain` 更高機率主動撒嬌
（滿值 20%，`bond=0` 時機率與舊版逐位元組相同 —— 有測試鎖）；**不影響餓度**（判準仍只有
`PetStats.isHungryAt`，不塞第二個影響餓度的機制）；**每隻動物各一份**（KV `pet_bond_<id>`）；
舊安裝不做遷移，從 0 算。

| 動作 | 加分 | 一天額度 |
| ---- | ---- | ---- |
| 短按摸牠（`pet()` 真的觸發才算；定格時無效 → 不加分） | +2 | 3 次 |
| **真的吃下一口**（抵達食物那一刻，不是丟食物那一刻） | +5 | 2 次 |

額度是防刷用的：沒有它，連點 100 次就能把親密度刷滿，整個機制三天報廢。一天最多 +16 → 滿分約 7 天。

**計分只發生在懸浮那側**（餓度與位置的同一教訓：只有 overlay 知道寵物在做什麼）——
`PetController.onFed` 回調只有 overlay 會掛，主頁預覽塊是沙箱、在 app 裡餵食不會養親密度。
顯示：選單那條餓度列右邊一顆愛心 + 數字（不另開區塊、不新增字串 → 不必動 4 個 ARB）。

**同日的 code review 補丁**（四條全修）：`onFed` 之前完全沒測試覆蓋（餵食計分整條路徑掛在它身上），
補一題鎖住「只能在**抵達食物**那一刻觸發、一餐一次、自主行為永不會自己吃到」；`pet()` 的回傳值現在是
「這一下加不加親密度」的契約，就在「定格摸牠無效」那題一起斷言 `isFalse`/`isTrue`（之前只鎖動畫，
回傳值壞掉會變成「定格被摸一摸、隔天憑空 +6」）；`_petNow` 拿動物 id 的備援分支是死路（`_controller`
與 `_resource` 同一個 setState 一起換）→ 改成 guard 把不變式寫進碼；刪掉下載的動物現在會連
`pet_bond_<id>` 那列 KV 一起清（`AnimalDownloadService.remove` 是唯一的刪除路徑，靠它才清得乾淨）。
兩個回歸都用「故意把程式改壞」驗證過會紅。

新增 `lib/domain/pet_bond.dart`（純計分 + encode/decode）與 `test/pet_bond_test.dart` 12 題
（額度、跨天歸零、封頂、encode/decode 守住額度、壞資料回 null、bond=0 回退舊機率、
滿值 20%、餓時親密度無效、亂傳負值/超大不搞壞機率）。`flutter test` 155 → **167** 全過、
analyze 0、debug APK ✅。**真機未測**：當時排的 A-12 清單（隨 `../DEVICE_TEST.md` 刪除；含 A-12c：
用 adb 把 bond 灌成 100，看牠會不會自己撒嬌 —— 這才是「有沒有後果」的驗證）。

---
## 2026-11-11 repo 衛生：版控裡不寫機器名

本案 repo 是 public，文件裡直接寫了那台 Linux/aarch64 開發機的主機名，屬基礎設施資訊。
README 3 處、REVIEW 2 處、CHANGELOG 1 處改寫成「Linux/aarch64 開發機」；中性詞對上哪台機器的
對照表搬到 `~/dennys/AGENTS.md` 新增的「文件用詞」節（那支檔不在版控裡）。
新增 `test/repo_hygiene_test.dart`：掃 `git ls-files` 的文字檔，命中機器名/IP/帳號/金鑰檔名就紅
（禁詞用串接寫，測試不會掃到自己；附「掃太少也算失敗」的防呆，與自我驗證：塞一個進去的確會紅）。
其他 token（IP、帳號、proxy、私鑰）實掃 0 命中。

⚠️ **清的是工作樹與之後的 commit，公開歷史改不掉**：`origin/main` 與 7 條已 push 的 commit
（含 `36fea6d` 的 commit message）裡還有那台機器的主機名。要徹底根除得 rebase/`git filter-repo` + force push，
那是另一件事；這條測試的價值是「以後不會再新增」。

---
## 2026-11-11 第二輪：互動與餓度的手感（①③④＋②B）

`flutter analyze` 0 issue、`flutter test` 154 全過（151 → 154）、debug APK 編過。
討論過程與被否決的選項全記在 `TODO.md`「互動與餓度」那一節；當時的 A-11 真機清單已隨 `../DEVICE_TEST.md` 刪除（未執行）。

- **②B 餓的判定 `>=` → `>`，並收成單一來源**：`PetStats.isHungryAt(hunger, threshold)` 是現在
  唯一的判準，`PetStats.isHungry`、`_setHunger` 的跨門檻通知、`setHungryThreshold`、以及
  `HungerBar` 自己重算的那份全部改走它（以前 PetStats 與 HungerBar 各寫一份 `>=`，改一邊必漏
  另一邊 → 會變成進度條紅著、寵物卻在睡覺）。
  **解的是**：餵食量是常數 40，餓透（100）餵一次剛好落在門檻 60 上，`>=` 判成「仍然餓」→
  要餵兩次才脫餓，而餓的時候 PetBrain 絕不睡覺 → 使用者餵完看到牠照常只走不睡，像餵了沒反應。
  現在餵一次就恢復正常。
- **① 定格時摸牠改為完全無視**：`PetController.pet()` 開頭 `if (_frozen) return;`。
  舊行為是照樣把 action 改成撒嬌，而 `_onTick` 在定格時不倒 hold → 卡在撒嬌最後一幀直到解凍，
  「定格＝動作固定不動」被破掉。放在 controller（不是 overlay 的 guard）是因為預覽塊與選單的
  「撫摸」列也都走 `pet()`，根因修一次。
- **③ hold 貼著動畫長度**：撒嬌 2s→1.2s（動畫 3 幀×300ms=0.9s）、進食 3s→**0.9s**（動畫 0.6s）。
  `loop: false` 的動作播完就停在最後一幀，多出來的 hold 就是肉眼可見的「乾等」—— 舊的 1.1s／
  **2.4s** 看起來像卡畫面。兩個數字變成 `_affectionateHold`／`_eatingHold` 常數並在註解寫明
  「改 animation.json 的幀數/速度要連這裡一起改」。
- **④ 拖曳不再播撒嬌**：`beginDrag()` 的 action 改 `sit`（坐著被拎）。以前拖曳與撫摸播同一支
  動畫，從外觀分不出來。沒有測試鎖住舊行為，所以 0 題測試需改。

**當場決定不動的**（理由都寫進 TODO 了，別再從零討論）：單擊 300ms 雙擊辨認期（保留乾淨手勢語意）、
睡覺只有 4~7 秒（等真機玩過）、「餓了絕不睡」（人類決定保留的產品定義，由 `pet_brain_test:16` 鎖住）、
餵食會偷偷解凍、餵食量與門檻的耦合、`hungerMinutesUntilHungry` 下限 1 分鐘。

---
## 2026-11-11 REVIEW 修復（第 3 份報告）：記位置、拖曳誤判、選單位置污染

`flutter analyze` 0 issue、`flutter test` 151 全過（132 → 151，+19：DragWatch 8、位置節流 8、getAll 合併 3）、
`flutter build apk --debug --target-platform android-arm64` ✅。**真機仍然零次** —— 這批改的正好是
只能上機驗的東西，當時的驗收步驟寫在 A-10（含 A-9c 期待反轉那條）；該單已隨 `../DEVICE_TEST.md` 刪除，未執行。

- **#1（Must）「記位置」整個是假的**：`PetController` 從來沒讀過原生的 `startPosition`，第一次 tick
  就把視窗抓回 `bounds.center`；加上首次載入必然要校準 `_roamFor`（此刻 `_controller` 還是 null，
  搬不回來）→ 每次開懸浮看得見「舊位置 → 左上角 → 右下角 → 中央」。現在 `_loadAnimal` 在 `_roamFor`
  **之前**讀一次 `currentPosition()` 當初始位置（讀不到才退回中央），`_roamFor` 加收 `anchor:`
  量完搬回同一個錨點，掛上 controller 後再 `_moveWindowQuietly` 以夾進 zone 的實際位置對齊一次。
- **#2（Must）走動時摸牠被誤判成拖曳**：判定基準從 `controller.position`（每 16ms 就在動，
  200 px/s 時一跳 3.2px > 2px 門檻，還疊著方法通道延遲）換成「視窗自己第一次的讀值」。整個狀態機
  抽出成 `domain/drag_watch.dart`（純邏輯），`test/drag_watch_test.dart` 8 題鎖住「寵物在走、
  視窗不動 → 一次 drag 都不能有」—— 換了基準之後這個 bug 在結構上就回不來。已知代價不變
  （舊驗收單 A-8：拖曳中停頓 >400ms 算放手，只確認「不會更糟」）。
- **#3（Must）存下來的是選單的位置**：主 app 的 `OverlayService._rememberPosition()` 整個刪掉
  （`close()` 不再有 `rememberPosition` 參數）—— 主 app 只看得見視窗左上角，選單開著時那個座標是
  選單的、比寵物高約 156px。位置一律由 overlay 這個唯一知情者存：走動時節流（5 秒／50px，靜止完全不寫）、
  收選單與按結束 `force` 必寫。節流判定抽成 `domain/position_throttle.dart`（純邏輯 + 8 題測試：靜止不寫、
  慢走要累積距離、時間與基準要一起重設），餓度與位置的 DB 寫入則收進同一個 `_writeWithRetry`（SQLITE_BUSY 重試）。
- **#4**：CI 改 `flutter test --coverage`。之前沒加 → `coverage/lcov.info` 根本不存在，Codecov 那步
  綠燈上傳空資料，等於裝了個假儀表板。
- **#5**：`DELETED.txt` 那四支檔案是**第三次**被宣稱已刪（上兩條 CHANGELOG 都寫了「真的刪掉」）而實際
  還在版控裡。這次由 `git rm` 落地：`android/.../com/dneko/app/OverlayService.kt`(177 行)、
  `assets/dneko.png`、`lib/domain/pet_display_mode.dart`、以及 `DELETED.txt` 自己。同一個 repo 有兩支
  `OverlayService` 的情況結束。
- **#6**：`getAll()` = DB 列 ∪ `builtIns`（同 id 以 DB 為準；純函式 `mergeBuiltIns` + 3 題測試）。
  `seedBuiltIns()`／`insertBuiltIns()`／onUpgrade 的 `oldVersion < 3` 分支，連「加新動物要記得 bump
  `petDbVersion`」那個永遠不會紅的坑一起消失（約 −25 行）。⚠️ 代價：**刪掉 DB 裡的內建列不會再讓牠
  消失**（舊驗收單 A-9c 的期待已反轉）；目前 UI 沒有刪內建的路徑，要做之前得先加一欄「使用者隱藏」。
- **#8**：`_applySettings` 的 cascade 跨 `await` 打在同一個（可能已被 `_loadAnimal` 換掉並 dispose 的）
  controller 上 → 改成先存區域變數、`await` 後 `identical` 才准套設定（本檔其他處早就在防這類競態）。
- **#11 / #12**：`_loadAnimal` 補 `_menuTimer?.cancel()`（否則 6 秒後會醒過來對新 controller 多搬一趟）；
  `overlay_main` 那句「showOverlay 的 enableDrag 已關」改對（其實是 true，拖曳由原生做，Dart 只輪詢
  跟讀）—— 那句註解正好壓在全案最容易搞錯的那段上面。
- **#13**：刪掉零呼叫者的死 API：`PetController.dragTo()`（測試改用真正的拖曳路徑 `syncFromWindow`
  ＋ `endDrag`，比原本測得準）、`appLog()`、`OverlayWindow.resize()` 的 `enableDrag` 參數（連介面宣告）。
  ⚠️ 報告點名的 `AnimalResource.copyWith()` **沒刪** —— 它不是零呼叫者，`pet_state_persistence_test`
  靠它驗「換版重下載後 AnimationLoader 快取要失效」，而且那個被批「無條件設成 now()」的 `updatedAt`
  正是該測試成立的條件。報告那一條是錯的。
- **#14**：`HomePage` 改依賴 `IOverlayService` 並在構造子開放注入（未注入時仍用真的 `OverlayService`）。
  留介面、補注入點，而不是照報告把介面刪掉 —— AGENTS.md 的 D 條寫的就是這件事。

**沒做**：#10（`petTick` 16→33ms）—— 為一個沒有測量的收益去動全域 tick（`speedPerTick`／`_hold`／
`PetStats` 全吊在它上面），先量到再說。#9（keystore 離線副本）**做不了**：那台 Linux/aarch64 開發機上根本沒有金鑰，
詳見 README「Release signing」的遺失風險那段（文件原本宣稱有，已改）。

## 2026-11-11 review 修復 + 餓的門檻改成設定（分鐘）

`flutter analyze` 0 issue、`flutter test` 132 全過（115 → 132，+17：safeName / locale / 門檻 / updateBounds）。

- **餓的門檻改成設定**（`PetSettings.hungerMinutesUntilHungry`，單位分鐘，1~100，預設 60）：
  主頁加 slider、存進 settings JSON、push 給 overlay 即時生效（`PetStats.setHungryThreshold`，
  只在 isHungry 翻轉時通知）；預覽塊沙箱也跟著走。`HungerBar` 改收 `threshold` 參數，
  變紅的顏色跟 isHungry 同一個來源。衰減速率仍固定 1 點/分鐘（`PetStats.defaultHungerPerSecond`）。
- **REVIEW #1（Must）**：換動物時 `_loadAnimal` 先 `_stopDragWatch` 再 dispose 舊 controller；
  `_pollDrag` 在 await 後加 `mounted + identical` 閘（controller 被換掉/ dispose 時不再碰它）。
- **REVIEW #2（Must）**：`_closeMenu` 不再無條件清 roam 快取 —— 加 `_roamCalibrated` 旗標，
  只有 fallback（未校準）才清；實測值保留，開選單不再瞬移兩個角落。`_roamFor` 的 catch
  也標 calibrated=false（校準失敗不再被當真實值快取）。
- **REVIEW #3（Must）**：quit 競態 —— overlay `_quitApp` 改存**寵物**位置（`controller.position`；
  選單開著時視窗左上角是選單的位置，比寵物高約 200px）且**先存再送 quit**（主 app 一收到就關服務，
  存盤還在飛會被中斷）；主 app 的 quit 分支改 `close(rememberPosition: false)` + 2s timeout 再 pop。
- **REVIEW #4**：live 餓度 push 改寫獨立的 `_liveHunger`，不再蓋 DB 讀的 `_savedHunger`；
  「更新 HH:mm」標籤只跟 DB 那份走，live 值顯示「即時」；overlay 關閉時清 live 值回退到 DB。
- **REVIEW #5**：把 2026-11-09/11-10 兩條 entry 宣稱已刪、實際還在 git 的死碼**真的刪掉**：
  `android/.../OverlayService.kt`（177 行）、`assets/dneko.png`（255 KB）、`lib/domain/pet_display_mode.dart`、
  `OverlayService.collapsedSize`。README 補一句商店目前停用（`kStoreEnabled = false`）。
- **REVIEW #6**：`_AnimalPicker` 渲染 `snap.error`（DB 讀不到不再空白）；商店回來後 key 變讓清單重查；
  `_apply` 加 try/catch + SnackBar（設定寫入失敗不再只進 logcat）。
- **REVIEW #7**：`PetController.updateBounds` 把 `_position`／`_target` 夾回新 bounds（zone 切換不瞬移）。
- **REVIEW #8**：`_safeName` 公開成 top-level `safeName` 並補測試（`..`、絕對路徑、分隔字元）；
  新增 `localeOfCode` 測試。（`decodeHunger` 的格式測試原本就有，在 pet_state_persistence_test。）
- **REVIEW #9**：`main` 與 `runOverlayApp` 都補 `FlutterError.onError`（framework/render 例外走
  reportError、不會 rethrow 進 zone，只靠 runZonedGuarded 抓不到）；overlay 入口也包 runZonedGuarded。
- **REVIEW #10**：`_writeHungerQuietly` 加一次重試（兩條連線寫同一個 DB 檔可能撞 SQLITE_BUSY）。
- **REVIEW #11**：刪 `AnimalRepository.getDownloaded`（介面＋實作＋兩個 test fake）、
  `AnimalAnimator.onComplete`（連同只為它存在的 `_onStatus`）。`AnimalResource.copyWith` **保留**
  （review 說 0 引用，但 pet_state_persistence_test 有用）；`IOverlayService` 也保留（AGENTS.md
  列名的架構縫，不是死碼）。
- **REVIEW #12**：pubspec 的 cat/、dog/ assets 重複列刪掉。
- **REVIEW #13**：`_feedDropDistance = 120` 兩處重複收進 `domain/pet_settings.dart` 的 `feedDropDistance`。
- **REVIEW #14**：`'zh-TW' → Locale` 的拆開從 main.dart / overlay_main.dart 兩處收進
  `domain/locale_code.dart` 的 `localeOfCode`。
- **REVIEW #15**：`asset_frames_test.dart` 的亂碼測試名與 reason 重打（原字元是 U+FFFD，已不可恢復，
  依測試邏輯重寫）。
- **REVIEW not-listed 三條**：`HungerBar` 改收 `threshold`（見上餓度設定條）；`_roamFor` catch 標
  calibrated=false（見上 #2 條）；`animation_loader.dart` 尾註更新（pushSettings → `_onData` 的換動物
  路徑其實是通的，只是 store 關著用不到）。

**未做**：REVIEW #8 的「抽出 `_onData` 的 decode 分支」——那是 755 行 overlay 入口的大重構，
本機沒有真機可驗，風險大於收益；safeName / locale / decodeHunger 三塊純邏輯已有測試。

---
## 2026-11-10 真機測試後的 6 項修復（自 TODO.md 歸檔，2026-11-13）

當時 TODO 裡這一節全部做完，按本檔案的慣例（「做完就搬到 CHANGELOG，別堆在 TODO 吃 token」）搬過來：

1. **主頁餓度即時化**：overlay 餓度變化經 `shareData({'cmd':'hunger','value':X})` push 給主 app，
   主頁用獨立的 `_liveHunger` 顯示（不蓋掉 DB 讀的 `_savedHunger`，2026-11-11 修正）；DB 存盤仍 60s 節流。
   label 語意：live 值顯示「即時」，「更新 HH:mm」只跟 DB 那份。
2. **Size bug（close→restart）**：engine 是 cached 的，payload dedup 會跳過 `_applySettings`
   （含 `_resizePetWindow`）→ 動物停在舊尺寸。修法：dedup 跳過時仍補跑一次 `_resizePetWindow`。
3. **A-2／A-7 拖曳不夾 zone**：`syncFromWindow` 拖曳中不 clamp（視窗要跟手），`endDrag` 放手時才
   `_clampToBounds` 夾回 zone 邊界。
4. **A-9a 換動物不再丟定格與位置**：`_loadAnimal` 在 dispose 舊 controller 前抓 `_frozen`＋`_position`
   掛給新的（`PetController` 構造子加 `position`、`PetControllerFactory.create` 加 `position`/`frozen`），
   position 夾進新 bounds。
5. **A-6a 選單餓度列沒出現**：當時判為「裝置 APK 過舊」（HungerBar 是無條件畫的）。
   **2026-11-13 真機結案** —— 選單頂部那條餓度列在 A-13 的多個項目裡反覆看過（含飽食度更新、深色）。
6. **A-4b topInset（差半個動物到頂）已修**：`fallbackRoam` 頂端補 `defaultStatusBarHeightDp`（25dp）；
   `_closeMenu` 只清**未校準**的 roam（`_roamCalibrated` 旗標，2026-11-11 的修正 —— 無條件清會讓每次
   開選單都重新量、寵物在兩個角落之間瞬移，REVIEW #2）。calibrated 路徑已含狀態列偏移，不可再加。

---
## 2026-11-10 four user-visible fixes (device checks still zero)

- `animal_animator.dart`: `didUpdateWidget` also watches `definition`/`resource`. Switching
  animal while the action stays `sit` used to keep drawing the previous animal
  (`test/animal_animator_test.dart` fails on the old code: dog folder + cat frame).
- `animal_download_service.dart`: wipe `animals/<id>/` before downloading, so a half-failed
  re-download cannot leave a new manifest next to old frames (`_verifyAssets` only checks names).
- `animal_repository.dart`: `seedBuiltIns()` seeds only when the table is empty, so deleting a
  built-in animal survives the next launch (shortcut: a newly added built-in will not appear
  for existing installs). `static_store_catalog.dart` no longer lists built-in `penguin`.
- `home_page.dart`: the 20 s hunger poll is skipped unless the app is resumed.
- ~~`pet_display_mode.dart` deleted (0 references)~~ —— 當時**沒有真的刪**（檔案還在 git），
  2026-11-11 才刪；stale "only one built-in animal" comment fixed。

---
## 2026-11-09 本輪：把審查報告的缺口做掉（代碼面，commit `0f56ce9`）

`flutter analyze` 0 issue、`flutter test` 92 全過（85 → 92，+4 預覽塊 / +3 previewBounds）。
**逐條都還沒在真機跑過** —— 驗收單後來集中到 `../DEVICE_TEST.md`（2026-11-16 已刪，從未填過），所以下面每一條的意義是
「程式碼這樣寫了並有單元測試」，不是「真機驗過了」。

- **README 宣稱的「App 內模式」補實作**（`presentation/widgets/pet_preview.dart`）：主頁上方一塊
  預覽塊，跑與 overlay **同一套** `PetController`／`AnimalAnimator`，短按=撫摸、雙擊=餵食、
  改速度/大小即時反映。刻意不做長按選單（選單是 overlay 限定）、忽略 zone（預覽塊沒有
  「全螢幕／僅下方」的語意）、餓度用**獨立沙箱**（共用持久化會讓「app 裡餵一口、懸浮那隻也飽」，
  還會跟 overlay 的缺席補算打架）。README 順手改掉三處不實敘述（含「餓度隨時間下降」其實是上升）。
- **餓度第一次變得看得見**：`HungerBar` 寫好以來**零個使用者** —— 代表 TODO 上那條
  「餵飽 → 殺 app → 重開，看餓度是否還在」從寫下來那天就無法執行。補兩處、走兩條獨立路徑
  好歸因：主頁那一欄讀 DB（=overlay 寫不寫得進去）、懸浮選單頂部讀活 stats（=overlay 讀不讀得回來）。
  `HungerBar` 改收 `double`（主頁那側沒有活的 PetStats，不為了顯示一個數字去 new 一個）。
- **`AnimalAnimator` 一個真 bug**：換動作時用同一個 vsync 重建 `AnimationController`，
  `SingleTickerProviderStateMixin` 第二次就斷言失敗 → 改 `TickerProviderStateMixin`。
  是預覽塊的 widget 測試第一天抓到的；**不只預覽塊，overlay 在 debug 換動作的瞬間一樣會炸**
  （release 只是剛好沒斷言，ticker 也漏在 mixin 的記錄之外）。
- **啟動防護**（`main.dart`）：`runApp()` 前那兩件會碰 DB 的事各補 try/catch，DB 損毀時用內建
  素材 + 預設設定把 app 開起來（以前是白屏崩潰到連重裝的按鈕都看不到），並加 `runZonedGuarded`
  —— 沒有後端也沒有 crash 回報的專案，logcat 是唯一支持管道。overlay 端早就有 `_readOr` 防呆，
  主 app 卻沒有，這條是把不對稱補平。
- **轉屏會推新尺寸給 overlay**（`home_page.dart`）：原本只聽 `resumed`、沒實作 `didChangeMetrics`，
  轉屏後 overlay 繼續用舊螢幕的校準範圍跑，寵物卡在半邊螢幕直到使用者手動開關一次。
  設定改動與轉屏現在共用 `_pushCurrentSettings()` 一條路。
- **啟動 payload 去重**：`_shareStartupData` 的 4 次延遲重送，從前每次收下來都跑一趟
  `_applySettings`（含 resize、必要時重校準）→ 寵物剛出現時看得見地抖。套過的 payload 直接丟。
- **`_resolveResource` 收進 `AnimalRepository`**：「DB 優先於內建」這個順序之前只存在於
  `overlay_main`，預覽塊要共用就得收出來（否則兩邊各養一份，遲早對不起來）。
- **`_readOr`／`_writeHungerQuietly` 的 catch 從無聲改成留 log**（新增 `utils/log.dart`，
  與 dHealth 同一套 `dhealth`／`dhealth.error` 對應的 `dneko`／`dneko.error`）：
  「DB 壞了」與「真的沒存過」在外部表現一模一樣，A-5 沒這條 log 就查不動。

**本輪沒做**：商店開放（`kStoreEnabled` 仍 false）、狗的 13 張素材、真機驗收單全部、
上架相關（`--no-tree-shake-icons`、`ios/` 死目錄、內建 cat 顯示名仍是 `'ねこ'`）—— 都在 TODO。

---

## 2026-11-06 第七輪：素材守門員（`test/asset_frames_test.dart`）

新增 10 條測試自動驗素材（`flutter test test/asset_frames_test.dart`），對應 `ASSET_PROMPT.md` 第 6 節。
**擋掉**：不是合法 PNG、無 8-bit alpha、四角全不透明（背景沒摳掉）、全透明空圖、主體貼邊被裁、
同一隻動物的兩幀位元組相同、`animation.json` 參考不存在的檔名、有圖卻沒被任何動作用到（白打包）、
六個動作缺項、以及「只有 json 沒圖卻註冊進選單」。**只示警**：各幀画布尺寸不一致、
`frameWidth/frameHeight` 與實際圖不符（現況貓就是 193×208~212×207 各不同，硬性規定會把檢查器弄成永遠紅）。
不另外拉 `image` 套件 —— 解碼/編碼都用 Flutter 自己的 codec（`dart:ui`）。

檢查器上線的第一天就抓到真問題：**小柴犬只有 `animation.json`，12 張圖全缺**，
而我上一輪剛把 dog 註冊進選單（理由是「素材存在卻選不到」—— 那個判斷錯了，素材其實不存在）。
已把 dog 從 `builtIns` 拿回（目錄與 json 留著當佔位，檢查器會一直示警提醒），
**產完圖再把那列加回來**：素材產生流程見 `ASSET_PROMPT.md`。
（檢查器本身也用「塞問題進去必須變紅」驗過：刪圖 / 兩幀複製 / 無圖卻註冊，四條斷言全數中招。）

---

---

## 2026-11-06 收尾輪：把碼內 `shortcut:` 與「還留著」的項目清掉

`flutter analyze` 0 issue、`flutter test` 76 全過（+13，見 `test/pet_state_persistence_test.dart`）。
每一條都驗過「把 bug 塞回去測試會紅」，不是怎麼跑都過的假測試。

- **內建動物的定義統一成四處→一處**（`AnimalRepository.builtIns` / `builtIn(id)`）。
  原本拆成兩處而且互相矛盾：`seedBuiltIns()` 只塞 cat 且顯示名寫成日文 `'ねこ'`（全 app 只有那行是日文），
  `overlay_main` 又自己硬編 `cat => 小花貓 / dog => 小柴犬`。
  **實際後果**：`assets/animals/dog/` 素材存在、overlay 也認得 dog，但 DB 沒這一列 →
  主頁選單讀 `getAll()`，小柴犬永遠選不到（素材白打包）。現在 dog 出現在選單裡，名字也統一。
  防呆：新增測試掃「`assets/animals/` 的資料夾 ⇔ `builtIns` 清單 ⇔ pubspec 的 assets 清單」三方一致。
- **overlay 載入順序改成 DB 優先**（原本是內建優先 → cat/dog 永遠無視 DB 裡的記錄，
  以後真開商店、同 id 換過素材就會拿錯）。DB 沒這一列（使用者刪掉了）才退回內建素材。
- **佔位貓不再是死路**：`_buildFallbackPet` 的 `onTap` 原本是 `_openMenu`，但 `_buildContent` 在
  resource/definition/controller 任一為 null 時一律回傳佔位畫面 → 「開選單」只是把視窗放大成選單尺寸、
  內容還是那顆圓，而 `_closeMenu` 再也叫不回來，使用者卡在那個大視窗上（而且沒有控制器也拖不動）。
  改成 tap = 重試載入。
  （拖曳本身仍需要控制器才能算位置；真的卡住時由主頁關掉懸浮，這是既有路徑。）
- **`AnimationLoader` 的 provider 快取有了失效機制**（碼內 `shortcut:` 移除）：載入時比對
  「version + 路徑 + updatedAt」指紋，同一 animalId 被重下載過就把該動物的 provider 從本 loader
  與 Flutter 全域 `ImageCache` 兩邊都趕掉（只清一邊沒用 —— FileImage 的 `==` 只比檔名）。
  只有 overlay isolate 會畫動物，所以同 isolate 內就處理完了。
- **餓度會補算缺席時間**（碼內 `shortcut:` 移除）：存盤改成 `{"hunger":42.5,"at":<ms>}`，
  重開懸浮時依「距上次存盤多久」補算 → 關掉 app 三天再打開，寵物不會還是飽的。
  舊格式（裸小數 `'42.00'`）仍讀得回來，但**不追溯補算**（沒有時間戳卻硬補，等於升級當下被一次餓透）。
  純函式 `PetStats.hungerAfterAbsence()`（含系統時鐘被調回的負時間）+ 格式解碼都有測試。

### 這一輪仍然不動的
- 商店：`_baseUrl` 佔位符 + manifest 沒有 INTERNET（兩件要一起改），入口由 `kStoreEnabled=false` 關著。
- 真機驗收單（上面 A 節 6 項）一項都還沒跑過；本機沒有 JDK 17+，`flutter build apk` 在這裡跑不了。
- 舊安裝已存在的 `cat` 列顯示名還是 `'ねこ'`（`ConflictAlgorithm.ignore` 不蓋使用者的資料）；
  開發機要重置就清 app 資料。app 尚未對外發布，不寫 migration。

---

---

## 2026-11-06：懸浮寵物功能（速度／大小／活動範圍／互動）落地後的待辦（已完成部分）

已完成（本輪，未 push，commit 見 `git log`）：設定頁（速度 / 大小 / 活動範圍）、
拖曳改自己實作、餵食真的走過去吃、餓度持久化、選單尺寸跟 petSize 連動、
水平走借幀（見下）。`flutter analyze` 0 issue、`flutter test` 44 全過。

---

## 2026-11-06（第二輪）：資源洩漏、空轉與不可信輸入

上架前的全案重審。架構不動，只補「會洩漏 / 會空轉 / 會被壞素材打挂」這三類。
`flutter analyze` 0 issue、`flutter test` 44 → **61 全過**。

- **`lib/overlay_main.dart`**
  - `FlutterOverlayWindow.overlayListener.listen(...)` 之前不存欄位也沒 cancel —— 存成
    `_eventSub` 並在 `dispose()` 關掉。
  - 載入加順序號 `_loadSeq`：主 isolate 送 payload 是 fire-and-forget，而 handler 中間有好多
    `await`；`if (!mounted) return` 拦不住「雨邊都還活著」，舊 payload 會蓋掉新動物，
    而且 `_driver?.dispose(); _controller?.dispose();` 在 await 之前做，兩重載疊在一起時會留下一個
    沒人接手但 **16ms timer 仍在跑**的 PetController。現在只在最後進入的那次寫入狀態。
  - payload 少了 `metrics` 之前會把整個 stream handler 炸掉（未處理例外）；現在沿用舊範圍。
- **`OverlayPetDriver`**：`moveTo` 由 unawaited 改成串行（一次只一個在飛）+ 期間的新位置記成待發；
  失敗會寫一次 log（不洗 logcat）並清掉已送記錄，下次變動重試 —— 之前平台端拒絕時只是「畫面不動」，
  沒有任何地方看得見，而且會永久卡在舊位置。
- **`PetController`**：通知收在「看得見的變化」（整數像素或動作換了）—— 之前每 16ms 一定
  `notifyListeners()`，overlay 那側固定 60 次/秒重建 widget，而桌寵大部分時間只是坐在那裡。
- **`PetStats`**：
  - 通知節流 1 點解析度（邊界與跨過門檻一定通知）。
  - **預設飢餓速度 1.0/秒 → 1/60**。舊值是：開機 **100 秒**就永遠停在 maxHunger，而餵食只贖回 40，
    於是 `isHungry` 恆為 true、`PetBrain` 永遠只選 wander/idle —— 這隻寵物再也沒睡過覺。
    現在約 1 小時變餓、100 分鐘餓透。
    ~~shortcut: 舊版本已落盤的 `hunger=100` 不會自動 decay~~ —— 收尾輪已做缺席補算（見上）；
    唯一還殘留的是「舊格式沒有時間戳，那一筆不追溯補算」，餵一次就回到正常軌道。
- **不可信輸入**（動物商店下載回來的 `animation.json`）：`AnimalAnimationDefinition`/`FrameAnimation`
  現在會擋掉空幀清單、非字串 frames、`frameDurationMs <= 0`、缺 `loop`、`actions` 空；
  認不出的動作名稱只是跳過（素材多給動作不該讓整隻動物載入失敗）。
  以前這些会一路走到 `AnimalAnimator` 的 `clamp(0, -1)` 丟 RangeError。
- **`AnimationLoader.getFrameImage` 加了 provider 快取**：之前 `build()` 每次重繪都 new 一個
  `AssetImage`/`FileImage`，Flutter 用 provider 的 `==` 做快取，所以等於**每幀把解好碼的圖攞掉重解**。
  ~~shortcut: 同一 animalId 重新下載後會繼續顯示舊圖~~ —— 收尾輪已修（見上：來源指紋 + 兩邊趕快取）。
- **删死碼**（~~2026-11-09 宣稱已刪，實際還在 git，2026-11-11 才真的刪~~）：`android/.../OverlayService.kt`
  （177 行，含 `NekoView`）、`MainActivity` 的 `com.dneko/native` MethodChannel（Dart 端沒有一處呼叫，
  這條當時是真的刪了，現行 channel 是 `com.dneko/app`）、`assets/dneko.png`（255 KB，
  根沒進 pubspec 的 assets 清單，本來就讀不到）、`OverlayService.collapsedSize`。
  懸浮視窗一律走 `flutter_overlay_window`，權限走 `permission_handler`。
- **l10n**：主頁啟動/關閉桌寵按鈕的四個字串（全 app 唯一跳過 l10n 的地方）補进 4 個 arb。
- **`edge_behavior.dart`**：雨個策略各自複製過一遍的貼邊判定收成 `isAtEdgeOf()`，容差統一成
  `edgeTolerance` 一個常數。
- `path_provider_android` 的本機 pin 從 `pubspec.yaml` 移到 `pubspec_overrides.yaml`（不進 git，
  這台機器的 path_provider 問題不該變成別人的 build 行為）。

---

---

## 2026-11-06（第三輪）：重審自己上一輪的產出

重讀一次改過的程式碼，抓出三個「上一輪的修自己就有 bug」的點（`flutter analyze` 0 issue、`flutter test` 63 全過）：

- **`PetStats` 在「已餓透」時反而變成 60 次/秒通知**：上一輪加節流時把 `if (clamped == _hunger) return;`
  一起拿掉了，於是 hunger 恆為 maxHunger 的每一幀都算出「在邊界上」→ 每幀都 notify。
  補回 early-return（有回歸測試：餓透後再 tick 600 次，通知 0 次）。
- **按「撫摸」不會播撒嬌動畫**：`pet()` 只換動作、不動位置，而 `_enter()` 不通知、`pet()` 也不通知，
  接著 hold=2s 讓 `_waitThenDecide` 連續 125 幀提前 return → 兩秒內畫面完全不會重繪。
  通知改放在 `_enter()`（`_notifyIfChanged` 會去重，不會多花）。
- **重載動物時可能卡在那個已 dispose 的舊 controller**：`_loadAnimal` 在 `await _resizePetWindow()`
  **之前**就把 `_driver`/`_controller` 關了；一旦這次載入後段失敗或被顺序號作廢，畫面就挂在一個
  關掉的 controller 上（拖不動也不會動）。改成新的一整套備妥後才關舊的，同時關掉上一個 `PetStats`
  （它是 overlay 自己 new 後注入的，`PetController._ownsStats` 不會替我們關）。
- **主頁啟動/關閉桌寵失敗時完全沒有回饋**：`_toggle` 只有 `finally`，`showOverlay()` 被平台擋掉時
  按鈕轉一輪就回復原狀，使用者與 logcat 都看不到原因。補 catch + SnackBar（l10n 四個檔都加）。

~~仍開著的小項：`_builtInResource()` 的名字與別處重複；`AnimationLoader` 快取沒有失效機制~~
—— 兩項都在收尾輪做掉了（前者整顆函式刪掉、改成 `AnimalRepository.builtIn()` 單一來源）。

---

---

## ~~待辦：overlay 拖曳抖動~~（✅ 2026-11-07 方案 (a) 已實作）

`overlay_main.dart`：`onPanDown` → 50ms 輪詢 `getOverlayPosition()`，位置變 > 2px 才
`beginDrag()` + 暫停 driver；連續 400ms 不動視為放手。以下原評估記錄留檔。

**現象**：拖曳寵物時會抖動。

**根因**：`overlay_main.dart` 的 `onPanUpdate` 用的是視窗內局部座標的 delta。Dart 每次移動視窗，局部座標就反向偏移，形成回授。

**相關事實**：
- ~~`android/.../OverlayService.kt` 是死代碼（NekoView 測試實作，MainActivity 註解已說明移除），改它無效。~~
  （2026-11-11 已刪；當時宣稱已刪但檔案還在 git。）
- 真正的懸浮窗由 `flutter_overlay_window` 1.0.2 原生層處理，`OverlayService.java` 的 `onTouch` 已用 `rawX/rawY` 拖曳，由 `enableDrag` 開關控制（目前 `overlay_service.dart` 與 `overlay_window.dart` 的 resize 都寫死 false）。
- 插件提供 `getOverlayPosition()`（回傳 dp，x/y），但原生拖曳結束時沒有回調給 Dart。

**方案 (a)，待實作**：
1. `showOverlay` 與 `resize` 改 `enableDrag: true`；選單狀態 resize 時仍用 false，避免選單被拖走後位置失同步。
2. 移除 `onPanUpdate/onPanEnd` 的 Dart 拖曳，改為 `onPanDown` 後開始輪詢 `getOverlayPosition()`（約 50 ms）。
3. 只有偵測到位置變化（與 `controller.position` 差 > 2 px）才 `beginDrag()` 並暫停 driver；否則單擊撫摸會被誤判成拖曳，導致 `endDrag()` 覆蓋撫摸動作。
4. 拖曳中以輪詢結果更新 controller 位置（新增 `syncFromWindow`，不 clamp，不 moveTo）。
5. 位置連續約 400 ms 不變視為放手：恢復 driver，呼叫 `endDrag()`。

**已知風險**：
- 若使用者拖曳中停頓超過 400 ms，會被提前判定放手，之後的拖曳可能與 Dart 的自主移動衝突。
- 原生拖曳沒有放手事件，只能靠靜止時間判斷。
- 需要真機驗證，尤其是 Android 版本差異與 dismiss 區（目前 `dismissConfig` 為 null，理論上不會出現）。

**替代方案 (b)**：fork 或 vendor 插件，在 `ACTION_UP` 時回傳事件，可徹底解決放手判定，但需要維護插件副本。

---

