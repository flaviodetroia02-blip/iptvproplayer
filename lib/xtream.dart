import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'models.dart';
import 'net.dart';

dynamic _decodeJson(Uint8List b) => jsonDecode(utf8.decode(b, allowMalformed: true));

class XtreamClient {
  final String server, user, pass;
  XtreamClient(String s, this.user, this.pass) : server = normServer(s);

  static String normServer(String s) {
    var v = s.trim();
    if (!v.startsWith('http')) v = 'http://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  Uri _uri(String? action, Map<String, String> extra) =>
      Uri.parse('$server/player_api.php').replace(queryParameters: {
        'username': user,
        'password': pass,
        if (action != null) 'action': action,
        ...extra,
      });

  Future<dynamic> _get(String? action, {Map<String, String> extra = const {}, int tries = 2}) async {
    final bytes = await fetchBytes(_uri(action, extra), idle: const Duration(seconds: 45), tries: tries);
    return compute(_decodeJson, bytes); // la lettura dei dati avviene fuori dal thread principale
  }

  /// Verifica utente e abbonamento, con messaggi chiari.
  Future<Map<String, dynamic>> checkLogin({int tries = 2}) async {
    final d = await _get(null, tries: tries);
    final info = d is Map ? d['user_info'] : null;
    if (info is! Map) {
      throw const NetError('Il server non ha riconosciuto i dati inseriti. Controlla indirizzo, utente e password.');
    }
    if ('${info['auth']}' == '0') throw const NetError('Utente o password non validi.');
    final status = '${info['status']}'.toLowerCase();
    if (status == 'expired') throw const NetError('Abbonamento scaduto.');
    if (status == 'disabled' || status == 'banned') throw const NetError('Account disattivato dal fornitore.');
    return Map<String, dynamic>.from(info);
  }

  Map<String, String> _catMap(dynamic d) =>
      d is List ? {for (final c in d) '${c['category_id']}': '${c['category_name']}'} : {};

  String? _img(dynamic v) {
    final s = v?.toString() ?? '';
    return s.startsWith('http') ? s : null;
  }

  Future<List<Item>> live() async {
    final r = await Future.wait([_get('get_live_categories'), _get('get_live_streams')]);
    final cats = _catMap(r[0]);
    final data = r[1];
    if (data is! List) return [];
    return [
      for (final s in data)
        Item(
          name: '${s['name']}',
          url: '$server/live/$user/$pass/${s['stream_id']}.m3u8',
          group: cats['${s['category_id']}'] ?? 'Altro',
          kind: Kind.live,
          image: _img(s['stream_icon']),
        ),
    ];
  }

  Future<List<Item>> movies() async {
    final r = await Future.wait([_get('get_vod_categories'), _get('get_vod_streams')]);
    final cats = _catMap(r[0]);
    final data = r[1];
    if (data is! List) return [];
    return [
      for (final s in data)
        Item(
          name: '${s['name']}',
          url: '$server/movie/$user/$pass/${s['stream_id']}.${s['container_extension'] ?? 'mp4'}',
          group: cats['${s['category_id']}'] ?? 'Altro',
          kind: Kind.movie,
          image: _img(s['stream_icon']),
          added: int.tryParse('${s['added']}'),
        ),
    ];
  }

  Future<List<Item>> series() async {
    final r = await Future.wait([_get('get_series_categories'), _get('get_series')]);
    final cats = _catMap(r[0]);
    final data = r[1];
    if (data is! List) return [];
    return [
      for (final s in data)
        Item(
          name: '${s['name']}',
          url: '',
          seriesId: '${s['series_id']}',
          group: cats['${s['category_id']}'] ?? 'Altro',
          kind: Kind.series,
          image: _img(s['cover']),
          added: int.tryParse('${s['last_modified']}'),
        ),
    ];
  }

  Future<List<Episode>> episodes(String seriesId) async {
    final data = await _get('get_series_info', extra: {'series_id': seriesId});
    final eps = data is Map ? data['episodes'] : null;
    final out = <Episode>[];
    if (eps is Map) {
      eps.forEach((season, list) {
        for (final e in list as List) {
          out.add(Episode(
            title: '${e['title']}',
            url: '$server/series/$user/$pass/${e['id']}.${e['container_extension'] ?? 'mp4'}',
            season: int.tryParse('$season') ?? 1,
            number: int.tryParse('${e['episode_num']}') ?? 0,
          ));
        }
      });
    }
    out.sort((a, b) =>
        a.season != b.season ? a.season.compareTo(b.season) : a.number.compareTo(b.number));
    return out;
  }
}
