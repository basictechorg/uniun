import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
import 'package:uniun/features/settings/widgets/settings_card.dart';
import 'package:uniun/features/shiv/model_select/cubit/select_ai_model_cubit.dart';
import 'package:uniun/features/shiv/model_select/utils/ai_model_l10n.dart';

class AICard extends StatelessWidget {
  const AICard({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<SelectAIModelCubit>(),
      child: const _AICardContent(),
    );
  }
}

class _AICardContent extends StatelessWidget {
  const _AICardContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<SelectAIModelCubit, SelectAIModelState>(
      builder: (context, state) {
        final activeModelId = state.activeModelId;
        final subtitle = activeModelId != null
            ? activeModelId.displayName(l10n)
            : l10n.aiModelNoneSelected;

        return SettingsRow(
          icon: Icons.memory_rounded,
          label: l10n.settingsDeviceAiModel,
          value: subtitle,
          valueAccent: activeModelId != null,
          onTap: () async {
            await context.pushNamed(AppRoutes.aiModelSelection);
            // Refresh active model state + storage stats after returning.
            if (context.mounted) {
              context.read<SelectAIModelCubit>().refresh();
              context.read<StorageCubit>().loadStats();
            }
          },
        );
      },
    );
  }
}
