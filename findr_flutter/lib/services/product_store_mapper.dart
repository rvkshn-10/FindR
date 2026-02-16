/// Maps product search terms to relevant OpenStreetMap shop/amenity types.
///
/// Instead of querying Overpass for ALL shops (which returns bakeries,
/// hair salons, etc. for a "batteries" search), this builds a targeted
/// regex filter so only stores that could plausibly sell the item appear.
library;

// ---------------------------------------------------------------------------
// General-retail store types: these sell a wide range of products and should
// ALWAYS be included regardless of what the user searches.
// ---------------------------------------------------------------------------

const List<String> _generalRetailShops = [
  'supermarket',
  'convenience',
  'department_store',
  'variety_store',
  'general',
  'wholesale',
  'mall',
  'discount',
  'trade',
];

// ---------------------------------------------------------------------------
// Amenity types that are always included (pharmacies sell many general items,
// fuel stations have convenience sections, marketplaces are general).
// ---------------------------------------------------------------------------

const List<String> _generalAmenities = [
  'marketplace',
  'pharmacy',
  'fuel',
];

// ---------------------------------------------------------------------------
// Product keyword → additional specialty shop types to include.
// Each list is ADDED on top of the general-retail set above.
// ---------------------------------------------------------------------------

const Map<String, List<String>> _keywordToShopTypes = {
  // Electronics / batteries / tech
  'battery': ['electronics', 'hardware', 'doityourself', 'mobile_phone', 'computer'],
  'batteries': ['electronics', 'hardware', 'doityourself', 'mobile_phone', 'computer'],
  'charger': ['electronics', 'mobile_phone', 'computer', 'hardware'],
  'cable': ['electronics', 'mobile_phone', 'computer'],
  'phone': ['electronics', 'mobile_phone', 'computer', 'telecommunication'],
  'headphones': ['electronics', 'mobile_phone', 'computer'],
  'earbuds': ['electronics', 'mobile_phone'],
  'usb': ['electronics', 'mobile_phone', 'computer'],
  'adapter': ['electronics', 'hardware', 'mobile_phone', 'computer'],
  'lightbulb': ['electronics', 'hardware', 'doityourself', 'lighting'],
  'light bulb': ['electronics', 'hardware', 'doityourself', 'lighting'],
  'bulb': ['electronics', 'hardware', 'doityourself', 'lighting'],
  'flashlight': ['electronics', 'hardware', 'doityourself', 'outdoor'],
  'extension cord': ['electronics', 'hardware', 'doityourself'],
  'power strip': ['electronics', 'hardware', 'doityourself'],
  'sd card': ['electronics', 'mobile_phone', 'computer'],
  'memory card': ['electronics', 'mobile_phone', 'computer'],
  'speaker': ['electronics', 'mobile_phone', 'computer', 'hifi'],
  'laptop': ['electronics', 'computer'],
  'tablet': ['electronics', 'computer', 'mobile_phone'],
  'printer': ['electronics', 'computer'],
  'ink': ['electronics', 'computer', 'stationery'],
  'toner': ['electronics', 'computer', 'stationery'],

  // Hardware / home improvement
  'nail': ['hardware', 'doityourself', 'trade'],
  'nails': ['hardware', 'doityourself', 'trade'],
  'screw': ['hardware', 'doityourself', 'trade'],
  'screws': ['hardware', 'doityourself', 'trade'],
  'drill': ['hardware', 'doityourself', 'trade'],
  'hammer': ['hardware', 'doityourself', 'trade'],
  'wrench': ['hardware', 'doityourself', 'trade'],
  'tool': ['hardware', 'doityourself', 'trade'],
  'tools': ['hardware', 'doityourself', 'trade'],
  'tape': ['hardware', 'doityourself', 'stationery'],
  'duct tape': ['hardware', 'doityourself'],
  'glue': ['hardware', 'doityourself', 'stationery', 'craft'],
  'paint': ['hardware', 'doityourself', 'trade'],
  'lock': ['hardware', 'doityourself'],
  'padlock': ['hardware', 'doityourself'],
  'plumbing': ['hardware', 'doityourself', 'trade'],
  'pipe': ['hardware', 'doityourself', 'trade'],
  'sandpaper': ['hardware', 'doityourself'],

  // Medicine / health / first aid
  'medicine': ['chemist'],
  'aspirin': ['chemist'],
  'ibuprofen': ['chemist'],
  'tylenol': ['chemist'],
  'advil': ['chemist'],
  'bandaid': ['chemist'],
  'band-aid': ['chemist'],
  'bandage': ['chemist'],
  'first aid': ['chemist'],
  'thermometer': ['chemist', 'electronics'],
  'cough': ['chemist'],
  'cold medicine': ['chemist'],
  'allergy': ['chemist'],
  'vitamin': ['chemist', 'health_food'],
  'vitamins': ['chemist', 'health_food'],
  'sunscreen': ['chemist'],
  'antacid': ['chemist'],

  // Baby / childcare
  'diaper': ['baby_goods', 'chemist'],
  'diapers': ['baby_goods', 'chemist'],
  'baby formula': ['baby_goods', 'chemist'],
  'formula': ['baby_goods', 'chemist'],
  'baby food': ['baby_goods', 'chemist'],
  'baby wipes': ['baby_goods', 'chemist'],
  'pacifier': ['baby_goods', 'chemist'],
  'bottle': ['baby_goods', 'chemist'],

  // Grocery / food
  'milk': ['dairy', 'farm', 'greengrocer', 'bakery', 'deli'],
  'bread': ['bakery', 'greengrocer', 'deli'],
  'eggs': ['farm', 'greengrocer', 'deli'],
  'water': ['beverages', 'outdoor'],
  'fruit': ['greengrocer', 'farm'],
  'vegetable': ['greengrocer', 'farm'],
  'vegetables': ['greengrocer', 'farm'],
  'meat': ['butcher', 'deli', 'farm'],
  'chicken': ['butcher', 'deli', 'farm'],
  'beef': ['butcher', 'deli', 'farm'],
  'fish': ['seafood', 'deli', 'farm'],
  'cheese': ['cheese', 'deli', 'farm'],
  'rice': ['greengrocer', 'deli'],
  'pasta': ['deli'],
  'cereal': [],
  'snack': ['bakery', 'confectionery'],
  'snacks': ['bakery', 'confectionery'],
  'candy': ['confectionery'],
  'chocolate': ['confectionery', 'bakery'],
  'coffee': ['coffee', 'beverages'],
  'tea': ['tea', 'beverages', 'health_food'],
  'juice': ['beverages', 'health_food'],
  'soda': ['beverages'],
  'beer': ['alcohol', 'beverages'],
  'wine': ['alcohol', 'beverages'],
  'liquor': ['alcohol', 'beverages'],
  'ice cream': ['ice_cream', 'frozen_food'],
  'frozen': ['frozen_food'],

  // Cleaning / household
  'soap': ['chemist', 'cosmetics'],
  'detergent': ['chemist'],
  'bleach': ['chemist'],
  'sponge': ['chemist', 'household'],
  'trash bags': ['chemist', 'household'],
  'paper towels': ['chemist', 'household'],
  'paper towel': ['chemist', 'household'],
  'toilet paper': ['chemist', 'household'],
  'tissues': ['chemist', 'household'],
  'cleaning': ['chemist', 'household'],

  // Personal care
  'shampoo': ['chemist', 'cosmetics'],
  'conditioner': ['chemist', 'cosmetics'],
  'toothbrush': ['chemist', 'cosmetics'],
  'toothpaste': ['chemist', 'cosmetics'],
  'deodorant': ['chemist', 'cosmetics'],
  'razor': ['chemist', 'cosmetics'],
  'lotion': ['chemist', 'cosmetics'],
  'moisturizer': ['chemist', 'cosmetics'],
  'makeup': ['cosmetics', 'chemist'],
  'mascara': ['cosmetics', 'chemist'],
  'lipstick': ['cosmetics', 'chemist'],

  // Pet
  'dog food': ['pet'],
  'cat food': ['pet'],
  'pet food': ['pet'],
  'cat litter': ['pet'],
  'leash': ['pet'],
  'pet': ['pet'],

  // Auto
  'motor oil': ['car_parts', 'car_repair', 'car'],
  'oil filter': ['car_parts', 'car_repair'],
  'wiper': ['car_parts', 'car_repair', 'car'],
  'antifreeze': ['car_parts', 'car_repair'],
  'tire': ['car_parts', 'car_repair', 'tyres'],
  'gas': ['car_parts', 'car_repair'],
  'gasoline': [],

  // Clothing
  'shirt': ['clothes', 'fashion', 'boutique'],
  'pants': ['clothes', 'fashion', 'boutique'],
  'shoes': ['shoes', 'clothes', 'fashion'],
  'socks': ['clothes', 'fashion'],
  'jacket': ['clothes', 'fashion', 'outdoor'],
  'coat': ['clothes', 'fashion', 'outdoor'],
  'hat': ['clothes', 'fashion'],
  'gloves': ['clothes', 'fashion', 'outdoor', 'hardware', 'doityourself'],
  'underwear': ['clothes', 'fashion'],
  'dress': ['clothes', 'fashion', 'boutique'],

  // Office / school
  'pen': ['stationery', 'books'],
  'pencil': ['stationery', 'books'],
  'notebook': ['stationery', 'books'],
  'paper': ['stationery', 'books'],
  'envelope': ['stationery', 'books'],
  'stapler': ['stationery'],
  'binder': ['stationery', 'books'],
  'folder': ['stationery', 'books'],
  'backpack': ['bag', 'outdoor', 'clothes'],

  // Outdoor / camping / safety
  'mask': ['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'],
  'masks': ['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'],
  'n95': ['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'],
  'tent': ['outdoor', 'sports'],
  'sleeping bag': ['outdoor', 'sports'],
  'camping': ['outdoor', 'sports'],
  'propane': ['outdoor', 'hardware', 'doityourself'],
  'fire extinguisher': ['hardware', 'doityourself'],
  'lantern': ['outdoor', 'hardware'],

  // Sports / fitness
  'ball': ['sports'],
  'weights': ['sports'],
  'yoga': ['sports'],
  'bicycle': ['bicycle'],
  'bike': ['bicycle'],
  'helmet': ['bicycle', 'sports', 'motorcycle'],

  // Garden
  'plant': ['garden_centre', 'florist'],
  'plants': ['garden_centre', 'florist'],
  'soil': ['garden_centre', 'doityourself'],
  'fertilizer': ['garden_centre', 'doityourself'],
  'seeds': ['garden_centre'],
  'hose': ['garden_centre', 'hardware', 'doityourself'],
  'lawn': ['garden_centre', 'hardware', 'doityourself'],
  'mower': ['garden_centre', 'hardware', 'doityourself'],
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Given a user's search [item], returns an Overpass `shop` regex filter
/// that targets only relevant store types (general retail + specialty).
///
/// Example return: `"supermarket|convenience|department_store|electronics|hardware"`
String shopFilterForItem(String item) {
  final lower = item.toLowerCase().trim();

  // Collect specialty types from keyword matches.
  final specialtyTypes = <String>{};
  _keywordToShopTypes.forEach((keyword, shopTypes) {
    if (lower.contains(keyword)) {
      specialtyTypes.addAll(shopTypes);
    }
  });

  // Combine general retail + matched specialty types.
  final allTypes = <String>{..._generalRetailShops, ...specialtyTypes};
  return allTypes.join('|');
}

/// Returns the amenity regex to use in the Overpass query.
/// Always includes general amenities; may expand for certain products.
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

  return amenities.join('|');
}
