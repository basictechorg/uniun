import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/features/shiv/model_select/utils/ai_model_l10n.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Drawer section for the Nataraj deck. Shows the active on-device AI model
/// and opens model selection on tap. Rendered as [ShivHistoryDrawer.topSection]
/// on the deck, so model selection lives in the same drawer as Gana selection.
class NatarajModelDrawerSection extends StatefulWidget {
  const NatarajModelDrawerSection({super.key});

  @override
  State<NatarajModelDrawerSection> createState() =>
      _NatarajModelDrawerSectionState();
}

class _NatarajModelDrawerSectionState extends State<NatarajModelDrawerSection> {
  // Resolved once — a drawer is short-lived, so a single read is enough.
  late final Future<Either<Failure, AIModelEntity?>> _modelFuture =
      getIt<GetActiveAIModelUseCase>().call();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
          child: Text(
            l10n.aiSelectModel.toUpperCase(),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        InkWell(
          onTap: () {
            Navigator.of(context).pop();
            context.pushNamed(AppRoutes.aiModelSelection);
          },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: FutureBuilder<Either<Failure, AIModelEntity?>>(
                    future: _modelFuture,
                    builder: (context, snap) {
                      final model = snap.data?.fold((_) => null, (m) => m);
                      final name = model != null
                          ? model.modelId.displayName(l10n)
                          : l10n.aiModelNoneSelected;
                      return Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
