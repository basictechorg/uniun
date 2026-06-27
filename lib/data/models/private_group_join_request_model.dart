import 'package:isar_community/isar.dart';

part 'private_group_join_request_model.g.dart';

@Collection(ignore: {'copyWith'})
@Name('PrivateChannelJoinRequest') // on-disk name preserved across the channel→group rename
class PrivateGroupJoinRequestModel {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String eventId;

  @Index()
  late String groupId;

  late String senderPubkey;
  
  /// The base64 encoded KeyPackage
  late String keyPackageB64;

  late DateTime timestamp;

  /// True once the admin has approved this request. The row is kept (never
  /// physically deleted) so a re-synced Kind 9021 event from the relay can't
  /// resurrect an already-handled request: the inbound handler's `eventId`
  /// idempotency check finds the existing row and skips the re-insert. Handled
  /// rows are filtered out of the pending-requests UI query.
  bool handled = false;
}
