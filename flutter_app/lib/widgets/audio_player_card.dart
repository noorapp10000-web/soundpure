import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../core/theme.dart';

class AudioPlayerCard extends StatefulWidget {
  final String title;
  final String filePath;
  final LinearGradient gradient;

  const AudioPlayerCard({
    super.key,
    required this.title,
    required this.filePath,
    required this.gradient,
  });

  @override
  State<AudioPlayerCard> createState() => _AudioPlayerCardState();
}

class _AudioPlayerCardState extends State<AudioPlayerCard> {
  final AudioPlayer _player = AudioPlayer();
  bool _ready = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await _player.setFilePath(widget.filePath);
      _duration = _player.duration ?? Duration.zero;
      _posSub = _player.positionStream.listen((p) {
        if (mounted) setState(() => _position = p);
      });
      _stateSub = _player.playerStateStream.listen((s) {
        if (mounted) setState(() => _playing = s.playing);
        if (s.processingState == ProcessingState.completed) {
          _player.seek(Duration.zero);
          _player.pause();
        }
      });
      if (mounted) setState(() => _ready = true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: kCardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(children: [
            ShaderMask(
              shaderCallback: (r) => widget.gradient.createShader(r),
              child: const Icon(Icons.graphic_eq_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Text(widget.title,
                style: const TextStyle(
                    color: kText, fontWeight: FontWeight.w600, fontSize: 14)),
          ]),
          const SizedBox(height: 14),

          if (!_ready)
            const Center(
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kAccent),
              ),
            )
          else ...[
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: kBorder,
                valueColor: AlwaysStoppedAnimation<Color>(
                    widget.gradient.colors.first),
              ),
            ),
            const SizedBox(height: 8),

            // Time + controls
            Row(children: [
              Text(_fmt(_position),
                  style: const TextStyle(color: kTextSub, fontSize: 12)),
              const Spacer(),

              // Seek back
              GestureDetector(
                onTap: () => _player.seek(
                    Duration(seconds: _position.inSeconds - 10)),
                child: const Icon(Icons.replay_10_rounded,
                    color: kTextSub, size: 22),
              ),
              const SizedBox(width: 12),

              // Play / pause
              GestureDetector(
                onTap: () => _playing ? _player.pause() : _player.play(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: widget.gradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.gradient.colors.first.withOpacity(0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Seek forward
              GestureDetector(
                onTap: () => _player.seek(
                    Duration(seconds: _position.inSeconds + 10)),
                child: const Icon(Icons.forward_10_rounded,
                    color: kTextSub, size: 22),
              ),
              const Spacer(),
              Text(_fmt(_duration),
                  style: const TextStyle(color: kTextSub, fontSize: 12)),
            ]),
          ],
        ],
      ),
    );
  }
}
