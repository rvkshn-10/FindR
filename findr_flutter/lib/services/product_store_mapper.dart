/// Maps product search terms to relevant OpenStreetMap shop/amenity types.
///
/// Builds targeted Overpass regex filters so only stores and places that
/// could plausibly sell or serve the item appear in results.
library;

// ---------------------------------------------------------------------------
// Two tiers of "general" retail:
//
// Tier 1 — Big-box / department stores that sell almost everything.
//          Included for ANY matched product keyword (not dining).
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

// Categories that are restaurants/dining — NOT retail products.
const Set<String> _diningCategories = {
  'dining',
};

// ---------------------------------------------------------------------------
// Keyword → shop types + amenity types + category tag.
// ---------------------------------------------------------------------------

class _Mapping {
  final List<String> shopTypes;
  final List<String> amenityTypes;
  final String category;
  const _Mapping(this.shopTypes, this.amenityTypes, this.category);
}

const Map<String, _Mapping> _keywordMap = {
  // =====================================================================
  //  DINING / RESTAURANTS / PREPARED FOOD
  //  These map to amenity types (restaurant, fast_food, cafe, etc.),
  //  NOT to big-box retail.  "cookie" → bakery + cafe, not Walmart.
  // =====================================================================

  // -- Burgers --
  'burger': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'burgers': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'hamburger': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'cheeseburger': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'whopper': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'big mac': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'mcdonalds': _Mapping([], ['fast_food'], 'dining'),
  "mcdonald's": _Mapping([], ['fast_food'], 'dining'),
  'wendys': _Mapping([], ['fast_food'], 'dining'),
  "wendy's": _Mapping([], ['fast_food'], 'dining'),
  'burger king': _Mapping([], ['fast_food'], 'dining'),
  'five guys': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'shake shack': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'in-n-out': _Mapping([], ['fast_food'], 'dining'),
  'whataburger': _Mapping([], ['fast_food'], 'dining'),

  // -- Pizza --
  'pizza': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'dominos': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  "domino's": _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'papa johns': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  "papa john's": _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'pizza hut': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'little caesars': _Mapping([], ['fast_food'], 'dining'),

  // -- Cookies / sweets / desserts --
  'cookie': _Mapping(['bakery', 'confectionery'], ['cafe', 'fast_food'], 'dining'),
  'cookies': _Mapping(['bakery', 'confectionery'], ['cafe', 'fast_food'], 'dining'),
  'crumbl': _Mapping(['bakery', 'confectionery'], ['cafe', 'fast_food'], 'dining'),
  'insomnia cookies': _Mapping(['bakery'], ['cafe', 'fast_food'], 'dining'),
  'donut': _Mapping(['bakery', 'confectionery'], ['cafe', 'fast_food'], 'dining'),
  'donuts': _Mapping(['bakery', 'confectionery'], ['cafe', 'fast_food'], 'dining'),
  'doughnut': _Mapping(['bakery', 'confectionery'], ['cafe', 'fast_food'], 'dining'),
  'krispy kreme': _Mapping(['bakery'], ['cafe', 'fast_food'], 'dining'),
  'dunkin': _Mapping(['bakery'], ['cafe', 'fast_food'], 'dining'),
  'cake': _Mapping(['bakery', 'confectionery'], ['cafe'], 'dining'),
  'cupcake': _Mapping(['bakery', 'confectionery'], ['cafe'], 'dining'),
  'pastry': _Mapping(['bakery', 'confectionery'], ['cafe'], 'dining'),
  'dessert': _Mapping(['bakery', 'confectionery', 'ice_cream'], ['cafe', 'restaurant'], 'dining'),
  'milkshake': _Mapping(['ice_cream'], ['cafe', 'fast_food'], 'dining'),
  'smoothie': _Mapping([], ['cafe', 'fast_food'], 'dining'),
  'froyo': _Mapping(['ice_cream'], ['cafe', 'fast_food'], 'dining'),
  'frozen yogurt': _Mapping(['ice_cream'], ['cafe', 'fast_food'], 'dining'),
  'boba': _Mapping([], ['cafe', 'fast_food'], 'dining'),
  'bubble tea': _Mapping([], ['cafe', 'fast_food'], 'dining'),

  // -- Mexican --
  'taco': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'tacos': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'burrito': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'burritos': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'quesadilla': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'nachos': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'chipotle': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'taco bell': _Mapping([], ['fast_food'], 'dining'),

  // -- Chicken --
  'fried chicken': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'chicken nuggets': _Mapping([], ['fast_food'], 'dining'),
  'chicken sandwich': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'chick-fil-a': _Mapping([], ['fast_food'], 'dining'),
  'popeyes': _Mapping([], ['fast_food'], 'dining'),
  'kfc': _Mapping([], ['fast_food'], 'dining'),
  'wingstop': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'wings': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'buffalo wings': _Mapping([], ['restaurant', 'fast_food'], 'dining'),

  // -- Sandwich / sub --
  'sandwich': _Mapping(['deli'], ['restaurant', 'fast_food', 'cafe'], 'dining'),
  'sandwiches': _Mapping(['deli'], ['restaurant', 'fast_food', 'cafe'], 'dining'),
  'sub': _Mapping(['deli'], ['fast_food', 'restaurant'], 'dining'),
  'subway': _Mapping([], ['fast_food'], 'dining'),
  'jersey mikes': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  "jersey mike's": _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'jimmy johns': _Mapping([], ['fast_food'], 'dining'),
  "jimmy john's": _Mapping([], ['fast_food'], 'dining'),
  'panera': _Mapping([], ['fast_food', 'restaurant', 'cafe'], 'dining'),

  // -- Asian --
  'sushi': _Mapping([], ['restaurant'], 'dining'),
  'ramen': _Mapping([], ['restaurant'], 'dining'),
  'pho': _Mapping([], ['restaurant'], 'dining'),
  'chinese food': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'chinese': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'thai food': _Mapping([], ['restaurant'], 'dining'),
  'thai': _Mapping([], ['restaurant'], 'dining'),
  'korean bbq': _Mapping([], ['restaurant'], 'dining'),
  'indian food': _Mapping([], ['restaurant'], 'dining'),
  'curry': _Mapping([], ['restaurant'], 'dining'),
  'panda express': _Mapping([], ['fast_food'], 'dining'),
  'teriyaki': _Mapping([], ['restaurant', 'fast_food'], 'dining'),

  // -- General dining --
  'breakfast': _Mapping([], ['restaurant', 'cafe', 'fast_food'], 'dining'),
  'brunch': _Mapping([], ['restaurant', 'cafe'], 'dining'),
  'lunch': _Mapping([], ['restaurant', 'cafe', 'fast_food'], 'dining'),
  'dinner': _Mapping([], ['restaurant'], 'dining'),
  'restaurant': _Mapping([], ['restaurant'], 'dining'),
  'fast food': _Mapping([], ['fast_food'], 'dining'),
  'drive thru': _Mapping([], ['fast_food'], 'dining'),
  'drive through': _Mapping([], ['fast_food'], 'dining'),
  'takeout': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'dine in': _Mapping([], ['restaurant'], 'dining'),
  'steak': _Mapping([], ['restaurant'], 'dining'),
  'steakhouse': _Mapping([], ['restaurant'], 'dining'),
  'bbq': _Mapping([], ['restaurant'], 'dining'),
  'barbecue': _Mapping([], ['restaurant'], 'dining'),
  'seafood': _Mapping(['seafood'], ['restaurant'], 'dining'),
  'salad': _Mapping([], ['restaurant', 'fast_food', 'cafe'], 'dining'),
  'soup': _Mapping([], ['restaurant', 'cafe'], 'dining'),
  'noodles': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'fries': _Mapping([], ['fast_food', 'restaurant'], 'dining'),
  'hot dog': _Mapping([], ['fast_food'], 'dining'),
  'hot dogs': _Mapping([], ['fast_food'], 'dining'),
  'waffle': _Mapping([], ['restaurant', 'cafe', 'fast_food'], 'dining'),
  'waffles': _Mapping([], ['restaurant', 'cafe', 'fast_food'], 'dining'),
  'pancake': _Mapping([], ['restaurant', 'cafe'], 'dining'),
  'pancakes': _Mapping([], ['restaurant', 'cafe'], 'dining'),

  // -- Coffee shops (dining, not grocery coffee) --
  'starbucks': _Mapping([], ['cafe'], 'dining'),
  'dunkin donuts': _Mapping([], ['cafe', 'fast_food'], 'dining'),
  'latte': _Mapping([], ['cafe'], 'dining'),
  'espresso': _Mapping([], ['cafe'], 'dining'),
  'cappuccino': _Mapping([], ['cafe'], 'dining'),
  'mocha': _Mapping([], ['cafe'], 'dining'),
  'frappuccino': _Mapping([], ['cafe'], 'dining'),
  'coffee shop': _Mapping([], ['cafe'], 'dining'),
  'cafe': _Mapping([], ['cafe'], 'dining'),

  // -- Ice cream (dining) --
  'ice cream': _Mapping(['ice_cream'], ['cafe', 'fast_food'], 'dining'),
  'gelato': _Mapping(['ice_cream'], ['cafe'], 'dining'),
  'baskin robbins': _Mapping(['ice_cream'], ['cafe', 'fast_food'], 'dining'),
  'dairy queen': _Mapping(['ice_cream'], ['fast_food'], 'dining'),
  'cold stone': _Mapping(['ice_cream'], ['cafe'], 'dining'),

  // =====================================================================
  //  RETAIL PRODUCTS (shop types, not restaurants)
  // =====================================================================

  // ---- Electronics / tech / computers ----
  'battery': _Mapping(['electronics', 'hardware', 'doityourself', 'mobile_phone', 'computer'], [], 'electronics'),
  'batteries': _Mapping(['electronics', 'hardware', 'doityourself', 'mobile_phone', 'computer'], [], 'electronics'),
  'charger': _Mapping(['electronics', 'mobile_phone', 'computer', 'hardware'], [], 'electronics'),
  'cable': _Mapping(['electronics', 'mobile_phone', 'computer'], [], 'electronics'),
  'phone': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], [], 'electronics'),
  'iphone': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], [], 'electronics'),
  'samsung': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], [], 'electronics'),
  'android': _Mapping(['electronics', 'mobile_phone', 'computer', 'telecommunication'], [], 'electronics'),
  'headphones': _Mapping(['electronics', 'mobile_phone', 'computer', 'hifi'], [], 'electronics'),
  'earbuds': _Mapping(['electronics', 'mobile_phone', 'hifi'], [], 'electronics'),
  'airpods': _Mapping(['electronics', 'mobile_phone', 'hifi'], [], 'electronics'),
  'usb': _Mapping(['electronics', 'mobile_phone', 'computer'], [], 'electronics'),
  'adapter': _Mapping(['electronics', 'hardware', 'mobile_phone', 'computer'], [], 'electronics'),
  'lightbulb': _Mapping(['electronics', 'hardware', 'doityourself', 'lighting'], [], 'electronics'),
  'light bulb': _Mapping(['electronics', 'hardware', 'doityourself', 'lighting'], [], 'electronics'),
  'bulb': _Mapping(['electronics', 'hardware', 'doityourself', 'lighting'], [], 'electronics'),
  'flashlight': _Mapping(['electronics', 'hardware', 'doityourself', 'outdoor'], [], 'electronics'),
  'extension cord': _Mapping(['electronics', 'hardware', 'doityourself'], [], 'electronics'),
  'power strip': _Mapping(['electronics', 'hardware', 'doityourself'], [], 'electronics'),
  'sd card': _Mapping(['electronics', 'mobile_phone', 'computer'], [], 'electronics'),
  'memory card': _Mapping(['electronics', 'mobile_phone', 'computer'], [], 'electronics'),
  'speaker': _Mapping(['electronics', 'mobile_phone', 'computer', 'hifi'], [], 'electronics'),
  'laptop': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'macbook': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'chromebook': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'computer': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'pc': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'desktop': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'monitor': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'keyboard': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'mouse': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'webcam': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'tablet': _Mapping(['electronics', 'computer', 'mobile_phone'], [], 'electronics'),
  'ipad': _Mapping(['electronics', 'computer', 'mobile_phone'], [], 'electronics'),
  'printer': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'ink': _Mapping(['electronics', 'computer', 'stationery'], [], 'electronics'),
  'toner': _Mapping(['electronics', 'computer', 'stationery'], [], 'electronics'),
  'tv': _Mapping(['electronics', 'hifi'], [], 'electronics'),
  'television': _Mapping(['electronics', 'hifi'], [], 'electronics'),
  'roku': _Mapping(['electronics', 'hifi'], [], 'electronics'),
  'firestick': _Mapping(['electronics', 'hifi'], [], 'electronics'),
  'xbox': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'playstation': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'ps5': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'nintendo': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'switch': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'video game': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'game': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'controller': _Mapping(['electronics', 'computer', 'games'], [], 'electronics'),
  'camera': _Mapping(['electronics', 'photo'], [], 'electronics'),
  'gopro': _Mapping(['electronics', 'photo', 'outdoor'], [], 'electronics'),
  'drone': _Mapping(['electronics', 'photo'], [], 'electronics'),
  'smart watch': _Mapping(['electronics', 'mobile_phone'], [], 'electronics'),
  'apple watch': _Mapping(['electronics', 'mobile_phone'], [], 'electronics'),
  'fitbit': _Mapping(['electronics', 'mobile_phone', 'sports'], [], 'electronics'),
  'router': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'wifi': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'hard drive': _Mapping(['electronics', 'computer'], [], 'electronics'),
  'ssd': _Mapping(['electronics', 'computer'], [], 'electronics'),

  // ---- Hardware / home improvement ----
  'nail': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'nails': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'screw': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'screws': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'drill': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'hammer': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'wrench': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'tool': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'tools': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'tape': _Mapping(['hardware', 'doityourself', 'stationery'], [], 'hardware'),
  'duct tape': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'glue': _Mapping(['hardware', 'doityourself', 'stationery', 'craft'], [], 'hardware'),
  'paint': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'lock': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'padlock': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'plumbing': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'pipe': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'sandpaper': _Mapping(['hardware', 'doityourself'], [], 'hardware'),

  // ---- Medicine / health / first aid ----
  'medicine': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'aspirin': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'ibuprofen': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'tylenol': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'advil': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'bandaid': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'band-aid': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'bandage': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'first aid': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'thermometer': _Mapping(['chemist', 'electronics'], ['pharmacy'], 'health'),
  'cough': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'cold medicine': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'allergy': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'vitamin': _Mapping(['chemist', 'health_food'], ['pharmacy'], 'health'),
  'vitamins': _Mapping(['chemist', 'health_food'], ['pharmacy'], 'health'),
  'sunscreen': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'antacid': _Mapping(['chemist'], ['pharmacy'], 'health'),

  // ---- Baby / childcare ----
  'diaper': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'diapers': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'baby formula': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'formula': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'baby food': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'baby wipes': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'pacifier': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'bottle': _Mapping(['baby_goods', 'chemist'], [], 'baby'),

  // ---- Grocery / food (buy at a store, not eat at a restaurant) ----
  'milk': _Mapping(['dairy', 'farm', 'greengrocer', 'bakery', 'deli'], [], 'grocery'),
  'bread': _Mapping(['bakery', 'greengrocer', 'deli'], [], 'grocery'),
  'eggs': _Mapping(['farm', 'greengrocer', 'deli'], [], 'grocery'),
  'water': _Mapping(['beverages', 'outdoor'], [], 'grocery'),
  'fruit': _Mapping(['greengrocer', 'farm'], [], 'grocery'),
  'vegetable': _Mapping(['greengrocer', 'farm'], [], 'grocery'),
  'vegetables': _Mapping(['greengrocer', 'farm'], [], 'grocery'),
  'meat': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'chicken': _Mapping(['butcher', 'deli', 'farm'], ['restaurant', 'fast_food'], 'food'),
  'beef': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'fish': _Mapping(['seafood', 'deli', 'farm'], [], 'grocery'),
  'cheese': _Mapping(['cheese', 'deli', 'farm'], [], 'grocery'),
  'rice': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'pasta': _Mapping(['deli'], [], 'grocery'),
  'cereal': _Mapping([], [], 'grocery'),
  'snack': _Mapping(['bakery', 'confectionery'], [], 'grocery'),
  'snacks': _Mapping(['bakery', 'confectionery'], [], 'grocery'),
  'candy': _Mapping(['confectionery'], [], 'grocery'),
  'chocolate': _Mapping(['confectionery', 'bakery'], [], 'grocery'),
  'coffee': _Mapping(['coffee', 'beverages'], ['cafe'], 'food'),
  'tea': _Mapping(['tea', 'beverages', 'health_food'], ['cafe'], 'food'),
  'juice': _Mapping(['beverages', 'health_food'], [], 'grocery'),
  'soda': _Mapping(['beverages'], [], 'grocery'),
  'beer': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'wine': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'liquor': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'frozen': _Mapping(['frozen_food'], [], 'grocery'),
  'food': _Mapping(['deli', 'bakery', 'greengrocer'], ['restaurant', 'fast_food', 'cafe'], 'food'),
  'grocery': _Mapping([], [], 'grocery'),
  'groceries': _Mapping([], [], 'grocery'),

  // ---- Cleaning / household ----
  'soap': _Mapping(['chemist', 'cosmetics'], [], 'household'),
  'detergent': _Mapping(['chemist'], [], 'household'),
  'bleach': _Mapping(['chemist'], [], 'household'),
  'sponge': _Mapping(['chemist', 'household'], [], 'household'),
  'trash bags': _Mapping(['chemist', 'household'], [], 'household'),
  'paper towels': _Mapping(['chemist', 'household'], [], 'household'),
  'paper towel': _Mapping(['chemist', 'household'], [], 'household'),
  'toilet paper': _Mapping(['chemist', 'household'], [], 'household'),
  'tissues': _Mapping(['chemist', 'household'], [], 'household'),
  'cleaning': _Mapping(['chemist', 'household'], [], 'cleaning'),

  // ---- Personal care ----
  'shampoo': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'conditioner': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'toothbrush': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'toothpaste': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'deodorant': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'razor': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'lotion': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'moisturizer': _Mapping(['chemist', 'cosmetics'], [], 'personal_care'),
  'makeup': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'mascara': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'lipstick': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),

  // ---- Pet ----
  'dog food': _Mapping(['pet'], [], 'pet'),
  'cat food': _Mapping(['pet'], [], 'pet'),
  'pet food': _Mapping(['pet'], [], 'pet'),
  'cat litter': _Mapping(['pet'], [], 'pet'),
  'leash': _Mapping(['pet'], [], 'pet'),
  'pet': _Mapping(['pet'], [], 'pet'),

  // ---- Auto ----
  'motor oil': _Mapping(['car_parts', 'car_repair', 'car'], ['fuel'], 'auto'),
  'oil filter': _Mapping(['car_parts', 'car_repair'], [], 'auto'),
  'wiper': _Mapping(['car_parts', 'car_repair', 'car'], [], 'auto'),
  'antifreeze': _Mapping(['car_parts', 'car_repair'], ['fuel'], 'auto'),
  'tire': _Mapping(['car_parts', 'car_repair', 'tyres'], [], 'auto'),
  'gas': _Mapping(['car_parts', 'car_repair'], ['fuel'], 'auto'),
  'gasoline': _Mapping([], ['fuel'], 'auto'),

  // ---- Clothing ----
  'shirt': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'pants': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'shoes': _Mapping(['shoes', 'clothes', 'fashion'], [], 'clothing'),
  'socks': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'jacket': _Mapping(['clothes', 'fashion', 'outdoor'], [], 'clothing'),
  'coat': _Mapping(['clothes', 'fashion', 'outdoor'], [], 'clothing'),
  'hat': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'gloves': _Mapping(['clothes', 'fashion', 'outdoor', 'hardware', 'doityourself'], [], 'clothing'),
  'underwear': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'dress': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),

  // ---- Office / school ----
  'pen': _Mapping(['stationery', 'books'], [], 'office'),
  'pencil': _Mapping(['stationery', 'books'], [], 'office'),
  'notebook': _Mapping(['stationery', 'books'], [], 'office'),
  'paper': _Mapping(['stationery', 'books'], [], 'office'),
  'envelope': _Mapping(['stationery', 'books'], [], 'office'),
  'stapler': _Mapping(['stationery'], [], 'office'),
  'binder': _Mapping(['stationery', 'books'], [], 'office'),
  'folder': _Mapping(['stationery', 'books'], [], 'office'),
  'backpack': _Mapping(['bag', 'outdoor', 'clothes'], [], 'office'),

  // ---- Outdoor / camping / safety ----
  'mask': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], ['pharmacy'], 'health'),
  'masks': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], ['pharmacy'], 'health'),
  'n95': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], ['pharmacy'], 'health'),
  'tent': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'sleeping bag': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'camping': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'propane': _Mapping(['outdoor', 'hardware', 'doityourself'], [], 'outdoor'),
  'fire extinguisher': _Mapping(['hardware', 'doityourself'], [], 'outdoor'),
  'lantern': _Mapping(['outdoor', 'hardware'], [], 'outdoor'),

  // ---- Sports / fitness ----
  'ball': _Mapping(['sports'], [], 'sports'),
  'weights': _Mapping(['sports'], [], 'sports'),
  'yoga': _Mapping(['sports'], [], 'sports'),
  'bicycle': _Mapping(['bicycle'], [], 'sports'),
  'bike': _Mapping(['bicycle'], [], 'sports'),
  'helmet': _Mapping(['bicycle', 'sports', 'motorcycle'], [], 'sports'),

  // ---- Garden ----
  'plant': _Mapping(['garden_centre', 'florist'], [], 'garden'),
  'plants': _Mapping(['garden_centre', 'florist'], [], 'garden'),
  'soil': _Mapping(['garden_centre', 'doityourself'], [], 'garden'),
  'fertilizer': _Mapping(['garden_centre', 'doityourself'], [], 'garden'),
  'seeds': _Mapping(['garden_centre'], [], 'garden'),
  'hose': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'lawn': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'mower': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Result of looking up an item in the keyword map.
