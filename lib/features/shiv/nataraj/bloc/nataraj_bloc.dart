import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import 'package:uniun/core/enum/nataraj_card_status.dart';
import 'package:uniun/domain/entities/draft/draft_entity.dart';
import 'package:uniun/domain/entities/manas/manas_entity.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/manas_usecases.dart';
import 'package:uniun/domain/usecases/nataraj_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';
import 'package:uniun/features/shiv/nataraj/engine/nataraj_generator.dart';
import 'package:uuid/uuid.dart';

part 'nataraj_event.dart';
part 'nataraj_state.dart';
part 'nataraj_bloc.freezed.dart';

const int _kBufferTarget = 5;
const int _kInitialFill = 1;

@injectable
class NatarajBloc extends Bloc<NatarajEvent, NatarajState> {
  final NatarajGenerator _generator;
  final GetNextNatarajCardUseCase _next;
  final RecordNatarajSwipeUseCase _record;
  final GetManasListUseCase _manasList;
  final GetActiveUserKeysUseCase _keys;
  final PublishNoteUseCase _publish;
  final SaveDraftUseCase _saveDraft;

  NatarajBloc(
    this._generator,
    this._next,
    this._record,
    this._manasList,
    this._keys,
    this._publish,
    this._saveDraft,
  ) : super(const NatarajState()) {
    on<_LoadDeck>(_onLoadDeck);
    on<_ChangeScope>(_onChangeScope);
    on<_SwipeCard>(_onSwipeCard, transformer: sequential());
    on<_ToggleReference>(_onToggleReference);
    on<_LoadMore>(_onLoadMore, transformer: droppable());
  }

  String get _scopeId => NatarajGenerator.scopeIdFor(state.manasIds);

  Future<void> _onLoadDeck(_LoadDeck e, Emitter<NatarajState> emit) async {
    final options = (await _manasList.call()).getOrElse(() => const []);
    emit(state.copyWith(
      status: NatarajStatus.loading,
      manasIds: e.manasIds,
      scopeName: _scopeNameFor(e.manasIds, options),
      manasOptions: options,
      currentCard: null,
      nextCard: null,
      excludedRefIds: const {},
    ));
    await _fillAndShow(emit);
  }

  Future<void> _onChangeScope(_ChangeScope e, Emitter<NatarajState> emit) async {
    emit(state.copyWith(
      status: NatarajStatus.loading,
      manasIds: e.manasIds,
      scopeName: _scopeNameFor(e.manasIds, state.manasOptions),
      currentCard: null,
      nextCard: null,
      excludedRefIds: const {},
      resurfacing: false,
    ));
    await _fillAndShow(emit);
  }

  Future<void> _onLoadMore(_LoadMore e, Emitter<NatarajState> emit) async {
    await _generator.fillBuffer(manasIds: state.manasIds, count: _kBufferTarget);
  }

  Future<void> _onToggleReference(
      _ToggleReference e, Emitter<NatarajState> emit) {
    final next = {...state.excludedRefIds};
    if (next.contains(e.noteId)) {
      next.remove(e.noteId);
    } else {
      next.add(e.noteId);
    }
    emit(state.copyWith(excludedRefIds: next));
    return Future.value();
  }

  Future<void> _onSwipeCard(_SwipeCard e, Emitter<NatarajState> emit) async {
    final card = state.currentCard;
    if (card == null) return;

    String? seed;
    switch (e.direction) {
      case NatarajDirection.up:
        if (!await _publishCard(card)) return;
        await _mark(card, NatarajCardStatus.published);
      case NatarajDirection.right:
        if (!await _draftCard(card)) return;
        await _mark(card, NatarajCardStatus.drafted);
      case NatarajDirection.left:
        await _mark(card, NatarajCardStatus.discarded);
      case NatarajDirection.down:
        await _mark(card, NatarajCardStatus.seen);
        seed = card.generatedParagraph;
    }

    // Advance + top up the buffer. When the buffer is momentarily empty
    // (next == null), switch to `loading` in the SAME emit — never leave
    // `ready` with a null card, or the deck body's `currentCard!` crashes
    // before _fillAndShow re-emits.
    final nextE = await _next.call(_scopeId);
    if (isClosed) return; // page closed while we were awaiting; bail
    final next = nextE.getOrElse(() => null);
    emit(state.copyWith(
      status: next == null ? NatarajStatus.loading : state.status,
      currentCard: next,
      nextCard: null,
      excludedRefIds: const {},
      seedChatParagraph: seed,
    ));
    if (next == null) {
      await _fillAndShow(emit);
    } else {
      if (!isClosed) add(const NatarajEvent.loadMore());
    }
  }

