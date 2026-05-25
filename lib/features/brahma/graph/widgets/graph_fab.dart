import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uniun/features/brahma/graph/bloc/graph_bloc.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/core/theme/app_theme.dart';

/// FAB that opens the compose page and reloads the graph on return.
class GraphFab extends StatelessWidget {
  const GraphFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _onTap(context),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.onPrimary,
      elevation: 4,
      child: const Icon(Icons.add_rounded, size: 28),
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final bloc = context.read<GraphBloc>();
    await Navigator.pushNamed(context, AppRoutes.brahmaCreate);
    bloc.add(const LoadGraphEvent());
  }
}
