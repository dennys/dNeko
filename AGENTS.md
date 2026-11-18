# AGENTS.md

給 AI 編碼代理（及人類貢獻者）的專案指南。請在動工前完整閱讀。

## 專案概觀

dNeko 是 ANeko 風格的桌面寵物 App（Flutter / Android）。動物可在 app 內或系統 overlay 上漫遊與互動。

## 語言與溝通

- 以**繁體中文**回覆與撰寫註解。
- 程式碼識別字、檔名沿用既有英文命名慣例。

## 架構分層

| 層 | 路徑 | 職責 | 可依賴 |
| ---- | ---- | ---- | ---- |
| Data | `lib/data` | models / repositories / services（DB、檔案、下載、overlay） | domain |
| Domain | `lib/domain` | 純邏輯：移動、決策、邊緣行為、飢餓、螢幕換算 | `dart:ui`（`Offset`/`Rect`/`Size`）與 `flutter/foundation.dart`（`ChangeNotifier`）；**不得 import `flutter/material.dart`** |
| Presentation | `lib/presentation` | controllers / pages / widgets | data, domain |

**規則**：domain 層不得 import `package:flutter/material.dart`（可用 `dart:ui` 的 `Offset`/`Rect`/`Size`）。

## 設計原則（務必遵守）

- **SOLID**
  - S：每個類別單一職責（如 `MovementEngine` 只算移動、`DirectionResolver` 只轉方向）。
  - O：擴充新行為用新類別（如新增 `EdgeBehavior` 策略），勿改既有。
  - L：子型別可替換父型別。
  - I：介面小而專一（`IOverlayWindow` 只管視窗、`IOverlayService` 只管 overlay 生命週期）。
  - D：高層依賴抽象介面，具體實作可注入（方便測試）。
- **KISS**：保持簡單，避免過度設計。
- **Guard Clauses**：優先用反向 if 提早 return。

## 命名規範（Sonar 相容）

| 對象 | 規則 | 範例 |
| ---- | ---- | ---- |
| 私有欄位 | `_camelCase` | `_controller` |
| 公開／保護成員、類別、列舉、介面 | `PascalCase` | `PetController` |
| 區域變數、參數 | `camelCase` | `localFolder` |
| 常數、readonly static | `PascalCase` | `MaxHunger` |
| 介面 | `I` 前綴 | `IOverlayService` |
| 泛型 | `T` 前綴 | `TItem` |

> 注意：Dart 慣例常數常用 `camelCase`/`lowerCamelCase`，本專案沿用既有 Dart 風格，但新增介面一律 `I` 前綴。

## 關鍵模組

- `PetController`：每幀 tick，協調 brain/movement/edge/stats，對外發 `notifyListeners`。
- `PetBrain` (`IPetBrain`)：決定下一個自主行為，參考飢餓值。
- `MovementEngine` (`IMovementEngine`)：朝目標移動並 clamp 範圍。
- `EdgeBehavior` (`IEdgeBehavior`)：碰邊策略，由 `EdgeBehaviorFactory` 依 `animation.json` 建立。
- `ScreenMetrics`：保存主 app 的邏輯螢幕資訊，供 overlay isolate 計算漫遊範圍。
- `OverlayService` / `OverlayWindow`：overlay 生命週期與視窗操作。

## Overlay 注意事項

- 選單（popup）是**第二個懸浮視窗**（實作見下一節）：**別改回「把寵物視窗放大來裝選單」**。
  overlay 的 Flutter view 是 `FlutterTextureView`，視窗一 resize 它就把舊尺寸的最後一幀拉伸到
  新邊框（錄影逐格有證據），開／關選單就會看到動物消失或跳位。2026-11-13 走過一次回頭路：
  resize 前先把那幀反縮（預先補償），純函式與往復測試都對，**真機體感沒改善** → 落選，
  分支已砍。要撿回來：`git branch x 1f26574` —— 它未 merge、是**悬空 commit**，`git gc --prune`
  之後就讀不到，要留就現在開 branch。驗收與教訓：`CHANGELOG.md` 2026-11-13 那幾條（原真機驗收單
  `../DEVICE_TEST.md` 已於 2026-11-16 刪除 —— 它從頭到尾一項都沒打勾）。

