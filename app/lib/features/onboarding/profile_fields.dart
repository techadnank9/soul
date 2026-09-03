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

const genders = <Choice>[
  Choice('male', 'Male'),
  Choice('female', 'Female'),
  Choice('nonbinary', 'Nonbinary'),
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
