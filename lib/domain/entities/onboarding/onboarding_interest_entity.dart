import 'package:freezed_annotation/freezed_annotation.dart';

part 'onboarding_interest_entity.freezed.dart';

/// A backend-owned "interest" shown on the onboarding interest-picker. Each
/// entry maps to a house account (a pubkey the gateway operator controls
/// that posts daily) — selecting an interest follows that account, so a
/// brand-new user never lands on an empty Vishnu feed.
@freezed
abstract class OnboardingInterestEntity with _$OnboardingInterestEntity {
  const factory OnboardingInterestEntity({
    required int id,
    required String name,
    required String pubkeyHex,
  }) = _OnboardingInterestEntity;
}
