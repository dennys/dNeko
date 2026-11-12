# 選單（popup）開關過場：現況、發現與後續選項（2026-11-12）

> 這份是給「之後要處理這個體驗」的人（含 AI）直接接手用的，寫得比 TODO／CHANGELOG 詳細。
> **結論先講**：現在沒有「飛」了，但下半螢幕開／關選單時，動物會**消失約 0.4 秒**（上半螢幕約 0.12 秒）。
> 這是用「藏起來等視窗穩定」換來的，不是真正解掉原因。要真的做到無閃爍，只剩「不改動物視窗」那條路（見最後一節）。

## 1. 現況行為（已實機確認，Pixel 5，螢幕 393×827 dp，寵物 120 dp）

| 情境 | 開選單 | 收選單 |
|---|---|---|
| 動物在上半螢幕（選單往下長，視窗 y 不變） | 消失約 0.12 秒後選單出現 | 消失約 0.12 秒後動物回原位 |
| 動物在下半螢幕（選單往上長，視窗 y 要變） | 消失約 0.4 秒 | 消失約 0.4 秒 |

沒有「瞬移」「飛上來」「先變大」了。使用者（2026-11-12 23:05）確認可接受，決定**維持現況**，之後再處理。

## 2. 實作位置（[lib/overlay_main.dart](lib/overlay_main.dart)）

- `_openMenu` / `_closeMenu`：都改走 `_resizeHidden(...)`。
- `_resizeHidden`：① `setState` 把內容設成透明（`_contentHidden`）並切到目標版面 → ② 等一幀 + 32 ms
  讓透明幀送到畫面 → ③ 設 `_expectedHeight`（**必須在 resize 之前**，新尺寸的幀可能比 await 回來還早）→
  ④ 呼叫 `moveAndResize` → ⑤ 等 `_buildContent` 的 `LayoutBuilder` 量到新高度才 `_reveal()`。
- `minHidden`：選單開在動物**上方**（`placement.above` / `_menuAbove`）時至少藏 `_moveSettle`（380 ms），
  理由見第 4 節。保底 timer = `minHidden + 400 ms`（原生把高度夾掉時才會用到）。
- `_buildContent`：`LayoutBuilder` + `Opacity(0/1)`。**用 Opacity 而不是不渲染**，是為了讓
  `AnimalAnimator`（以 `_animatorKey` 的 GlobalKey）的狀態不被重建，否則會重載幀。
- `_openMenu` **不能再呼叫 `_roamFor`**：它校準時會把視窗搬到 (0,0)、(100000,100000) 再搬回來，
  那段內容還看得見，就是「第一次開選單瞬移到螢幕角落再回來」。現在只用載入時量好的 `_roam` 快取，
  沒有快取退回 `fallbackRoam`。
- `_closeMenu`：先記下 `restorePos = controller.position`（過場期間動物可能已開始走），
  `setPaused(false)` 要在 `_resizeHidden` 之前（`playFlourish` 依賴暫停已解除）。
- 選單的 `Column` 外包 `OverflowBox`（依 `_menuAbove` 靠上或靠下），避免視窗還沒放大時 overflow。
- 診斷時用過的暫時面板已全部移除。

## 3. 根因分析（哪些有證據、哪些是推論）

**有證據的**
1. overlay 的 Flutter view 是 `FlutterTextureView`（[OverlayService.java:148](packages/flutter_overlay_window/android/src/main/java/flutter/overlay/window/flutter_overlay_window/OverlayService.java)）。
   TextureView 在視窗 resize 時會把「舊尺寸的最後一幀」拉伸到新尺寸，直到 Flutter 畫出新尺寸的幀。
   → 這解釋「一開始是大 size」「動物被畫到視窗外」。
2. 第一次開選單的瞬移 = `_roamFor` 校準（第二次有快取就沒有）。已移除。
3. 錄影逐格分析（見第 6 節）：上半螢幕收選單 = 空白 ~0.12 秒後直接在原位，**沒有滑動**；
   下半螢幕收選單 = 空白後，動物先出現在選單視窗頂端附近，再以**逐格平滑**的方式約 0.2 秒滑到原位。

**只是推論、沒證實的**
- 那 0.2 秒的平滑滑動，我推測是**系統對視窗 frame（位置＋尺寸）變化做的動畫**，不是我們的程式搬的
  （`OverlayPetDriver` 只在 controller 位置變動時才 `moveTo`，而且是離散跳點，不會逐格平滑）。
  沒有查到 AOSP 的確切機制，也沒有 logcat 可對照。
- 若推論正確：Dart 端怎麼藏內容都擋不住，只能「等滑完才顯示」——這就是 `_moveSettle` 的由來。
- 影片中量到：空白 ~5 格 + 滑動 ~12 格 ≈ 0.28 秒（60 fps），所以取 380 ms 留餘裕。
  縮到 ~300 ms 理論上可行但太貼近，沒有測。

## 4. 為什麼上下半螢幕差那麼多（0.12 vs 0.4）

