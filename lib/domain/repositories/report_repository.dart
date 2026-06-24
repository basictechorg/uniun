import 'package:dartz/dartz.dart';
import 'package:uniun/core/enum/report_type.dart';
import 'package:uniun/core/error/failures.dart';
import 'package:uniun/domain/entities/report/report_entity.dart';

/// NIP-56 reporting. v1 only sends reports — UNIUN does not consume reports
/// authored by others. Filtering / aggregation is left to the relay layer
/// (or to a future client-side scoring pass).
abstract class ReportRepository {
  /// Report a specific note (carries both `e` and `p` tags). The reporter's
  /// active private key is loaded from the same secure-storage path used by
  /// the other publish flows.
  Future<Either<Failure, ReportEntity>> reportNote({
    required String targetEventId,
    required String targetPubkey,
    required ReportType type,
    String content,
  });

  /// Report a user only (carries `p` tag, no `e`).
  Future<Either<Failure, ReportEntity>> reportUser({
    required String targetPubkey,
    required ReportType type,
    String content,
  });
}