- 選單的開／關／6 秒逾時／指令派工住在 `presentation/controllers/menu_director.dart`（純狀態機，
  不吃 Flutter 與平台，凍結與視窗動作由呼叫端注入回調 → `test/menu_director_test.dart` 鎖得住）。
  规矩只有兩條，動選單前先看它們：`close()` **冪等且永遠還原凍結**、`open()` 失敗時先還原再把例外
  丟回呼叫端。以前這些散在 `overlay_main` 的欄位與 try/catch 裡，結果「開到一半丟例外」那條路把解凍
  擋在 `if (!_menuOpen) return` 後面 → 寵物永久凍住（cached engine 讓關掉重開也不救）。
  新增任何關閉路徑（新的關閉按鈕、新的逾時）都要走 `_menu.close()`，別繞過去自己藏 `_menuOpen`。
- **關掉懸浮不等於 isolate 沒了**：插件的 `closeOverlay` 只有 `stopService`，`OverlayService.onDestroy()`
  不銷毀 `FlutterEngineCache` 裡那顆 engine，所以 overlay 的 Dart 會繼續活著。以前這變成「寵物趁你關掉
  時去散步」——16ms 定時器繼續跳、`_rememberPosition` 每 5 秒寫 DB，下次開懸浮牠就出現在別的地方
  （`moveOverlay` 在 service 沒了時不擲例外、只回 `false`，所以完全無聲）。守這條的機制：
  `IOverlayWindow.moveTo` 一定要把那個 bool 傳上來（別改回 `Future<void>`），`OverlayPetDriver`
  連續拒絕就 `PetController.stop()`，重開時一定要有人叫 `OverlayPetDriver.restart()`
  （現在是 `overlay_main._onData`）。`stop()`/`restart()` 少接一邊的症狀是「關一次之後寵物永遠站著」。
- 選單那 6 個動作格**不分狀態一律按得下去**：定格中按下去會先解除定格再播（與餵食同一套語意，
  2026-11-17 拍板）。別再加回「按不下去」那套 —— `FeedingMenuTile.enabled` 與 `MenuPayload.frozen`
  就是為了這件事而存在的，已經一起刪掉了。
- overlay 跑在獨立 isolate；`main.dart` 必須保留 `@pragma('vm:entry-point') overlayMain()` 與 `menuMain()`
  （後者是選單那顆 engine 的入口），分別委派到 `overlay_main.dart` / `menu_main.dart`。
- overlay 載入動物走 `AnimalRepository.resolveResource()`：DB 優先（下載過的那份要贏過內建定義），
  但**讀不到 DB 會退回內建素材**（`builtIn()`）而不是把內建動物一起打回佔位圓 —— 這是 2026-11-16
  補的（`test/animal_repository_test.dart` 鎖住）：sqflite 在 overlay isolate 掛掉時，那八隻打包進
  assets 的動物仍要開得出來。下載的動物沒辦法這樣救（本地資料夾路徑只能問 DB）。
- 全螢幕漫遊用「移動小視窗」技巧：視窗只有寵物大小，靠 `moveOverlay` 移動。
- 寵物視窗的操作一律經 `_OverlayApp.window`（`IOverlayWindow`，由 `runOverlayApp` 這個組合根注入），
  **不要再在 `overlay_main.dart` 裡自己 new `OverlayWindow()`** —— 那九處就是為了讓「換一個視窗實作」
  只有一個地方要改（桌面版、或自己開 N 顆原生視窗）。訊息通道（`overlayListener` 與 `shareData`）
  目前仍直接打插件：真要換平台時那三處得一起抽，但現在沒有第二個實作者，不先造介面。
- **觸控模型：預設可觸控**（`OverlayFlag.defaultFlag` = 可觸控不搶焦點）。摸／餵／長按開選單
  三件事全掛在寵物那顆視窗的 `GestureDetector` 上，所以**別把牠改成預設穿透**：穿透的視窗收不到
  任何事件，連「使用者想拖牠」都不知道，也沒有東西能把牠切回來。逐像素命中測試 OS 不支持
  （只能逐窗）。被抱怨擋到東西 → 第一解是 zone（主頁的 `PetZone` chips），不是穿透；
  完整的拍板與代價清單寫在 TODO「多寵物」那節。
