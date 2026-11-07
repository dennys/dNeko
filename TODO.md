# TODO

## 兩段被移除的程式碼片段（commit `85c3e36`）

`lib/presentation/pages/home_page.dart`（20 行）與 `lib/presentation/widgets/pet_stage.dart`（9 行）
是兩個**從未被 import、也無法編譯**的游離片段檔 —— 檔名跟真正的實作撞名（真正的 `HomePage` 在
`lib/main.dart`），內容其實是当初寫給自己看的待辦筆記。2026-11-05 對齊工具鏈時為了讓
`flutter analyze` 與編譯變乾淨，把這兩個檔案刪掉，筆記內容搬到这里留檔。

逐條核對现在的程式碼後：**兩個想法其實都已经實作了**，只剩一條還開著。

| 筆記裡的idea | 現況 |
|---|---|
| AppBar 加一顆商店按鈕 → 開 `StorePage` | ✅ 已實作：`lib/main.dart:61`（`actions:` → `StorePage(controller: storeController)`） |
| 用 `PetControllerFactory` 建立 pet controller | ✅ 已實作：`lib/overlay_main.dart:37`（`static const _controllerFactory`）與 `:105`（`_controllerFactory.create(...)`）—— 片段檔放在 `widgets/pet_stage.dart`，位置本身也是錯的 |
| **從商店返回後重新載入動物清單**（可能有新下載的動物） | ⬜ **仍待做**：`lib/main.dart:64-69` 的 `onPressed` 只有 `push(...)`，沒有 `await` 之後的回載動作 |

### 待做那條的線索
`HomePage` 目前是 `StatelessWidget`（`lib/main.dart:50`），而 `_loadAnimals()`／`_buildModeToggle()`
這兩個被筆記呼叫的方法在現在的程式碼裡**已不存在**。要實作「返回後重新載入」，先決定清單狀態放在哪：
放在 `StoreController`（則返回後請它重刷即可，`HomePage` 可維持 `StatelessWidget`），
或把 `HomePage` 改為 `StatefulWidget` 再 `setState`。傾向前者 —— 清單本来就是 store 的狀態。

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

## 2026-11-06 第七輪：素材守門員（`test/asset_frames_test.dart`）

新增 10 條測試自動驗素材（`flutter test test/asset_frames_test.dart`），對應 `ASSET_PROMPT.md` 第 6 節。
**擋掉**：不是合法 PNG、無 8-bit alpha、四角全不透明（背景沒摳掉）、全透明空圖、主體貼邊被裁、
同一隻動物的兩幀位元組相同、`animation.json` 參考不存在的檔名、有圖卻沒被任何動作用到（白打包）、
六個動作缺項、以及「只有 json 沒圖卻註冊進選單」。**只示警**：各幀画布尺寸不一致、
`frameWidth/frameHeight` 與實際圖不符（現況貓就是 193×208~212×207 各不同，硬性規定會把檢查器弄成永遠紅）。
不另外拉 `image` 套件 —— 解碼/編碼都用 Flutter 自己的 codec（`dart:ui`）。

檢查器上線的第一天就抓到真問題：**小柴犬只有 `animation.json`，12 張圖全缺**，
而我上一輪剛把 dog 註冊進選單（理由是「素材存在卻選不到」—— 那個判斷錯了，素材其實不存在）。
已把 dog 從 `builtIns` 拿回（目錄與 json 留著當佔位，檢查器會一直示警提醒），
**產完圖再把那列加回來**：素材產生流程見 `ASSET_PROMPT.md`。
（檢查器本身也用「塞問題進去必須變紅」驗過：刪圖 / 兩幀複製 / 無圖卻註冊，四條斷言全數中招。）

---

## 2026-11-06 收尾輪：把碼內 `shortcut:` 與「還留著」的項目清掉

`flutter analyze` 0 issue、`flutter test` 76 全過（+13，見 `test/pet_state_persistence_test.dart`）。
每一條都驗過「把 bug 塞回去測試會紅」，不是怎麼跑都過的假測試。

