import 'app_localizations.dart';

/// 內建動物的名字跟著語系走（animation.json 裡的 displayName 是寫死的中文，
/// 換語系不會變）；下載回來的動物我們不知道作者取的名字，維持素材本名。
///
/// ⚠️ 新增內建動物要這裡加一格 ＋ 四份 arb 各加一個 `animalXxx`，漏了的症狀是
/// 「只有那個語系看得到中文本名」（`test/l10n_arb_test.dart` 鎖住了這件事）。
extension AnimalNameL10n on AppLocalizations {
  String animalName(String animalId, String fallback) => switch (animalId) {
    'cat' => animalCat,
    'cat2' => animalCat2,
    'dog' => animalDog,
    'penguin' => animalPenguin,
    'fox' => animalFox,
    'heart_dog' => animalHeartDog,
    'racoon' => animalRacoon,
    'sloth' => animalSloth,
    'monkey' => animalMonkey,
    _ => fallback,
  };
}
