import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../models/job_status.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  final Dio _dio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 30),
    sendTimeout: const Duration(minutes: 10),
  ));

  // ── Upload ──────────────────────────────────────────────────────── //

  Future<String> uploadAudio(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final fileName = p.basename(file.path);
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final resp = await _dio.post<Map<String, dynamic>>(
      '/upload',
      data: formData,
      onSendProgress: (sent, total) {
        if (total > 0 && onProgress != null) {
          onProgress(sent / total);
        }
      },
    );

    final data = resp.data;
    if (data == null || data['job_id'] == null) {
      throw Exception('Server returned no job_id');
    }
    return data['job_id'] as String;
  }

  // ── Status polling ───────────────────────────────────────────────── //

  Future<JobStatus> getStatus(String jobId) async {
    final resp = await _dio.get<Map<String, dynamic>>('/status/$jobId');
    return JobStatus.fromJson(resp.data!);
  }

  /// Emits JobStatus objects every [kPollInterval] until done.
  Stream<JobStatus> pollStatus(String jobId) async* {
    while (true) {
      final status = await getStatus(jobId);
      yield status;
      if (status.isDone) break;
      await Future.delayed(kPollInterval);
    }
  }

  // ── Download ─────────────────────────────────────────────────────── //

  /// Downloads the enhanced file and returns the local path.
  Future<String> downloadResult(
    String jobId,
    String originalFormat, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final savePath =
        p.join(dir.path, 'soundpure_enhanced$originalFormat');

    await _dio.download(
      '/download/$jobId',
      savePath,
      onReceiveProgress: (recv, total) {
        if (total > 0 && onProgress != null) {
          onProgress(recv / total);
        }
      },
    );

    return savePath;
  }
}
