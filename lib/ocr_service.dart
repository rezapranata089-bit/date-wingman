import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class _Ln {
  final String text;
  final double left;
  final double right;
  final double top;
  final double bottom;
  final String time;
  final bool date;
  _Ln(this.text, this.left, this.right, this.top, this.bottom,
      {this.time = '', this.date = false});
}

class OcrService {
  static final RegExp _timeRe = RegExp(r'^\d{1,2}[:.]\d{2}(\s?[APap][Mm])?$');
  static final RegExp _tailTimeRe =
      RegExp(r'\s*[\dgGoOlI]{1,2}[:.][\dOo]{2}\s?[APap][Mm]\b.{0,3}$');
  static final RegExp _noiseRe = RegExp(r'^(\d[A-Za-z]|[A-Za-z]\d)$');
  static final RegExp _dateRe = RegExp(
      r'^(\d{1,2}\s+(jan|feb|mar|apr|mei|jun|jul|agu|aug|sep|okt|oct|nov|des|dec)[a-z]*(\s+\d{4})?|hari ini|kemarin|today|yesterday|senin|selasa|rabu|kamis|jumat|jum.at|sabtu|minggu|monday|tuesday|wednesday|thursday|friday|saturday|sunday)$',
      caseSensitive: false);

  static String _normTime(String s) {
    final m = RegExp(r'([\dgGoOlI]{1,2})[:.]([\dOo]{2})\s?([APap][Mm])')
        .firstMatch(s);
    if (m == null) return '';
    String fix(String x) => x
        .replaceAll(RegExp('[gG]'), '9')
        .replaceAll(RegExp('[oO]'), '0')
        .replaceAll(RegExp('[lI]'), '1');
    return '${fix(m.group(1)!)}:${fix(m.group(2)!)} ${m.group(3)!.toUpperCase()}';
  }

  /// True jika hasil OCR terlihat berantakan (dipakai untuk mode hybrid).
  static bool looksBad(String t) {
    final ls = t.split('\n').where((e) => e.trim().isNotEmpty).toList();
    if (ls.length < 2) return true;
    var bad = 0;
    for (final l in ls) {
      final b = l.replaceFirst(RegExp(r'^(\[[^\]]*\]\s*)?(Aku|Dia): '), '');
      if (b.length < 2 || RegExp(r'\d[:.]\d{2}').hasMatch(b)) bad++;
    }
    return bad / ls.length > 0.3;
  }