上半螢幕：選單往下長，視窗左上角 y 不變，只有尺寸變 → 只需等新尺寸的第一幀 → ~0.12 秒。
下半螢幕：選單往上長（`placeMenu` 的 `above == true`），視窗左上角 y 必須上移／收回時下移 →
多了那段平滑滑動 → 要等它結束才顯示。**要讓兩邊都 0.12 秒，視窗就不能搬位置**（做不到的話只剩第 7 節）。

## 5. 今天走過的彎路（避免重蹈）

按時間順序，括號是結果：
1. 選單裡的動物寫死 `AnimationAction.affectionate` → 開關選單時動作切換重載幀（**真的 bug，已修**：
   改成 `controller.action`，`AnimalAnimator.didUpdateWidget` 才不會重建 controller）。
2. 先切版面再放大視窗 + `OverflowBox`（**沒解掉瞬移**，只解了「大 size」那一部分）。
3. 開選單不再校準（**解掉「第一次開選單瞬移到角落」**）。
4. 先藏內容再 resize + LayoutBuilder 等新高度（**解掉 TextureView 拉伸舊畫面**）。
5. 下半螢幕多藏 380 ms（**解掉滑動**，現況）。
6. ⚠️ **誤診：「拖到下半螢幕放手後動物自己往上跑」**——花了很久，最後是**設定頁「區域」被選成「右上」**
   （`zoneBounds` 把可漫遊範圍縮成寵物尺寸 2 倍的方框，放手時 `endDrag` 的 `_clampToBounds` 把位置夾回
   方框下界）。判斷依據：診斷面板顯示 `b=33,49,273,289`（240×240，`roam=0,49,273,707` 才是全螢幕）。
   **不是程式 bug**，改成「全螢幕」就好。中途加的「放手後停 3 秒」「`onPanCancel` 補開監看」兩個猜測性
   改動已全部還原。教訓：下次看到「動物被夾到某個固定位置」，**先確認設定頁的區域**。
   （順帶：設定頁選了區域後沒有明顯提示，容易忘記；可考慮在主頁顯示目前區域，或做成「全螢幕」以外時有標記。）
7. 一度把 overlay 還原成開工前版本做二分、又 `git stash` 回純 HEAD 驗證「是不是今天改壞」——
   結論是 HEAD 與 11/11 23:19 的版本同樣會「上跳」（因為設定就是右上區域）。

## 6. 如何不靠 adb 取得證據（有效，下次直接用）

使用者沒有 adb。**螢幕錄影 + ffmpeg 逐格拆**非常有效：
- 手機錄影 → Syncthing 同步到 `D:\Syncthing\Pixel5\DCIM\Camera\`。
- ffmpeg 在 `D:\bin\Media\ffmpeg\bin\ffmpeg.exe`。先用 `fps=2,scale=160:-1,tile=10x6` 做總覽找時間點，
  再用 `-ss <起> -t <長> -vf "fps=60,crop=W:H:X:Y,scale=240:-1,tile=9x4"` 對該瞬間拆 60 fps 逐格。
- 用 `view` 看輸出的 PNG。診斷用完把暫存檔刪掉。
- 另一個有效的技巧：**在選單裡顯示暫時診斷面板**（roam／bounds／pos／最近事件），使用者長按開選單後截圖。
  這次靠它一次就定位到區域設定。

## 7. 若要真的消除空白（待處理，需要人決定）

「不改動物視窗尺寸／位置」，選單用別的東西畫。三個做法：

| 做法 | 內容 | 優點 | 缺點 |
|---|---|---|---|
| **A. 第二個 overlay 視窗放選單** | 動物視窗不動 | 動物完全不動 | 目前 plugin 只支援一個 overlay（`OverlayService.instance` 是單例），要大改 fork，風險最高 |
| **B. 原生 PopupWindow 畫選單**（建議） | 在 fork 的 `OverlayService.java` 另外加原生 popup；Dart 傳選項、點擊回傳 | 動物視窗完全不縮放不搬移，兩邊都沒有空白 | 要動原生；選單變原生畫，深色模式／多語系／樣式要自己處理；fork 多一個補丁（AGENTS.md 的補丁表要更新，升級 plugin 要重打） |
| **C. 原生端控制藏視窗** | resize 時把視窗 alpha 設 0，等 Flutter 回報新尺寸第一幀才恢復 | 改動最小 | 仍有空白；若滑動確實是系統動畫，這招也不一定擋得住 |

不可行：把視窗永遠開成選單大小——透明區域會擋底下 app 的觸控，Android overlay 不能讓透明像素穿透。

建議順序：先維持現況；真要處理走 B；A 不建議。

## 8. 同日其它改動（不屬於這個問題，備忘）

- 6 個新小動作 + 2 欄動作格、`FlourishScheduler`、選單不再讓動物換動作、定格時可摸牠（撒嬌後回原動作仍維持定格）。
  細節見 CHANGELOG 2026-11-12。
- 定格 + `playFlourish`：目前**靜默無效**（點了只是收選單），沒有任何回饋；是否要改成可用或給提示，尚未決定。