- `flutter_overlay_window` API 參數以 Android dp 為主；不要在呼叫 `moveOverlay` / `resizeOverlay` 前自行乘上 `devicePixelRatio`。

## flutter_overlay_window（2026-11-16 起改回 pub.dev 版）

現在用的是 **pub.dev 的 `flutter_overlay_window: 1.0.2`**。

> 📌 **2026-11-17 更正**：本節以前寫「`packages/flutter_overlay_window/` 那個本地 fork 已經刪掉了」——
> 那是錯的。2026-11-16 只把 `pubspec.yaml` 從 path 依賴改回 pub 版，目錄本身（含那兩記補丁，
> 23 支檔）一直留在版控裡到今天才真的 `git rm`。它是**惰性死代碼**（pubspec 不引用 → 不參與編譯），
> 但會誤導人以為還在改 fork。要撿回來：`git log --diff-filter=D -- packages` 找到那筆刪除，
> 再 `git show <該 commit>^:<路徑>` 取檔（或從 2026-11-17 之前的 zip 備份裡拿）。

為什麼曾經 fork：上游 issue #170（overlay 視窗要聽見「點螢幕其他地方」）被 maintainer
`closed as not planned`，所以自己打了兩記補丁讓選單能點外面關掉。2026-11-13 選單改成
**第二個懸浮視窗**（app 模組自己的 `MenuOverlay.kt` + 第二顆 FlutterEngine，entrypoint
`menuMain` + `lib/menu_main.dart`）之後，「點外面」由選單那顆視窗自己的
`FLAG_WATCH_OUTSIDE_TOUCH` 處理，寵物視窗那兩記補丁沒人聽了。2026-11-16 用 `curl` 抓 pub 封存
diff 過：fork 與上游**只差那兩記補丁**（`lib/`、`pubspec.yaml`、`android/src/test` 全相同），
所以整個退回 pub 版。

### 哪天又要「寵物視窗聽見點外面」

必須重新 fork（上游不會收），配方就那兩處，都在 `OverlayService.java`：

1. `onStartCommand` 的 `WindowManager.LayoutParams` flags 多加 `| FLAG_WATCH_OUTSIDE_TOUCH`
2. `onTouch()` 開頭（**必須在 enableDrag 早退之前**）：`ACTION_OUTSIDE` 時
   `flutterChannel.invokeMethod("onOutsideTap", null)` 後 `return false`

Dart 端要自己對 `MethodChannel('x-slayer/overlay')`（= `OverlayConstants.OVERLAY_TAG`）註冊
handler 收 `onOutsideTap` —— 沒有這一步，補丁只是把事件丟進空氣。

### 選單那顆 engine 有兩條坑（跟 fork 無關，pub 版照樣成立）

| 坑 | 說明 |
| ---- | ---- |
| `MenuOverlay.PET_ENGINE_TAG` | 必須等於插件的 `OverlayConstants.CACHED_TAG`（現行 `"myCachedEngine"`）。對不上**不會編譯錯誤**，只會「選單按了沒反應」—— 升插件版號時要核對這一串。 |
| 選單那顆 engine 用 `setAutomaticallyRegisterPlugins(false)` | 讓 plugin 自動註冊的話，插件的單例 `WindowSetup` 會被第二個 plugin 實例 `setMessenger` 搶走，寵物→主 app 的訊息（即時餓度、結束）就再也送不到。哪天要讓選單用 plugin，先讀 `MenuOverlay.ensureMenuEngine` 那段註解。 |

升版流程現在很單純：改 `pubspec.yaml` 版號 → `flutter pub get` → `flutter analyze` /
`flutter test` / `flutter build apk` → 核對 `CACHED_TAG` 沒變 → **上機重掃外掛本身那組**
（開懸浮、拖曳寵物、關了再開、撤權限後的行為）。

另外 `dependency_overrides` 把 `path_provider_android` 鎖在 2.2.23（Linux/aarch64 主機的 NDK/CMake
問題），升它之前先讀 pubspec 裡那段註解。

## 餓昏鬧騰（`beg` / `faint`）

給 9 歲玩的調性：**滑稽優先，不可憐**，而且**沒有死亡機制**（`PetStats` 的 hunger 封頂 100），
餵一口就結束 —— 這纯粹是一段演出，別把它做成會「養死」的壓力源。

