import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/app_tokens.dart';
import '../../app/widgets/app_components.dart';
import '../../data/services/user_data_backup_service.dart';

class BackupPage extends StatefulWidget {
  const BackupPage({super.key, this.service = const UserDataBackupService()});
  final UserDataBackupService service;

  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('النسخ الاحتياطي')),
    body: ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const PremiumCard(
          child: Text(
            'احفظ بياناتك الشخصية في ملف محلي. لا تتضمن النسخة نص القرآن أو التفسير أو الترجمات.',
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton.icon(
          key: const ValueKey('backup-export'),
          onPressed: _busy ? null : _export,
          icon: const Icon(Icons.ios_share_rounded),
          label: const Text('تصدير نسخة'),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton.icon(
          key: const ValueKey('backup-import'),
          onPressed: _busy ? null : _import,
          icon: const Icon(Icons.file_open_outlined),
          label: const Text('استيراد نسخة'),
        ),
        const SizedBox(height: AppSpacing.md),
        const Text(
          'يشمل الملف المحفوظات، تقدم القراءة، تفضيلات المصحف، الحفظ، الختمة، المفضلة، السبحة، وجداول التنبيه الآمنة. الاستيراد لا يتم قبل عرض المحتوى وتأكيدك.',
        ),
        if (_busy) ...[
          const SizedBox(height: AppSpacing.lg),
          const Center(child: CircularProgressIndicator()),
        ],
      ],
    ),
  );

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = await widget.service.exportJson();
      final date = DateTime.now().toIso8601String().substring(0, 10);
      await SharePlus.instance.share(
        ShareParams(
          title: 'نسخة احتياطية لرفيق المسلم',
          subject: 'نسخة احتياطية محلية',
          text: 'نسخة من بيانات التطبيق الشخصية فقط.',
          files: [
            XFile.fromData(utf8.encode(json), mimeType: 'application/json'),
          ],
          fileNameOverrides: ['muslim-companion-backup-$date.json'],
        ),
      );
    } catch (_) {
      if (mounted) _message('تعذر إنشاء النسخة الآن.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > UserDataBackupService.maxImportBytes) {
        throw const BackupFormatException(
          'ملف النسخة الاحتياطية أكبر من الحد المسموح.',
        );
      }
      final preview = widget.service.preview(utf8.decode(bytes));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('استعادة هذه النسخة؟'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أنشئت في ${preview.createdAt.toLocal().toString().substring(0, 16)}',
                ),
                const SizedBox(height: 8),
                ...preview.sections.entries.map(
                  (entry) => Text('${entry.key}: ${entry.value}'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ستُستبدل الأقسام الظاهرة فقط. لن تتغير بيانات أخرى.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              key: const ValueKey('backup-confirm-replace'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.service.replaceFromPreview(preview, confirmed: true);
      if (mounted) {
        _message('تمت الاستعادة. أعد فتح التطبيق لتحميل كل البيانات.');
      }
    } on BackupFormatException catch (error) {
      if (mounted) _message(error.message);
    } catch (_) {
      if (mounted) _message('تعذر استيراد هذا الملف.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
