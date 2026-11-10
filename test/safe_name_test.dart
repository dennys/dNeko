import 'package:dneko/data/services/animal_download_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// path traversal 守門員（REVIEW #8）：animalId / 檔名未來會來自遠端 catalogue，
/// 一旦放行 `..` 或絕對路徑，p.join 會把檔案寫到 animals/ 資料夾以外。
void main() {
  group('safeName', () {
    test('正常的 id 與檔名原樣通過', () {
      expect(safeName('cat', 'animalId'), 'cat');
      expect(safeName('animation.json', 'fileNames[0]'), 'animation.json');
      expect(safeName('heart_dog', 'animalId'), 'heart_dog');
    });

    test('空字串與 . / .. 擋掉', () {
      expect(() => safeName('', 'animalId'), throwsArgumentError);
      expect(() => safeName('.', 'animalId'), throwsArgumentError);
      expect(() => safeName('..', 'animalId'), throwsArgumentError);
    });

    test('路徑分隔字元擋掉（Windows 與 POSIX 都要）', () {
      expect(() => safeName('a/b', 'animalId'), throwsArgumentError);
      expect(() => safeName('a\\b', 'animalId'), throwsArgumentError);
    });

    test('絕對路徑擋掉', () {
      expect(() => safeName('/etc/passwd', 'animalId'), throwsArgumentError);
      expect(() => safeName('C:\\Windows', 'animalId'), throwsArgumentError);
    });

    test('例外訊息帶欄位名（logcat 看得懂是哪個欄位壞了）', () {
      expect(
        () => safeName('..', 'fileNames[3]'),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'fileNames[3]')),
      );
    });
  });
}