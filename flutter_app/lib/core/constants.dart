/// ⚠️  UPDATE THIS URL after you deploy the backend to Railway!
/// Go to Railway → your project → Settings → Domains → copy the URL.
const String kApiBaseUrl = 'https://YOUR-APP.up.railway.app';

/// Polling interval while a job is in progress
const Duration kPollInterval = Duration(seconds: 2);

/// Max upload file size shown to user (UI only – server enforces 500 MB)
const int kMaxFileMb = 500;

/// Supported audio extensions (display only)
const List<String> kSupportedFormats = [
  'MP3', 'WAV', 'M4A', 'AAC',
  'OGG', 'FLAC', 'WMA', 'OPUS',
];

/// Processing stage labels shown in the UI
const List<String> kStageLabels = [
  'تحويل الصيغة إلى WAV',
  'تحميل نموذج Demucs AI',
  'فصل الصوت البشري (htdemucs_ft)',
  'إزالة الضوضاء – Spectral Gating',
  'فلتر Wiener للضوضاء المتبقية',
  'إزالة صوت الهواء – Spectral Subtraction',
  'تحسين الترددات البشرية (EQ)',
  'تطبيع الصوت والإخراج النهائي',
];
