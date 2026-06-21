import 'dart:convert';
import 'package:http/http.dart' as http;

const kAppVersion = '1.4.0';

class AppUpdateInfo {
  final String version;
  final String url;
  final String? body;
  final String? downloadUrl;
  const AppUpdateInfo({required this.version, required this.url, this.body, this.downloadUrl});
}

class AppUpdateService {
  static const _api =
      'https://api.github.com/repos/LittleSoldier2185/pso2-character-manager/releases/latest';

  static Future<AppUpdateInfo?> check() async {
    try {
      final res = await http
          .get(Uri.parse(_api))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag =
          ((data['tag_name'] as String?) ?? '').replaceFirst(RegExp(r'^[vV]'), '');
      if (!_isNewer(tag)) return null;
      final assets = (data['assets'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final zip = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').endsWith('.zip'),
        orElse: () => {},
      );
      return AppUpdateInfo(
        version: tag,
        url: (data['html_url'] as String?) ??
            'https://github.com/LittleSoldier2185/pso2-character-manager/releases/latest',
        body: data['body'] as String?,
        downloadUrl: zip['browser_download_url'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _isNewer(String latest) {
    if (latest.isEmpty) return false;
    parse(String v) =>
        v.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final l = parse(latest), c = parse(kAppVersion);
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }
}
