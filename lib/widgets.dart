import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

Color tone(String seed, {double lightness = 0.28}) {
  final h = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) % 360);
  return HSLColor.fromAHSL(1, h.toDouble(), 0.35, lightness).toColor();
}

/// Fattore di ingrandimento per schermi grandi (PC e TV).
double uiScale(BuildContext c) {
  final w = MediaQuery.of(c).size.width;
  if (w >= 1700) return 1.35;
  if (w >= 1300) return 1.2;
  if (w >= 1000) return 1.1;
  return 1;
}

/// Margine laterale che cresce con la larghezza della finestra.
double sidePad(BuildContext c) => (MediaQuery.of(c).size.width * 0.03).clamp(20.0, 64.0).toDouble();

/// Immagine con sfondo sfumato di riserva (se manca o non carica).
class Art extends StatelessWidget {
  final String? url;
  final String title;
  final bool contain;
  const Art({super.key, required this.url, required this.title, this.contain = false});

  @override
  Widget build(BuildContext context) {
    final label = Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(title,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [tone(title), tone(title, lightness: 0.12)],
          ),
        ),
      ),
      if (url == null)
        label
      else
        Padding(
          padding: EdgeInsets.all(contain ? 22 : 0),
          child: Image.network(url!,
              fit: contain ? BoxFit.contain : BoxFit.cover,
              errorBuilder: (_, __, ___) => label),
        ),
    ]);
  }
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.circle, size: 6, color: Colors.white),
          SizedBox(width: 5),
          Text('DIRETTA',
              style: TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: Colors.white)),
        ]),
      );
}

/// Contenitore con ingrandimento al passaggio del mouse e al focus (telecomando, tastiera).
class FocusTile extends StatefulWidget {
  final Widget Function(bool active) builder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double radius, scale;
  final bool border;
  const FocusTile({
    super.key,
    required this.builder,
    required this.onTap,
    this.onLongPress,
    this.radius = 12,
    this.scale = 1.05,
    this.border = true,
  });

  @override
  State<FocusTile> createState() => _FocusTileState();
}

class _FocusTileState extends State<FocusTile> {
  bool _f = false, _h = false;

  @override
  Widget build(BuildContext context) {
    final active = _f || _h;
    return AnimatedScale(
      scale: active ? widget.scale : 1,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: (v) => setState(() => _f = v),
        onHover: (v) => setState(() => _h = v),
        borderRadius: BorderRadius.circular(widget.radius),
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(widget.radius),
            border: widget.border
                ? Border.all(color: _f ? AppColors.accent : const Color(0x14FFFFFF), width: 1.5)
                : (_f ? Border.all(color: Colors.white, width: 2) : null),
          ),
          child: widget.builder(active),
        ),
      ),
    );
  }
}

