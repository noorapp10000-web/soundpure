class JobStatus {
  final String jobId;
  final String status; // pending | processing | completed | failed
  final int progress;  // 0–100
  final String stage;
  final String originalFormat;
  final String? outputPath;
  final String? error;

  const JobStatus({
    required this.jobId,
    required this.status,
    required this.progress,
    required this.stage,
    required this.originalFormat,
    this.outputPath,
    this.error,
  });

  factory JobStatus.fromJson(Map<String, dynamic> j) => JobStatus(
        jobId: j['job_id'] as String,
        status: j['status'] as String,
        progress: (j['progress'] as num).toInt(),
        stage: j['stage'] as String,
        originalFormat: j['original_format'] as String? ?? '.mp3',
        outputPath: j['output_path'] as String?,
        error: j['error'] as String?,
      );

  bool get isPending    => status == 'pending';
  bool get isProcessing => status == 'processing';
  bool get isCompleted  => status == 'completed';
  bool get isFailed     => status == 'failed';
  bool get isDone       => isCompleted || isFailed;
}
