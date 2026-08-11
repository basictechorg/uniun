// Real-device UNIUN Cloud Gana matrix — every GanaOutputType plus a
// reactive (input-driven) trigger, all against the live gateway. Cloud is
// the fast backend (~10-15s/run vs. local's cold-model-load minutes), so
// this is where a combination matrix is actually practical on a real
// device — `gana_local_engine_e2e_test.dart` stays a single scenario.
//
// Shares one bootstrap (identity, UNIUN Cloud connect, Gateway isolate,
// free-model pick) across all scenarios via `setUpAll` — self-provisions
// whatever's missing, reuses whatever's already there, same as
// `gana_cloud_engine_e2e_test.dart`. Each scenario seeds its own Gana and
// waits for a real relay OK ack.
//
// The group and DM scenarios use a REAL group/conversation already on the
// device rather than fabricating one — no synthetic group-creation event,
// no throwaway keypair standing in for a DM peer. If you haven't joined a
// group or started a DM on this device yet, those two scenarios SKIP with
// a message telling you to do that in the app first; nothing is faked to
// force them to run.
//
// By request, nothing is cleaned up afterward — every Gana definition, run
// log, and published post/message stays in local Isar so you can actually
// see the test posts in the app. Each PASSING scenario publishes one real,
// permanent event either way (Feed Freedom, no delete) — run against a
// disposable identity.
//
//   flutter test integration_test/gana_cloud_combinations_e2e_test.dart -d <device-id>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/core/enum/gana_input_type.dart';
import 'package:uniun/core/enum/gana_output_type.dart';
import 'package:uniun/core/enum/gana_run_status.dart';
import 'package:uniun/core/enum/gana_trigger_mode.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/notes/note_kinds.dart';
import 'package:uniun/data/datasources/cloud/uniun_gateway_client.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/data/models/event_queue_model.dart';
import 'package:uniun/data/models/gana_model.dart';
import 'package:uniun/data/models/gana_run_model.dart';
import 'package:uniun/data/models/group_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/llm/llm_backend_type.dart';
import 'package:uniun/domain/repositories/user_repository.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/features/shiv/gana/engine/gana_engine.dart';
import 'package:uniun/gateway/gateway.dart';

