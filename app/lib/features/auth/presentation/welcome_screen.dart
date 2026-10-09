import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/brand_logo.dart';

/// Splash-style landing: brand, tagline, and the two entry actions.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const onGradient = Colors.white;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3B2FB8), Color(0xFF5B4FE0), Color(0xFFE9876B)],
            stops: [0, 0.6, 1],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: AppSpacing.page,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 40),
                    const Center(
                      child: BrandLogo(
                        size: 84,
                        showWordmark: false,
                        onDark: true,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Nomad Mingle',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: onGradient, fontSize: 34),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Find your people.\nMake a plan. Go together.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: onGradient.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 64),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                      ),
                      onPressed: () => context.push('/register'),
                      child: const Text('Get Started'),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white, width: 1.5),
                      ),
                      onPressed: () => context.push('/sign-in'),
                      child: const Text('I already have an account'),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'For adults 18+. By continuing you agree to our Terms of Service and Community Guidelines.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: onGradient.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
