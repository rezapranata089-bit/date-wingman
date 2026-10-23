import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Opt {
  final String id;
  final String label;
  final String prompt;
  const Opt(this.id, this.label, this.prompt);
}

String optPrompt(List<Opt> list, String id) =>
    list.firstWhere((o) => o.id == id, orElse: () => list.first).prompt;

String optLabel(List<Opt> list, String id) =>
    list.firstWhere((o) => o.id == id, orElse: () => list.first).label;

const List<Opt> kTones = [
  Opt('santai', '😎 Santai', 'santai, natural, seperti ngobrol dengan teman dekat'),
  Opt('lucu', '😂 Lucu', 'lucu dan witty dengan humor ringan yang tidak memaksa'),
  Opt('flirty', '😏 Flirty', 'menggoda secara halus, percaya diri, tidak murahan'),
  Opt('romantis', '🥰 Romantis', 'hangat, manis, dan tulus'),
  Opt('perhatian', '🤗 Perhatian', 'peduli, empatik, dan menunjukkan mendengarkan'),
  Opt('cool', '🧊 Cool', 'singkat, tenang, sedikit misterius, tidak terlalu antusias'),
  Opt('sopan', '🙂 Sopan', 'sopan, rapi, dan menghormati'),
  Opt('berani', '🔥 Berani', 'berani dan to the point, tetap menghargai batasan'),
];

const List<Opt> kGoals = [
  Opt('lanjut', 'Lanjutkan obrolan',
      'menjaga obrolan tetap hidup dan menarik, menanggapi lalu menambah pertanyaan atau topik'),
  Opt('opener', 'Pesan pembuka',
      'membuka obrolan pertama yang menarik dan tidak klise berdasarkan info profil atau konteks'),
  Opt('ajak', 'Ajak ketemu',
      'mengajak bertemu atau kencan secara santai, spesifik, dan tanpa tekanan'),
  Opt('jawab', 'Jawab pertanyaan',
      'menjawab pertanyaan Dia dengan menarik lalu memantulkan pertanyaan balik bila pas'),
  Opt('sulit', 'Pesan sulit',
      'menanggapi situasi canggung atau sensitif dengan dewasa dan tenang'),
  Opt('tolak', 'Tolak halus',
      'menolak atau mengurangi intensitas dengan sopan, jelas, dan tidak menyakiti'),
  Opt('maaf', 'Minta maaf',
      'meminta maaf dengan tulus dan memperbaiki suasana tanpa berlebihan'),
  Opt('tutup', 'Akhiri obrolan',
      'mengakhiri obrolan dengan baik dan meninggalkan kesan positif'),
];

const List<Opt> kStages = [
  Opt('baru', 'Baru kenalan', 'baru kenalan, jaga tetap ringan dan tidak terlalu personal'),
  Opt('pdkt', 'PDKT', 'tahap pendekatan, ada ketertarikan tapi belum resmi'),
  Opt('dekat', 'Sudah dekat', 'sudah akrab dan nyaman satu sama lain'),
  Opt('pacaran', 'Pacaran', 'sudah berpacaran, boleh hangat dan personal'),
  Opt('mantan', 'Mantan', 'mantan pasangan, jaga batasan dan jangan memanipulasi'),
];

const List<Opt> kLanguages = [
  Opt('gaul', 'Indo gaul',
      'Bahasa Indonesia santai sehari-hari (aku/kamu, boleh singkatan wajar seperti gak, udah, banget)'),
  Opt('baku', 'Indo sopan', 'Bahasa Indonesia sopan dan rapi'),
  Opt('campur', 'Indo-Inggris',
      'campuran Indonesia dan Inggris ala anak Jaksel, tidak berlebihan'),
  Opt('en', 'English', 'English yang natural'),
  Opt('auto', 'Ikuti chat', 'samakan bahasa dan gaya dengan chat Dia'),
];

const List<Opt> kLengths = [
  Opt('pendek', 'Pendek', '1 kalimat singkat'),
  Opt('sedang', 'Sedang', '1-2 kalimat'),
  Opt('panjang', 'Panjang', '2-4 kalimat'),
];

