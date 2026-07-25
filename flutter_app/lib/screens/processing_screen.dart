import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/job_status.dart';
import '../services/api_service.dart';
import '../widgets/stage_item.dart';
import 'result_screen.dart';

class ProcessingScreen extends StatefulWidget {
  final String jobId;
  final String fileName;
  final double fileSize;
  final String originalFilePath;

  const ProcessingScreen({
    super.key,
    required this.jobId,
    required this.fileName,
    required this.fileSize,
    required this.originalFilePath,
  });

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  StreamSubscription<JobStatus>? _sub;
  JobStatus? _status;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _sub = ApiService.instance
        .pollStatus(widget.jobId)
        .listen((status) async {
      if (!mounted) return;
      setState(() => _status = status);

      if (status.isCompleted && !_navigated) {
        _navigated = true;
        _sub?.cancel();

        // Download the enhanced file
        try {
          final localPath = await ApiService.instance.downloadResult(
            widget.jobId,
            status.originalFormat,
          );
          if (!mounted) return;
          await Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => ResultScreen(
                enhancedFilePath: localPath,
                originalFilePath: widget.originalFilePath,
                fileName: widget.fileName,
              ),
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('خطأ في التحميل: $e'),
                backgroundColor: kError,
              ),
            );
          }
        }
      }

      if (status.isFailed && !_navigated) {
        _navigated = true;
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // Determine stage state based on overall progress
  StageState _stageState(int stageIndex) {
    if (_status == null) return StageState.pending;
    final p = _status!.progress;

    // Map progress 0-100 across 8 stages
    final stageDone = (p / 100 * kStageLabels.length).floor();

    if (stageIndex < stageDone) return StageState.done;
    if (stageIndex == stageDone && p < 100) return StageState.active;
    return StageState.pending;
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_status?.progress ?? 0) / 100.0;
    final isFailed = _status?.isFailed ?? false;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ── App bar ────────────────────────────────────────── //
                Row(children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: kText, size: 18),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ShaderMask(
                    shaderCallback: (r) => kAccentGradient.createShader(r),
                    child: const Text('معالجة الصوت',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 28),

                // ── File info card ─────────────────────────────────── //
                _buildFileCard(),
                const SizedBox(height: 24),

                // ── Progress ───────────────────────────────────────── //
                if (!isFailed) ...[
                  _buildProgressSection(progress),
                  const SizedBox(height: 24),

                  // ── Stages ──────────────────────────────────────── //
                  _buildStagesCard(),
                ] else
                  _buildErrorCard(),

                const SizedBox(height: 32),
                _buildHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: kCardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: kAccentGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.audio_file_rounded,
              color: Colors.white, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.fileName,
                  style: const TextStyle(
                      color: kText,
                      fontWeight: FontWeight.w600,
                      fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text('${widget.fileSize.toStringAsFixed(1)} MB',
                  style: const TextStyle(color: kTextSub, fontSize: 12)),
            ],
          ),
        ),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kAccent.withOpacity(0.3)),
          ),
          child: const Text('معالجة',
              style: TextStyle(
                  color: kAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ),
      ]),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _buildProgressSection(double progress) {
    final pct = (progress * 100).toInt();
    final stageLabel = _status?.stage ?? 'جاري التحميل...';

    return Column(
      children: [
        // Percentage ring
        Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CircularProgressIndicator(
              value: progress > 0 ? progress : null,
              strokeWidth: 8,
              backgroundColor: kBorder,
              valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            ShaderMask(
              shaderCallback: (r) => kAccentGradient.createShader(r),
              child: Text('$pct%',
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white)),
            ),
          ]),
        ])
            .animate(onPlay: (c) => c.repeat())
            .shimmer(
                duration: 2000.ms,
                color: kAccent.withOpacity(0.1)),
        const SizedBox(height: 16),
        Text(stageLabel,
            style: const TextStyle(color: kAccent, fontSize: 14,
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildStagesCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: kCardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('مراحل المعالجة',
              style: TextStyle(
                  color: kText,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          const SizedBox(height: 16),
          ...kStageLabels.asMap().entries.map(
                (e) => StageItem(
                  index: e.key,
                  label: e.value,
                  state: _stageState(e.key),
                ),
              ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildErrorCard() {
    return Container(
      decoration: BoxDecoration(
        color: kError.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kError.withOpacity(0.4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        const Icon(Icons.error_outline_rounded,
            color: kError, size: 48),
        const SizedBox(height: 12),
        const Text('فشلت المعالجة',
            style: TextStyle(
                color: kError,
                fontWeight: FontWeight.w700,
                fontSize: 18)),
        const SizedBox(height: 8),
        Text(_status?.error ?? 'خطأ غير معروف',
            style: const TextStyle(color: kTextSub, fontSize: 13),
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('حاول مرة أخرى'),
          style: ElevatedButton.styleFrom(
            backgroundColor: kError,
            foregroundColor: Colors.white,
          ),
        ),
      ]),
    ).animate().shakeX(duration: 400.ms);
  }

  Widget _buildHint() {
    return const Text(
      '⏱ المعالجة قد تستغرق من دقيقتين إلى عشر دقائق\nحسب حجم الملف وسرعة السيرفر',
      style: TextStyle(color: kTextSub, fontSize: 12, height: 1.6),
      textAlign: TextAlign.center,
    );
  }
}
