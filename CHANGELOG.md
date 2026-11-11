# dNeko CHANGELOG

已完成事项的归档区（把 TODO.md 瘦成「只剩還沒做的事」）。
**`git log` 才是權威**，這裡只是保留當時的判斷與驗收數字，方便日後回溯「為什麼现在是這樣」。
新的完成紀錄加在最上面。

---
## 2026-11-11 第三輪：親密度（摸牠終於有意義了）

先回答 18 個問題再寫程式（人類的條件：B 組「能換到什麼」與 D 組「每隻各一份／不遷移舊檔」）。
規格：**0~100、只漲不跌、不衰減、無等級**；唯一的**後果**是 `PetBrain` 更高機率主動撒嬌
（滿值 20%，`bond=0` 時機率與舊版逐位元組相同 —— 有測試鎖）；**不影響餓度**（判準仍只有
`PetStats.isHungryAt`，不塞第二個影響餓度的機制）；**每隻動物各一份**（KV `pet_bond_<id>`）；
舊安裝不做遷移，從 0 算。

| 動作 | 加分 | 一天額度 |
| ---- | ---- | ---- |
| 短按摸牠（`pet()` 真的觸發才算；定格時無效 → 不加分） | +2 | 3 次 |
| **真的吃下一口**（抵達食物那一刻，不是丟食物那一刻） | +5 | 2 次 |

額度是防刷用的：沒有它，連點 100 次就能把親密度刷滿，整個機制三天報廢。一天最多 +16 → 滿分約 7 天。

**計分只發生在懸浮那側**（餓度與位置的同一教訓：只有 overlay 知道寵物在做什麼）——
`PetController.onFed` 回調只有 overlay 會掛，主頁預覽塊是沙箱、在 app 裡餵食不會養親密度。
顯示：選單那條餓度列右邊一顆愛心 + 數字（不另開區塊、不新增字串 → 不必動 4 個 ARB）。

**同日的 code review 補丁**（四條全修）：`onFed` 之前完全沒測試覆蓋（餵食計分整條路徑掛在它身上），
補一題鎖住「只能在**抵達食物**那一刻觸發、一餐一次、自主行為永不會自己吃到」；`pet()` 的回傳值現在是
「這一下加不加親密度」的契約，就在「定格摸牠無效」那題一起斷言 `isFalse`/`isTrue`（之前只鎖動畫，
回傳值壞掉會變成「定格被摸一摸、隔天憑空 +6」）；`_petNow` 拿動物 id 的備援分支是死路（`_controller`
與 `_resource` 同一個 setState 一起換）→ 改成 guard 把不變式寫進碼；刪掉下載的動物現在會連
`pet_bond_<id>` 那列 KV 一起清（`AnimalDownloadService.remove` 是唯一的刪除路徑，靠它才清得乾淨）。
兩個回歸都用「故意把程式改壞」驗證過會紅。

新增 `lib/domain/pet_bond.dart`（純計分 + encode/decode）與 `test/pet_bond_test.dart` 12 題
（額度、跨天歸零、封頂、encode/decode 守住額度、壞資料回 null、bond=0 回退舊機率、
滿值 20%、餓時親密度無效、亂傳負值/超大不搞壞機率）。`flutter test` 155 → **167** 全過、
analyze 0、debug APK ✅。**真機未測**：A-12 清單在 `~/dennys/DEVICE_TEST.md`（尤其 A-12c：
用 adb 把 bond 灌成 100，看牠會不會自己撒嬌 —— 這才是「有沒有後果」的驗證）。

---
## 2026-11-11 repo 衛生：版控裡不寫機器名

本案 repo 是 public，文件裡直接寫了那台 Linux/aarch64 開發機的主機名，屬基礎設施資訊。
README 3 處、REVIEW 2 處、CHANGELOG 1 處改寫成「Linux/aarch64 開發機」；中性詞對上哪台機器的
對照表搬到 `~/dennys/AGENTS.md` 新增的「文件用詞」節（那支檔不在版控裡）。
新增 `test/repo_hygiene_test.dart`：掃 `git ls-files` 的文字檔，命中機器名/IP/帳號/金鑰檔名就紅
（禁詞用串接寫，測試不會掃到自己；附「掃太少也算失敗」的防呆，與自我驗證：塞一個進去的確會紅）。
其他 token（IP、帳號、proxy、私鑰）實掃 0 命中。

