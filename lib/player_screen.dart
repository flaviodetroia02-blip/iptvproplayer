import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'app_state.dart';
import 'epg.dart';
import 'models.dart';
import 'sports.dart';
import 'theme.dart';

const fitLabels = ['Adatta', 'Riempi (taglia i bordi)', 'Allunga', '16:9', '4:3', '21:9'];

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class PlayerScreen extends StatefulWidget {
  final String title, url;
  final AppState? state;
  final Item? item;
  const PlayerScreen({super.key, required this.title, required this.url, this.state, this.item});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  late Item? _cur = widget.item;
  late String _url = widget.url;
  late String _title = widget.title;
  Item? _original; // canale di partenza, se è stata abbassata la qualità
  bool _hlsMin = false, _failed = false, _prompting = false, _everPlayed = false;
  int _fit = 0, _retries = 0;
  Epg? _epg;
  Timer? _epgTimer, _watch;
  final List<StreamSubscription> _subs = [];
  final List<DateTime> _stalls = [];
  DateTime _startedAt = DateTime.now();
  DateTime? _bufSince, _quietUntil;

  bool get _isLive => _cur?.kind == Kind.live;

  @override
  void initState() {
    super.initState();
    final st = widget.state;
    final it = widget.item;
    _fit = st?.fitMode ?? 0;
    Duration? start;
    if (st != null && it != null) {
      st.markWatched(it);
      if (it.kind != Kind.live) {
        final pos = st.positionOf(it.url);
        if (pos > 0) start = Duration(seconds: pos);
      }
    }
    _tune().then((_) {
      if (mounted) _open(start: start);
    });
    _subs.add(player.stream.buffering.listen(_onBuffering));
    _subs.add(player.stream.position.listen((p) {
      if (p > const Duration(seconds: 1)) {
        _everPlayed = true;
        _retries = 0;
        if (_failed && mounted) setState(() => _failed = false);
      }
    }));
    _subs.add(player.stream.error.listen(_onError));
    if (_isLive) {
      _loadEpg();
      _epgTimer = Timer.periodic(const Duration(minutes: 2), (_) => _loadEpg());
      _precheck();
    }
    _watch = Timer.periodic(const Duration(seconds: 2), (_) => _check());
  }

  // ---- motore di riproduzione ----
  Future<void> _prop(String k, String v) async {
    try {
      await (player.platform as dynamic).setProperty(k, v);
    } catch (_) {}
  }

  /// Buffer ampio, riconnessione automatica e timeout di rete: meno blocchi.
  Future<void> _tune() async {
    final st = widget.state;
    await _prop('cache', 'yes');
    await _prop('demuxer-max-bytes', '${(st?.bufferMb ?? 32) * 1024 * 1024}');
    await _prop('demuxer-readahead-secs', '${st?.readaheadSecs ?? 20}');
    await _prop('network-timeout', '20');
    await _prop('stream-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=5');
  }

  Future<void> _open({Duration? start}) async {
    _startedAt = DateTime.now();
    _everPlayed = false;
    _bufSince = null;
    _stalls.clear();
    await _prop('hls-bitrate', _hlsMin ? 'min' : 'max');
    await player.open(Media(_url, start: start));
  }

  void _onBuffering(bool b) {
    final now = DateTime.now();
    if (b) {
      _bufSince = now;
      if (_everPlayed) _stalls.add(now);
    } else {
      _bufSince = null;
    }
  }

  void _onError(String e) {
    if (e.isEmpty || !mounted) return;
    if (_retries < 3) {
      _retries++;
      Future.delayed(Duration(seconds: 2 * _retries), () {
        if (mounted) _open();
      });
    } else if (!_failed) {
      setState(() => _failed = true);
    }
  }

  // ---- connessione lenta ----
  void _check() {
    final st = widget.state;
    if (!mounted || _prompting || !_isLive || st == null || !st.slowWarn) return;
    final now = DateTime.now();
    if (_quietUntil != null && now.isBefore(_quietUntil!)) return;
    _stalls.removeWhere((t) => now.difference(t) > const Duration(seconds: 60));
    String? why;
    if (!_everPlayed && now.difference(_startedAt) > const Duration(seconds: 12)) {
      why = 'Il canale sta impiegando troppo ad avviarsi.';
    } else if (_bufSince != null && now.difference(_bufSince!) > const Duration(seconds: 8)) {
      why = 'Il video è fermo da diversi secondi.';
    } else if (_stalls.length >= 3) {
      why = 'Il video si blocca spesso.';
    }
    if (why != null) _offerLower(why);
  }

  /// All'apertura di un canale ad alta risoluzione controlla se la connessione basta.
  Future<void> _precheck() async {
    final st = widget.state;
    final cur = _cur;
    if (st == null || cur == null || !st.slowWarn) return;
    final score = resolutionScore(cur.name);
    if (score < 2) return;
    final v = await st.measureSpeed();
    if (v == null || !mounted || _prompting) return;
    final need = score >= 4 ? 20.0 : (score >= 3 ? 8.0 : 4.0);
    if (v < need) {
      _offerLower(
          'La tua connessione (circa ${v.toStringAsFixed(1)} Mbps) potrebbe non bastare per un canale ${resolutionLabel(cur.name)}.');
    }
  }

  Future<void> _offerLower(String why) async {
    final st = widget.state;
    final cur = _cur;
    if (st == null || cur == null || _prompting) return;
    final alt = st.lowerVariant(cur);
    final canHls = !_hlsMin && _url.toLowerCase().contains('.m3u8');
    if (alt == null && !canHls) {
      _quietUntil = DateTime.now().add(const Duration(minutes: 4));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Connessione lenta: non esiste una versione a qualità inferiore di questo canale.'),
      ));
      return;
    }
    _prompting = true;
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Connessione lenta'),
        content: Text(alt != null
            ? '$why\n\nVuoi passare a "${alt.name}", con risoluzione più bassa?'
            : '$why\n\nVuoi provare la qualità più bassa disponibile di questo canale?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Resta su questo canale')),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Passa a qualità inferiore'),
          ),
        ],
      ),
    );
    _prompting = false;
    if (!mounted) return;
    if (ok == true) {
      if (alt != null) {
        await _switchTo(alt, lowered: true);
      } else {
        await _lowerHls();
      }
    } else {
      _quietUntil = DateTime.now().add(const Duration(minutes: 5));
    }
  }

  Future<void> _switchTo(Item it, {required bool lowered}) async {
    setState(() {
      if (lowered) {
        _original ??= _cur;
      } else {
        _original = null;
      }
      _cur = it;
      _url = it.url;
      _title = it.name;
      _hlsMin = false;
      _failed = false;
      _retries = 0;
      _epg = null;
    });
    await _open();
    _loadEpg();
  }

  Future<void> _lowerHls() async {
    setState(() => _hlsMin = true);
    await _open();
  }

  Future<void> _restore() async {
    if (_original != null) {
      await _switchTo(_original!, lowered: false);
    } else if (_hlsMin) {
      setState(() => _hlsMin = false);
      await _open();
    }
  }

  // ---- guida programmi ----
  Future<void> _loadEpg() async {
    if (!_isLive) return;
    final e = await fetchEpg(_url);
    if (mounted) setState(() => _epg = e);
  }

  @override
  void dispose() {
    _epgTimer?.cancel();
    _watch?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    final st = widget.state;
    final it = widget.item;
    if (st != null && it != null && it.kind != Kind.live) {
      st.savePosition(it.url, player.state.position.inSeconds, player.state.duration.inSeconds);
    }
    player.dispose();
    super.dispose();
  }

  // ---- interfaccia ----
  Widget _video() {
    Widget ratio(double r) =>
        Center(child: AspectRatio(aspectRatio: r, child: Video(controller: controller, fit: BoxFit.fill)));
    switch (_fit) {
      case 1:
        return Video(controller: controller, fit: BoxFit.cover);
      case 2:
        return Video(controller: controller, fit: BoxFit.fill);
      case 3:
        return ratio(16 / 9);
      case 4:
        return ratio(4 / 3);
      case 5:
        return ratio(21 / 9);
      default:
        return Video(controller: controller, fit: BoxFit.contain);
    }
  }

  Widget _epgInfo(Epg e) {
    const small = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e.now != null) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('IN ONDA',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1, color: AppColors.accent)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(e.now!.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 10),
            Text('${_hm(e.now!.start)} – ${_hm(e.now!.end)}', style: small),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            width: 260,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: e.now!.progress,
                minHeight: 3,
                backgroundColor: const Color(0x33FFFFFF),
                color: AppColors.accent,
              ),
            ),
          ),
        ],
        if (e.next != null) ...[
          const SizedBox(height: 10),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('DOPO',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.textSecondary)),
            const SizedBox(width: 10),
            Flexible(
              child: Text(e.next!.title,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
            ),
            const SizedBox(width: 10),
            Text(_hm(e.next!.start), style: small),
          ]),
        ],
      ]),
    );
  }

  Widget _qualityMenu() {
    return PopupMenuButton<String>(
      tooltip: 'Qualità',
      icon: const Icon(Icons.speed_rounded),
      onSelected: (v) {
        final st = widget.state;
        if (v == 'alt' && st != null && _cur != null) {
          final alt = st.lowerVariant(_cur!);
          if (alt != null) _switchTo(alt, lowered: true);
        } else if (v == 'min') {
          _lowerHls();
        } else if (v == 'max') {
          _restore();
        }
      },
      itemBuilder: (_) {
        final st = widget.state;
        final alt = (st != null && _cur != null) ? st.lowerVariant(_cur!) : null;
        final items = <PopupMenuEntry<String>>[];
        if (_original != null || _hlsMin) {
          items.add(const PopupMenuItem(value: 'max', child: Text('Torna alla qualità massima')));
        }
        if (alt != null) {
          items.add(PopupMenuItem(value: 'alt', child: Text('Passa a "${alt.name}"')));
        }
        if (!_hlsMin && _url.toLowerCase().contains('.m3u8')) {
          items.add(const PopupMenuItem(value: 'min', child: Text('Qualità minima (stesso canale)')));
        }
        if (items.isEmpty) {
          items.add(const PopupMenuItem(enabled: false, child: Text('Nessuna alternativa disponibile')));
        }
        return items;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lowered = _original != null || _hlsMin;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: _video()),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
            child: SafeArea(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const BackButton(color: Colors.white),
                  Expanded(
                    child: Text(_title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Formato video',
                    icon: const Icon(Icons.aspect_ratio_rounded),
                    initialValue: _fit,
                    onSelected: (i) {
                      setState(() => _fit = i);
                      widget.state?.setFitMode(i);
                    },
                    itemBuilder: (_) => [
                      for (var i = 0; i < fitLabels.length; i++)
                        PopupMenuItem(value: i, child: Text(fitLabels[i])),
                    ],
                  ),
                  if (_isLive) _qualityMenu(),
                  const SizedBox(width: 6),
                ]),
                if (lowered)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(56, 0, 16, 8),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.speed_rounded, size: 16, color: AppColors.accent),
                      const SizedBox(width: 6),
                      const Text('Qualità ridotta', style: TextStyle(fontSize: 13)),
                      TextButton(onPressed: _restore, child: const Text('Torna alla massima')),
                    ]),
                  ),
                if (_epg != null) _epgInfo(_epg!),
              ]),
            ),
          ),
        ),
        if (_failed)
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Il canale non risponde.', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () {
                  setState(() => _failed = false);
                  _retries = 0;
                  _open();
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                child: const Text('Riprova'),
              ),
            ]),
          ),
      ]),
    );
  }
}
