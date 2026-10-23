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
  }

  @override
  void dispose() {
    _gKey.dispose();
    _gModel.dispose();
    _cKey.dispose();
    _cModel.dispose();
    _about.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label,
    ValueChanged<String> onChanged, {
    bool secret = false,
    int lines = 1,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        obscureText: secret,
        enableSuggestions: !secret,
        autocorrect: !secret,
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
                  _field(_gKey, 'API key Gemini',
                      (v) => s.update(() => s.geminiKey = v.trim()),
                      secret: true),
                  _field(_gModel, 'Model Gemini',
                      (v) => s.update(() => s.geminiModel = v.trim())),
                ] else ...[
                  _field(_cKey, 'API key Claude',
                      (v) => s.update(() => s.claudeKey = v.trim()),
                      secret: true),
                  _field(_cModel, 'Model Claude',
                      (v) => s.update(() => s.claudeModel = v.trim())),
                ],
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