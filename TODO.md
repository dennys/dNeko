# TODO

慣例：一個待辦一段，寫清「檔案＋符號名」（**別寫行號**，改一次檔就全部爛掉）與「為什麼现在是這樣」。
**做完就搬到 `CHANGELOG.md`**（`git log` 才是權威），別堆在這裡吃 token。

## 2026-11-17 代碼審查修復之後欠的上機驗證（細節見 CHANGELOG 同一日那條）

1. **關掉懸浮後 isolate 真的停了** —— 本輪最重要的一條，而且**已經有一條真機佐證**：使用者實測
   「關掉懸浮幾秒鐘再打開，寵物出現在別的地方」。這正是 `closeOverlay` 之後 isolate 還活著的症狀
   （插件只 stopService、`onDestroy` 不銷毀 cached engine）：16ms 定時器繼續跳、寵物無形中散步、
   `_rememberPosition` 每 5 秒把新位置寫進 DB。
   修法：`OverlayWindow.moveTo` 收平台回的那個 bool，`OverlayPetDriver` 連續拒絕 3 次就
   `PetController.stop()`；重開懸浮時 `overlay_main._onData` 呼叫 `OverlayPetDriver.restart()` 喚醒。
   上機請逐項填 ✅／✗＋日期：
   - [ ] 開懸浮 → 記住位置 → 關掉 → 等 2~3 分鐘 → 再開：要在**關掉時那個位置**（修之前會跑到別處）
   - [ ] 同一時間 `adb shell top -b -n1 | grep dneko`：關掉之後 %CPU 要趨近 0
   - [ ] `adb logcat -s dneko.error`：關掉那一刻出現「懸浮視窗已不存在，停止寵物主迴圈」是**預期的**
   - [ ] 關掉→重開連做三次，每次都醒得回來（`restart()` 沒接上的話會變成「開懸浮後寵物永遠站著」，
     這是本輪最容易踩的回歸點，`test/overlay_pet_driver_test.dart` 有鎖一條）
2. **定格時那些動作格按得下去**（`test/pet_controller_test.dart`、`test/feeding_menu_test.dart` 鎖住），
   但**動作播起來的手機手感沒人評過**（跳跳／搖擺／打盹…的速度與 hold 也沒人評過）。
2b. **餓昏鬧騰（本輪新增，全部未上機）** —— 調性是給 9 歲玩的「滑稽」，好不好笑只有人眼能判：
   - [ ] 選單那兩格（討食／裝死）按下去播得完整、不會卡在最後一幀（**各 5 秒**；3 秒還在演、5.2 秒收有測試鎖，
     但「5 秒會不會太長／太短」只有人眼能判）
   - [ ] **八隻都還沒補 `Beg`/`Faint` 素材** → 借 `sit` 的幀 + `AnimalAnimator` 疊的程式化作動
     （討食一伏一伏地拜、裝死從站姿倒下後攤著）。**倒下的角度與落點是盲調的**（`_faintAngle` 1.4 rad、
     `_faintDropFraction` 0.26），請判：看不看得懂在裝死？有沒有倒到一半卡住？頭有沒有被視窗裁掉？
   - [ ] 此時**頭頂那顆氣泡仍是唯一「牠很餓」的持續訊號**：缺圖時由 `_BubblePainter` 現畫一顆，
     請判「陽春但看得出來」夠不夠，不夠就先補氣泡圖
   - [ ] 餓度條：過餓昏線變橘色 + 火苗圖示、軌道上那道刻痕看得出來嗎（這是「報信」的全部）
   - [ ] 餓昏時摸牠 → 播討食（不是撒嬌）、也不接跳跳；這下要「好笑」而不是「怪怪的」
   - [ ] 設定頁把「多久變餓」拉到最慢（100 分）：不該看到餓昏；拉到最快（5 分）：餓昏約 62 分鐘
   - [ ] 選單多兩格後高了 52px：窄屏／貼邊擺位會不會被裁（`kMenuWindowSize` 由 `contentHeight` 算）
   - [ ] 開聲音（`soundEnabled` 預設關閉，要先去設定頁開）：**摸（餓昏時）、選單按那兩格、牠自己鬧**
     三條路都要聽到叫聲，而且是同一聲叫聲壓低（討食 0.75／裝死 0.6 倍速）—— 聽起來要「低沉委屈」
     而不是「卡帶／壞掉」；餓昏時摸牠只能聽到一聲（不該疊兩聲）。
     **penguin/racoon/sloth/monkey 與下載的動物無聲是正確的**（音效表本來就沒列）
   - [ ] `assets/animals/cat2/` 那六張 `beg1-3`／`faint1-3` 是**孤兒圖**（512×512、animation.json 沒宣告）
     → `test/asset_frames_test.dart` 有兩條因此**一直是紅的**。要接就得重出 256 的圖（腳底基線對齊 sit 的
     y=223、內容高要貼近 163px），產完把 `Beg`/`Faint` 寫進 `animation.json` —— 屆時 `AnimalAnimator`
     會自動停用疊加的程式化作動（見 AGENTS.md 餓昏鬧騰那節）
