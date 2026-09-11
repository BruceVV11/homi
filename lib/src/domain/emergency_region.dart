enum EmergencyServiceKind {
  emergency,
  police,
  ambulance,
  fire,
}

class EmergencyContact {
  const EmergencyContact({
    required this.kind,
    required this.label,
    required this.number,
    this.note,
    this.primary = false,
  });

  final EmergencyServiceKind kind;
  final String label;
  final String number;
  final String? note;
  final bool primary;
}

class EmergencyRegion {
  const EmergencyRegion({
    required this.isoCode,
    required this.countryName,
    required this.contacts,
    required this.dataBasis,
  });

  final String isoCode;
  final String countryName;
  final List<EmergencyContact> contacts;

  /// Internal provenance/review note. It is not presented as a guarantee that
  /// a responder or a specific number is available in every local condition.
  final String dataBasis;

  EmergencyContact? get primaryContact {
    for (final contact in contacts) {
      if (contact.primary) return contact;
    }
    return null;
  }
}

/// Emergency numbers bundled in the application binary.
///
/// Homi never needs Firebase or mobile data to show these values. The catalog
/// intentionally fails closed: an unsupported region gets no invented fallback
/// number. Every market enabled in a public store rollout must be checked
/// against ITU-T E.129 and/or the relevant national public-safety authority as
/// part of release governance.
abstract final class EmergencyRegionCatalog {
  static const String ituBasis =
      'Bundled ITU-T E.129 / national public-safety baseline';
  static const String eu112Basis =
      'EU 112 framework / national public-safety baseline';

  static const EmergencyRegion southAfrica = EmergencyRegion(
    isoCode: 'ZA',
    countryName: 'South Africa',
    dataBasis: ituBasis,
    contacts: <EmergencyContact>[
      EmergencyContact(
        kind: EmergencyServiceKind.emergency,
        label: 'Emergency',
        number: '112',
        note: 'From a mobile phone',
        primary: true,
      ),
      EmergencyContact(
        kind: EmergencyServiceKind.police,
        label: 'Police emergency',
        number: '10111',
      ),
      EmergencyContact(
        kind: EmergencyServiceKind.ambulance,
        label: 'Ambulance emergency',
        number: '10177',
      ),
    ],
  );

  static const Map<String, String> _eu112Countries = <String, String>{
    'AT': 'Austria',
    'BE': 'Belgium',
    'BG': 'Bulgaria',
    'HR': 'Croatia',
    'CY': 'Cyprus',
    'CZ': 'Czechia',
    'DK': 'Denmark',
    'EE': 'Estonia',
    'FI': 'Finland',
    'FR': 'France',
    'DE': 'Germany',
    'GR': 'Greece',
    'HU': 'Hungary',
    'IE': 'Ireland',
    'IT': 'Italy',
    'LV': 'Latvia',
    'LT': 'Lithuania',
    'LU': 'Luxembourg',
    'MT': 'Malta',
    'NL': 'Netherlands',
    'PL': 'Poland',
    'PT': 'Portugal',
    'RO': 'Romania',
    'SK': 'Slovakia',
    'SI': 'Slovenia',
    'ES': 'Spain',
    'SE': 'Sweden',
  };

  static EmergencyRegion _universal(
    String isoCode,
    String countryName,
    String number, {
    String? note,
    String dataBasis = ituBasis,
  }) =>
      EmergencyRegion(
        isoCode: isoCode,
        countryName: countryName,
        dataBasis: dataBasis,
        contacts: <EmergencyContact>[
          EmergencyContact(
            kind: EmergencyServiceKind.emergency,
            label: 'Emergency',
            number: number,
            note: note,
            primary: true,
          ),
        ],
      );

  static final List<EmergencyRegion> regions = <EmergencyRegion>[
    southAfrica,
    ..._eu112Countries.entries.map(
      (entry) => _universal(
        entry.key,
        entry.value,
        '112',
        dataBasis: eu112Basis,
      ),
    ),
    _universal('US', 'United States', '911'),
    _universal('CA', 'Canada', '911'),
    const EmergencyRegion(
      isoCode: 'GB',
      countryName: 'United Kingdom',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.emergency,
          label: 'Emergency',
          number: '999',
          primary: true,
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.emergency,
          label: 'Emergency alternate',
          number: '112',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'AU',
      countryName: 'Australia',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.emergency,
          label: 'Emergency',
          number: '000',
          primary: true,
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.emergency,
          label: 'Emergency alternate',
          number: '112',
          note: 'Mobile phones',
        ),
      ],
    ),
    _universal('NZ', 'New Zealand', '111'),
    _universal('IS', 'Iceland', '112'),
    _universal('NO', 'Norway', '112'),
    _universal('CH', 'Switzerland', '112'),
    _universal('TR', 'Türkiye', '112'),
    _universal('IN', 'India', '112'),
    _universal('PH', 'Philippines', '911'),
    _universal('MX', 'Mexico', '911'),
    _universal('CO', 'Colombia', '123'),
    _universal('CR', 'Costa Rica', '911'),
    _universal('EC', 'Ecuador', '911'),
    _universal('DO', 'Dominican Republic', '911'),
    _universal('NG', 'Nigeria', '112'),
    _universal('RW', 'Rwanda', '112'),
    const EmergencyRegion(
      isoCode: 'JP',
      countryName: 'Japan',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '110',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance & fire',
          number: '119',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'KR',
      countryName: 'South Korea',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '112',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance & fire',
          number: '119',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'CN',
      countryName: 'China',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '110',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '120',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '119',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'SG',
      countryName: 'Singapore',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '999',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance & fire',
          number: '995',
        ),
      ],
    ),
    _universal('MY', 'Malaysia', '999'),
    const EmergencyRegion(
      isoCode: 'AE',
      countryName: 'United Arab Emirates',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '999',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '998',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '997',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'IL',
      countryName: 'Israel',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '100',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '101',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '102',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'BR',
      countryName: 'Brazil',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '190',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '192',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '193',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'CL',
      countryName: 'Chile',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '133',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '131',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '132',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'TH',
      countryName: 'Thailand',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '191',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Medical emergency',
          number: '1669',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '199',
        ),
      ],
    ),
    const EmergencyRegion(
      isoCode: 'VN',
      countryName: 'Vietnam',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '113',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '115',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '114',
        ),
      ],
    ),
    _universal('BD', 'Bangladesh', '999'),
    _universal('QA', 'Qatar', '999'),
    _universal('BH', 'Bahrain', '999'),
    _universal('KW', 'Kuwait', '112'),
    _universal('OM', 'Oman', '9999'),
    _universal('JO', 'Jordan', '911'),
    const EmergencyRegion(
      isoCode: 'EG',
      countryName: 'Egypt',
      dataBasis: ituBasis,
      contacts: <EmergencyContact>[
        EmergencyContact(
          kind: EmergencyServiceKind.police,
          label: 'Police',
          number: '122',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.ambulance,
          label: 'Ambulance',
          number: '123',
        ),
        EmergencyContact(
          kind: EmergencyServiceKind.fire,
          label: 'Fire',
          number: '180',
        ),
      ],
    ),
  ];

  static EmergencyRegion? byIsoCode(String? value) {
    final isoCode = value?.trim().toUpperCase();
    if (isoCode == null || isoCode.length != 2) return null;
    for (final region in regions) {
      if (region.isoCode == isoCode) return region;
    }
    return null;
  }

  static List<EmergencyRegion> get sortedRegions {
    final result = List<EmergencyRegion>.of(regions);
    result.sort((a, b) => a.countryName.compareTo(b.countryName));
    return result;
  }
}