⚠️ **清的是工作樹與之後的 commit，公開歷史改不掉**：`origin/main` 與 7 條已 push 的 commit
（含 `36fea6d` 的 commit message）裡還有那台機器的主機名。要徹底根除得 rebase/`git filter-repo` + force push，
那是另一件事；這條測試的價值是「以後不會再新增」。

---
## 2026-11-11 第二輪：互動與餓度的手感（①③④＋②B）

`flutter analyze` 0 issue、`flutter test` 154 全過（151 → 154）、debug APK 編過。
討論過程與被否決的選項全記在 `TODO.md`「互動與餓度」那一節；真機驗收單 = `../DEVICE_TEST.md` A-11。

- **②B 餓的判定 `>=` → `>`，並收成單一來源**：`PetStats.isHungryAt(hunger, threshold)` 是現在
  唯一的判準，`PetStats.isHungry`、`_setHunger` 的跨門檻通知、`setHungryThreshold`、以及
  `HungerBar` 自己重算的那份全部改走它（以前 PetStats 與 HungerBar 各寫一份 `>=`，改一邊必漏
  另一邊 → 會變成進度條紅著、寵物卻在睡覺）。
  **解的是**：餵食量是常數 40，餓透（100）餵一次剛好落在門檻 60 上，`>=` 判成「仍然餓」→
  要餵兩次才脫餓，而餓的時候 PetBrain 絕不睡覺 → 使用者餵完看到牠照常只走不睡，像餵了沒反應。
  現在餵一次就恢復正常。
- **① 定格時摸牠改為完全無視**：`PetController.pet()` 開頭 `if (_frozen) return;`。
  舊行為是照樣把 action 改成撒嬌，而 `_onTick` 在定格時不倒 hold → 卡在撒嬌最後一幀直到解凍，
  「定格＝動作固定不動」被破掉。放在 controller（不是 overlay 的 guard）是因為預覽塊與選單的
  「撫摸」列也都走 `pet()`，根因修一次。
- **③ hold 貼著動畫長度**：撒嬌 2s→1.2s（動畫 3 幀×300ms=0.9s）、進食 3s→**0.9s**（動畫 0.6s）。
  `loop: false` 的動作播完就停在最後一幀，多出來的 hold 就是肉眼可見的「乾等」—— 舊的 1.1s／
  **2.4s** 看起來像卡畫面。兩個數字變成 `_affectionateHold`／`_eatingHold` 常數並在註解寫明
  「改 animation.json 的幀數/速度要連這裡一起改」。
- **④ 拖曳不再播撒嬌**：`beginDrag()` 的 action 改 `sit`（坐著被拎）。以前拖曳與撫摸播同一支
  動畫，從外觀分不出來。沒有測試鎖住舊行為，所以 0 題測試需改。

**當場決定不動的**（理由都寫進 TODO 了，別再從零討論）：單擊 300ms 雙擊辨認期（保留乾淨手勢語意）、
睡覺只有 4~7 秒（等真機玩過）、「餓了絕不睡」（人類決定保留的產品定義，由 `pet_brain_test:16` 鎖住）、
餵食會偷偷解凍、餵食量與門檻的耦合、`hungerMinutesUntilHungry` 下限 1 分鐘。

---
## 2026-11-11 REVIEW 修復（第 3 份報告）：記位置、拖曳誤判、選單位置污染

`flutter analyze` 0 issue、`flutter test` 151 全過（132 → 151，+19：DragWatch 8、位置節流 8、getAll 合併 3）、
`flutter build apk --debug --target-platform android-arm64` ✅。**真機仍然零次** —— 這批改的正好是
只能上機驗的東西，驗收步驟已寫進 `../DEVICE_TEST.md` 的 A-10（含 A-9c 期待反轉那條）。

- **#1（Must）「記位置」整個是假的**：`PetController` 從來沒讀過原生的 `startPosition`，第一次 tick
  就把視窗抓回 `bounds.center`；加上首次載入必然要校準 `_roamFor`（此刻 `_controller` 還是 null，
  搬不回來）→ 每次開懸浮看得見「舊位置 → 左上角 → 右下角 → 中央」。現在 `_loadAnimal` 在 `_roamFor`
  **之前**讀一次 `currentPosition()` 當初始位置（讀不到才退回中央），`_roamFor` 加收 `anchor:`
  量完搬回同一個錨點，掛上 controller 後再 `_moveWindowQuietly` 以夾進 zone 的實際位置對齊一次。
