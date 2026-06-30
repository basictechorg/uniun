/// A predefined "interest" shown on the onboarding interest-picker.
///
/// Each entry maps to a **house account** — a pubkey we control that posts every
/// day. Selecting an interest follows that account, so a brand-new user never
/// lands on an empty Vishnu feed.
///
/// **Extensible by design:** to add an interest, append one [OnboardingInterest]
/// to [kOnboardingInterests]. The picker, its search, and the follow-on-continue
/// step all read from this single list — nothing else needs to change. The list
/// is expected to grow (30–40+) as more house accounts come online.
///
/// [name] is the account's display name with the "UNIUN"/"Bot" words dropped.
class OnboardingInterest {
  const OnboardingInterest({required this.name, required this.pubkeyHex});

  /// Short, human-facing label shown on the chip (e.g. "Tech").
  final String name;

  /// secp256k1 public key (hex) of the house account this interest follows.
  final String pubkeyHex;
}

/// The interest roster. Order here is the order chips flow into the picker.
///
/// Add a new house account by appending a row below.
const List<OnboardingInterest> kOnboardingInterests = [
  OnboardingInterest(
    name: 'Daily',
    pubkeyHex: '3bbccf9927fb9dbb94b0c565218465094cde8e782e781d64d04b84514a425de0',
  ),
  OnboardingInterest(
    name: 'Tech',
    pubkeyHex: '71b0db2a9236ca44969bc3cab14aa1a49ff599ca2d24c8c544f9b3beb460e12b',
  ),
  OnboardingInterest(
    name: 'Motivation',
    pubkeyHex: '58f2f274ae07d57b0fc7f1047802afaa890fa65264ed73122a6863f9e527b150',
  ),
  OnboardingInterest(
    name: 'India',
    pubkeyHex: '981818c48d88cc9a70240eba2b801f00a9784503f1a2ee5c1df59ff88a987b24',
  ),
  OnboardingInterest(
    name: 'Europe',
    pubkeyHex: 'bb2daf156e25d591e34bffe562720da468bf769fb2232682604d4050d1c0cc36',
  ),
  OnboardingInterest(
    name: 'Asia',
    pubkeyHex: 'a82e72104fafdab40d7fe5d51f4fc05fac26968b4be53caa958631c7a758a32c',
  ),
  OnboardingInterest(
    name: 'Middle East',
    pubkeyHex: 'd8ded59d3f1de27235198f418f97c23521700e29b892bffbb242a3ae4890c327',
  ),
  OnboardingInterest(
    name: 'Africa',
    pubkeyHex: '1492ba8aea1aa8f63d637832ddb81dca7bca5e9e94edef7e9aa97d36f95ab643',
  ),
  OnboardingInterest(
    name: 'LatAm',
    pubkeyHex: 'a1927a2689751416c9f1f993d73756aea97c56e80da12614270b82a00de186eb',
  ),
  OnboardingInterest(
    name: 'Finance',
    pubkeyHex: '36bd9d3c1d8488ff8113f028f92eae80febde1dcf51e6715a73dc9aa53da58dc',
  ),
  OnboardingInterest(
    name: 'Startups',
    pubkeyHex: '4d7f8b9157ed9301258ee03540b6e38a47b682225847e8829da797050f45f33f',
  ),
  OnboardingInterest(
    name: 'Science',
    pubkeyHex: '930877dedb70cf90561b123312c078a695e2007c597cc850d76905c64145d421',
  ),
  OnboardingInterest(
    name: 'Energy',
    pubkeyHex: '58995c91f8a0b0e704fca2f75e9a2baa973291e9a5778304467cdd9b4a156e21',
  ),
];
