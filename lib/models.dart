enum Kind { live, movie, series }

class Item {
  final String name, url, group;
  final String? image;
  final Kind kind;
  final String? seriesId;
  const Item({
    required this.name,
    required this.url,
    required this.group,
    required this.kind,
    this.image,
    this.seriesId,
  });

  String get id => seriesId != null ? 'series:$seriesId' : url;
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
