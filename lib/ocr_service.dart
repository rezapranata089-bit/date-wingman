import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class _Ln {
  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;
  _Ln(this.text, this.left, this.right, this.top, this.bottom);
}

class OcrService {
  static final RegExp _timeRe = RegExp(r'^\d{1,2}[:.]\d{2}(\s?[APap][Mm])?$');

  /// Membaca screenshot chat, mengembalikan teks berlabel "Dia:" / "Aku:".
  static Future<String> read(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble();
    final h = frame.image.height.toDouble();
    frame.image.dispose();
    codec.dispose();

    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await rec.processImage(InputImage.fromFilePath(path));
      final lines = <_Ln>[];
      for (final b in res.blocks) {
        for (final l in b.lines) {
          final r = l.boundingBox;
          final t = l.text.trim();
          if (t.isEmpty) continue;
          final cy = (r.top + r.bottom) / 2;
          if (cy < h * 0.10 || cy > h * 0.92) continue;
          final cx = ((r.left + r.right) / 2) / w;
          final wd = (r.right - r.left) / w;
          if ((cx - 0.5).abs() < 0.08 && wd < 0.45) continue;
          if (_timeRe.hasMatch(t)) continue;
          lines.add(_Ln(t, r.left, r.right, r.top, r.bottom));
        }
      }
      lines.sort((a, b) => a.top.compareTo(b.top));

      final groups = <List<_Ln>>[];
      for (final l in lines) {
        if (groups.isNotEmpty) {
          final last = groups.last.last;
          final gap = l.top - last.bottom;
          final lh = last.bottom - last.top;
          if (gap < lh * 0.6 && (l.left - last.left).abs() < w * 0.04) {
            groups.last.add(l);
            continue;
          }
        }
        groups.add([l]);
      }

      final out = <String>[];
      for (final g in groups) {
        var left = g.first.left;
        var right = g.first.right;
        for (final l in g) {
          if (l.left < left) left = l.left;
          if (l.right > right) right = l.right;
        }
        final mine = left > (w - right) + w * 0.04;
        final text = g.map((e) => e.text).join(' ');
        out.add('${mine ? 'Aku' : 'Dia'}: $text');
      }

      final recent = out.length > 60 ? out.sublist(out.length - 60) : out;
      var joined = recent.join('\n');
      if (joined.length > 4000) {
        joined = joined.substring(joined.length - 4000);
      }
      return joined;
    } finally {
      await rec.close();
    }
  }
}