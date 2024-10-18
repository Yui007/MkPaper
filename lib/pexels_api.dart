import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;


class PexelsApi {
  static const String _apiKey = 's8MiQx1Wre2ObqQTdmtNVdvzOxDlraQrpbhE3lyftrZfjGSDVB4nEyua';
  static const String _baseUrl = 'https://api.pexels.com/v1';

  static Future<List<dynamic>> getPhotos(String query, int page) async {
    if (query.isEmpty) {
      query = 'nature'; // Default query if empty
    }

    final url = Uri.parse('$_baseUrl/search?query=${Uri.encodeComponent(query)}&page=$page&per_page=80');

    print('Fetching photos from Pexels API');
    print('URL: $url');

    try {
      http.Response response;
      if (kIsWeb) {
        // For web platform
        response = await http.get(
          url,
          headers: {'Authorization': _apiKey},
        );
      } else {
        // For mobile platforms
        response = await http.get(
          url,
          headers: {'Authorization': _apiKey},
        );
      }

      print('Response status code: ${response.statusCode}');
      print('Response headers: ${response.headers}');

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData.containsKey('photos') && jsonData['photos'] != null) {
          return jsonData['photos'];
        } else {
          throw Exception('Photos not found in response or is null');
        }
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Failed to load photos. Status code: ${response.statusCode}. Error: ${errorBody['error']}');
      }
    } catch (e) {
      print('Error in getPhotos: $e');
      rethrow;
    }
  }
}
