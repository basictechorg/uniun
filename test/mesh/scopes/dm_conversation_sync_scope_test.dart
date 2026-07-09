// Integration tests for [DmConversationSyncScope]. Real Isar, real
// MeshEventCodec. The `d` tag is the counterparty pubkey — save/delete
// conversation both address the same addressable slot per plan §5.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:nostr_core_dart/nostr.dart';
import 'package:uniun/data/models/dm/dm_conversation_model.dart';
import 'package:uniun/features/mesh/sync/bodies/dm_conversation_body.dart';
import 'package:uniun/features/mesh/sync/mesh_event_codec.dart';
import 'package:uniun/features/mesh/sync/scopes/dm_conversation_sync_scope.dart';

import '../../_helpers/isar_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const flutterSecureStorage =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(flutterSecureStorage, (_) async => null);

  late Isar isar;
  late Keychain me;
  late MeshEventCodec codec;
  late DmConversationSyncScope scope;

  setUp(() async {
    isar = await openTestIsar();
    me = Keychain.generate();
    codec = MeshEventCodec(privkeyHex: me.private, pubkeyHex: me.public);
    scope = DmConversationSyncScope(isar, codec);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  DmConversationModel makeRow(String pk, {List<String> relays = const []}) =>
      DmConversationModel()
        ..otherPubkey = pk
        ..relays = relays;

  Future<String> seedSignedRow(
    String pk, {
    required int createdAtSec,
    MeshRecordState state = MeshRecordState.active,
    List<String> relays = const [],
  }) async {
    final row = makeRow(pk, relays: relays);
    final body = state == MeshRecordState.active
        ? DmConversationBody.forActive(row)
        : DmConversationBody.forRemoved(row);
    final signed = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: pk,
      content: body,
      createdAtSec: createdAtSec,
    );
    row.signedNostrEvent = signed;
    row.removedAt = state == MeshRecordState.removed ? DateTime.now() : null;
    await isar.writeTxn(() => isar.dmConversationModels.put(row));
    return signed;
  }

  test('localIndex returns (eventId → createdAt) only for signed rows',
      () async {
    await seedSignedRow('pk-a', createdAtSec: 1720000000);
    await isar
        .writeTxn(() => isar.dmConversationModels.put(makeRow('pk-b')));

    final index = await scope.localIndex();
    expect(index.length, 1);
    expect(index.values.single, 1720000000);
  });

  test('signedEvent looks up a row by outer event id', () async {
    final signed = await seedSignedRow('pk-a', createdAtSec: 1720000000);
    final id = (await codec.openRecord(signed)).event['id'] as String;
    expect(await scope.signedEvent(id), signed);
  });

  test('upsertSigned inserts a new active row keyed by counterparty',
      () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-new',
      content: DmConversationBody.forActive(
        makeRow('pk-new', relays: const ['wss://r.example']),
      ),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(signed);

    final row = await isar.dmConversationModels
        .where()
        .otherPubkeyEqualTo('pk-new')
        .findFirst();
    expect(row, isNotNull);
    expect(row!.relays, ['wss://r.example']);
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, signed);
  });

  test('upsertSigned flips an active row to tombstone on newer removed event',
      () async {
    await seedSignedRow('pk-a', createdAtSec: 1720000000);

    final tombstone = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-a',
      content: DmConversationBody.forRemoved(makeRow('pk-a')),
      createdAtSec: 1720000100,
    );
    await scope.upsertSigned(tombstone);

    final row = await isar.dmConversationModels
        .where()
        .otherPubkeyEqualTo('pk-a')
        .findFirst();
    expect(row!.removedAt, isNotNull);
    expect(row.signedNostrEvent, tombstone);
  });

  test('upsertSigned survives out-of-order save→delete→save', () async {
    final activeOld = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-a',
      content: DmConversationBody.forActive(
        makeRow('pk-a', relays: const ['wss://old']),
      ),
      createdAtSec: 1720000100,
    );
    final removed = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-a',
      content: DmConversationBody.forRemoved(makeRow('pk-a')),
      createdAtSec: 1720000200,
    );
    final activeNew = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-a',
      content: DmConversationBody.forActive(
        makeRow('pk-a', relays: const ['wss://new']),
      ),
      createdAtSec: 1720000300,
    );

    await scope.upsertSigned(activeNew);
    await scope.upsertSigned(activeOld);
    await scope.upsertSigned(removed);

    final row = await isar.dmConversationModels
        .where()
        .otherPubkeyEqualTo('pk-a')
        .findFirst();
    expect(row!.relays, ['wss://new']);
    expect(row.removedAt, isNull);
    expect(row.signedNostrEvent, activeNew);
  });

  test('upsertSigned silently drops an event signed by another identity',
      () async {
    final foreign = Keychain.generate();
    final foreignCodec =
        MeshEventCodec(privkeyHex: foreign.private, pubkeyHex: foreign.public);
    final foreignSigned = await foreignCodec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-foreign',
      content: DmConversationBody.forActive(makeRow('pk-foreign')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(foreignSigned);

    expect(await isar.dmConversationModels.count(), 0);
  });

  test('upsertSigned silently drops a tampered event', () async {
    final signed = await codec.signRecord(
      kind: MeshEventKinds.dmConversation,
      dTag: 'pk-tamper',
      content: DmConversationBody.forActive(makeRow('pk-tamper')),
      createdAtSec: 1720000000,
    );
    final tampered = signed.replaceFirstMapped(
      RegExp(r'"sig":"([0-9a-f])'),
      (m) => '"sig":"${_flipHex(m.group(1)!)}',
    );
    expect(tampered != signed, isTrue);

    await scope.upsertSigned(tampered);

    expect(await isar.dmConversationModels.count(), 0);
  });

  test('upsertSigned silently drops an event of a non-dmConversation kind',
      () async {
    final wrongKind = await codec.signRecord(
      kind: 30599,
      dTag: 'pk-x',
      content: DmConversationBody.forActive(makeRow('pk-x')),
      createdAtSec: 1720000000,
    );

    await scope.upsertSigned(wrongKind);

    expect(await isar.dmConversationModels.count(), 0);
  });
}

/// Deterministic hex tamper — nudges 0→1 (or f→0) so the tampered string is
/// guaranteed to differ from the original regardless of what char was there.
String _flipHex(String c) => c == '0' ? '1' : '0';
