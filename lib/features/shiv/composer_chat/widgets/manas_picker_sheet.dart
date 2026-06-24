import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/features/brahma/utils/manas_icons.dart';

/// The "All notes" scope icon — same as the Brahma drawer's whole-library entry.
const IconData kAllNotesIcon = Icons.hub_rounded;

/// The scope the composer-chat reasons over: a specific Manas, or the whole
/// library (`manasIds` empty). [icon] is the resolved icon to show in the
/// composer avatar while chatting in this scope.
class ManasChatScope {
  const ManasChatScope({
    required this.manasIds,
    required this.icon,
    this.name,
  });

  final List<String> manasIds;
  final String? name;
  final IconData icon;
}

/// Long-press the composer avatar → pick which Manas the inline chat should be
/// grounded in. Returns null if dismissed. Reuses [GetManasListUseCase].
Future<ManasChatScope?> showManasChatPicker(BuildContext context) {
  return showModalBottomSheet<ManasChatScope>(
    context: context,
    backgroundColor: AppColors.surfaceContainerLow,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ManasPickerSheet(),
  );
}

class _ManasPickerSheet extends StatelessWidget {
  const _ManasPickerSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Text(
                'Select your manas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            _ScopeTile(
              icon: kAllNotesIcon,
              title: 'All notes',
              subtitle: 'Your whole library',
              onTap: () => Navigator.pop(
                context,
                const ManasChatScope(manasIds: [], icon: kAllNotesIcon),
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceContainerHigh),
            Flexible(
              child: FutureBuilder(
                future: getIt<GetManasListUseCase>().call(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: DropLoadingIndicator(size: 22),
                        ),
                      ),
                    );
                  }
                  final list = snapshot.data!.fold(
                    (_) => <ManasEntity>[],
                    (l) => l,
                  );
                  if (list.isEmpty) return const SizedBox.shrink();
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final icon = ManasIcons.byName(m.iconName);
                      return _ScopeTile(
                        icon: icon,
                        title: m.name,
                        subtitle: '${m.noteCount} notes',
                        onTap: () => Navigator.pop(
                          context,
                          ManasChatScope(
                            manasIds: [m.manasId],
                            name: m.name,
                            icon: icon,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScopeTile extends StatelessWidget {
  const _ScopeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.onSurface,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      onTap: onTap,
    );
  }
}
