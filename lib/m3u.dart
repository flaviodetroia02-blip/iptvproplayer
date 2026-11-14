import 'models.dart';

final _attr = RegExp(r'([\w-]+)="([^"]*)"');

/// Legge una playlist M3U/M3U8. Distingue film e serie dal percorso
/// dell'indirizzo (/movie/, /series/); tutto il resto è TV diretta.
List<Item> parseM3u(String text) {
  final items = <Item>[];
  String? name, group, logo;
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.startsWith('#EXTINF')) {
      final attrs = {
        for (final m in _attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!,
      };
      final comma = line.lastIndexOf(',');
      var n = comma >= 0 ? line.substring(comma + 1).trim() : '';
      if (n.isEmpty) n = attrs['tvg-name'] ?? 'Senza nome';
      name = n;
      final g = (attrs['group-title'] ?? '').trim();
      group = g.isEmpty ? 'Altro' : g;
      logo = attrs['tvg-logo'];
    } else if (line.isNotEmpty && !line.startsWith('#') && name != null) {
      final lower = line.toLowerCase();
      final kind = lower.contains('/movie/')
          ? Kind.movie
          : lower.contains('/series/')
              ? Kind.series
              : Kind.live;
      items.add(Item(
        name: name,
        url: line,
        group: group ?? 'Altro',
        kind: kind,
        image: (logo == null || !logo.startsWith('http')) ? null : logo,
      ));
      name = null;
    }
  }
  return items;
}
