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

- overlay 跑在獨立 isolate；`main.dart` 必須保留 `@pragma('vm:entry-point') overlayMain()` 與 `menuMain()`
  （後者是選單那顆 engine 的入口），分別委派到 `overlay_main.dart` / `menu_main.dart`。
- overlay 載入動物走 `AnimalRepository.resolveResource()`：DB 優先（下載過的那份要贏過內建定義），
  但**讀不到 DB 會退回內建素材**（`builtIn()`）而不是把內建動物一起打回佔位圓 —— 這是 2026-11-16
  補的（`test/animal_repository_test.dart` 鎖住）：sqflite 在 overlay isolate 掛掉時，那八隻打包進
  assets 的動物仍要開得出來。下載的動物沒辦法這樣救（本地資料夾路徑只能問 DB）。
- 全螢幕漫遊用「移動小視窗」技巧：視窗只有寵物大小，靠 `moveOverlay` 移動。
- `flutter_overlay_window` API 參數以 Android dp 為主；不要在呼叫 `moveOverlay` / `resizeOverlay` 前自行乘上 `devicePixelRatio`。

## flutter_overlay_window（2026-11-16 起改回 pub.dev 版）

現在用的是 **pub.dev 的 `flutter_overlay_window: 1.0.2`**，`packages/flutter_overlay_window/`
那個本地 fork 已經刪掉了。

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
