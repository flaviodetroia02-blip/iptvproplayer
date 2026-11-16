import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'device.dart';
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
  final Widget Function(BuildContext)? poster; // locandina mostrata 5 secondi prima del video
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
    this.poster,
  });
}

/// Riquadro principale della home: anteprima video muta che parte da sola,
/// con tasto "Guarda ora" e scorrimento tra gli altri eventi.
class HeroCarousel extends StatefulWidget {
  final List<HeroSlide> slides;
  final bool active;
  final bool netflix; // variante film e serie
  final bool previews; // anteprime video attive
  const HeroCarousel({
    super.key,
    required this.slides,
    required this.active,
    this.netflix = false,
    this.previews = true,
  });

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  int _i = 0;
  String? _url;
  bool _muted = true;
  String? _posterFor;
  bool _posterOn = false;
  Timer? _posterTimer;

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
    _posterTimer?.cancel();
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

  void _cancelPoster() {
    _posterTimer?.cancel();
    _posterFor = null;
    _posterOn = false;
  }

  void _sync() {
    if (widget.slides.isEmpty || !widget.active) {
      _cancelPoster();
      _setUrl(null);
      return;
    }
    final s = widget.slides[_i];
    if (!widget.previews) {
      // anteprime video spente: resta solo la locandina
      _posterTimer?.cancel();
      _posterFor = null;
      _posterOn = s.poster != null;
      _setUrl(null);
      return;
    }
    if (s.poster != null) {
      if (_posterFor != s.id) {
        // nuovo evento: prima la locandina, dopo 5 secondi parte l'anteprima
        _posterTimer?.cancel();
        _posterFor = s.id;
        _posterOn = true;
        _setUrl(null);
        if (s.preview == null && s.previewLoader != null && !_cache.containsKey(s.id)) _resolve(s);
        _posterTimer = Timer(const Duration(seconds: 5), () {
          if (!mounted) return;
          setState(() {
            _posterOn = false;
            _sync();
          });
        });
        return;
      }
      if (_posterOn) {
        _setUrl(null);
        return;
      }
    } else {
      _cancelPoster();
    }
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

  /// Versione per telefono: scheda arrotondata, titolo grande, un solo tasto principale
  /// a tutta larghezza e indicatori a segmenti in basso. Si scorre col dito.
  Widget _buildNarrow(BuildContext context, HeroSlide s, bool nf) {
    final n = widget.slides.length;
    final text = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    final height = (mq.size.height * 0.56).clamp(400.0, 540.0).toDouble();
    final base = nf ? Colors.black : AppColors.background;

    final badge = nf
        ? Text(s.badge.toUpperCase(),
            style: const TextStyle(
                color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 3))
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: s.live ? AppColors.accent : const Color(0x33FFFFFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(s.badge,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
          );

    final primary = FilledButton.icon(
      onPressed: s.onWatch,
      icon: const Icon(Icons.play_arrow_rounded, size: 26),
      label: Text(nf ? 'Riproduci' : 'Guarda ora'),
      style: FilledButton.styleFrom(
        backgroundColor: nf ? Colors.white : AppColors.accent,
        foregroundColor: nf ? Colors.black : Colors.white,
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, mq.padding.top + 10, 12, 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: SizedBox(
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
              if (s.poster != null)
                IgnorePointer(
                  child: AnimatedOpacity(
                    opacity: _posterOn ? 1 : 0,
                    duration: const Duration(milliseconds: 700),
                    child: s.poster!(context),
                  ),
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [const Color(0x55000000), const Color(0x00000000), base.withAlpha(0xF2)],
                    stops: const [0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 12,
                child: _url == null
                    ? const SizedBox.shrink()
                    : IconButton(
                        tooltip: _muted ? 'Attiva audio' : 'Disattiva audio',
                        onPressed: _toggleSound,
                        icon: Icon(_muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            size: 22),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0x66000000),
                          foregroundColor: Colors.white,
                        ),
                      ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 30,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    key: ValueKey(_i),
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      badge,
                      const SizedBox(height: 10),
                      Text(s.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.headlineMedium?.copyWith(fontSize: 30, height: 1.05)),
                      const SizedBox(height: 6),
                      Text(s.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: const Color(0xCCFFFFFF))),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: primary),
                        if (s.onChange != null) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: IconButton(
                              tooltip: nf ? 'Altre info' : 'Cambia canale',
                              onPressed: s.onChange,
                              icon: Icon(nf ? Icons.info_outline_rounded : Icons.swap_horiz_rounded),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x33FFFFFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              if (n > 1)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 14,
                  child: Row(children: [
                    for (var k = 0; k < n; k++)
                      Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: k == _i ? Colors.white : const Color(0x44FFFFFF),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.slides.length;
    final s = widget.slides[_i.clamp(0, n - 1)];
    final text = Theme.of(context).textTheme;
    final nf = widget.netflix;
    final narrow = MediaQuery.of(context).size.width < 700;
    final sc = uiScale(context);
    final pad = sidePad(context);
    if (narrow) return _buildNarrow(context, s, nf);
    final screenH = MediaQuery.of(context).size.height;
    final height = (screenH * (nf ? 0.62 : 0.5)).clamp(420.0, 720.0).toDouble();
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

    final buttons = Wrap(spacing: 12, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
      FilledButton.icon(
        autofocus: Device.isTv,
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

    final controls = Row(mainAxisSize: MainAxisSize.min, children: [
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
          if (s.image != null && s.poster == null)
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
          if (s.poster != null)
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _posterOn ? 1 : 0,
                duration: const Duration(milliseconds: 700),
                child: s.poster!(context),
              ),
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
            left: pad,
            right: pad,
            bottom: nf ? 56 : 32,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.bottomLeft,
                children: [...previous, if (current != null) current],
              ),
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
                        style: text.headlineMedium?.copyWith(fontSize: narrow ? (nf ? 34 : 28) : (nf ? 46 : 36) * sc)),
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
                  if (narrow) ...[const SizedBox(height: 14), controls],
                ],
              ),
            ),
          ),
          if (!narrow)
            Positioned(right: pad, bottom: nf ? 56 : 32, child: controls),
        ]),
      ),
    );
  }
}
