import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';

/// Shared white page used by login, sign-up, forgot-password and
/// verify-email: back arrow, 24/700 heading, grey subtitle, content, and an
/// optional footer pinned to the bottom (or just below the content on short
/// screens).
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.footer,
    this.showBack = true,
    this.centered = false,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? footer;
  final bool showBack;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final canBack = showBack && Navigator.of(context).canPop();
    final align = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: canBack
                                ? IconButton(
                                    tooltip: 'Back',
                                    padding: EdgeInsets.zero,
                                    alignment: Alignment.centerLeft,
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 20,
                                    ),
                                    onPressed: () => context.pop(),
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: align,
                          children: [
                            Text(
                              title,
                              style: t.textTheme.headlineMedium,
                              textAlign: centered
                                  ? TextAlign.center
                                  : TextAlign.start,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                subtitle!,
                                textAlign: centered
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: t.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 28),
                        ...children,
                        if (footer != null) ...[
                          const Spacer(),
                          const SizedBox(height: 16),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Prompt  Action" row with a bold indigo link, e.g. "Don't have an
/// account? Sign Up".
class AuthSwitchRow extends StatelessWidget {
  const AuthSwitchRow({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            prompt,
            style: t.textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          onPressed: onPressed,
          child: Text(
            action,
            style: t.textTheme.bodyMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Centered grey "Or continue with" caption as in the design.
class OrContinueWith extends StatelessWidget {
  const OrContinueWith({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Text(
      'Or continue with',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
    ),
  );
}

/// Inline error shown above the primary button.
class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}
