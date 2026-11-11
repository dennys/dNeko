# dNeko 專案審查報告（2026-11-11）

> 純審查，未改任何程式碼。上一份（2026-11-08）列的問題多半已修並進 CHANGELOG，本份只寫**新發現**；
> TODO.md 已記錄的舊項只簡短引用，不再重複。
> 本機實測：`flutter analyze` 0 issues；`flutter test` 132 題全過。

## What this repo does:

ANeko 風格的 Android 桌寵。主頁一塊預覽塊＋一個開關；開開關後寵物以系統懸浮視窗（overlay）在整個
螢幕上自主漫遊、可摸可餵可拖。核心邏輯（移動/決策/飢餓/邊緣行為）與 UI 解耦，預覽塊與 overlay 共用。

**假設的負載**：一個使用者、一支手機、一隻寵物、一個 overlay 視窗。沒有後端、沒有多併發使用者。
所有「規模」判斷都以此為基準 —— 這案不需要擔心多用戶競爭，要擔心的是**單機上的時序與座標系對不起來**。

---

## Must fix

### 1. 寵物啟動位置永遠被重設回畫面中央，「記位置」其實是假的

- **這是什麼**：`OverlayService.show()` 會讀上次存的位置、夾進螢幕，塞給 `showOverlay(startPosition: ...)`
  （`overlay_service.dart:32-44,51-61`）；關掉時 `_rememberPosition()` 存回視窗位置。
- **問題**：這條路只到原生視窗為止。overlay 的 `_loadAnimal()` 建立 `PetController` 時傳的是
  `position: oldPosition`，而第一次啟動 `oldController == null` → `position == null`
  （`overlay_main.dart:379,393`）→ `PetController` 把 `_position` 設成 `bounds.center`
  （`pet_controller.dart:42`）。`OverlayPetDriver` 掛上去後第一次 tick 就 `moveTo(center)` 蓋掉原生
  的還原位置。疊上第一次載入必然要校準 `_roamFor`（把視窗搬到 (0,0) 再搬到 (100000,100000)，
  而此刻 `_controller` 還是 null，所以搬不回來，`overlay_main.dart:310-316`），使用者每次開懸浮看到的是：
  寵物出現在舊位置 → 跳左上角 → 跳右下角 → 落在畫面中央。
- **修法**：載入前先讀一次視窗**實際**位置（`OverlayWindow.currentPosition()`），夾進 `zoneBounds` 後
  當 `PetController` 的初始 position —— `oldPosition` 這條路已經存在，只要讓它第一次就不是 null。
  `_roamFor` 量完搬回同一個錨點。約 5 行。
- **跳過的話**：存位置這個功能（含一個 DB key、三支函式、兩處測試）對外等於不存在；每次開寵物都被
  抓回中央，而且看得見三次跳躍。

### 2. 按「撫摸」對走動的寵物會被誤判成拖曳

- **這是什麼**：拖曳由原生做，Dart 端 `onPanDown` 起一個 50 ms 輪詢 `_pollDrag`
  （`overlay_main.dart:143-166`），判定「視窗有動 = 真的在拖」。
- **問題**：判定式是 `(p - controller.position).distance >= 2`（`overlay_main.dart:146`），但
  `controller.position` 自己每 16 ms 就在動 —— 速度 90 px/s 時一跳 1.44 px、上限 200 px/s 時
  一跳 **3.2 px**，而視窗永遠落後 controller 一個方法通道往返。差超過 2 px 就 `_dragging = true`
  → 關 driver + `beginDrag()`；接著 400 ms 靜止 → `endDrag()` → `_applyDecision()` 當場換掉行為。
  後果：在走動的寵物身上摸一下 = 先卡住 0.4 秒，撒嬌動作被 wander/idle 蓋掉。
  CHANGELOG 寫這個比較正是為了「避免單擊被誤判成拖曳」，但參考點本身在動，所以那個防護只在寵物
  靜止時成立（brain 45% 的決定是 wander，而且走一段要幾秒，所以多數時候牠是動著的）。
- **修法**：比較對象換成視窗**自己的前一次讀值**（`_lastWin` 第一次輪詢就存 `p`，之後都跟它比）。
  一個運算式，`_maxPreDragPolls` 與靜止判定都不用改；真拖曳照樣偵測得到。
