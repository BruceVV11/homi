import 'package:flutter/material.dart';

class SupplyIconOption {
  const SupplyIconOption(this.key, this.label, this.icon);

  final String key;
  final String label;
  final IconData icon;
}

abstract final class SupplyIconCatalog {
  static const String defaultKey = 'inventory';

  static const List<SupplyIconOption> all = <SupplyIconOption>[
    SupplyIconOption('inventory', 'General', Icons.inventory_2_outlined),
    SupplyIconOption('milk', 'Milk', Icons.local_drink_outlined),
    SupplyIconOption('bread', 'Bread', Icons.bakery_dining_outlined),
    SupplyIconOption('eggs', 'Eggs', Icons.egg_alt_outlined),
    SupplyIconOption('water', 'Water', Icons.water_drop_outlined),
    SupplyIconOption('coffee', 'Coffee', Icons.coffee_outlined),
    SupplyIconOption('tea', 'Tea', Icons.emoji_food_beverage_outlined),
    SupplyIconOption('fruit', 'Fruit', Icons.eco_outlined),
    SupplyIconOption('vegetables', 'Vegetables', Icons.grass_outlined),
    SupplyIconOption('meat', 'Meat', Icons.kebab_dining_outlined),
    SupplyIconOption('fish', 'Fish', Icons.set_meal_outlined),
    SupplyIconOption('frozen', 'Frozen food', Icons.ac_unit_outlined),
    SupplyIconOption('snacks', 'Snacks', Icons.cookie_outlined),
    SupplyIconOption('cereal', 'Cereal', Icons.breakfast_dining_outlined),
    SupplyIconOption('pasta', 'Pasta', Icons.ramen_dining_outlined),
    SupplyIconOption('rice', 'Rice', Icons.rice_bowl_outlined),
    SupplyIconOption('tin', 'Tinned food', Icons.soup_kitchen_outlined),
    SupplyIconOption('spices', 'Spices', Icons.restaurant_outlined),
    SupplyIconOption('oil', 'Cooking oil', Icons.opacity_outlined),
    SupplyIconOption('sauce', 'Sauces', Icons.liquor_outlined),
    SupplyIconOption('pet_food', 'Pet food', Icons.pets_outlined),
    SupplyIconOption('medicine', 'Medicine', Icons.medication_outlined),
    SupplyIconOption('first_aid', 'First aid', Icons.medical_services_outlined),
    SupplyIconOption('vitamins', 'Vitamins', Icons.health_and_safety_outlined),
    SupplyIconOption('soap', 'Soap', Icons.soap_outlined),
    SupplyIconOption('shampoo', 'Shampoo', Icons.shower_outlined),
    SupplyIconOption('toothpaste', 'Dental care', Icons.clean_hands_outlined),
    SupplyIconOption('toilet_paper', 'Toilet paper', Icons.wc_outlined),
    SupplyIconOption('tissues', 'Tissues', Icons.layers_outlined),
    SupplyIconOption('laundry', 'Laundry', Icons.local_laundry_service_outlined),
    SupplyIconOption('dishwasher', 'Dishwashing', Icons.dishwasher_outlined),
    SupplyIconOption('cleaner', 'Cleaner', Icons.cleaning_services_outlined),
    SupplyIconOption('spray', 'Cleaning spray', Icons.sanitizer_outlined),
    SupplyIconOption('bin_bags', 'Bin bags', Icons.delete_outline_rounded),
    SupplyIconOption('paper_towels', 'Paper towels', Icons.article_outlined),
    SupplyIconOption('foil', 'Foil / wrap', Icons.view_week_outlined),
    SupplyIconOption('lightbulb', 'Light bulbs', Icons.lightbulb_outline_rounded),
    SupplyIconOption('battery', 'Batteries', Icons.battery_std_outlined),
    SupplyIconOption('tools', 'Tools', Icons.handyman_outlined),
    SupplyIconOption('hardware', 'Hardware', Icons.build_outlined),
    SupplyIconOption('garden', 'Garden', Icons.local_florist_outlined),
    SupplyIconOption('pool', 'Pool', Icons.pool_outlined),
    SupplyIconOption('gas', 'Gas', Icons.local_fire_department_outlined),
    SupplyIconOption('electricity', 'Electricity', Icons.bolt_outlined),
    SupplyIconOption('stationery', 'Stationery', Icons.edit_note_outlined),
    SupplyIconOption('printer', 'Printer supplies', Icons.print_outlined),
    SupplyIconOption('baby', 'Baby', Icons.child_friendly_outlined),
    SupplyIconOption('nappies', 'Nappies', Icons.baby_changing_station_outlined),
    SupplyIconOption('cosmetics', 'Cosmetics', Icons.face_retouching_natural_outlined),
    SupplyIconOption('razor', 'Shaving', Icons.content_cut_outlined),
    SupplyIconOption('candles', 'Candles', Icons.candle_outlined),
    SupplyIconOption('matches', 'Matches / lighters', Icons.local_fire_department_outlined),
    SupplyIconOption('office', 'Office', Icons.work_outline_rounded),
    SupplyIconOption('school', 'School', Icons.school_outlined),
    SupplyIconOption('car', 'Car supplies', Icons.directions_car_outlined),
    SupplyIconOption('garage', 'Garage', Icons.garage_outlined),
    SupplyIconOption('paint', 'Paint', Icons.format_paint_outlined),
    SupplyIconOption('storage', 'Storage', Icons.inventory_outlined),
    SupplyIconOption('party', 'Party supplies', Icons.celebration_outlined),
    SupplyIconOption('bbq', 'Braai / BBQ', Icons.outdoor_grill_outlined),
    SupplyIconOption('ice', 'Ice', Icons.ac_unit_rounded),
    SupplyIconOption('bottle', 'Bottled drinks', Icons.local_cafe_outlined),
    SupplyIconOption('shopping', 'Shopping', Icons.shopping_basket_outlined),
  ];

  static IconData iconFor(String? key) {
    for (final option in all) {
      if (option.key == key) return option.icon;
    }
    return Icons.inventory_2_outlined;
  }

  static SupplyIconOption optionFor(String? key) {
    for (final option in all) {
      if (option.key == key) return option;
    }
    return all.first;
  }
}
