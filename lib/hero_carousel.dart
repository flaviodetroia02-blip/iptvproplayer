import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'models.dart';
import 'theme.dart';
import 'widgets.dart';

class HeroSlide {
  final String badge, title, subtitle;
  final bool live;
  final Item? preview; // canale mostrato in anteprima, senza audio
  final VoidCallback onWatch;
  final VoidCallback? onChange; // "Cambia canale"
  const HeroSlide({
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.live,
    required this.preview,
    required this.onWatch,
    this.onChange,
  });
}

/// Riquadro principale della home: anteprima video muta che parte da sola,
/// con tasto "Guarda ora" e scorrimento tra gli altri eventi.
class HeroCarousel extends StatefulWidget {
  final List<HeroSlide> slides;
  final bool active;
  const HeroCarousel({super.key, required this.slides, required this.active});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  int _i = 0;
  String? _url;

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

  void _sync() {
    final want = (widget.active && widget.slides.isNotEmpty) ? widget.slides[_i].preview?.url : null;
    if (want == _url) return;
    _url = want;
    if (want == null) {
      _player.stop();
    } else {
      _player.setVolume(0);
      _player.open(Media(want));
    }
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
    final arrow = IconButton.styleFrom(backgroundColor: const Color(0x88000000));

    return SizedBox(
      height: 440,
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
                colors: [tone(s.title, lightness: 0.34), AppColors.background],
              ),
            ),
          ),
          if (_url != null)
            Video(
              controller: _video,
              controls: NoVideoControls,
              fit: BoxFit.cover,
              fill: Colors.transparent,
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66111113), Color(0x00111113), AppColors.background],
                stops: [0, 0.3, 1],
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 28,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Column(
                key: ValueKey(_i),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 12),
                  Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.headlineMedium),
                  const SizedBox(height: 6),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    if (_url != null) ...[
                      const Icon(Icons.volume_off_rounded, size: 15, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                    ],
                    Flexible(child: Text(s.subtitle, style: text.bodySmall)),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    FilledButton.icon(
                      onPressed: s.onWatch,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Guarda ora'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                      ),
                    ),
                    if (s.onChange != null) ...[
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: s.onChange,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(color: AppColors.surfaceHigh),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                        ),
                        child: const Text('Cambia canale'),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
          if (n > 1)
            Positioned(
              right: 24,
              top: 24,
              child: Row(children: [
                IconButton(
                    onPressed: () => _go(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                    style: arrow),
                const SizedBox(width: 8),
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
                const SizedBox(width: 8),
                IconButton(
                    onPressed: () => _go(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                    style: arrow),
              ]),
            ),
        ]),
      ),
    );
  }
}