- **內建動物的定義統一成四處→一處**（`AnimalRepository.builtIns` / `builtIn(id)`）。
  原本拆成兩處而且互相矛盾：`seedBuiltIns()` 只塞 cat 且顯示名寫成日文 `'ねこ'`（全 app 只有那行是日文），
  `overlay_main` 又自己硬編 `cat => 小花貓 / dog => 小柴犬`。
  **實際後果**：`assets/animals/dog/` 素材存在、overlay 也認得 dog，但 DB 沒這一列 →
  主頁選單讀 `getAll()`，小柴犬永遠選不到（素材白打包）。現在 dog 出現在選單裡，名字也統一。
  防呆：新增測試掃「`assets/animals/` 的資料夾 ⇔ `builtIns` 清單 ⇔ pubspec 的 assets 清單」三方一致。
- **overlay 載入順序改成 DB 優先**（原本是內建優先 → cat/dog 永遠無視 DB 裡的記錄，
  以後真開商店、同 id 換過素材就會拿錯）。DB 沒這一列（使用者刪掉了）才退回內建素材。
- **佔位貓不再是死路**：`_buildFallbackPet` 的 `onTap` 原本是 `_openMenu`，但 `_buildContent` 在
  resource/definition/controller 任一為 null 時一律回傳佔位畫面 → 「開選單」只是把視窗放大成選單尺寸、
  內容還是那顆圓，而 `_closeMenu` 再也叫不回來，使用者卡在那個大視窗上（而且沒有控制器也拖不動）。
  改成 tap = 重試載入。
  （拖曳本身仍需要控制器才能算位置；真的卡住時由主頁關掉懸浮，這是既有路徑。）
- **`AnimationLoader` 的 provider 快取有了失效機制**（碼內 `shortcut:` 移除）：載入時比對
  「version + 路徑 + updatedAt」指紋，同一 animalId 被重下載過就把該動物的 provider 從本 loader
  與 Flutter 全域 `ImageCache` 兩邊都趕掉（只清一邊沒用 —— FileImage 的 `==` 只比檔名）。
  只有 overlay isolate 會畫動物，所以同 isolate 內就處理完了。
- **餓度會補算缺席時間**（碼內 `shortcut:` 移除）：存盤改成 `{"hunger":42.5,"at":<ms>}`，
  重開懸浮時依「距上次存盤多久」補算 → 關掉 app 三天再打開，寵物不會還是飽的。
  舊格式（裸小數 `'42.00'`）仍讀得回來，但**不追溯補算**（沒有時間戳卻硬補，等於升級當下被一次餓透）。
  純函式 `PetStats.hungerAfterAbsence()`（含系統時鐘被調回的負時間）+ 格式解碼都有測試。

### 這一輪仍然不動的
- 商店：`_baseUrl` 佔位符 + manifest 沒有 INTERNET（兩件要一起改），入口由 `kStoreEnabled=false` 關著。
- 真機驗收單（上面 A 節 6 項）一項都還沒跑過；本機沒有 JDK 17+，`flutter build apk` 在這裡跑不了。
- 舊安裝已存在的 `cat` 列顯示名還是 `'ねこ'`（`ConflictAlgorithm.ignore` 不蓋使用者的資料）；
  開發機要重置就清 app 資料。app 尚未對外發布，不寫 migration。

---

## 2026-11-06：懸浮寵物功能（速度／大小／活動範圍／互動）落地後的待辦

已完成（本輪，未 push，commit 見 `git log`）：設定頁（速度 / 大小 / 活動範圍）、
拖曳改自己實作、餵食真的走過去吃、餓度持久化、選單尺寸跟 petSize 連動、
水平走借幀（見下）。`flutter analyze` 0 issue、`flutter test` 44 全過。

### A. 真機要驗的 6 項（本輪改動的驗收單，尚未有一項在真機跑過）
1. 懸浮開著 → 開設定改速度／大小／範圍 → 應**立即**生效（走 `pushSettings`，不重開視窗）
2. **拖曳**：現在應該拖得動（`enableDrag` 已關，改由 overlay 內 pan 手勢處理），
   而且拖不出所選區域
3. 餵食：按了會**走過去**再播吃東西動畫（`PetController.feedAt` → `goToFood` → `eat`）
4. 「僅下方」有沒有被 navigation bar 壓到（`ScreenMetrics.bottomInset` 已傳入，實測校正值）
5. 殺 app 重開 → 餓度還在（節流 60 秒，餵食瞬間的變化最多延後 1 分鐘落盤）
6. 六種活動範圍（全螢幕／僅下方／四角）是否都真的把牠關住

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

## 2026-11-06（第二輪）：資源洩漏、空轉與不可信輸入

