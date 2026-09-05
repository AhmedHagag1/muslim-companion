import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import 'assistant_intent_service.dart';

typedef AssistantCommandExecutor =
    Future<AssistantResponse?> Function(AssistantCommand command);
typedef AssistantCitationExecutor =
    Future<void> Function(AssistantCitation citation);

class AskPage extends StatefulWidget {
  const AskPage({
    super.key,
    required this.onExecute,
    this.onCitationTap,
    this.intentService = const AssistantIntentService(),
  });

  final AssistantCommandExecutor onExecute;
  final AssistantCitationExecutor? onCitationTap;
  final AssistantIntentService intentService;

  @override
  State<AskPage> createState() => _AskPageState();
}

class _AskPageState extends State<AskPage> {
  final _controller = TextEditingController();
  String? _message;
  AssistantResponse? _response;
  bool _unsupported = false;
  bool _busy = false;

  static const _suggestions = [
    'سورة الكهف',
    'آية الكرسي',
    'متى المغرب',
    'افتح القبلة',
    'أذكار الصباح',
    'ورد اليوم',
    'مراجعة الحفظ',
    'تفسير 2:255',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('اسأل')),
    body: ListView(
      key: const ValueKey('ask-page'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        140,
      ),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.large),
            image: const DecorationImage(
              image: ResizeImage(
                AssetImage('assets/design/11_islamic_pattern_dark.webp'),
                width: 900,
              ),
              fit: BoxFit.cover,
              opacity: 0.18,
            ),
            gradient: const LinearGradient(
              colors: [AppColors.surfaceRaised, AppColors.surface],
            ),
            border: Border.all(
              color: AppColors.accentGold.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.accentGold,
                size: 30,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'ماذا تريد؟',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'افتح سورة، أو ابحث عن آية، أو انتقل إلى عبادتك اليومية.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                key: const ValueKey('ask-input'),
                controller: _controller,
                textInputAction: TextInputAction.search,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  hintText: 'مثال: سورة الكهف',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    key: const ValueKey('ask-submit'),
                    tooltip: 'تنفيذ',
                    onPressed: _busy ? null : () => _submit(_controller.text),
                    icon: _busy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_back_rounded),
                  ),
                  filled: true,
                  fillColor: AppColors.appBackground.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            key: ValueKey(_unsupported ? 'ask-unsupported' : 'ask-result'),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _unsupported
                      ? Icons.info_outline_rounded
                      : Icons.check_circle_outline_rounded,
                  color: AppColors.accentGold,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(_message!)),
              ],
            ),
          ),
        ],
        if (_response != null) ...[
          const SizedBox(height: AppSpacing.md),
          PremiumCard(
            key: const ValueKey('ask-grounded-result'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _response!.boundary ? 'حدود المساعدة' : 'نص المصدر',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SelectableText(_response!.sourceText),
                if (_response!.summary != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'ملخص المساعد',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(_response!.summary!),
                ],
                if (_response!.citations.isNotEmpty) ...[
                  const Divider(height: AppSpacing.xl),
                  Text(
                    'المصادر',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final citation in _response!.citations)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_outlined),
                      title: Text(citation.title),
                      subtitle: Text(citation.detail),
                      trailing: citation.actionType == null
                          ? null
                          : const Icon(Icons.arrow_back_rounded),
                      onTap:
                          citation.actionType == null ||
                              widget.onCitationTap == null
                          ? null
                          : () => widget.onCitationTap!(citation),
                    ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader('جرّب أن تقول'),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final suggestion in _suggestions)
              ActionChip(
                key: ValueKey('ask-suggestion-$suggestion'),
                label: Text(suggestion),
                onPressed: () {
                  _controller.text = suggestion;
                  _submit(suggestion);
                },
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        const Text(
          'تصل هذه الأوامر إلى وظائف التطبيق ومصادره المحلية مباشرة.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );

  Future<void> _submit(String value) async {
    if (_busy || value.trim().isEmpty) return;
    final command = widget.intentService.parse(value);
    if (!command.isSupported) {
      setState(() {
        _unsupported = true;
        _response = null;
        _message =
            'لا توجد مصادر محلية كافية للإجابة عن هذا الطلب. جرّب سؤالاً عن آية محددة أو إحدى وظائف التطبيق.';
      });
      return;
    }
    setState(() {
      _busy = true;
      _unsupported = false;
      _message = null;
      _response = null;
    });
    final response = await widget.onExecute(command);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _response = response;
    });
  }
}