3. **桌面捷徑關懸浮要連選單一起收**：選單開著時按捷徑關掉 → 螢幕上不能留一張關不掉的選單，
   且 `MenuOverlay` 那顆 engine 要跟著放掉（原生那兩行沒有任何測試，只能上機看）。
4. 2026-11-16 那組「真機零次」的還在：都要 DB／平台真的出錯才走得到的路徑 —— 包括本輪新加的
   `_resizePetWindow` 失敗 log、以及 `resolveResource`「DB 讀不到 → 退回內建素材」那條
   （正常情況不該看到那條 log）。本機造不出條件，下次上機順手掃。

## 2026-11-17 Windows 桌寵版（第一版）**上機零次**

純代碼側全綠（analyze 0、test 292、Android `build apk --debug` 不受影響），但**螢幕上會發生的事
一項都沒驗過** —— 開發機是 Linux/aarch64，編不了 Windows 目標。完整的 14 層 ladder 在
**`WINDOWS.md`**，這裡只記「最可能先壞、壞了最難查」的三條：

1. **編譯期就挂**（第 1 層）：`sqlite3` 3.x 走 Dart native assets，build 時下載 SQLite 原始碼自己編。
   → 編譯機第一次 build 一定要網路。錯誤裡有 `sqlite3`/`hooks`/`native assets` 字樣就整段貼回來；
   退路是我把 Windows 側換成 JSON 存檔（約一支檔），不用你折騰。
2. **視窗看不見 / 不透明 / 搶焦點**（第 2~4 層）：`WS_EX_LAYERED|TOOLWINDOW|NOACTIVATE` 是在
   `windows/runner/win32_window.cpp` **建立時**給的（window_manager 0.5.x 沒有 no-activate 的 API）。
   layered 視窗沒給層式屬性會整顆不畫 —— 已補 `SetLayeredWindowAttributes(...,255,LWA_ALPHA)`，
   但這是盲寫，`--debug` 跑起來「完全看不到東西」就是這條。
3. **開選單貓跳位**（第 9 層）：選單疊在同一顆視窗，視窗每次都要重算成「寵物∪選單」的並集。
   幾何是純函式且有 6 條測試鎖住（`test/windows_pet_window_geometry_test.dart`），但「測試對、
   真機跳」在 Android 選單上走過一次回頭路（見 AGENTS.md）—— 上機請特別盯這一項。

**已知沒做（不是 bug，別當缺陷回報）**：Windows 沒有設定頁（能調的在系統匣）、沒扣工作列、
商店/下載未接、開機自啟沒有、系統匣沿用 PNG（可能要換 `.ico`）。

**下一層**（ladder 全過才動）：Windows 設定視窗 → 換寵物 → 開機自啟 → 多隻同時懸浮。
另外 `windows/` 是 `flutter create` 生出來的，之後 `flutter migrate` 可能會想改它 ——
`.metadata` 已記 windows 平台，改動前先看 diff。

## 2026-11-17 各養各的上機驗證（純代碼側全綠，真機零次）

1. [ ] **各歸各的**：貓餵到飽、換狗（狗應該餓昏闹騰，因为牠的計時從上次收起來算）、再換回貓
   （貓要是飽的）。餓度與位置都要各自回來，不是帶著上一隻的走。
2. [ ] **收起來不餓**：放養中關掉懸浮 → 過 2 小時再開 → 餓度要還是在關掉那一刻的值
   （不會偷偷補算）。這條是靠 `OverlayPetDriver.onStopped` 接到的，**最容易斷的一條**。
3. [ ] **當掉會補算**：`adb shell am kill`（或直接關機）讓牠來不及存盤 → 隔段时间再開要看到
   餓度有補算。與第 2 條一起構成了 `wasDisplayed` 旗標的兩條路徑。
4. [ ] **換寵物那一刻的寫盤**：餵幾口 → 立刻換宠物 → 換回來餓度不能跳回舊值（logcat
   `dneko.error` 不該出現「收起來存盤失敗」）。
