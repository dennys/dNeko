# Windows 桌寵版（懸浮版）

> 狀態：**第一版（盲寫）**。程式在 Linux/aarch64 開發機上寫，那台主機**編不了** Windows 目標
> （也沒有 Windows 圖形環境可看），所以本檔寫得比平常囉唆 —— 目標是「上機的人不必問人」。
>
> 已在開發機驗證過的：`flutter analyze` 0 issue、`flutter test` 全綠（含 Windows 幾何的
> 純函式測試）、Android 那條路 `flutter build apk --debug` 不受影響。
> **沒有驗證過的：任何會真的出現在螢幕上的東西。**

## 這是怎麼回事（30 秒）

Android 版：主 app 是設定頁，寵物由 `flutter_overlay_window` 開的懸浮視窗承載，跑在獨立
isolate，選單是第二顆視窗。

Windows 版：**整個 exe 就是那顆懸浮視窗**。無邊框、透明、置頂、不進工作列、點牠不搶鍵盤焦點。
選單疊在同一顆視窗裡（Windows 沒有 Android 那個 `FlutterTextureView` resize 拉伸 bug，
不需要第二顆 engine）。待辦清單與分层驗收見本檔末。

共用的是真正承重的部分：`PetController` / `MenuDirector` / `ScreenMetrics` /
`SettingsRepository`（含「各養各的」）/ `AnimalAnimator` / `FeedingMenu`。
Windows 專屬的只有 `lib/platform/windows/`（3 支）與 `windows/runner/` 的 3 處 C++ 修改。

## 需要的東西

| 項目 | 說明 |
| ---- | ---- |
| Windows 10 / 11 x64 | Windows 7/8 沒試過，別期待 |
| **Visual Studio 2022** + 工作負載「**使用 C++ 的桌面開發**」 | Flutter Windows 的硬性需求（`cl.exe`、Windows SDK）。**不要**只裝 Build Tools 裡的舊 SDK |
| Flutter SDK（與開發機同版：3.47.x stable） | `flutter --version` 若差很多請先對齊，插件 API 會分岔 |
| **第一次 build 要有網路** | 兩件事：`flutter pub get` 抓套件；`sqlite3` 3.x 在編譯時期**下載 SQLite 原始碼自己編**（見下方「DB」）。第一次會多花幾分鐘 |
| 本 repo（含 `assets/`） | 素材不在版控外的地方，整包解壓即可 |

## 建置

```powershell
cd <repo 目錄>
flutter pub get
flutter build windows --release      # 要看 log 除錯時改用 --debug
```