- **跳過的話**：核心互動（摸）看起來壞一半，速度調高後 100% 觸發。

### 3. 選單開著時從主頁按「停止」，存下來的是選單的位置，不是寵物的

- **這是什麼**：選單開著時視窗被放大並往上長，左上角比寵物高 `menuHeight - petSize`
  （petSize 120 約 156 px，`overlay_main.dart:60-63,473-500`）。
- **問題**：`_toggle()` 關懸浮走的是 `close()` 預設 `rememberPosition: true`
  （`home_page.dart` `_toggle` → `overlay_service.dart:113-124`），`_rememberPosition()` 讀
  `getOverlayPosition()` 存進 DB → 存成選單左上角。選單按「結束」那條路已經用
  `rememberPosition: false` 處理掉了（CHANGELOG REVIEW #3），主頁這條漏掉；選單 6 秒才自動關，
  期間使用者完全切得到主頁去按停止。
- **修法**：位置一律由 overlay 存（`_quitApp` 已經會存寵物位置，`_closeMenu` 補一次即可），主 app 的
  `_rememberPosition()` 整個刪掉 —— 主 app 本来就不知道寵物在哪。
- **跳過的話**：現在被 #1 掩蓋（反正都跳回中央）；修好 #1 之後會變成「下次開寵物偏高，被系統夾到螢幕頂」。

---

## Should fix

### 4. CI 的覆蓋率是空的（綠燈但沒資料）

- **這是什麼**：最後一個 commit `eb29113` 加了 Codecov 上傳步驟。
- **問題**：`flutter test` 不加 `--coverage` 就不會產 `coverage/lcov.info`（本機跑完 `coverage/`
  目錄根本不存在，已實測）。工作區裡沒有 Dart 覆蓋率檔，Codecov 步驟在 CI 綠燈
  （最新 run 42831737956 第 15 步 success）但收進去的是空資料 —— 這個訊號永遠不會動。
- **修法**：`- name: Run tests` 改 `flutter test --coverage`。一行。
- **跳過的話**：裝了一個假的儀表板，之後會有人以為「覆蓋率沒變」其實是因為它沒在量。

### 5. `DELETED.txt` 列的四支檔案其實一支都沒刪掉（280 行死碼還在版控裡）

- **這是什麼**：repo 裡有 `DELETED.txt`，指示「另一台機器請刪除 REVIEW.md／
  `android/.../OverlayService.kt`／`assets/dneko.png`／`lib/domain/pet_display_mode.dart`」。
- **問題**：這四支在 `git ls-files` 裡全部還在。最糟的是 `com/dneko/app/OverlayService.kt`
  （177 行，含 `NekoView` 的無限 `postDelayed` 動畫迴圈）：它是早期原生實作的殘骸，Manifest 註冊的是
  插件的 `flutter.overlay.window.flutter_overlay_window.OverlayService`，`ToggleShortcutActivity`
  import 的也是插件那個 —— 同一個 repo 有兩個 `OverlayService`，grep 的人會被帶到錯的那支。
  它读的 `flutter_assets/assets/dneko.png` 也沒註冊進 `pubspec.yaml` 的 assets（打包根本不會進去），
  所以就算被呼叫也必然失敗。`PetDisplayMode` 整個 enum 零個引用。
- **修法**：照 `DELETED.txt` 自己講的刪掉，連 `DELETED.txt` 一起刪（它的內容已經是對內了）。
- **跳過的話**：之後要找「懸浮視窗是怎麼開的」會多花 10 分鐘，而且可能順手去改一支永遠不會跑的檔案。

### 6. 新增內建動物要手動 bump DB 版本，忘了測試不會紅

- **這是什麼**：主頁動物選單讀 `AnimalRepository.getAll()`（只讀 DB 資料列，`animal_repository.dart:14`），
  所以內建動物必須先被 `seedBuiltIns()` 寫進 DB 才選得到；既有安裝要補寫靠 `pet_database.dart:50`
  的 `if (oldVersion < 3) insertBuiltIns(db)`。