- **#2（Must）走動時摸牠被誤判成拖曳**：判定基準從 `controller.position`（每 16ms 就在動，
  200 px/s 時一跳 3.2px > 2px 門檻，還疊著方法通道延遲）換成「視窗自己第一次的讀值」。整個狀態機
  抽出成 `domain/drag_watch.dart`（純邏輯），`test/drag_watch_test.dart` 8 題鎖住「寵物在走、
  視窗不動 → 一次 drag 都不能有」—— 換了基準之後這個 bug 在結構上就回不來。已知代價不變
  （DEVICE_TEST A-8：拖曳中停頓 >400ms 算放手）。
- **#3（Must）存下來的是選單的位置**：主 app 的 `OverlayService._rememberPosition()` 整個刪掉
  （`close()` 不再有 `rememberPosition` 參數）—— 主 app 只看得見視窗左上角，選單開著時那個座標是
  選單的、比寵物高約 156px。位置一律由 overlay 這個唯一知情者存：走動時節流（5 秒／50px，靜止完全不寫）、
  收選單與按結束 `force` 必寫。節流判定抽成 `domain/position_throttle.dart`（純邏輯 + 8 題測試：靜止不寫、
  慢走要累積距離、時間與基準要一起重設），餓度與位置的 DB 寫入則收進同一個 `_writeWithRetry`（SQLITE_BUSY 重試）。
- **#4**：CI 改 `flutter test --coverage`。之前沒加 → `coverage/lcov.info` 根本不存在，Codecov 那步
  綠燈上傳空資料，等於裝了個假儀表板。
- **#5**：`DELETED.txt` 那四支檔案是**第三次**被宣稱已刪（上兩條 CHANGELOG 都寫了「真的刪掉」）而實際
  還在版控裡。這次由 `git rm` 落地：`android/.../com/dneko/app/OverlayService.kt`(177 行)、
  `assets/dneko.png`、`lib/domain/pet_display_mode.dart`、以及 `DELETED.txt` 自己。同一個 repo 有兩支
  `OverlayService` 的情況結束。
- **#6**：`getAll()` = DB 列 ∪ `builtIns`（同 id 以 DB 為準；純函式 `mergeBuiltIns` + 3 題測試）。
  `seedBuiltIns()`／`insertBuiltIns()`／onUpgrade 的 `oldVersion < 3` 分支，連「加新動物要記得 bump
  `petDbVersion`」那個永遠不會紅的坑一起消失（約 −25 行）。⚠️ 代價：**刪掉 DB 裡的內建列不會再讓牠
  消失**（DEVICE_TEST A-9c 的期待已反轉）；目前 UI 沒有刪內建的路徑，要做之前得先加一欄「使用者隱藏」。
- **#8**：`_applySettings` 的 cascade 跨 `await` 打在同一個（可能已被 `_loadAnimal` 換掉並 dispose 的）
  controller 上 → 改成先存區域變數、`await` 後 `identical` 才准套設定（本檔其他處早就在防這類競態）。
- **#11 / #12**：`_loadAnimal` 補 `_menuTimer?.cancel()`（否則 6 秒後會醒過來對新 controller 多搬一趟）；
  `overlay_main` 那句「showOverlay 的 enableDrag 已關」改對（其實是 true，拖曳由原生做，Dart 只輪詢
  跟讀）—— 那句註解正好壓在全案最容易搞錯的那段上面。
- **#13**：刪掉零呼叫者的死 API：`PetController.dragTo()`（測試改用真正的拖曳路徑 `syncFromWindow`
  ＋ `endDrag`，比原本測得準）、`appLog()`、`OverlayWindow.resize()` 的 `enableDrag` 參數（連介面宣告）。
  ⚠️ 報告點名的 `AnimalResource.copyWith()` **沒刪** —— 它不是零呼叫者，`pet_state_persistence_test`
  靠它驗「換版重下載後 AnimationLoader 快取要失效」，而且那個被批「無條件設成 now()」的 `updatedAt`
  正是該測試成立的條件。報告那一條是錯的。
- **#14**：`HomePage` 改依賴 `IOverlayService` 並在構造子開放注入（未注入時仍用真的 `OverlayService`）。
  留介面、補注入點，而不是照報告把介面刪掉 —— AGENTS.md 的 D 條寫的就是這件事。