5. [ ] **刪寵物清乾淨**：刪掉一隻下載動物後重新下載同 id，親密度與餓度都要是新的（不能憑空繼承）。
6. [ ] **遷移只搬一次**：從舊版（`pet_hunger` 全域鍵）升級起來的第一次會搬給當時那隻；
   之後重開不該再動舊鍵。搬完舊鍵**故意保留**，不是没清乾淨。
7. [ ] 主頁那行餓度在換寵物後**立刻**變成新那隻的數字（不是等 20 秒輪詢）。

## 2026-11-13 選單過場：**已定案 own-window**（上機回報可用），剩下的都是次要項

兩條解法上機比過：選單另開一個視窗那條 **✅ 可用**（口頭回報 P0~P2 通過 —— 當時那張驗收單
`../DEVICE_TEST.md` 已於 2026-11-16 刪除，**逐項打勾與日期從未填過，所以這句話目前沒有書面證據**）；
同一視窗「舊幀預先補償」那條 **❌ 與改動前體感相同**，分支已砍（`1f26574` —— 未 merge 的悬空
commit，`git gc --prune` 之後就讀不到；要留就現在 `git branch x 1f26574`）。為什麼必須另開視窗：`AGENTS.md`「選單是另一個視窗」；過程與教訓：
`CHANGELOG.md` 2026-11-13 那兩條。還欠的事：

1. **只剩量化兩項**（不影響可用性）：多一顆 FlutterEngine 的記憶體差、第一次開選單的預熱效果。
2. ✅ **fork 已整個刪除、改回 pub.dev 的 `flutter_overlay_window: 1.0.2`**（2026-11-16）。
   代碼側驗過：analyze 0、`flutter test` 全過、debug APK 編得過。
   **欠一次上機重掃外掛本身那組**：開懸浮、拖曳寵物、關懸浮再開、撤權限後的行為
   （換的是插件的原生碼來源，雖然 diff 證明只差兩記死補丁）。
   另：Windows 那台第一次 build 要能從 pub.dev 抓這個套件。
3. ✅ **定格時那 6 個動作格：2026-11-17 拍板改成「照樣按得下去，按了先解除定格再播」**
   （`test/feeding_menu_test.dart` ＋ `test/pet_controller_test.dart` 鎖住）。
   上面那條「仍待決定：選單裡按動作該不該把定格解凍再播」就是這個 —— 定了：要解凍，
   與餵食同一套語意（按選單是明確互動）。代價：`MenuPayload` 不再需要 `frozen`、
   `FeedingMenuTile.enabled` 整個消失（沒有人再會把格子設成不可按）。
另外：
- 「動物被夾到某個固定位置」**先查設定頁的「區域」**，多半不是程式 bug（`zoneBounds` 會把可漫遊
   範圍縮成小方框，`endDrag` 的 `_clampToBounds` 就把它夾回去）。判斷依據：診斷面板的
   `b=` 遠小於 `roam=` 就是這個。實測過一次：設定被選成「右上」。（設定頁選了區域後沒有明顯
   提示，容易忘記 —— 可考慮非「全螢幕」時在主頁給個標記。）
- ~~中文標籤塞不塞得進 92 dp、ja／zh 翻譯~~ —— ✅ 2026-11-13 上機回報過（中／日／英各開過選單，
  同樣沒留書面記錄）。只剩「新動作的手感」沒人評過（跳跳／搖擺／打盹那六個的速度與 hold）。

## 2026-11-11 互動與餓度：本輪決定與留下的待辦

本輪做了 ①定格時摸牠無效（**2026-11-12 已改為定格時摸牠有效**，見 CHANGELOG）、③撒嬌/進食的 hold 貼著動畫長度、④拖曳改播 sit、②B 餓的判定 `>=`→`>`
（細節見 CHANGELOG 同一日那條）。以下這些是**看過、量過、當場決定不做**的，寫下來是為了別每次
重讀代碼時又從零討論一遍。

### 1. 親密度（**已實作，真機未驗**）
2026-11-11 拍板的規格：0~100、**只漲不跌**、不隨時間衰減、無等級；每隻動物各一份
（KV `pet_bond_<animalId>`）；舊安裝不遷移、從 0 算。計分只在懸浮那側（預覽塊是沙箱）：
摸 +2（一天最多計 3 次）、真的吃下一口 +5（一天 2 次）—— 額度是**防連點刷分**，一天最多 +16。
唯一的**後果**是 `PetBrain` 主動撒嬌的機率（滿值 20%）；**不進餓度那條路**（判準仍只有
`PetStats.isHungryAt`）。真機尚未驗過（原 A-12 清單隨 `../DEVICE_TEST.md` 一併刪除）。

