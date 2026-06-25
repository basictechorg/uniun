import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/atoms/uniun_back_button.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/drop_loading_indicator.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/enum/gana_trigger_preset.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';
import 'package:uniun/domain/entities/channel/channel_entity.dart';
import 'package:uniun/domain/entities/dm/dm_conversation_entity.dart';
import 'package:uniun/domain/entities/followed_note/followed_note_entity.dart';
import 'package:uniun/domain/entities/llm/llm_task_kind.dart';
import 'package:uniun/domain/entities/private_channel/private_channel_entity.dart';
import 'package:uniun/domain/usecases/scheduler_usecases.dart';
import 'package:uniun/features/shiv/gana/form/bloc/gana_form_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

part '../widgets/gana_form_sections.dart';
part '../widgets/gana_form_controls.dart';
part '../widgets/gana_form_atoms.dart';

class GanaFormPage extends StatelessWidget {
  const GanaFormPage({super.key, this.ganaId});
  final String? ganaId; // null ⇒ create mode

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<GanaFormBloc>()..add(GanaFormLoadEvent(ganaId)),
      child: const _GanaFormView(),
    );
  }
}

class _GanaFormView extends StatefulWidget {
  const _GanaFormView();
  @override
  State<_GanaFormView> createState() => _GanaFormViewState();
}

class _GanaFormViewState extends State<_GanaFormView> {
  final _nameCtrl = TextEditingController();
  final _taskCtrl = TextEditingController();
  final _userRefCtrl = TextEditingController();
  final _intervalCtrl = TextEditingController();
  final _maxOutputsCtrl = TextEditingController();
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    // Hoist Gana jobs to T1 while the form (with its inline preview) is
    // open — docs/SHIVA/scheduling.md §3.
    getIt<SetForegroundKindUseCase>().call(LlmTaskKind.gana);
  }

  @override
  void dispose() {
    getIt<SetForegroundKindUseCase>().call(null);
    _nameCtrl.dispose();
    _taskCtrl.dispose();
    _userRefCtrl.dispose();
    _intervalCtrl.dispose();
    _maxOutputsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BlocConsumer<GanaFormBloc, GanaFormState>(
      listenWhen: (p, c) => p.status != c.status,
      listener: (context, state) {
        if (state.status == GanaFormStatus.saved ||
            state.status == GanaFormStatus.deleted) {
          Navigator.of(context).pop(true);
        }
        if (state.status == GanaFormStatus.ready && !_seeded) {
          _seeded = true;
          _nameCtrl.text = state.name;
          _taskCtrl.text = state.taskPrompt;
          _userRefCtrl.text = state.inputType == GanaInputType.user
              ? (state.inputRefId ?? '')
              : '';
          _intervalCtrl.text =
              state.triggerIntervalMinutes?.toString() ?? '';
          _maxOutputsCtrl.text = state.maxOutputs?.toString() ?? '';
        }
        if (state.status == GanaFormStatus.error &&
            state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(state.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ));
        }
      },
      builder: (context, state) {
        final loading = state.status == GanaFormStatus.loading ||
            state.status == GanaFormStatus.initial;
        final isEdit = state.isEditMode;

        return Scaffold(
          backgroundColor: AppColors.surfaceContainerLow,
          appBar: AppBar(
            backgroundColor: AppColors.surfaceContainerLow,
            scrolledUnderElevation: 0,
            leading:
                UniunBackButton(onPressed: () => Navigator.of(context).pop()),
            title: Text(
              isEdit
                  ? (state.name.isEmpty
                      ? l10n.ganaFormEditTitleFallback
                      : l10n.ganaFormEditTitle(state.name))
                  : l10n.ganaFormCreateTitle,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          body: loading
              ? const Center(
                  child: DropLoadingIndicator(
                      color: AppColors.primary))
              : _Body(
                  state: state,
                  nameCtrl: _nameCtrl,
                  taskCtrl: _taskCtrl,
                  userRefCtrl: _userRefCtrl,
                  intervalCtrl: _intervalCtrl,
                  maxOutputsCtrl: _maxOutputsCtrl,
                ),
          bottomNavigationBar: loading ? null : _SaveBar(state: state),
        );
      },
    );
  }
}

