import 'package:flutter/material.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// Visual identity for a non-image attachment. Single source of truth shared
/// by the feed/DM/channel attachment card and the media gallery tile so
/// "PDF", "MP4", "DOCX" look identical wherever they appear.
class FileTypeStyle {
  const FileTypeStyle({
    required this.label,
    required this.readableType,
    required this.icon,
  });

  /// 3-4 char chip abbreviation ("PDF", "XLSX", "MP4").
  final String label;

  /// Subtitle label ("PDF Document", "Spreadsheet").
  final String readableType;
  final IconData icon;

  Color get color => AppColors.primary;

  static FileTypeStyle fromMime(String mime, String? filename) {
    final ext = _extOf(filename, mime);
    switch (ext) {
      case 'pdf':
        return const FileTypeStyle(
          label: 'PDF',
          readableType: 'PDF Document',
          icon: Icons.picture_as_pdf_outlined,
        );
      case 'doc':
      case 'docx':
        return FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Word Document',
          icon: Icons.description_outlined,
        );
      case 'xls':
      case 'xlsx':
      case 'csv':
        return FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Spreadsheet',
          icon: Icons.table_chart_outlined,
        );
      case 'ppt':
      case 'pptx':
        return FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Presentation',
          icon: Icons.slideshow_outlined,
        );
      case 'zip':
      case 'rar':
      case '7z':
        return FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Archive',
          icon: Icons.folder_zip_outlined,
        );
      case 'txt':
      case 'md':
        return FileTypeStyle(
          label: ext.toUpperCase(),
          readableType: 'Text',
          icon: Icons.notes_outlined,
        );
    }
    if (mime.startsWith('video/')) {
      return FileTypeStyle(
        label: ext.isEmpty ? 'VID' : ext.toUpperCase(),
        readableType: 'Video',
        icon: Icons.play_circle_outline,
      );
    }
    if (mime.startsWith('audio/')) {
      return FileTypeStyle(
        label: ext.isEmpty ? 'AUD' : ext.toUpperCase(),
        readableType: 'Audio',
        icon: Icons.audiotrack_outlined,
      );
    }
    return FileTypeStyle(
      label: ext.isEmpty ? 'FILE' : ext.toUpperCase(),
      readableType: 'File',
      icon: Icons.insert_drive_file_outlined,
    );
  }

  /// Prefer filename extension over mime mapping — filenames are accurate
  /// when present; mime is `application/octet-stream` for anything the OS
  /// picker couldn't sniff.
  static String _extOf(String? filename, String mime) {
    if (filename != null) {
      final dot = filename.lastIndexOf('.');
      if (dot >= 0 && dot < filename.length - 1) {
        return filename.substring(dot + 1).toLowerCase();
      }
    }
    const mimeExt = {
      'application/pdf': 'pdf',
      'application/msword': 'doc',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
          'docx',
      'application/vnd.ms-excel': 'xls',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet':
          'xlsx',
      'application/vnd.ms-powerpoint': 'ppt',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation':
          'pptx',
      'text/csv': 'csv',
      'text/plain': 'txt',
      'application/zip': 'zip',
      'application/x-rar-compressed': 'rar',
      'application/x-7z-compressed': '7z',
    };
    return mimeExt[mime.toLowerCase()] ?? '';
  }
}