  static double _dist(List<int> a, List<int> b) {
    final dr = (a[0] - b[0]).toDouble();
    final dg = (a[1] - b[1]).toDouble();
    final db = (a[2] - b[2]).toDouble();
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  static List<int>? _avgColor(List<List<int>?> cols, List<int> idx) {
    if (idx.isEmpty) return null;
    var r = 0, g = 0, b = 0;
    for (final i in idx) {
      final c = cols[i]!;
      r += c[0];
      g += c[1];
      b += c[2];
    }
    return [r ~/ idx.length, g ~/ idx.length, b ~/ idx.length];
  }

  /// Warna latar bubble: sampel piksel di kiri teks (area padding bubble).
  static List<int>? _bubbleColor(
      ByteData? bd, int iw, int ih, double left, double cy) {
    if (bd == null) return null;
    final xi = (left - 12).round();
    if (xi < 0 || xi >= iw) return null;
    var r = 0, g = 0, b = 0, n = 0;
    for (final dy in [-6, 0, 6]) {
      final yi = cy.round() + dy;
      if (yi < 0 || yi >= ih) continue;
      final o = (yi * iw + xi) * 4;
      r += bd.getUint8(o);
      g += bd.getUint8(o + 1);
      b += bd.getUint8(o + 2);
      n++;
    }
    if (n == 0) return null;
    return [r ~/ n, g ~/ n, b ~/ n];
  }

  /// Membaca screenshot chat, mengembalikan teks berlabel "Dia:" / "Aku:".
  static Future<String> read(String path, {String myName = ''}) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final w = frame.image.width.toDouble();
    final h = frame.image.height.toDouble();
    final iw = frame.image.width;
    final ih = frame.image.height;
    ByteData? bd;
    try {
      bd = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } catch (_) {}
    frame.image.dispose();
    codec.dispose();

    final rec = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final res = await rec.processImage(InputImage.fromFilePath(path));
      final lines = <_Ln>[];
      final times = <_Ln>[];
      for (final b in res.blocks) {
        for (final l in b.lines) {
          final r = l.boundingBox;
          final raw = l.text.trim();
          final tm = _normTime(raw);
          final t = raw.replaceAll(_tailTimeRe, '').trim();
          if (tm.isNotEmpty && (t.isEmpty || _timeRe.hasMatch(raw))) {
            times.add(_Ln('', r.left, r.right, r.top, r.bottom, time: tm));
            continue;
          }
          if (t.length <= 1 || _noiseRe.hasMatch(t)) continue;
          final cy = (r.top + r.bottom) / 2;
          if (cy < h * 0.10 || cy > h * 0.92) continue;
          if (_timeRe.hasMatch(t)) continue;
          lines.add(_Ln(t, r.left, r.right, r.top, r.bottom,
              time: tm, date: _dateRe.hasMatch(t)));
        }
      }
      lines.sort((a, b) => a.top.compareTo(b.top));

      // Buang iklan Telegram: baris "Iklan" + baris rapat di bawahnya (rata kiri sama).
      final noAd = <_Ln>[];
      double? adLeft;
      var adBottom = 0.0;
      for (final l in lines) {
        final lh = l.bottom - l.top;
        if (l.text.toLowerCase().startsWith('iklan')) {
          adLeft = l.left;
          adBottom = l.bottom;
          continue;
        }
        if (adLeft != null &&
            (l.left - adLeft).abs() < w * 0.03 &&
            l.top - adBottom < lh * 0.9) {
          adBottom = l.bottom;
          continue;
        }
        adLeft = null;
        noAd.add(l);
      }
      lines
        ..clear()
        ..addAll(noAd);

      // Buang kutipan reply: baris header (nama pengirim) + baris kutipan di bawahnya.
      final me = myName.trim().toLowerCase();
      bool isHeader(String s) {
        final x = s.toLowerCase().trim();
        return x.contains('@') ||
            x.startsWith('anonymous chat') ||
            (me.isNotEmpty && x == me);
      }

      final kept = <_Ln>[];
      for (var i = 0; i < lines.length; i++) {
        final x = lines[i].text.toLowerCase().trim();
        if (isHeader(lines[i].text)) {
          i++;
          continue;
        }
        if (me.isNotEmpty && x.startsWith('$me ')) continue;
        kept.add(lines[i]);
      }
      lines
        ..clear()
        ..addAll(kept);

      final groups = <List<_Ln>>[];
      for (final l in lines) {
        if (groups.isNotEmpty) {
          final last = groups.last.last;
          final gap = l.top - last.bottom;
          final lh = last.bottom - last.top;
          if (!l.date &&
              !last.date &&
              gap < lh * 0.6 &&
              (l.left - last.left).abs() < w * 0.04) {
            groups.last.add(l);
            continue;
          }
        }
        groups.add([l]);
      }

      final texts = <String>[];
      final tms = <String>[];
      final dates = <bool>[];
      final lefts = <double>[];
      final rights = <double>[];
      final cols = <List<int>?>[];
      for (final g in groups) {
        var left = g.first.left;
        var right = g.first.right;
        for (final l in g) {
          if (l.left < left) left = l.left;
          if (l.right > right) right = l.right;
        }
        texts.add(g.map((e) => e.text).join(' '));
        dates.add(g.first.date);
        var gt = '';
        for (final e in g) {
          if (e.time.isNotEmpty) gt = e.time;
        }
        if (gt.isEmpty) {
          final gTop = g.first.top;
          final gBot = g.last.bottom;
          var best = 1e9;
          for (final tl in times) {
            final cyt = (tl.top + tl.bottom) / 2;
            if (cyt < gTop - 5 || cyt > gBot + 30) continue;
            final d = (cyt - gBot).abs();
            if (d < best) {
              best = d;
              gt = tl.time;
            }
          }
        }
        tms.add(gt);
        lefts.add(left);
        rights.add(right);
        cols.add(_bubbleColor(bd, iw, ih, left, (g.first.top + g.last.bottom) / 2));
      }

      // Referensi warna: bubble yang jelas di kiri (Dia) dan jelas di kanan (Aku).
      final dIdx = <int>[];
      final mIdx = <int>[];
      for (var i = 0; i < texts.length; i++) {
        if (cols[i] == null) continue;
        final gapR = w - rights[i];
        if (lefts[i] < w * 0.2 && gapR > w * 0.18) {
          dIdx.add(i);
        } else if (lefts[i] > w * 0.22 && gapR < w * 0.12) {
          mIdx.add(i);
        }
      }
      final rd = _avgColor(cols, dIdx);
      final rm = _avgColor(cols, mIdx);
      final useColor = rd != null && rm != null && _dist(rd, rm) > 40;

      final out = <String>[];
      for (var i = 0; i < texts.length; i++) {
        final c = cols[i];
        final mine = (useColor && c != null)
            ? _dist(c, rm!) < _dist(c, rd!)
            : lefts[i] > (w - rights[i]) + w * 0.04;
        if (dates[i]) {
          out.add('--- ${texts[i]} ---');
          continue;
        }
        final tt = tms[i].isEmpty ? '' : '[${tms[i]}] ';
        out.add('$tt${mine ? 'Aku' : 'Dia'}: ${texts[i]}');
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