輸出：`build\windows\x64\runner\Release\dneko.exe`（debug 版在 `Debug\`）。

直接雙擊執行即可；它**不會**出現在工作列（`WS_EX_TOOLWINDOW`），右下角系統匣会有圖示。
第一次執行若被 SmartScreen 擋 → 「更多信息 → 仍要執行」（沒有簽章）。

## 不用自己開機就能先知道的事：CI

`.github/workflows/github_action.yaml` 有一個 **`Windows 桌寵版（analyze / test / build）`** job
（`windows-latest`，自帶 VS 2022 C++ 工作負載，不需要金鑰，只出 debug artifact）。
**第一次先在 GitHub 上看那個 job**：它綠了再上自己機器，能省一次裝機與一次來回。
它紅了就把 log（尤其第一個失敗的 step 與其上 20 行）貼回來 —— 那正是這邊看不到的情報。

## 上機驗收 ladder（按這個順序回報）

每一層通過才往下。任何一層卡住，**把整段錯誤文字貼回來**（不要摘要、不要截圖裡只有一半）。
Dart 側的 log 會出現在 `--debug` 執行時的終端機視窗（`appError` 走 `stderr`，tag 仍是
`dneko.error` 語意）；沒有終端機就用 [DebugView](https://learn.microsoft.com/sysinternals/downloads/debugview) 看。

| # | 驗收項 | 通過條件 | 掛了要貼什麼 |
| ---- | ---- | ---- | ---- |
| 1 | 編得起來 | `flutter build windows --release` 结束碼 0 | 完整錯誤區塊（尤其 `cl.exe` / `CMake` / `LNK` / `sqlite3` 字樣那幾行） |
| 2 | 視窗開得出來 | 桌面出現一隻會動的貓，**沒有**先閃一大塊白盤 | 「閃白盤」/「完全看不到」/「透明但內容是空的」是哪一種 |
| 3 | 真的透明 | 寵物周圍沒有灰底、沒有黑框 | 貼截圖或描述底色 |
| 4 | 點牠不搶焦點 | 在記事本打字，點貓一下，**游標仍留在記事本** | 焦點被搶走的話，說明被搶去哪裡 |
| 5 | 置頂 | 開著檔案總管/瀏覽器，貓還在最上面 | 被誰蓋住 |
| 6 | 拖曳 | 按住貓拖，能拖到螢幕任何位置；放開後停住 | 拖不动 / 拖曳時抖動 / 放開後跳回 |
| 7 | 自主漫遊 | 貓自己會走、碰邊會轉、範圍正確（含設定「僅下方」時） | 超出螢幕 / 鑽進工作列 / 卡在某處 |
| 8 | 點擊互動 | 單擊=摸（有音效）、雙擊=餵食、長按=開選單 | 哪一個沒反應 |
| 9 | 選單（同視窗） | 長按開選單：**貓不跳位**、選單完整可見、6 秒無操作自動收、收起來後貓回到原位不被拉伸 | 「貓跳了」「選單被切掉」「收起來後貓變大塊」是哪一種 |
| 10 | 系統匣 | 圖示可見；顯示/隱藏、滑鼠穿透開/關、大小 80/120/180、活動範圍、結束 都有效 | 圖示是空白／選單開不出來／某項無效 |
| 11 | 各養各的 | 換隻之後兩邊的餓度/位置互不干擾；正常「結束」再重開，餓度**不補算**（收起來不算餓） | 描述時間與看到的餓度 |
| 12 | 持久化 | 結束再重開：位置與餓度還在（DB 在 `%APPDATA%\<exe 的支援目錄>`，見「DB」節） | 重開就回到預設 → 貼 DB 相關 log |
| 13 | 單實例 | 重開 exe 不會出現第二隻貓 | 出現兩隻 → 說明怎麼觸發的 |
| 14 | 穿透 | 開穿透後能點到貓下面的視窗，且還能從系統匣關回來 | 關不回來（這是嚴重項） |

## 已知取捨（第一版刻意沒做，不是 bug）

| 項目 | 現況 | 為什麼 |
| ---- | ---- | ---- |
| 設定頁 | Windows 版**沒有**主 app 設定頁，能調的都在系統匣（大小、活動範圍、穿透、顯示/隱藏、結束） | 桌寵版啟動就是寵物；設定視窗是下一層 |
| 換寵物、商店、下載 | 未接（用 DB 裡現存的 `animalId`，預設第一隻內建動物） | 下載路徑用的是 Android 的 `getExternalStorageDirectory()`；商店在 Windows 上也沒有意義 |
| 工作列 | **沒扣**：貓可能走到工作列上面 | Flutter 在 Windows 沒給 visible bounds；要準就取 `MonitorInfo` 的 workArea（見 `windows_pet_app._screenMetrics` 的 shortcut 註解） |
| 多隻寵物同時懸浮 | 一次一隻 | 與 Android 現況一致；先確認一隻的经驗是好的 |
| 開機自啟 | 沒有 | 要做就寫 `HKCU\Software\Microsoft\Windows\CurrentVersion\Run`，等前面 14 項過了再說 |
| 圖示 | 系統匣沿用 `assets/images/icon.png`（PNG）；Windows 慣用 `.ico` | 若托盤圖示顯示異常，就要一支 `assets/windows/dneko.ico` 並改 `windows_pet_app._trayIconAsset` |
| 音效 | 沿用 `assets/sounds/*.mp3`（audioplayers 有 Windows 實作） | 沒實測過，屬「應該能用」 |

## DB（最容易在第 1 層卡住的地方）

`sqflite` 只有 Android/iOS/macOS 實作，所以桌面改用 `sqflite_common_ffi`（FFI 後端），
切換點只有一處：`lib/data/repositories/pet_database.dart` 的 `databaseDirectory()`
（**DDL 只有一份**，不會出現兩邊 schema 分岔）。連資料目錄也一起換了：ffi 後端下
`getDatabasesPath()` 會退回 temp 目錄 → 重開機資料全丟，那種錯太兇，所以改用
`getApplicationSupportDirectory()`。

要注意的兩件事：

1. **第一次 build 要網路**：`sqlite3` 3.x 走 Dart 的 native assets 機制，編譯時下載 SQLite
   原始碼自行編譯。若報錯裡有 `sqlite3` / `hooks` / `native assets` 字樣，把整段貼回來。
   退路（我這邊改，你不用動）：Windows 側換成 JSON 檔存檔，代價約一支檔。
2. 若執行時報「找不到 sqlite3.dll / Failed to load dynamic library」：先確認不是上面那條
   （native assets 正常的話**不需要** dll）。真的要手動補，就把官方 `sqlite3.dll`(x64) 放到
   `dneko.exe` 同目錄再試 —— 但請先回報，這條是備用方案不是正規做法。

## 我這邊改過、你在機器上看到行為古怪時先懷疑這幾處

| 檔 | 改了什麼 | 猜錯的後果 |
| ---- | ---- | ---- |
| `windows/runner/win32_window.cpp` | `CreateWindowExW` + `WS_EX_LAYERED\|TOOLWINDOW\|NOACTIVATE`、樣式 `WS_POPUP`、建立後 `SetLayeredWindowAttributes(...,255,LWA_ALPHA)` | 完全不顯示 / 不透明 / 出現標題列 / 搶焦點 |
| `windows/runner/flutter_window.cpp` | 拿掉「第一幀就 `Show()`」，改由 Dart 決定顯示時機 | 開機閃一大塊白盤 / 永遠不顯示 |
| `windows/runner/main.cpp` | 初始尺寸 120×120、標題 `dNekoPet`、named mutex 單實例 | 第二隻貓開得起來 / 位置怪 |
| `lib/platform/windows/windows_overlay_window.dart` | `IOverlayWindow` → window_manager 的 `setPosition/setSize/getPosition/hide` | 貓不動 / 選單擺錯位置 |
| `lib/platform/windows/windows_pet_app.dart` | 桌寵 shell（載入、選單、托盤、存檔） | 各自的功能失效（會有 log） |
| `lib/platform/windows/pet_window_geometry.dart` | 開選單時的視窗並集幾何（**有測試**） | 貓跳位 / 選單出界 |

> window_manager 停在 `0.5.2`、tray_manager 停在 `0.5.2`：這一版自帶 C++、不拖 `nativeapi`
> 原生核心，裝的機器只要 VS 的 C++ 工作負載。 newer 版（0.6/0.7）換了 API 且需要更新的
> Flutter/Dart，**別順手升級**；要升請先跟我說（`AGENTS.md` 那類「升版要注意的坑」會補）。
