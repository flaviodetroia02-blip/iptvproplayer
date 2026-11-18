import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Copia locale della playlist: l'app si apre subito e aggiorna in secondo piano.
class CacheData {
  final int time;
  final List<Item> live, movies, series;
  const CacheData({required this.time, required this.live, required this.movies, required this.series});
}

Future<File?> _file() async {
  if (kIsWeb) return null;
  final d = await getApplicationSupportDirectory();
  return File('${d.path}${Platform.pathSeparator}playlist_cache.bin');
}

Uint8List _encode(List args) {
  List<Map<String, dynamic>> conv(List l) => [for (final i in l) (i as Item).toJson()];
  final m = {'k': args[0], 't': args[1], 'l': conv(args[2] as List), 'm': conv(args[3] as List), 's': conv(args[4] as List)};
  return Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(m))));
}

List<dynamic> _decode(Uint8List b) {
  final m = jsonDecode(utf8.decode(gzip.decode(b))) as Map<String, dynamic>;
  List<Item> items(String k) => [for (final j in m[k] as List) Item.fromJson(j as Map<String, dynamic>)];
  return [m['k'], m['t'], items('l'), items('m'), items('s')];
}

Future<void> saveCache(String key, List<Item> live, List<Item> movies, List<Item> series) async {
  try {
    final f = await _file();
    if (f == null) return;
    final bytes = await compute(_encode, [key, DateTime.now().millisecondsSinceEpoch, live, movies, series]);
    await f.writeAsBytes(bytes, flush: true);
  } catch (_) {}
}

Future<CacheData?> loadCache(String key) async {
  try {
    final f = await _file();
    if (f == null || !await f.exists()) return null;
    final r = await compute(_decode, await f.readAsBytes());
    if (r[0] != key) return null;
    return CacheData(
      time: r[1] as int,
      live: (r[2] as List).cast<Item>(),
      movies: (r[3] as List).cast<Item>(),
      series: (r[4] as List).cast<Item>(),
    );
  } catch (_) {
    return null;
  }
}

Future<void> deleteCache() async {
  try {
    final f = await _file();
    if (f != null && await f.exists()) await f.delete();
  } catch (_) {}
}
