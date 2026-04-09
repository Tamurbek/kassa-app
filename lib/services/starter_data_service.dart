import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'database_service.dart';

class StarterDataService {
  static Future<int> seed1000Products() async {
    try {
      final String response = await rootBundle.loadString('assets/starter_products.json');
      final List<dynamic> data = json.decode(response);
      
      List<Product> productsToSeed = [];
      Map<String, String> categoryMap = {};

      // 1. Get/Create Categories
      final existingCats = await DatabaseService.getCategories();
      final categories = data.map((item) => item['category'] as String).toSet().toList();
      
      for (var catName in categories) {
        var cat = existingCats.where((c) => c.name == catName).firstOrNull;
        if (cat == null) {
          cat = Category(
            id: DateTime.now().millisecondsSinceEpoch.toString() + catName.hashCode.toString(),
            name: catName,
          );
          await DatabaseService.saveCategory(cat);
        }
        categoryMap[catName] = cat.id;
      }

      // 2. Prepare Products
      for (var item in data) {
        productsToSeed.add(Product.create(
          item['name'],
          item['price'].toDouble(),
          categoryMap[item['category']]!,
          item['barcode'],
          costPrice: item['costPrice'].toDouble(),
          unit: item['unit'],
        ));
      }

      await DatabaseService.saveProductsBatch(productsToSeed);
      return productsToSeed.length;
    } catch (e) {
       rethrow;
    }
  }
}
