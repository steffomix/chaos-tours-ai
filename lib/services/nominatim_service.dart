import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_service.dart';

/// A single result from a Nominatim forward-geocoding search.
class NominatimResult {
  final String displayName;
  final double lat;
  final double lng;

  const NominatimResult({
    required this.displayName,
    required this.lat,
    required this.lng,
  });
}

class NominatimService {
  NominatimService._();
  static final NominatimService instance = NominatimService._();

  /// Built-in default User-Agent, used when the user has not set a custom one.
  static String get _defaultUserAgent =>
      "ChaosTours/1.0 (user_${SettingsService.instance.deviceId})";

  /// Effective User-Agent: the user's custom value, or the default when empty.
  static String get _userAgent {
    final custom = SettingsService.instance.nominatimUserAgent;
    return custom.isNotEmpty ? custom : _defaultUserAgent;
  }

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

  /// Forward geocode using structured fields (country, city, street).
  /// Returns up to 10 matches sorted by Nominatim relevance.
  Future<List<NominatimResult>> searchAddress({
    String country = '',
    String city = '',
    String street = '',
  }) async {
    final params = <String, String>{
      'format': 'json',
      'addressdetails': '1',
      'limit': '10',
      if (country.isNotEmpty) 'country': country,
      if (city.isNotEmpty) 'city': city,
      if (street.isNotEmpty) 'street': street,
    };

    final uri = Uri.https('nominatim.openstreetmap.org', '/search', params);

    try {
      final response = await http
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(_timeout);

      if (response.statusCode != 200) return [];

      final list = json.decode(response.body) as List<dynamic>;
      return list.map((item) {
        final m = item as Map<String, dynamic>;
        return NominatimResult(
          displayName: m['display_name'] as String? ?? '',
          lat: double.tryParse(m['lat'] as String? ?? '') ?? 0.0,
          lng: double.tryParse(m['lon'] as String? ?? '') ?? 0.0,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }
}