- **問題**：加一隻新動物 = 「註冊 `builtIns` ＋ pubspec assets ＋ **bump `petDbVersion`**」三件事。
  前兩件有測試擋（`asset_frames_test.dart`、`pet_state_persistence_test.dart`），第三件什麼都沒擋：
  照流程加完、analyze 綠、132 題全過，舊安裝的選單卻永遠看不到那隻。本案已經踩過一次
  （`c616eab` 加四隻就要跟著 bump 到 3）。
- **修法**：`getAll()` = DB 行 ∪ `builtIns`（依 animalId 去重，DB 優先）。這樣
  `seedBuiltIns()`、`insertBuiltIns()`、version 3 的 onUpgrade 分支、以及「版本號陷阱」一起消失
  （約 −25 行）。⚠️ 代價：「把內建動物從 DB 刪掉就不會再長回來」這個語意會消失 —— 目前 UI 沒有
  任何路徑能刪內建，所以現況沒差；如果日後要讓使用者刪內建，就要另外記一列「使用者隱藏」標記。
- **跳過的話**：每加一隻動物就多一個只能靠真機安裝舊版才發現的坑。

### 7. 拖曳判定是全案最難測的邏輯，而且完全沒有測試（792 行的 overlay_main 同時做 7 件事）

- **這是什麼**：`overlay_main.dart` 792 行，裡面住著：視窗狀態機、漫遊範圍校準、原生拖曳輪詢
  狀態機、餓度節流落盤＋重試、payload 解碼去重、選單擺位（已抽成 `placeMenu`）、佔位繪圖。
- **問題**：純的部分（`placeMenu`、`zoneBounds`、`previewBounds`、`OverlayPetDriver`）都抽出去並有測試，
  剩下沒抽的恰好是最容易錯的兩段：`_pollDrag` 的 begin/stop 狀態機（#2 就錯在這裡；TODO 另外承認
  「拖曳中停頓 >400 ms 會被誤判放手」），以及 `_writeHungerQuietly` 的重試路徑。它們測不到是因為
  長在 widget state 裡，不是因為不需要測。
- **修法**：`_pollDrag` 的決策抽成純函式（輸入：上一次視窗位置、這次視窗位置、controller 位置、poll 計數
  → 輸出 enum `{keepWaiting, startDrag, stop}`），照 `menu_placement.dart` 的格式補一組測試；
  餓度落盤那段抽成一個小類別，測試用假 repository 打。不要按行數拆，就按這兩個「職責」拆。
- **跳過的話**：#2 這類 bug 會繼續在只有真機才看得见的地方重生。

### 8. `_applySettings` 對可能已經被換掉的 controller 呼叫方法

- **這是什麼**：`_applySettings` 用 cascade 對 `_controller` 連做三件事，中間 `await _roamFor(...)`
  （`overlay_main.dart:288-292`）。
- **問題**：cascade 只在開頭讀一次 `_controller`；`await` 期間如果 `_loadAnimal` 插進來換掉／dispose 了
  controller，恢復後會對**已 dispose** 的 `ChangeNotifier` 呼叫 `updateBounds` →
  `notifyListeners()`，debug 模式直接斷言「A ChangeNotifier was used after being disposed」。
  目前商店關閉、執行期不會換動物，所以走不到；但這是本檔已經用 `stale()` 防過的那類競態，只在這
  一處漏防。
- **修法**：`await` 完再讀一次區域變數，`if (!identical(c, _controller)) return;` 再套設定。3 行。
- **跳過的話**：等商店開啟或做「執行中換動物」那天，會得到一個 debug 才出現、很難归因的斷言。

### 9. 簽章金鑰目前只有一份，而且兩份副本在同一顆硬碟上

- **這是什麼**：release 用固定 keystore 簽名，換鑰 = 舊安裝無法覆蓋升級、只能砍掉重裝。
- **問題**：README 自己寫了「目前新鑰只有 `android/app/` 與 `~/backups/` 兩份，同一台機器同一顆硬碟」。
  具體情況：那台 Linux/aarch64 開發機的碟壞掉 → 既沒 keystore 也沒備份 → 所有已安裝的使用者永遠收不到更新，
  要手動通知他們砍掉重裝。這是全案唯一不可逆的風險點。
