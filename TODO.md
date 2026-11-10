# TODO

慣例：一個待辦一段，寫清「檔案:行」與「為什麼现在是這樣」。
**做完就搬到 `CHANGELOG.md`**（`git log` 才是權威），別堆在這裡吃 token。

## 2026-11-11 review（REVIEW.md）仍開著的

REVIEW.md（2026-11-10，15 條 + 4 條 not-listed）已處理完：完成的都進 CHANGELOG（2026-11-11 entry），
檔案已刪。剩下三條：

1. **REVIEW #8 剩餘：`_onData` decode 分支抽出測試**
   `overlay_main.dart`（755 行）的 payload dedup、`_loadSeq` staleness gate、`_readOr` fallback、
   `_roamFor` 校準仍無測試。純邏輯三塊已補（`safeName` / `localeOfCode` / `decodeHunger`，2026-11-11）。
   抽出 `_onData` 的 decode 分支是 755 行入口的大重構，本機沒有真機可驗，風險大於收益，擱置。
   做的那天：decode 抽成純函式 + 表列測試，`placeMenu` 的抽出模式可參考。
2. **REVIEW #10 剩餘：SQLITEBUSY 真機驗證**
   `_writeHungerQuietly` 已加一次重試（2026-11-11），但「overlay isolate 能不能用 sqflite」
   仍未在真機驗證（見下面 2026-11-06 的 B.3：餵飽 → 殺 app → 重開，看餓度是否還在）。
3. **已知殘留 edge case：主頁按「關閉」時若 overlay 選單開著，存的是選單位置**
   quit 路徑（選單按「結束」）已完全修好（overlay 先存寵物位置、主 app 不寫位置，2026-11-11）。
   但使用者開著 overlay 選單、切回主頁按「關閉」時，`_rememberPosition` 仍存視窗左上角
   （選單位置，比寵物高約 200px）→ 下次啟動寵物偏高被夾到螢幕頂。罕見路徑；根治要 overlay
   把寵物位置或選單狀態 push 給主 app（新 channel 訊息），目前不划算。

## 2026-11-10 真機測試後：6 項修復（bug + feature）

### ✅ 已完成（code + test）

1. **主頁餓度即時化**（feature）：overlay 餓度變化時經 `shareData({'cmd':'hunger','value':X})`
   push 給主 app（`overlay_main.dart` `_pushHunger`），主 app `_onOverlayEvent` 加 `cmd=='hunger'`
   分支 → `setState` 更新 `_liveHunger`（獨立欄位，不蓋 DB 讀的 `_savedHunger`；2026-11-11 修正）。
   DB 存盤維持 60s 節流。label 語義已定：live 值顯示「即時」，「更新 HH:mm」只跟 DB 那份走。
2. **Size bug（close→restart）**：engine cached，dedup `data==_lastAppliedPayload` 跳過
   `_applySettings`（含 `_resizePetWindow`）→ 動物停在舊尺寸。修法：dedup 跳過時仍補跑
   `_resizePetWindow`（`overlay_main.dart` `_onData`）。
3. **A-2/A-7 拖曳不夾 zone**：`syncFromWindow` 拖曳中不 clamp（視窗跟手），`endDrag` 放開時
   才 `_clampToBounds` 夾回 zone 邊界（`pet_controller.dart` `endDrag`）。
4. **A-9a 換動物丟定格＋位置**：`_loadAnimal` dispose 舊 controller 前抓 `_frozen`＋`_position`，
   掛到新 controller（`PetController` constructor 加 `position` 參數、`PetControllerFactory.create`
   加 `position`＋`frozen` 參數）。position clamp 到新 bounds。

### ⬜ 待做

5. **A-6a 餓度列沒出現**（本輪回歸）：sub-agent 診斷——Dart code 乾淨（HungerBar 無條件在
   `_buildMenu`），最可能是**裝置上 APK 過舊**（build 早於 `0f56ce9` 加 HungerBar 的 commit）。
   需確認裝置 About 頁版本字串 / `git describe`；若舊於 `0f56ce9`，rebuild 重測即可。
   次要可能：native height clamp + `_menuAbove==true` 時 Column `mainAxisAlignment: end`
   把 20dp 餓度列推出頂端（需 `_petSize + 281 > usableDp`，只在短螢幕/橫向觸發）。
