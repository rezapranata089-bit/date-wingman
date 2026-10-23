import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'settings_store.dart';

class HistoryScreen extends StatelessWidget {
  final AppSettings settings;
  const HistoryScreen({super.key, required this.settings});

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) settings.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final items = settings.history;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Riwayat'),
            actions: [
              if (items.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context),
                ),
            ],
          ),
          body: items.isEmpty
              ? const Center(child: Text('Belum ada riwayat.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final it = items[i];
                    final t = it.time.length >= 16
                        ? it.time.substring(0, 16).replaceFirst('T', ' ')
                        : it.time;
                    return Card(
                      child: ExpansionTile(
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text('${it.tone}  •  $t'),
                        subtitle: Text(it.preview,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        children: [
                          ...it.replies.map((r) => ListTile(
                                title: Text(r),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy, size: 18),
                                  onPressed: () async {
                                    await Clipboard.setData(
                                        ClipboardData(text: r));
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Disalin'),
                                        duration: Duration(seconds: 1),
                                      ),
                                    );
                                  },
                                ),
                              )),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => settings.removeHistoryAt(i),
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Hapus'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}