仍待／明確不做（等真機證明那 20% 撒嬌看得出差異再說，現在做都沒有資料可調）：
等級與文案、解鎖新動作／新幀（要產圖，最貴）、扣分與時間衰減、跨動物共享、
愛心的文字標籤（要補 4 語系 l10n key）、選單那行改成即時刷新（目前是開選單那一刻的快照，
餓度條本來就這樣）。

### 2. 行為機率寫進每隻動物（`PetBrain` 現在全案共用一組 45/30/25）
`PetBrain.decideNext`（`lib/domain/pet_brain.dart`）是寫死的三個數字，所以八隻內建動物個性完全相同。
`AnimalAnimationDefinition` 已經有 `edgeBehavior` 這種「個性」欄位，加一組權重是順理成章的擴充：
`animation.json` 加 `behaviourWeights: {wander, idle, sleep}`（缺欄位就用現在的預設），
`IPetBrain.decideNext` 收一個權重參數。**現在只有一組數，做了也沒資料可調**，等真要做出
「那隻比較愛睡」的差異時再動。

### 3. 餵食量與「多久變餓」的耦合 —— ✅ 已修（2026-11-13，見 CHANGELOG）
`feed()` 預設改成**餵到飽**（hunger 歸零），設定頁那個 slider 現在講的是真話：
餵完能安靜的分鐘數＝門檻值。留個紀錄防止走回頭路：**別改成 `amount ?? hungryThreshold`** ——
門檻設 20 時從餓透（100）餵一次只降到 80，還是餓 → 要連按 5 次才脫餓，又變回「餵了沒反應」。
`pet_stats_test` 已把那三個門檻（20/60/90）的「餵完撐多久」鎖住。

### 4. ✅ `hungerMinutesUntilHungry` 下限 1 分鐘 = 「永不睡」開關（已修）
門檻設 1 分鐘 → 幾乎恆為餓 → 餓的時候 `PetBrain` 0% 睡覺（見下面第 5 條）→ 牠永遠只走不睡。
**已做**：`PetSettings.minHungerMinutes`（`lib/domain/pet_settings.dart`）已從 1 抬到 **5**，
`fromJson` 會把舊安裝存的 1 夾上來（理由寫在該檔註解）。留這段只是為了別再把它調回 1。

### 5. 「餓了絕不睡」是人類決定保留的（2026-11-11）
`PetBrain.decideNext` 的 `isHungry` 分支：`isHungry` 時 70% wander / 30% idle、**0% sleep**，
由 `test/pet_brain_test.dart:16`（`expect(decision.behavior, isNot(PetBehavior.sleep))`）鎖住。
提議過的「餓時也留 10% 睡覺」被**否決** —— 現行的產品定義是「餓到死也要找食物」。
⚠️ 連帶要知道的：本案**沒有自動食物**（`goToFood` 只能由使用者雙擊觸發），所以餓透又不餵的
宠物是一個「只走不睡」的終端狀態，不會自己recover。②B（`>=`→`>`）已經把「餵一次就脫餓」補起來了，
這條留着是因為它是行為定義、不是 bug。要反轉就先改那題測試，別讓它無聲漂移。

### 6. 定格裡餵食會偷偷解凍（現況保留）
`PetController.feedAt()` 明確寫了 `_frozen = false`（餵食是明確動作，否則走不過去吃）。
所以按了選單「暫停」之後雙擊餵食，會讓定格默默失效、牠自己走起來。（原先與「定格時摸牠無效」是同一個
問題的兩面；2026-11-12 起定格時摸牠已有效，只剩餵食會解凍這一面。）本輪選擇保留（理由：餵食是明確互動），**要改的兩個方向**：
(a) ✅ 已做（2026-11-13）：選單網格下方那行小字 `menuFeedUnfreezes`（「餵食會解除定格」）；
    2026-11-17 起 `playFlourish`（選單那 6 格）也跟餵食一樣會解凍 —— 所以「默默失效」的範圍變大了，
    但換來的是定格中選單不再殘廢一半。小字仍只寫餵食，因為按動作格時選單當場收掉、
    寵物立刻開始動，原因一眼就看得出來；
