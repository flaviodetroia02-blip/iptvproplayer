import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'app_state.dart';
import 'epg.dart';
import 'models.dart';
import 'theme.dart';

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
  Epg? _epg;
  Timer? _timer;

  bool get _isLive => widget.item?.kind == Kind.live;

  @override
  void initState() {
    super.initState();
    final st = widget.state;
    final it = widget.item;
    Duration? start;
    if (st != null && it != null) {
      st.markWatched(it);
      if (it.kind != Kind.live) {
        final pos = st.positionOf(it.url);
        if (pos > 0) start = Duration(seconds: pos);
      }
    }
    player.open(Media(widget.url, start: start));
    if (_isLive) {
      _loadEpg();
      _timer = Timer.periodic(const Duration(minutes: 2), (_) => _loadEpg());
    }
  }

  Future<void> _loadEpg() async {
    final e = await fetchEpg(widget.url);
    if (mounted) setState(() => _epg = e);
  }

  @override
  void dispose() {
    _timer?.cancel();
    final st = widget.state;
    final it = widget.item;
    if (st != null && it != null && it.kind != Kind.live) {
      st.savePosition(it.url, player.state.position.inSeconds, player.state.duration.inSeconds);
    }
    player.dispose();
    super.dispose();
  }

  Widget _epgInfo(Epg e) {
    const small = TextStyle(fontSize: 13, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 0, 16, 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (e.now != null) ...[
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Text('IN ONDA',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                    color: AppColors.accent)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        Positioned.fill(child: Video(controller: controller, fit: BoxFit.contain)),
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
                    child: Text(widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ]),
                if (_epg != null) _epgInfo(_epg!),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
