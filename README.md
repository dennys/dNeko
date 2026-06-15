# dNeko 🐾

一個 ANeko 風格的桌面寵物 App（Flutter / Android）。動物可以在 app 畫面內漫遊互動，也能以系統懸浮視窗（overlay）跑遍整個桌面。

## ✨ 功能

- **自主漫遊**：動物在限定範圍內隨機走動，支援 8 方向動畫。
- **互動**：點擊撫摸、放食物餵食，並有飢餓值系統影響行為。
- **兩種顯示模式**
  - App 內模式：在應用畫面中遊玩。
  - Overlay 模式：懸浮在其他 app 之上，跑遍整個螢幕，仍可點擊互動。
- **邊緣行為**：碰到螢幕邊緣可「沿邊走」或「回頭」，由 `animation.json` 設定，資料驅動。
- **預設 + 下載**：內建貓／狗／兔，可另外下載動物素材包。
- **多國語言**：內建英文、繁體中文、日文。

## 🏗️ 架構

採分層架構，遵循 SOLID 原則：

```
lib/
├── data/          # 資料層：models / repositories / services
├── domain/        # 領域層：純邏輯（移動、決策、邊緣行為、飢餓值）
├── presentation/  # 表現層：controllers / pages / widgets
├── l10n/          # 多國語言 ARB
├── main.dart      # App 進入點
└── overlay_main.dart  # Overlay isolate 進入點
```

核心邏輯（`PetController`、`MovementEngine`、`PetBrain`、`PetStats`、`EdgeBehavior`）
與 UI 完全解耦，app 內模式與 overlay 模式**共用同一套**。

## 🚀 開始使用

### 環境需求

- Flutter SDK `>=3.0.0 <4.0.0`
- Android（overlay 模式需 `SYSTEM_ALERT_WINDOW` 權限）

### 安裝與執行

```bash
flutter pub get
flutter gen-l10n      # 產生多國語言程式
flutter run
```

### 執行測試

```bash
flutter test
```

## 🐱 新增／下載動物

每隻動物是一個資料夾，包含 `animation.json` 與各動作的 PNG 幀圖。

```json
{
  "animalId": "cat",
  "displayName": "小花貓",
  "frameWidth": 32,
  "frameHeight": 32,
  "edgeBehavior": "walk",        // walk = 沿邊走, turnBack = 回頭
  "actions": {
    "WalkUp": { "frames": ["walk_u1","walk_u2"], "frameDurationMs": 250, "loop": true }
    // ... 其他動作
  }
}
```

- **內建動物**：放在 `assets/animals/<id>/`，並在 `pubspec.yaml` 註冊。
- **下載動物**：透過 `AnimalDownloadService` 下載到本機，寫入 SQLite。

## 🌍 多國語言

語系檔位於 `lib/l10n/`（`app_en.arb` / `app_zh.arb` / `app_ja.arb`）。
新增語言：複製一份 ARB 改 `@@locale`，再執行 `flutter gen-l10n`。

## 📄 授權

MIT