(b) 餵食不解凍、吃飽後繼續定格（要處理「定格裡走不過去食物」→ 得先解凍吃完再凍回去，複雜）。

### 7. 單擊 300ms 辨認期、睡覺只有 4~7 秒（人類決定：不動）
- 300ms：同一個 `GestureDetector` 掛了 `onDoubleTap`，單擊要等 `kDoubleTapTimeout` 才觸發
  （`test/pet_preview_test.dart:116` 就特意 `pump(350ms)` 才收得到）。改 `onTapDown` 可以立刻反應，
  代價是雙擊的第一下也會先撒嬌 —— **決定不動**，保留乾淨的手勢語意。
- 睡覺 4~7 秒（`PetBrain.decideNext` 的 sleep 分支）：醒來就重抽，所以盯著看 30 秒可能一次都沒看到。
  **決定不動**，等真機玩過再決定要不要拉長。

## 2026-11-11 review 仍開著的

三份審查報告（最後一份 2026-11-11，15 條）都逐條處理完，結算寫在 `CHANGELOG.md` 的
「2026-11-11 REVIEW 修復」那條 entry（連報告自己講錯的三處都反駁過）；報告檔案本身已刪 ——
內容全數搬走，留著只是過時的行號與敘述。剩下三條：

1. **REVIEW #8 剩餘：`_onData` decode 分支抽出測試**
   `overlay_main.dart`（900+ 行）的 payload dedup、`_loadSeq` staleness gate、`_readOr` fallback、
   `_roamFor` 校準仍無測試。純邏輯三塊已補（`safeName` / `localeOfCode` / `decodeHunger`，2026-11-11）。
   抽出 `_onData` 的 decode 分支是這個 900+ 行入口的大重構，本機沒有真機可驗，風險大於收益，擱置。
   做的那天：decode 抽成純函式 + 表列測試，可參考 `domain/drag_watch.dart`／`placeMenuWindow` 的抽法。
2. **REVIEW #10 剩餘：SQLITE_BUSY／overlay isolate 能不能用 sqflite**（口頭回報正常，**無書面記錄**）
   2026-11-13 上機回報過「用選單餵食 → 殺 app → 重開，餓度還在」，但當時那張驗收單沒填就結案了。
   寫路徑走共用的 `_writeWithRetry`（2026-11-11）。⚠️ 位置與餓度同一條路（overlay isolate 寫 DB），
   這條壞了兩者一起壞 —— 下次上機優先掃它。
3. ~~**已知殘留 edge case：主頁按「關閉」時若 overlay 選單開著，存的是選單位置**~~
   **已修（2026-11-11，REVIEW #3）**：主 app 的 `OverlayService._rememberPosition()` 整個刪除
   （`close()` 不再有 `rememberPosition`），位置一律由 overlay 存：走動時節流
   （`domain/position_throttle.dart`）＋收選單／按結束 `force`。主 app 不需要再被告知寵物在哪。
   ⚠️ 新的依賴：位置與餓度同一條路（overlay isolate 寫 DB），第 2 條真機驗不過時兩者一起失效。

## 待辦：多寵物（2026-11-07 評估完，人類決定暫緩，只留記錄）

現況 `flutter_overlay_window` 只有**一個** overlay 視窗，所以同時只能有一隻寵物。

> 📌 2026-11-17 更正認知：這是**插件的實作限制，不是 Android 的限制**。插件的 `OverlayService`
> 是 `static instance`、`onStartCommand` 看到第二張就先關第一張、Dart API 全程沒有 windowId。
> OS 那邊要幾顆給幾顆 —— 選單那顆視窗就是我們自己用原生 `addView` 開的（`MenuOverlay.kt`），
> 已經真機跑過 N 顆視窗 + 多顆 engine 這組原語。

### 參考：ANeko Reborn（github.com/pass-with-high-score/ANeko）的實證
- 每隻寵物 = 一個**原生小視窗**（ImageView 逐幀），不是 Flutter 視窗。
- 觸控**不是**動態 touch region —— 是整個視窗在「可觸控 / 穿透」兩個 flag 之間切換。
- 所以「一隻擋滑鼠、一隻可摸」那種需求，原生派也做不到逐像素，只能逐窗。

### 路線 D2（評估結論，實作估 2.5–3 天）
- 自家 Kotlin Service 開 N 個原生視窗當**純顯示器**（貼圖 + 播動畫素材），MethodChannel 回報
  觸控/拖曳/座標；`PetController` / `PetBrain` 全部留在 Dart 端不动 —— 行为邏輯只有一份，
  原生只畫圖。`flutter_overlay_window` 退役。