**沒做**：#10（`petTick` 16→33ms）—— 為一個沒有測量的收益去動全域 tick（`speedPerTick`／`_hold`／
`PetStats` 全吊在它上面），先量到再說。#9（keystore 離線副本）**做不了**：那台 Linux/aarch64 開發機上根本沒有金鑰，
詳見 README「Release signing」的遺失風險那段（文件原本宣稱有，已改）。

## 2026-11-11 review 修復 + 餓的門檻改成設定（分鐘）

`flutter analyze` 0 issue、`flutter test` 132 全過（115 → 132，+17：safeName / locale / 門檻 / updateBounds）。

- **餓的門檻改成設定**（`PetSettings.hungerMinutesUntilHungry`，單位分鐘，1~100，預設 60）：
  主頁加 slider、存進 settings JSON、push 給 overlay 即時生效（`PetStats.setHungryThreshold`，
  只在 isHungry 翻轉時通知）；預覽塊沙箱也跟著走。`HungerBar` 改收 `threshold` 參數，
  變紅的顏色跟 isHungry 同一個來源。衰減速率仍固定 1 點/分鐘（`PetStats.defaultHungerPerSecond`）。
- **REVIEW #1（Must）**：換動物時 `_loadAnimal` 先 `_stopDragWatch` 再 dispose 舊 controller；
  `_pollDrag` 在 await 後加 `mounted + identical` 閘（controller 被換掉/ dispose 時不再碰它）。
- **REVIEW #2（Must）**：`_closeMenu` 不再無條件清 roam 快取 —— 加 `_roamCalibrated` 旗標，
  只有 fallback（未校準）才清；實測值保留，開選單不再瞬移兩個角落。`_roamFor` 的 catch
  也標 calibrated=false（校準失敗不再被當真實值快取）。
- **REVIEW #3（Must）**：quit 競態 —— overlay `_quitApp` 改存**寵物**位置（`controller.position`；
  選單開著時視窗左上角是選單的位置，比寵物高約 200px）且**先存再送 quit**（主 app 一收到就關服務，
  存盤還在飛會被中斷）；主 app 的 quit 分支改 `close(rememberPosition: false)` + 2s timeout 再 pop。
- **REVIEW #4**：live 餓度 push 改寫獨立的 `_liveHunger`，不再蓋 DB 讀的 `_savedHunger`；
  「更新 HH:mm」標籤只跟 DB 那份走，live 值顯示「即時」；overlay 關閉時清 live 值回退到 DB。
- **REVIEW #5**：把 2026-11-09/11-10 兩條 entry 宣稱已刪、實際還在 git 的死碼**真的刪掉**：
  `android/.../OverlayService.kt`（177 行）、`assets/dneko.png`（255 KB）、`lib/domain/pet_display_mode.dart`、
  `OverlayService.collapsedSize`。README 補一句商店目前停用（`kStoreEnabled = false`）。
- **REVIEW #6**：`_AnimalPicker` 渲染 `snap.error`（DB 讀不到不再空白）；商店回來後 key 變讓清單重查；
  `_apply` 加 try/catch + SnackBar（設定寫入失敗不再只進 logcat）。
- **REVIEW #7**：`PetController.updateBounds` 把 `_position`／`_target` 夾回新 bounds（zone 切換不瞬移）。
- **REVIEW #8**：`_safeName` 公開成 top-level `safeName` 並補測試（`..`、絕對路徑、分隔字元）；
  新增 `localeOfCode` 測試。（`decodeHunger` 的格式測試原本就有，在 pet_state_persistence_test。）
- **REVIEW #9**：`main` 與 `runOverlayApp` 都補 `FlutterError.onError`（framework/render 例外走
  reportError、不會 rethrow 進 zone，只靠 runZonedGuarded 抓不到）；overlay 入口也包 runZonedGuarded。
- **REVIEW #10**：`_writeHungerQuietly` 加一次重試（兩條連線寫同一個 DB 檔可能撞 SQLITE_BUSY）。
- **REVIEW #11**：刪 `AnimalRepository.getDownloaded`（介面＋實作＋兩個 test fake）、
  `AnimalAnimator.onComplete`（連同只為它存在的 `_onStatus`）。`AnimalResource.copyWith` **保留**
  （review 說 0 引用，但 pet_state_persistence_test 有用）；`IOverlayService` 也保留（AGENTS.md
  列名的架構縫，不是死碼）。
