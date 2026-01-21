import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dneko/generated/l10n/app_localizations.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'dNeko',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'dNeko'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.dneko/native');

  String _result = 'No result yet';

  Future<void> _callNativeMethod() async {
    String result;
    try {
      final String response = await platform.invokeMethod('getNativeMessage');
      result = AppLocalizations.of(context)!.nativeSays(response);
    } on PlatformException catch (e) {
      result = AppLocalizations.of(context)!.failedToGetNativeMessage(e.message ?? '');
    }

    setState(() {
      _result = result;
    });
  }

  Future<void> _showOverlay() async {
    try {
      await platform.invokeMethod('showOverlay');
      setState(() {
        _result = 'Overlay displayed!';
      });
    } on PlatformException catch (e) {
      setState(() {
        _result = 'Failed to show overlay: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Center(child: Text(AppLocalizations.of(context)!.appTitle)),
      ),
      body: Column(
        children: <Widget>[
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _callNativeMethod,
            child: Text(AppLocalizations.of(context)!.callNativeMethod),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _showOverlay,
            child: const Text('Show Dneko Overlay'),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    AppLocalizations.of(context)!.callNativePlatformCode,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _result,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