- 被否決的替代：每寵一個 Flutter overlay（插件不支持、重量也爆）；原生全權 AI（行為邏輯
  要 Kotlin 重寫一份，兩邊腐）。
- **觸控模型已拍板（2026-11-17，人類）**：**預設可觸控**，放棄預設穿透。
  理由：摸／餵／長按開選單三件事全掛在寵物那顆視窗的 `GestureDetector` 上，穿透 = 三件一起失能；
  而穿透的視窗收不到任何事件 → 沒有輸入可以觸發「切回可觸控」，**整個功能的成本都在造一個喚醒入口**
  （捷徑／通知 action／全螢幕 watcher 三选一，且只有真機驗得動）。逐像素（只有寵物身體吃滑鼠）
  OS 不支持，直接放棄。
  - 使用者抱怨「擋到東西」時的**第一解是 zone**（`PetZone` 已有四角與 bottomBand，主頁有 chips 可選），
    不是穿透。第二解才是「閒時 `FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough)` ＋ 捷徑喚醒」。
    ⚠️ 做那天要記：`OverlayService.updateOverlayFlag` 寫的是插件的**全域單例 `WindowSetup`**，
    穿透狀態下 close→重開懸浮會**繼承穿透** —— 每次 `showOverlay` 之後要明確把 flag 設回來。
  - **`touchable` 必須是 per-animal**（跟親密度一樣走 per-animal KV），不能是全域設定：
    逐窗是唯一粒度，全域 flag 會讓兩隻一起變穿透，湊不出「一隻擋滑鼠、一隻可摸」。

---

## 2026-11-09 審查後仍開著的（代碼面；已做的都進 CHANGELOG 了）

### 1. `dependency_overrides` 是**全域** pin，不是本機 pin
`pubspec.yaml` 把 `path_provider_android` 釘在 2.2.23，而且它在 git 裡 → **CI 與 Windows
也跟著用 2.2.23**。這是刻意的決定（pubspec 的註解已寫清楚），不是漏搬：要讓它只影響 Linux/aarch64 主機，
就照 dHealth 的作法搬到本機 `pubspec_overrides.yaml`（已被 .gitignore 擋掉）。
代價記在這裡，別哪天 CI 版號對不上時才發現是這條。

### 2. ~~從商店返回後不重載動物清單~~ —— 2026-11-11 已做（REVIEW #6，見 CHANGELOG）：
商店 `onPressed` 改 `await push(...)` 後 `_pickerRefresh++`（key 變 → picker 重建重查）；
`_AnimalPicker` 也補了 `snap.error` 渲染（DB 讀不到不再空白）與 `_apply` 的 try/catch + SnackBar。
（開放商店時才有意義；`kStoreEnabled` 現在是 false。）

### 3. 預覽塊（`PetPreview`）的兩條已知限制
- app 進背景時 tick 仍舊在跑（`PetController` 只有 dispose、沒有 pause）。真機若測出明顯耗電/發熱，
  就給 `PetController` 補 pause/resume。
- 不做拖曳：預覽塊裡拖牠沒有意義（要拖去懸浮拖）。要的是能摸能餵，已經有了。

### 4. 上架前再說（2026-11-09 人類決定：上架擱置，先不排）
- `--no-tree-shake-icons`（CI 的 `Build release APK` 那步）讓 release APK 帶整套
  Material 字型；查一下是不是某個圖示需要，能拿掉就拿掉。
- `ios/` 是死重量（52K）：`flutter_overlay_window`（pub.dev 1.0.2 也只發了 `android/`）沒有 iOS
  實作，iOS runner 永遠跑不起來，留著只誤導人。
- 舊安裝的 cat 顯示名仍是 `'ねこ'`（`ConflictAlgorithm.ignore`，當初決定不寫 migration）；
  真要改名，記得**連 DB 既有那列一起改**。
- 拖曳判定是 50ms 輪詢 + 400ms 靜止：拖曳中停頓超過 400ms 會被誤判放手。根治要在原生補
  `ACTION_UP` 回調（現行做法只能是插件上游收，或自己再 fork），目前可接受（真機只口頭確認過
  「不會更糟」，無書面記錄）。

---

## 擱置中：商店下載動物是空殼（2026-11-05 人類決定：之後再做）

- `lib/data/services/static_store_catalog.dart` 的 `_baseUrl` 是佔位符 `https://example.com/animals`
  （清單現在只有 `fox` 一隻掛在它下面），所以按「下載」必然失敗。
