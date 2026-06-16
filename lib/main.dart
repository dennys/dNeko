import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'overlay_main.dart' as overlay_entry;
import 'data/repositories/animal_repository.dart';
import 'data/services/animal_download_service.dart';
import 'data/services/static_store_catalog.dart';
import 'presentation/controllers/store_controller.dart';
import 'presentation/pages/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = AnimalRepository();
  await repository.seedBuiltIns();
  final downloadService = AnimalDownloadService(repository);
  final storeController = StoreController(
    catalog: StaticStoreCatalog(),
    downloadService: downloadService,
    repository: repository,
  );
  runApp(MyApp(storeController: storeController));
}

@pragma('vm:entry-point')
void overlayMain() {
  overlay_entry.runOverlayApp();
}

class MyApp extends StatelessWidget {
  final StoreController storeController;

  const MyApp({super.key, required this.storeController});

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
      home: HomePage(storeController: storeController),
    );
  }
}
