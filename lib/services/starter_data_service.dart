import 'dart:math';
import '../models/models.dart';
import 'database_service.dart';

class StarterDataService {
  static final List<String> categories = [
    "Ichimliklar",
    "Sut mahsulotlari",
    "Qandolat",
    "Oziq-ovqat",
    "Maishiy kimyo",
    "Kantselyariya",
    "Non mahsulotlari"
  ];

  static final Map<String, List<String>> brands = {
    "Ichimliklar": ["Coca-Cola", "Pepsi", "Fanta", "Sprite", "Dinay", "Hydrolife", "Chortoq", "Borjomi", "Lipton", "FuseTea", "Flash Up", "Adrenaline Rush", "Molochnaya Reka", "Rich", "J7", "Bliss"],
    "Sut mahsulotlari": ["Musaffo", "Bio-Sut", "Kamilka", "Lactel", "Prostokvashino", "Domik v Derevne", "Sami", "Pishir-pishir"],
    "Qandolat": ["Alpen Gold", "Snickers", "Twix", "Bounty", "Mars", "Kinder", "Milka", "Nestle", "Roshen", "Konty", "Yasnaya Polyana", "Slavyanka", "Lotte"],
    "Oziq-ovqat": ["Makfa", "Shebekino", "Siyom", "Moya Semya", "Ahmad Tea", "Greenfield", "Curtis", "Dilmah", "Baraka", "Lazar", "Alanga", "Koguruchi"],
    "Maishiy kimyo": ["Ariel", "Tide", "Persil", "Fairy", "Domestos", "Colgate", "Oral-B", "Paltmolive", "SafeGuard", "Nivea", "Rexona", "Old Spice"],
    "Kantselyariya": ["ErichKrause", "Deli", "Centropen", "Berlingo"],
    "Non mahsulotlari": ["Buxanka", "Patir", "Lochira", "Rogalik"],
  };

  static Future<int> seed1000Products() async {
    final random = Random();
    List<Product> productsToSeed = [];
    Map<String, String> categoryMap = {};

    // 1. Create/Get Categories
    final existingCats = await DatabaseService.getCategories();
    for (var catName in categories) {
      var cat = existingCats.where((c) => c.name == catName).firstOrNull;
      if (cat == null) {
        cat = Category(
          id: DateTime.now().millisecondsSinceEpoch.toString() + random.nextInt(1000).toString(),
          name: catName,
        );
        await DatabaseService.saveCategory(cat);
      }
      categoryMap[catName] = cat.id;
    }

    // 2. Generate 1000 items
    int count = 0;
    Set<String> usedBarcodes = {};

    String genBarcode() {
      while (true) {
        String bc = "";
        for (int i = 0; i < 13; i++) bc += random.nextInt(10).toString();
        if (!usedBarcodes.contains(bc)) {
          usedBarcodes.add(bc);
          return bc;
        }
      }
    }

    // specific base products
    final baseProducts = [
      ["Coca-Cola 1.5L", "Ichimliklar", 13000.0, 10000.0, "5449000131805"],
      ["Pepsi 1.5L", "Ichimliklar", 12500.0, 9500.0, "4823063100029"],
      ["Musaffo Sut 3.2% 1L", "Sut mahsulotlari", 14500.0, 11000.0, "4780004920027"],
      ["Ariel 450g", "Maishiy kimyo", 20000.0, 15000.0, "4015600001234"],
    ];

    for (var p in baseProducts) {
      productsToSeed.add(Product.create(
        p[0] as String,
        p[2] as double,
        categoryMap[p[1]]!,
        p[4] as String,
        costPrice: p[3] as double,
      ));
      usedBarcodes.add(p[4] as String);
      count++;
    }

    // variants and fillers
    for (var entry in brands.entries) {
      final catName = entry.key;
      final catId = categoryMap[catName]!;
      for (var brand in entry.value) {
        for (var size in ["0.5L", "1L", "1.5L", "200g", "450g", "1kg"]) {
          if (count >= 1000) break;
          double cost = (20 + random.nextInt(180)) * 100.0;
          double price = (cost * (1.15 + random.nextDouble() * 0.3) / 100).round() * 100.0;
          
          productsToSeed.add(Product.create(
            "$brand ${catName.substring(0, catName.length - 3)} $size",
            price,
            catId,
            genBarcode(),
            costPrice: cost,
            unit: size.contains('kg') ? 'kg' : 'dona',
          ));
          count++;
        }
        if (count >= 1000) break;
      }
      if (count >= 1000) break;
    }

    // fillers to reach 1000
    while (count < 1000) {
      final catName = categories[random.nextInt(categories.length)];
      final brand = brands[catName]![random.nextInt(brands[catName]!.length)];
      double cost = (10 + random.nextInt(490)) * 100.0;
      double price = (cost * (1.1 + random.nextDouble() * 0.4) / 100).round() * 100.0;

      productsToSeed.add(Product.create(
        "$brand Mahsulot №${count + 1}",
        price,
        categoryMap[catName]!,
        genBarcode(),
        costPrice: cost,
        unit: random.nextBool() ? 'dona' : 'kg',
      ));
      count++;
    }

    await DatabaseService.saveProductsBatch(productsToSeed);
    return productsToSeed.length;
  }
}
