import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/models/tasbeeh.dart';
import 'tasbeeh_controller.dart';

class TasbeehPage extends StatelessWidget {
  const TasbeehPage({super.key, required this.controller});
  final TasbeehController controller;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('السبحة')),
    body: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.error != null || controller.state == null) {
          return AppEmptyState(
            icon: Icons.error_outline,
            title: 'تعذر فتح السبحة',
            message: controller.error ?? 'لا توجد عبارات موثقة متاحة.',
          );
        }
        final state = controller.state!;
        final phrase = controller.selectedPhrase!;
        return ListView(
          key: const ValueKey('tasbeeh-page'),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            DropdownButtonFormField<String>(
              key: const ValueKey('tasbeeh-phrase'),
              initialValue: phrase.id,
              decoration: const InputDecoration(labelText: 'الذكر'),
              items: controller.phrases
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.arabicText),
                    ),
                  )
                  .toList(),
              onChanged: (id) {
                if (id != null) controller.selectPhrase(id);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _targetSelector(context, state),
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              button: true,
              label: 'زيادة عداد السبحة',
              value: '${state.count}',
              child: InkWell(
                key: const ValueKey('tasbeeh-increment'),
                borderRadius: BorderRadius.circular(180),
                onTap: () async {
                  await HapticFeedback.selectionClick();
                  await controller.increment();
                },
                child: SizedBox.square(
                  dimension: 260,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CircularProgressIndicator(
                        value: state.target == null
                            ? 0
                            : (state.count / state.target!).clamp(0.0, 1.0),
                        strokeWidth: 8,
                        backgroundColor: AppColors.surfaceRaised,
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${state.count}',
                            style: Theme.of(context).textTheme.displayLarge,
                          ),
                          Text(
                            state.target == null
                                ? 'بدون هدف'
                                : 'من ${state.target}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              phrase.arabicText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, height: 1.6),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${phrase.sourceText} • ${phrase.reference}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('tasbeeh-decrement'),
                    onPressed: state.count > 0 ? controller.decrement : null,
                    icon: const Icon(Icons.remove_rounded),
                    label: const Text('إنقاص'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('tasbeeh-reset'),
                    onPressed: state.count > 0
                        ? () => _confirmReset(context)
                        : null,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('تصفير'),
                  ),
                ),
              ],
            ),
            if (state.history.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader('السجل الأخير'),
              const SizedBox(height: AppSpacing.sm),
              PremiumCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < state.history.length; i++) ...[
                      _historyTile(state.history[i]),
                      if (i < state.history.length - 1)
                        const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    ),
  );

  Widget _targetSelector(BuildContext context, TasbeehState state) => Wrap(
    alignment: WrapAlignment.center,
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final target in const [33, 34, 100])
        ChoiceChip(
          label: Text('$target'),
          selected: state.target == target,
          onSelected: (_) => controller.setTarget(target),
        ),
      ChoiceChip(
        label: const Text('بدون هدف'),
        selected: state.target == null,
        onSelected: (_) => controller.setTarget(null),
      ),
      ActionChip(
        label: const Text('هدف مخصص'),
        avatar: const Icon(Icons.edit_outlined, size: 18),
        onPressed: () => _customTarget(context),
      ),
    ],
  );

  Widget _historyTile(TasbeehHistoryEntry entry) {
    final phrase = controller.phrases
        .where((item) => item.id == entry.phraseId)
        .firstOrNull;
    return ListTile(
      dense: true,
      title: Text(phrase?.arabicText ?? 'ذكر'),
      subtitle: Text(
        '${entry.completedAt.toLocal().day}/${entry.completedAt.toLocal().month}',
      ),
      trailing: Text('${entry.count}'),
    );
  }

  Future<void> _confirmReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفير العداد؟'),
        content: const Text('سيُحفظ العدد الحالي في السجل الأخير.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تصفير'),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.reset();
  }

  Future<void> _customTarget(BuildContext context) async {
    var input = '';
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('هدف مخصص'),
        content: TextFormField(
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: (value) => input = value,
          decoration: const InputDecoration(hintText: 'أدخل عدداً موجباً'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(input);
              if (value != null && value > 0) Navigator.pop(context, value);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (target != null) await controller.setTarget(target);
  }
}
