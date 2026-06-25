import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/moderation/cubit/report_sheet_cubit.dart';

/// Optional multi-line reason field on the report sheet. Capped at 280 chars
/// (Twitter-style, plenty for the NIP-56 `content` payload). The counter
/// label is suppressed to keep the sheet compact.
class ReasonField extends StatelessWidget {
  const ReasonField({super.key, required this.hint});

  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      maxLines: 3,
      maxLength: 280,
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
      ),
      onChanged: (v) => context.read<ReportSheetCubit>().setReason(v),
    );
  }
}
