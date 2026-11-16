# dNeko 🐾

[![GitHub Actions](https://github.com/dennys/dNeko/actions/workflows/github_action.yaml/badge.svg)](https://github.com/dennys/dNeko/actions/workflows/github_action.yaml)
[![codecov](https://codecov.io/gh/dennys/dNeko/graph/badge.svg?token=NRQ565J1WO)](https://codecov.io/gh/dennys/dNeko)


一個 ANeko 風格的桌面寵物 App（Flutter / Android）。主頁有一塊可以摸、可以餵的**預覽塊**；
打開懸浮後，牠會以系統懸浮視窗（overlay）跑遍整個螢幕。

## ✨ 功能

- **自主漫遊**：動物依 `animation.json` 的 8 方向動畫在限定範圍內走動，速度／大小／活動範圍可在主頁調整。
- **互動**：
  - 短按 = 撫摸（有音效的動物會叫，現行只有貓系與狗系）、雙擊 = 餵食（預覽塊與 overlay 相同）。
  - 長按（**僅 overlay**）= 彈出選單（**第二個懸浮視窗**，寵物不會被搬走）：餵食／撫摸／凍結／收起／
    結束 5 列 + **6 個小動作格**（張望／打盹／搖擺／跳跳／伸懶腰／轉圈），選單頂部一條是即時餓度
    （右邊一顆愛心是親密度）；點螢幕其他地方或按寵物即收起，6 秒無操作也自動收起。預覽塊沒有選單。
    小動作也會由 `FlourishScheduler` 自主隨機播（每分鐘約 25%、冷卻 30 秒）。
- **兩種顯示模式**
  - 主頁預覽塊：跑的是與 overlay **同一套** `PetController`，拖速度／大小滑桿即時看到結果；
    活動範圍（zone）對它無效（預覽塊沒有「全螢幕／僅下方」的語意），餓度也是**獨立沙箱**，
    在預覽塊餵食不會讓懸浮那隻變飽。
  - Overlay 模式：懸浮在其他 app 之上（需 `SYSTEM_ALERT_WINDOW` 權限），可拖曳、跑遍全螢幕，仍可點擊互動。
- **飢餓值系統**：餓度隨時間**上升**（0 = 飽、100 = 餓透）並影響行為，跨重開保存（依離開時間補算）。
  主頁那一欄是**存盤的餓度**（走 DB）、懸浮選單那條是**即時餓度**；分兩處是為了能歸因
  「overlay 寫不寫得進去」與「overlay 讀不讀得回來」。
- **親密度**：0~100、只漲不跌、每隻動物各一份；唯一的後果是越高越會**主動撒嬌**（不影響餓度）。
  計分只發生在懸浮那側（預覽塊是沙箱）。
- **邊緣行為**：碰邊「沿邊走」或「回頭」，由 `animation.json` 設定，資料驅動。
- **動物**：內建 8 隻（貓、貓 2、狗、小企鵝、愛心狗、浣熊、樹懶、猴子）；商店下載的架構在寫著、
  入口目前關著（見下方「新增／下載動物」）。
- **多國語言**：英文、簡體中文、繁體中文、日文（主頁下拉式選單，預設跟隨系統）。
- **主題**：跟随系統／淺色／深色。
- **桌面捷徑**：一鍵開關懸浮寵物。

## 🏗️ 架構

採分層架構，遵循 SOLID 原則（詳見 `AGENTS.md`）：

```text
lib/
├── data/          # 資料層：models / repositories / services
├── domain/        # 領域層：純邏輯（移動、決策、邊緣行為、飢餓值）
├── presentation/  # 表現層：controllers / pages / widgets
├── l10n/          # 多國語言 ARB
├── main.dart      # App 進入點；也保留 overlayMain / menuMain native entrypoint
├── overlay_main.dart  # Overlay isolate UI 實作（那隻寵物）
└── menu_main.dart     # 選單那顆 engine 的 UI（第二個懸浮視窗）
```

核心邏輯（`PetController`、`MovementEngine`、`PetBrain`、`PetStats`、`EdgeBehavior`）
與 UI 完全解耦，主頁預覽塊與 overlay 模式**共用同一套**。

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

**哪台機器能出什麼**（`--release` 需要 AOT 編譯器 `gen_snapshot`，Google 只發 x86-64 host 版 ——
這是**主機平台**的限制，跟本專案無關）：

| 機器 | debug | release |
|---|---|---|
| Windows（x86-64） | ✅ | ✅ 實測可裝機（需 keystore + key.properties，見下節） |
| GitHub Actions（ubuntu-latest，x86-64） | ✅ | ✅ 產在 artifacts |
| Linux/aarch64 | ✅ | ❌ 沒有 linux-arm64 的 `gen_snapshot` |

所以 Linux/aarch64 主機上日常只跑 `--debug`；**要 release 就在 x86-64 機器（Windows）出，或 push 後取 CI 的 artifact。**

## 🔑 簽名（升級免重裝）

release 以**固定的一把** keystore 簽名（同一案只准有一把：換鑰 = 舊安裝無法覆蓋升級，只能砍掉重裝）。
repo 是 public，金鑰與密碼**不進版控**：

| 位置 | 放什麼 |
|---|---|
| Windows 開發機 | `android\app\dneko.keystore` + `android\app\key.properties`（**目前唯一存活的實體檔**） |
| GitHub Actions | secrets `KEYSTORE_B64`（keystore 檔的 base64）、`KEY_PROPERTIES`（key.properties 全文） |
| Linux/aarch64 開發機 | ❌ 2026-11-11 實查**什麼都沒有**（該放的兩支檔都不存在 —— 見下方的遺失風險） |

兩處必須是**同一把**。`key.properties` 四行（`storeFile` 是**相對 `android/app/` 的路徑**，別寫成 `app/dneko.keystore`）：

```properties
storeFile=dneko.keystore
storePassword=<密碼>
keyAlias=dneko
keyPassword=<同上那個密碼>
```

> ⚠️ `keyPassword` 請填**與 `storePassword 相同**的值。實測 JDK 21：PKCS12 的 private key 是用
> **store 密碼**保護的，`keytool -genkeypair -keypass` 給不同值也不會真的分開保護 —— 之後拿那個
> 不同的值去 `getKey()` 會 `UnrecoverableKeyException: Given final block not properly padded`，
> 而 Gradle 簽名走的正是 `getKey()`（`build.gradle.kts` 直接把這四行餵給 signingConfig）。

⚠️ **不要在新機器上 `keytool -genkeypair` 另生一把** —— 簽名不同就等於換鑰，舊安裝收不到覆蓋更新。
新機器請**從 Windows 開發機**複製（Linux/aarch64 那台沒有鑰，照它抄只會失敗）：

```bash
scp <existing-machine>:<repo>/android/app/dneko.keystore   <new-machine>:<repo>/android/app/
scp <existing-machine>:<repo>/android/app/key.properties    <new-machine>:<repo>/android/app/
```
（只有第一次建立、或鑰真的遺失／作廢時，才重新生成 keystore 並**同時**更新兩個 secrets。）

CI 的 `Restore signing key` 會先清洗 secret 被判貼帶入的空白/`\r`，再用一小段 Java 做**跟 Gradle 同一條路**的
預檢：`load(storePassword)` → `getKey(keyAlias, keyPassword)`，三個值有任何一個不對就一步報錯，
不會等 Gradle 兩分鐘後才在 `:app:packageRelease` 炸 `keystore password was incorrect`。
（`keytool` 不能用：`-list` 只驗 store 密碼；`-importkeystore -srckeypass` 對 PKCS12 也驗不到 key 密碼 ——
兩種都是假綠燈，實測於 JDK 21。）

> ⚠️ 2026-11-09 換鑰：舊 `dneko` 共用鑰的密碼曾以明文寫進 `android/app/build.gradle.kts` 並 commit
> （`600ae0f` 加入、`cbb8e26` 才移除）。公開 repo 的歷史 commit 改不掉，該密碼永久視為洩漏——
> 拿到它的人能簽出可覆蓋升級舊安裝的 APK。已換發新鑰，**換鑰後的首次安裝必須先砍掉重裝**。
> CI 有防呆：貼回那把作廢的鑰（`storePassword` 等於歷史洩漏值）會被預檢直接擋下。
> 日後再洩：重生成 keystore → 更新兩個 secrets → 到這裡補一筆（同 dHealth README 的處理原則）。
>
> 📌 遺失風險（2026-11-11 實查更正）：**那台 Linux/aarch64 開發機上一把新鑰都沒有** —— `android/app/dneko.keystore`
> 與 `~/backups/dNeko-signing-20261109/` 兩處都不存在（這兩支檔名本來就在 `.gitignore` 裡，版控也追不到）。
> 本節與 `~/dennys/AGENTS.md` 之前寫的「備份在那台開發機的 `~/backups/`」是錯的，照那段 `scp` 只會複製失敗。
> 目前查得到的持有處只剩：**Windows 開發機的 `android\app\`** 與 **GitHub secrets `KEYSTORE_B64`**
> —— 而 secrets 寫進去就讀不出來，實質上等於只有一份。
> `keystore` 遺失＝所有已安裝的使用者永遠收不到更新，只能逐一通知他們砍掉重裝；這是全案唯一不可逆的風險點。
> **待辦（人手的事，不是代碼）**：從 Windows 機取 `dneko.keystore` + `key.properties`，分存三處
> （開發機／第二台機器或 NAS／密碼管理器），`sha256sum` 核對一致後把實際路徑補回這一段。

## 📦 overlay 插件（`flutter_overlay_window`）

用 pub.dev 的 `1.0.2`（2026-11-16 起）。本案曾经把它 fork 進 repo 打補丁做「點螢幕其他地方關選單」，
但選單已改成第二個懸浮視窗、自己處理點外面，補丁與 fork 都不再需要。
**升版前讀 `AGENTS.md` 的「flutter_overlay_window」章節**：兩條必核對的坑（`CACHED_TAG`、
選單 engine 不自動註冊 plugin）與上機重掃清單。

## 🐱 新增／下載動物

每隻動物是一個資料夾：`assets/animals/<id>/` 裡的 `animation.json` + **15 張 PNG**
（`sit1/2`、`walk_u1/2`、`walk_d1/2`、`walk_s1/2`、`sleep1/2`、`eat1/2`、`afct1/2/3`）。
`animation.json` 的標準模板（七個動作鍵一個都不能少，直接複製）在 **`ASSET_PROMPT.md` 第 5 節**，
產圖規格與 self-check 在同一份檔。

新增一隻內建動物是**三步**，少一步就不對：

1. 素材放進 `assets/animals/<id>/`（含 `animation.json`），`frame` 名就是 PNG 檔名（`walk_u1` → `walk_u1.png`）。
2. `pubspec.yaml` 的 `flutter.assets` 加一行 `- assets/animals/<id>/`（漏了 rootBundle 讀不到 → 整隻變佔位圓）。
3. `lib/data/repositories/animal_repository.dart` 的 `builtIns` 加 `('<id>', '<顯示名>')` —— 漏了这步
   就是「素材齊了但主頁選單選不到」（`c616eab` 踩過）。

验：`flutter test test/asset_frames_test.dart`（素材合規 + 資料夾 ⇄ `builtIns` ⇄ pubspec 三方一致）。

- **下載動物**：透過商店下載到本機，寫入 SQLite。**商店目前停用**（`home_page.dart` 的 `kStoreEnabled = false`，
  入口隱藏；原因與開放條件見該常數的註解與 TODO.md），所以現行版本只有內建動物。

## 🖥️ Overlay 注意事項

- `flutter_overlay_window` 會以字串尋找 `main.dart` 內的 `overlayMain()`；請保留該 entrypoint，再委派到 `overlay_main.dart`。
- Overlay 跑在獨立 isolate。載入動物走 `AnimalRepository.resolveResource()`：DB 優先（下載過的贏過
  內建定義），但**DB 讀不到會退回內建素材**，不會連貓都開不出來（`test/animal_repository_test.dart` 鎖住）。
  載入失敗時畫面退成佔位圓（tap = 重試），原因一律記進 logcat 的 `dneko.error`。
- 漫遊範圍由 overlay 端「搬到極端再讀回」實測校準（原生 WindowManager 的安全區與 MediaQuery 常對不上）。
- 快速切換 start/stop 時，UI 會鎖住按鈕等待外掛狀態同步，避免重複 show/close 造成狀態卡住。

## 🌍 多國語言

語系檔位於 `lib/l10n/`（`app_en.arb` / `app_zh.arb` / `app_zh_TW.arb` / `app_ja.arb`）。
新增語言：複製一份 ARB 改 `@@locale`，補 `l10n.yaml`／支援清單，再執行 `flutter gen-l10n`。

## 📋 紀錄

進行中的待辦在 [TODO.md](TODO.md)，已完成的歸檔在 [CHANGELOG.md](CHANGELOG.md)。

## 📄 授權

MIT