- **修法**：再拷一份到另一台機器或密碼管理器（README 已經建議，只是沒人做）。不用寫 code。
- **跳過的話**：機率低、代價是整個安裝基地作廢。

---

## Nice to have

### 10. `petTick` 16 ms 讓視窗每幀一次平台往返

`OverlayPetDriver` 已做串行＋待發（做得對），但每個「整數像素變化」仍會觸發一次
`moveOverlay` 方法通道往返。桌寵的視覺不需要 60 fps：`petTick` 改 33 ms（`pet_settings.dart:2`，
一個常數）就少一半平台呼叫與 CPU，動畫幀由 `AnimationController` 自己管，不受影響。

### 11. 選單開著時換動物，沒 cancel 選單定時器

`_loadAnimal` 的 `setState` 把 `_state` 設回 `collapsed`（`overlay_main.dart:399-410`）但沒關
`_menuTimer`；6 秒內定時器會醒過來跑一次 `_closeMenu()`，對新 controller 做一趟多餘的
`moveAndResize`。無害，但狀態是錯的；補一行 `_menuTimer?.cancel()`。

### 12. 註解會把人帶錯方向：`overlay_main.dart:661`

寫「自己處理拖曳（showOverlay 的 enableDrag 已關）」，但 `show()` 實際是 `enableDrag: true`
（`overlay_service.dart:37`）—— 拖曳其實是**原生**做的，Dart 只是輪詢跟上去。這句註解正好在
全案最容易搞錯的那一段上面。順手改掉（或刪掉）。

### 13. 零個呼叫者的死 API

- `PetController.dragTo()`（`pet_controller.dart:108`）：lib 內零個呼叫者，只有測試在用
  （拖曳實際走 `syncFromWindow`）。連測試一起刪，測試改用 `syncFromWindow` 當位移工具。
- `appLog()`（`utils/log.dart:9`）：零個呼叫者。
- `AnimalResource.copyWith()`（`animal_resource.dart:22`）：零個呼叫者，而且它的
  `updatedAt` 無條件設成 `now()`、不讓呼叫端指定 —— 就算哪天要用也是錯的。
- `OverlayWindow.resize()` 的 `enableDrag` 參數（`overlay_window.dart:17`）：唯一兩個需要改
  enableDrag 的地方都走 `moveAndResize`，這個參數永遠是預設值。

### 14. `IOverlayService` 是只有單一實作、也沒被注入的介面

`IOverlayWindow`／`IPetBrain`／`IMovementEngine`／`IAnimalRepository` 都有 fake 或真的注入點，
值得留。`IOverlayService`（33 行）沒有：`HomePage` 直接 `OverlayService()`，測試也沒有 fake，
唯一存在的效果是多一層要跳的檔案。可以併掉。

### 15. 商店整組在 `kStoreEnabled = false` 下不可達（已知決策，這裡只是記帳）

`store_page` + `store_controller` + `animal_download_service` + `static_store_catalog` + 兩個 model
= **385 行**，加上 `dio` 這支依賴，從 UI 完全走不到。TODO 已記錄原因與開放條件，防呆也做得
像樣（`safeName` 擋路徑穿越、dio 有 timeout、半套素材會擋）。只提醒：路徑穿越的守門員有測試，
但 `remove()` 那條「fileNames 給空清單時驗證等於什麼都沒做」只写在註解裡，沒有測試擋。

---

## 做得好的地方（值得留著的判斷）

- **素材守門員測試是真貨**：`asset_frames_test.dart` 會解 PNG 查 alpha／背景不透明／兩幀同圖／
  主體貼邊被裁／孤兒圖／缺檔，而且先寫了「檢查器本身要抓得到問題（不是怎麼跑都過的假測試）」
  這組自我驗證。多數專案沒有這個層級。
- **l10n 完整**：實查 `app_zh`／`app_zh_TW`／`app_ja` 與 `app_en` 各 54 個鍵，缺 0、多 0。
  UI 沒有硬編字串（只有語言選單按業界慣例用各自母語寫死，正確）。