Isar? _isar;
String? _freeModelId;
bool _preconditionsMet = false;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await configureDependencies();
    _isar = getIt<Isar>();

    final keys = await getIt<UserRepository>().getActiveKeysHex();
    if (keys == null) {
      final generated = await getIt<UserRepository>().generateKey();
      if (generated.isLeft()) return;
    }

    var connected = await getIt<IsUniunCloudConnectedUseCase>().call();
    if (!connected) {
      final result = await getIt<ConnectUniunCloudUseCase>().call();
      if (result.isLeft()) return;
      connected = await getIt<IsUniunCloudConnectedUseCase>().call();
    }
    if (!connected) return;

    final free = (await UniunGatewayClient().listModels())
        .where((m) => !m.isPaid)
        .toList();
    if (free.isEmpty) return;
    _freeModelId = free.first.id;

    await GatewayBootstrap.start();
    _preconditionsMet = true;
  });

  /// Seeds a standalone/reactive cloud-pinned Gana, starts a fresh
  /// [GanaEngine], waits for the run to succeed, then waits for a real
  /// relay OK ack. No cleanup — everything it wrote stays in local Isar.
  Future<void> runAndVerify({
    required String ganaId,
    required String taskPrompt,
    required GanaOutputType outputType,
    String? outputGroupId,
    int? outputDmConversationId,
    GanaInputType? inputType,
    String? inputRefId,
    bool triggerReactive = false,
    // NIP-17: a DM's real relay event is the Kind 1059 gift wrap, signed
    // with a random throwaway key — a totally different id than the local
    // bookkeeping id `GanaRunModel.outputEventId` holds (see
    // `SendDmUseCase`'s `localId` comment). Set this for DM output so the
    // ack-wait checks the actual wire event (by kind + p-tag) instead of
    // an id that was never queued for broadcast in the first place.
    String? dmPeerPubkey,
  }) async {
    if (!_preconditionsMet) {
      // ignore: avoid_print
      print('SKIP ($ganaId): preconditions not met (no identity/cloud/'
          'network/free model) — see setUpAll');
      return;
    }
    final isar = _isar!;
    final now = DateTime.now();
    await isar.writeTxn(() async {
      await isar.ganaModels.put(
        GanaModel()
          ..ganaId = ganaId
          ..name = 'E2E combo test Gana (auto-deleted)'
          ..taskPrompt = taskPrompt
          ..outputType = outputType
          ..outputGroupId = outputGroupId
          ..outputDmConversationId = outputDmConversationId
          ..inputType = inputType
          ..inputRefId = inputRefId
          ..triggerReactive = triggerReactive
          ..desiredBackend = LlmBackendType.uniunCloud
          ..desiredModelId = _freeModelId
          ..triggerMode =
              inputType == null ? GanaTriggerMode.oneShot : GanaTriggerMode.recurring
          ..maxOutputs = inputType == null ? null : 100
          ..enabled = true
          ..createdAt = now
          ..updatedAt = now,
      );
    });

    String? publishedEventId;
    final engine = getIt<GanaEngine>();
    await engine.start();

    if (inputType != null) {
      // Standalone one-shot fires on enable automatically; a reactive
      // Gana needs an actual note write after start() to trip the
      // watcher — the input filter itself decides relevance.
      await isar.writeTxn(() async {
        await isar.noteModels.put(NoteModel(
          eventId: '$ganaId-trigger',
          sig: 'sig',
          authorPubkey: inputRefId!,
          content: 'trigger note for $ganaId',
          kind: kNoteKind,
          type: NoteType.text,
          eTagRefs: const [],
          pTagRefs: const [],
          tTags: const [],
          created: DateTime.now(),
        ));
      });
    }

    GanaRunStatus? status;
    final runDeadline = DateTime.now().add(const Duration(seconds: 30));
    while (DateTime.now().isBefore(runDeadline)) {
      final run =
          await isar.ganaRunModels.filter().ganaIdEqualTo(ganaId).findFirst();
      if (run != null) {
        status = run.status;
        publishedEventId = run.outputEventId;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await engine.stop();

    expect(status, isNotNull,
        reason: '$ganaId: no GanaRunModel appeared within 30s');
    expect(status, GanaRunStatus.succeeded,
        reason: '$ganaId: expected the run to succeed');
    expect(publishedEventId, isNotNull);

    final eventId = publishedEventId!;
    var acked = false;
    EventQueueModel? giftWrapRow;
    final ackDeadline = DateTime.now().add(const Duration(seconds: 20));
    while (DateTime.now().isBefore(ackDeadline)) {
      if (dmPeerPubkey != null) {
        final candidates = await isar.eventQueueModels
            .filter()
            .kindEqualTo(1059)
            .and()
            .pTagRefsElementEqualTo(dmPeerPubkey)
            .sortByEnqueuedAtDesc()
            .findAll();
        final row =
            candidates.where((r) => r.enqueuedAt.isAfter(now)).firstOrNull;
        if (row != null && row.sentCount > 0) {
          acked = true;
          giftWrapRow = row;
          break;
        }
      } else {
        final queued = await isar.eventQueueModels
            .filter()
            .eventIdEqualTo(eventId)
            .findFirst();
        if (queued != null && queued.sentCount > 0) {
          acked = true;
          break;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (!acked) {
      fail('$ganaId: eventId=$eventId published locally but never '
          'relay-acked within 20s');
    }
    // ignore: avoid_print
    print('OK ($ganaId): outputType=${outputType.name} '
        'eventId=${giftWrapRow?.eventId ?? eventId} model=$_freeModelId');
  }

  test('feed output — standalone, one-shot', () async {
    await runAndVerify(
      ganaId: 'e2e-combo-feed-${DateTime.now().microsecondsSinceEpoch}',
      taskPrompt: 'Say, in one short sentence, that this is a UNIUN Cloud '
          'Gana test post to the feed.',
      outputType: GanaOutputType.feed,
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('group output — standalone, one-shot, publishing into a real group '
      'you already belong to', () async {
    if (!_preconditionsMet) {
      // ignore: avoid_print
      print('SKIP: preconditions not met');
      return;
    }
    final existing = await _isar!.groupModels
        .filter()
        .removedAtIsNull()
        .findFirst();
    if (existing == null) {
      // ignore: avoid_print
      print('SKIP: no group joined on this device yet — join one in the '
          'app first (no fake group is created for this test)');
      return;
    }

    await runAndVerify(
      ganaId: 'e2e-combo-group-${DateTime.now().microsecondsSinceEpoch}',
      taskPrompt: 'Say, in one short sentence, that this is a UNIUN Cloud '
          'Gana test post to a group.',
      outputType: GanaOutputType.group,
      outputGroupId: existing.groupId,
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('dm output — standalone, one-shot, against a real conversation you '
      'already have', () async {
    if (!_preconditionsMet) {
      // ignore: avoid_print
      print('SKIP: preconditions not met');
      return;
    }
    final existing = await _isar!.dmConversationModels
        .filter()
        .removedAtIsNull()
        .findFirst();
    if (existing == null) {
      // ignore: avoid_print
      print('SKIP: no DM conversation on this device yet — start one in the '
          'app first (no fake peer is generated for this test)');
      return;
    }

    await runAndVerify(
      ganaId: 'e2e-combo-dm-${DateTime.now().microsecondsSinceEpoch}',
      taskPrompt: 'Say, in one short sentence, that this is a UNIUN Cloud '
          'Gana test DM.',
      outputType: GanaOutputType.dm,
      outputDmConversationId: existing.id,
      dmPeerPubkey: existing.otherPubkey,
    );
  }, timeout: const Timeout(Duration(seconds: 90)));

  test('reactive input trigger — fires on a new note from the watched user',
      () async {
    await runAndVerify(
      ganaId: 'e2e-combo-reactive-${DateTime.now().microsecondsSinceEpoch}',
      taskPrompt: 'Say, in one short sentence, that this Gana reacted via a '
          'UNIUN Cloud model.',
      outputType: GanaOutputType.feed,
      inputType: GanaInputType.user,
      inputRefId:
          'e2e0000000000000000000000000000000000000000000000000000000002',
      triggerReactive: true,
    );
  }, timeout: const Timeout(Duration(seconds: 90)));
}
