import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class XtreamClient {
  final String server, user, pass;
  XtreamClient(String s, this.user, this.pass) : server = _norm(s);

  static String _norm(String s) {
    var v = s.trim();
    if (!v.startsWith('http')) v = 'http://$v';
    while (v.endsWith('/')) {
      v = v.substring(0, v.length - 1);
    }
    return v;
  }

  Future<dynamic> _get(String action, [Map<String, String> extra = const {}]) async {
    final uri = Uri.parse('$server/player_api.php').replace(queryParameters: {
      'username': user,
      'password': pass,
      'action': action,
      ...extra,
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 45));
    if (r.statusCode != 200) throw Exception('Risposta ${r.statusCode}');
    return jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
  }

  Future<Map<String, String>> _cats(String action) async {
    final data = (await _get(action)) as List;
    return {for (final c in data) '${c['category_id']}': '${c['category_name']}'};
  }

  String? _img(dynamic v) {
    final s = v?.toString() ?? '';
    return s.startsWith('http') ? s : null;
  }

  Future<List<Item>> live() async {
    final cats = await _cats('get_live_categories');
    final data = (await _get('get_live_streams')) as List;
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
    final cats = await _cats('get_vod_categories');
    final data = (await _get('get_vod_streams')) as List;
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
    final cats = await _cats('get_series_categories');
    final data = (await _get('get_series')) as List;
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
    final data = await _get('get_series_info', {'series_id': seriesId});
    final eps = data['episodes'];
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
