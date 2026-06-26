import 'package:flutter/material.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';

/// Minimal onboarding top bar — just a back arrow on the left. The centered
/// UNIUN logo/wordmark header was removed; back navigation is preserved and the
/// freed space lets the onboarding content sit higher.
class OnboardingAppBar extends StatelessWidget {
  const OnboardingAppBar({super.key, required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: UniunBackButton(onPressed: onBack),
      ),
    );
  }
}
