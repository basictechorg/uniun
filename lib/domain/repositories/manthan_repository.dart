// lib/domain/repositories/manthan_repository.dart
import 'package:dartz/dartz.dart';
import 'package:uniun/core/enum/manthan_card_status.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/manthan/manthan_card_entity.dart';

abstract class ManthanRepository {
  /// Oldest `buffered` card for the scope, or null when the buffer is empty.
  Future<Either<Failure, ManthanCardEntity?>> nextBufferedCard(String scopeId);

  /// Every signature already used in this scope (any status) — the dedup set.
  Future<Either<Failure, Set<String>>> getKnownSignatures(String scopeId);

  /// Persist freshly generated cards (status already set to buffered).
  Future<Either<Failure, Unit>> insertBufferedCards(List<ManthanCardEntity> cards);

  /// Set a card's status and stamp lastSeenAt = now.
  Future<Either<Failure, Unit>> updateStatus(
      String scopeId, String signature, ManthanCardStatus status);

  Future<Either<Failure, int>> countByStatus(
      String scopeId, ManthanCardStatus status);

  /// Flip up to [limit] `discarded` cards (oldest lastSeenAt first) back to
  /// `buffered`. Returns how many were rehydrated (0 ⇒ nothing to resurface).
  Future<Either<Failure, int>> rehydrateOldestDiscarded(String scopeId, int limit);
}
