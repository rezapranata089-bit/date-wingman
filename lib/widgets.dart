import 'package:flutter/material.dart';

import 'settings_store.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class Spark extends StatelessWidget {
  final List<int> v;
  const Spark(this.v, {super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final d = v.length > 20 ? v.sublist(v.length - 20) : v;
    return SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: d
            .map((x) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Container(
                      height: 4 + 36 * (x.clamp(0, 100) / 100),
                      decoration: BoxDecoration(
                        color: x < 35 ? cs.error : cs.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class OptChips extends StatelessWidget {
  final List<Opt> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const OptChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options
          .map((o) => ChoiceChip(
                label: Text(o.label),
                selected: o.id == selected,
                onSelected: (_) => onSelected(o.id),
              ))
          .toList(),
    );
  }
}