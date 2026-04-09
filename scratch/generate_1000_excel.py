import pandas as pd
import random

# Base lists for generation
brands = {
    "Ichimliklar": ["Coca-Cola", "Pepsi", "Fanta", "Sprite", "Dinay", "Hydrolife", "Chortoq", "Borjomi", "Lipton", "FuseTea", "Flash Up", "Adrenaline Rush", "Molochnaya Reka", "Rich", "J7", "Bliss"],
    "Sut mahsulotlari": ["Musaffo", "Bio-Sut", "Kamilka", "Lactel", "Prostokvashino", "Domik v Derevne", "Sami", "Pishir-pishir"],
    "Qandolat": ["Alpen Gold", "Snickers", "Twix", "Bounty", "Mars", "Kinder", "Milka", "Nestle", "Roshen", "Konty", "Yasnaya Polyana", "Slavyanka", "Lotte"],
    "Oziq-ovqat": ["Makfa", "Shebekino", "Siyom", "Moya Semya", "Ahmad Tea", "Greenfield", "Curtis", "Dilmah", "Baraka", "Lazar", "Alanga", "Koguruchi"],
    "Maishiy kimyo": ["Ariel", "Tide", "Persil", "Fairy", "Domestos", "Colgate", "Oral-B", "Paltmolive", "SafeGuard", "Nivea", "Rexona", "Old Spice"],
    "Kantselyariya": ["ErichKrause", "Deli", "Centropen", "Berlingo"],
    "Non mahsulotlari": ["Buxanka", "Patir", "Lochira", "Rogalik"],
}

units = ["dona", "kg", "litr", "blok", "pachka"]

data = []

# 1. Existing specific products (~35)
specific_products = [
    ["Coca-Cola 1.5L", "Ichimliklar", 10000, 13000, "5449000131805", "dona"],
    ["Pepsi 1.5L", "Ichimliklar", 9500, 12500, "4823063100029", "dona"],
    ["Musaffo Sut 3.2% 1L", "Sut mahsulotlari", 11000, 14500, "4780004920027", "dona"],
    ["Ariel 450g", "Maishiy kimyo", 15000, 20000, "4015600001234", "dona"],
    # ... more added in generation loop
]

# Generate 1000 items
categories = list(brands.keys())
used_barcodes = set(["5449000131805", "4823063100029", "4780004920027", "4015600001234"])

def gen_barcode():
    while True:
        bc = "".join([str(random.randint(0, 9)) for _ in range(13)])
        if bc not in used_barcodes:
            used_barcodes.add(bc)
            return bc

# Pre-population with variations
for cat, b_list in brands.items():
    for brand in b_list:
        for size in ["0.5L", "1L", "1.5L", "2L", "100g", "200g", "450g", "1kg"]:
            name = f"{brand} {cat[:-2] if cat.endswith('lar') else cat} {size}"
            cost = random.randint(20, 200) * 100
            price = int(cost * random.uniform(1.15, 1.4) / 100) * 100
            unit = "dona" if any(x in size for x in ["L", "g"]) else "kg"
            data.append([name, cat, cost, price, gen_barcode(), unit])

# Fill the rest to reach 1000
while len(data) < 1000:
    cat = random.choice(categories)
    brand = random.choice(brands[cat])
    item_num = len(data) + 1
    name = f"{brand} Mahsulot №{item_num}"
    cost = random.randint(10, 500) * 100
    price = int(cost * random.uniform(1.1, 1.5) / 100) * 100
    unit = random.choice(units)
    data.append([name, cat, cost, price, gen_barcode(), unit])

# Trim to exactly 1000 if needed
data = data[:1000]

df = pd.DataFrame(data, columns=["Mahsulot nomi", "Kategoriya", "Tan narxi", "Sotish narxi", "Shtrix kod", "O'lchov birligi"])
df.to_excel("tayyor_mahsulotlar_1000.xlsx", index=False)
print("1000 ta mahsulotli Excel fayli 'tayyor_mahsulotlar_1000.xlsx' nomi bilan yaratildi.")
