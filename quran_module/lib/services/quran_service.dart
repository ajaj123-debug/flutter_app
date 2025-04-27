import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/surah.dart';

class QuranService {
  static const String baseUrl = 'http://api.alquran.cloud/v1';

  Future<List<Surah>> getSurahs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/surah'));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedData = json.decode(response.body);
        final List<dynamic> surahs = decodedData['data'];
        return surahs.map((surah) => Surah.fromJson(surah)).toList();
      } else {
        throw Exception('Failed to load surahs: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching surahs: $e');
    }
  }
}