class ItemFilterResult {
  /// Overpass shop regex (e.g. "bakery|confectionery|department_store").
  /// Null if no shop types are relevant.
  final String? shopFilter;

  /// Overpass amenity regex (e.g. "cafe|fast_food|restaurant").
  /// Null if no amenity types are relevant.
  final String? amenityFilter;

  /// Whether any keyword matched at all.
  final bool matched;

  /// Whether this is a dining/restaurant search (not a retail product).
  final bool isDining;

  const ItemFilterResult({
    this.shopFilter,
    this.amenityFilter,
    this.matched = false,
    this.isDining = false,
  });
}

/// Given a user's search [item], returns shop and amenity filters for Overpass.
ItemFilterResult filtersForItem(String item) {
  final lower = item.toLowerCase().trim();

  final shopTypes = <String>{};
  final amenityTypes = <String>{};
  final categories = <String>{};

  _keywordMap.forEach((keyword, mapping) {
    if (lower.contains(keyword)) {
      shopTypes.addAll(mapping.shopTypes);
      amenityTypes.addAll(mapping.amenityTypes);
      categories.add(mapping.category);
    }
  });

  // If nothing matched, return unmatched.
  if (shopTypes.isEmpty && amenityTypes.isEmpty && categories.isEmpty) {
    return const ItemFilterResult(matched: false);
  }

  final isDining = categories.any((c) => _diningCategories.contains(c));

  // For retail products, add big-box stores.
  // For dining, do NOT add department stores (nobody eats at Walmart).
  if (!isDining) {
    shopTypes.addAll(_bigBoxRetail);
  }

  // Only include grocery stores for grocery/food/health/baby/household.
  if (categories.any((c) => _groceryCategories.contains(c))) {
    shopTypes.addAll(_groceryRetail);
  }

  // Always include marketplace as a base amenity for non-dining.
  if (!isDining) {
    amenityTypes.add('marketplace');
  }

  return ItemFilterResult(
    shopFilter: shopTypes.isNotEmpty ? shopTypes.join('|') : null,
    amenityFilter: amenityTypes.isNotEmpty ? amenityTypes.join('|') : null,
    matched: true,
    isDining: isDining,
  );
}

// Keep backward-compatible API for existing callers.

/// Returns the Overpass shop regex filter, or null if no keywords matched.
String? shopFilterForItem(String item) => filtersForItem(item).shopFilter;

/// Returns the Overpass amenity regex filter.
String amenityFilterForItem(String item) {
  final result = filtersForItem(item);
  if (result.amenityFilter != null) return result.amenityFilter!;
  // Fallback: marketplace only.
  return 'marketplace';
}