上架前的全案重審。架構不動，只補「會洩漏 / 會空轉 / 會被壞素材打挂」這三類。
`flutter analyze` 0 issue、`flutter test` 44 → **61 全過**。

- **`lib/overlay_main.dart`**
  - `FlutterOverlayWindow.overlayListener.listen(...)` 之前不存欄位也沒 cancel —— 存成
    `_eventSub` 並在 `dispose()` 關掉。
  - 載入加順序號 `_loadSeq`：主 isolate 送 payload 是 fire-and-forget，而 handler 中間有好多
    `await`；`if (!mounted) return` 拦不住「雨邊都還活著」，舊 payload 會蓋掉新動物，
    而且 `_driver?.dispose(); _controller?.dispose();` 在 await 之前做，兩重載疊在一起時會留下一個
    沒人接手但 **16ms timer 仍在跑**的 PetController。現在只在最後進入的那次寫入狀態。
  - payload 少了 `metrics` 之前會把整個 stream handler 炸掉（未處理例外）；現在沿用舊範圍。
- **`OverlayPetDriver`**：`moveTo` 由 unawaited 改成串行（一次只一個在飛）+ 期間的新位置記成待發；
  失敗會寫一次 log（不洗 logcat）並清掉已送記錄，下次變動重試 —— 之前平台端拒絕時只是「畫面不動」，
  沒有任何地方看得見，而且會永久卡在舊位置。
- **`PetController`**：通知收在「看得見的變化」（整數像素或動作換了）—— 之前每 16ms 一定
  `notifyListeners()`，overlay 那側固定 60 次/秒重建 widget，而桌寵大部分時間只是坐在那裡。
- **`PetStats`**：
  - 通知節流 1 點解析度（邊界與跨過門檻一定通知）。
  - **預設飢餓速度 1.0/秒 → 1/60**。舊值是：開機 **100 秒**就永遠停在 maxHunger，而餵食只贖回 40，
    於是 `isHungry` 恆為 true、`PetBrain` 永遠只選 wander/idle —— 這隻寵物再也沒睡過覺。
    現在約 1 小時變餓、100 分鐘餓透。
    ~~shortcut: 舊版本已落盤的 `hunger=100` 不會自動 decay~~ —— 收尾輪已做缺席補算（見上）；
    唯一還殘留的是「舊格式沒有時間戳，那一筆不追溯補算」，餵一次就回到正常軌道。
- **不可信輸入**（動物商店下載回來的 `animation.json`）：`AnimalAnimationDefinition`/`FrameAnimation`
  現在會擋掉空幀清單、非字串 frames、`frameDurationMs <= 0`、缺 `loop`、`actions` 空；
  認不出的動作名稱只是跳過（素材多給動作不該讓整隻動物載入失敗）。
  以前這些会一路走到 `AnimalAnimator` 的 `clamp(0, -1)` 丟 RangeError。
- **`AnimationLoader.getFrameImage` 加了 provider 快取**：之前 `build()` 每次重繪都 new 一個
  `AssetImage`/`FileImage`，Flutter 用 provider 的 `==` 做快取，所以等於**每幀把解好碼的圖攞掉重解**。
  ~~shortcut: 同一 animalId 重新下載後會繼續顯示舊圖~~ —— 收尾輪已修（見上：來源指紋 + 兩邊趕快取）。
- **删死碼**：`android/.../OverlayService.kt`（177 行，含 `NekoView`）、`MainActivity` 的
  `com.dneko/native` MethodChannel（Dart 端沒有一處呼叫）、`assets/dneko.png`（255 KB，
  根沒進 pubspec 的 assets 清單，本來就讀不到）、`OverlayService.collapsedSize`。
  懸浮視窗一律走 `flutter_overlay_window`，權限走 `permission_handler`。
- **l10n**：主頁啟動/關閉桌寵按鈕的四個字串（全 app 唯一跳過 l10n 的地方）補进 4 個 arb。
- **`edge_behavior.dart`**：雨個策略各自複製過一遍的貼邊判定收成 `isAtEdgeOf()`，容差統一成
  `edgeTolerance` 一個常數。
- `path_provider_android` 的本機 pin 從 `pubspec.yaml` 移到 `pubspec_overrides.yaml`（不進 git，
  這台機器的 path_provider 問題不該變成别人的 build 行為）。

---

