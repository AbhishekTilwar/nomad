import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design field: optional bold label ABOVE the input, grey hint inside,
/// optional leading icon. Passwords get a visibility toggle.
///
/// [showLabel] false renders hint-only (login / sign-up screens) while keeping
/// [label] as the accessible name.
class AppFormField extends StatefulWidget {
  const AppFormField({
    super.key,
    required this.label,
    this.controller,
    this.validator,
    this.hint,
    this.helper,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLines = 1,
    this.maxLength,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.enabled = true,
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.readOnly = false,
    this.onTap,
    this.showLabel = true,
    this.initialValue,
  });

  /// Used only when no [controller] is supplied (read-only display fields).
  final String? initialValue;
  final String label;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final String? hint;
  final String? helper;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int maxLines;
  final int? maxLength;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool readOnly;
  final VoidCallback? onTap;
  final bool showLabel;

  @override
  State<AppFormField> createState() => _AppFormFieldState();
}

class _AppFormFieldState extends State<AppFormField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final field = TextFormField(
      key: widget.controller == null ? ValueKey(widget.initialValue) : null,
      controller: widget.controller,
      initialValue: widget.controller == null ? widget.initialValue : null,
      validator: widget.validator,
      obscureText: _hidden,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      onTap: widget.onTap,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      maxLines: widget.obscure ? 1 : widget.maxLines,
      maxLength: widget.maxLength,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onSubmitted,
      inputFormatters: widget.inputFormatters,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: t.textTheme.bodyMedium?.copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: widget.hint ?? (widget.showLabel ? null : widget.label),
        helperText: widget.helper,
        helperMaxLines: 3,
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, size: 20),
        suffixIcon: widget.obscure
            ? IconButton(
                tooltip: _hidden ? 'Show password' : 'Hide password',
                icon: Icon(
                  _hidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              )
            : widget.suffixIcon,
      ),
    );
    return Semantics(
      label: widget.label,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.showLabel) ...[
            ExcludeSemantics(
              child: Text(
                widget.label,
                style: t.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          field,
        ],
      ),
    );
  }
}

/// Dropdown styled like [AppFormField] (label above, hint inside).
class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hint,
    this.prefixIcon,
    this.showLabel = true,
    this.validator,
  });

  final String label;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final T? value;
  final ValueChanged<T?> onChanged;
  final IconData? prefixIcon;
  final bool showLabel;
  final String? Function(T?)? validator;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Semantics(
      label: label,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            ExcludeSemantics(
              child: Text(
                label,
                style: t.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
          DropdownButtonFormField<T>(
            initialValue: value,
            items: items,
            onChanged: onChanged,
            validator: validator,
            isExpanded: true,
            style: t.textTheme.bodyMedium?.copyWith(fontSize: 15),
            icon: const Icon(Icons.keyboard_arrow_down),
            decoration: InputDecoration(
              hintText: hint ?? (showLabel ? null : label),
              prefixIcon: prefixIcon == null
                  ? null
                  : Icon(prefixIcon, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
