import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_logo.dart';

/// Shared white page used by sign-in, sign-up, forgot-password and
/// verify-email: back arrow, centred dark brand logo, bold 18 heading, grey 13
/// subtitle, content, and an optional footer pinned to the bottom (or just
/// below the content on short screens).
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.footer,
    this.showBack = true,
    this.centered = true,
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
                        const Center(child: BrandLogo(size: 34)),
                        const SizedBox(height: 14),
                        Column(
                          crossAxisAlignment: align,
                          children: [
                            Text(
                              title,
                              style: t.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: centered
                                  ? TextAlign.center
                                  : TextAlign.start,
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                subtitle!,
                                textAlign: centered
                                    ? TextAlign.center
                                    : TextAlign.start,
                                style: t.textTheme.bodySmall?.copyWith(
                                  fontSize: 13,
                                  color: AppColors.inkMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 22),
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

/// "Prompt  Action" row with a bold navy link, e.g. "Don't have an
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
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal rule with a centred "or".
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(child: Divider(color: AppColors.outline)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text(
          'or',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
        ),
      ),
      const Expanded(child: Divider(color: AppColors.outline)),
    ],
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