6. **A-4b topInset**（差半個動物到頂）：✅ 已修（code + test）。
   根因：`fallbackRoam` 用 (0,0) 起點（MediaQuery logicalSize），但 overlay 視窗頂端被
   WindowManager 夾在狀態列下方（25dp）→ 回退時頂端差一個狀態列。修法：
   - `fallbackRoam` 頂端偏移 `defaultStatusBarHeightDp`（25dp，`pet_settings.dart`）。
   - `_closeMenu` 清 `_roam`/`_roamPetSize`（選單開著時 `_applySettings` 可能設成 fallback，
     關選單後下次 `_openMenu` 重新量真實 roam 範圍）。
     （2026-11-11 修正：改成只清**未校準**的 —— 加 `_roamCalibrated` 旗標；無條件清會讓
     每次開選單都重新量、寵物瞬移兩個角落，REVIEW #2。）
   注意：calibrated path（`_roamFor` 實測）已含狀態列偏移，不需再加 topInset（會 double-count）。

## 待辦：多寵物（2026-11-07 評估完，人類決定暫緩，只留記錄）

現況 `flutter_overlay_window` 只有**一個** overlay 視窗，所以同時只能有一隻寵物。

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
- **開工前要先拍板**：寵物窗預設「可觸控」還是「穿透」？ANeko 採預設穿透、點到才開觸控；
  dNeko 的摸/餵互動比較重，傾向預設可觸控、拖出螢幕才穿透。

---

## 兩段被移除的程式碼片段（commit `85c3e36`）

`lib/presentation/pages/home_page.dart`（20 行）與 `lib/presentation/widgets/pet_stage.dart`（9 行）
是兩個**從未被 import、也無法編譯**的游離片段檔 —— 檔名跟真正的實作撞名（真正的 `HomePage` 在
`lib/main.dart`），內容其實是当初寫給自己看的待辦筆記。2026-11-05 對齊工具鏈時為了讓
`flutter analyze` 與編譯變乾淨，把這兩個檔案刪掉，筆記內容搬到这里留檔。

逐條核對现在的程式碼後：**兩個想法其實都已经實作了**，只剩一條還開著。

| 筆記裡的idea | 現況 |
|---|---|
| AppBar 加一顆商店按鈕 → 開 `StorePage` | ✅ 已實作：現在在 `lib/presentation/pages/home_page.dart` 的 AppBar（由 `kStoreEnabled=false` 關著） |
| 用 `PetControllerFactory` 建立 pet controller | ✅ 已實作：`lib/overlay_main.dart:37`（`static const _controllerFactory`）與 `:105`（`_controllerFactory.create(...)`）—— 片段檔放在 `widgets/pet_stage.dart`，位置本身也是錯的 |
| **從商店返回後重新載入動物清單**（可能有新下載的動物） | ✅ 已做（2026-11-11，REVIEW #6）：商店 `onPressed` 改 `await push(...)` 後 `_pickerRefresh++`（key 變 → picker 重建 → `late final` 重新建 future 重查） |

### 待做那條的線索（2026-11-11 已做，留檔）
`HomePage` 已在 `lib/presentation/pages/home_page.dart`（2026-11-07 與設定頁合併）。實作方式：
`await push(...)` 之後 `_pickerRefresh++` + `setState`（key 帶上計數，picker 重建即重查）。

---

### 原始片段留存（方便日後接回時參考）

<details>
<summary><code>lib/presentation/pages/home_page.dart</code>（原 20 行）</summary>

```dart
  // AppBar actions 增加一顆商店按鈕：
  // actions: [_buildStoreButton(), _buildModeToggle()],

  Widget _buildStoreButton() {
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      tooltip: l10n.storeTitle,
      icon: const Icon(Icons.store),
      onPressed: _openStore,
    );
  }

  Future<void> _openStore() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StorePage(controller: widget.storeController),
      ),
    );
    // 回來後重新載入（可能有新下載的動物）
    await _loadAnimals();
  }
```

</details>

<details>
<summary><code>lib/presentation/widgets/pet_stage.dart</code>（原 9 行）</summary>

```dart
// ... import 增加：
// import '../controllers/pet_controller_factory.dart';

  static const _controllerFactory = PetControllerFactory();

  // build() 內建立 controller 的那行改為：
  // final controller = _controller ??= _controllerFactory.create(
  //   bounds: bounds,
  //   definition: widget.definition,
  // )..start();
```

