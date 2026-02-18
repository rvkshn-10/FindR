/// Content safety filter for search queries.
///
/// Blocks searches for illegal, dangerous, or harmful items using a local
/// keyword check. No network call needed — runs instantly.
library;

class SafetyCheckResult {
  final bool blocked;
  final String? reason;

  const SafetyCheckResult({this.blocked = false, this.reason});
  const SafetyCheckResult.ok() : blocked = false, reason = null;
  const SafetyCheckResult.blocked(String this.reason) : blocked = true;
}

SafetyCheckResult checkQuerySafety(String query) {
  final lower = query.toLowerCase().trim();
  if (lower.isEmpty) return const SafetyCheckResult.ok();

  for (final entry in _blockedPatterns) {
    for (final term in entry.terms) {
      if (_matches(lower, term)) {
        return SafetyCheckResult.blocked(entry.message);
      }
    }
  }

  return const SafetyCheckResult.ok();
}

bool _matches(String query, String term) {
  if (term.startsWith('*') && term.endsWith('*')) {
    return query.contains(term.substring(1, term.length - 1));
  }
  final words = query.split(RegExp(r'\s+'));
  if (words.contains(term)) return true;
  if (query.contains(term) && term.contains(' ')) return true;
  return false;
}

class _BlockedCategory {
  final String message;
  final List<String> terms;
  const _BlockedCategory(this.message, this.terms);
}

const List<_BlockedCategory> _blockedPatterns = [
  // ── Explosives & weapons ──
  _BlockedCategory(
    'Searches for weapons or explosives are not allowed.',
    [
      'bomb', 'bombs', 'bombing',
      'explosive', 'explosives',
      'dynamite', 'tnt', 'c4', 'c-4',
      'detonator', 'detonators',
      'grenade', 'grenades',
      'landmine', 'land mine',
      'ied', 'pipe bomb',
      'molotov', 'molotov cocktail',
      'napalm', 'thermite',
      'semtex', 'nitroglycerin',
      'ammonium nitrate bomb',
      '*how to make a bomb*',
      '*how to build a bomb*',
      '*make an explosive*',
      '*build a weapon*',
    ],
  ),

  // ── Firearms (illegal context) ──
  _BlockedCategory(
    'Searches for illegal firearms or weapon modifications are not allowed.',
    [
      'ghost gun', 'ghost guns',
      'untraceable gun', 'untraceable firearm',
      'illegal gun', 'illegal firearm',
      'full auto conversion', 'auto sear',
      'bump stock',
      'silencer', 'suppressor',
      'sawed off shotgun', 'sawed-off',
      '3d printed gun',
      '*how to make a gun*',
      '*build a gun*',
    ],
  ),

  // ── Drugs & narcotics ──
  _BlockedCategory(
    'Searches for illegal drugs or controlled substances are not allowed.',
    [
      'cocaine', 'crack cocaine', 'crack',
      'heroin', 'fentanyl',
      'methamphetamine', 'meth', 'crystal meth',
      'mdma', 'ecstasy', 'molly',
      'lsd', 'acid tab', 'acid tabs',
      'psilocybin', 'magic mushrooms', 'shrooms',
      'ketamine', 'special k',
      'pcp', 'angel dust',
      'ghb', 'date rape drug',
      'opium', 'oxycodone', 'oxycontin',
      'xanax', 'percocet', 'adderall',
      'codeine', 'lean', 'purple drank',
      'bath salts', 'synthetic cathinone',
      'spice drug', 'k2 drug',
      'dmt', 'ayahuasca',
      'drug dealer', 'drug dealers',
      '*buy drugs*', '*sell drugs*',
      '*where to get drugs*',
    ],
  ),

  // ── Drug paraphernalia ──
  _BlockedCategory(
    'Searches for drug paraphernalia are not allowed.',
    [
      'crack pipe', 'meth pipe',
      'heroin needle', 'drug needle',
      '*how to cook meth*',
      '*how to make drugs*',
      '*how to grow weed*',
    ],
  ),

  // ── Poisons & toxic substances (harmful intent) ──
  _BlockedCategory(
    'Searches for poisons or harmful substances are not allowed.',
    [
      'poison someone', 'poisoning someone',
      'ricin', 'cyanide',
      'arsenic poison',
      'sarin', 'nerve agent', 'nerve gas',
      'anthrax', 'bioweapon', 'bio weapon',
      'chemical weapon', 'chemical weapons',
      '*how to poison*',
      '*how to make poison*',
      '*undetectable poison*',
    ],
  ),

  // ── Human trafficking & exploitation ──
  _BlockedCategory(
    'This type of search is not allowed.',
    [
      'human trafficking',
      'buy a person', 'buy people',
      'sex trafficking',
      'child exploitation',
      '*buy a slave*',
      '*sell a person*',
    ],
  ),

  // ── Counterfeiting & fraud ──
  _BlockedCategory(
    'Searches related to counterfeiting or fraud are not allowed.',
    [
      'counterfeit money', 'counterfeit bills',
      'fake money', 'fake currency',
      'fake id', 'fake ids', 'fake identification',
      'fake passport', 'fake license',
      'credit card skimmer', 'card skimmer',
      '*how to counterfeit*',
      '*how to forge*',
    ],
  ),

  // ── Theft & burglary tools ──
  _BlockedCategory(
    'Searches for theft or burglary tools are not allowed.',
    [
      'lock pick set', 'lockpick set',
      'slim jim car', 'car jacking tool',
      'bump key', 'bump keys',
      '*how to pick a lock*',
      '*how to break into*',
      '*how to steal*',
      '*how to shoplift*',
      '*how to hotwire*',
    ],
  ),

  // ── Self-harm ──
  _BlockedCategory(
    'If you are in crisis, please call 988 (Suicide & Crisis Lifeline) or text HOME to 741741.',
    [
      '*how to kill myself*',
      '*how to end my life*',
      '*suicide method*',
      '*ways to die*',
    ],
  ),

  // ── Harm to others ──
  _BlockedCategory(
    'Searches that involve harming others are not allowed.',
    [
      '*how to kill someone*',
      '*how to murder*',
      '*how to hurt someone*',
      '*how to kidnap*',
      '*how to assault*',
      'hit man', 'hitman',
      'hire a killer', 'assassin for hire',
    ],
  ),
];
