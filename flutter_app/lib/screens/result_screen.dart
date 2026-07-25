import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../core/theme.dart';
import '../widgets/audio_player_card.dart';

class ResultScreen extends StatefulWidget {
  final String enhancedFilePath;
  final String originalFilePath;
  final String fileName;

  const ResultScreen({
    super.key,
    required this.enhancedFilePath,
    required this.originalFilePath,
    required this.fileName,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      await Share.shareXFiles(
        [XFile(widget.enhancedFilePath)],
        subject: 'صوت محسّن بـ SoundPure',
        text: 'تم تنقية هذا الصوت بواسطة SoundPure AI',
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _openFile() async {
    await OpenFile.open(widget.enhancedFilePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 24, vertical: 24),
            child: Column(
              children: [
                // ── App bar ────────────────────────────────────────── //
                Row(children: [
                  GestureDetector(
                    onTap: () =>
                        Navigator.popUntil(context, (r) => r.isFirst),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(Icons.home_rounded,
                          color: kText, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ShaderMask(
                    shaderCallback: (r) =>
                        kSuccessGradient.createShader(r),
                    child: const Text('تم بنجاح!',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ]),
                const SizedBox(height: 32),

                // ── Success badge ─────────────────────────────────── //
                _buildSuccessBadge(),
                const SizedBox(height: 36),

                // ── Before player ─────────────────────────────────── //
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('قبل المعالجة',
                      style: TextStyle(
                          color: kTextSub,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(height: 8),
                AudioPlayerCard(
                  title: p.basename(widget.originalFilePath),
                  filePath: widget.originalFilePath,
                  gradient: const LinearGradient(
                      colors: [Color(0xFF546E7A), Color(0xFF37474F)]),
                ),
                const SizedBox(height: 20),

                // ── After player ──────────────────────────────────── //
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('بعد المعالجة ✨',
                      style: TextStyle(
                          color: kSuccess,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
                const SizedBox(height: 8),
                AudioPlayerCard(
                  title: 'soundpure_enhanced',
                  filePath: widget.enhancedFilePath,
                  gradient: kSuccessGradient,
                ),
                const SizedBox(height: 32),

                // ── Actions ───────────────────────────────────────── //
                _buildActions(),
                const SizedBox(height: 20),

                // ── Process another ───────────────────────────────── //
                TextButton.icon(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  icon: const Icon(Icons.add_circle_outline_rounded,
                      color: kTextSub),
                  label: const Text('معالجة ملف آخر',
                      style: TextStyle(color: kTextSub)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Success badge ───────────────────────────────────────────────────── //
  Widget _buildSuccessBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).scale(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kSuccess.withOpacity(0.3)),
        color: kSuccess.withOpacity(0.08),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: kSuccessGradient,
              boxShadow: [
                BoxShadow(
                  color: kSuccess.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 6,
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded,
                color: Colors.white, size: 44),
          )
              .animate()
              .scale(
                  begin: const Offset(0, 0),
                  end: const Offset(1, 1),
                  duration: 500.ms,
                  curve: Curves.elasticOut),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (r) => kSuccessGradient.createShader(r),
            child: const Text(
              'تم تنقية الصوت بنجاح!',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 6),
          const Text(
            'تمت المعالجة بـ 5 نماذج AI متخصصة',
            style: TextStyle(color: kTextSub, fontSize: 13),
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  // ── Actions ─────────────────────────────────────────────────────────── //
  Widget _buildActions() {
    return Column(
      children: [
        // Open / Save button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: kSuccessGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: kSuccess.withOpacity(0.35),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: _openFile,
              icon: const Icon(Icons.folder_open_rounded,
                  color: Colors.white),
              label: const Text('فتح / حفظ الملف المحسّن',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.2),
        const SizedBox(height: 12),

        // Share button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _sharing ? null : _share,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: kAccent),
                  )
                : const Icon(Icons.share_rounded, color: kAccent),
            label: Text(
              _sharing ? 'جاري المشاركة...' : 'مشاركة',
              style: const TextStyle(
                  color: kAccent,
                  fontWeight: FontWeight.w600,
                  fontSize: 15),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kAccent, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2),
      ],
    );
  }
}

// Extension to scale gradient (helper)
extension _LinearGradientScale on LinearGradient {
  LinearGradient scale(double factor) => LinearGradient(
        colors: colors.map((c) => c.withOpacity(factor)).toList(),
      );
}
