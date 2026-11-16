import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'device.dart';
import 'theme.dart';

/// Numero di compilazione, inserito automaticamente da GitHub (0 = versione di prova).
const kBuild = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
const kRepo = 'flaviodetroia02-blip/iptvproplayer';

class UpdateInfo {
  final int build;
  final String url;
  const UpdateInfo(this.build, this.url);
}

/// Controlla se su GitHub c'è una versione più recente di quella installata.
Future<UpdateInfo?> checkForUpdate() async {
  if (kIsWeb || kBuild == 0) return null;
  final String asset;
  if (Platform.isAndroid) {
    asset = 'PRIMA.apk';
  } else if (Platform.isWindows) {
    asset = 'PRIMA-windows.zip';
  } else {
    return null;
  }
  try {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final b = int.tryParse('${j['tag_name']}'.replaceAll(RegExp(r'[^0-9]'), ''));
    if (b == null || b <= kBuild) return null;
    for (final a in (j['assets'] as List? ?? [])) {
      if (a['name'] == asset) return UpdateInfo(b, '${a['browser_download_url']}');
    }
  } catch (_) {}
  return null;
}

/// Scarica l'aggiornamento e lo installa (Android: installazione guidata; Windows: sostituzione dei file).
Future<void> installUpdate(UpdateInfo u, void Function(double?) onProgress) async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}${Platform.pathSeparator}${Platform.isAndroid ? 'PRIMA-update.apk' : 'PRIMA-update.zip'}');
  final client = http.Client();
  try {
    final resp = await client.send(http.Request('GET', Uri.parse(u.url)));
    if (resp.statusCode != 200) throw Exception('download');
    final total = resp.contentLength ?? 0;
    var got = 0;
    final sink = file.openWrite();
    await for (final chunk in resp.stream) {
      sink.add(chunk);
      got += chunk.length;
      onProgress(total > 0 ? got / total : null);
    }
    await sink.close();
  } finally {
    client.close();
  }
  if (Platform.isAndroid) {
    await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
  } else if (Platform.isWindows) {
    final exe = Platform.resolvedExecutable;
    final appDir = File(exe).parent.path;
    final tmp = Directory.systemTemp.createTempSync('prima_upd').path;
    final script = File('$tmp\\aggiorna.bat');
    await script.writeAsString('@echo off\r\n'
        'timeout /t 3 /nobreak >nul\r\n'
        'powershell -NoProfile -Command "Expand-Archive -Force -LiteralPath \'${file.path}\' -DestinationPath \'$tmp\\new\'"\r\n'
        'xcopy /E /Y /I "$tmp\\new\\*" "$appDir\\" >nul\r\n'
        'start "" "$exe"\r\n');
    await Process.start('cmd', ['/c', script.path], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// Banner "Nuova versione disponibile" con tasto Aggiorna.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  UpdateInfo? _info;
  bool _hidden = false, _busy = false;
  double? _progress;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _check();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    final u = await checkForUpdate();
    if (!mounted || u == null) return;
    setState(() {
      if (_info?.build != u.build) _hidden = false;
      _info = u;
    });
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      await installUpdate(_info!, (p) {
        if (mounted) setState(() => _progress = p);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Aggiornamento non riuscito. Riprova più tardi.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null || _hidden) return const SizedBox.shrink();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          color: const Color(0xF21B1B1F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x66E5173F)),
          boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 28, offset: Offset(0, 10))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.system_update_rounded, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Nuova versione disponibile',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  _error ?? (_busy ? 'Scarico l\'aggiornamento…' : 'Aggiorna per avere le ultime novità.'),
                  style: TextStyle(
                      fontSize: 12.5, color: _error != null ? AppColors.accent : AppColors.textSecondary),
                ),
              ]),
            ),
            if (!_busy) ...[
              FilledButton(
                onPressed: _run,
                autofocus: Device.isTv,
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                child: const Text('Aggiorna'),
              ),
              IconButton(
                tooltip: 'Più tardi',
                onPressed: () => setState(() => _hidden = true),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ]),
          if (_busy) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: LinearProgressIndicator(
                  value: _progress, minHeight: 4, color: AppColors.accent, backgroundColor: const Color(0x33FFFFFF)),
            ),
          ],
        ]),
      ),
    );
  }
}
