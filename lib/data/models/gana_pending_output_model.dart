import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/gana_output_type.dart';

part 'gana_pending_output_model.g.dart';

/// Output queue between the Gana engine isolate and the main-isolate
/// dispatcher.
///
/// The engine writes one row per successful inference; the main-isolate
/// `GanaOutputDispatcher` watches this collection, picks up rows newest-
/// last, and invokes the matching publish use case. The dispatcher deletes
/// the row on success and either deletes or marks it failed otherwise.
///
/// Why a table instead of another `SendPort`: publishing (especially
/// NIP-17 DMs and NIP-29 private channels) touches native plugins
/// (`openmls`) and main-isolate services that aren't easily exposed via
/// port. Using Isar keeps the engine pure-Dart and lets the main isolate
/// own publishing exactly as it does for user-driven sends today.
@Collection(ignore: {'copyWith'})
@Name('GanaPendingOutput')
class GanaPendingOutputModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String pendingId;

  @Index()
  late String ganaId;

  /// runId of the `GanaRunModel` row that produced this body. The
  /// dispatcher stamps `outputEventId` back on that run when publish
  /// succeeds.
  @Index()
  late String runId;

  /// Plain text body to publish. Already trimmed and `<NOOP>`-filtered.
  late String body;

  @Enumerated(EnumType.name)
  late GanaOutputType outputType;

  /// One of these is non-null per [outputType]:
  String? outputChannelId;
  String? outputGroupId;
  // Plain int? — `Id` is reserved for the primary key of this collection.
  int? outputDmConversationId;

  @Index()
  late DateTime createdAt;

  /// How many times the dispatcher attempted to publish this row. Capped
  /// at 3 — beyond that the row is deleted and the run logged as failed
  /// by the dispatcher.
  int attempts = 0;

  String? lastError;
}
