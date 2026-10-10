/// ISO-3166 alpha-2 codes with display names. Flags are derived from the code
/// (regional-indicator emoji), so no image assets are needed.
const kCountries = <String, String>{
  'AR': 'Argentina',
  'AU': 'Australia',
  'AT': 'Austria',
  'BD': 'Bangladesh',
  'BE': 'Belgium',
  'BR': 'Brazil',
  'CA': 'Canada',
  'CL': 'Chile',
  'CN': 'China',
  'CO': 'Colombia',
  'HR': 'Croatia',
  'CZ': 'Czechia',
  'DK': 'Denmark',
  'EG': 'Egypt',
  'FI': 'Finland',
  'FR': 'France',
  'DE': 'Germany',
  'GR': 'Greece',
  'HK': 'Hong Kong',
  'HU': 'Hungary',
  'IN': 'India',
  'ID': 'Indonesia',
  'IE': 'Ireland',
  'IL': 'Israel',
  'IT': 'Italy',
  'JP': 'Japan',
  'KE': 'Kenya',
  'MY': 'Malaysia',
  'MX': 'Mexico',
  'NP': 'Nepal',
  'NL': 'Netherlands',
  'NZ': 'New Zealand',
  'NG': 'Nigeria',
  'NO': 'Norway',
  'PK': 'Pakistan',
  'PE': 'Peru',
  'PH': 'Philippines',
  'PL': 'Poland',
  'PT': 'Portugal',
  'RO': 'Romania',
  'RU': 'Russia',
  'SA': 'Saudi Arabia',
  'SG': 'Singapore',
  'ZA': 'South Africa',
  'KR': 'South Korea',
  'ES': 'Spain',
  'LK': 'Sri Lanka',
  'SE': 'Sweden',
  'CH': 'Switzerland',
  'TW': 'Taiwan',
  'TH': 'Thailand',
  'TR': 'Turkey',
  'UA': 'Ukraine',
  'AE': 'United Arab Emirates',
  'GB': 'United Kingdom',
  'US': 'United States',
  'VN': 'Vietnam',
};

String? flagEmoji(String? code) {
  if (code == null || code.length != 2) return null;
  final up = code.toUpperCase();
  if (!RegExp(r'^[A-Z]{2}$').hasMatch(up)) return null;
  return String.fromCharCodes([
    0x1F1E6 + up.codeUnitAt(0) - 65,
    0x1F1E6 + up.codeUnitAt(1) - 65,
  ]);
}

String countryName(String? code) => kCountries[code?.toUpperCase()] ?? '';
