import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../state/upload_state.dart';
import 'processing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  bool _uploading = false;
  double _uploadProgress = 0;
  String? _error;

  Future<void> _pickAndUpload() async {
    setState(() {
      _error = null;
      _uploadProgress = 0;
    });

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'mp3', 'wav', 'm4a', 'aac',
        'ogg', 'flac', 'wma', 'opus', 'mp4',
      ],
      withData: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final fileSize = await file.length();
    final sizeMb = fileSize / (1024 * 1024);

    if (sizeMb > kMaxFileMb) {
      setState(() => _error = 'الملف كبير جداً (الحد الأقصى $kMaxFileMb MB)');
      return;
    }

    setState(() => _uploading = true);

    try {
      final jobId = await ApiService.instance.uploadAudio(
        file,
        onProgress: (pct) => setState(() => _uploadProgress = pct),
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProcessingScreen(
            jobId: jobId,
            fileName: p.basename(file.path),
            fileSize: sizeMb,
            originalFilePath: file.path,
          ),
        ),
      );
    } catch (e) {
      setState(() => _error = 'خطأ في الرفع: تأكد من رابط الـ API في constants.dart\n$e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: kBgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Logo + Title ─────────────────────────────────────── //
                _buildHeader(),
                const SizedBox(height: 48),

                // ── Upload Card ──────────────────────────────────────── //
                _buildUploadCard(),
                const SizedBox(height: 24),

                // ── Error ────────────────────────────────────────────── //
                if (_error != null) _buildError(),

                // ── Formats ──────────────────────────────────────────── //
                const SizedBox(height: 16),
                _buildFormats(),
                const SizedBox(height: 40),

                // ── Pipeline info ─────────────────────────────────────── //
                _buildPipelineInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────── //
  Widget _buildHeader() {
    return Column(
      children: [
        // Glowing icon
        Container(
          width: 96,
          height: 96,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: kAccentGradient,
            boxShadow: [
              BoxShadow(
                color: kAccent.withOpacity(0.4),
                blurRadius: 32,
                spreadRadius: 8,
              ),
            ],
          ),
          child: const Icon(Icons.graphic_eq_rounded,
              color: Colors.white, size: 48),
        )
            .animate(onPlay: (c) => c.repeat())
            .shimmer(duration: 3000.ms, color: Colors.white.withOpacity(0.2)),
        const SizedBox(height: 20),
        ShaderMask(
          shaderCallback: (r) => kAccentGradient.createShader(r),
          child: const Text(
            'SoundPure',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
        const SizedBox(height: 8),
        const Text(
          'تنقية الصوت بالذكاء الاصطناعي',
          style: TextStyle(color: kTextSub, fontSize: 15),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  // ── Upload Card ─────────────────────────────────────────────────────── //
  Widget _buildUploadCard() {
    return GestureDetector(
      onTap: _uploading ? null : _pickAndUpload,
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          gradient: kCardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: _uploading ? kAccent : kBorder,
            width: _uploading ? 1.5 : 1,
          ),
          boxShadow: _uploading
              ? [BoxShadow(
                  color: kAccent.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 4,
                )]
              : [],
        ),
        child: _uploading ? _buildUploading() : _buildDropZone(),
      )
          .animate()
          .fadeIn(delay: 300.ms)
          .slideY(begin: 0.1),
    );
  }

  Widget _buildDropZone() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: kAccentGradient,
            boxShadow: [
              BoxShadow(
                color: kAccent.withOpacity(0.35),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.upload_file_rounded,
              color: Colors.white, size: 38),
        )
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.05, duration: 1200.ms,
                curve: Curves.easeInOut),
        const SizedBox(height: 18),
        const Text(
          'اضغط لاختيار ملف صوتي',
          style: TextStyle(
            color: kText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'أي صيغة · أي مدة · حتى 500 MB',
          style: TextStyle(color: kTextSub, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildUploading() {
    final pct = (_uploadProgress * 100).toInt();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            value: _uploadProgress > 0 ? _uploadProgress : null,
            strokeWidth: 3,
            color: kAccent,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _uploadProgress > 0 ? 'جاري الرفع... $pct%' : 'جاري الرفع...',
          style: const TextStyle(color: kText, fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (_uploadProgress > 0)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _uploadProgress,
                minHeight: 4,
                backgroundColor: kBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(kAccent),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: kError.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kError.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: kError, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(_error!,
              style: const TextStyle(color: kError, fontSize: 13)),
        ),
      ]),
    ).animate().shakeX(duration: 400.ms);
  }

  // ── Formats ─────────────────────────────────────────────────────────── //
  Widget _buildFormats() {
    return Column(
      children: [
        const Text('الصيغ المدعومة',
            style: TextStyle(color: kTextSub, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: kSupportedFormats
              .map((f) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder),
                    ),
                    child: Text(f,
                        style: const TextStyle(
                            color: kTextSub, fontSize: 12,
                            fontWeight: FontWeight.w500)),
                  ))
              .toList(),
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  // ── Pipeline info ───────────────────────────────────────────────────── //
  Widget _buildPipelineInfo() {
    final steps = [
      ('🤖', 'Demucs htdemucs_ft', 'فصل الصوت البشري عن الخلفية'),
      ('🔇', 'Spectral Gating', 'إزالة الضوضاء متعددة المراحل'),
      ('📐', 'Wiener Filter', 'تصفية رياضية للضوضاء المتبقية'),
      ('💨', 'Spectral Subtraction', 'إزالة صوت الهواء والمحيط'),
      ('🎚️', 'Voice EQ', 'تحسين ترددات الصوت البشري'),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: kCardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('النماذج المستخدمة',
              style: TextStyle(
                  color: kText, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Text(e.value.$1, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value.$2,
                            style: const TextStyle(
                                color: kAccent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(e.value.$3,
                            style: const TextStyle(
                                color: kTextSub, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1);
  }
}