- **REVIEW #12**：pubspec 的 cat/、dog/ assets 重複列刪掉。
- **REVIEW #13**：`_feedDropDistance = 120` 兩處重複收進 `domain/pet_settings.dart` 的 `feedDropDistance`。
- **REVIEW #14**：`'zh-TW' → Locale` 的拆開從 main.dart / overlay_main.dart 兩處收進
  `domain/locale_code.dart` 的 `localeOfCode`。
- **REVIEW #15**：`asset_frames_test.dart` 的亂碼測試名與 reason 重打（原字元是 U+FFFD，已不可恢復，
  依測試邏輯重寫）。
- **REVIEW not-listed 三條**：`HungerBar` 改收 `threshold`（見上餓度設定條）；`_roamFor` catch 標
  calibrated=false（見上 #2 條）；`animation_loader.dart` 尾註更新（pushSettings → `_onData` 的換動物
  路徑其實是通的，只是 store 關著用不到）。

**未做**：REVIEW #8 的「抽出 `_onData` 的 decode 分支」——那是 755 行 overlay 入口的大重構，
本機沒有真機可驗，風險大於收益；safeName / locale / decodeHunger 三塊純邏輯已有測試。

---
## 2026-11-10 four user-visible fixes (device checks still zero)

- `animal_animator.dart`: `didUpdateWidget` also watches `definition`/`resource`. Switching
  animal while the action stays `sit` used to keep drawing the previous animal
  (`test/animal_animator_test.dart` fails on the old code: dog folder + cat frame).
- `animal_download_service.dart`: wipe `animals/<id>/` before downloading, so a half-failed
  re-download cannot leave a new manifest next to old frames (`_verifyAssets` only checks names).
- `animal_repository.dart`: `seedBuiltIns()` seeds only when the table is empty, so deleting a
  built-in animal survives the next launch (shortcut: a newly added built-in will not appear
  for existing installs). `static_store_catalog.dart` no longer lists built-in `penguin`.
- `home_page.dart`: the 20 s hunger poll is skipped unless the app is resumed.
- ~~`pet_display_mode.dart` deleted (0 references)~~ —— 當時**沒有真的刪**（檔案還在 git），
  2026-11-11 才刪；stale "only one built-in animal" comment fixed。

---
## 2026-11-09 本輪：把審查報告的缺口做掉（代碼面，commit `0f56ce9`）

`flutter analyze` 0 issue、`flutter test` 92 全過（85 → 92，+4 預覽塊 / +3 previewBounds）。
**逐條都還沒在真機跑過** —— 驗收單集中到 **`../DEVICE_TEST.md`**，所以下面每一條的意義是
「程式碼這樣寫了並有單元測試」，不是「真機驗過了」。

- **README 宣稱的「App 內模式」補實作**（`presentation/widgets/pet_preview.dart`）：主頁上方一塊
  預覽塊，跑與 overlay **同一套** `PetController`／`AnimalAnimator`，短按=撫摸、雙擊=餵食、
  改速度/大小即時反映。刻意不做長按選單（選單是 overlay 限定）、忽略 zone（預覽塊沒有
  「全螢幕／僅下方」的語意）、餓度用**獨立沙箱**（共用持久化會讓「app 裡餵一口、懸浮那隻也飽」，
  還會跟 overlay 的缺席補算打架）。README 順手改掉三處不實敘述（含「餓度隨時間下降」其實是上升）。
- **餓度第一次變得看得見**：`HungerBar` 寫好以來**零個使用者** —— 代表 TODO 上那條
  「餵飽 → 殺 app → 重開，看餓度是否還在」從寫下來那天就無法執行。補兩處、走兩條獨立路徑
  好歸因：主頁那一欄讀 DB（=overlay 寫不寫得進去）、懸浮選單頂部讀活 stats（=overlay 讀不讀得回來）。
  `HungerBar` 改收 `double`（主頁那側沒有活的 PetStats，不為了顯示一個數字去 new 一個）。
- **`AnimalAnimator` 一個真 bug**：換動作時用同一個 vsync 重建 `AnimationController`，
  `SingleTickerProviderStateMixin` 第二次就斷言失敗 → 改 `TickerProviderStateMixin`。
  是預覽塊的 widget 測試第一天抓到的；**不只預覽塊，overlay 在 debug 換動作的瞬間一樣會炸**
  （release 只是剛好沒斷言，ticker 也漏在 mixin 的記錄之外）。
