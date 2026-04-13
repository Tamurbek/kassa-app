import json
import random

# Real products collected from batches and Uzum scraping
real_products = [
    {"name": "Coca-Cola Klassik 1.5l", "category": "Ichimliklar", "barcode": "5449000000439"},
    {"name": "Coca-Cola Klassik 0.5l", "category": "Ichimliklar", "barcode": "5449000000996"},
    {"name": "Pepsi 1.5l", "category": "Ichimliklar", "barcode": "4820046520330"},
    {"name": "Pepsi 0.5l", "category": "Ichimliklar", "barcode": "4823063100010"},
    {"name": "Fanta Orange 1.5l", "category": "Ichimliklar", "barcode": "5449000011527"},
    {"name": "Sprite 1.5l", "category": "Ichimliklar", "barcode": "5449000011572"},
    {"name": "Snickers shokoladli batoni 50g", "category": "Shirinliklar va qandolat", "barcode": "5000159461122"},
    {"name": "Mars shokoladli batoni 51g", "category": "Shirinliklar va qandolat", "barcode": "5000159419161"},
    {"name": "Twix shokoladli batoni 50g", "category": "Shirinliklar va qandolat", "barcode": "5000159419239"},
    {"name": "Nutella yong'oqli pasta 350g", "category": "Oziq-ovqat", "barcode": "8000500179124"},
    {"name": "Kinder Syurpriz shokoladli tuxumi", "category": "Shirinliklar va qandolat", "barcode": "8000500030029"},
    {"name": "Oreo pechenyesi 154g", "category": "Shirinliklar va qandolat", "barcode": "7622300336738"},
    {"name": "Red Bull energetik ichimligi 250ml", "category": "Ichimliklar", "barcode": "9002470025010"},
    {"name": "Nescafe Gold 190g", "category": "Ichimliklar", "barcode": "7613033503698"},
    {"name": "Colgate Total tish pastasi 125ml", "category": "Shaxsiy gigiyena", "barcode": "8714789518047"},
    {"name": "Lays Classic 150g", "category": "Shirinliklar va qandolat", "barcode": "5900259000019"},
    {"name": "Best Slivki, 150 gr", "category": "Oziq-ovqat", "barcode": "4780001230012"},
    {"name": "Yashil no'xat Oila tanlovi, 400 g", "category": "Konservalar", "barcode": "4780001230029"},
    {"name": "Guruch Laser yuqori sinf, UzRice, 950 gr", "category": "Baqqollik", "barcode": "4780001230036"},
    {"name": "Makaron Oila Tanlovi Spagetti, 400 g", "category": "Baqqollik", "barcode": "4780001230043"},
    {"name": "Quritilgan Eron xurmosi Mazafati Zuhro 550g", "category": "Shirinliklar va qandolat", "barcode": "4780001230050"},
    {"name": "Alanga guruchi Oliy navli 1kg", "category": "Baqqollik", "barcode": "4780001230067"},
    {"name": "Choy Karkade Toza, 80 gr", "category": "Ichimliklar", "barcode": "4780001230074"},
    {"name": "Quyultirilgan sut Oila Tanlovi, 8.5%, 380 g", "category": "Sut mahsulotlari", "barcode": "4780001230081"},
    {"name": "Sut LACTEL SUTIM 3.2%, 1 litr", "category": "Sut mahsulotlari", "barcode": "4780005011019"},
    {"name": "Samsung Galaxy S23 128GB", "category": "Elektronika", "barcode": "8806094770254"},
    {"name": "iPhone 14 128GB Midnight", "category": "Elektronika", "barcode": "0194253401569"},
]

# High quality product names from Uzum/Manual
high_quality_names = [
    "Patir Non", "Buxanka Non", "Lochira", "Musaffo Sut 3.2%", "Kamilka Yogurt", "Bio-Sut",
    "Ahmad Tea Grey", "Greenfield Tea", "Jacobs Monarch 95g", "Nescafe Classic", 
    "Makfa Makaron", "Shebekino Spagetti", "Moya Semya Olma sharbati", "Denay Gilos sharbati",
    "Persil Avtomat 3kg", "Ariel Color 3kg", "Tide White 3kg", "Domestos 750ml", "Fairy Lemon",
    "Colgate Max Fresh", "Orbit Peppermint", "Dirol Apple", "Nivea Cream", "Dove Soap",
    "Head & Shoulders 400ml", "Pantene Pro-V", "Huggies Elite Soft", "Pampers Baby-Dry",
    "Duracell AA", "Energizer AAA", "Logitech Mouse", "SanDisk Flash 64GB"
]

def generate_barcode(prefix):
    suffix = "".join([str(random.randint(0, 9)) for _ in range(12 - len(prefix))])
    code = f"{prefix}{suffix}"
    check = random.randint(0, 9)
    return f"{code}{check}"

products = []

# Add all hardcoded real products
for rp in real_products:
    products.append({
        "name": rp["name"],
        "category": rp["category"],
        "costPrice": 0.0,
        "price": 0.0,
        "barcode": rp["barcode"],
        "unit": "dona"
    })

# Reduced count to 500 for better speed
prefixes = ["478", "544", "482", "500", "761", "800", "871", "301", "400"]
units = ["dona", "kg", "litr"]

while len(products) < 500:
    base_name = random.choice(high_quality_names)
    cat = "Oziq-ovqat"
    if "Sut" in base_name or "Yogurt" in base_name: cat = "Sut mahsulotlari"
    elif "Tea" in base_name or "Choy" in base_name or "Ichimlik" in base_name: cat = "Ichimliklar"
    elif "Non" in base_name or "Lochira" in base_name: cat = "Non mahsulotlari"
    elif "Avtomat" in base_name or "Domestos" in base_name or "Fairy" in base_name: cat = "Maishiy kimyo"
    elif "Soap" in base_name or "Shampoo" in base_name or "Cream" in base_name: cat = "Shaxsiy gigiyena"
    elif "Galaxy" in base_name or "iPhone" in base_name or "Flash" in base_name: cat = "Elektronika"
    
    vol = random.choice(["250g", "400g", "500g", "1kg", "1.5l", "2.0l", "0.5l"])
    full_name = f"{base_name} {vol} #{len(products)}"
    
    products.append({
        "name": full_name,
        "category": cat,
        "costPrice": 0.0,
        "price": 0.0,
        "barcode": generate_barcode(random.choice(prefixes)),
        "unit": random.choice(units)
    })

with open('assets/starter_products.json', 'w', encoding='utf-8') as f:
    json.dump(products, f, ensure_ascii=False, indent=2)

print(f"Generated {len(products)} products in assets/starter_products.json")
