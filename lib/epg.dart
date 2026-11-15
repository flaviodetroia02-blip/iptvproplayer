import 'dart:convert';
import 'package:http/http.dart' as http;

class Programme {
  final String title, description;
  final DateTime start, end;
  const Programme({
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  double get progress {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0;
    return (DateTime.now().difference(start).inSeconds / total).clamp(0.0, 1.0).toDouble();
  }
}

class Epg {
  final Programme? now, next;
  const Epg({this.now, this.next});
}

// Indirizzi del tipo http://host:porta/live/utente/password/ID.m3u8 (o senza /live).
final _xt = RegExp(r'^(https?://[^/]+)/(?:live/)?([^/]+)/([^/]+)/(\d+)(?:\.[A-Za-z0-9]+)?(?:\?.*)?$');

String _b64(String s) {
  try {
    return utf8.decode(base64.decode(base64.normalize(s)), allowMalformed: true);
  } catch (_) {
    return s;
  }
}

/// Programma in onda e successivo, se il servizio fornisce la guida (formato Xtream).
Future<Epg?> fetchEpg(String streamUrl) async {
  final m = _xt.firstMatch(streamUrl);
  if (m == null) return null;
  try {
    final uri = Uri.parse('${m.group(1)}/player_api.php').replace(queryParameters: {
      'username': m.group(2)!,
      'password': m.group(3)!,
      'action': 'get_short_epg',
      'stream_id': m.group(4)!,
      'limit': '4',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
    final list = data is Map ? data['epg_listings'] : null;
    if (list is! List) return null;
    final items = <Programme>[];
    for (final e in list) {
      final s = int.tryParse('${e['start_timestamp']}');
      final en = int.tryParse('${e['stop_timestamp']}');
      if (s == null || en == null) continue;
      items.add(Programme(
        title: _b64('${e['title']}'),
        description: _b64('${e['description'] ?? ''}'),
        start: DateTime.fromMillisecondsSinceEpoch(s * 1000),
        end: DateTime.fromMillisecondsSinceEpoch(en * 1000),
      ));
    }
    items.sort((a, b) => a.start.compareTo(b.start));
    final now = DateTime.now();
    Programme? cur, nxt;
    for (final p in items) {
      if (cur == null && !now.isBefore(p.start) && now.isBefore(p.end)) {
        cur = p;
      } else if (nxt == null && p.start.isAfter(now)) {
        nxt = p;
      }
    }
    if (cur == null && nxt == null) return null;
    return Epg(now: cur, next: nxt);
  } catch (_) {
    return null;
  }
}
