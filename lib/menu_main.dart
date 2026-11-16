import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'l10n/app_localizations.dart';
import 'domain/locale_code.dart';
import 'domain/menu_payload.dart';
import 'domain/pet_behavior.dart';
import 'presentation/widgets/feeding_menu.dart';
import 'presentation/widgets/hunger_bar.dart';
import 'utils/log.dart';

/// 選單 isolate 的進入點（原生 `MenuOverlay.kt` 用 `menuMain` 起這顆 engine）。
///
/// 選單是**另一個懸浮視窗**，跟寵物那個完全分開：寵物視窗從此不用為選單改尺寸，
/// 也就不會再被 TextureView 拉伸舊幀（為什麼必須另開視窗：`AGENTS.md`「選單是另一個視窗」）。
/// 這一側很笨：起的時候向原生要一份 [MenuPayload] 快照畫出來，按到哪一格就把動作
/// 名稱送回寵物那側 —— 不讀 DB、不做翻譯、不碰 PetController。
void runMenuApp() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) => appError('menu framework 例外', details.exception, details.stack);
  runZonedGuarded(
    () => runApp(const _MenuApp()),
    (e, st) => appError('menu 未捕获例外', e, st),
  );
}

/// 選單視窗的大小（邏輯像素）：餓度列 + 空隙 + 選單本體 + 底部留白。
/// 寬高由選單自己的版面決定，`overlay_main` 開視窗時用它算位置（`placeMenuWindow`）。
const Size kMenuWindowSize = Size(
  FeedingMenu.contentWidth,
  20 + 8 + FeedingMenu.contentHeight + 8,
);

/// 原生 `MenuOverlay.kt` 綁在選單 engine 上的通道
const _channel = MethodChannel('com.dneko/menu');

/// 動作格要用哪個 icon。清單本身在 `kFlourishBehaviors`（兩側共用），這裡只補圖示 ——
/// 圖示是呈現細節、留在選單這一側，不進 payload。
IconData _iconFor(PetBehavior behavior) => switch (behavior) {
      PetBehavior.lookAround => Icons.visibility,
      PetBehavior.doze => Icons.bedtime_outlined,
      PetBehavior.wobble => Icons.swap_horiz,
      PetBehavior.hop => Icons.keyboard_double_arrow_up,
      PetBehavior.stretch => Icons.wb_sunny_outlined,
      PetBehavior.circle => Icons.autorenew,
      _ => Icons.bolt,
    };

class _MenuApp extends StatefulWidget {
  const _MenuApp();

  @override
  State<_MenuApp> createState() => _MenuAppState();
}

class _MenuAppState extends State<_MenuApp> {
  MenuPayload? _payload;

  @override
  void initState() {
    super.initState();
    // 這一側的 isolate 跟 engine 同命：preWarm 起來時就跑過一次 initState（那時候還沒有
    // 任何快照），之後每次開選單由原生推 `payload` 過來的時候重抓。少了那個推送，選單會
    // 永遠停在空白畫面（第二次、第三次開都一樣）。
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'payload') await _loadPayload();
    });
    unawaited(_loadPayload());
  }

  /// 快照由原生暫存（開選單時寵物那側一起送過來的），向原生要、不繞主 app：
  /// 使用者劃掉 app 介面後寵物還在跑，那時候主 app isolate 已經不存在了。
  Future<void> _loadPayload() async {
    try {
      final raw = await _channel.invokeMethod<String>('requestPayload');
      final payload = MenuPayload.decode(raw);
      if (payload != null && mounted) setState(() => _payload = payload);
    } catch (e, st) {
      appError('選單讀 payload 失敗', e, st);
    }
  }

  void _send(String action) {
    unawaited(
      _channel
          .invokeMethod('command', {'json': jsonEncode({'action': action})})
          .catchError((Object e, StackTrace st) {
        appError('選單指令送不出去', e, st);
        return false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _payload;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: localeOfCode(payload?.languageCode ?? 'en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // 深色模式跟著寵物那側送過來的 themeMode（選單是 Card/InkWell，兩邊要同一套）
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.green)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark),
      ),
      themeMode: switch (payload?.themeMode) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: Material(
        color: Colors.transparent,
        child: payload == null ? const SizedBox.shrink() : _buildMenu(payload),
      ),
    );
  }

  Widget _buildMenu(MenuPayload payload) {
    // 餓度列在選單上方：開選單就是來看牠狀態的（與舊版同一個擺法）
    final hunger = SizedBox(
      height: 20,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: HungerBar(
                hunger: payload.hunger,
                threshold: payload.hungryThreshold,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.favorite, size: 13, color: Color(0xFFE91E63)),
            const SizedBox(width: 2),
            Text('${payload.bondValue}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
    final menu = FeedingMenu(
      // 按到任何一格就請寵物那側重新計時（自動關選單的定時器住在那邊）
      onInteract: () => _send('interact'),
      feedLabel: payload.labelFor('feed'),
      petLabel: payload.labelFor('pet'),
      closeLabel: payload.labelFor('close'),
      freezeLabel: payload.labelFor('freeze'),
      quitLabel: payload.labelFor('quit'),
      onFeed: () => _send('feed'),
      onPet: () => _send('pet'),
      onFreeze: () => _send('freeze'),
      onClose: () => _send('close'),
      onQuit: () => _send('quit'),
      tiles: [
        for (final behavior in kFlourishBehaviors)
          FeedingMenuTile(
            icon: _iconFor(behavior),
            label: payload.labelFor(behavior.name),
            // 定格時 `playFlourish` 會靜默丟掉這些動作 —— 變灰比較誠實。（要的是「解凍再播」嗎？
            // 那是「定格該不該被選單打破」的產品決定，尚未拍板，見 TODO）
            enabled: !payload.frozen,
            onTap: () => _send(behavior.name),
          ),
      ],
      footnote: payload.labels['feedUnfreezes'],
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [hunger, const SizedBox(height: 8), menu],
    );
  }
}
