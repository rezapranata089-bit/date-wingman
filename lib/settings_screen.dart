import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_store.dart';
import 'widgets.dart';

class SettingsScreen extends StatefulWidget {
  final AppSettings settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const MethodChannel _ch = MethodChannel('date/native');

  late final TextEditingController _gKey;
  late final TextEditingController _gModel;
  late final TextEditingController _cKey;
  late final TextEditingController _cModel;
  late final TextEditingController _about;
  late final TextEditingController _style;
  late final TextEditingController _prompt;

  static const List<List<String>> _promptExamples = [
    [
      'Cowok santai',
      'Kamu menulis sebagai cowok santai, humoris tapi kalem. Balasan singkat, tidak lebay, tidak sok puitis. Selalu tutup dengan pertanyaan ringan agar obrolan lanjut.'
    ],
    [
      'Cuek tapi hangat',
      'Tulis dengan gaya cuek tapi hangat. Jangan terlalu antusias, jangan pakai kata berlebihan. Sesekali selipkan perhatian kecil yang spesifik pada hal yang Dia ceritakan.'
    ],
    [
      'Humor receh',
      'Pakai humor receh dan permainan kata ringan. Maksimal satu candaan per balasan, dan jangan menyinggung.'
    ],
    [
      'Dewasa & tenang',
      'Tulis dengan gaya dewasa, tenang, dan percaya diri. Tidak pakai singkatan alay. Fokus pada obrolan yang bermakna dan jujur.'
    ],
  ];

  static const List<Opt> _providers = [
    Opt('gemini', 'Gemini', ''),
    Opt('claude', 'Claude', ''),
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.settings;
    _gKey = TextEditingController(text: s.geminiKey);
    _gModel = TextEditingController(text: s.geminiModel);
    _cKey = TextEditingController(text: s.claudeKey);
    _cModel = TextEditingController(text: s.claudeModel);
    _about = TextEditingController(text: s.aboutMe);
    _style = TextEditingController(text: s.styleSample);
    _prompt = TextEditingController(text: s.customPrompt);
  }