| 要知道的 | 在哪 |
| ---- | ---- |
| 餓昏線由餓線推導（`PetStats.starvingThresholdAt`：餓線→餓透之間的 60%，預設 84 分＝不餵 84 分鐘）。**別另設第二個門檻，也別寫死「門檻 × 1.6」** —— slider 拉到 70 以上就永遠餓昏不了 | `lib/domain/pet_stats.dart` |
| 素材可以缺：`animation.json` 沒宣告 `Beg`/`Faint` 就自動借幀（**兩格都借 `sit`**；`faint` 刻意不借 `sleep` —— 已經躺平的幀看不出在裝死，而且餓昏時 brain 本來就不准睡）。**宣告了卻少圖**會被 `test/asset_frames_test.dart` 擋 | `AnimationDefinition._missingFrameAlias` |
| 兩格各 **5 秒**（`_begHold`/`_faintHold`）。**不做成「持續到餵食為止」**：餓昏的持續訊號已經是頭頂那顆氣泡，動作再釘死就讓牠整個不動，讀起來像壞掉也可憐（調性是滑稽）。要更誇張就調這兩個數字，鬧的頻率由 `PetBrain` 的餓昏機率決定 | `PetController` |
| **借幀時的「拜」與「倒」是 `AnimalAnimator` 疊的程式化作動**（`_motionFor`）：討食一伏一伏地拜（借的 sit 是 `loop: true`，會一直循環）、裝死前 55% 倒下去之後攤著（借幀的 faint 強制 `forward()`，否則會看到牠每秒重新站起來再倒）。**animation.json 一宣告 `Beg`/`Faint` 就自動停用這些疊加** —— 別把兩層同時開著（真素材在倒 + 又被轉 80 度）。守這三條的是 `test/animal_animator_test.dart` | `presentation/widgets/animal_animator.dart` |
| 叫聲：**不另外做音效檔**。`PetController.onHungerCry` 在 `_enter` 進 beg/faint 時發（摸、選單、PetBrain 自己鬧三條路都過得來 → 只掛一個地方就不會漏），overlay 那側播**同一聲叫聲降倍速**（`hungerCryRate`：討食 0.75／裝死 0.6）。餓昏時摸牠不疊聲（叫聲已由回調播過）。沒音效的動物（下載的 + penguin/racoon/sloth/monkey）照樣無聲 —— 與摸牠一致 | `overlay_main._playHungerCry`、`animal_sound.dart` |
| 選單 8 格 = `kFlourishBehaviors` ∪ `FeedingMenu._gridRows`，**兩處要一起改**（assert 會擋）。這兩格不分狀態永遠可按 —— 小孩不會等 84 分鐘才看到裝死 | `menu_payload.dart`、`feeding_menu.dart` |
| 求助氣泡畫在**寵物框內**右上角：懸浮視窗只有寵物大小，畫到框外會被視窗裁掉。缺圖時 `_BubblePainter` 現畫一顆（同配色） | `presentation/widgets/hunger_bubble.dart` |
| 出圖 prompt（含「允許道具」那段要接在主模板後面） | `ASSET_PROMPT.md` 第 9 節 |
| 餓昏時摸牠播討食而非撒嬌，且討食後面不接 `hop`（跳跳會把氣氛破掉） | `PetController.pet()` |

## Windows 桌寵版（2026-11-17 第一版，**盲寫、上機零次**）

同一個 repo、同一套 domain。入口只認 **`lib/platform/pet_platform.dart` 的 `PetPlatform.current`**
一個分岔（`main()` 裡）；要加第二個桌面平台（Linux）就加在那裡，**別在呼叫端寫 `Platform.isLinux`**。

| 位置 | 內容 |
| ---- | ---- |
| `lib/platform/windows/windows_pet_app.dart` | 桌寵 shell：整個 exe 就是那顆懸浮視窗（寵物 + 同視窗選單 + 系統匣） |
| `lib/platform/windows/windows_overlay_window.dart` | `IOverlayWindow` 的 Windows 實作（window_manager） |
| `lib/platform/windows/pet_window_geometry.dart` | 開選單時的「寵物∪選單」視窗幾何（**純函式，有測試**） |
| `windows/runner/{win32_window,flutter_window,main}.cpp` | 建立時給 `WS_EX_LAYERED\|TOOLWINDOW\|NOACTIVATE`、不自己 `Show()`、單實例 |
| **`WINDOWS.md`** | 上機 runbook：環境需求、build 指令、14 層驗收 ladder、已知取捨、改了 C++ 該懷疑什麼 |

