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

class Contact {
  String id;
  String name;
  String notes;
  String memory;
  List<String> log;

  Contact({
    required this.id,
    required this.name,
    this.notes = '',
    this.memory = '',
    List<String>? log,
  }) : log = log ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'notes': notes,
        'memory': memory,
        'log': log,
      };

  factory Contact.fromJson(Map<String, dynamic> j) => Contact(
        id: '${j['id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        notes: '${j['notes'] ?? ''}',
        memory: '${j['memory'] ?? ''}',
        log: ((j['log'] as List?) ?? []).map((e) => '$e').toList(),
      );
}

const List<List<String>> kPresetRules = [
  ['kamu', 'kmu'],
  ['tidak', 'gak'],
  ['nggak', 'gak'],
  ['sudah', 'udah'],
  ['yang', 'yg'],
  ['dengan', 'dgn'],
  ['kalau', 'kalo'],
  ['bagaimana', 'gimana'],
  ['terima kasih', 'makasih'],
  ['sama-sama', 'sm2'],
];

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

  bool useMemory = true;
  String customPrompt = '';
  String styleSample = '';
  bool lowercaseAll = false;
  bool noPeriod = false;
  List<List<String>> rules = [];
  List<String> templates = [];
  List<Contact> contacts = [];
  String? activeContactId;

  List<HistoryItem> history = [];

  Contact? get activeContact {
    for (final c in contacts) {
      if (c.id == activeContactId) return c;
    }
    return null;
  }

  Contact? get memoryContact => useMemory ? activeContact : null;

  String get activeKey => provider == 'claude' ? claudeKey : geminiKey;
  String get activeModel => provider == 'claude' ? claudeModel : geminiModel;

  static List<String> splitKeys(String raw) => raw
      .split(RegExp(r'[\s,;]+'))
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();

  List<String> get activeKeys => splitKeys(activeKey);

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
    useMemory = p.getBool('useMemory') ?? useMemory;
    styleSample = p.getString('styleSample') ?? styleSample;
    customPrompt = p.getString('customPrompt') ?? customPrompt;
    lowercaseAll = p.getBool('lowercaseAll') ?? lowercaseAll;
    noPeriod = p.getBool('noPeriod') ?? noPeriod;
    activeContactId = p.getString('activeContactId');
    try {
      final cr = p.getString('contacts');
      if (cr != null) {
        contacts = (jsonDecode(cr) as List)
            .map((e) => Contact.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final rr = p.getString('rules');
      if (rr != null) {
        rules = (jsonDecode(rr) as List)
            .map((e) => (e as List).map((x) => '$x').toList())
            .toList();
      }
      templates = p.getStringList('templates') ?? templates;
    } catch (_) {}
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

  void addContact(String name, String notes) {
    final c = Contact(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      notes: notes,
    );
    contacts.add(c);
    activeContactId = c.id;
    notifyListeners();
    _save();
  }

  void removeContact(String id) {
    contacts.removeWhere((c) => c.id == id);
    if (activeContactId == id) activeContactId = null;
    notifyListeners();
    _save();
  }

  void updateContact(Contact c, {String chat = '', String memory = ''}) {
    final seen = c.log.toSet();
    for (final raw in chat.split('\n')) {
      final l = raw.trim();
      if (l.isEmpty || seen.contains(l)) continue;
      c.log.add(l);
      seen.add(l);
    }
    if (c.log.length > 300) c.log = c.log.sublist(c.log.length - 300);
    if (memory.trim().isNotEmpty) c.memory = memory.trim();
    notifyListeners();
    _save();
  }

  String applyStyle(String text) {
    var t = text;
    for (final r in rules) {
      if (r.length < 2 || r[0].isEmpty) continue;
      t = t.replaceAll(
          RegExp('\\b${RegExp.escape(r[0])}\\b', caseSensitive: false), r[1]);
    }
    if (noPeriod) t = t.trim().replaceAll(RegExp(r'(?<!\.)\.$'), '');
    if (lowercaseAll) t = t.toLowerCase();
    return t;
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
    await p.setBool('useMemory', useMemory);
    await p.setString('styleSample', styleSample);
    await p.setString('customPrompt', customPrompt);
    await p.setBool('lowercaseAll', lowercaseAll);
    await p.setBool('noPeriod', noPeriod);
    await p.setString('rules', jsonEncode(rules));
    await p.setStringList('templates', templates);
    await p.setString(
        'contacts', jsonEncode(contacts.map((e) => e.toJson()).toList()));
    final ac = activeContactId;
    if (ac == null) {
      await p.remove('activeContactId');
    } else {
      await p.setString('activeContactId', ac);
    }
    await p.setString(
        'history', jsonEncode(history.map((e) => e.toJson()).toList()));
  }
}