</details>

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
- app 進背景時 tick 仍舊在跑（`PetController` 只有 dispose、沒有 pause）。真機 P-8
  若測出明顯耗電/發熱，就給 PetController 補 pause/resume。
- 不做拖曳：預覽塊裡拖牠沒有意義（要拖去懸浮拖）。要的是能摸能餵，已經有了。

### 4. 上架前再說（2026-11-09 人類決定：上架擱置，先不排）
- `--no-tree-shake-icons`（`.github/workflows/github_action.yaml:145`）讓 release APK 帶整套
  Material 字型；查一下是不是某個圖示需要，能拿掉就拿掉。
- `ios/` 是死重量（52K）：fork 的 `flutter_overlay_window` 只有 Android 實作，iOS runner
  永遠跑不起來，留著只誤導人。
- 舊安裝的 cat 顯示名仍是 `'ねこ'`（`ConflictAlgorithm.ignore`，當初決定不寫 migration）；
  真要改名，記得**連 DB 既有那列一起改**。
- 拖曳判定是 50ms 輪詢 + 400ms 靜止：拖曳中停頓超過 400ms 會被誤判放手。根治要 fork 插件
  補 `ACTION_UP` 回調，目前可接受（DEVICE_TEST A-8 只確認「不會更糟」）。

---

## 擱置中的兩件事（2026-11-05 人類決定：之後再做）

### 1. 「商店下載動物」目前是空殼，不能上線
- `lib/data/services/static_store_catalog.dart:5` 的 `_baseUrl` 是佔位符 `https://example.com/animals`
  （fox / dog / penguin 全部掛在它下面），所以按「下載」必然失敗。
- `android/app/src/main/AndroidManifest.xml` **沒有 `INTERNET` 權限**（現在只需要
  `SYSTEM_ALERT_WINDOW`、`FOREGROUND_SERVICE`、`FOREGROUND_SERVICE_SPECIAL_USE` 三條）。
  → 真要上線時，這兩處要**一起**改，只補權限沒用。
- 已先做好的防呆（不用重複做）：`animal_download_service.dart` 的 dio 已設
  `connectTimeout 15s` / `receiveTimeout 60s`，且 `animalId` 與檔名會經 `_safeName()`
  擋掉 `..`、絕對路徑與路徑分隔字元（catalog 以後改成遠端來源時才用得上）。
- 商店按鈕目前對使用者是可點的（`lib/main.dart` 的 AppBar action），要藏起來的話跟這條一起處理。

### 2. 狗的圖一張都沒有（13 張全缺）
`assets/animals/dog/` 只有 `animation.json`，需要但缺失的 13 張：

```
walk_u1.png walk_u2.png   walk_d1.png walk_d2.png
sit1.png    sit2.png      sleep1.png  sleep2.png
eat1.png    eat2.png      afct1.png   afct2.png   afct3.png
```

檔名規則與貓完全相同（`assets/animals/cat/` 那 13 張就是範本，貓不缺圖 ✓）。
`animation.json` 已備妥（actions: WalkUp/WalkDown/Sit/Sleep/Eat/Affectionate），
補進圖檔就能直接跑，不用改任何程式碼。
目前選到狗時不會崩：`animal_animator.dart` 的 `errorBuilder` 會改用 `_FallbackPetPainter`
畫一個佔位小精靈，所以現在是「看得到但是一隻抽象狗」。

---

## 2026-11-06：懸浮寵物功能（速度／大小／活動範圍／互動）落地後的待辦

### A. 真機驗收單 → 已搬到 **`../DEVICE_TEST.md`**（跨 dHealth／dNeko 一份）

2026-11-09：驗收單集中到 repo 外的 `../DEVICE_TEST.md`，做新功能時把它的驗收步驟當場加進
那一節，最後一次真機 session 一起清掉。**至今仍然一項都沒在真機跑過**，其中 A-5（餓度跨重開）
現在才有辦法執行 —— `HungerBar` 寫好以來零個使用者，餓度在 app 裡根本看不到。

