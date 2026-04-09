import pandas as pd

data = [
    # Ichimliklar
    ["Coca-Cola 1.5L", "Ichimliklar", 10000, 13000, "5449000131805", "dona"],
    ["Coca-Cola 0.5L", "Ichimliklar", 5000, 7000, "5449000000286", "dona"],
    ["Fanta 1.5L", "Ichimliklar", 10000, 13000, "5449000133335", "dona"],
    ["Pepsi 1.5L", "Ichimliklar", 9500, 12500, "4823063100029", "dona"],
    ["Dinay Olma 1L", "Ichimliklar", 8000, 11000, "4780000250012", "dona"],
    ["Hydrolife 0.5L gazsiz", "Ichimliklar", 2000, 3000, "4780005080010", "dona"],
    ["Flash Up Energy", "Ichimliklar", 7000, 9500, "4605634005370", "dona"],
    ["Lipton Choy 0.5L", "Ichimliklar", 5500, 7500, "5900643033104", "dona"],
    
    # Sut mahsulotlari
    ["Musaffo Sut 3.2% 1L", "Sut mahsulotlari", 11000, 14500, "4780004920027", "dona"],
    ["Musaffo Qatiq 1L", "Sut mahsulotlari", 7000, 9000, "4780004920058", "dona"],
    ["Bio-Sut 2.5% 1L", "Sut mahsulotlari", 10000, 13000, "4780003000010", "dona"],
    ["Smetana Kamilka 15% 200g", "Sut mahsulotlari", 6500, 8500, "4780002000011", "dona"],
    ["Tvorog Kamilka 9% 200g", "Sut mahsulotlari", 7500, 10000, "4780002000022", "dona"],
    
    # Qandolat
    ["Alpen Gold Chocolate 90g", "Qandolat", 11000, 14000, "7622201416750", "dona"],
    ["Snickers Bar 50g", "Qandolat", 6000, 8500, "5000159461122", "dona"],
    ["Twix Bar 50g", "Qandolat", 6000, 8500, "5000159461153", "dona"],
    ["Bounty Bar 57g", "Qandolat", 6000, 8500, "4011100196232", "dona"],
    ["Kinder Chocolate 50g", "Qandolat", 8000, 11000, "4008400000029", "dona"],
    ["Pechene Slivichniy 1kg", "Qandolat", 18000, 24000, "", "kg"],
    ["Vafele Yasnaya Polyana 1kg", "Qandolat", 25000, 32000, "", "kg"],
    
    # Oziq-ovqat
    ["Makaron Shebekinskoye 450g", "Oziq-ovqat", 8500, 11000, "4601445002001", "dona"],
    ["Guruch Lazar 1kg", "Oziq-ovqat", 18000, 22000, "", "kg"],
    ["Guruch Alanga 1kg", "Oziq-ovqat", 14000, 18000, "", "kg"],
    ["Yog' Siyom 1L", "Oziq-ovqat", 14000, 17500, "4780001000012", "dona"],
    ["Shakar 1kg", "Oziq-ovqat", 11000, 13500, "", "kg"],
    ["Tuz Osh 1kg", "Oziq-ovqat", 2000, 3000, "4780006000017", "dona"],
    ["Yumshoq Non", "Oziq-ovqat", 2500, 3000, "", "dona"],
    ["Choy Ahmad Tea 100g", "Oziq-ovqat", 18000, 23000, "054881000016", "dona"],
    
    # Maishiy kimyo
    ["Safia Suyuq Sovun 500ml", "Maishiy kimyo", 8000, 12000, "4780007000016", "dona"],
    ["Ariel Kir Poroshok 450g", "Maishiy kimyo", 15000, 20000, "4015600001234", "dona"],
    ["Fairy Idish yuvuvchi 450ml", "Maishiy kimyo", 14000, 19000, "5413149312345", "dona"],
    ["Domestos 750ml", "Maishiy kimyo", 18000, 24000, "8717163012345", "dona"],
    ["Colgate Pasta 100ml", "Maishiy kimyo", 12000, 16000, "6920395912345", "dona"],
    ["Breeze Salfetka 100talik", "Maishiy kimyo", 4000, 6000, "4780008000015", "dona"],
]

df = pd.DataFrame(data, columns=["Mahsulot nomi", "Kategoriya", "Tan narxi", "Sotish narxi", "Shtrix kod", "O'lchov birligi"])
df.to_excel("tayyor_mahsulotlar.xlsx", index=False)
print("Excel fayli 'tayyor_mahsulotlar.xlsx' nomi bilan yaratildi.")
