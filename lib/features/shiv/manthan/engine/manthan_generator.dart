// lib/features/shiv/manthan/engine/manthan_generator.dart
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:injectable/injectable.dart';
import 'package:isar_community/isar.dart';
import 'package:uniun/core/enum/manthan_card_status.dart';
import 'package:uniun/core/utils/llm_text_sanitizer.dart';
import 'package:uniun/domain/entities/manthan/manthan_card_entity.dart';
import 'package:uniun/domain/repositories/manthan_repository.dart';
import 'package:uniun/domain/usecases/llm_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/shiv/generation/context/manas_context_loader.dart';
import 'package:uniun/features/shiv/manthan/utils/manthan_prompt_builder.dart';
import 'package:uniun/features/shiv/manthan/utils/manthan_sampler.dart';

enum ManthanFillState { ok, needsMoreNotes, resurfacing, exhausted, error }

class ManthanFillResult {
  final int inserted;
  final ManthanFillState state;
  const ManthanFillResult({required this.inserted, required this.state});
}

@lazySingleton
class ManthanGenerator {
  final Isar _isar;
  final ManthanRepository _repo;
  final GenerateOneShotUseCase _generate;
  final GetActiveUserKeysUseCase _keys;

  ManthanGenerator(this._isar, this._repo, this._generate, this._keys);

  /// 'all' for the empty (All notes) scope, else a stable SHA-1 key over
  /// the sorted manas id set.
  static String scopeIdFor(List<String> manasIds) {
    if (manasIds.isEmpty) return 'all';
    final sorted = [...manasIds]..sort();
    return sha1.convert(utf8.encode(sorted.join('|'))).toString();
  }

  /// Generate up to [count] fresh cards into the buffer for [manasIds]
  /// (empty ⇒ All notes). Falls back to resurfacing discarded cards when
  /// the fresh combination space is exhausted.
  Future<ManthanFillResult> fillBuffer({
    required List<String> manasIds,
    int count = 5,
  }) async {
    final scopeId = scopeIdFor(manasIds);

    // 1. Load the candidate note pool.
    final List<PackedNote> pool;
    if (manasIds.isEmpty) {
      // All-notes scope: need the user's pubkey to find their own notes.
      final keysE = await _keys.call();
      final selfPubkey = keysE.fold((_) => null, (k) => k.pubkeyHex);
      if (selfPubkey == null) {
        return const ManthanFillResult(
            inserted: 0, state: ManthanFillState.error);
      }
      pool = await ManasContextLoader.loadAll(
          isar: _isar, selfPubkey: selfPubkey);
    } else {
      pool =
          await ManasContextLoader.loadPool(isar: _isar, manasIds: manasIds);
    }

    if (pool.length < 2) {
      return const ManthanFillResult(
          inserted: 0, state: ManthanFillState.needsMoreNotes);
    }

    // 2. Known signatures → 3. sample unseen combos.
    final known =
        (await _repo.getKnownSignatures(scopeId)).getOrElse(() => <String>{});
    final combos = sampleUnseenCombos(
      poolIds: pool.map((p) => p.id).toList(),
      knownSignatures: known,
      count: count,
      random: Random(),
    );

    if (combos.isEmpty) {
      // Fresh combination space exhausted → resurface discarded cards instead.
      final n =
          (await _repo.rehydrateOldestDiscarded(scopeId, count)).getOrElse(
        () => 0,
      );
      return ManthanFillResult(
        inserted: 0,
        state:
            n > 0 ? ManthanFillState.resurfacing : ManthanFillState.exhausted,
      );
    }

    // 4-5. Generate + sanitize each combo.
    final byId = {for (final p in pool) p.id: p};
    final cards = <ManthanCardEntity>[];

    for (final combo in combos) {
      final notes = combo.noteIds
          .map((id) => byId[id])
          .whereType<PackedNote>()
          .toList();
      if (notes.length < 2) continue;

      final prompt = ManthanPromptBuilder.build(notes: notes);
      final res = await _generate.call(
        GenerateOneShotInput(
          // maxTokens here is only a fallback: the runner opens the engine at
          // the model's baked-in KV-cache size (LocalModelParams.maxTokens),
          // NOT this value — opening smaller fails the native invoke. The
          // prompt is bounded by truncating each note in ManthanPromptBuilder;
          // output length is capped below. highPriority routes Manthan onto the
          // chat lane so it runs while the Shiv tab holds the low lane paused.
          prompt: prompt,
          maxTokens: 512,
          highPriority: true,
        ),
      );
      final raw = res.fold((_) => null, (s) => s);
      if (raw == null) continue; // preempted / no model → retry next fill

      final clean = LlmTextSanitizer.clean(raw).trim();
      if (clean.isEmpty ||
          clean.toUpperCase().contains(ManthanPromptBuilder.noopSentinel)) {
        continue;
      }
      // Hard-cap to ~60 words. The prompt asks for 60 words max but not every
      // model obeys; a runaway paragraph overruns the card. This is the text
      // that gets published, so cap it here, not just in the display.
      final words = clean.split(RegExp(r'\s+'));
      final paragraph =
          words.length > 60 ? '${words.take(60).join(' ')}…' : clean;

      cards.add(ManthanCardEntity(
        scopeId: scopeId,
        signature: combo.signature,
        noteIds: combo.noteIds,
        generatedParagraph: paragraph,
        status: ManthanCardStatus.buffered,
        createdAt: DateTime.now(),
      ));
    }

    if (cards.isNotEmpty) await _repo.insertBufferedCards(cards);
    return ManthanFillResult(
        inserted: cards.length, state: ManthanFillState.ok);
  }
}
