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