/// Scheda canale (stile DAZN): immagine 16:9 con etichetta in diretta, titolo sotto.
class LiveCard extends StatelessWidget {
  final Item item;
  final bool fav;
  final VoidCallback onTap, onLong;
  const LiveCard(
      {super.key, required this.item, required this.fav, required this.onTap, required this.onLong});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260 * uiScale(context),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        FocusTile(
          onTap: onTap,
          onLongPress: onLong,
          builder: (_) => AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(fit: StackFit.expand, children: [
              Art(url: item.image, title: item.name, contain: true),
              const Positioned(left: 10, top: 10, child: LiveBadge()),
              if (fav)
                const Positioned(
                    right: 10,
                    top: 10,
                    child: Icon(Icons.favorite_rounded, size: 18, color: AppColors.accent)),
            ]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 10, 2, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 2),
            Text(item.group,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

/// Locandina (stile Netflix): al passaggio del mouse compaiono titolo e tasto play.
class PosterCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  final double? progress; // quanto hai già guardato, da 0 a 1
  const PosterCard({super.key, required this.item, required this.onTap, this.progress});

  @override
  Widget build(BuildContext context) {
    final p = progress;
    return SizedBox(
      width: 150 * uiScale(context),
      child: FocusTile(
        radius: 6,
        scale: 1.08,
        border: false,
        onTap: onTap,
        builder: (active) => AspectRatio(
          aspectRatio: 2 / 3,
          child: Stack(fit: StackFit.expand, children: [
            Art(url: item.image, title: item.name),
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: active ? 1 : 0,
                duration: const Duration(milliseconds: 150),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0xEE000000)],
                      stops: [0.35, 1],
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(10, 10, 10, p != null ? 14 : 10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.name,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Container(
                            width: 30,
                            height: 30,
                            decoration:
                                const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (p != null && p > 0.01)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: p,
                  minHeight: 3,
                  backgroundColor: const Color(0x66000000),
                  color: AppColors.accent,
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

/// Riga scorrevole con frecce laterali (utili col mouse sul PC).
class Rail extends StatefulWidget {
  final String title;
  final double height;
  final List<Widget> children;
  final VoidCallback? onSeeAll;
  const Rail({
    super.key,
    required this.title,
    required this.height,
    required this.children,
    this.onSeeAll,
  });

  @override
  State<Rail> createState() => _RailState();
}

class _RailState extends State<Rail> {
  final _c = ScrollController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _scroll(int dir) {
    if (!_c.hasClients) return;
    final step = MediaQuery.of(context).size.width * 0.7;
    final target = (_c.offset + dir * step).clamp(0.0, _c.position.maxScrollExtent).toDouble();
    _c.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
  }

  Widget _arrow(IconData icon, int dir) => IconButton(
        onPressed: () => _scroll(dir),
        icon: Icon(icon, size: 26),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xB3000000),
          foregroundColor: Colors.white,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 700;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.title.isNotEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(sidePad(context), 26, 16, 0),
          child: Row(children: [
            Expanded(
              child: Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            if (widget.onSeeAll != null)
              TextButton(
                onPressed: widget.onSeeAll,
                style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Vedi tutti'),
                  Icon(Icons.chevron_right_rounded, size: 18),
                ]),
              ),
          ]),
        ),
      SizedBox(
        height: widget.height,
        child: Stack(children: [
          ListView.builder(
            controller: _c,
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sidePad(context), vertical: 14),
            itemCount: widget.children.length,
            itemBuilder: (_, i) =>
                Padding(padding: const EdgeInsets.only(right: 14), child: widget.children[i]),
          ),
          if (wide && widget.children.length > 3) ...[
            Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _arrow(Icons.chevron_left_rounded, -1))),
            Align(
                alignment: Alignment.centerRight,
                child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: _arrow(Icons.chevron_right_rounded, 1))),
          ],
        ]),
      ),
    ]);
  }
}

/// Schede dei giorni per il calendario (Oggi, Domani, ...).
class DayTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onSelect;
  const DayTabs({super.key, required this.labels, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: sidePad(context)),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(labels[i]),
          selected: i == selected,
          showCheckmark: false,
          onSelected: (_) => onSelect(i),
          selectedColor: AppColors.accent,
          backgroundColor: AppColors.surface,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          labelStyle: TextStyle(
            fontWeight: FontWeight.w600,
            color: i == selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Filtri per categoria, come le schede in alto di DAZN.
class GenreChips extends StatelessWidget {
  final List<String> groups;
  final String? selected;
  final ValueChanged<String?> onSelect;
  const GenreChips({super.key, required this.groups, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: sidePad(context)),
        itemCount: groups.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final label = i == 0 ? 'Tutti' : groups[i - 1];
          final sel = i == 0 ? selected == null : selected == label;
          return ChoiceChip(
            label: Text(label),
            selected: sel,
            showCheckmark: false,
            onSelected: (_) => onSelect(i == 0 ? null : label),
            selectedColor: AppColors.accent,
            backgroundColor: AppColors.surface,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              color: sel ? Colors.white : AppColors.textSecondary,
            ),
          );
        },
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String name;
  final String? url;
  const _TeamBadge({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(name.isEmpty ? '' : name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
    );
    return Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(4),
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(color: AppColors.surfaceHigh, shape: BoxShape.circle),
      child: url == null
          ? initial
          : Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => initial),
    );
  }
}

