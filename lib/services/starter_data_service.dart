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
      List<Category> newCategories = [];

      // 1. Get/Create Categories
      final existingCats = await DatabaseService.getCategories();
      final categoryNames = data.map((item) => item['category'] as String).toSet().toList();
      
      for (var catName in categoryNames) {
        var cat = existingCats.where((c) => c.name == catName).firstOrNull;
        if (cat == null) {
          cat = Category(
            id: DateTime.now().millisecondsSinceEpoch.toString() + catName.hashCode.toString(),
            name: catName,
          );
          newCategories.add(cat);
        }
        categoryMap[catName] = cat.id;
      }

      if (newCategories.isNotEmpty) {
        await DatabaseService.saveCategoriesBatch(newCategories);
      }

      // 2. Prepare Products
      for (var item in data) {
        productsToSeed.add(Product.create(
          item['name'],
          (item['price'] as num).toDouble(),
          categoryMap[item['category']]!,
          item['barcode'],
          costPrice: (item['costPrice'] as num).toDouble(),
          unit: item['unit'] ?? 'dona',
        ));
      }

      await DatabaseService.saveProductsBatch(productsToSeed);
      return productsToSeed.length;
    } catch (e) {
       rethrow;
    }
  }
}
