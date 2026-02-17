/// Maps product search terms to relevant OpenStreetMap shop/amenity types.
///
/// Instead of querying Overpass for ALL shops (which returns bakeries,
/// hair salons, etc. for a "macbooks" search), this builds a targeted
/// regex filter so only stores that could plausibly sell the item appear.
library;

// ---------------------------------------------------------------------------
// Two tiers of "general" retail:
//
// Tier 1 — Big-box / department stores that sell almost everything.
//          Always included for ANY matched keyword.
//
// Tier 2 — Grocery / convenience stores.  Only included when the item
//          is something you'd actually find at a grocery store (food,
//          household, health, baby, cleaning, etc.).
// ---------------------------------------------------------------------------

const List<String> _bigBoxRetail = [
  'department_store',
  'variety_store',
  'general',
  'wholesale',
  'mall',
  'discount',
];

const List<String> _groceryRetail = [
  'supermarket',
  'convenience',
];

// Categories where grocery/convenience stores make sense.
const Set<String> _groceryCategories = {
  'grocery', 'food', 'health', 'baby', 'cleaning', 'household', 'personal_care',
};

// ---------------------------------------------------------------------------
// General amenities (always included).
// ---------------------------------------------------------------------------

const List<String> _generalAmenities = [
  'marketplace',
];

// ---------------------------------------------------------------------------
// Keyword → specialty shop types + a category tag.
// The category is used to decide whether to include grocery stores.
// ---------------------------------------------------------------------------

class _Mapping {
  final List<String> shopTypes;
  final String category; // used to decide grocery inclusion
  const _Mapping(this.shopTypes, this.category);
}