/// Scheda partita con stemmi, orario e tasto "Guarda ora".
class MatchCard extends StatelessWidget {
  final Fixture match;
  final VoidCallback onWatch;
  const MatchCard({super.key, required this.match, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    Widget team(String name, String? badge) => Row(children: [
          _TeamBadge(name: name, url: badge),
          const SizedBox(width: 10),
          Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ]);
    return Container(
      width: 300 * uiScale(context),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x14FFFFFF)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text(match.league,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ),
          Text(match.when,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: match.live ? FontWeight.w800 : FontWeight.w500,
                  color: match.live ? AppColors.accent : AppColors.textSecondary)),
        ]),
        const SizedBox(height: 14),
        team(match.home, match.homeBadge),
        const SizedBox(height: 10),
        team(match.away, match.awayBadge),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onWatch,
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Guarda ora'),
          ),
        ),
      ]),
    );
  }
}

/// Riquadro di riserva quando non ci sono anteprime disponibili.
class FeaturedBanner extends StatelessWidget {
  final Item item;
  final bool fav, cover;
  final String playLabel;
  final VoidCallback onPlay, onFav;
  const FeaturedBanner({
    super.key,
    required this.item,
    required this.fav,
    required this.cover,
    required this.playLabel,
    required this.onPlay,
    required this.onFav,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final bg = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [tone(item.name, lightness: 0.34), AppColors.background],
        ),
      ),
    );
    return SizedBox(
      height: 400,
      child: Stack(fit: StackFit.expand, children: [
        if (cover && item.image != null)
          Image.network(item.image!,
              fit: BoxFit.cover, alignment: Alignment.topCenter, errorBuilder: (_, __, ___) => bg)
        else
          bg,
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x00111113), AppColors.background],
              stops: [0.35, 1],
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 28,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (item.kind == Kind.live) ...[const LiveBadge(), const SizedBox(height: 12)],
            Text(item.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.headlineMedium),
            const SizedBox(height: 6),
            Text(item.group, style: text.bodySmall),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(playLabel),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _BigBadge extends StatelessWidget {
  final String name;
  final String? url;
  const _BigBadge({required this.name, required this.url});

  @override
  Widget build(BuildContext context) {
    final initial = Center(
      child: Text(name.isEmpty ? '' : name[0].toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 40)),
    );
    return Container(
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0x22FFFFFF),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: url == null
          ? initial
          : Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => initial),
    );
  }
}

/// Locandina dell'evento mostrata 5 secondi prima che parta l'anteprima.
class EventPoster extends StatelessWidget {
  final Fixture match;
  const EventPoster({super.key, required this.match});

  Widget _side(String name, String? badge) => SizedBox(
        width: 150,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _BigBadge(name: name, url: badge),
          const SizedBox(height: 10),
          Text(name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              tone(match.home, lightness: 0.3),
              const Color(0xFF0B0B0D),
              tone(match.away, lightness: 0.3),
            ],
            stops: const [0, 0.5, 1],
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 0.8,
            colors: [Color(0x22FFFFFF), Color(0x00000000)],
          ),
        ),
      ),
      Align(
        alignment: const Alignment(0, -0.42),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(match.league.toUpperCase(),
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4,
                    color: Color(0xB3FFFFFF))),
            const SizedBox(height: 20),
            Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _side(match.home, match.homeBadge),
              const SizedBox(width: 24),
              Column(children: [
                const SizedBox(height: 28),
                const Text('VS',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: AppColors.accent)),
                const SizedBox(height: 8),
                Text(match.when, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(width: 24),
              _side(match.away, match.awayBadge),
            ]),
          ]),
        ),
      ),
    ]);
  }
}

/// Locandina di film e serie: occupa tutta l'area dell'anteprima.
class VodPoster extends StatelessWidget {
  final Item item;
  const VodPoster({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final img = item.image;
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [tone(item.name, lightness: 0.3), Colors.black],
        ),
      ),
    );
    if (img == null) return fallback;
    return Stack(fit: StackFit.expand, children: [
      fallback,
      Image.network(img,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.25),
          errorBuilder: (_, __, ___) => fallback),
      const ColoredBox(color: Color(0x44000000)),
    ]);
  }
}
