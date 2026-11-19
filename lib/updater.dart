import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'device.dart';
import 'net.dart';
import 'theme.dart';

/// Numero di compilazione, inserito automaticamente da GitHub (0 = versione di prova).
const kBuild = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);
const kRepo = 'flaviodetroia02-blip/iptvproplayer';

class UpdateInfo {
  final int build;
  final String url;
  const UpdateInfo(this.build, this.url);
}

class UpdateCheck {
  final String message;
  final UpdateInfo? info;
  const UpdateCheck(this.message, [this.info]);
}

/// Controlla se su GitHub c'è una versione più recente e spiega il risultato.
Future<UpdateCheck> checkUpdateDetailed() async {
  if (kIsWeb) return const UpdateCheck('Sulla versione web gli aggiornamenti sono automatici.');
  if (kBuild == 0) {
    return const UpdateCheck('Questa copia è stata installata senza numero di compilazione, quindi non può '
        'controllare gli aggiornamenti. Installa a mano l\'ultima versione da "Releases" su GitHub: '
        'da quella in poi funzionerà.');
  }
  final String asset;
  if (Platform.isAndroid) {
    asset = 'PRIMA.apk';
  } else if (Platform.isWindows) {
    asset = 'PRIMA-windows.zip';
  } else {
    return const UpdateCheck('Aggiornamento automatico non disponibile su questo dispositivo.');
  }
  try {
    final r = await http
        .get(Uri.parse('https://api.github.com/repos/$kRepo/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'})
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) {
      return const UpdateCheck('Su GitHub non risulta nessuna versione pubblicata, oppure la repo è ancora privata.');
    }
    if (r.statusCode != 200) return UpdateCheck('GitHub ha risposto con errore ${r.statusCode}. Riprova più tardi.');
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    final tag = '${j['tag_name']}';
    final b = int.tryParse(tag.replaceAll(RegExp(r'[^0-9]'), ''));
    if (b == null) return UpdateCheck('Numero di versione non riconosciuto ($tag).');
    if (b <= kBuild) return UpdateCheck('Sei aggiornato. Versione installata: build $kBuild. Ultima su GitHub: build $b.');
    for (final a in (j['assets'] as List? ?? [])) {
      if (a['name'] == asset) {
        return UpdateCheck('Nuova versione disponibile: build $b (installata: build $kBuild).',
            UpdateInfo(b, '${a['browser_download_url']}'));
      }
    }
    return UpdateCheck('Esiste la build $b ma non contiene il file $asset.');
  } catch (e) {
    return UpdateCheck('Non riesco a contattare GitHub. ${explain(e)}');
  }
}

Future<UpdateInfo?> checkForUpdate() async => (await checkUpdateDetailed()).info;

/// Errore di aggiornamento con messaggio già pronto.
class UpdateError implements Exception {
  final String message;
  const UpdateError(this.message);
}

/// Su Android chiede il permesso di installare app (necessario per l'aggiornamento).
Future<bool> askInstallPermission(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return true;
  if (await Permission.requestInstallPackages.isGranted) return true;
  if (!context.mounted) return false;
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Permesso necessario'),
      content: const Text('Per installare l\'aggiornamento Android deve consentire a PRIMA di installare app. '
          'Premi Continua: si apre la schermata delle impostazioni. Attiva l\'interruttore e torna indietro.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
        FilledButton(
          autofocus: true,
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
          child: const Text('Continua'),
        ),
      ],
    ),
  );
  if (go != true) return false;
  final r = await Permission.requestInstallPackages.request();
  return r.isGranted;
}

Future<File> _target() async {
  try {
    Directory? dir;
    if (Platform.isAndroid) dir = await getExternalStorageDirectory();
    dir ??= await getTemporaryDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}${Platform.isAndroid ? 'PRIMA-update.apk' : 'PRIMA-update.zip'}');
    if (await f.exists()) await f.delete();
    return f;
  } catch (_) {
    throw const UpdateError('Non riesco a preparare lo spazio per il download.');
  }
}

