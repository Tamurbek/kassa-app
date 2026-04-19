class Translit {
  static const Map<String, String> _latToCyr = {
    'sh': 'ш', 'Sh': 'Ш', 'SH': 'Ш',
    'ch': 'ч', 'Ch': 'Ч', 'CH': 'Ч',
    'yo': 'ё', 'Yo': 'Ё', 'YO': 'Ё',
    'yu': 'ю', 'Yu': 'Ю', 'YU': 'Ю',
    'ya': 'я', 'Ya': 'Я', 'YA': 'Я',
    'ye': 'е', 'Ye': 'Е', 'YE': 'Е',
    "o'": 'ў', "O'": 'Ў', 'oʻ': 'ў', 'Oʻ': 'Ў', 'o’': 'ў', 'O’': 'Ў',
    "g'": 'ғ', "G'": 'Ғ', 'gʻ': 'ғ', 'Gʻ': 'Ғ', 'g’': 'ғ', 'G’': 'Ғ',
    'a': 'а', 'A': 'А',
    'b': 'б', 'B': 'Б',
    'd': 'д', 'D': 'Д',
    'e': 'е', 'E': 'Е',
    'f': 'ф', 'F': 'Ф',
    'g': 'г', 'G': 'Г',
    'h': 'ҳ', 'H': 'Ҳ',
    'i': 'и', 'I': 'И',
    'j': 'ж', 'J': 'Ж',
    'k': 'к', 'K': 'К',
    'l': 'л', 'L': 'Л',
    'm': 'м', 'M': 'М',
    'n': 'н', 'N': 'Н',
    'o': 'о', 'O': 'О',
    'p': 'п', 'P': 'П',
    'q': 'қ', 'Q': 'Қ',
    'r': 'р', 'R': 'Р',
    's': 'с', 'S': 'С',
    't': 'т', 'T': 'Т',
    'u': 'у', 'U': 'У',
    'v': 'в', 'V': 'В',
    'x': 'х', 'X': 'Х',
    'y': 'й', 'Y': 'Й',
    'z': 'з', 'Z': 'З',
  };

  static const Map<String, String> _cyrToLat = {
    'ш': 'sh', 'Ш': 'Sh',
    'ч': 'ch', 'Ч': 'Ch',
    'ё': 'yo', 'Ё': 'Yo',
    'ю': 'yu', 'Ю': 'Yu',
    'я': 'ya', 'Я': 'Ya',
    'ў': "o'", 'Ў': "O'",
    'ғ': "g'", 'Ғ': "G'",
    'қ': 'q', 'Қ': 'Q',
    'ҳ': 'h', 'Ҳ': 'H',
    'а': 'a', 'А': 'A',
    'б': 'b', 'Б': 'B',
    'в': 'v', 'В': 'V',
    'г': 'g', 'Г': 'G',
    'д': 'd', 'Д': 'D',
    'е': 'e', 'Е': 'E',
    'ж': 'j', 'Ж': 'J',
    'з': 'z', 'З': 'Z',
    'и': 'i', 'И': 'I',
    'й': 'y', 'Й': 'Y',
    'к': 'k', 'К': 'K',
    'л': 'l', 'Л': 'L',
    'м': 'm', 'М': 'M',
    'н': 'n', 'Н': 'N',
    'о': 'o', 'О': 'O',
    'п': 'p', 'П': 'P',
    'р': 'r', 'Р': 'R',
    'с': 's', 'С': 'S',
    'т': 't', 'Т': 'T',
    'у': 'u', 'У': 'U',
    'ф': 'f', 'Ф': 'F',
    'х': 'x', 'Х': 'X',
    'ц': 'ts', 'Ц': 'Ts',
    'э': 'e', 'Э': 'E',
    'ь': '', 'ъ': '',
  };

  static String toCyrillic(String latin) {
    String result = latin;
    
    // Order matters: multi-char mappings first
    final sortedKeys = _latToCyr.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var key in sortedKeys) {
      result = result.replaceAll(key, _latToCyr[key]!);
    }
    return result;
  }

  static String toLatin(String cyrillic) {
    String result = cyrillic;
    
    final sortedKeys = _cyrToLat.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (var key in sortedKeys) {
      result = result.replaceAll(key, _cyrToLat[key]!);
    }
    return result;
  }

  static List<String> getVariations(String query) {
    if (query == null || query.isEmpty) return [];
    
    Set<String> variations = {query};
    
    // Check if it looks like Latin or Cyrillic
    bool hasCyrillic = query.runes.any((rune) => rune >= 0x0400 && rune <= 0x04FF);
    
    if (hasCyrillic) {
      variations.add(toLatin(query));
    } else {
      variations.add(toCyrillic(query));
      // Also handle different types of quotes for O' and G'
      if (query.contains("'") || query.contains("ʻ") || query.contains("’") || query.contains("‘")) {
        String base = query.replaceAll(RegExp(r"[ʻ’‘']"), "'");
        variations.add(base);
        variations.add(base.replaceAll("'", "ʻ"));
        variations.add(base.replaceAll("'", "’"));
        variations.add(base.replaceAll("'", "‘"));
      }
    }
    
    return variations.toList();
  }
}
