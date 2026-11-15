enum Kind { live, movie, series }

class Item {
  final String name, url, group;
  final String? image;
  final Kind kind;
  final String? seriesId;
  final int? added; // data di aggiunta (se il servizio la fornisce)
  const Item({
    required this.name,
    required this.url,
    required this.group,
    required this.kind,
    this.image,
    this.seriesId,
    this.added,
  });

  String get id => seriesId != null ? 'series:$seriesId' : url;

  Map<String, dynamic> toJson() =>
      {'n': name, 'u': url, 'g': group, 'k': kind.index, 'i': image, 's': seriesId, 'a': added};

  factory Item.fromJson(Map<String, dynamic> j) => Item(
        name: j['n'] as String,
        url: j['u'] as String,
        group: j['g'] as String,
        kind: Kind.values[j['k'] as int],
        image: j['i'] as String?,
        seriesId: j['s'] as String?,
        added: j['a'] as int?,
      );
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Partita di Serie A o Champions League.
class Fixture {
  final String home, away, league;
  final String tag; // 'a' Serie A, 'eu' coppe europee, 'nz' nazionali
  final int score;
  final String? homeBadge, awayBadge;
  final DateTime start;
  const Fixture({
    required this.home,
    required this.away,
    required this.league,
    required this.tag,
    required this.start,
    this.score = 0,
    this.homeBadge,
    this.awayBadge,
  });

  bool get live {
    final n = DateTime.now();
    return !n.isBefore(start) && n.isBefore(start.add(const Duration(hours: 2)));
  }

  String get when {
    if (live) return 'In corso';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(start.year, start.month, start.day);
    final diff = day.difference(today).inDays;
    final hm = '${_two(start.hour)}:${_two(start.minute)}';
    if (diff == 0) return 'Oggi $hm';
    if (diff == 1) return 'Domani $hm';
    const names = ['Lun', 'Mar', 'Mer', 'Gio', 'Ven', 'Sab', 'Dom'];
    return '${names[start.weekday - 1]} $hm';
  }
}

class Episode {
  final String title, url;
  final int season, number;
  const Episode({
    required this.title,
    required this.url,
    required this.season,
    required this.number,
  });
}
