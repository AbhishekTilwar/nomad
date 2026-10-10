import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_tokens.dart';

/// Gradient "@handle" pill that opens the member's Instagram.
class InstagramPill extends StatelessWidget {
  const InstagramPill({super.key, required this.handle, required this.onTap});
  final String handle;
  final VoidCallback onTap;

  // A plain Container paints its gradient in place. (Ink paints on the nearest
  // Material, which sits *behind* opaque panels like the profile sheet, so the
  // gradient vanished and left white text on white.)
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Instagram @$handle',
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        gradient: const LinearGradient(
          colors: [Color(0xFF833AB4), Color(0xFFFD1D1D), Color(0xFFFCB045)],
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.camera_alt_outlined,
                  size: 18,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Text(
                  '@$handle',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

/// Opens instagram.com/[handle] in the browser or the Instagram app.
Future<void> openInstagram(String handle) => launchUrl(
  Uri.parse('https://instagram.com/$handle'),
  mode: LaunchMode.externalApplication,
);
