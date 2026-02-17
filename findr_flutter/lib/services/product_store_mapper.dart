/// Maps product search terms to relevant OpenStreetMap shop/amenity types.
///
/// Builds targeted Overpass regex filters so only stores and places that
/// could plausibly sell or serve the item appear in results.
///
/// Coverage: consumer goods, fresh food, household, health & beauty,
/// clothing, home & kitchen, raw materials, construction, industrial,
/// specialty/hobbyist, craft, local services, dining, and more.
library;

// ---------------------------------------------------------------------------
// Two tiers of "general" retail:
//
// Tier 1 — Big-box / department stores that sell almost everything.
//          Included for ANY matched product keyword (not dining/services).
//
// Tier 2 — Grocery / convenience stores.  Only included when the item
//          is something you'd actually find at a grocery store.
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

const Set<String> _groceryCategories = {
  'grocery', 'food', 'health', 'baby', 'cleaning', 'household', 'personal_care',
};

const Set<String> _diningCategories = { 'dining' };
const Set<String> _serviceCategories = { 'service' };

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
  //  1.  DINING / RESTAURANTS / PREPARED FOOD
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
  'enchilada': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
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
  'korean': _Mapping([], ['restaurant'], 'dining'),
  'indian food': _Mapping([], ['restaurant'], 'dining'),
  'curry': _Mapping([], ['restaurant'], 'dining'),
  'panda express': _Mapping([], ['fast_food'], 'dining'),
  'teriyaki': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'dim sum': _Mapping([], ['restaurant'], 'dining'),
  'pad thai': _Mapping([], ['restaurant'], 'dining'),
  'vietnamese': _Mapping([], ['restaurant'], 'dining'),
  'japanese': _Mapping([], ['restaurant'], 'dining'),
  'hibachi': _Mapping([], ['restaurant'], 'dining'),
  'wok': _Mapping([], ['restaurant', 'fast_food'], 'dining'),

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
  'gyro': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'falafel': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'shawarma': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'kebab': _Mapping([], ['restaurant', 'fast_food'], 'dining'),
  'mediterranean': _Mapping([], ['restaurant'], 'dining'),
  'italian': _Mapping([], ['restaurant'], 'dining'),
  'mexican food': _Mapping([], ['restaurant', 'fast_food'], 'dining'),

  // -- Coffee shops (dining) --
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
  //  2.  CONSUMER GOODS — FRESH FOOD & STAPLES
  // =====================================================================

  'produce': _Mapping(['greengrocer', 'farm'], ['marketplace'], 'grocery'),
  'fruit': _Mapping(['greengrocer', 'farm'], ['marketplace'], 'grocery'),
  'fruits': _Mapping(['greengrocer', 'farm'], ['marketplace'], 'grocery'),
  'vegetable': _Mapping(['greengrocer', 'farm'], ['marketplace'], 'grocery'),
  'vegetables': _Mapping(['greengrocer', 'farm'], ['marketplace'], 'grocery'),
  'dairy': _Mapping(['dairy', 'farm', 'greengrocer'], [], 'grocery'),
  'milk': _Mapping(['dairy', 'farm', 'greengrocer', 'bakery', 'deli'], [], 'grocery'),
  'butter': _Mapping(['dairy', 'farm', 'deli'], [], 'grocery'),
  'yogurt': _Mapping(['dairy', 'farm', 'deli'], [], 'grocery'),
  'cream': _Mapping(['dairy', 'farm', 'deli'], [], 'grocery'),
  'cheese': _Mapping(['cheese', 'deli', 'farm'], [], 'grocery'),
  'eggs': _Mapping(['farm', 'greengrocer', 'deli'], [], 'grocery'),
  'bread': _Mapping(['bakery', 'greengrocer', 'deli'], [], 'grocery'),
  'meat': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'chicken': _Mapping(['butcher', 'deli', 'farm'], ['restaurant', 'fast_food'], 'food'),
  'beef': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'pork': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'lamb': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'turkey': _Mapping(['butcher', 'deli', 'farm'], [], 'grocery'),
  'fish': _Mapping(['seafood', 'deli', 'farm'], [], 'grocery'),
  'shrimp': _Mapping(['seafood', 'deli'], [], 'grocery'),
  'salmon': _Mapping(['seafood', 'deli'], [], 'grocery'),
  'honey': _Mapping(['farm', 'greengrocer', 'health_food'], ['marketplace'], 'grocery'),
  'grain': _Mapping(['greengrocer', 'health_food'], [], 'grocery'),
  'grains': _Mapping(['greengrocer', 'health_food'], [], 'grocery'),
  'flour': _Mapping(['greengrocer', 'bakery'], [], 'grocery'),
  'oil': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'olive oil': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'cooking oil': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'rice': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'pasta': _Mapping(['deli'], [], 'grocery'),
  'cereal': _Mapping([], [], 'grocery'),
  'oatmeal': _Mapping([], [], 'grocery'),
  'sugar': _Mapping(['greengrocer'], [], 'grocery'),
  'salt': _Mapping(['greengrocer'], [], 'grocery'),
  'spice': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'spices': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'seasoning': _Mapping(['greengrocer', 'deli'], [], 'grocery'),
  'sauce': _Mapping(['deli', 'greengrocer'], [], 'grocery'),
  'condiment': _Mapping(['deli', 'greengrocer'], [], 'grocery'),
  'ketchup': _Mapping(['deli', 'greengrocer'], [], 'grocery'),
  'mustard': _Mapping(['deli', 'greengrocer'], [], 'grocery'),
  'snack': _Mapping(['bakery', 'confectionery'], [], 'grocery'),
  'snacks': _Mapping(['bakery', 'confectionery'], [], 'grocery'),
  'candy': _Mapping(['confectionery'], [], 'grocery'),
  'chocolate': _Mapping(['confectionery', 'bakery'], [], 'grocery'),
  'nuts': _Mapping(['greengrocer', 'health_food'], [], 'grocery'),
  'coffee': _Mapping(['coffee', 'beverages'], ['cafe'], 'food'),
  'tea': _Mapping(['tea', 'beverages', 'health_food'], ['cafe'], 'food'),
  'juice': _Mapping(['beverages', 'health_food'], [], 'grocery'),
  'soda': _Mapping(['beverages'], [], 'grocery'),
  'water': _Mapping(['beverages', 'outdoor'], [], 'grocery'),
  'beer': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'wine': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'liquor': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'spirits': _Mapping(['alcohol', 'beverages'], [], 'grocery'),
  'frozen': _Mapping(['frozen_food'], [], 'grocery'),
  'food': _Mapping(['deli', 'bakery', 'greengrocer'], ['restaurant', 'fast_food', 'cafe'], 'food'),
  'grocery': _Mapping([], [], 'grocery'),
  'groceries': _Mapping([], [], 'grocery'),
  'organic': _Mapping(['health_food', 'greengrocer', 'farm'], [], 'grocery'),

  // =====================================================================
  //  3.  CONSUMER GOODS — HOUSEHOLD ITEMS
  // =====================================================================

  'soap': _Mapping(['chemist', 'cosmetics'], [], 'household'),
  'detergent': _Mapping(['chemist'], [], 'household'),
  'laundry detergent': _Mapping(['chemist'], [], 'household'),
  'laundry': _Mapping(['chemist', 'household'], ['dry_cleaning'], 'household'),
  'bleach': _Mapping(['chemist'], [], 'household'),
  'sponge': _Mapping(['chemist', 'household'], [], 'household'),
  'mop': _Mapping(['chemist', 'household', 'hardware'], [], 'household'),
  'broom': _Mapping(['chemist', 'household', 'hardware'], [], 'household'),
  'vacuum': _Mapping(['electronics', 'hardware', 'household'], [], 'household'),
  'trash bags': _Mapping(['chemist', 'household'], [], 'household'),
  'garbage bags': _Mapping(['chemist', 'household'], [], 'household'),
  'paper towels': _Mapping(['chemist', 'household'], [], 'household'),
  'paper towel': _Mapping(['chemist', 'household'], [], 'household'),
  'toilet paper': _Mapping(['chemist', 'household'], [], 'household'),
  'tissues': _Mapping(['chemist', 'household'], [], 'household'),
  'cleaning supplies': _Mapping(['chemist', 'household'], [], 'cleaning'),
  'cleaning': _Mapping(['chemist', 'household'], [], 'cleaning'),
  'dish soap': _Mapping(['chemist', 'household'], [], 'household'),
  'disinfectant': _Mapping(['chemist', 'household'], [], 'household'),
  'air freshener': _Mapping(['chemist', 'household'], [], 'household'),

  // =====================================================================
  //  4.  CONSUMER GOODS — HEALTH & BEAUTY
  // =====================================================================

  'medicine': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'prescription': _Mapping(['chemist'], ['pharmacy'], 'health'),
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
  'supplements': _Mapping(['chemist', 'health_food'], ['pharmacy'], 'health'),
  'sunscreen': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'antacid': _Mapping(['chemist'], ['pharmacy'], 'health'),
  'pharmacy': _Mapping(['chemist'], ['pharmacy'], 'health'),

  // Personal care
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
  'cosmetics': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'perfume': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'cologne': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'hair dye': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'nail polish': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'skincare': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),
  'face wash': _Mapping(['cosmetics', 'chemist'], [], 'personal_care'),

  // =====================================================================
  //  5.  CONSUMER GOODS — BABY / CHILDCARE
  // =====================================================================

  'diaper': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'diapers': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'baby formula': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'formula': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'baby food': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'baby wipes': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'pacifier': _Mapping(['baby_goods', 'chemist'], ['pharmacy'], 'baby'),
  'bottle': _Mapping(['baby_goods', 'chemist'], [], 'baby'),
  'stroller': _Mapping(['baby_goods'], [], 'baby'),
  'car seat': _Mapping(['baby_goods'], [], 'baby'),
  'crib': _Mapping(['baby_goods', 'furniture'], [], 'baby'),

  // =====================================================================
  //  6.  CLOTHING & TEXTILES
  // =====================================================================

  'shirt': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  't-shirt': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'pants': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'jeans': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'shorts': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'shoes': _Mapping(['shoes', 'clothes', 'fashion'], [], 'clothing'),
  'boots': _Mapping(['shoes', 'clothes', 'outdoor'], [], 'clothing'),
  'sandals': _Mapping(['shoes', 'clothes'], [], 'clothing'),
  'sneakers': _Mapping(['shoes', 'clothes', 'sports'], [], 'clothing'),
  'footwear': _Mapping(['shoes', 'clothes'], [], 'clothing'),
  'socks': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'jacket': _Mapping(['clothes', 'fashion', 'outdoor'], [], 'clothing'),
  'coat': _Mapping(['clothes', 'fashion', 'outdoor'], [], 'clothing'),
  'hoodie': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'sweater': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'hat': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'cap': _Mapping(['clothes', 'fashion', 'sports'], [], 'clothing'),
  'belt': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'belts': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'gloves': _Mapping(['clothes', 'fashion', 'outdoor', 'hardware', 'doityourself'], [], 'clothing'),
  'scarf': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'underwear': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'dress': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'suit': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'tie': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'apparel': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'clothing': _Mapping(['clothes', 'fashion', 'boutique'], [], 'clothing'),
  'uniform': _Mapping(['clothes', 'fashion'], [], 'clothing'),
  'backpack': _Mapping(['bag', 'outdoor', 'clothes'], [], 'clothing'),
  'purse': _Mapping(['bag', 'fashion', 'boutique'], [], 'clothing'),
  'wallet': _Mapping(['leather', 'fashion', 'boutique'], [], 'clothing'),
  'sunglasses': _Mapping(['optician', 'fashion'], [], 'clothing'),

  // =====================================================================
  //  7.  HOME & KITCHEN / FURNITURE
  // =====================================================================

  'furniture': _Mapping(['furniture'], [], 'home'),
  'couch': _Mapping(['furniture'], [], 'home'),
  'sofa': _Mapping(['furniture'], [], 'home'),
  'table': _Mapping(['furniture'], [], 'home'),
  'chair': _Mapping(['furniture'], [], 'home'),
  'desk': _Mapping(['furniture'], [], 'home'),
  'shelf': _Mapping(['furniture'], [], 'home'),
  'shelves': _Mapping(['furniture'], [], 'home'),
  'bookshelf': _Mapping(['furniture'], [], 'home'),
  'mattress': _Mapping(['furniture', 'bed'], [], 'home'),
  'bed': _Mapping(['furniture', 'bed'], [], 'home'),
  'dresser': _Mapping(['furniture'], [], 'home'),
  'cabinet': _Mapping(['furniture', 'kitchen'], [], 'home'),
  'wardrobe': _Mapping(['furniture'], [], 'home'),
  'kitchenware': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'pan': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'pans': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'cast iron': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'pot': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'pots': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'cutlery': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'knife': _Mapping(['kitchen', 'houseware', 'hardware'], [], 'home'),
  'knives': _Mapping(['kitchen', 'houseware', 'hardware'], [], 'home'),
  'spatula': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'blender': _Mapping(['kitchen', 'electronics', 'houseware'], [], 'home'),
  'mixer': _Mapping(['kitchen', 'electronics', 'houseware'], [], 'home'),
  'toaster': _Mapping(['kitchen', 'electronics', 'houseware'], [], 'home'),
  'microwave': _Mapping(['electronics', 'houseware'], [], 'home'),
  'dishes': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'plates': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'cups': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'mugs': _Mapping(['kitchen', 'houseware'], [], 'home'),
  'glasses': _Mapping(['kitchen', 'houseware', 'optician'], [], 'home'),
  'storage bin': _Mapping(['houseware', 'hardware'], [], 'home'),
  'storage bins': _Mapping(['houseware', 'hardware'], [], 'home'),
  'storage': _Mapping(['houseware', 'hardware'], [], 'home'),
  'container': _Mapping(['houseware', 'hardware'], [], 'home'),
  'organizer': _Mapping(['houseware', 'hardware'], [], 'home'),
  'basket': _Mapping(['houseware', 'craft'], [], 'home'),
  'candle': _Mapping(['houseware', 'gift'], [], 'home'),
  'candles': _Mapping(['houseware', 'gift'], [], 'home'),
  'curtain': _Mapping(['curtain', 'houseware', 'interior_decoration'], [], 'home'),
  'curtains': _Mapping(['curtain', 'houseware', 'interior_decoration'], [], 'home'),
  'rug': _Mapping(['carpet', 'interior_decoration'], [], 'home'),
  'carpet': _Mapping(['carpet', 'interior_decoration'], [], 'home'),
  'pillow': _Mapping(['houseware', 'bed'], [], 'home'),
  'blanket': _Mapping(['houseware', 'bed'], [], 'home'),
  'towel': _Mapping(['houseware', 'bed'], [], 'home'),
  'towels': _Mapping(['houseware', 'bed'], [], 'home'),
  'sheet': _Mapping(['houseware', 'bed'], [], 'home'),
  'sheets': _Mapping(['houseware', 'bed'], [], 'home'),
  'lamp': _Mapping(['lighting', 'houseware', 'electronics'], [], 'home'),
  'fan': _Mapping(['electronics', 'houseware', 'hardware'], [], 'home'),
  'heater': _Mapping(['electronics', 'hardware'], [], 'home'),
  'appliance': _Mapping(['electronics', 'houseware'], [], 'home'),
  'appliances': _Mapping(['electronics', 'houseware'], [], 'home'),

  // =====================================================================
  //  8.  ELECTRONICS / TECH / COMPUTERS
  // =====================================================================

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

  // =====================================================================
  //  9.  HARDWARE / HOME IMPROVEMENT / CONSTRUCTION MATERIALS
  // =====================================================================

  'nail': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'nails': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'screw': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'screws': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'bolt': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'bolts': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'drill': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'hammer': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'wrench': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'saw': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'tool': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'tools': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'tape': _Mapping(['hardware', 'doityourself', 'stationery'], [], 'hardware'),
  'duct tape': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'glue': _Mapping(['hardware', 'doityourself', 'stationery', 'craft'], [], 'hardware'),
  'paint': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'stain': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'lock': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'padlock': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'plumbing': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'pipe': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'sandpaper': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'electrical': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'wire': _Mapping(['hardware', 'doityourself', 'electronics'], [], 'hardware'),
  'rope': _Mapping(['hardware', 'doityourself', 'outdoor'], [], 'hardware'),
  'chain': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'ladder': _Mapping(['hardware', 'doityourself'], [], 'hardware'),

  // Construction materials
  'lumber': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  'timber': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  'wood': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  'plywood': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  '2x4': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  'firewood': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber', 'fuel'], [], 'construction'),
  'sand': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'gravel': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'stone': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'cement': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'concrete': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'brick': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'drywall': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'insulation': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'roofing': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'steel': _Mapping(['trade', 'hardware', 'building_materials'], [], 'construction'),
  'metal': _Mapping(['trade', 'hardware', 'building_materials'], [], 'construction'),
  'rebar': _Mapping(['trade', 'hardware', 'building_materials'], [], 'construction'),
  'tile': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'tiles'], [], 'construction'),
  'tiles': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'tiles'], [], 'construction'),
  'flooring': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'flooring'], [], 'construction'),
  'window': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'glaziery'], [], 'construction'),
  'glass': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'glaziery'], [], 'construction'),
  'pvc': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'raw material': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  'raw materials': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials', 'timber'], [], 'construction'),
  'building materials': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'building supply': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),
  'building supplies': _Mapping(['hardware', 'doityourself', 'trade', 'building_materials'], [], 'construction'),

  // =====================================================================
  //  10. RAW MATERIALS / AGRICULTURE / INDUSTRIAL
  // =====================================================================

  'feed': _Mapping(['agrarian', 'farm'], [], 'agriculture'),
  'livestock feed': _Mapping(['agrarian', 'farm'], [], 'agriculture'),
  'animal feed': _Mapping(['agrarian', 'farm', 'pet'], [], 'agriculture'),
  'hay': _Mapping(['agrarian', 'farm'], [], 'agriculture'),
  'straw': _Mapping(['agrarian', 'farm'], [], 'agriculture'),
  'fertilizer': _Mapping(['garden_centre', 'doityourself', 'agrarian'], [], 'agriculture'),
  'pesticide': _Mapping(['garden_centre', 'agrarian'], [], 'agriculture'),
  'herbicide': _Mapping(['garden_centre', 'agrarian'], [], 'agriculture'),
  'seeds': _Mapping(['garden_centre', 'agrarian'], [], 'agriculture'),
  'mulch': _Mapping(['garden_centre', 'doityourself'], [], 'agriculture'),
  'compost': _Mapping(['garden_centre', 'doityourself'], [], 'agriculture'),

  // Industrial / chemicals
  'chemical': _Mapping(['trade', 'hardware'], [], 'industrial'),
  'chemicals': _Mapping(['trade', 'hardware'], [], 'industrial'),
  'welding': _Mapping(['trade', 'hardware'], [], 'industrial'),
  'machinery': _Mapping(['trade', 'hardware'], [], 'industrial'),
  'petroleum': _Mapping([], ['fuel'], 'industrial'),

  // =====================================================================
  //  11. PET
  // =====================================================================

  'dog food': _Mapping(['pet'], [], 'pet'),
  'cat food': _Mapping(['pet'], [], 'pet'),
  'pet food': _Mapping(['pet'], [], 'pet'),
  'cat litter': _Mapping(['pet'], [], 'pet'),
  'leash': _Mapping(['pet'], [], 'pet'),
  'pet': _Mapping(['pet'], [], 'pet'),
  'aquarium': _Mapping(['pet'], [], 'pet'),
  'fish tank': _Mapping(['pet'], [], 'pet'),
  'bird food': _Mapping(['pet'], [], 'pet'),
  'pet supplies': _Mapping(['pet'], [], 'pet'),
  'dog treats': _Mapping(['pet'], [], 'pet'),

  // =====================================================================
  //  12. AUTO
  // =====================================================================

  'motor oil': _Mapping(['car_parts', 'car_repair', 'car'], ['fuel'], 'auto'),
  'oil filter': _Mapping(['car_parts', 'car_repair'], [], 'auto'),
  'wiper': _Mapping(['car_parts', 'car_repair', 'car'], [], 'auto'),
  'wiper blades': _Mapping(['car_parts', 'car_repair', 'car'], [], 'auto'),
  'antifreeze': _Mapping(['car_parts', 'car_repair'], ['fuel'], 'auto'),
  'coolant': _Mapping(['car_parts', 'car_repair'], [], 'auto'),
  'tire': _Mapping(['car_parts', 'car_repair', 'tyres'], [], 'auto'),
  'tires': _Mapping(['car_parts', 'car_repair', 'tyres'], [], 'auto'),
  'brake pads': _Mapping(['car_parts', 'car_repair'], [], 'auto'),
  'car battery': _Mapping(['car_parts', 'car_repair'], [], 'auto'),
  'gas': _Mapping(['car_parts', 'car_repair'], ['fuel'], 'auto'),
  'gasoline': _Mapping([], ['fuel'], 'auto'),
  'car wash': _Mapping([], ['car_wash'], 'auto'),

  // =====================================================================
  //  13. OFFICE / SCHOOL / STATIONERY
  // =====================================================================

  'pen': _Mapping(['stationery', 'books'], [], 'office'),
  'pencil': _Mapping(['stationery', 'books'], [], 'office'),
  'notebook': _Mapping(['stationery', 'books'], [], 'office'),
  'paper': _Mapping(['stationery', 'books'], [], 'office'),
  'envelope': _Mapping(['stationery', 'books'], [], 'office'),
  'stapler': _Mapping(['stationery'], [], 'office'),
  'binder': _Mapping(['stationery', 'books'], [], 'office'),
  'folder': _Mapping(['stationery', 'books'], [], 'office'),
  'marker': _Mapping(['stationery'], [], 'office'),
  'highlighter': _Mapping(['stationery'], [], 'office'),
  'eraser': _Mapping(['stationery'], [], 'office'),
  'scissors': _Mapping(['stationery', 'hardware'], [], 'office'),
  'tape dispenser': _Mapping(['stationery'], [], 'office'),
  'calculator': _Mapping(['stationery', 'electronics'], [], 'office'),
  'whiteboard': _Mapping(['stationery'], [], 'office'),
  'sticky notes': _Mapping(['stationery'], [], 'office'),
  'planner': _Mapping(['stationery', 'books'], [], 'office'),
  'calendar': _Mapping(['stationery', 'books'], [], 'office'),

  // =====================================================================
  //  14. SPECIALTY & HOBBYIST GOODS
  // =====================================================================

  // Artisanal / crafts
  'pottery': _Mapping(['craft', 'art'], [], 'craft'),
  'ceramic': _Mapping(['craft', 'art'], [], 'craft'),
  'ceramics': _Mapping(['craft', 'art'], [], 'craft'),
  'handmade': _Mapping(['craft', 'art'], ['marketplace'], 'craft'),
  'artisan': _Mapping(['craft', 'art'], ['marketplace'], 'craft'),

  // Jewelry
  'jewelry': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'jewellery': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'ring': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'necklace': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'bracelet': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'earring': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'earrings': _Mapping(['jewelry', 'jewellery'], [], 'jewelry'),
  'watch': _Mapping(['jewelry', 'jewellery', 'watches'], [], 'jewelry'),

  // Craft supplies
  'yarn': _Mapping(['craft', 'fabric'], [], 'craft'),
  'sewing': _Mapping(['craft', 'fabric'], [], 'craft'),
  'fabric': _Mapping(['fabric', 'craft'], [], 'craft'),
  'thread': _Mapping(['craft', 'fabric'], [], 'craft'),
  'needle': _Mapping(['craft', 'fabric'], [], 'craft'),
  'knitting': _Mapping(['craft', 'fabric'], [], 'craft'),
  'crochet': _Mapping(['craft', 'fabric'], [], 'craft'),
  'quilting': _Mapping(['craft', 'fabric'], [], 'craft'),
  'craft': _Mapping(['craft'], [], 'craft'),
  'craft supplies': _Mapping(['craft'], [], 'craft'),
  'beads': _Mapping(['craft'], [], 'craft'),
  'paint brushes': _Mapping(['art', 'craft'], [], 'craft'),
  'canvas': _Mapping(['art', 'craft'], [], 'craft'),
  'art supplies': _Mapping(['art', 'craft', 'stationery'], [], 'craft'),

  // Books / media
  'book': _Mapping(['books'], [], 'books'),
  'books': _Mapping(['books'], [], 'books'),
  'magazine': _Mapping(['books', 'newsagent'], [], 'books'),
  'comic': _Mapping(['books', 'newsagent'], [], 'books'),
  'vinyl': _Mapping(['music', 'hifi'], [], 'books'),
  'record': _Mapping(['music', 'hifi'], [], 'books'),

  // =====================================================================
  //  15. OUTDOOR / CAMPING / SPORTS / FITNESS
  // =====================================================================

  'tent': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'sleeping bag': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'camping': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'hiking': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'propane': _Mapping(['outdoor', 'hardware', 'doityourself'], [], 'outdoor'),
  'fire extinguisher': _Mapping(['hardware', 'doityourself'], [], 'outdoor'),
  'lantern': _Mapping(['outdoor', 'hardware'], [], 'outdoor'),
  'cooler': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'fishing': _Mapping(['outdoor', 'sports'], [], 'outdoor'),
  'fishing rod': _Mapping(['outdoor', 'sports'], [], 'outdoor'),

  'ball': _Mapping(['sports'], [], 'sports'),
  'weights': _Mapping(['sports'], [], 'sports'),
  'dumbbell': _Mapping(['sports'], [], 'sports'),
  'yoga': _Mapping(['sports'], [], 'sports'),
  'yoga mat': _Mapping(['sports'], [], 'sports'),
  'bicycle': _Mapping(['bicycle'], [], 'sports'),
  'bike': _Mapping(['bicycle'], [], 'sports'),
  'helmet': _Mapping(['bicycle', 'sports', 'motorcycle'], [], 'sports'),
  'gym equipment': _Mapping(['sports'], [], 'sports'),
  'treadmill': _Mapping(['sports'], [], 'sports'),
  'basketball': _Mapping(['sports'], [], 'sports'),
  'football': _Mapping(['sports'], [], 'sports'),
  'soccer': _Mapping(['sports'], [], 'sports'),
  'baseball': _Mapping(['sports'], [], 'sports'),
  'tennis': _Mapping(['sports'], [], 'sports'),
  'golf': _Mapping(['sports'], [], 'sports'),
  'swimming': _Mapping(['sports'], [], 'sports'),
  'swimsuit': _Mapping(['sports', 'clothes'], [], 'sports'),
  'goggles': _Mapping(['sports', 'outdoor'], [], 'sports'),
  'skateboard': _Mapping(['sports'], [], 'sports'),
  'scooter': _Mapping(['sports', 'bicycle'], [], 'sports'),

  // -- Safety --
  'mask': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], ['pharmacy'], 'health'),
  'masks': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], ['pharmacy'], 'health'),
  'n95': _Mapping(['chemist', 'hardware', 'doityourself', 'outdoor', 'medical_supply'], ['pharmacy'], 'health'),
  'safety glasses': _Mapping(['hardware', 'doityourself'], [], 'hardware'),
  'hard hat': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),
  'safety vest': _Mapping(['hardware', 'doityourself', 'trade'], [], 'hardware'),

  // =====================================================================
  //  16. GARDEN
  // =====================================================================

  'plant': _Mapping(['garden_centre', 'florist'], [], 'garden'),
  'plants': _Mapping(['garden_centre', 'florist'], [], 'garden'),
  'flowers': _Mapping(['florist', 'garden_centre'], [], 'garden'),
  'bouquet': _Mapping(['florist'], [], 'garden'),
  'soil': _Mapping(['garden_centre', 'doityourself'], [], 'garden'),
  'potting soil': _Mapping(['garden_centre', 'doityourself'], [], 'garden'),
  'hose': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'lawn': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'mower': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'lawn mower': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'greenhouse': _Mapping(['garden_centre'], [], 'garden'),
  'garden tools': _Mapping(['garden_centre', 'hardware'], [], 'garden'),
  'shovel': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'rake': _Mapping(['garden_centre', 'hardware', 'doityourself'], [], 'garden'),
  'wheelbarrow': _Mapping(['garden_centre', 'hardware'], [], 'garden'),
  'planter': _Mapping(['garden_centre'], [], 'garden'),
  'sprinkler': _Mapping(['garden_centre', 'hardware'], [], 'garden'),
  'weed killer': _Mapping(['garden_centre', 'hardware'], [], 'garden'),
  'tree': _Mapping(['garden_centre'], [], 'garden'),

  // =====================================================================
  //  17. LOCAL SERVICES (amenity-based, not retail)
  // =====================================================================

  // Maintenance & repair
  'mechanic': _Mapping(['car_repair'], ['car_repair'], 'service'),
  'auto repair': _Mapping(['car_repair'], ['car_repair'], 'service'),
  'car repair': _Mapping(['car_repair'], ['car_repair'], 'service'),
  'oil change': _Mapping(['car_repair'], ['car_repair'], 'service'),
  'tire shop': _Mapping(['tyres', 'car_repair'], [], 'service'),
  'body shop': _Mapping(['car_repair'], [], 'service'),

  'hair salon': _Mapping([], ['hairdresser'], 'service'),
  'salon': _Mapping([], ['hairdresser'], 'service'),
  'haircut': _Mapping([], ['hairdresser', 'barber'], 'service'),
  'barber': _Mapping([], ['barber'], 'service'),
  'barbershop': _Mapping([], ['barber'], 'service'),
  'nail salon': _Mapping(['beauty'], [], 'service'),
  'spa': _Mapping(['beauty'], [], 'service'),
  'massage': _Mapping(['beauty', 'massage'], [], 'service'),

  'laundromat': _Mapping([], ['laundry'], 'service'),
  'dry cleaning': _Mapping([], ['dry_cleaning'], 'service'),
  'dry cleaner': _Mapping([], ['dry_cleaning'], 'service'),
  'tailor': _Mapping(['tailor'], [], 'service'),
  'alteration': _Mapping(['tailor'], [], 'service'),

  // Professional services
  'bank': _Mapping([], ['bank'], 'service'),
  'atm': _Mapping([], ['atm'], 'service'),
  'credit union': _Mapping([], ['bank'], 'service'),
  'insurance': _Mapping([], ['insurance'], 'service'),

  'dentist': _Mapping([], ['dentist'], 'service'),
  'doctor': _Mapping([], ['doctors'], 'service'),
  'clinic': _Mapping([], ['clinic'], 'service'),
  'hospital': _Mapping([], ['hospital'], 'service'),
  'urgent care': _Mapping([], ['clinic'], 'service'),
  'optometrist': _Mapping(['optician'], ['doctors'], 'service'),
  'eye doctor': _Mapping(['optician'], ['doctors'], 'service'),
  'chiropractor': _Mapping([], ['doctors'], 'service'),
  'veterinarian': _Mapping([], ['veterinary'], 'service'),
  'vet': _Mapping([], ['veterinary'], 'service'),
  'animal hospital': _Mapping([], ['veterinary'], 'service'),

  'lawyer': _Mapping([], ['lawyers'], 'service'),
  'attorney': _Mapping([], ['lawyers'], 'service'),
  'legal': _Mapping([], ['lawyers'], 'service'),
  'accountant': _Mapping([], ['accountant'], 'service'),
  'tax': _Mapping([], ['accountant'], 'service'),

  // Hospitality
  'hotel': _Mapping([], ['hotel'], 'service'),
  'motel': _Mapping([], ['motel'], 'service'),
  'inn': _Mapping([], ['hotel'], 'service'),
  'lodge': _Mapping([], ['hotel'], 'service'),
  'hostel': _Mapping([], ['hostel'], 'service'),
  'airbnb': _Mapping([], ['hotel'], 'service'),

  // Fitness
  'gym': _Mapping([], ['gym', 'fitness_centre'], 'service'),
  'fitness': _Mapping([], ['gym', 'fitness_centre'], 'service'),
  'yoga studio': _Mapping([], ['fitness_centre'], 'service'),
  'crossfit': _Mapping([], ['fitness_centre'], 'service'),

  // Other services
  'post office': _Mapping([], ['post_office'], 'service'),
  'shipping': _Mapping([], ['post_office'], 'service'),
  'ups': _Mapping([], ['post_office'], 'service'),
  'fedex': _Mapping([], ['post_office'], 'service'),
  'storage unit': _Mapping([], ['storage_rental'], 'service'),
  'self storage': _Mapping([], ['storage_rental'], 'service'),
  'car rental': _Mapping([], ['car_rental'], 'service'),
  'daycare': _Mapping([], ['childcare'], 'service'),
  'preschool': _Mapping([], ['childcare'], 'service'),
  'tutoring': _Mapping([], ['school'], 'service'),
  'library': _Mapping([], ['library'], 'service'),
  'copy center': _Mapping([], ['copy_shop'], 'service'),
  'printing': _Mapping([], ['copy_shop'], 'service'),
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class ItemFilterResult {
  final String? shopFilter;
  final String? amenityFilter;
  final bool matched;
  final bool isDining;
  final bool isService;

  const ItemFilterResult({
    this.shopFilter,
    this.amenityFilter,
    this.matched = false,
    this.isDining = false,
    this.isService = false,
  });
}

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

  if (shopTypes.isEmpty && amenityTypes.isEmpty && categories.isEmpty) {
    return const ItemFilterResult(matched: false);
  }

  final isDining = categories.any((c) => _diningCategories.contains(c));
  final isService = categories.any((c) => _serviceCategories.contains(c));

  // For retail products, add big-box stores.
  // For dining/services, skip department stores.
  if (!isDining && !isService) {
    shopTypes.addAll(_bigBoxRetail);
  }

  if (categories.any((c) => _groceryCategories.contains(c))) {
    shopTypes.addAll(_groceryRetail);
  }

  if (!isDining && !isService) {
    amenityTypes.add('marketplace');
  }

  return ItemFilterResult(
    shopFilter: shopTypes.isNotEmpty ? shopTypes.join('|') : null,
    amenityFilter: amenityTypes.isNotEmpty ? amenityTypes.join('|') : null,
    matched: true,
    isDining: isDining,
    isService: isService,
  );
}
