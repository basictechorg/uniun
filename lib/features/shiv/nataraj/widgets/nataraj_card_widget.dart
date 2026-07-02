import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uniun/common/locator.dart';
import 'package:uniun/common/widgets/note_card/large_note_card.dart';
import 'package:uniun/common/widgets/note_card/reference_note_card.dart';
import 'package:uniun/core/enum/note_type.dart';
import 'package:uniun/core/router/app_routes.dart';
import 'package:uniun/domain/entities/nataraj/nataraj_card_entity.dart';
import 'package:uniun/domain/entities/note/note_entity.dart';
import 'package:uniun/domain/entities/profile/profile_entity.dart';
import 'package:uniun/domain/usecases/draft_usecases.dart';
import 'package:uniun/domain/usecases/note_usecases.dart';
import 'package:uniun/domain/usecases/profile_usecases.dart';
import 'package:uniun/domain/usecases/user_usecases.dart';
import 'package:uniun/features/brahma/utils/nostr_event_utils.dart';
import 'package:uniun/features/shiv/nataraj/bloc/nataraj_bloc.dart';
import 'package:uniun/l10n/app_localizations.dart';

/// Imperative handle that lets an outside widget (e.g. the deck's fallback
/// action buttons) trigger the same fly-off animation as a real swipe, instead
/// of advancing the deck instantly. Bound to the card's state while mounted.
class NatarajCardController {
  void Function(NatarajDirection dir)? _swipe;

  void _bind(void Function(NatarajDirection dir) fn) => _swipe = fn;
  void _unbind(void Function(NatarajDirection dir) fn) {
    if (_swipe == fn) _swipe = null;
  }

  /// Fly the current card off in [dir] (no-op if no card is mounted).
  void swipe(NatarajDirection dir) => _swipe?.call(dir);
}

class NatarajCardWidget extends StatefulWidget {
  const NatarajCardWidget({
    super.key,
    required this.card,
    this.peek,
    required this.onSwipe,
    this.controller,
  });

  final NatarajCardEntity card;

  /// Optional next card shown peeking behind this one (scaled + offset).
  final NatarajCardEntity? peek;

  final void Function(NatarajDirection) onSwipe;

  /// Optional handle so the deck's action buttons can trigger the same fly-off.
  final NatarajCardController? controller;

  @override
  State<NatarajCardWidget> createState() => _NatarajCardWidgetState();
}

