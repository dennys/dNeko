# AGENT.md

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
| Domain | `lib/domain` | 純邏輯：移動、決策、邊緣行為、飢餓、螢幕換算 | 無（不依賴 Flutter UI） |
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

- overlay 跑在獨立 isolate；`main.dart` 必須保留 `@pragma('vm:entry-point') overlayMain()`，再委派到 `overlay_main.dart` 的實作。
- overlay 內建動物應直接從 assets 載入，避免啟動時依賴 SQLite plugin；下載動物才查 repository。
- 全螢幕漫遊用「移動小視窗」技巧：視窗只有寵物大小，靠 `moveOverlay` 移動。
- `flutter_overlay_window` API 參數以 Android dp 為主；不要在呼叫 `moveOverlay` / `resizeOverlay` 前自行乘上 `devicePixelRatio`。

## 本地 fork 插件（升級前必讀）

`flutter_overlay_window` 不是 pub.dev 版，是複製進 `packages/flutter_overlay_window/` 的 fork
（基底 = pub 1.0.2），用 path 依賴。**升級 = 解壓新版覆蓋後重打補丁，漏打不會編譯錯誤、
只會讓「點外面關選單」無聲失效**，务必照下表逐項核對。

上游已知不會收這個功能：issue #170（ACTION_OUTSIDE）被 maintainer closed as not planned。

補丁只有兩處，都在 `android/.../OverlayService.java`，搜 `dNeko patch` 可定位：

| # | 位置 | 內容 |
| ---- | ---- | ---- |
| 1 | `onStartCommand` 的 `WindowManager.LayoutParams` flags | 多加 `\| FLAG_WATCH_OUTSIDE_TOUCH` |
| 2 | `onTouch()` 開頭（**必須在 enableDrag 早退之前**，選單開著時 drag 是關的） | `ACTION_OUTSIDE` 時 `flutterChannel.invokeMethod("onOutsideTap", null)` 後 `return false` |

Dart 端（原版檔案、未改）：`lib/overlay_main.dart` 自己對 `MethodChannel('x-slayer/overlay')`
註冊 handler 收 `onOutsideTap`。升級時確認原生端這個 channel 名字（`OverlayConstants.OVERLAY_TAG`）
還是 `x-slayer/overlay`、且原生端沒有自己註冊同名的 Dart→native handler 之外的用途。

升版流程：下載 pub 封存（`https://pub.dev/api/archives/flutter_overlay_window-<ver>.tar.gz`）
→ 解壓覆蓋 `packages/flutter_overlay_window/`（保留例：刪除 example/ 與 test/）
→ 重打上面兩處補丁 → 手測：開選單 → 點桌面其他地方 → 選單應收起。

另外 `dependency_overrides` 把 `path_provider_android` 鎖在 2.2.23（dgx1 ARM64 的 NDK/CMake
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
