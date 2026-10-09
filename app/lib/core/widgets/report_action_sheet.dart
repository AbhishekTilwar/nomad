import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';
import 'primary_button.dart';

enum ReportReason {
  spam('Spam or advertising'),
  harassment('Harassment or bullying'),
  unsafe('Unsafe or threatening'),
  inappropriate('Inappropriate content'),
  other('Something else');

  const ReportReason(this.label);
  final String label;
}

class ReportResult {
  const ReportResult(this.reason, this.details);
  final ReportReason reason;
  final String details;
}

/// Bottom sheet collecting a report reason. Returns null if dismissed.
class ReportActionSheet extends StatefulWidget {
  const ReportActionSheet({super.key, required this.title});
  final String title;

  static Future<ReportResult?> show(
    BuildContext context, {
    required String title,
  }) => showModalBottomSheet<ReportResult>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => ReportActionSheet(title: title),
  );

  @override
  State<ReportActionSheet> createState() => _ReportActionSheetState();
}

class _ReportActionSheetState extends State<ReportActionSheet> {
  ReportReason? _reason;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: t.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Reports are reviewed by our moderators. The person you report isn\'t told who reported them.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label),
                      value: r,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Submit report',
              onPressed: _reason == null
                  ? null
                  : () => Navigator.of(
                      context,
                    ).pop(ReportResult(_reason!, _details.text.trim())),
            ),
          ],
        ),
      ),
    );
  }
}
