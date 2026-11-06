import 'package:school_app/config/config.dart';

String buildBackendFileUrl(String rawPath) {
  final trimmed = rawPath.trim();
  if (trimmed.isEmpty) {
    return '';
  }

  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }

  var normalized = trimmed.replaceAll('\\', '/');
  if (!normalized.startsWith('/')) {
    normalized = '/$normalized';
  }

  if (normalized.startsWith('/content/uploads/') ||
      normalized.startsWith('/uploads/') ||
      normalized.startsWith('/content/')) {
    return AppConfig.absoluteUrl(normalized);
  }

  return AppConfig.absoluteUrl('/content/uploads$normalized');
}

bool isPdfFileUrl(String url) {
  return _path(url).toLowerCase().endsWith('.pdf');
}

bool isImageFileUrl(String url) {
  final lowerPath = _path(url).toLowerCase();
  return lowerPath.endsWith('.png') ||
      lowerPath.endsWith('.jpg') ||
      lowerPath.endsWith('.jpeg') ||
      lowerPath.endsWith('.gif') ||
      lowerPath.endsWith('.webp') ||
      lowerPath.endsWith('.bmp') ||
      lowerPath.endsWith('.avif') ||
      lowerPath.endsWith('.heic') ||
      lowerPath.endsWith('.heif');
}

String fileTitleFromUrl(String url, {String fallback = 'File'}) {
  final path = _path(url);
  final segments = path.split('/').where((segment) => segment.isNotEmpty);
  if (segments.isEmpty) {
    return fallback;
  }

  return Uri.decodeComponent(segments.last);
}

String _path(String url) {
  return Uri.tryParse(url)?.path ?? url;
}
