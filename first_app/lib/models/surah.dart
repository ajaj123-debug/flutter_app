class Surah {
  final int id;
  final String nameAr;
  final String nameEn;
  final bool isMakki;
  final int versesCount;
  final String content;
  final String originalClassification;

  Surah({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.isMakki,
    required this.versesCount,
    required this.content,
    required this.originalClassification,
  });

  factory Surah.fromMap(Map<String, dynamic> map) {
    // Helper to safely get a value with multiple possible keys
    T? getValueWithAlternatives<T>(
        Map<String, dynamic> map, List<String> possibleKeys) {
      for (final key in possibleKeys) {
        if (map.containsKey(key) && map[key] != null) {
          return map[key] as T;
        }
      }
      return null;
    }

    // Get ID from various possible column names
    final id = getValueWithAlternatives<int>(map, [
          'id',
          'ID',
          'surah_id',
          'surahId',
          'number',
          'index',
        ]) ??
        1; // Default to 1 if no ID found

    // Get Arabic name from various possible column names
    final nameAr = getValueWithAlternatives<String>(map, [
          'name_ar',
          'nameAr',
          'arabic_name',
          'arabicName',
          'arabic',
          'name',
        ]) ??
        ''; // Default to empty string if not found

    // Get English name from various possible column names
    final nameEn = getValueWithAlternatives<String>(map, [
          'name_pron_en',
          'nameEn',
          'english_name',
          'englishName',
          'english',
          'translation',
          'name_en',
        ]) ??
        ''; // Default to empty string if not found

    // Get Makki/Madani classification
    final classificationStr = getValueWithAlternatives<String>(map, [
          'class',
          'classification',
          'type',
          'revelation_type',
          'revelationType',
        ]) ??
        'Makki'; // Default to Makki if not found

    // Check if classification is in Arabic
    final isMakki = classificationStr == 'مكية' ||
        classificationStr.toLowerCase().contains('makk');

    // Store the original value for display
    final originalClassification = classificationStr;

    // Get verses count
    final versesCount = getValueWithAlternatives<int>(map, [
          'verses_number',
          'versesNumber',
          'verses_count',
          'versesCount',
          'verse_count',
          'verseCount',
          'ayah_count',
          'ayahCount',
          'count',
        ]) ??
        0; // Default to 0 if not found

    // Get content
    final content = getValueWithAlternatives<String>(map, [
          'content',
          'text',
          'arabic_text',
          'arabicText',
          'verses',
          'ayahs',
        ]) ??
        ''; // Default to empty string if not found

    return Surah(
      id: id,
      nameAr: nameAr,
      nameEn: nameEn,
      isMakki: isMakki,
      versesCount: versesCount,
      content: content,
      originalClassification: originalClassification,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name_ar': nameAr,
      'name_pron_en': nameEn,
      'class': isMakki ? 'Makki' : 'Madani',
      'verses_number': versesCount,
      'content': content,
    };
  }
}