  Future<void> _mark(NatarajCardEntity card, NatarajCardStatus status) =>
      _record.call(RecordNatarajSwipeInput(
        scopeId: card.scopeId,
        signature: card.signature,
        status: status,
      ));

  static bool _isEventId(String id) =>
      id.length == 64 && RegExp(r'^[0-9a-f]{64}$').hasMatch(id);

  Future<bool> _publishCard(NatarajCardEntity card) async {
    final keys = (await _keys.call()).fold((_) => null, (k) => k);
    if (keys == null) return false;
    final mentionIds = card.noteIds
        .where((id) => !state.excludedRefIds.contains(id))
        .where(_isEventId)
        .toList();
    final hashtags = extractHashtags(card.generatedParagraph);
    final tags = buildNoteTags(mentionIds: mentionIds, hashtags: hashtags);
    final event = signNostrEvent(
      content: card.generatedParagraph,
      tags: tags,
      privkeyHex: keys.privkeyHex,
    );
    final note = noteEntityFromEvent(
      event: event,
      pubkeyHex: keys.pubkeyHex,
      eTagRefs: mentionIds,
      tTags: hashtags,
    );
    return (await _publish.call(note)).isRight();
  }

  Future<bool> _draftCard(NatarajCardEntity card) async {
    final mentionIds = card.noteIds
        .where((id) => !state.excludedRefIds.contains(id))
        .where(_isEventId)
        .toList();
    final now = DateTime.now();
    return (await _saveDraft.call(DraftEntity(
      draftId: const Uuid().v4(),
      content: card.generatedParagraph,
      eTagRefs: mentionIds,
      pTagRefs: const [],
      tTags: extractHashtags(card.generatedParagraph),
      createdAt: now,
      updatedAt: now,
    ))).isRight();
  }

  Future<void> _fillAndShow(Emitter<NatarajState> emit) async {
    // Generate one card first so the user sees something immediately.
    final result = await _generator.fillBuffer(
        manasIds: state.manasIds, count: _kInitialFill);
    // LLM generation can take 30+ seconds — page may have been closed in the
    // meantime. Bail rather than emit/add to a dead bloc.
    if (isClosed) return;
    final card = (await _next.call(_scopeId)).getOrElse(() => null);
    if (isClosed) return;

    if (card != null) {
      emit(state.copyWith(
        status: NatarajStatus.ready,
        currentCard: card,
        resurfacing: result.state == NatarajFillState.resurfacing,
      ));
      // Top the buffer up to _kBufferTarget in the background while the
      // user reads the first card.
      if (!isClosed) add(const NatarajEvent.loadMore());
      return;
    }
    emit(state.copyWith(
      status: switch (result.state) {
        NatarajFillState.needsMoreNotes => NatarajStatus.needsMoreNotes,
        NatarajFillState.exhausted => NatarajStatus.exhausted,
        NatarajFillState.error => NatarajStatus.error,
        NatarajFillState.ok => NatarajStatus.error,
        NatarajFillState.resurfacing => NatarajStatus.error,
      },
      currentCard: null,
    ));
  }

  String _scopeNameFor(List<String> ids, List<ManasEntity> options) {
    if (ids.length == 1) {
      final matches = options.where((o) => o.manasId == ids.first);
      if (matches.isNotEmpty) return matches.first.name;
    }
    // Empty (all notes) or multi-manas: return '' — the page supplies
    // the localized label via l10n.natarajScopeAllNotes /
    // l10n.natarajScopeManasCount.
    return '';
  }
}
