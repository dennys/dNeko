# dNeko 🐾

一個 ANeko 風格的桌面寵物 App（Flutter / Android）。動物可以在 app 畫面內漫遊互動，也能以系統懸浮視窗（overlay）跑遍整個螢幕。

## ✨ 功能

- **自主漫遊**：動物依 `animation.json` 的 8 方向動畫在限定範圍內走動，速度／大小／活動範圍可在主頁調整。
- **互動**：
  - 短按 = 撫摸、雙擊 = 餵食（app 內與 overlay 相同）。
  - 長按（overlay）= 彈出選單：餵食／撫摸／凍結／收起／結束；點螢幕其他地方或按寵物即收起，數秒無操作也會自動收起。
- **兩種顯示模式**
  - App 內模式：在應用畫面中遊玩。
  - Overlay 模式：懸浮在其他 app 之上（需 `SYSTEM_ALERT_WINDOW` 權限），可拖曳、跑遍全螢幕，仍可點擊互動。
- **飢餓值系統**：餓度隨時間下降並影響行為，跨重開保存（依離開時數補算）。
- **邊緣行為**：碰邊「沿邊走」或「回頭」，由 `animation.json` 設定，資料驅動。
- **動物**：內建貓／狗／小企鵝，可另外下載動物素材包。
- **多國語言**：英文、簡體中文、繁體中文、日文（主頁下拉式選單，預設跟隨系統）。
- **主題**：跟随系統／淺色／深色。
- **桌面捷徑**：一鍵開關懸浮寵物。

## 🏗️ 架構

採分層架構，遵循 SOLID 原則（詳見 `AGENT.md`）：

```text
lib/
├── data/          # 資料層：models / repositories / services
├── domain/        # 領域層：純邏輯（移動、決策、邊緣行為、飢餓值）
├── presentation/  # 表現層：controllers / pages / widgets
├── l10n/          # 多國語言 ARB
├── main.dart      # App 進入點；也保留 overlayMain native entrypoint
└── overlay_main.dart  # Overlay isolate UI 實作
packages/
└── flutter_overlay_window/  # 本地 fork 的懸浮窗插件（見下方「本地 fork 插件」）
```

核心邏輯（`PetController`、`MovementEngine`、`PetBrain`、`PetStats`、`EdgeBehavior`）
與 UI 完全解耦，app 內模式與 overlay 模式**共用同一套**。

## 🚀 開發

### 環境需求

- Flutter 3.47+（Dart 3.13+）、JDK 17+
- Android SDK（overlay 模式需 `SYSTEM_ALERT_WINDOW` 權限）

### 安裝與執行

```bash
flutter pub get
flutter gen-l10n      # 產生多國語言程式
flutter run
```

### 檢查與測試

```bash
flutter analyze
flutter test
```

### 建置 APK

```bash
flutter build apk --release --target-platform android-arm64 --no-tree-shake-icons
```

只出 arm64（通用 APK 會多塞兩份引擎庫 +30MB）。CI（GitHub Actions，`.github/workflows/github_action.yaml`）會跑 analyze / test / debug+release APK 建置。

## 🔑 簽名（升級免重裝）

release 以固定 keystore 簽名。repo 是 public，因此金鑰與密碼**都不進版控**：
本地放 `android/app/debug.keystore` + `android/app/key.properties`（兩者已 gitignore，自行備份），
CI 由 repo secrets `KEYSTORE_B64`（keystore 的 base64）與 `KEY_PROPERTIES`（key.properties 內容）還原。
**keystore 遺失 = 使用者必須砍掉重裝。**

## 📦 本地 fork 插件

`flutter_overlay_window` 改用 `packages/flutter_overlay_window/`（基底 = pub 1.0.2 的 fork），
原生端加了 `ACTION_OUTSIDE` 支援，讓 overlay 選單可以「點螢幕其他地方」關掉（上游 issue #170 被拒絕，不會有官方版）。
**升級此插件前必讀 `AGENT.md` 的「本地 fork 插件」章節**：補丁清单、升版流程、手測步驟。

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

- **內建動物**：放在 `assets/animals/<id>/`，並在 `pubspec.yaml` 註冊。`animation.json` 的 frame 名稱需對應同資料夾 PNG 檔名，例如 `walk_u1` 對應 `walk_u1.png`。建議使用透明背景 PNG，尺寸以 `frameWidth` / `frameHeight` 為準。
- **下載動物**：透過商店下載到本機，寫入 SQLite。

## 🖥️ Overlay 注意事項

- `flutter_overlay_window` 會以字串尋找 `main.dart` 內的 `overlayMain()`；請保留該 entrypoint，再委派到 `overlay_main.dart`。
- Overlay 跑在獨立 isolate，內建動物直接從 assets 載入，避免啟動時依賴 SQLite plugin。
- 漫遊範圍由 overlay 端「搬到極端再讀回」實測校準（原生 WindowManager 的安全區與 MediaQuery 常對不上）。
- 快速切換 start/stop 時，UI 會鎖住按鈕等待外掛狀態同步，避免重複 show/close 造成狀態卡住。

## 🌍 多國語言

語系檔位於 `lib/l10n/`（`app_en.arb` / `app_zh.arb` / `app_zh_TW.arb` / `app_ja.arb`）。
新增語言：複製一份 ARB 改 `@@locale`，補 `l10n.yaml`／支援清單，再執行 `flutter gen-l10n`。

## 📄 授權

MIT