- **簽章這段處理得很成熟**：JCA 預檢走的是跟 Gradle 同一條路（`load` → `getKey`）、secret 清洗、
  `::add-mask::`、把已作廢的洩漏密碼直接擋掉，並在 README 寫清楚為何 `keytool` 是假綠燈。
  `allowBackup="false"` 也是對的。
- **座標系的根因判斷正確**：放棄用 MediaQuery 算漫遊範圍、改成「搬到極端再讀回來」實測，
  並在註解寫清楚為什麼 —— 這類「平台不等於你想的那樣」的知識留下来了。
- **熱路徑有被當回事**：`PetStats` 的通知粒度、`PetController._notifyIfChanged`、
  `OverlayPetDriver` 的串行＋待發、`AnimationLoader` 的 provider 快取，四處都在省 60 fps 空轉，
  而且每一處都註解了省掉的是哪一種空轉。

---

## Verdict

**健康，但有三個「使用者每天會看到」的 bug 卡在路徑上**：先修 #1（位置還原整個是假的＋每次啟動跳
三個位置）與 #2（走動時摸牠會卡 0.4 秒、撒嬌被蓋掉），#3 順手一起收。#5（DELETED.txt 那批死碼，
含一支會跟插件同名的 native `OverlayService`）半小時就能清乾淨，值得先做，之後要找東西會比較舒服。

## Lean: −約 270 行、−0 個依賴可刪。

（177 死 Kotlin ＋ 4 `PetDisplayMode` ＋ 8 `DELETED.txt` ＋ ~25 seed/version 那套 ＋ `dragTo`/`appLog`/
`copyWith`/多餘參數/`IOverlayService` ~35。`dio` 不算 —— 商店是明確保留的功能，不該為了清行數拿掉。）

## Not checked

- 沒在真機跑過：所有 WindowManager 座標/安全區行為、`_roamFor` 校準的真實跳數、overlay isolate 內
  sqflite 是否可用（`_readOr` 失敗時餓度歸零這條只能靠 logcat 驗）、_foreground service_ 在 Android
  14+ 的行為，全部依賴 `../DEVICE_TEST.md`，而 TODO 自己寫「至今一項都沒在真機跑過」。
- 沒讀 `packages/flutter_overlay_window/` 的原生實作細節（只核對 AGENTS.md 列的兩處 `dNeko patch`
  都在：`FLAG_WATCH_OUTSIDE_TOUCH` 與 `ACTION_OUTSIDE` 早退，且 `OVERLAY_TAG` 仍是 `x-slayer/overlay`），
  也完全沒跑 fork 內建的 `OverlayBoundsTest`／`DismissConfigTest`（CI 只跑 Dart 測試，這兩個原生測試
  永遠不會被執行）。
- 沒讀 `ASSET_PROMPT.md`（14 KB 的產圖提示詞）、`CHANGELOG.md` 全文、`ios/`、`assets/animals/*/animation.json`
  逐檔內容。
- 商店路徑（`store_page.dart` 的 UI 細節）只粗讀，因為它從 UI 不可達。

---

## 修復狀態（2026-11-11，本份報告的 15 條逐條結算）

`flutter analyze` 0 issue、`flutter test` 151 全過（+19）、debug APK 編過。**真機仍零次** ——
#1/#2/#3 的真實表現只能在機上驗，驗收步驟已進 `../DEVICE_TEST.md` A-10。

