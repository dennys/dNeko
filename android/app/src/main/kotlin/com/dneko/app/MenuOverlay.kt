package com.dneko.app

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.FlutterInjector
import io.flutter.embedding.android.FlutterTextureView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.FlutterEngineGroup
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

/**
 * 選單自己的第二個懸浮視窗（動物的那個交給 flutter_overlay_window，它從此不必為選單改尺寸）。
 *
 * 為什麼要另一個視窗：動物的視窗一 resize，它的 `FlutterTextureView` 會把舊尺寸的最後一幀
 * 拉伸到新邊框，於是開／關選單時動物會消失或变形（[POPUP_TRANSITION.md] 第 3 節）。
 * 選單改成獨立視窗之後是 `addView` 一張全新的 surface —— 沒有舊幀可拉伸，問題整個消失，
 * 而且選單要開在動物上方還是下方都不再影響動物。
 *
 * 不是 Service：選單只活幾秒，而寵物那顆 foreground service 已經把進程撐著了，
 * 用不著第二張通知，也不必碰「背景啟動 service」那一堆限制（要開視窗時直接 post 到主執行緒）。
 *
 * 三個通道端點都叫 `com.dneko/menu`，差在綁到哪顆 engine（MethodChannel 的名字是 per-messenger）：
 *   - 選單 engine（本檔建的）：收 `requestPayload` / `command`
 *   - 寵物 overlay engine：收 `showMenu` / `hideMenu`，本檔對它 invoke `menuCommand`
 *   - 主 app engine（MainActivity 註冊）：收 `preWarmMenu` / `hideMenu` / `disposeMenu`
 * 選單的指令一律經本檔轉到寵物那側，**不繞主 app**：使用者劃掉 app 介面後寵物還在跑，
 * 那時候主 app isolate 已經沒了，繞它選單就會當著當著失靈。
 */
object MenuOverlay {
    private const val TAG = "dNekoMenu"

    /** 三顆 engine 共用的通道名（per-messenger，互不衝突） */
    private const val CHANNEL = "com.dneko/menu"
    private const val MENU_ENTRYPOINT = "menuMain"

    /**
     * 必須跟 fork 的 `OverlayConstants.CACHED_TAG` 一致（packages/flutter_overlay_window）。
     * 對不上不會編譯錯誤，只會「選單按了沒反應」—— 升 fork 時要核對這串字（AGENTS.md 補丁表）。
     */
    private const val PET_ENGINE_TAG = "myCachedEngine"

    private val mainThread = Handler(Looper.getMainLooper())
    private var appContext: Context? = null

    /** FlutterEngineGroup 一定要持有引用，交給 GC 會把用它的 engine 一併帶走 */
    private var engineGroup: FlutterEngineGroup? = null
    private var menuEngine: FlutterEngine? = null
    private var menuView: FlutterView? = null
    private var menuChannel: MethodChannel? = null

    /** 開選單時存下來的快照（JSON），選單 isolate 起來後向這裡要 */
    private var payload: String? = null

    /// 建好選單那顆 engine（重複呼叫無效）。主 app 開懸浮時就該 call 它，第一次開選單才不用等冷啟動。
    fun preWarm(context: Context) {
        appContext = context.applicationContext
        mainThread.post {
            val ctx = appContext ?: return@post
            ensureMenuEngine(ctx)
            attachPetEngine()
        }
    }

    /// 開選單視窗。座標與尺寸都是邏輯像素（跟 Dart 那邊同一套單位，插件也是直接 dpToPx）。
    @SuppressLint("ClickableViewAccessibility")
    fun showMenu(context: Context, x: Double, y: Double, width: Double, height: Double, payloadJson: String?) {
        appContext = context.applicationContext
        payload = payloadJson
        mainThread.post {
            val ctx = appContext ?: return@post
            val engine = ensureMenuEngine(ctx)
            removeViewNow()
            val view = FlutterView(ctx, FlutterTextureView(ctx))
            view.attachToFlutterEngine(engine)
            view.setBackgroundColor(Color.TRANSPARENT)
            // 點選單外面 → 關選單。回 false 讓事件繼續進 Flutter（選單自己的點擊要用）。
            view.setOnTouchListener { _, event ->
                if (event.actionMasked == MotionEvent.ACTION_OUTSIDE) {
                    forwardToPet("""{"action":"outsideTap"}""")
                }
                false
            }
            val params = WindowManager.LayoutParams(
                dp(width), dp(height), dp(x), dp(y),
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_PHONE,
                // NOT_TOUCH_MODAL：選單外的點擊給底下的 app（不能把整塊蓋住不讓人用）
                // WATCH_OUTSIDE_TOUCH：同時讓我們聽見 ACTION_OUTSIDE，拿來關選單
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
                        or WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH
                        or WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        or WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        or WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                        or WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
            )
            params.gravity = Gravity.TOP or Gravity.START
            try {
                windowManager(ctx).addView(view, params)
                menuView = view
                // 選單那顆 isolate 只在 engine 起來時跑一次 initState（preWarm 那時候根本還沒有
                // 快照），所以每次開都要推它重抓一次 —— 少了這行，選單會永遠畫空白。
                pushPayload(view)
                // 剛 preWarm 就立刻開選單時，選單 isolate 可能還沒跑到 initState 註冊 handler
                // （那時候推過去會被丟掉）→ 補打一次，Dart 端 _loadPayload 是冪等的。
                mainThread.postDelayed({ if (menuView === view) pushPayload(view) }, 250)
            } catch (e: Exception) {
                // 沒給懸浮權視窗被拒等情境：選單開不出來就好，不能把 pet 那側一起拖崩
                Log.w(TAG, "addView 失敗，選單開不起來", e)
                runCatching { view.detachFromFlutterEngine() }
                // 但 pet 那側已經把寵物凍住了（addView 是 post 出來的，它那邊早一步 success）
                // → 當它被收掉處理，否則寵物會白白凍到 6 秒逾時、期間長按也沒反應。
                forwardToPet("""{"action":"close"}""")
            }
        }
    }

