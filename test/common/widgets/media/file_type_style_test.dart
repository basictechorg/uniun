import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uniun/common/widgets/media/file_type_style.dart';

void main() {
  group('extension-driven (filename wins over mime)', () {
    test('pdf', () {
      final s = FileTypeStyle.fromMime('application/octet-stream', 'a.pdf');
      expect(s.label, 'PDF');
      expect(s.readableType, 'PDF Document');
      expect(s.icon, Icons.picture_as_pdf_outlined);
    });

    test('doc + docx → Word Document', () {
      expect(FileTypeStyle.fromMime('', 'r.doc').label, 'DOC');
      expect(FileTypeStyle.fromMime('', 'r.docx').label, 'DOCX');
      expect(FileTypeStyle.fromMime('', 'r.docx').readableType,
          'Word Document');
    });

    test('xls / xlsx / csv → Spreadsheet', () {
      for (final n in ['s.xls', 's.xlsx', 's.csv']) {
        final s = FileTypeStyle.fromMime('', n);
        expect(s.readableType, 'Spreadsheet');
        expect(s.label, n.split('.').last.toUpperCase());
      }
    });

    test('ppt + pptx → Presentation', () {
      expect(FileTypeStyle.fromMime('', 'd.ppt').readableType,
          'Presentation');
      expect(FileTypeStyle.fromMime('', 'd.pptx').label, 'PPTX');
    });

    test('zip / rar / 7z → Archive', () {
      for (final n in ['a.zip', 'a.rar', 'a.7z']) {
        expect(FileTypeStyle.fromMime('', n).readableType, 'Archive');
      }
    });

    test('txt + md → Text', () {
      expect(FileTypeStyle.fromMime('', 'r.txt').readableType, 'Text');
      expect(FileTypeStyle.fromMime('', 'r.md').readableType, 'Text');
    });

    test('uppercase extension lowercased for matching, label uppercased', () {
      final s = FileTypeStyle.fromMime('', 'REPORT.PDF');
      expect(s.label, 'PDF');
      expect(s.readableType, 'PDF Document');
    });
  });

  group('mime-driven (no filename / unknown extension)', () {
    test('application/pdf → pdf', () {
      expect(FileTypeStyle.fromMime('application/pdf', null).label, 'PDF');
    });

    test('text/csv → csv / Spreadsheet', () {
      final s = FileTypeStyle.fromMime('text/csv', null);
      expect(s.label, 'CSV');
      expect(s.readableType, 'Spreadsheet');
    });

    test('mime is case-insensitive', () {
      expect(FileTypeStyle.fromMime('APPLICATION/PDF', null).label, 'PDF');
    });
  });

  group('video / audio fallback', () {
    test('video/* with extension keeps it as label', () {
      final s = FileTypeStyle.fromMime('video/mp4', 'clip.mp4');
      expect(s.label, 'MP4');
      expect(s.readableType, 'Video');
      expect(s.icon, Icons.play_circle_outline);
    });

    test('video/* with no filename → VID', () {
      final s = FileTypeStyle.fromMime('video/quicktime', null);
      expect(s.label, 'VID');
      expect(s.readableType, 'Video');
    });

    test('audio/* with no filename → AUD', () {
      final s = FileTypeStyle.fromMime('audio/mpeg', null);
      expect(s.label, 'AUD');
      expect(s.readableType, 'Audio');
    });

    test('audio/* with extension uses extension', () {
      final s = FileTypeStyle.fromMime('audio/wav', 'voice.wav');
      expect(s.label, 'WAV');
    });
  });

  group('unknown', () {
    test('unknown mime + no filename → FILE', () {
      final s = FileTypeStyle.fromMime('application/octet-stream', null);
      expect(s.label, 'FILE');
      expect(s.readableType, 'File');
      expect(s.icon, Icons.insert_drive_file_outlined);
    });

    test('unknown mime + filename without extension → FILE', () {
      final s = FileTypeStyle.fromMime('application/octet-stream', 'README');
      expect(s.label, 'FILE');
    });

    test('unknown mime + filename ending in dot → FILE', () {
      final s = FileTypeStyle.fromMime('application/octet-stream', 'README.');
      expect(s.label, 'FILE');
    });

    test('unknown mime + unknown extension uses extension uppercased', () {
      final s = FileTypeStyle.fromMime('application/octet-stream', 'a.xyz');
      expect(s.label, 'XYZ');
      expect(s.readableType, 'File');
    });
  });

  // (color is now resolved via colorFor(BuildContext); widget-level test lives
  // in the note_card tests where the chip actually renders.)

  // ── Edge cases ─────────────────────────────────────────────────────────────

  group('multi-dot filenames', () {
    test('uses ONLY the last extension', () {
      // "Project.Final.tar.gz" → ext = "gz" (not "tar.gz").
      final s = FileTypeStyle.fromMime('', 'Project.Final.tar.gz');
      expect(s.label, 'GZ');
      expect(s.readableType, 'File');
    });

    test('the actual zip extension wins', () {
      final s = FileTypeStyle.fromMime('', 'a.b.c.zip');
      expect(s.label, 'ZIP');
      expect(s.readableType, 'Archive');
    });
  });

  group('case insensitivity', () {
    test('all-caps PDF filename', () {
      expect(FileTypeStyle.fromMime('', 'INVOICE.PDF').label, 'PDF');
    });

    test('mixed-case mime', () {
      expect(FileTypeStyle.fromMime('Application/PDF', null).label, 'PDF');
    });

    test('mixed-case extension', () {
      expect(FileTypeStyle.fromMime('', 'photo.JPEG').label, 'JPEG');
    });
  });

  group('weird filenames', () {
    test('empty filename falls back to mime', () {
      expect(FileTypeStyle.fromMime('application/pdf', '').label, 'PDF');
    });

    test('".gitignore" → ext = gitignore', () {
      // lastIndexOf('.') == 0; 0 < length-1.
      expect(FileTypeStyle.fromMime('', '.gitignore').label, 'GITIGNORE');
    });

    test('path separators are not split — only the last "." matters', () {
      expect(FileTypeStyle.fromMime('', 'path/to/a.pdf').label, 'PDF');
    });

    test('trailing dot → no usable extension', () {
      expect(FileTypeStyle.fromMime('', 'incomplete.').label, 'FILE');
    });

    test('very long extension keeps the full string as label', () {
      final s = FileTypeStyle.fromMime('', 'file.thisisaridiculouslylongext');
      expect(s.label, 'THISISARIDICULOUSLYLONGEXT');
    });
  });

  group('mime → extension mapping', () {
    test('docx mime → DOCX / Word Document', () {
      final s = FileTypeStyle.fromMime(
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
          null);
      expect(s.label, 'DOCX');
      expect(s.readableType, 'Word Document');
    });

    test('xlsx mime → XLSX / Spreadsheet', () {
      final s = FileTypeStyle.fromMime(
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          null);
      expect(s.label, 'XLSX');
      expect(s.readableType, 'Spreadsheet');
    });

    test('pptx mime → PPTX / Presentation', () {
      final s = FileTypeStyle.fromMime(
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
          null);
      expect(s.label, 'PPTX');
      expect(s.readableType, 'Presentation');
    });

    test('rar mime → RAR / Archive', () {
      final s = FileTypeStyle.fromMime('application/x-rar-compressed', null);
      expect(s.label, 'RAR');
      expect(s.readableType, 'Archive');
    });
  });

  group('all typed extensions classify (guard against switch removal)', () {
    const typed = {
      'pdf': 'PDF Document',
      'doc': 'Word Document',
      'docx': 'Word Document',
      'xls': 'Spreadsheet',
      'xlsx': 'Spreadsheet',
      'csv': 'Spreadsheet',
      'ppt': 'Presentation',
      'pptx': 'Presentation',
      'zip': 'Archive',
      'rar': 'Archive',
      '7z': 'Archive',
      'txt': 'Text',
      'md': 'Text',
    };
    for (final entry in typed.entries) {
      test(entry.key, () {
        final s = FileTypeStyle.fromMime('', 'name.${entry.key}');
        expect(s.readableType, entry.value);
        expect(s.label, entry.key.toUpperCase());
      });
    }
  });
}