- `android/app/src/main/AndroidManifest.xml` **沒有 `INTERNET` 權限**（現在只需要
  `SYSTEM_ALERT_WINDOW`、`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE` 三條）。
  → 真要上線時，這兩處要**一起**改，只補權限沒用。
- 已先做好的防呆（不用重複做）：`animal_download_service.dart` 的 dio 已設
  `connectTimeout 15s` / `receiveTimeout 60s`，且 `animalId` 與檔名會經 `_safeName()`
  擋掉 `..`、絕對路徑與路徑分隔字元（catalog 以後改成遠端來源時才用得上）。
- 入口已由 `lib/presentation/pages/home_page.dart` 的 `kStoreEnabled = false` 關著（AppBar 不出現商店按鈕）。

---

## 2026-11-06：懸浮寵物功能（速度／大小／活動範圍／互動）落地後的待辦

### A. 真機驗收單：**已刪除（2026-11-16），不再維護那種長清單**

`../DEVICE_TEST.md` 已刪除 —— 它從頭到尾沒有任何一項打勾或填日期，留著只會讓人誤以為「都驗過了」。
**代價**：本檔與 CHANGELOG 裡「真機 P0~P2 全過」「餓度跨重開还在」这类敘述現在都沒有書面證據，
只是口頭回報。真要驗，就照 CHANGELOG 2026-11-13 那幾條的項目臨時開一張單，**當場填 ✅／✗＋日期**，
驗完才存檔（沒填日期的打勾等於沒測）。

### B. 已知缺口（按優先序）
1. ✅ **水平走**（現況）：八隻內建動物都有 `walk_s1/walk_s2`，`WalkSide` 存在時由
   `AnimalAnimationDefinition.mirrorsSideFor()` 鏡射出向右走。`_missingFrameAlias` **仍要留** ——
   它現在服務的是斜向（借 `walkUp`/`walkDown`）與六個小動作（借 `sit`/`affectionate`），
   不是水平走；別再把它當成「補圖就刪」的遺留物。
2. ✅ **垂直基準**（2026-11-13 上機回報，無書面記錄）：`fallbackRoam` 已含 `defaultStatusBarHeightDp`，
   四角與貼邊開選單都沒出現「整体偏移一個狀態列」。
3. ✅ **overlay isolate 能用 sqflite**（2026-11-13 上機回報：用選單餵食 → 殺 app → 重開，餓度還在；
   同樣無書面記錄）。fail-safe（讀不到用預設）照樣留著。
4. **選動物**：已經做完了（`home_page.dart` 的 `_AnimalPicker` 選 → `settings.animalId` → overlay 讀它），
   八隻內建動物素材都齊（15 張）。
5. **商店下載是空殼**（見上面「擱置中：商店下載動物是空殼」）。2026-11-06 第四輪：入口先關起來 ——
   `lib/presentation/pages/home_page.dart` 的 `kStoreEnabled = false`，AppBar 不再出現商店按鈕。
   要開放時：`StaticStoreCatalog._baseUrl` 換成真站 **加上** manifest 補 INTERNET（兩件一起才有效），
   再把它改回 true；StoreController / StorePage / 下載服務 / 測試都是通的。
6. ~~`PetController.dispose()` 沒有 dispose `PetStats`~~ —— 2026-11-06 已修：controller 自己 new 的
   stats 自己關，外部注入的（overlay 傳持久化餓度那種）由注入方負責（`_ownsStats`）。
   ~~仍開著的小項：`_buildFallbackPet()` 沒掛 pan 手勢~~ —— 收尾輪處理了：佔位狀態根本沒有控制器可以
  算位置，真正的問題是 tap 會把視窗開成「選單尺寸但沒有選單」的死路，已改成 tap = 重試載入。

### C. 與其他案的一致性
- 主題已與 dHealth 對齊：兩案都用 `ColorScheme.fromSeed(seedColor: Colors.green)`。
- 若要版式也對齊 dHealth 的 `SetupScreen`（`ListTile` + `DropdownButton` + `SwitchListTile`
  + 分節標題），是 1–2 小時的工；目前 dNeko 用原生 M3 的 `Slider` + `ChoiceChip`。

---

## 2026-11-09 待辦：遷移到 Flutter Built-in Kotlin（三案共同，先拿 d2048 試）

