/// Filter options for store search: quality tier, membership warehouses, specific stores.
library;

/// Quality tiers: store name substrings (lowercase) that belong to each tier.
const Map<String, List<String>> qualityTierBrands = {
  'Premium': ['whole foods', "trader joe's", 'sprouts', 'fresh market', 'wegmans', 'publix greenwise'],
  'Standard': [
    'kroger', 'safeway', 'albertsons', 'publix', 'h-e-b', 'wegmans',
    'stop & shop', 'giant', 'food lion', 'harris teeter', 'meijer', 'hy-vee',
    'target', 'cvs', 'walgreens', 'rite aid', 'walmart neighborhood',
  ],
  'Budget': [
    'walmart', 'aldi', 'dollar general', 'dollar tree', 'family dollar',
    'costco', "sam's club", "bj's", 'lidl', 'food 4 less', 'save-a-lot',
  ],
};

/// Store name substrings (lowercase) for membership/warehouse clubs only.
const List<String> membershipStoreNames = [
  'costco', "sam's club", "bj's", 'bj\'s wholesale', 'warehouse',
];

/// Common store names for the "Specific stores" multi-select.
const List<String> commonStoresForFilter = [
  'Walmart',
  'Target',
  'CVS',
  'Walgreens',
  'Costco',
  "Sam's Club",
  'Kroger',
  'Safeway',
  'Aldi',
  'Whole Foods',
  "Trader Joe's",
  'Dollar General',
  'Dollar Tree',
  'Publix',
  'H-E-B',
  'BJ\'s',
  'Rite Aid',
  'Meijer',
  'Wegmans',
];

/// Returns true if [storeName] matches the given [qualityTier] (e.g. Premium, Standard, Budget).
bool storeMatchesQualityTier(String storeName, String qualityTier) {
  final brands = qualityTierBrands[qualityTier];
  if (brands == null) return true;
  final lower = storeName.toLowerCase();
  return brands.any((b) => lower.contains(b));
}

/// Returns true if [storeName] looks like a membership/warehouse club.
bool storeIsMembership(String storeName) {
  final lower = storeName.toLowerCase();
  return membershipStoreNames.any((m) => lower.contains(m));
}

/// Returns true if [storeName] contains any of the selected [storeFilters] (case-insensitive).
bool storeMatchesSpecificStores(String storeName, List<String> storeFilters) {
  if (storeFilters.isEmpty) return true;
  final lower = storeName.toLowerCase();
  return storeFilters.any((s) => lower.contains(s.toLowerCase()));
}