| # | 狀態 | 做了什麼 |
| ---- | ---- | ---- |
| 1 | ✅ 已修 | `_loadAnimal` 在 `_roamFor` 之前讀 `currentPosition()` 當初始位置；`_roamFor` 收 `anchor:` 量完搬回錨點；掛上 controller 後 `_moveWindowQuietly` 對齊。實際行數比報告估的 5 行多（錨點要穿過 `_roamFor`，還要區分首次載入／換動物） |
| 2 | ✅ 已修 | 基準換成「視窗自己第一次的讀值」，狀態機抽成 `domain/drag_watch.dart` + 8 題測試。⚠️ 報告的修法寫成「跟前一次讀值比」——那樣慢拖會永遠偵測不到、也會每拍重設基準；實作是**錨定第一次**，且另開 `_anchor`／`_lastMoved` 兩個欄位（`_lastWin` 的舊語意是「上次變動的位置」，餵給靜止計數用，混用會把 400ms 放手判定一起壞掉） |
| 3 | ✅ 已修 | 主 app 的 `_rememberPosition()` 整個刪掉，`close()` 不再有 `rememberPosition`；位置由 overlay 節流存（5 秒／50px）＋收選單／結束 force。報告沒提的風險：overlay 被主 app 直接關掉時 isolate 說沒就沒，所以「只在關閉那一刻存」會重新變成記不住位置 —— 節流存盤是為了補這個 |
| 4 | ✅ 已修 | `flutter test --coverage` 一行 |
| 5 | ✅ 已修 | 四支檔 `git rm`（含 `DELETED.txt` 自己）。這是它們第三次被宣稱已刪 |
| 6 | ✅ 已修 | `getAll()` = DB ∪ `builtIns`（純函式 `mergeBuiltIns` + 3 題測試）；`seedBuiltIns`／`insertBuiltIns`／`oldVersion < 3` 全刪。影響面比報告多一處：`store_controller` 也用 `getAll()` 決定商店顯示「已下載」，語意改變要一起記（DEVICE_TEST A-9c 的期待已反轉） |
| 7 | ✅ 做了該做的 | `_pollDrag` 狀態機抽成 `domain/drag_watch.dart`（8 題）、位置節流判定抽成 `domain/position_throttle.dart`（8 題）—— 這兩段是「只有真機才看得見」的那種邏輯。餓度／位置的 DB 重試只收進共用的 `_writeWithRetry`，沒再抽類別：它 5 行，且 host 端重現不了 SQLITE_BUSY，為了測試而抽它是假測試 |
| 8 | ✅ 已修 | 先存區域變數、`await` 後 `identical` 才准套。⚠️ 報告說「debug 直接斷言」太硬：`_notifyIfChanged` 在位置與動作都沒變時會提前 return，要 clamp 真的移動了位置才炸 |
| 9 | ❌ 做不了 | **那台 Linux/aarch64 開發機上根本沒有 keystore**（`~/backups/` 與 `android/app/dneko.keystore` 都不存在，兩支檔名在 `.gitignore` 內）。報告那條是照抄 README 的宣稱、沒人查過實際檔案。README 與 `~/dennys/AGENTS.md` 已改成實情；剩下的是人手：從 Windows 機取鑰、分存三處、`sha256sum` 核對 |
| 10 | ✗ 擱置 | 為一個沒測過的收益去動全域 `petTick`（`speedPerTick`／`_hold`／`PetStats` 全吊在上面），先量到再說 |
| 11 | ✅ 已修 | `_loadAnimal` 補 `_menuTimer?.cancel()` |
| 12 | ✅ 已修 | 那句註解改對（`enableDrag` 其實是 true，拖曳由原生做） |
| 13 | ✅ 已修（一半照抄會壞） | 刪 `dragTo()`（測試改走真正的拖曳路徑）、`appLog()`、`resize()` 的 `enableDrag`。⚠️ `AnimalResource.copyWith()` **不是零呼叫者** —— `pet_state_persistence_test:138` 用它驗「換版重下載後快取要失效」，而且那個被批的 `updatedAt: DateTime.now()` 正是該測試成立的條件；照報告刪會弄壞一題有意義的測試，保留 |
| 14 | ✅ 改了相反的方向 | 報告建議刪 `IOverlayService`，但 AGENTS.md 的 D 條白紙黑字要求高層依賴抽象介面。真正的問題是 `HomePage` 直接 new、沒有注入點 —— 已改成構造子可注入 `IOverlayService`，介面留著。沒為它寫 HomePage widget 測試：那頁 583 行要拉 DB＋l10n 骨架，成本與這條的收益不成比例 |
| 15 | — 記帳 | 維持現況（`kStoreEnabled = false`）。`remove()` 空清單那條只有註解、沒測試，已在原處留字 |

**報告本身漏的一條已一併處理**：`_openMenu` 也會觸發 `_roamFor` 校準跳躍（`_closeMenu` 清掉未校準值後，
下一次長按開選單會把寵物搬到兩個角落再搬回來）。讀位置的順序已改成「先讀位置、再校準、搬回錨點」，
並列進 DEVICE_TEST A-10d。