class _NatarajCardWidgetState extends State<NatarajCardWidget>
    with TickerProviderStateMixin {
  // Drag offset as a ValueNotifier (not setState) so per-frame drag / spring /
  // exit ticks re-apply the card transform without rebuilding the card body.
  final ValueNotifier<Offset> _drag = ValueNotifier<Offset>(Offset.zero);
  static const double _threshold = 90;

  late final AnimationController _springController;
  Animation<Offset>? _springAnimation;

  // ── Fly-off exit animation ────────────────────────────────────────────────
  // On commit, the front card flies off-screen in the swipe direction while the
  // peek card behind rises (scale 0.94→1.0, offset 14→0) into the front slot.
  // onSwipe (which advances the bloc) only fires once the card is off-screen.
  late final AnimationController _exitController;
  Animation<Offset>? _exitAnimation;
  NatarajDirection? _pendingDir;
  bool _exiting = false;

  // Resolved state — populated in initState / didUpdateWidget.
  String _selfPubkey = '';
  List<NoteEntity> _references = [];
  // Reference authors' profiles, keyed by pubkey. ReferenceNoteCard takes the
  // profile as a param and does NOT fetch it itself, so we resolve them here.
  Map<String, ProfileEntity> _profiles = {};

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Register listener once — reads _springAnimation which is set before forward().
    _springController.addListener(() {
      if (_springAnimation != null) {
        _drag.value = _springAnimation!.value;
      }
    });

    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _exitController.addListener(() {
      if (_exitAnimation != null) {
        _drag.value = _exitAnimation!.value;
      }
    });
    // Once the card has flown off-screen, advance the deck. The transforms are
    // reset in didUpdateWidget when the new card arrives — not here — so the
    // outgoing card never flashes back to center before the swap.
    _exitController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _pendingDir != null) {
        final dir = _pendingDir!;
        _pendingDir = null;
        widget.onSwipe(dir);
      }
    });

    widget.controller?._bind(_animateSwipe);
    _resolve();
  }

  @override
  void didUpdateWidget(NatarajCardWidget old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._unbind(_animateSwipe);
      widget.controller?._bind(_animateSwipe);
    }
    // Re-resolve only when the card itself changes (signature is stable per card).
    if (old.card.signature != widget.card.signature) {
      // The new card has arrived (the risen peek now sits exactly where this
      // card renders), so reset every transform in this one frame — the swap is
      // seamless and the outgoing card never reappears at center.
      _exitController.stop();
      _exiting = false;
      _pendingDir = null;
      _drag.value = Offset.zero;
      _resolve();
    }
  }

  @override
  void dispose() {
    widget.controller?._unbind(_animateSwipe);
    _drag.dispose();
    _springController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  /// Resolves the user's pubkey + the source note entities. Caps to the first 2
  /// references to fit the card layout. Falls back to draft on note-miss.
  Future<void> _resolve() async {
    // 1. Own pubkey (fast — Isar local read).
    final keysResult = await getIt<GetActiveUserKeysUseCase>().call();
    final pubkey = keysResult.fold((_) => '', (k) => k.pubkeyHex);

    // 2. Resolve up to 2 references (cap to fit the card).
    final resolved = await _resolveNatarajNotes(
      widget.card.noteIds.take(2).toList(),
      pubkey,
    );

    if (!mounted) return;
    setState(() {
      _selfPubkey = pubkey;
      _references = resolved;
    });

    // 3. Resolve each reference author's profile as a second phase (after the
    //    cards are already shown) so a slow profile lookup never delays them.
    final profiles = await _resolveNatarajProfiles(resolved);
    if (!mounted || profiles.isEmpty) return;
    setState(() => _profiles = profiles);
  }

  /// Opens a bottom sheet listing every reference behind this card (not just
  /// the two shown). Only reachable when there are more than two.
  void _showAllReferences() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllReferencesSheet(
        noteIds: widget.card.noteIds,
        selfPubkey: _selfPubkey,
        onOpenThread: (id) {
          Navigator.of(context).pop();
          context.pushNamed(AppRoutes.thread, pathParameters: {'noteId': id});
        },
      ),
    );
  }

  // ── Swipe gesture ──────────────────────────────────────────────────────────

  bool _past(Offset o) => o.dx.abs() >= _threshold || o.dy.abs() >= _threshold;

  void _onPanUpdate(DragUpdateDetails d) {
    if (_exiting) return;
    _springController.stop();
    final next = _drag.value + d.delta;
    // Tick once each time the drag crosses the commit threshold, so the user
    // feels when a release will fire a swipe (vs. spring back).
    if (_past(next) && !_past(_drag.value)) HapticFeedback.selectionClick();
    _drag.value = next;
  }

  void _onPanEnd(DragEndDetails _) {
    if (_exiting) return;
    final dx = _drag.value.dx;
    final dy = _drag.value.dy;
    if (dx.abs() < _threshold && dy.abs() < _threshold) {
      // Spring back to center.
      _springAnimation = Tween<Offset>(begin: _drag.value, end: Offset.zero)
          .animate(
            CurvedAnimation(parent: _springController, curve: Curves.easeOut),
          );
      _springController.forward(from: 0);
      return;
    }
    final dir = dx.abs() > dy.abs()
        ? (dx > 0 ? NatarajDirection.right : NatarajDirection.left)
        : (dy > 0 ? NatarajDirection.down : NatarajDirection.up);
    _animateSwipe(dir);
  }

  /// Flies the card off-screen in [dir], then advances the deck once it's gone.
  /// Shared by the swipe gesture and the deck's fallback action buttons (via
  /// [NatarajCardController]), so both paths feel identical.
  void _animateSwipe(NatarajDirection dir) {
    if (_exiting) return;
    _springController.stop();
    HapticFeedback.lightImpact();
    final size = MediaQuery.of(context).size;
    final drag = _drag.value;
    final target = switch (dir) {
      NatarajDirection.left => Offset(-size.width * 1.4, drag.dy),
      NatarajDirection.right => Offset(size.width * 1.4, drag.dy),
      NatarajDirection.up => Offset(drag.dx, -size.height * 1.2),
      NatarajDirection.down => Offset(drag.dx, size.height * 1.2),
    };
    _exitAnimation = Tween<Offset>(
      begin: drag,
      end: target,
    ).animate(CurvedAnimation(parent: _exitController, curve: Curves.easeIn));
    _pendingDir = dir;
    setState(() => _exiting = true);
    _exitController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    // The card body is built here (and re-built only when the card data or a
    // resolved profile changes), then handed to AnimatedBuilder as a cached
    // `child`. Per-frame drag / spring / exit updates flow through _drag +
    // _exitController, so the builder below only re-applies the transforms — it
    // never rebuilds the body. RepaintBoundary caches the card (incl. its blur
    // shadow) as a layer, so the transforms re-composite that texture instead of
    // re-rasterizing the shadow every frame.
    final front = RepaintBoundary(child: _card(context));
    return AnimatedBuilder(
      animation: Listenable.merge([_drag, _exitController]),
      child: front,
      builder: (context, child) {
        final drag = _drag.value;
        final angle = drag.dx * 0.0004;
        // During the fly-off, the front card fades out and the peek rises into
        // its place. Both are driven by _exitController; 0 when idle.
        final t = _exiting ? _exitController.value : 0.0;
        final frontOpacity = (1.0 - Curves.easeIn.transform(t)).clamp(0.0, 1.0);
        final rise = Curves.easeOut.transform(t);
        return Stack(
          children: [
            if (widget.peek != null) _PeekCard(card: widget.peek!, rise: rise),
            Opacity(
              opacity: frontOpacity,
              child: GestureDetector(
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Transform.translate(
                  offset: drag,
                  child: Transform.rotate(angle: angle, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _card(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final totalRefs = widget.card.noteIds.length;
    final extraCount = totalRefs > 2 ? totalRefs - 2 : 0;

    // Build the synthesized NoteEntity for LargeNoteCard.
    final synthesized = NoteEntity(
      id: '',
      sig: '',
      authorPubkey: _selfPubkey,
      content: widget.card.generatedParagraph,
      type: NoteType.text,
      eTagRefs: const [],
      pTagRefs: const [],
      tTags: extractHashtags(widget.card.generatedParagraph),
      created: widget.card.createdAt,
    );

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.16),
            blurRadius: 50,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      // The deck (_DeckBody) caps this card to the available height. A short
      // card hugs its content (Column.min); a long one fills that cap and the
      // generated-note section below scrolls internally so nothing is clipped.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "⚓ REFERENCES" section label (non-interactive) ────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 13,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.natarajReferencesLabel.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                  ),
                ),
                if (extraCount > 0) ...[
                  const SizedBox(width: 6),
                  Text(
                    '+${l10n.natarajRefsCount(extraCount)}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Source notes as ReferenceNoteCards (tap → thread page) ─────
          if (_references.isNotEmpty) ...[
            for (int i = 0; i < _references.length; i++) ...[
              ReferenceNoteCard(
                note: _references[i],
                profile: _profiles[_references[i].authorPubkey],
                // Real notes open their thread; draft sources (uuid ids, not
                // published) have no thread, so they stay non-tappable.
                onTap: _references[i].id.length == 64
                    ? () => context.pushNamed(
                        AppRoutes.thread,
                        pathParameters: {'noteId': _references[i].id},
                      )
                    : null,
              ),
              if (i < _references.length - 1)
                Divider(
                  height: 14,
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25),
                ),
            ],
            // Reveal the references not shown on the card (only when there are
            // more than the two rendered above).
            if (extraCount > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _showAllReferences,
                  icon: const Icon(Icons.unfold_more_rounded, size: 16),
                  label: Text(l10n.natarajReferencesView),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ] else ...[
            // Placeholder while resolving (keeps layout stable).
            const SizedBox(height: 8),
          ],

          // ── Divider before the synthesized note ────────────────────────
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),

          // ── Generated note as LargeNoteCard (actions hidden) ──────────
          // Scrolls within the card when the note is long, so the whole text
          // is readable without the card growing behind the action buttons.
          // ListView(shrinkWrap) hugs short notes (the card stays sized to its
          // content) and scrolls long ones; its vertical-drag recognizer wins
          // over the card's 4-way pan inside this region, so dragging the text
          // scrolls it instead of firing a swipe. Up/down swipes still fire
          // from the references area above and the action buttons below.
          // Key on _selfPubkey: it's empty on first build until _resolve()
          // finishes, and LargeNoteCard's NoteCardCubit is created once from
          // the note's authorPubkey. Without re-keying, the cubit keeps
          // watching the empty pubkey and the author renders as a raw hash
          // instead of the user's profile name/avatar.
          Flexible(
            child: ListView(
              primary: false,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                LargeNoteCard(
                  key: ValueKey(_selfPubkey),
                  note: synthesized,
                  showActions: false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Peek card — shown scaled & offset behind the active card.
class _PeekCard extends StatelessWidget {
  const _PeekCard({required this.card, this.rise = 0});

  final NatarajCardEntity card;

  /// 0 = resting behind the front card; 1 = risen flush into the front slot
  /// (driven by the front card's fly-off so the next card slides up smoothly).
  final double rise;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(0, 14 * (1 - rise)),
      child: Transform.scale(
        scale: 0.94 + 0.06 * rise,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Text(
            card.generatedParagraph,
            style: TextStyle(
              fontSize: 18,
              height: 1.6,
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 6,
            overflow: TextOverflow.fade,
          ),
        ),
      ),
    );
  }
}

/// Resolves [ids] to NoteEntities (published note → draft fallback). A draft
/// source (uuid id) is fabricated into a minimal NoteEntity authored by
/// [selfPubkey]; unknown ids are skipped silently.
Future<List<NoteEntity>> _resolveNatarajNotes(
  List<String> ids,
  String selfPubkey,
) async {
  final noteUseCase = getIt<GetNoteByIdUseCase>();
  final draftUseCase = getIt<GetDraftByIdUseCase>();
  final resolved = <NoteEntity>[];

  for (final id in ids) {
    final noteResult = await noteUseCase.call(id);
    final entity = noteResult.fold((_) => null, (n) => n);
    if (entity != null) {
      resolved.add(entity);
      continue;
    }
    final draftResult = await draftUseCase.call(id);
    draftResult.fold(
      (_) {},
      (draft) => resolved.add(
        NoteEntity(
          id: draft.draftId,
          sig: '',
          authorPubkey: selfPubkey,
          content: draft.content,
          type: NoteType.text,
          eTagRefs: const [],
          pTagRefs: const [],
          tTags: draft.tTags,
          created: draft.updatedAt,
        ),
      ),
    );
  }
  return resolved;
}

/// Resolves each note author's profile so the cards render a name/avatar
/// instead of a raw pubkey hash. Missing profiles trigger a relay fetch.
Future<Map<String, ProfileEntity>> _resolveNatarajProfiles(
  List<NoteEntity> notes,
) async {
  final getProfile = getIt<GetProfileUseCase>();
  final fetchProfile = getIt<RequestProfileFetchUseCase>();
  final profiles = <String, ProfileEntity>{};
  for (final ref in notes) {
    final pk = ref.authorPubkey;
    if (pk.isEmpty || profiles.containsKey(pk)) continue;
    final pe = (await getProfile.call(pk)).fold((_) => null, (p) => p);
    if (pe != null) {
      profiles[pk] = pe;
    } else {
      fetchProfile.call(pk);
    }
  }
  return profiles;
}

/// Bottom sheet listing every reference behind a Nataraj card. Resolves the
/// full [noteIds] set (the card itself only shows the first two), with the
/// same two-phase note → profile load.
class _AllReferencesSheet extends StatefulWidget {
  const _AllReferencesSheet({
    required this.noteIds,
    required this.selfPubkey,
    required this.onOpenThread,
  });

  final List<String> noteIds;
  final String selfPubkey;

  /// Opens the thread for a tapped (published) reference. Drafts are not tapped.
  final void Function(String noteId) onOpenThread;

  @override
  State<_AllReferencesSheet> createState() => _AllReferencesSheetState();
}

class _AllReferencesSheetState extends State<_AllReferencesSheet> {
  List<NoteEntity> _refs = [];
  Map<String, ProfileEntity> _profiles = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final notes = await _resolveNatarajNotes(widget.noteIds, widget.selfPubkey);
    if (!mounted) return;
    setState(() {
      _refs = notes;
      _loading = false;
    });
    final profiles = await _resolveNatarajProfiles(notes);
    if (!mounted || profiles.isEmpty) return;
    setState(() => _profiles = profiles);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.natarajReferencesLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.noteIds.length}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      controller: scrollController,
                      itemCount: _refs.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 16,
                        color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.25),
                      ),
                      itemBuilder: (_, i) => ReferenceNoteCard(
                        note: _refs[i],
                        profile: _profiles[_refs[i].authorPubkey],
                        onTap: _refs[i].id.length == 64
                            ? () => widget.onOpenThread(_refs[i].id)
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
