import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';

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

/// Thin product boundary around Google Places Autocomplete (New).
///
/// The key is supplied at build/run time and is never committed to source:
/// `--dart-define=HOMI_PLACES_API_KEY=<restricted Android key>`.
/// Homi's existing Google Cloud setup already restricts the Android credential
/// by package/SHA and Maps SDK + Places API (New).
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
      throw StateError(
        'Google address search is not configured for this build yet.',
      );
    }
    return _client ??= FlutterGooglePlacesSdk(
      _apiKey.trim(),
      useNewApi: true,
    );
  }

  Future<List<HomiPlaceSuggestion>> search(String query) async {
    final value = query.trim();
    if (value.length < 3) return const <HomiPlaceSuggestion>[];

    try {
      final response = await _places.findAutocompletePredictions(
        value,
        countries: const <String>['ZA'],
        newSessionToken: _startNewSession,
      );
      _startNewSession = false;
      return response.predictions
          .map(
            (prediction) => HomiPlaceSuggestion(
              placeId: prediction.placeId,
              primaryText: prediction.primaryText,
              secondaryText: prediction.secondaryText,
              fullText: prediction.fullText,
            ),
          )
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
          PlaceField.Address,
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
