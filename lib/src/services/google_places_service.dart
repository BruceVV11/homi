import 'package:google_places_sdk_plus/google_places_sdk_plus.dart';

import 'emergency_region_service.dart';

class HomiPlaceSuggestion {
  const HomiPlaceSuggestion({
    required this.placeId,
    required this.primaryText,
    required this.secondaryText,
    required this.fullText,
  });

  final String placeId;
  final String primaryText;
  final String secondaryText;
  final String fullText;
}

class HomiResolvedPlace {
  const HomiResolvedPlace({
    required this.placeId,
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String placeId;
  final String address;
  final double latitude;
  final double longitude;
}

/// Thin product boundary around Google Places API (New).
///
/// The key is supplied at build/run time and is never committed to source:
/// `--dart-define=HOMI_PLACES_API_KEY=<restricted Android key>`.
/// Homi's existing Google Cloud setup restricts the Android credential by
/// package/SHA and to Maps SDK for Android + Places API (New).
class HomiGooglePlacesService {
  HomiGooglePlacesService({String? apiKey})
      : _apiKey = apiKey ??
            const String.fromEnvironment(
              'HOMI_PLACES_API_KEY',
              defaultValue: '',
            );

  final String _apiKey;
  FlutterGooglePlacesSdk? _client;
  bool _startNewSession = true;

  bool get configured => _apiKey.trim().isNotEmpty;

  FlutterGooglePlacesSdk get _places {
    if (!configured) {
      throw StateError('Google address search is unavailable right now.');
    }
    return _client ??= FlutterGooglePlacesSdk(_apiKey.trim());
  }

  Future<List<HomiPlaceSuggestion>> search(String query) async {
    final value = query.trim();
    if (value.length < 3) return const <HomiPlaceSuggestion>[];

    try {
      final selectedRegion = EmergencyRegionService.instance.current;
      final countries = selectedRegion == null
          ? null
          : <String>[selectedRegion.isoCode];
      final response = await _places.findAutocompletePredictions(
        value,
        countries: countries,
        newSessionToken: _startNewSession,
      );
      _startNewSession = false;

      return response.predictions
          .where((prediction) => prediction.placeId?.trim().isNotEmpty == true)
          .map((prediction) {
            final placeId = prediction.placeId!.trim();
            final primary = prediction.primaryText?.trim() ?? '';
            final secondary = prediction.secondaryText?.trim() ?? '';
            final full = prediction.fullText?.trim() ?? '';
            final fallback = <String>[primary, secondary]
                .where((part) => part.isNotEmpty)
                .join(', ');

            return HomiPlaceSuggestion(
              placeId: placeId,
              primaryText: primary.isNotEmpty
                  ? primary
                  : (full.isNotEmpty ? full : 'Google Maps result'),
              secondaryText: secondary,
              fullText: full.isNotEmpty
                  ? full
                  : (fallback.isNotEmpty ? fallback : 'Google Maps result'),
            );
          })
          .toList(growable: false);
    } catch (_) {
      throw StateError(
        'Google address search could not load suggestions. Check your connection and try again.',
      );
    }
  }

  Future<HomiResolvedPlace> resolve(HomiPlaceSuggestion suggestion) async {
    try {
      final response = await _places.fetchPlace(
        suggestion.placeId,
        fields: const <PlaceField>[
          PlaceField.Id,
          PlaceField.FormattedAddress,
          PlaceField.Location,
        ],
      );
      _startNewSession = true;
      final place = response.place;
      final coordinate = place?.latLng;
      if (place == null || coordinate == null) {
        throw const FormatException('Google did not return a map position.');
      }
      final address = place.address?.trim();
      return HomiResolvedPlace(
        placeId: place.id?.trim().isNotEmpty == true
            ? place.id!.trim()
            : suggestion.placeId,
        address: address?.isNotEmpty == true ? address! : suggestion.fullText,
        latitude: coordinate.lat,
        longitude: coordinate.lng,
      );
    } catch (_) {
      _startNewSession = true;
      throw StateError(
        'Homi could not load that Google Maps place. Choose it again or use Set from here.',
      );
    }
  }

  void startNewSession() {
    _startNewSession = true;
  }
}