const Map<String, _Mapping> _keywordMap = {
  // ---- Electronics / tech / computers ----
  'battery': _Mapping(['electronics', 'hardware', 'doityourself', 'mobile_phone', 'computer'], 'electronics'),
  'batteries': _Mapping(['electronics', 'hardware', 'doityourself', 'mobile_phone', 'computer'], 'electronics'),
  'charger': _Mapping(['electronics', 'mobile_phone', 'computer', 'hardware'], 'electronics'),
  'cable': _Mapping(['electronics', 'mobile_phone', 'computer'], 'electronics'),
  'phone': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], 'electronics'),
  'iphone': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], 'electronics'),
  'samsung': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], 'electronics'),
  'android': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], 'electronics'),
  'headphones': _Mapping(['electronics', 'mobile_phone', 'computer', 'hifi'], 'electronics'),
  'earbuds': _Mapping(['electronics', 'mobile_phone', 'hifi'], 'electronics'),
  'airpods': _Mapping(['electronics', 'mobile_phone', 'hifi'], 'electronics'),
  'usb': _Mapping(['electronics', 'mobile_phone', 'computer'], 'electronics'),
  'adapter': _Mapping(['electronics', 'hardware', 'mobile_phone', 'computer'], 'electronics'),
  'lightbulb': _Mapping(['electronics', 'hardware', 'doityourself', 'lighting'], 'electronics'),
  'light bulb': _Mapping(['electronics', 'hardware', 'doityourself', 'lighting'], 'electronics'),
  'bulb': _Mapping(['electronics', 'hardware', 'doityourself', 'lighting'], 'electronics'),
  'flashlight': _Mapping(['electronics', 'hardware', 'doityourself', 'outdoor'], 'electronics'),
  'extension cord': _Mapping(['electronics', 'hardware', 'doityourself'], 'electronics'),
  'power strip': _Mapping(['electronics', 'hardware', 'doityourself'], 'electronics'),
  'sd card': _Mapping(['electronics', 'mobile_phone', 'computer'], 'electronics'),
  'memory card': _Mapping(['electronics', 'mobile_phone', 'computer'], 'electronics'),
  'speaker': _Mapping(['electronics', 'mobile_phone', 'computer', 'hifi'], 'electronics'),
  'laptop': _Mapping(['electronics', 'computer'], 'electronics'),
  'macbook': _Mapping(['electronics', 'computer'], 'electronics'),
  'chromebook': _Mapping(['electronics', 'computer'], 'electronics'),
  'computer': _Mapping(['electronics', 'computer'], 'electronics'),
  'pc': _Mapping(['electronics', 'computer'], 'electronics'),
  'desktop': _Mapping(['electronics', 'computer'], 'electronics'),
  'monitor': _Mapping(['electronics', 'computer'], 'electronics'),
  'keyboard': _Mapping(['electronics', 'computer'], 'electronics'),
  'mouse': _Mapping(['electronics', 'computer'], 'electronics'),
  'webcam': _Mapping(['electronics', 'computer'], 'electronics'),
  'tablet': _Mapping(['electronics', 'computer', 'mobile_phone'], 'electronics'),
  'ipad': _Mapping(['electronics', 'computer', 'mobile_phone'], 'electronics'),
  'printer': _Mapping(['electronics', 'computer'], 'electronics'),
  'ink': _Mapping(['electronics', 'computer', 'stationery'], 'electronics'),
  'toner': _Mapping(['electronics', 'computer', 'stationery'], 'electronics'),
  'tv': _Mapping(['electronics', 'hifi'], 'electronics'),
  'television': _Mapping(['electronics', 'hifi'], 'electronics'),
  'roku': _Mapping(['electronics', 'hifi'], 'electronics'),
  'firestick': _Mapping(['electronics', 'hifi'], 'electronics'),
  'xbox': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'playstation': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'ps5': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'nintendo': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'switch': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'video game': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'game': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'controller': _Mapping(['electronics', 'computer', 'games'], 'electronics'),
  'camera': _Mapping(['electronics', 'photo'], 'electronics'),
  'gopro': _Mapping(['electronics', 'photo', 'outdoor'], 'electronics'),
  'drone': _Mapping(['electronics', 'photo'], 'electronics'),
  'smart watch': _Mapping(['electronics', 'mobile_phone'], 'electronics'),
  'apple watch': _Mapping(['electronics', 'mobile_phone'], 'electronics'),
  'fitbit': _Mapping(['electronics', 'mobile_phone', 'sports'], 'electronics'),
  'router': _Mapping(['electronics', 'computer'], 'electronics'),
  'wifi': _Mapping(['electronics', 'computer'], 'electronics'),
  'hard drive': _Mapping(['electronics', 'computer'], 'electronics'),
  'ssd': _Mapping(['electronics', 'computer'], 'electronics'),

  // ---- Hardware / home improvement ----
  'nail': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'nails': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'screw': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'screws': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'drill': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'hammer': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'wrench': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'tool': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'tools': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'tape': _Mapping(['hardware', 'doityourself', 'stationery'], 'hardware'),
  'duct tape': _Mapping(['hardware', 'doityourself'], 'hardware'),
  'glue': _Mapping(['hardware', 'doityourself', 'stationery', 'craft'], 'hardware'),
  'paint': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'lock': _Mapping(['hardware', 'doityourself'], 'hardware'),
  'padlock': _Mapping(['hardware', 'doityourself'], 'hardware'),
  'plumbing': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'pipe': _Mapping(['hardware', 'doityourself', 'trade'], 'hardware'),
  'sandpaper': _Mapping(['hardware', 'doityourself'], 'hardware'),

  // ---- Medicine / health / first aid ----
  'medicine': _Mapping(['chemist'], 'health'),
  'aspirin': _Mapping(['chemist'], 'health'),
  'ibuprofen': _Mapping(['chemist'], 'health'),
  'tylenol': _Mapping(['chemist'], 'health'),
  'advil': _Mapping(['chemist'], 'health'),
  'bandaid': _Mapping(['chemist'], 'health'),
  'band-aid': _Mapping(['chemist'], 'health'),
  'bandage': _Mapping(['chemist'], 'health'),
  'first aid': _Mapping(['chemist'], 'health'),
  'thermometer': _Mapping(['chemist', 'electronics'], 'health'),
  'cough': _Mapping(['chemist'], 'health'),
  'cold medicine': _Mapping(['chemist'], 'health'),
  'allergy': _Mapping(['chemist'], 'health'),
  'vitamin': _Mapping(['chemist', 'health_food'], 'health'),
  'vitamins': _Mapping(['chemist', 'health_food'], 'health'),
  'sunscreen': _Mapping(['chemist'], 'health'),
  'antacid': _Mapping(['chemist'], 'health'),

  // ---- Baby / childcare ----
  'diaper': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'diapers': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'baby formula': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'formula': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'baby food': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'baby wipes': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'pacifier': _Mapping(['baby_goods', 'chemist'], 'baby'),
  'bottle': _Mapping(['baby_goods', 'chemist'], 'baby'),

  // ---- Grocery / food ----
  'milk': _Mapping(['dairy', 'farm', 'greengrocer', 'bakery', 'deli'], 'grocery'),
  'bread': _Mapping(['bakery', 'greengrocer', 'deli'], 'grocery'),
  'eggs': _Mapping(['farm', 'greengrocer', 'deli'], 'grocery'),
  'water': _Mapping(['beverages', 'outdoor'], 'grocery'),
  'fruit': _Mapping(['greengrocer', 'farm'], 'grocery'),
  'vegetable': _Mapping(['greengrocer', 'farm'], 'grocery'),
  'vegetables': _Mapping(['greengrocer', 'farm'], 'grocery'),
  'meat': _Mapping(['butcher', 'deli', 'farm'], 'grocery'),
  'chicken': _Mapping(['butcher', 'deli', 'farm'], 'grocery'),
  'beef': _Mapping(['butcher', 'deli', 'farm'], 'grocery'),
  'fish': _Mapping(['seafood', 'deli', 'farm'], 'grocery'),
  'cheese': _Mapping(['cheese', 'deli', 'farm'], 'grocery'),
  'rice': _Mapping(['greengrocer', 'deli'], 'grocery'),
  'pasta': _Mapping(['deli'], 'grocery'),
  'cereal': _Mapping([], 'grocery'),
  'snack': _Mapping(['bakery', 'confectionery'], 'grocery'),
  'snacks': _Mapping(['bakery', 'confectionery'], 'grocery'),
  'candy': _Mapping(['confectionery'], 'grocery'),
  'chocolate': _Mapping(['confectionery', 'bakery'], 'grocery'),
  'coffee': _Mapping(['coffee', 'beverages'], 'grocery'),
  'tea': _Mapping(['tea', 'beverages', 'health_food'], 'grocery'),
  'juice': _Mapping(['beverages', 'health_food'], 'grocery'),
  'soda': _Mapping(['beverages'], 'grocery'),
  'beer': _Mapping(['alcohol', 'beverages'], 'grocery'),
  'wine': _Mapping(['alcohol', 'beverages'], 'grocery'),
  'liquor': _Mapping(['alcohol', 'beverages'], 'grocery'),
  'ice cream': _Mapping(['ice_cream', 'frozen_food'], 'grocery'),
  'frozen': _Mapping(['frozen_food'], 'grocery'),
  'food': _Mapping(['deli', 'bakery', 'greengrocer'], 'grocery'),
  'grocery': _Mapping([], 'grocery'),
  'groceries': _Mapping([], 'grocery'),

  // ---- Cleaning / household ----
  'soap': _Mapping(['chemist', 'cosmetics'], 'household'),
  'detergent': _Mapping(['chemist'], 'household'),
  'bleach': _Mapping(['chemist'], 'household'),
  'sponge': _Mapping(['chemist', 'household'], 'household'),
  'trash bags': _Mapping(['chemist', 'household'], 'household'),
  'paper towels': _Mapping(['chemist', 'household'], 'household'),
  'paper towel': _Mapping(['chemist', 'household'], 'household'),
  'toilet paper': _Mapping(['chemist', 'household'], 'household'),
  'tissues': _Mapping(['chemist', 'household'], 'household'),
  'cleaning': _Mapping(['chemist', 'household'], 'cleaning'),

  // ---- Personal care ----
  'shampoo': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'conditioner': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'toothbrush': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'toothpaste': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'deodorant': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'razor': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'lotion': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'moisturizer': _Mapping(['chemist', 'cosmetics'], 'personal_care'),
  'makeup': _Mapping(['cosmetics', 'chemist'], 'personal_care'),
  'mascara': _Mapping(['cosmetics', 'chemist'], 'personal_care'),
  'lipstick': _Mapping(['cosmetics', 'chemist'], 'personal_care'),

  // ---- Pet ----
  'dog food': _Mapping(['pet'], 'pet'),
  'cat food': _Mapping(['pet'], 'pet'),
  'pet food': _Mapping(['pet'], 'pet'),
  'cat litter': _Mapping(['pet'], 'pet'),
  'leash': _Mapping(['pet'], 'pet'),
  'pet': _Mapping(['pet'], 'pet'),

  // ---- Auto ----
  'motor oil': _Mapping(['car_parts', 'car_repair', 'car'], 'auto'),
  'oil filter': _Mapping(['car_parts', 'car_repair'], 'auto'),
  'wiper': _Mapping(['car_parts', 'car_repair', 'car'], 'auto'),
  'antifreeze': _Mapping(['car_parts', 'car_repair'], 'auto'),
  'tire': _Mapping(['car_parts', 'car_repair', 'tyres'], 'auto'),
  'gas': _Mapping(['car_parts', 'car_repair'], 'auto'),
  'gasoline': _Mapping([], 'auto'),

  // ---- Clothing ----
  'shirt': _Mapping(['clothes', 'fashion', 'boutique'], 'clothing'),
  'pants': _Mapping(['clothes', 'fashion', 'boutique'], 'clothing'),
  'shoes': _Mapping(['shoes', 'clothes', 'fashion'], 'clothing'),
  'socks': _Mapping(['clothes', 'fashion'], 'clothing'),
  'jacket': _Mapping(['clothes', 'fashion', 'outdoor'], 'clothing'),
  'coat': _Mapping(['clothes', 'fashion', 'outdoor'], 'clothing'),
  'hat': _Mapping(['clothes', 'fashion'], 'clothing'),
  'gloves': _Mapping(['clothes', 'fashion', 'outdoor', 'hardware', 'doityourself'], 'clothing'),
  'underwear': _Mapping(['clothes', 'fashion'], 'clothing'),
  'dress': _Mapping(['clothes', 'fashion', 'boutique'], 'clothing'),

  // ---- Office / school ----
  'pen': _Mapping(['stationery', 'books'], 'office'),
  'pencil': _Mapping(['stationery', 'books'], 'office'),
  'notebook': _Mapping(['stationery', 'books'], 'office'),
  'paper': _Mapping(['stationery', 'books'], 'office'),
  'envelope': _Mapping(['stationery', 'books'], 'office'),
  'stapler': _Mapping(['stationery'], 'office'),
  'binder': _Mapping(['stationery', 'books'], 'office'),
  'folder': _Mapping(['stationery', 'books'], 'office'),
  'backpack': _Mapping(['bag', 'outdoor', 'clothes'], 'office'),

  // ---- Outdoor / camping / safety ----
  'mask': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], 'health'),
  'masks': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], 'health'),
  'n95': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], 'health'),
  'tent': _Mapping(['outdoor', 'sports'], 'outdoor'),
  'sleeping bag': _Mapping(['outdoor', 'sports'], 'outdoor'),
  'camping': _Mapping(['outdoor', 'sports'], 'outdoor'),
  'propane': _Mapping(['outdoor', 'hardware', 'doityourself'], 'outdoor'),
  'fire extinguisher': _Mapping(['hardware', 'doityourself'], 'outdoor'),
  'lantern': _Mapping(['outdoor', 'hardware'], 'outdoor'),

  // ---- Sports / fitness ----
  'ball': _Mapping(['sports'], 'sports'),
  'weights': _Mapping(['sports'], 'sports'),
  'yoga': _Mapping(['sports'], 'sports'),
  'bicycle': _Mapping(['bicycle'], 'sports'),
  'bike': _Mapping(['bicycle'], 'sports'),
  'helmet': _Mapping(['bicycle', 'sports', 'motorcycle'], 'sports'),

  // ---- Garden ----
  'plant': _Mapping(['garden_centre', 'florist'], 'garden'),
  'plants': _Mapping(['garden_centre', 'florist'], 'garden'),
  'soil': _Mapping(['garden_centre', 'doityourself'], 'garden'),
  'fertilizer': _Mapping(['garden_centre', 'doityourself'], 'garden'),
  'seeds': _Mapping(['garden_centre'], 'garden'),
  'hose': _Mapping(['garden_centre', 'hardware', 'doityourself'], 'garden'),
  'lawn': _Mapping(['garden_centre', 'hardware', 'doityourself'], 'garden'),
  'mower': _Mapping(['garden_centre', 'hardware', 'doityourself'], 'garden'),
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Given a user's search [item], returns an Overpass `shop` regex filter
/// that targets only relevant store types.
///
/// - Big-box retail (department_store, wholesale, mall) always included.
/// - Grocery/convenience stores ONLY included for grocery/food/health/baby items.
/// - Specialty types added based on keyword matches.
/// - Returns null if no keywords matched (caller should use a broad search).
String? shopFilterForItem(String item) {
  final lower = item.toLowerCase().trim();

  final specialtyTypes = <String>{};
  final categories = <String>{};

  _keywordMap.forEach((keyword, mapping) {
    if (lower.contains(keyword)) {
      specialtyTypes.addAll(mapping.shopTypes);
      categories.add(mapping.category);
    }
  });

  // If nothing matched, return null — the caller decides what to do.
  if (specialtyTypes.isEmpty && categories.isEmpty) return null;

  // Always include big-box retail.
  final allTypes = <String>{..._bigBoxRetail, ...specialtyTypes};

  // Only include grocery stores for items you'd actually find there.
  if (categories.any((c) => _groceryCategories.contains(c))) {
    allTypes.addAll(_groceryRetail);
  }

  return allTypes.join('|');
}

/// Returns the amenity regex to use in the Overpass query.
String amenityFilterForItem(String item) {
  final lower = item.toLowerCase().trim();
  final amenities = <String>{..._generalAmenities};

  // Add pharmacy/chemist amenity for health-related searches.
  const healthKeywords = [
    'medicine', 'aspirin', 'ibuprofen', 'tylenol', 'advil',
    'bandaid', 'band-aid', 'bandage', 'first aid', 'thermometer',
    'cough', 'cold medicine', 'allergy', 'vitamin', 'vitamins',
    'sunscreen', 'antacid', 'diaper', 'diapers', 'baby formula',
    'formula', 'mask', 'masks', 'n95',
  ];
  if (healthKeywords.any((k) => lower.contains(k))) {
    amenities.add('pharmacy');
    amenities.add('clinic');
  }

  // Add fuel for auto-related searches.
  const autoKeywords = ['gas', 'gasoline', 'motor oil', 'antifreeze', 'wiper'];
  if (autoKeywords.any((k) => lower.contains(k))) {
    amenities.add('fuel');
  }

  return amenities.join('|');
}
