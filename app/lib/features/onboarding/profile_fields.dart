/// The profile fields, as keys and the words a user reads.
///
/// The keys are the API's, not the interface's. They match the enums in
/// db/src/schema.ts and the region list in api/src/profile/regions.ts. Change
/// those and this together, or a user's answer stops meaning what they
/// chose.
///
/// The region list carries no timezone. The server derives it, because a check
/// back is fired against it days later and a value that arrived from a device
/// is one we would have to trust.
class Choice {
  const Choice(this.key, this.label);
  final String key;
  final String label;
}

/// The bands do not overlap. Asked for as under 13, then 13 to 18, then 18 to
/// 25, which puts eighteen year olds in two bands at once, so each band ends
/// where the next one starts.
const ageBands = <Choice>[
  Choice('under_13', 'Under 13'),
  Choice('13_17', '13 to 17'),
  Choice('18_24', '18 to 24'),
  Choice('25_34', '25 to 34'),
  Choice('35_49', '35 to 49'),
  Choice('50_plus', '50 or over'),
];

/// Three, on the founder's call of 4 September 2026. The database enum still
/// carries nonbinary, so a row that already holds it keeps it; the profile
/// tab shows such a row's label as nothing, since labelFor finds no match.
const genders = <Choice>[
  Choice('male', 'Male'),
  Choice('female', 'Female'),
  Choice('not_said', 'Rather not say'),
];

const regions = <Choice>[
  Choice('uk', 'United Kingdom'),
  Choice('ireland', 'Ireland'),
  Choice('us_east', 'United States, east'),
  Choice('us_central', 'United States, central'),
  Choice('us_mountain', 'United States, mountain'),
  Choice('us_west', 'United States, west'),
  Choice('canada_east', 'Canada, east'),
  Choice('canada_west', 'Canada, west'),
  Choice('australia_east', 'Australia, east'),
  Choice('australia_west', 'Australia, west'),
  Choice('new_zealand', 'New Zealand'),
  Choice('india', 'India'),
  Choice('singapore', 'Singapore'),
  Choice('uae', 'United Arab Emirates'),
  Choice('south_africa', 'South Africa'),
  Choice('elsewhere', 'Somewhere else'),
];

/// The words for a stored key, or null if there is no answer to show.
String? labelFor(List<Choice> among, String? key) {
  if (key == null) return null;
  for (final choice in among) {
    if (choice.key == key) return choice.label;
  }
  return null;
}

/// A country on the map, as the region it stores as. The map shows the
/// whole world and the list has sixteen regions, so most countries store
/// as elsewhere, with the place the person picked shown back and held as
/// words.
const regionByCountry = <String, String>{
  'GBR': 'uk',
  'IRL': 'ireland',
  'NZL': 'new_zealand',
  'IND': 'india',
  'SGP': 'singapore',
  'ARE': 'uae',
  'ZAF': 'south_africa',
};

/// Three countries span several of the list's regions, and which one is
/// decided by the state. Rough, by the zone most of a state keeps: a state
/// that straddles two lands with the larger part.
const _usWest = {'Washington', 'Oregon', 'California', 'Nevada', 'Alaska', 'Hawaii'};
const _usMountain = {'Idaho', 'Montana', 'Wyoming', 'Utah', 'Colorado', 'Arizona', 'New Mexico'};
const _usCentral = {
  'North Dakota', 'South Dakota', 'Nebraska', 'Kansas', 'Oklahoma', 'Texas',
  'Minnesota', 'Iowa', 'Missouri', 'Arkansas', 'Louisiana', 'Wisconsin',
  'Illinois', 'Mississippi', 'Alabama', 'Tennessee',
};
const _canadaWest = {'British Columbia', 'Alberta', 'Saskatchewan', 'Yukon', 'Northwest Territories'};
const _australiaWest = {'Western Australia'};

/// The region a country and state store as.
String regionFor(String iso3, String? state) {
  switch (iso3) {
    case 'USA':
      if (_usWest.contains(state)) return 'us_west';
      if (_usMountain.contains(state)) return 'us_mountain';
      if (_usCentral.contains(state)) return 'us_central';
      return 'us_east';
    case 'CAN':
      return _canadaWest.contains(state) ? 'canada_west' : 'canada_east';
    case 'AUS':
      return _australiaWest.contains(state) ? 'australia_west' : 'australia_east';
    default:
      return regionByCountry[iso3] ?? 'elsewhere';
  }
}
