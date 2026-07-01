import 'package:flutter/material.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Terms & Privacy acceptance checkbox shown on signup (your_identity_keys)
/// and login (import_identity). Apple Guideline 1.2 requires the user to
/// agree before registering OR logging in — both flows wire the Continue
/// button to its `accepted` state.
class TermsCheckbox extends StatelessWidget {
  const TermsCheckbox({
    super.key,
    required this.accepted,
    required this.onChanged,
    required this.onOpenTerms,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenTerms;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final linkStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: accepted,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: Theme.of(context).colorScheme.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                l10n.keysAgreePrefix,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              GestureDetector(
                onTap: onOpenTerms,
                child: Text(l10n.keysAgreeTerms, style: linkStyle),
              ),
              Text(
                l10n.keysAgreeConjunction,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              GestureDetector(
                onTap: onOpenPrivacy,
                child: Text(l10n.keysAgreePrivacy, style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
