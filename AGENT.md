# AGENT.md

給 AI 編碼代理（及人類貢獻者）的專案指南。請在動工前完整閱讀。

## 專案概觀

dNeko 是 ANeko 風格的桌面寵物 App（Flutter / Android）。動物可在 app 內或系統 overlay 上漫遊與互動。

## 語言與溝通

- 以**繁體中文**回覆與撰寫註解。
- 程式碼識別字、檔名沿用既有英文命名慣例。

## 架構分層

| 層 | 路徑 | 職責 | 可依賴 |
|----|------|------|--------|
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
|------|------|------|
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
- `ScreenMetrics`：邏輯↔物理像素換算的唯一來源（overlay 座標校準）。
- `OverlayService` / `OverlayWindow`：overlay 生命週期與視窗操作。

## Overlay 注意事項

- overlay 跑在獨立 isolate（`overlayMain()`），需自行初始化 repository/loader。
- 全螢幕漫遊用「移動小視窗」技巧：視窗只有寵物大小，靠 `moveOverlay` 移動。
- 座標單位用 `ScreenMetrics` 換算，勿在他處散落 `* devicePixelRatio`。

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