/// Scarica l'aggiornamento e lo installa (Android: installazione guidata; Windows: sostituzione dei file).
/// Restituisce un messaggio da mostrare all'utente, se serve.
Future<String?> installUpdate(UpdateInfo u, void Function(double?) onProgress) async {
  final file = await _target();
  final client = http.Client();
  try {
    final resp = await client.send(http.Request('GET', Uri.parse(u.url))).timeout(const Duration(seconds: 30));
    if (resp.statusCode != 200) throw UpdateError('Download non riuscito (errore ${resp.statusCode}).');
    final total = resp.contentLength ?? 0;
    var got = 0;
    final sink = file.openWrite();
    try {
      await for (final chunk in resp.stream.timeout(const Duration(seconds: 40))) {
        sink.add(chunk);
        got += chunk.length;
        onProgress(total > 0 ? got / total : null);
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && got < total) throw const UpdateError('Download interrotto. Riprova.');
  } on UpdateError {
    rethrow;
  } catch (e) {
    throw UpdateError(explain(e));
  } finally {
    client.close();
  }

  if (Platform.isAndroid) {
    final r = await OpenFilex.open(file.path, type: 'application/vnd.android.package-archive');
    switch (r.type) {
      case ResultType.done:
        return 'Conferma l\'installazione nella schermata di Android.';
      case ResultType.permissionDenied:
        throw const UpdateError('Permesso negato: consenti a PRIMA di installare app e riprova.');
      case ResultType.fileNotFound:
        throw const UpdateError('File di aggiornamento non trovato. Riprova.');
      case ResultType.noAppToOpen:
        throw const UpdateError('Questo dispositivo non ha un installatore di pacchetti disponibile.');
      default:
        throw UpdateError('Installazione non partita. ${r.message}');
    }
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
  return null;
}

/// Banner "Nuova versione disponibile" con tasto Aggiorna.
class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key});

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> with WidgetsBindingObserver {
  UpdateInfo? _info;
  bool _hidden = false, _busy = false;
  double? _progress;
  String? _error, _note;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
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
    if (!await askInstallPermission(context)) {
      if (mounted) setState(() => _error = 'Senza il permesso non posso installare l\'aggiornamento.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
      _note = null;
    });
    try {
      final note = await installUpdate(_info!, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _note = note);
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is UpdateError ? e.message : 'Aggiornamento non riuscito. Riprova più tardi.');
      }
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
                  _error ??
                      _note ??
                      (_busy
                          ? 'Scarico l\'aggiornamento…${_progress != null ? ' ${(_progress! * 100).round()}%' : ''}'
                          : 'Aggiorna per avere le ultime novità.'),
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
                child: Text(_note != null ? 'Riapri' : 'Aggiorna'),
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

/// Finestra con il risultato del controllo e il tasto per aggiornare.
class UpdateDialog extends StatefulWidget {
  const UpdateDialog({super.key});

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  UpdateCheck? _c;
  bool _busy = false;
  double? _progress;
  String? _err, _note;

  @override
  void initState() {
    super.initState();
    checkUpdateDetailed().then((c) {
      if (mounted) setState(() => _c = c);
    });
  }

  Future<void> _run() async {
    if (!await askInstallPermission(context)) {
      if (mounted) setState(() => _err = 'Senza il permesso non posso installare l\'aggiornamento.');
      return;
    }
    setState(() {
      _busy = true;
      _progress = 0;
      _err = null;
      _note = null;
    });
    try {
      final note = await installUpdate(_c!.info!, (p) {
        if (mounted) setState(() => _progress = p);
      });
      if (mounted) setState(() => _note = note);
    } catch (e) {
      if (mounted) setState(() => _err = e is UpdateError ? e.message : 'Aggiornamento non riuscito. Riprova più tardi.');
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Aggiornamenti'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (c == null)
            const Row(children: [
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent)),
              SizedBox(width: 12),
              Text('Controllo su GitHub…'),
            ])
          else
            Text(c.message),
          if (_busy) ...[
            const SizedBox(height: 14),
            LinearProgressIndicator(value: _progress, minHeight: 4, color: AppColors.accent),
            const SizedBox(height: 6),
            Text('Scarico… ${_progress != null ? '${(_progress! * 100).round()}%' : ''}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ],
          if (_note != null) ...[
            const SizedBox(height: 10),
            Text(_note!, style: const TextStyle(color: AppColors.textSecondary)),
          ],
          if (_err != null) ...[
            const SizedBox(height: 10),
            Text(_err!, style: const TextStyle(color: AppColors.accent)),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Chiudi')),
        if (c?.info != null && !_busy)
          FilledButton(
            onPressed: _run,
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Aggiorna ora'),
          ),
      ],
    );
  }
}