規則（都是為了讓第二個人不必重新研究）：

- **Windows 相關的行為改了，要同時更新 `WINDOWS.md`**（ladder 或取捨表）。那支檔是上機的人唯一
  的說明書；它過時比沒有更壞。
- **`window_manager 0.5.2` / `tray_manager 0.5.2` 是指定的**：0.6+ 換了整套 API、要 Flutter 3.47+/
  Dart 3.13+，並拖 `nativeapi` 的 C++ 核心。要升就是大事，先討論；升完把坑補進本節。
- 選單在 Windows 是**疊在同一顆視窗**（不是第二顆 engine）。`MenuDirector` 是純狀態機、平台動作
  由回調注入，所以兩側共用它；指令仍走同一條 `{"action": ...}` JSON 協定 —— 別在 Windows 那側
  另開一條派工路，否則行為會分岔。
- **DB 只有一個開檔點**（`pet_database.openPetDatabase`），桌面後端的切換在
  `pet_database.databaseDirectory()`：Windows 用 `sqflite_common_ffi` + `getApplicationSupportDirectory()`
  （ffi 後端下 `getDatabasesPath()` 會退回 temp 目錄 → 重開機資料丟光）。DDL 必須繼續只有一份。
- 這台 Linux/aarch64 開發機**編不了** Windows 目標，也看不到畫面：改 Windows 代碼後，能宣稱的只有
  「analyze/test 綠」＋（若動到共用檔）Android `build apk --debug` 過。**別把 Windows 寫成「已驗證」**。
- 既有鐵律繼續成立：domain 層不得 import `flutter/material.dart`；字串進 arb；新逻辑留小測試。

## 多國語言

- 字串一律放 `lib/l10n/*.arb`，透過 `AppLocalizations` 取用，**禁止硬編字串**於 UI。
- 新增字串：先加到 `app_en.arb`（template），再補各語系，最後 `flutter gen-l10n`。
- 無狀態 widget（如 `FeedingMenu`）由外部注入字串，不直接依賴 `AppLocalizations`。

## 開發流程

```bash
flutter pub get
flutter gen-l10n
flutter analyze
flutter test
```

## 提交前檢查清單

- [ ] 通過 `flutter analyze`（無警告）。
- [ ] 通過 `flutter test`。
- [ ] 純邏輯類別有對應單元測試（domain 層）。
- [ ] 新字串已加入所有 ARB 並重新產生。
- [ ] domain 層未 import Flutter material。
- [ ] 遵循命名規範與 SOLID。
- [ ] 動到 Windows（`lib/platform/windows/`、`windows/runner/`、`window_manager`/`tray_manager` 那兩支 pin）→ `WINDOWS.md` 跟著改。
- [ ] 動到 Windows（`lib/platform/windows/`、`windows/runner/`、那兩個 pin 的套件）→ `WINDOWS.md` 跟著改。

## 建置與機器（debug / release 谁能做）

機器矩陣與 build 指令在 **README 的「建置 APK」節**（Windows 與 CI 都出得了 release；只有
Linux/aarch64 主機出不了，因為缺 AOT 的 `gen_snapshot`——是**主機**限制，不是本專案的）。
**別為了那台主機動依賴版本**，release 該在 x86-64 機器或 CI 出。
各機器環境設定見 `~/dennys/AGENTS.md`。

- `android/gradlew` 與 `gradle/wrapper/gradle-wrapper.jar` 被 `.gitignore` 排除是**正常**的：flutter 會從
  `bin/cache/artifacts/gradle_wrapper` 自動注入；真正 pin Gradle 版的是有被追蹤的 `gradle-wrapper.properties`。
  這不是 bug，別去「修」它。
- `pubspec.yaml` 的 `dependency_overrides: path_provider_android 2.2.23` 只為 Linux/aarch64 主機存在（理由寫在 pubspec 的註解裡）；
  別隨手拿掉，也別以為 x86-64 機器也需要它。
