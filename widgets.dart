import 'package:flutter/material.dart';
import 'models.dart';
import 'theme.dart';

Color tone(String seed, {double lightness = 0.28}) {
  final h = seed.codeUnits.fold<int>(0, (a, b) => (a * 31 + b) % 360);
  return HSLColor.fromAHSL(1, h.toDouble(), 0.35, lightness).toColor();
}

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
            colors: [tone(title), tone(title, lightness: 0.14)],
          ),
        ),
      ),
      if (url == null)
        label
      else
        Padding(
          padding: EdgeInsets.all(contain ? 18 : 0),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(4)),
        child: const Text('Diretta',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
      );
}

/// Contenitore con evidenziazione quando ha il focus (telecomando, tastiera).
class FocusTile extends StatefulWidget {
  final Widget Function(bool focused) builder;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const FocusTile({super.key, required this.builder, required this.onTap, this.onLongPress});

  @override
  State<FocusTile> createState() => _FocusTileState();
}

class _FocusTileState extends State<FocusTile> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _f ? 1.05 : 1,
      duration: const Duration(milliseconds: 140),
      child: InkWell(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onFocusChange: (v) => setState(() => _f = v),
        borderRadius: BorderRadius.circular(10),
        focusColor: Colors.transparent,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _f ? AppColors.accent : Colors.transparent, width: 2),
          ),
          child: widget.builder(_f),
        ),
      ),
    );
  }
}

class LiveCard extends StatelessWidget {
  final Item item;
  final bool fav;
  final VoidCallback onTap, onLong;
  const LiveCard(
      {super.key, required this.item, required this.fav, required this.onTap, required this.onLong});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: FocusTile(
        onTap: onTap,
        onLongPress: onLong,
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                Art(url: item.image, title: item.name, contain: true),
                const Positioned(right: 8, top: 8, child: LiveBadge()),
                if (fav)
                  const Positioned(
                      left: 8,
                      top: 8,
                      child: Icon(Icons.favorite_rounded, size: 18, color: AppColors.accent)),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(item.group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class PosterCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;
  const PosterCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: FocusTile(
        onTap: onTap,
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 2 / 3, child: Art(url: item.image, title: item.name)),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Text(item.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

class Rail extends StatelessWidget {
  final String title;
  final double height;
  final List<Widget> children;
  const Rail({super.key, required this.title, required this.height, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      SizedBox(
        height: height,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          itemCount: children.length,
          itemBuilder: (_, i) =>
              Padding(padding: const EdgeInsets.only(right: 14), child: children[i]),
        ),
      ),
    ]);
  }
}

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
            Row(children: [
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
              if (item.kind == Kind.live) ...[
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onFav,
                  icon: Icon(fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, size: 20),
                  label: Text(fav ? 'Nei preferiti' : 'Aggiungi ai preferiti'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.surfaceHigh),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                ),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

/// Riquadro grande in alto per eventi e canali in primo piano.
class EventBanner extends StatelessWidget {
  final String badge, title, subtitle, button;
  final bool live;
  final VoidCallback onPressed;
  const EventBanner({
    super.key,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.button,
    required this.live,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 400,
      child: Stack(fit: StackFit.expand, children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [tone(title, lightness: 0.34), AppColors.background],
            ),
          ),
        ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: live ? AppColors.accent : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(badge,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 12),
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.headlineMedium),
            const SizedBox(height: 6),
            Text(subtitle, style: text.bodySmall),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(button),
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

class MatchCard extends StatelessWidget {
  final Match match;
  final VoidCallback onWatch;
  const MatchCard({super.key, required this.match, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    const name = TextStyle(fontSize: 16, fontWeight: FontWeight.w700);
    return Container(
      width: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(match.league,
            style: const TextStyle(
                color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 12.5)),
        const SizedBox(height: 10),
        Text(match.home, maxLines: 1, overflow: TextOverflow.ellipsis, style: name),
        Text(match.away, maxLines: 1, overflow: TextOverflow.ellipsis, style: name),
        const SizedBox(height: 8),
        Text(match.when,
            style: TextStyle(
                fontSize: 13,
                color: match.live ? AppColors.accent : AppColors.textSecondary,
                fontWeight: match.live ? FontWeight.w700 : FontWeight.w400)),
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