class HistoryItem {
  final String time;
  final String tone;
  final String preview;
  final List<String> replies;

  HistoryItem({
    required this.time,
    required this.tone,
    required this.preview,
    required this.replies,
  });

  Map<String, dynamic> toJson() => {
        'time': time,
        'tone': tone,
        'preview': preview,
        'replies': replies,
      };

  factory HistoryItem.fromJson(Map<String, dynamic> j) => HistoryItem(
        time: '${j['time'] ?? ''}',
        tone: '${j['tone'] ?? ''}',
        preview: '${j['preview'] ?? ''}',
        replies: ((j['replies'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

class AppSettings extends ChangeNotifier {
  SharedPreferences? _p;

  String provider = 'gemini';
  String geminiKey = '';
  String claudeKey = '';
  String geminiModel = 'gemini-2.5-flash';
  String claudeModel = 'claude-haiku-5-5';

  String toneId = 'santai';
  String goal = 'lanjut';
  String stage = 'pdkt';
  String language = 'gaul';
  String length = 'sedang';
  bool useEmoji = true;
  String aboutMe = '';

  bool autoGenerate = true;
  bool useVision = false;
  bool saveHistory = true;
  bool hideTip = false;

  List<HistoryItem> history = [];

  String get activeKey => provider == 'claude' ? claudeKey : geminiKey;
  String get activeModel => provider == 'claude' ? claudeModel : geminiModel;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _p = p;
    provider = p.getString('provider') ?? provider;
    geminiKey = p.getString('geminiKey') ?? geminiKey;
    claudeKey = p.getString('claudeKey') ?? claudeKey;
    geminiModel = p.getString('geminiModel') ?? geminiModel;
    claudeModel = p.getString('claudeModel') ?? claudeModel;
    toneId = p.getString('toneId') ?? toneId;
    goal = p.getString('goal') ?? goal;
    stage = p.getString('stage') ?? stage;
    language = p.getString('language') ?? language;
    length = p.getString('length') ?? length;
    useEmoji = p.getBool('useEmoji') ?? useEmoji;
    aboutMe = p.getString('aboutMe') ?? aboutMe;
    autoGenerate = p.getBool('autoGenerate') ?? autoGenerate;
    useVision = p.getBool('useVision') ?? useVision;
    saveHistory = p.getBool('saveHistory') ?? saveHistory;
    hideTip = p.getBool('hideTip') ?? hideTip;
    final raw = p.getString('history');
    if (raw != null) {
      try {
        history = (jsonDecode(raw) as List)
            .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        history = [];
      }
    }
  }

  void update(VoidCallback fn) {
    fn();
    notifyListeners();
    _save();
  }

  void addHistory(HistoryItem item) {
    history.insert(0, item);
    if (history.length > 50) history = history.sublist(0, 50);
    notifyListeners();
    _save();
  }

  void removeHistoryAt(int index) {
    if (index < 0 || index >= history.length) return;
    history.removeAt(index);
    notifyListeners();
    _save();
  }

  void clearHistory() {
    history = [];
    notifyListeners();
    _save();
  }

  Future<void> _save() async {
    final p = _p;
    if (p == null) return;
    await p.setString('provider', provider);
    await p.setString('geminiKey', geminiKey);
    await p.setString('claudeKey', claudeKey);
    await p.setString('geminiModel', geminiModel);
    await p.setString('claudeModel', claudeModel);
    await p.setString('toneId', toneId);
    await p.setString('goal', goal);
    await p.setString('stage', stage);
    await p.setString('language', language);
    await p.setString('length', length);
    await p.setBool('useEmoji', useEmoji);
    await p.setString('aboutMe', aboutMe);
    await p.setBool('autoGenerate', autoGenerate);
    await p.setBool('useVision', useVision);
    await p.setBool('saveHistory', saveHistory);
    await p.setBool('hideTip', hideTip);
    await p.setString(
        'history', jsonEncode(history.map((e) => e.toJson()).toList()));
  }
}