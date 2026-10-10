import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';

/// Sign-in field: bold 13px label above the input, grey hint inside, and for
/// passwords an eye toggle separated from the text by a thin divider.
class LabeledAuthField extends StatefulWidget {
  const LabeledAuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.validator,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<LabeledAuthField> createState() => _LabeledAuthFieldState();
}

class _LabeledAuthFieldState extends State<LabeledAuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: widget.label,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: Text(
              widget.label,
              style: t.labelMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: widget.controller,
            validator: widget.validator,
            obscureText: _hidden,
            enabled: widget.enabled,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            style: t.bodyMedium?.copyWith(fontSize: 15),
            decoration: InputDecoration(
              hintText: widget.hint,
              suffixIcon: widget.obscure
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 1,
                          height: 24,
                          color: AppColors.outline,
                        ),
                        IconButton(
                          tooltip: _hidden ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _hidden
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20,
                          ),
                          onPressed: () => setState(() => _hidden = !_hidden),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
