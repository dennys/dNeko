import 'app_localizations.dart';

/// 內建動物的名字跟著語系走（animation.json 裡的 displayName 是寫死的中文，
/// 換語系不會變）；下載回來的動物我們不知道作者取的名字，維持素材本名。
extension AnimalNameL10n on AppLocalizations {
  String animalName(String animalId, String fallback) => switch (animalId) {
    'cat' => animalCat,
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
