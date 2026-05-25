import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/l10n/app_localizations.dart';
import 'package:uniun/features/settings/cubit/storage_cubit.dart';
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

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: // Model selector row
              GestureDetector(
                onTap: () async {
                  await Navigator.of(context)
                      .pushNamed(AppRoutes.aiModelSelection);
                  // Refresh active model state + storage stats after returning.
                  if (context.mounted) {
                    context.read<SelectAIModelCubit>().refresh();
                    context.read<StorageCubit>().loadStats();
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.aiSelectModel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: activeModelId != null
                                  ? AppColors.primary
                                  : AppColors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.onSurfaceVariant),
                  ],
                ),
              ),
        );
      },
    );
  }
}
