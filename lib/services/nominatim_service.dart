import 'dart:convert';

import 'package:http/http.dart' as http;

class NominatimService {
  NominatimService._();
  static final NominatimService instance = NominatimService._();

  static const String _userAgent = 'ChaosToursAI/1.0';
  static const Duration _timeout = Duration(seconds: 10);

  /// Reverse geocode [lat]/[lng] and return a human-readable address string,
  /// or null if the request fails.
  Future<String?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': lat.toStringAsFixed(7),
      'lon': lng.toStringAsFixed(7),
      'format': 'json',
      'addressdetails': '1',
    });

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode != 200) return null;

      final data = json.decode(response.body) as Map<String, dynamic>;
      return _buildAddress(data);
    } catch (_) {
      return null;
    }
  }

  String? _buildAddress(Map<String, dynamic> data) {
    final address = data['address'] as Map<String, dynamic>?;
    if (address == null) {
      return data['display_name'] as String?;
    }

    // Build a concise address: road + house number + postcode + city
    final parts = <String>[];
    final road = address['road'] as String?;
    final houseNumber = address['house_number'] as String?;
    final postcode = address['postcode'] as String?;
    final city =
        (address['city'] ??
                address['town'] ??
                address['village'] ??
                address['municipality'])
            as String?;

    if (road != null) {
      parts.add(houseNumber != null ? '$road $houseNumber' : road);
    }
    final cityPart = postcode != null && city != null
        ? '$postcode $city'
        : (city ?? postcode);
    if (cityPart != null) parts.add(cityPart);

    if (parts.isEmpty) {
      return data['display_name'] as String?;
    }
    return parts.join(', ');
  }
}