## 2026-11-06（第三輪）：重審自己上一輪的產出

重讀一次改過的程式碼，抓出三個「上一輪的修自己就有 bug」的點（`flutter analyze` 0 issue、`flutter test` 63 全過）：

- **`PetStats` 在「已餓透」時反而變成 60 次/秒通知**：上一輪加節流時把 `if (clamped == _hunger) return;`
  一起拿掉了，於是 hunger 恆為 maxHunger 的每一幀都算出「在邊界上」→ 每幀都 notify。
  補回 early-return（有回歸測試：餓透後再 tick 600 次，通知 0 次）。
- **按「撫摸」不會播撒嬌動畫**：`pet()` 只換動作、不動位置，而 `_enter()` 不通知、`pet()` 也不通知，
  接著 hold=2s 讓 `_waitThenDecide` 連續 125 幀提前 return → 兩秒內畫面完全不會重繪。
  通知改放在 `_enter()`（`_notifyIfChanged` 會去重，不會多花）。
- **重載動物時可能卡在那個已 dispose 的舊 controller**：`_loadAnimal` 在 `await _resizePetWindow()`
  **之前**就把 `_driver`/`_controller` 關了；一旦這次載入後段失敗或被顺序號作廢，畫面就挂在一個
  關掉的 controller 上（拖不動也不會動）。改成新的一整套備妥後才關舊的，同時關掉上一個 `PetStats`
  （它是 overlay 自己 new 後注入的，`PetController._ownsStats` 不會替我們關）。
- **主頁啟動/關閉桌寵失敗時完全沒有回饋**：`_toggle` 只有 `finally`，`showOverlay()` 被平台擋掉時
  按鈕轉一輪就回復原狀，使用者與 logcat 都看不到原因。補 catch + SnackBar（l10n 四個檔都加）。

~~仍開著的小項：`_builtInResource()` 的名字與別處重複；`AnimationLoader` 快取沒有失效機制~~
—— 兩項都在收尾輪做掉了（前者整顆函式刪掉、改成 `AnimalRepository.builtIn()` 單一來源）。

---

## 待辦：overlay 拖曳抖動（未實作，之後再處理）

**現象**：拖曳寵物時會抖動。

**根因**：`overlay_main.dart` 的 `onPanUpdate` 用的是視窗內局部座標的 delta。Dart 每次移動視窗，局部座標就反向偏移，形成回授。

**相關事實**：
- `android/.../OverlayService.kt` 是死代碼（NekoView 測試實作，MainActivity 註解已說明移除），改它無效。
- 真正的懸浮窗由 `flutter_overlay_window` 1.0.2 原生層處理，`OverlayService.java` 的 `onTouch` 已用 `rawX/rawY` 拖曳，由 `enableDrag` 開關控制（目前 `overlay_service.dart` 與 `overlay_window.dart` 的 resize 都寫死 false）。
- 插件提供 `getOverlayPosition()`（回傳 dp，x/y），但原生拖曳結束時沒有回調給 Dart。

**方案 (a)，待實作**：
1. `showOverlay` 與 `resize` 改 `enableDrag: true`；選單狀態 resize 時仍用 false，避免選單被拖走後位置失同步。
2. 移除 `onPanUpdate/onPanEnd` 的 Dart 拖曳，改為 `onPanDown` 後開始輪詢 `getOverlayPosition()`（約 50 ms）。
3. 只有偵測到位置變化（與 `controller.position` 差 > 2 px）才 `beginDrag()` 並暫停 driver；否則單擊撫摸會被誤判成拖曳，導致 `endDrag()` 覆蓋撫摸動作。
4. 拖曳中以輪詢結果更新 controller 位置（新增 `syncFromWindow`，不 clamp，不 moveTo）。
5. 位置連續約 400 ms 不變視為放手：恢復 driver，呼叫 `endDrag()`。

**已知風險**：
- 若使用者拖曳中停頓超過 400 ms，會被提前判定放手，之後的拖曳可能與 Dart 的自主移動衝突。
- 原生拖曳沒有放手事件，只能靠靜止時間判斷。
- 需要真機驗證，尤其是 Android 版本差異與 dismiss 區（目前 `dismissConfig` 為 null，理論上不會出現）。

**替代方案 (b)**：fork 或 vendor 插件，在 `ACTION_UP` 時回傳事件，可徹底解決放手判定，但需要維護插件副本。