每次 build 都噴 `applies the Kotlin Gradle Plugin, which will cause build failures in future versions
of Flutter`（guide：docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin）。
現在靠 `android/gradle.properties` 的 `android.builtInKotlin=false`／`android.newDsl=false`
（Flutter migrator 自動加的）壓住，還跑得動；等它變成 error 就會被卡死在不能升 Flutter 版，到時是被動改。

細節與步驟方向写在 **`../d2048/TODO.md`**（同一時間寫的同一件事）。**d2048 已於 2026-11-09 試通**（AGP 9.1.0；用 init script 實測 `:app` 的 `pluginManager.hasPlugin("org.jetbrains.kotlin.android")` 由 true 變 false，就真的生效了），可以照抄——
本案真正的 blocker 只有 `package_info_plus`（見下一節；`flutter_overlay_window` 已改回 pub 版、已 built-in，本案也沒有 drift／health —— 那是 dHealth 的），
但 own 的 `MenuOverlay.kt` 是 Kotlin，改動要含一次 release build 驗收（AOT 只能在 x86-64 機器或 CI 驗）。

## 2026-11-09 評估完、**保留不動**：`package_info_plus` 是本案 built-in Kotlin 的唯一 blocker

**事實（2026-11-09 查證）**
· 本案原生依賴裡，只有 `package_info_plus` 10.2.2 會被擋：它自己的 `android/build.gradle.kts` 有
  `apply(plugin = "org.jetbrains.kotlin.android")`。其餘（`path_provider_android`、`sqflite_android`、
  `flutter_overlay_window`）都已 built-in ✅ → 移除它，本案就能翻 `android.builtInKotlin=true`。
· 升版解不了：pub.dev 最新就是 10.2.2；上游 `fluttercommunity/plus_plugins` 的 main 也還套著 KGP（查於當日）。
· **決定：不 fork**（人類 2026-11-09 定的），所以只能等上游或移除依賴。
· 我們其實只用兩個欄位：`home_page.dart` 的 `_VersionTile`（`PackageInfo.fromPlatform()` → `version`
  與 `buildNumber`），而這兩個的本質是 build 時 `flutter build`
  從 `pubspec.yaml` 的 `version:` 蓋進 AndroidManifest 的 versionName/versionCode —— 打包當下就知道了，
  插件只是 runtime 用 MethodChannel 再問原生端一次。它其余的 appName/packageName/installerStore/
  buildSignature/changingPackages 與 Windows 端 fileVersion 那套，我們一個都沒用。

**四个選項與取捨（未做，留給要動的那天）**
| | 做法 | 缺點 |
|---|---|---|
| A 等上游 | 什麼都不做 | 日期未知；本案一直進不了 built-in Kotlin |
| B `--dart-define` | `String.fromEnvironment('APP_VERSION')` + build 時傳 `--dart-define=APP_VERSION=1.0.0+1` | 每台機器與 CI 都要記得傳；忘傳 UI 就顯示錯 |
| **C 小檔 + 測試**（評估時的建議） | `lib/gen/app_version.dart` 由兩行腳本從 pubspec 生，簽進版控；再加一個 test 解析 pubspec 比對，不同就紅 | 升版要重生一次（但 test 立刻擋，不會無聲說謊） |
| D 自己開 MethodChannel | 在 app 模組的 `MainActivity` 加個小 channel（`com.dneko/app` 已經在那兒，不需 fork 任何插件） | 版號邏輯離開 Dart、要兩邊除錯；而版號本來打包時就知道 → 不划算 |

**重啟這條的時機**
1. 要翻本案 `android.builtInKotlin=true` 的時候（順序見 `../d2048/TODO.md`：d2048 → dNeko → dHealth）。
2. **反向訊號**：哪天要做「偵測非官方渠道安裝／APK 被重打包」，就需要 `installerStore` 或 `buildSignature`
   （Android 專屬，只能問原生端，`dart-define` 給不了）→ 那時候就**留著這個插件等上游**，別移除。
   （搜 `installerStore|buildSignature|installer|簽章檢查` 於 TODO/AGENTS/lib：0 命中，目前純粹是關於頁顯示版號。）

**掃 blocker 的兩個坑（下次別再踩）**
· 正則要連 Kotlin DSL 的 `apply(plugin = "org.jetbrains.kotlin.android")` 一起算，只寫
  `apply plugin:'kotlin-android'` / `id("...")` 會把 plus_plugins 整派漏掉（我 2026-11-09 就漏過一次）。
· 只掃插件的 `android/build.gradle(.kts)`；遞迴掃 `android/**` 會連插件自帶的 `example/android/app/**`
  算進來 → 每個插件都假陽性。

