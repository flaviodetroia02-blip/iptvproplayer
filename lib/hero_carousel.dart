import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class HeroSlide {
  final String id, badge, title, subtitle;
  final bool live;
  final String? image; // locandina mostrata finché non parte il video
  final Item? preview; // contenuto mostrato in anteprima, senza audio
  final Future<String?> Function()? previewLoader; // per le serie: primo episodio
  final VoidCallback onWatch;
  final VoidCallback? onChange; // "Cambia canale"
  const HeroSlide({
    required this.id,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.live,
    required this.preview,
    required this.onWatch,
    this.image,
    this.previewLoader,
    this.onChange,
  });
}

/// Riquadro principale della home: anteprima video muta che parte da sola,
/// con tasto "Guarda ora" e scorrimento tra gli altri eventi.
class HeroCarousel extends StatefulWidget {
  final List<HeroSlide> slides;
  final bool active;
  final bool netflix; // variante film e serie
  const HeroCarousel({super.key, required this.slides, required this.active, this.netflix = false});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  int _i = 0;
  String? _url;
  bool _muted = true;

  @override
  void initState() {
    super.initState();
    _player.setVolume(0);
    _sync();
  }

  @override
  void didUpdateWidget(HeroCarousel old) {
    super.didUpdateWidget(old);
    if (_i >= widget.slides.length) _i = 0;
    _sync();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  final Map<String, String?> _cache = {};
  final Set<String> _loading = {};

  void _setUrl(String? want) {
    if (want == _url) return;
    _url = want;
    if (want == null) {
      _player.stop();
    } else {
      _player.setVolume(_muted ? 0 : 100);
      _player.open(Media(want));
    }
  }

  void _sync() {
    if (widget.slides.isEmpty || !widget.active) {
      _setUrl(null);
      return;
    }
    final s = widget.slides[_i];
    if (s.preview != null) {
      _setUrl(s.preview!.url);
    } else if (s.previewLoader == null) {
      _setUrl(null);
    } else if (_cache.containsKey(s.id)) {
      _setUrl(_cache[s.id]);
    } else {
      _setUrl(null);
      _resolve(s);
    }
  }

  Future<void> _resolve(HeroSlide s) async {
    if (!_loading.add(s.id)) return;
    String? u;
    try {
      u = await s.previewLoader!();
    } catch (_) {}
    _loading.remove(s.id);
    _cache[s.id] = u;
    if (mounted) setState(_sync);
  }

  void _toggleSound() {
    setState(() => _muted = !_muted);
    _player.setVolume(_muted ? 0 : 100);
  }

  void _go(int d) {
    final n = widget.slides.length;
    if (n < 2) return;
    setState(() => _i = (_i + d + n) % n);
    _sync();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.slides.length;
    final s = widget.slides[_i.clamp(0, n - 1)];
    final text = Theme.of(context).textTheme;
    final nf = widget.netflix;
    final screenH = MediaQuery.of(context).size.height;
    final height = (screenH * (nf ? 0.62 : 0.5)).clamp(420.0, 640.0).toDouble();
    final round = IconButton.styleFrom(backgroundColor: const Color(0x88000000));
    final base = nf ? Colors.black : AppColors.background;

    final badge = nf
        ? Text(s.badge.toUpperCase(),
            style: const TextStyle(
                color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 3))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: s.live ? AppColors.accent : AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(s.badge,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ]);

    final buttons = Row(children: [
      FilledButton.icon(
        onPressed: s.onWatch,
        icon: const Icon(Icons.play_arrow_rounded),
        label: Text(nf ? 'Riproduci' : 'Guarda ora'),
        style: FilledButton.styleFrom(
          backgroundColor: nf ? Colors.white : AppColors.accent,
          foregroundColor: nf ? Colors.black : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      if (s.onChange != null) ...[
        const SizedBox(width: 12),
        if (nf)
          FilledButton.icon(
            onPressed: s.onChange,
            icon: const Icon(Icons.info_outline_rounded),
            label: const Text('Altre info'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0x99555555),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          )
        else
          OutlinedButton(
            onPressed: s.onChange,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: Color(0x44FFFFFF)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
            child: const Text('Cambia canale'),
          ),
      ],
    ]);

    return SizedBox(
      height: height,
      child: GestureDetector(
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (v < -250) {
            _go(1);
          } else if (v > 250) {
            _go(-1);
          }
        },
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [tone(s.title, lightness: 0.34), base],
              ),
            ),
          ),
          if (s.image != null)
            Image.network(s.image!,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          if (_url != null)
            Video(
              controller: _video,
              controls: NoVideoControls,
              fit: BoxFit.cover,
              fill: Colors.transparent,
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [const Color(0x66000000), const Color(0x00000000), base],
                stops: const [0, 0.35, 1],
              ),
            ),
          ),
          if (nf)
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xAA000000), Color(0x00000000)],
                  stops: [0, 0.6],
                ),
              ),
            ),
          Positioned(
            left: 24,
            right: 24,
            bottom: nf ? 56 : 32,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(_i),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  badge,
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: nf ? 620 : 900),
                    child: Text(s.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.headlineMedium?.copyWith(fontSize: nf ? 46 : 36)),
                  ),
                  const SizedBox(height: 8),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_url != null) ...[
                      Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: Text(s.subtitle, style: text.bodySmall)),
                  ]),
                  const SizedBox(height: 20),
                  buttons,
                ],
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: nf ? 56 : 32,
            child: Row(children: [
              if (_url != null)
                IconButton(
                  tooltip: _muted ? 'Attiva audio' : 'Disattiva audio',
                  onPressed: _toggleSound,
                  icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded),
                  style: round,
                ),
              if (n > 1) ...[
                const SizedBox(width: 10),
                IconButton(
                    onPressed: () => _go(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    style: round),
                const SizedBox(width: 6),
                for (var k = 0; k < n; k++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: k == _i ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: k == _i ? AppColors.accent : const Color(0x66FFFFFF),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                const SizedBox(width: 6),
                IconButton(
                    onPressed: () => _go(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    style: round),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