  @override
  void dispose() {
    _gKey.dispose();
    _gModel.dispose();
    _cKey.dispose();
    _cModel.dispose();
    _about.dispose();
    _style.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label,
    ValueChanged<String> onChanged, {
    bool secret = false,
    int lines = 1,
    String? hint,
    bool keys = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: secret,
        enableSuggestions: !(secret || keys),
        autocorrect: !(secret || keys),
        minLines: lines,
        maxLines: secret ? 1 : (lines > 1 ? lines + 2 : 1),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Future<List<String>?> _askFields(String title, List<String> labels) async {
    final cs = labels.map((_) => TextEditingController()).toList();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < labels.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: cs[i],
                  autofocus: i == 0,
                  decoration: InputDecoration(
                    labelText: labels[i],
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return null;
    final v = cs.map((e) => e.text.trim()).toList();
    if (v.any((e) => e.isEmpty)) return null;
    return v;
  }

  Future<void> _addRule() async {
    final v = await _askFields(
        'Ganti kata', ['Kata asli (mis. kamu)', 'Jadi (mis. kmu)']);
    if (v == null) return;
    widget.settings.update(() => widget.settings.rules.add(v));
  }

  Future<void> _addTemplate() async {
    final v = await _askFields('Template baru', ['Isi template']);
    if (v == null) return;
    widget.settings.update(() => widget.settings.templates.add(v[0]));
  }

  void _presetRules() {
    final s = widget.settings;
    s.update(() {
      for (final r in kPresetRules) {
        if (!s.rules.any((x) => x[0] == r[0])) s.rules.add([r[0], r[1]]);
      }
    });
  }

  Future<void> _openAssist() async {
    try {
      await _ch.invokeMethod('openAssistSettings');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Pengaturan')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                const SectionTitle('Penyedia AI'),
                OptChips(
                  options: _providers,
                  selected: s.provider,
                  onSelected: (id) => s.update(() => s.provider = id),
                ),
                const SizedBox(height: 12),
                if (s.provider == 'gemini') ...[
                  _field(_gKey, 'API key Gemini (satu per baris)',
                      (v) => s.update(() => s.geminiKey = v.trim()),
                      lines: 3, keys: true, hint: 'AIza...\nAIza...'),
                  _field(_gModel, 'Model Gemini',
                      (v) => s.update(() => s.geminiModel = v.trim())),
                ] else ...[
                  _field(_cKey, 'API key Claude (satu per baris)',
                      (v) => s.update(() => s.claudeKey = v.trim()),
                      lines: 3, keys: true, hint: 'sk-ant-...\nsk-ant-...'),
                  _field(_cModel, 'Model Claude',
                      (v) => s.update(() => s.claudeModel = v.trim())),
                ],
                Text(
                  'Terdeteksi ${s.activeKeys.length} key. Urutan = prioritas. Jika key gagal (kuota habis, key salah, atau server error), otomatis pakai key berikutnya.',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'API key disimpan di HP kamu. Untuk rilis publik, sebaiknya pakai server sendiri agar key tidak ikut di dalam aplikasi.',
                  style: TextStyle(fontSize: 12),
                ),
                const SectionTitle('Tentang kamu'),
                _field(
                  _about,
                  'Hobi, pekerjaan, gaya bicara',
                  (v) => s.update(() => s.aboutMe = v),
                  lines: 3,
                  hint: 'Contoh: suka kopi dan hiking, kerja di IT, humoris tapi kalem',
                ),
                const SectionTitle('Memori percakapan'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ingat obrolan sebelumnya'),
                  subtitle: const Text(
                      'Chat dan ringkasan per lawan bicara disimpan di HP, lalu ikut dikirim ke AI sebagai konteks'),
                  value: s.useMemory,
                  onChanged: (v) => s.update(() => s.useMemory = v),
                ),
                const SectionTitle('Prompt kustom'),
                _field(
                  _prompt,
                  'Instruksi untuk AI (opsional)',
                  (v) => s.update(() => s.customPrompt = v),
                  lines: 5,
                  hint:
                      'Contoh: Kamu adalah aku, cowok santai. Jangan pakai kata "banget". Selalu balas dengan pertanyaan balik.',
                ),
                const Text(
                  'Instruksi ini jadi aturan utama untuk AI dan mengalahkan preferensi lain. Format hasil tetap dijaga. Ketuk contoh di bawah untuk mengisi otomatis.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ..._promptExamples.map((x) => ActionChip(
                          label: Text(x[0]),
                          onPressed: () {
                            _prompt.text = x[1];
                            s.update(() => s.customPrompt = x[1]);
                          },
                        )),
                    ActionChip(
                      avatar: const Icon(Icons.clear, size: 18),
                      label: const Text('Kosongkan'),
                      onPressed: () {
                        _prompt.clear();
                        s.update(() => s.customPrompt = '');
                      },
                    ),
                  ],
                ),
                const SectionTitle('Gaya bicara'),
                _field(
                  _style,
                  'Contoh caramu chatting',
                  (v) => s.update(() => s.styleSample = v),
                  lines: 3,
                  hint: 'Contoh: gpp kok, nanti aku kabarin ya. wkwk iya sih',
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Huruf kecil semua'),
                  value: s.lowercaseAll,
                  onChanged: (v) => s.update(() => s.lowercaseAll = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hilangkan titik di akhir balasan'),
                  value: s.noPeriod,
                  onChanged: (v) => s.update(() => s.noPeriod = v),
                ),
                const SizedBox(height: 8),
                const Text('Ganti kata otomatis (contoh: kamu → kmu)'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ...List.generate(
                      s.rules.length,
                      (i) => InputChip(
                        label: Text('${s.rules[i][0]} → ${s.rules[i][1]}'),
                        onDeleted: () => s.update(() => s.rules.removeAt(i)),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah'),
                      onPressed: _addRule,
                    ),
                    ActionChip(
                      label: const Text('Preset gaul'),
                      onPressed: _presetRules,
                    ),
                  ],
                ),
                const SectionTitle('Template balasan cepat'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ...List.generate(
                      s.templates.length,
                      (i) => InputChip(
                        label: Text(s.templates[i]),
                        onDeleted: () =>
                            s.update(() => s.templates.removeAt(i)),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah'),
                      onPressed: _addTemplate,
                    ),
                  ],
                ),
                const SectionTitle('Preferensi default'),
                const Text('Bahasa'),
                const SizedBox(height: 6),
                OptChips(
                  options: kLanguages,
                  selected: s.language,
                  onSelected: (id) => s.update(() => s.language = id),
                ),
                const SizedBox(height: 12),
                const Text('Panjang balasan'),
                const SizedBox(height: 6),
                OptChips(
                  options: kLengths,
                  selected: s.length,
                  onSelected: (id) => s.update(() => s.length = id),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pakai emoji'),
                  value: s.useEmoji,
                  onChanged: (v) => s.update(() => s.useEmoji = v),
                ),
                const SectionTitle('Perilaku'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Langsung buat balasan'),
                  subtitle: const Text(
                      'Setelah screenshot terbaca, saran balasan otomatis dibuat'),
                  value: s.autoGenerate,
                  onChanged: (v) => s.update(() => s.autoGenerate = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kirim gambar ke AI'),
                  subtitle: const Text(
                      'Lebih akurat (baca stiker/emoji) tapi lebih mahal dan kurang privat. Default: hanya teks hasil OCR'),
                  value: s.useVision,
                  onChanged: (v) => s.update(() => s.useVision = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Simpan riwayat'),
                  subtitle:
                      const Text('Hanya saran balasan dan cuplikan chat singkat'),
                  value: s.saveHistory,
                  onChanged: (v) => s.update(() => s.saveHistory = v),
                ),
                const SectionTitle('Tombol Home (asisten digital)'),
                const Text(
                  '1. Tekan tombol di bawah, pilih Date Wingman sebagai Asisten digital.\n'
                      '2. Aktifkan opsi "Gunakan screenshot" di halaman yang sama.\n'
                      '3. Buka chat, lalu tekan lama tombol Home atau gesture asisten.',
                ),
                const SizedBox(height: 8),
                FilledButton.tonalIcon(
                  onPressed: _openAssist,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Buka pengaturan asisten'),
                ),
                const SectionTitle('Privasi'),
                const Text(
                  'Screenshot diproses di memori dan file sementara langsung dihapus setelah selesai, tidak masuk galeri. OCR berjalan di HP; hanya teks chat yang dikirim ke AI (kecuali opsi kirim gambar aktif).',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    s.clearHistory();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Riwayat dihapus')),
                    );
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Hapus semua riwayat'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}