import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Errore di rete con un messaggio già pronto da mostrare.
class NetError implements Exception {
  final String message;
  const NetError(this.message);
  @override
  String toString() => message;
}

const _ua =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

const _vpnHint = 'Con una VPN attiva succede spesso: molti servizi bloccano gli indirizzi delle VPN. '
    'Prova un altro server (meglio in Italia), un altro protocollo, oppure escludi PRIMA dalla VPN.';

/// Trasforma un errore tecnico in una spiegazione comprensibile.
String explain(Object e) {
  if (e is NetError) return e.message;
  if (e is TimeoutException) return 'Il server non risponde in tempo. $_vpnHint';
  if (e is HandshakeException) return 'Errore di sicurezza nella connessione (certificato non valido).';
  if (e is SocketException) return 'Impossibile raggiungere il server: controlla internet, il DNS o la VPN.';
  if (e is http.ClientException) return 'Connessione interrotta dal server. Riprova tra poco.';
  return 'Caricamento non riuscito. Controlla link o credenziali e la connessione.';
}

/// Scarica un indirizzo con nuovi tentativi. Il limite di tempo vale per i periodi
/// senza dati, quindi una playlist grande su una connessione lenta ma attiva non viene interrotta.
Future<Uint8List> fetchBytes(Uri uri, {Duration idle = const Duration(seconds: 40), int tries = 2}) async {
  Object? last;
  for (var attempt = 1; attempt <= tries; attempt++) {
    final client = http.Client();
    try {
      final req = http.Request('GET', uri)..headers['User-Agent'] = _ua;
      final resp = await client.send(req).timeout(const Duration(seconds: 20));
      final code = resp.statusCode;
      if (code == 401 || code == 403 || code == 451) {
        throw NetError('Il server ha rifiutato la richiesta (errore $code). $_vpnHint');
      }
      if (code >= 400 && code < 500) {
        throw NetError('Il server ha risposto con errore $code. Controlla indirizzo e credenziali.');
      }
      if (code != 200) throw http.ClientException('stato $code', uri);
      final b = BytesBuilder(copy: false);
      await for (final chunk in resp.stream.timeout(idle)) {
        b.add(chunk);
      }
      return b.takeBytes();
    } on NetError {
      rethrow;
    } catch (e) {
      last = e;
      if (attempt < tries) await Future.delayed(Duration(seconds: 2 * attempt));
    } finally {
      client.close();
    }
  }
  throw last ?? const NetError('Caricamento non riuscito.');
}

/// Velocità di download stimata in Mbit/s (null se non misurabile).
Future<double?> speedTestMbps() async {
  try {
    final sw = Stopwatch()..start();
    final r = await http
        .get(Uri.parse('https://speed.cloudflare.com/__down?bytes=3000000'))
        .timeout(const Duration(seconds: 12));
    sw.stop();
    if (r.statusCode != 200 || sw.elapsedMilliseconds == 0) return null;
    return (r.bodyBytes.length * 8) / (sw.elapsedMilliseconds / 1000) / 1e6;
  } on TimeoutException {
    return 0.5;
  } catch (_) {
    return null;
  }
}