    fun hideMenu() {
        mainThread.post { removeViewNow() }
    }

    /**
     * 關懸浮時把選單那顆 engine 一起放掉 —— 桌面寵物是一整天開著的，多一顆 engine 的
     * 記憶體不該在懸浮關掉之後還留著。下次開懸浮 `preWarm` 會重建（`engineGroup` 留著）。
     */
    fun disposeMenu() {
        mainThread.post {
            removeViewNow()
            menuChannel?.setMethodCallHandler(null)
            menuChannel = null
            runCatching { menuEngine?.destroy() }
            menuEngine = null
            payload = null
        }
    }

    // ---- 內部 ----

    /// 請選單 isolate 重抓快照（快照存在本物件的 [payload]，見 ensureMenuEngine 的 requestPayload）
    private fun pushPayload(view: FlutterView) {
        if (menuView !== view) return // 已經被收掉/換掉了，別推給舊的
        menuChannel?.invokeMethod("payload", null)
    }

    private fun windowManager(context: Context) =
        context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private fun dp(value: Double): Int = (value * DENSITY).toInt()

    private val DENSITY: Float
        get() = appContext?.resources?.displayMetrics?.density ?: 1f

    private fun ensureMenuEngine(ctx: Context): FlutterEngine {
        menuEngine?.let { return it }
        val group = engineGroup ?: FlutterEngineGroup(ctx).also { engineGroup = it }
        val options = FlutterEngineGroup.Options(ctx)
            .setDartEntrypoint(
                DartExecutor.DartEntrypoint(
                    FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                    MENU_ENTRYPOINT
                )
            )
            // 選單 isolate 不使用任何 plugin。讓它自動註冊反而會出包：fork 的 `WindowSetup` 是
            // 單例，plugin 一 attach 就把 `messenger` 改指到選單 engine，寵物→主 app 的訊息
            // （即時餓度、結束程式）就再也送不到了。
            .setAutomaticallyRegisterPlugins(false)
        val engine = group.createAndRunEngine(options)
        engine.lifecycleChannel.appIsResumed()
        menuEngine = engine
        menuChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        menuChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPayload" -> result.success(payload)
                "command" -> {
                    forwardToPet(call.argument<String>("json"))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
        return engine
    }

    /// 寵物那側（fork 的 overlay engine）可能還沒起來，所以每次 preWarm 都重新綁一次。
    private fun attachPetEngine() {
        val pet = FlutterEngineCache.getInstance().get(PET_ENGINE_TAG)
        if (pet == null) {
            Log.w(TAG, "寵物 overlay 的 engine 還不在（$PET_ENGINE_TAG），選單現在還開不起來")
            return
        }
        MethodChannel(pet.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showMenu" -> {
                    val x = call.argument<Double>("x")
                    val y = call.argument<Double>("y")
                    val w = call.argument<Double>("width")
                    val h = call.argument<Double>("height")
                    if (x == null || y == null || w == null || h == null) {
                        result.error("BAD_ARGS", "showMenu 需要 x/y/width/height", null)
                    } else {
                        showMenu(appContext ?: return@setMethodCallHandler, x, y, w, h, call.argument("payload"))
                        result.success(true)
                    }
                }
                "hideMenu" -> {
                    hideMenu()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun forwardToPet(json: String?) {
        if (json == null) return
        val pet = FlutterEngineCache.getInstance().get(PET_ENGINE_TAG)
        if (pet == null) {
            // 宠物那側沒了，6 秒自動關的定時器也沒了（它在 pet 的 Dart 裡）—— 連 ACTION_OUTSIDE
            // 都會送到這裡被丟掉，那就沒人關得起這顆視窗了。自己收掉，別留一顆浮著關不掉的。
            Log.w(TAG, "寵物那側的 engine 不在，選單自己收掉：$json")
            removeViewNow()
            return
        }
        MethodChannel(pet.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("menuCommand", json)
    }

    private fun removeViewNow() {
        val view = menuView ?: return
        menuView = null
        val ctx = appContext
        runCatching { if (ctx != null) windowManager(ctx).removeView(view) }
        runCatching { view.detachFromFlutterEngine() }
    }
}
