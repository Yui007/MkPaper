import 'dart:convert';
import 'package:http/http.dart' as http;

class UnsplashApi {
  static const String _apiKey = 'bvFLCvPeYf83x6E0Z1fAAq_aNOjAhuqofayR5E3Hvo0';
  static const String _baseUrl = 'https://api.unsplash.com';

  Future<List<dynamic>> fetchWallpapers({int page = 1, String? query}) async {
    final Uri url;
    if (query != null && query.isNotEmpty) {
      url = Uri.parse('$_baseUrl/search/photos?client_id=$_apiKey&page=$page&per_page=30&query=${Uri.encodeComponent(query)}');
    } else {
      url = Uri.parse('$_baseUrl/photos?client_id=$_apiKey&page=$page&per_page=30');
    }
    
    print('Unsplash API Request URL: $url');
    print('Fetching page: $page');

    try {
      final response = await http.get(url);
      
      print('Unsplash API Response Status Code: ${response.statusCode}');
      print('Unsplash API Response Headers: ${response.headers}');

      if (response.statusCode == 200) {
        final dynamic jsonData = jsonDecode(response.body);
        if (jsonData == null) {
          print('Received null response from Unsplash API');
          return [];
        }
        if (query != null && query.isNotEmpty) {
          if (jsonData['results'] == null) {
            print('Received null results from Unsplash API search');
            return [];
          }
          return jsonData['results'] as List<dynamic>;
        } else {
          if (jsonData is! List<dynamic>) {
            print('Unexpected response format from Unsplash API: ${jsonData.runtimeType}');
            return [];
          }
          return jsonData;
        }
      } else {
        print('Failed to load wallpapers. Status code: ${response.statusCode}, Response: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error in fetchWallpapers: $e');
      return [];
    }
  }
}