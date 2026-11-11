import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 本案 repo 是 **public**：機器名、內網 IP、帳號路徑、金鑰檔名不許進版控。
/// 這類字串「寫的時候覺得方便、事後刪不掉」—— 公開 repo 的歷史 commit 改不掉，
/// 本案已經為一把洩漏的 keystore 密碼換過一次鑰。所以把它變成會紅的測試，而不是靠記憶。
///
/// 中性詞對上哪台機器，記在 `~/dennys/AGENTS.md` 的「文件用詞」節（那支檔不在版控裡）。
/// 詞條刻意用串接寫 —— 否則這支測試會掃到自己。
const Map<String, String> _forbidden = {
  'dg' 'x1': '機器名 → 文件寫「Linux/aarch64 開發機」',
  'v5' 'llm': '離線機主機名 → 寫「離線機」',
  'hc' 'vllm': '內網主機名 → 不要寫進 repo',
  '10.' '191.': '內網 IP → 不要寫進 repo',
  'id_' 'ed25519': '金鑰檔名 → 不要寫進 repo',
  '/home/' 'v5': '本機帳號路徑 → 改用 ~',
};

/// 只掃會寫人話的檔案；PNG／jar 等二進位不掃（亂碼會誤判）
const _extensions = {
  '.md', '.dart', '.yaml', '.yml', '.json', '.txt', '.sh', //
  '.kt', '.kts', '.java', '.xml', '.gradle', '.properties',
};

bool _wanted(String path) {
  final dot = path.lastIndexOf('.');
  return dot > 0 && _extensions.contains(path.substring(dot));
}

void main() {
  test('版控裡不許出現機器名 / IP / 帳號（repo 是 public）', () {
    // 用 git ls-files 而不是走目錄：測試的契約是「**版控裡**不許出現」，而 build 產物
    // （android/local.properties、ios/Flutter/flutter_export_environment.sh）本來就含本機
    // 絕對路徑，它們被 .gitignore 擋著、不該算，也不該由這裡硬寫清單去排除。
    final git = Process.runSync('git', ['ls-files', '-z']);
    if (git.exitCode != 0) {
      // 掃不到檔清單 = 檢查器壞掉，必須紅，不能當成通過
      throw StateError('git ls-files 失敗：${git.stderr}');
    }
    final files = (git.stdout as String)
        .split('\u0000')
        .where((p) => p.isNotEmpty && _wanted(p) && File(p).existsSync())
        .toList();

    final hits = <String>[];
    for (final path in files) {
      final lines = File(path).readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].toLowerCase();
        for (final entry in _forbidden.entries) {
          if (line.contains(entry.key.toLowerCase())) {
            hits.add('$path:${i + 1}  [${entry.key}] ${entry.value}\n'
                '      ${lines[i].trim()}');
          }
        }
      }
    }

    // 防呆：掃描範圍壞了會讓這條變成「怎麼跑都過」的假綠燈（本案的守門員測試都要附這條）
    expect(files.length, greaterThan(50), reason: '只掃到 ${files.length} 個檔，掃描範圍不對');
    expect(
      hits,
      isEmpty,
      reason: '改成中性說法（對照表在 ~/dennys/AGENTS.md「文件用詞」節）\n\n${hits.join("\n")}',
    );
  });
}
