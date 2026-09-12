import 'package:flutter/material.dart';

import '../theme/homi_theme.dart';

Future<void> showHomiInfoSheet(
  BuildContext context, {
  required String title,
  required String message,
  String actionLabel = 'Got it',
  IconData icon = Icons.info_outline_rounded,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: HomiColors.peach.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: HomiColors.coral),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> showHomiConfirmSheet(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  IconData icon = Icons.help_outline_rounded,
  bool destructive = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: HomiColors.peach.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icon,
                    color: destructive
                        ? Theme.of(context).colorScheme.error
                        : HomiColors.coral,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: destructive
                        ? FilledButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.error,
                            foregroundColor: Theme.of(context).colorScheme.onError,
                          )
                        : null,
                    onPressed: () => Navigator.pop(sheetContext, true),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result == true;
}

class HomiChoiceGroup<T> extends StatelessWidget {
  const HomiChoiceGroup({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onSelected,
    this.enabledFor,
    this.compact = false,
    super.key,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelFor;
  final ValueChanged<T> onSelected;
  final bool Function(T value)? enabledFor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final active = value == selected;
        final enabled = enabledFor?.call(value) ?? true;
        return Opacity(
          opacity: enabled ? 1 : 0.48,
          child: Semantics(
            selected: active,
            button: true,
            label: labelFor(value),
            child: GestureDetector(
              onTap: enabled ? () => onSelected(value) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 14,
                  vertical: compact ? 8 : 10,
                ),
                decoration: BoxDecoration(
                  color: active
                      ? HomiColors.coral
                      : HomiColors.peach.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: active ? HomiColors.coral : HomiColors.border,
                  ),
                ),
                child: Text(
                  labelFor(value),
                  style: TextStyle(
                    fontSize: compact ? 12 : 13,
                    fontWeight: FontWeight.w900,
                    color: active ? Colors.white : HomiColors.slate,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}

class HomiMultiChoiceGroup<T> extends StatelessWidget {
  const HomiMultiChoiceGroup({
    required this.values,
    required this.selected,
    required this.labelFor,
    required this.onChanged,
    super.key,
  });

  final List<T> values;
  final Set<T> selected;
  final String Function(T value) labelFor;
  final ValueChanged<Set<T>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((value) {
        final active = selected.contains(value);
        return GestureDetector(
          onTap: () {
            final next = Set<T>.of(selected);
            active ? next.remove(value) : next.add(value);
            onChanged(next);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: active
                  ? HomiColors.sage.withValues(alpha: 0.34)
                  : Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? HomiColors.sage : HomiColors.border,
              ),
            ),
            child: Text(
              labelFor(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: active ? HomiColors.slate : HomiColors.muted,
              ),
            ),
          ),
        );
      }).toList(growable: false),
    );
  }
}