- **啟動防護**（`main.dart`）：`runApp()` 前那兩件會碰 DB 的事各補 try/catch，DB 損毀時用內建
  素材 + 預設設定把 app 開起來（以前是白屏崩潰到連重裝的按鈕都看不到），並加 `runZonedGuarded`
  —— 沒有後端也沒有 crash 回報的專案，logcat 是唯一支持管道。overlay 端早就有 `_readOr` 防呆，
  主 app 卻沒有，這條是把不對稱補平。
- **轉屏會推新尺寸給 overlay**（`home_page.dart`）：原本只聽 `resumed`、沒實作 `didChangeMetrics`，
  轉屏後 overlay 繼續用舊螢幕的校準範圍跑，寵物卡在半邊螢幕直到使用者手動開關一次。
  設定改動與轉屏現在共用 `_pushCurrentSettings()` 一條路。
- **啟動 payload 去重**：`_shareStartupData` 的 4 次延遲重送，從前每次收下來都跑一趟
  `_applySettings`（含 resize、必要時重校準）→ 寵物剛出現時看得見地抖。套過的 payload 直接丟。
- **`_resolveResource` 收進 `AnimalRepository`**：「DB 優先於內建」這個順序之前只存在於
  `overlay_main`，預覽塊要共用就得收出來（否則兩邊各養一份，遲早對不起來）。
- **`_readOr`／`_writeHungerQuietly` 的 catch 從無聲改成留 log**（新增 `utils/log.dart`，
  與 dHealth 同一套 `dhealth`／`dhealth.error` 對應的 `dneko`／`dneko.error`）：
  「DB 壞了」與「真的沒存過」在外部表現一模一樣，A-5 沒這條 log 就查不動。

**本輪沒做**：商店開放（`kStoreEnabled` 仍 false）、狗的 13 張素材、真機驗收單全部、
上架相關（`--no-tree-shake-icons`、`ios/` 死目錄、內建 cat 顯示名仍是 `'ねこ'`）—— 都在 TODO。

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

---

## 2026-11-06：懸浮寵物功能（速度／大小／活動範圍／互動）落地後的待辦（已完成部分）

已完成（本輪，未 push，commit 見 `git log`）：設定頁（速度 / 大小 / 活動範圍）、
拖曳改自己實作、餵食真的走過去吃、餓度持久化、選單尺寸跟 petSize 連動、
水平走借幀（見下）。`flutter analyze` 0 issue、`flutter test` 44 全過。

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
- **删死碼**（~~2026-11-09 宣稱已刪，實際還在 git，2026-11-11 才真的刪~~）：`android/.../OverlayService.kt`
  （177 行，含 `NekoView`）、`MainActivity` 的 `com.dneko/native` MethodChannel（Dart 端沒有一處呼叫，
  這條當時是真的刪了，現行 channel 是 `com.dneko/app`）、`assets/dneko.png`（255 KB，
  根沒進 pubspec 的 assets 清單，本來就讀不到）、`OverlayService.collapsedSize`。
  懸浮視窗一律走 `flutter_overlay_window`，權限走 `permission_handler`。
- **l10n**：主頁啟動/關閉桌寵按鈕的四個字串（全 app 唯一跳過 l10n 的地方）補进 4 個 arb。
- **`edge_behavior.dart`**：雨個策略各自複製過一遍的貼邊判定收成 `isAtEdgeOf()`，容差統一成
  `edgeTolerance` 一個常數。
- `path_provider_android` 的本機 pin 從 `pubspec.yaml` 移到 `pubspec_overrides.yaml`（不進 git，
  這台機器的 path_provider 問題不該變成别人的 build 行為）。

---

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

---

## ~~待辦：overlay 拖曳抖動~~（✅ 2026-11-07 方案 (a) 已實作）

`overlay_main.dart`：`onPanDown` → 50ms 輪詢 `getOverlayPosition()`，位置變 > 2px 才
`beginDrag()` + 暫停 driver；連續 400ms 不動視為放手。以下原評估記錄留檔。

**現象**：拖曳寵物時會抖動。

**根因**：`overlay_main.dart` 的 `onPanUpdate` 用的是視窗內局部座標的 delta。Dart 每次移動視窗，局部座標就反向偏移，形成回授。

**相關事實**：
- ~~`android/.../OverlayService.kt` 是死代碼（NekoView 測試實作，MainActivity 註解已說明移除），改它無效。~~
  （2026-11-11 已刪；當時宣稱已刪但檔案還在 git。）
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

---

