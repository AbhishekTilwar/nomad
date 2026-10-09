import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/form_field.dart';

/// Read-only "Date of birth" field that opens a date picker and enforces 18+.
class DobFormField extends StatefulWidget {
  const DobFormField({super.key, required this.onChanged});

  final ValueChanged<DateTime> onChanged;

  @override
  State<DobFormField> createState() => _DobFormFieldState();
}

class _DobFormFieldState extends State<DobFormField> {
  final _text = TextEditingController();
  DateTime? _dob;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Date of birth',
    );
    if (picked == null) return;
    _dob = picked;
    _text.text = DateFormat.yMMMMd().format(picked);
    widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) => AppFormField(
    label: 'Date of birth',
    showLabel: false,
    controller: _text,
    readOnly: true,
    onTap: _pick,
    prefixIcon: Icons.calendar_today_outlined,
    validator: (_) => Validators.dateOfBirth(_dob),
  );
}
