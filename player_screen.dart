import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'app_state.dart';
import 'models.dart';

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
  // Rendering software: evita il video in miniatura visto su alcuni PC Windows.
  late final VideoController controller = VideoController(
    player,
    configuration: const VideoControllerConfiguration(enableHardwareAcceleration: false),
  );

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
  }

  @override
  void dispose() {
    final st = widget.state;
    final it = widget.item;
    if (st != null && it != null && it.kind != Kind.live) {
      st.savePosition(it.url, player.state.position.inSeconds, player.state.duration.inSeconds);
    }
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Video(controller: controller, fit: BoxFit.contain)),
        SafeArea(
          child: Row(children: [
            const BackButton(color: Colors.white),
            Expanded(
              child: Text(widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}
