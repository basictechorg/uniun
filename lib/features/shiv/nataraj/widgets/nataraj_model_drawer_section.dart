import 'package:dartz/dartz.dart' hide State;
import 'package:flutter/material.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/ai_model/ai_model_entity.dart';
import 'package:uniun/domain/usecases/ai_model_usecases.dart';
import 'package:uniun/features/shiv/chat/widgets/shiv_model_picker_sheet.dart';
import 'package:uniun/features/shiv/model_select/utils/ai_model_l10n.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Drawer section for the Nataraj deck. Shows the active on-device AI model
/// and opens the shared model picker (#161 — same sheet as Shiv chat) on
/// tap, inline, without navigating away from the deck.
class NatarajModelDrawerSection extends StatefulWidget {
  const NatarajModelDrawerSection({super.key});

  @override
  State<NatarajModelDrawerSection> createState() =>
      _NatarajModelDrawerSectionState();
}

class _NatarajModelDrawerSectionState extends State<NatarajModelDrawerSection> {
  late Future<Either<Failure, AIModelEntity?>> _modelFuture;

  @override
  void initState() {
    super.initState();
    _modelFuture = getIt<GetActiveAIModelUseCase>().call();
  }

  Future<void> _pickModel() async {
    await showModelPickerSheet(context);
    if (!mounted) return;
    // The picker may have changed the active model — refresh the label.
    setState(() => _modelFuture = getIt<GetActiveAIModelUseCase>().call());
  }

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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        InkWell(
          onTap: _pickModel,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 10),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.smart_toy_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
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
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
