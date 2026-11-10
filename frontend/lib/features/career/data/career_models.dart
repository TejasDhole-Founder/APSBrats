/// One job or one degree on someone's Journey. Mirrors the backend
/// CareerEntryDto. `endDate == null` means "still here".
class CareerEntry {
  const CareerEntry({
    required this.id,
    required this.kind,
    required this.organizationId,
    required this.organizationName,
    required this.title,
    this.fieldOfStudy,
    this.location,
    this.description,
    required this.startDate,
    this.endDate,
    this.isHidden = false,
  });

  final String id;

  /// 'WORK' or 'EDUCATION'.
  final String kind;
  final String organizationId;
  final String organizationName;

  /// Job title (WORK) or degree (EDUCATION).
  final String title;
  final String? fieldOfStudy;
  final String? location;
  final String? description;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isHidden;

  bool get isWork => kind == kWork;
  bool get isCurrent => endDate == null;

  factory CareerEntry.fromJson(Map<String, dynamic> json) => CareerEntry(
    id: json['id'] as String,
    kind: json['kind'] as String? ?? kWork,
    organizationId: json['organizationId'] as String? ?? '',
    organizationName: json['organizationName'] as String? ?? '',
    title: json['title'] as String? ?? '',
    fieldOfStudy: json['fieldOfStudy'] as String?,
    location: json['location'] as String?,
    description: json['description'] as String?,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] == null
        ? null
        : DateTime.parse(json['endDate'] as String),
    isHidden: json['isHidden'] as bool? ?? false,
  );
}

const kWork = 'WORK';
const kEducation = 'EDUCATION';

/// The one line shown under a person's name: "Engineer at Zomato", or
/// "B.Tech student at NIT Trichy". Null when they have no current entry.
String? careerHeadline(List<CareerEntry> entries) {
  final current = entries.where((e) => e.isCurrent && !e.isHidden).toList();
  final job = current.where((e) => e.isWork).firstOrNull;
  if (job != null) return '${job.title} at ${job.organizationName}';
  final study = current.where((e) => !e.isWork).firstOrNull;
  if (study != null)
    return '${study.title} student at ${study.organizationName}';
  return null;
}

/// A company or college from the autocomplete list.
class OrgOption {
  const OrgOption({
    required this.id,
    required this.name,
    this.verified = false,
  });

  final String id;
  final String name;
  final bool verified;

  factory OrgOption.fromJson(Map<String, dynamic> json) => OrgOption(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    verified: json['verified'] as bool? ?? false,
  );
}

/// What the add/edit form holds while the user types. Also saved inside the
/// onboarding draft, so it round-trips through JSON.
class CareerDraft {
  const CareerDraft({
    this.id,
    this.kind = kWork,
    this.organizationId = '',
    this.organizationName = '',
    this.title = '',
    this.fieldOfStudy = '',
    this.startYear,
    this.startMonth,
    this.endYear,
    this.endMonth,
    this.current = true,
    this.isHidden = false,
  });

  /// Set when editing an existing entry.
  final String? id;
  final String kind;

  /// Empty when the user typed a new name instead of picking from the list.
  final String organizationId;
  final String organizationName;
  final String title;
  final String fieldOfStudy;
  final int? startYear;

  /// Work only; college uses whole years.
  final int? startMonth;
  final int? endYear;
  final int? endMonth;
  final bool current;
  final bool isHidden;

  bool get isWork => kind == kWork;

  factory CareerDraft.fromEntry(CareerEntry e) => CareerDraft(
    id: e.id,
    kind: e.kind,
    organizationId: e.organizationId,
    organizationName: e.organizationName,
    title: e.title,
    fieldOfStudy: e.fieldOfStudy ?? '',
    startYear: e.startDate.year,
    startMonth: e.startDate.month,
    endYear: e.endDate?.year,
    endMonth: e.endDate?.month,
    current: e.endDate == null,
    isHidden: e.isHidden,
  );

  /// Nothing typed or picked yet: such a card is ignored, not an error.
  bool get isBlank =>
      organizationName.trim().isEmpty &&
      title.trim().isEmpty &&
      startYear == null;

  /// Why it can't be saved yet, or null when it's ready.
  String? get problem {
    if (organizationName.trim().isEmpty) {
      return isWork ? 'Enter your company' : 'Enter your college';
    }
    if (title.trim().isEmpty) {
      return isWork ? 'Enter your job title' : 'Enter your degree';
    }
    if (startYear == null) return 'Pick when you started';
    if (!current) {
      if (endYear == null) return 'Pick when you left, or mark it as current';
      final start = _date(startYear!, startMonth);
      final end = _date(endYear!, endMonth);
      if (end.isBefore(start)) return "The end can't be before the start";
    }
    return null;
  }

  /// Body for POST/PUT /career.
  Map<String, dynamic> toRequest() => {
    'kind': kind,
    if (organizationId.isNotEmpty) 'organizationId': organizationId,
    if (organizationId.isEmpty) 'organizationName': organizationName.trim(),
    'title': title.trim(),
    if (!isWork && fieldOfStudy.trim().isNotEmpty)
      'fieldOfStudy': fieldOfStudy.trim(),
    'startDate': _iso(_date(startYear!, isWork ? startMonth : null)),
    'endDate': current ? null : _iso(_date(endYear!, isWork ? endMonth : null)),
    'isHidden': isHidden,
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'organizationId': organizationId,
    'organizationName': organizationName,
    'title': title,
    'fieldOfStudy': fieldOfStudy,
    'startYear': startYear,
    'startMonth': startMonth,
    'endYear': endYear,
    'endMonth': endMonth,
    'current': current,
    'isHidden': isHidden,
  };

  factory CareerDraft.fromJson(Map<String, dynamic> json) => CareerDraft(
    id: json['id'] as String?,
    kind: json['kind'] as String? ?? kWork,
    organizationId: json['organizationId'] as String? ?? '',
    organizationName: json['organizationName'] as String? ?? '',
    title: json['title'] as String? ?? '',
    fieldOfStudy: json['fieldOfStudy'] as String? ?? '',
    startYear: (json['startYear'] as num?)?.toInt(),
    startMonth: (json['startMonth'] as num?)?.toInt(),
    endYear: (json['endYear'] as num?)?.toInt(),
    endMonth: (json['endMonth'] as num?)?.toInt(),
    current: json['current'] as bool? ?? true,
    isHidden: json['isHidden'] as bool? ?? false,
  );

  CareerDraft copyWith({
    String? kind,
    String? organizationId,
    String? organizationName,
    String? title,
    String? fieldOfStudy,
    int? startYear,
    int? startMonth,
    int? endYear,
    int? endMonth,
    bool? current,
    bool? isHidden,
  }) => CareerDraft(
    id: id,
    kind: kind ?? this.kind,
    organizationId: organizationId ?? this.organizationId,
    organizationName: organizationName ?? this.organizationName,
    title: title ?? this.title,
    fieldOfStudy: fieldOfStudy ?? this.fieldOfStudy,
    startYear: startYear ?? this.startYear,
    startMonth: startMonth ?? this.startMonth,
    endYear: endYear ?? this.endYear,
    endMonth: endMonth ?? this.endMonth,
    current: current ?? this.current,
    isHidden: isHidden ?? this.isHidden,
  );

  static DateTime _date(int year, int? month) => DateTime(year, month ?? 1);

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-01';
}
