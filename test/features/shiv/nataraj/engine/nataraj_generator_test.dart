import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:mocktail/mocktail.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/data/models/manas_note_link_model.dart';
import 'package:uniun/data/models/notes/note_model.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/repositories/nataraj_repository.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/shiv/nataraj/engine/nataraj_generator.dart';
import 'package:uniun/features/shiv/nataraj/utils/nataraj_sampler.dart';

import '../../../../_helpers/fixtures.dart';
import '../../../../_helpers/isar_test_harness.dart';

class _MockRepo extends Mock implements NatarajRepository {}

class _MockGenerate extends Mock implements GenerateOneShotUseCase {}

class _MockKeys extends Mock implements GetActiveUserKeysUseCase {}

NoteModel _note(String id, String content, {String author = 'self'}) =>
    NoteModel(
      eventId: id,
      sig: 'sig',
      authorPubkey: author,
      content: content,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: const [],
      created: DateTime(2026, 1, 1),
    );

ManasNoteLinkModel _link(String manasId, String noteId) => ManasNoteLinkModel()
  ..manasId = manasId
  ..noteId = noteId
  ..addedAt = DateTime(2026, 1, 1);

void main() {
  late Isar isar;
  late _MockRepo repo;
  late _MockGenerate generate;
  late _MockKeys keys;
  late NatarajGenerator generator;

  setUpAll(() {
    registerFallbackValue(<NatarajCardEntity>[]);
    registerFallbackValue(const GenerateOneShotInput(prompt: 'x'));
  });

  setUp(() async {
    isar = await openTestIsar();
    repo = _MockRepo();
    generate = _MockGenerate();
    keys = _MockKeys();
    generator = NatarajGenerator(isar, repo, generate, keys);
  });

  tearDown(() async {
    await isar.close(deleteFromDisk: true);
  });

  group('scopeIdFor', () {
    test('empty manasIds maps to the sentinel "all"', () {
      expect(NatarajGenerator.scopeIdFor(const []), 'all');
    });

    test('is order-independent (sorts before hashing)', () {
      expect(NatarajGenerator.scopeIdFor(['b', 'a']),
          NatarajGenerator.scopeIdFor(['a', 'b']));
    });

    test('differs for genuinely different manas sets', () {
      expect(NatarajGenerator.scopeIdFor(['a']),
          isNot(NatarajGenerator.scopeIdFor(['b'])));
    });
  });

  group('fillBuffer — pool loading', () {
    test('all-notes scope with no active signing keys errors before '
        'touching the repo', () async {
      when(() => keys.call())
          .thenAnswer((_) async => const Left(Failure.errorFailure('no keys')));

      final result = await generator.fillBuffer(manasIds: const []);

      expect(result.state, NatarajFillState.error);
      expect(result.inserted, 0);
      verifyNever(() => repo.getKnownSignatures(any()));
    });

    test('a pool smaller than 2 notes reports needsMoreNotes', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.put(_note('n1', 'only one'));
        await isar.manasNoteLinkModels.put(_link('m1', 'n1'));
      });

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.needsMoreNotes);
      expect(result.inserted, 0);
    });

    test('all-notes scope resolves the pool via loadAll using the active '
        'pubkey', () async {
      when(() => keys.call())
          .thenAnswer((_) async => Right(aSigningKeys(pubkeyHex: 'self')));
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([
          _note('n1', 'first note about the sea', author: 'self'),
          _note('n2', 'second note about the sky', author: 'self'),
        ]);
      });
      when(() => repo.getKnownSignatures(any()))
          .thenAnswer((_) async => const Right(<String>{}));
      when(() => generate.call(any()))
          .thenAnswer((_) async => const Right('A short paragraph.'));
      when(() => repo.insertBufferedCards(any()))
          .thenAnswer((_) async => const Right(unit));

      final result = await generator.fillBuffer(manasIds: const [], count: 1);

      expect(result.state, NatarajFillState.ok);
      expect(result.inserted, 1);
    });
  });

  group('fillBuffer — combo sampling + resurfacing', () {
    test('when every combination is already known, resurfaces discarded '
        'cards instead of generating', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      // 2-note pool has exactly 1 possible combo — mark it known.
      final sig = _pairSignature(['n1', 'n2']);
      when(() => repo.getKnownSignatures(any()))
          .thenAnswer((_) async => Right({sig}));
      when(() => repo.rehydrateOldestDiscarded(any(), any()))
          .thenAnswer((_) async => const Right(2));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.resurfacing);
      expect(result.inserted, 0);
      verifyNever(() => generate.call(any()));
    });

    test('a rehydrateOldestDiscarded failure degrades to 0 resurfaced '
        '(getOrElse), reporting exhausted', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      final sig = _pairSignature(['n1', 'n2']);
      when(() => repo.getKnownSignatures(any()))
          .thenAnswer((_) async => Right({sig}));
      when(() => repo.rehydrateOldestDiscarded(any(), any())).thenAnswer(
          (_) async => const Left(Failure.errorFailure('db error')));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.exhausted);
    });

    test('when the fresh space is exhausted and nothing resurfaces, '
        'reports exhausted', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      final sig = _pairSignature(['n1', 'n2']);
      when(() => repo.getKnownSignatures(any()))
          .thenAnswer((_) async => Right({sig}));
      when(() => repo.rehydrateOldestDiscarded(any(), any()))
          .thenAnswer((_) async => const Right(0));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.exhausted);
    });

    test('a getKnownSignatures failure degrades to treating nothing as '
        'known (getOrElse)', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      when(() => repo.getKnownSignatures(any()))
          .thenAnswer((_) async => const Left(Failure.errorFailure('db error')));
      when(() => generate.call(any()))
          .thenAnswer((_) async => const Right('A generated paragraph.'));
      when(() => repo.insertBufferedCards(any()))
          .thenAnswer((_) async => const Right(unit));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.ok);
      expect(result.inserted, 1);
    });
  });

  group('fillBuffer — per-combo generation outcomes', () {
    setUp(() {
      when(() => repo.getKnownSignatures(any()))
          .thenAnswer((_) async => const Right(<String>{}));
    });

    test('a null (preempted / no model) response is skipped, not counted',
        () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      when(() => generate.call(any())).thenAnswer((_) async => const Right(null));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.ok);
      expect(result.inserted, 0);
      verifyNever(() => repo.insertBufferedCards(any()));
    });

    test('an empty-after-sanitize response is skipped', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      when(() => generate.call(any())).thenAnswer((_) async => const Right('   '));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.ok);
      expect(result.inserted, 0);
    });

    test('a NOOP-sentinel response is skipped', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      when(() => generate.call(any()))
          .thenAnswer((_) async => const Right('<NOOP>'));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.state, NatarajFillState.ok);
      expect(result.inserted, 0);
    });

    test('a runaway paragraph is hard-capped to 60 words with an ellipsis',
        () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      final longParagraph = List.generate(80, (i) => 'word$i').join(' ');
      when(() => generate.call(any()))
          .thenAnswer((_) async => Right(longParagraph));
      List<NatarajCardEntity>? captured;
      when(() => repo.insertBufferedCards(any())).thenAnswer((invocation) async {
        captured = invocation.positionalArguments.single as List<NatarajCardEntity>;
        return const Right(unit);
      });

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.inserted, 1);
      final paragraph = captured!.single.generatedParagraph;
      expect(paragraph.endsWith('…'), isTrue);
      // The ellipsis is appended directly to the 60th word (no separating
      // space), so splitting on whitespace still yields exactly 60 tokens.
      expect(paragraph.split(RegExp(r'\s+')).length, 60);
    });

    test('a normal-length response is inserted unmodified (no ellipsis)',
        () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      when(() => generate.call(any()))
          .thenAnswer((_) async => const Right('A short paragraph.'));
      when(() => repo.insertBufferedCards(any()))
          .thenAnswer((_) async => const Right(unit));

      final result = await generator.fillBuffer(manasIds: const ['m1']);

      expect(result.inserted, 1);
      expect(result.state, NatarajFillState.ok);
    });

    test('insertBufferedCards is never called when every combo yields no '
        'usable card', () async {
      await isar.writeTxn(() async {
        await isar.noteModels.putAll([_note('n1', 'a'), _note('n2', 'b')]);
        await isar.manasNoteLinkModels.putAll(
            [_link('m1', 'n1'), _link('m1', 'n2')]);
      });
      when(() => generate.call(any())).thenAnswer((_) async => const Right(null));

      await generator.fillBuffer(manasIds: const ['m1']);

      verifyNever(() => repo.insertBufferedCards(any()));
    });
  });
}

/// A 2-note pool has exactly one possible combo — its signature is
/// [natarajSignature] of the sorted pair, the same function the generator's
/// own sampler uses.
String _pairSignature(List<String> ids) => natarajSignature(ids);