### B. 已知缺口（按優先序）
1. **水平走的正式解法**：現在 `AnimalAnimationDefinition._missingFrameAlias` 借用 `walkDown`
   幀（貓的 `animation.json` 只有 `WalkUp`/`WalkDown`），所以左右走看起來像在往下走。
   補 `walk_l1/l2、walk_r1/r2` 四張圖後**把這張 alias 表整張刪掉**即可
   （`actions` 有直接命中就不會走 alias）。進階選項：用 `Transform.scale(scaleX: -1)`
   把 `walkRight` 鏡射成 `walkLeft`，就只需要 2 張圖。
2. **垂直基準未驗**：overlay 視窗 y=0 是物理螢幕頂（含 status bar）還是 FlutterView 頂，
   只能真機看。若整體偏移一個 status bar 高度，就比照 `bottomInset` 加一個 `topInset`
   （`ScreenMetrics` + payload 各加一個欄位，`zoneBounds` 的上邊界用它）。
3. **overlay isolate 能不能用 sqflite 未驗**：貓是內建素材、走不到 DB，所以沒有證據。
   已做 fail-safe（讀不到用預設、寫入失敗不影響執行期），代價是 overlay 啟動瞬間的
   餓度可能歸零。真機跑一次：餵飽 → 殺 app → 重開，看餓度是否還在。
4. **選狗仍然做不到**（三層都缺，任一層補都沒用，要一起）：
   - UI 沒有「使用這隻」：`store_page.dart` 的 tile 只有下載／刪除
   - 上層寫死：`main.dart` 的 `show(animalId: defaultAnimalId)` 與 `overlay_main.dart`
     的 `_loadDefaultAnimal()`
   - `assets/animals/dog/` 缺 13 張圖（見上一節）
5. **商店下載是空殼**（見上一節「擱置中的兩件事」）。2026-11-06 第四輪：入口先關起來 ——
   `lib/main.dart` 的 `kStoreEnabled = false`，AppBar 不再出現商店按鈕。
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
本案有本地 fork 的原生插件／drift／health 等原生依賴，直接動風險高得多。驗收要含一次 release build
（AOT 只能在 x86-64 機器或 CI 驗）。

## 2026-11-09 評估完、**保留不動**：`package_info_plus` 是本案 built-in Kotlin 的唯一 blocker

**事實（2026-11-09 查證）**
· 本案原生依賴裡，只有 `package_info_plus` 10.2.2 會被擋：`android/build.gradle.kts:38` 有
  `apply(plugin = "org.jetbrains.kotlin.android")`。其餘（`path_provider_android`、`sqflite_android`、
  本地 fork `flutter_overlay_window`）都已 built-in ✅ → 移除它，本案就能翻 `android.builtInKotlin=true`。
· 升版解不了：pub.dev 最新就是 10.2.2；上游 `fluttercommunity/plus_plugins` 的 main 也還套著 KGP（查於當日）。
· **決定：不 fork**（人類 2026-11-09 定的），所以只能等上游或移除依賴。
· 我們其實只用兩個欄位：`lib/presentation/pages/home_page.dart:411,415,418` 的
  `PackageInfo.fromPlatform()` → `version` 與 `buildNumber`，而這兩個的本質是 build 時 `flutter build`
  從 `pubspec.yaml` 的 `version:` 蓋進 AndroidManifest 的 versionName/versionCode —— 打包當下就知道了，
  插件只是 runtime 用 MethodChannel 再問原生端一次。它其余的 appName/packageName/installerStore/
  buildSignature/changingPackages 與 Windows 端 fileVersion 那套，我們一個都沒用。

**四个選項與取捨（未做，留給要動的那天）**
| | 做法 | 缺點 |
|---|---|---|
| A 等上游 | 什麼都不做 | 日期未知；本案一直進不了 built-in Kotlin |
| B `--dart-define` | `String.fromEnvironment('APP_VERSION')` + build 時傳 `--dart-define=APP_VERSION=1.0.0+1` | 每台機器與 CI 都要記得傳；忘傳 UI 就顯示錯 |
| **C 小檔 + 測試**（評估時的建議） | `lib/gen/app_version.dart` 由兩行腳本從 pubspec 生，簽進版控；再加一個 test 解析 pubspec 比對，不同就紅 | 升版要重生一次（但 test 立刻擋，不會無聲說謊） |
| D 自己開 MethodChannel | 在本地 fork 的原生碼加個小 channel | 版號邏輯塞進 fork，耦合更糟、原生碼變多 → 不划算 |

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

