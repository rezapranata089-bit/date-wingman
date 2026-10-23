import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'ai_service.dart';
import 'ocr_service.dart';
import 'settings_store.dart';
import 'widgets.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onCaptured;
  final VoidCallback onGoSettings;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.onCaptured,
    required this.onGoSettings,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const MethodChannel _ch = MethodChannel('date/native');

  final TextEditingController _chatCtl = TextEditingController();
  final TextEditingController _extraCtl = TextEditingController();
  String? _imagePath;
  bool _busy = false;
  String _status = '';
  String? _error;
  AiResult? _result;
  final Set<int> _picked = {};

  static const List<List<String>> _refines = [
    ['Lebih singkat', 'buat lebih singkat dan padat'],
    ['Lebih lucu', 'buat lebih lucu dan witty'],
    ['Lebih berani', 'buat lebih berani dan percaya diri, tetap respect'],
    ['Lebih sopan', 'buat lebih sopan dan rapi'],
    ['Lebih santai', 'buat lebih santai seperti ngobrol dengan teman'],
    ['Opsi baru', 'buat 3 opsi yang benar-benar berbeda dari sebelumnya'],
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'onCapture') {
        await _onCapture(call.arguments as String?);
      }
      return null;
    });
    _checkPending();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ch.setMethodCallHandler(null);
    _chatCtl.dispose();
    _extraCtl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPending();
  }

  Future<void> _checkPending() async {
    try {
      final p = await _ch.invokeMethod<String>('getPendingCapture');
      if (p != null) {
        await _onCapture(p);
      } else if (_imagePath == null && !_busy) {
        await _ch.invokeMethod('clearCaptures');
      }
    } catch (_) {}
  }

  Future<void> _discardImage() async {
    final p = _imagePath;
    _imagePath = null;
    if (p != null) {
      try {
        final f = File(p);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  Future<void> _onCapture(String? path) async {
    if (path == null) return;
    widget.onCaptured();
    if (path == 'ERROR') {
      if (!mounted) return;
      setState(() {
        _error =
            'Screenshot tidak tersedia. Aplikasi mungkin memblokir screenshot, atau opsi "Gunakan screenshot" di pengaturan asisten belum aktif. Coba tempel teks chat manual.';
      });
      return;
    }
    if (!File(path).existsSync()) return;
    if (_imagePath != null && _imagePath != path) await _discardImage();
    if (!mounted) return;
    setState(() {
      _imagePath = path;
      _busy = true;
      _status = 'Membaca layar...';
      _error = null;
      _result = null;
    });
    try {
      final text = await OcrService.read(path);
      if (!mounted) return;
      _chatCtl.text = text;
      final s = widget.settings;
      setState(() => _busy = false);
      if (s.autoGenerate && s.activeKey.isNotEmpty) {
        await _generate();
      } else if (text.trim().isEmpty) {
        setState(() => _error =
            'Teks chat tidak terbaca. Tempel manual, atau isi API key agar AI bisa membaca gambarnya.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Gagal membaca gambar: $e';
      });
    }
  }

  Future<void> _generate(
      {String instruction = '', bool keepAvoid = true}) async {
    final s = widget.settings;
    final chat = _chatCtl.text.trim();
    final extra = _extraCtl.text.trim();
    if (s.activeKey.isEmpty) {
      setState(() => _error = 'Isi API key dulu di tab Pengaturan.');
      return;
    }
    if (chat.isEmpty && extra.isEmpty && _imagePath == null) {
      setState(() => _error = 'Tempel chat atau ambil screenshot dulu ya.');
      return;
    }
    setState(() {
      _busy = true;
      _status = 'AI lagi mikir...';
      _error = null;
    });
    try {
      final useImage = _imagePath != null && (s.useVision || chat.isEmpty);
      final res = await AiService.suggest(
        s: s,
        chat: chat,
        extra: extra,
        instruction: instruction,
        avoid: keepAvoid
            ? (_result?.replies.map((e) => e.text).toList() ??
                const <String>[])
            : const <String>[],
        imagePath: useImage ? _imagePath : null,
        contact: s.memoryContact,
      );
      if (!mounted) return;
      final mc = s.memoryContact;
      if (mc != null) s.updateContact(mc, chat: chat, memory: res.memory);
      setState(() {
        _result = res;
        _picked.clear();
      });
      if (s.saveHistory) {
        final prev = chat.length > 160 ? chat.substring(chat.length - 160) : chat;
        s.addHistory(HistoryItem(
          time: DateTime.now().toIso8601String(),
          tone: optLabel(kTones, s.toneId),
          preview: prev.isEmpty ? '(tanpa chat)' : prev,
          replies: res.replies.map((e) => e.text).toList(),
        ));
      }
      await _discardImage();
    } on AiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (x != null) await _onCapture(x.path);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membuka galeri: $e');
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final t = d?.text;
    if (t != null && t.isNotEmpty) {
      setState(() => _chatCtl.text = t);
    }
  }

  void _swap() {
    final t = _chatCtl.text.split('\n').map((l) {
      if (l.startsWith('Dia: ')) return 'Aku: ${l.substring(5)}';
      if (l.startsWith('Aku: ')) return 'Dia: ${l.substring(5)}';
      return l;
    }).join('\n');
    setState(() => _chatCtl.text = t);
  }

  Future<void> _clear() async {
    await _discardImage();
    if (!mounted) return;
    setState(() {
      _chatCtl.clear();
      _extraCtl.clear();
      _result = null;
      _error = null;
    });
  }

  Future<void> _copy(String t) async {
    await Clipboard.setData(ClipboardData(text: t));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disalin'), duration: Duration(seconds: 1)),
    );
  }

  Future<void> _openAssist() async {
    try {
      await _ch.invokeMethod('openAssistSettings');
    } catch (_) {}
  }

  Future<void> _contactDialog({Contact? edit}) async {
    final nameCtl = TextEditingController(text: edit?.name ?? '');
    final notesCtl = TextEditingController(text: edit?.notes ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(edit == null ? 'Lawan bicara baru' : 'Edit lawan bicara'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nama',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtl,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                hintText: 'Kenalan di Bumble, suka kucing',
                border: OutlineInputBorder(),
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
    final name = nameCtl.text.trim();
    final notes = notesCtl.text.trim();
    if (ok != true || name.isEmpty) return;
    final s = widget.settings;
    if (edit == null) {
      s.addContact(name, notes);
    } else {
      s.update(() {
        edit.name = name;
        edit.notes = notes;
      });
    }
  }

  Widget _contactCard(Contact c, AppSettings s) {
    final info = '${c.log.length} pesan tersimpan'
        '${s.useMemory ? '' : ' (memori nonaktif)'}';
    return Card(
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        leading: const Icon(Icons.psychology_outlined),
        title: Text('Memori ${c.name}'),
        subtitle: Text(info),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(c.memory.isEmpty
              ? 'Belum ada ringkasan. Terisi otomatis setelah balasan dibuat.'
              : c.memory),
          if (c.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Catatan: ${c.notes}'),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: () => _contactDialog(edit: c),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
              OutlinedButton.icon(
                onPressed: () => s.update(() {
                  c.memory = '';
                  c.log.clear();
                }),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset memori'),
              ),
              OutlinedButton.icon(
                onPressed: () => s.removeContact(c.id),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Hapus'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.settings;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Date Wingman')),
          body: SafeArea(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                if (s.activeKey.isEmpty)
                  Card(
                    color: cs.errorContainer,
                    child: ListTile(
                      leading: const Icon(Icons.key),
                      title: const Text('API key belum diisi'),
                      subtitle: const Text('Isi dulu agar AI bisa membuat balasan.'),
                      trailing: TextButton(
                        onPressed: widget.onGoSettings,
                        child: const Text('Isi'),
                      ),
                    ),
                  ),
                if (!s.hideTip)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.touch_app_outlined),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                    'Tekan lama tombol Home (atau gesture asisten) saat buka chat. Wingman otomatis membaca layar dan memberi saran balasan.'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => s.update(() => s.hideTip = true),
                                child: const Text('Tutup'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.tonal(
                                onPressed: _openAssist,
                                child: const Text('Aktifkan'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SectionTitle('Lawan bicara'),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('Tanpa memori'),
                      selected: s.activeContact == null,
                      onSelected: (_) =>
                          s.update(() => s.activeContactId = null),
                    ),
                    ...s.contacts.map((c) => ChoiceChip(
                          label: Text(c.name),
                          selected: c.id == s.activeContactId,
                          onSelected: (_) =>
                              s.update(() => s.activeContactId = c.id),
                        )),
                    ActionChip(
                      avatar: const Icon(Icons.person_add_alt, size: 18),
                      label: const Text('Baru'),
                      onPressed: () => _contactDialog(),
                    ),
                  ],
                ),
                if (s.activeContact != null)
                  _contactCard(s.activeContact!, s),
                const SectionTitle('Nada balasan'),
                OptChips(
                  options: kTones,
                  selected: s.toneId,
                  onSelected: (id) => s.update(() => s.toneId = id),
                ),
                ExpansionTile(
                  title: const Text('Tujuan dan situasi'),
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tujuan'),
                    const SizedBox(height: 6),
                    OptChips(
                      options: kGoals,
                      selected: s.goal,
                      onSelected: (id) => s.update(() => s.goal = id),
                    ),
                    const SizedBox(height: 12),
                    const Text('Tahap hubungan'),
                    const SizedBox(height: 6),
                    OptChips(
                      options: kStages,
                      selected: s.stage,
                      onSelected: (id) => s.update(() => s.stage = id),
                    ),
                    const SizedBox(height: 12),
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
                  ],
                ),
                const SectionTitle('Chat'),
                TextField(
                  controller: _chatCtl,
                  minLines: 4,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText:
                        'Tempel chat di sini atau ambil dari screenshot.\nFormat: "Dia: ..." dan "Aku: ..."',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _paste,
                      icon: const Icon(Icons.content_paste, size: 18),
                      label: const Text('Tempel'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Screenshot'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _swap,
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Tukar Aku/Dia'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _clear,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Hapus'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _extraCtl,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Konteks tambahan (opsional)',
                    hintText: 'Misal: dia suka kucing, kenalan di Bumble',
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _generate(),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(_busy
                      ? _status
                      : (_result == null ? 'Buatkan Balasan' : 'Buat Ulang')),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!, style: TextStyle(color: cs.error)),
                  ),
                if (_result != null) ..._resultWidgets(context),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _mix() async {
    final r = _result;
    if (r == null || _picked.length < 2) return;
    final idx = _picked.toList()..sort();
    final b = StringBuffer(
        'Gabungkan balasan-balasan berikut menjadi 3 versi baru yang lebih bagus. Ambil kelebihan masing-masing (ide, humor, kehangatan, pertanyaan balik) lalu tulis ulang agar mengalir natural seperti satu pesan utuh, bukan sekadar disambung. Jangan lebih panjang dari yang perlu. Balasan sumber:\n');
    var n = 1;
    for (final i in idx) {
      if (i < r.replies.length) {
        b.writeln('$n) ${r.replies[i].text}');
        n++;
      }
    }
    await _generate(instruction: b.toString(), keepAvoid: false);
  }

  List<Widget> _resultWidgets(BuildContext context) {
    final r = _result!;
    final cs = Theme.of(context).colorScheme;
    final note = [r.analysis, r.tip].where((e) => e.isNotEmpty).join('\n\n');
    return [
      const SectionTitle('Saran balasan'),
      if (note.isNotEmpty)
        Card(
          color: cs.secondaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.psychology_alt_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(note)),
              ],
            ),
          ),
        ),
      ...r.replies.asMap().entries.map((en) {
        final e = en.value;
        final i = en.key;
        final on = _picked.contains(i);
        return Card(
          color: on ? cs.primaryContainer : null,
          child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.style.isNotEmpty)
                    Text(
                      e.style,
                      style: TextStyle(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  const SizedBox(height: 4),
                  SelectableText(e.text, style: const TextStyle(fontSize: 16)),
                  Row(
                    children: [
                      FilterChip(
                        avatar: Icon(
                            on
                                ? Icons.check_circle
                                : Icons.add_circle_outline,
                            size: 18),
                        label: const Text('Gabung'),
                        selected: on,
                        onSelected: _busy
                            ? null
                            : (v) => setState(() {
                                  if (v) {
                                    _picked.add(i);
                                  } else {
                                    _picked.remove(i);
                                  }
                                }),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _copy(e.text),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Salin'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        );
      }),
      if (_picked.length >= 2)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: FilledButton.icon(
            onPressed: _busy ? null : _mix,
            icon: const Icon(Icons.merge_type),
            label: Text('Gabungkan ${_picked.length} pilihan'),
          ),
        )
      else
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Tips: tandai "Gabung" di 2 balasan atau lebih, lalu gabungkan jadi versi yang lebih bagus.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      const SectionTitle('Ubah hasil'),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: _refines
            .map((x) => ActionChip(
                  label: Text(x[0]),
                  onPressed: _busy ? null : () => _generate(instruction: x[1]),
                ))
            .toList(),
      ),
    ];
  }
}