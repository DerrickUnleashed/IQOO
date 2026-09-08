import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// A tactile preference card. Every selection has a checkmark as well as the
/// color treatment, so the attractive treatment stays accessible.
class PreferenceGroup<T> extends StatelessWidget {
  const PreferenceGroup({super.key, required this.title, required this.description, required this.values, required this.selected, required this.labelOf, required this.onChanged});
  final String title, description;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

  IconData get _icon => switch (title) {
    'Movement' => Icons.directions_walk_rounded,
    'Sight' => Icons.visibility_outlined,
    'Hearing' => Icons.hearing_rounded,
    'Guidance style' => Icons.map_outlined,
    _ => Icons.tune_rounded,
  };

  Color get _accent => switch (title) {
    'Sight' => AppColors.accent,
    'Hearing' => AppColors.rose,
    'Guidance style' => AppColors.gold,
    _ => AppColors.primaryDark,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    label: title,
    child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .055),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: .12)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: _accent.withValues(alpha: .15)), child: Icon(_icon, color: _accent, size: 20)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: Theme.of(context).textTheme.titleMedium), if (description.isNotEmpty) Text(description, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))])),
        ]),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [for (final value in values) _SelectableChip<T>(value: value, label: labelOf(value), selected: value == selected, onSelected: (_) => onChanged(value))]),
      ]),
    ),
  );
}

class _SelectableChip<T> extends StatelessWidget {
  const _SelectableChip({required this.value, required this.label, required this.selected, required this.onSelected});
  final T value; final String label; final bool selected; final ValueChanged<bool> onSelected;
  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label), selected: selected, onSelected: onSelected, showCheckmark: true,
    selectedColor: AppColors.primary.withValues(alpha: .36), checkmarkColor: Colors.white,
    labelStyle: TextStyle(color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface),
    side: BorderSide(color: selected ? AppColors.primaryDark : Colors.white.withValues(alpha: .18)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}
