import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

/// Every APS school, for the school picker.
final apsSchoolsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final dio = ref.read(dioProvider);
      final response = await dio.get<dynamic>(
        ApiEndpoints.schools,
        queryParameters: const {'page': 0, 'size': 200},
      );
      final payload = response.data as Map<String, dynamic>;
      final raw = payload['data'] as List<dynamic>? ?? [];
      return raw.whereType<Map<String, dynamic>>().toList();
    });

const kClassOptions = [
  '1st',
  '2nd',
  '3rd',
  '4th',
  '5th',
  '6th',
  '7th',
  '8th',
  '9th',
  '10th',
  '11th',
  '12th',
];

const kSectionOptions = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

/// Section dropdown: a blank choice is honest — classmates are only matched
/// when both people picked a section.
const kSectionChoices = ['', ...kSectionOptions];
String sectionLabel(String v) => v.isEmpty ? 'Not sure' : v;

/// Shows a class as a Roman numeral (1st -> I, 12th -> XII). The stored value
/// stays as it is.
String romanClass(String v) {
  final n = int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), ''));
  if (n == null || n < 1 || n > 12) return v;
  const numerals = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X',
    'XI',
    'XII',
  ];
  return numerals[n - 1];
}

/// Stream codes (as stored by the API) and their labels.
const kStreams = <String, String>{
  'SCIENCE_MEDICAL': 'Science (Medical / PCB)',
  'SCIENCE_NON_MEDICAL': 'Science (Non-Medical / PCM)',
  'SCIENCE_PCMB': 'Science (PCMB)',
  'COMMERCE': 'Commerce',
  'ARTS': 'Arts / Humanities',
};

String streamLabel(String? code) => kStreams[code] ?? '';

// ── Editor ────────────────────────────────────────────────────────────────────

/// The list of editable school cards. Used by the onboarding "Schools" step
/// and by the profile's "Edit schools" page, so both look and behave the same.
class SchoolHistoryEditor extends ConsumerWidget {
  const SchoolHistoryEditor({
    super.key,
    required this.drafts,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
  });

  final List<SchoolHistoryDraft> drafts;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int index, SchoolHistoryDraft draft) onUpdate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(apsSchoolsProvider)
        .when(
          data: (schools) => Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                for (int i = 0; i < drafts.length; i++) ...[
                  _SchoolCard(
                    key: ValueKey(i),
                    index: i,
                    entry: drafts[i],
                    schools: schools,
                    canDelete: drafts.length > 1,
                    onDelete: () => onRemove(i),
                    onChanged: (draft) => onUpdate(i, draft),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 4),
                _AddSchoolButton(onPressed: onAdd),
                const SizedBox(height: 8),
              ],
            ),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.crimson),
            ),
          ),
          error: (e, _) => _NetworkError(error: e),
        );
  }
}

// ── School card ───────────────────────────────────────────────────────────────

class _SchoolCard extends StatefulWidget {
  const _SchoolCard({
    super.key,
    required this.index,
    required this.entry,
    required this.schools,
    required this.canDelete,
    required this.onDelete,
    required this.onChanged,
  });

  final int index;
  final SchoolHistoryDraft entry;
  final List<Map<String, dynamic>> schools;
  final bool canDelete;
  final VoidCallback onDelete;
  final ValueChanged<SchoolHistoryDraft> onChanged;

  @override
  State<_SchoolCard> createState() => _SchoolCardState();
}

class _SchoolCardState extends State<_SchoolCard> {
  late final TextEditingController _yearJoinedCtrl;
  late final TextEditingController _yearLeftCtrl;

  /// Which year we worked out for the user ('joined' / 'left'), so it keeps
  /// following the other one. Typing in it yourself makes it yours (null).
  String? _auto;

  /// Saves a change, then refreshes the worked-out year (if any) to match.
  void _emit(SchoolHistoryDraft next) {
    final auto = _auto;
    widget.onChanged(auto == null ? next : fillSchoolYear(next, auto));
  }

  void _onYearJoined(String v) {
    final next = widget.entry.copyWith(yearJoined: v);
    if (_auto == 'joined') _auto = null;
    // Fill "Year left" only if it's blank or was filled by us.
    if (_auto == null && widget.entry.yearLeft.isEmpty) _auto = 'left';
    _emit(next);
  }

  void _onYearLeft(String v) {
    final next = widget.entry.copyWith(yearLeft: v);
    if (_auto == 'left') _auto = null;
    if (_auto == null && widget.entry.yearJoined.isEmpty) _auto = 'joined';
    _emit(next);
  }

  @override
  void initState() {
    super.initState();
    _yearJoinedCtrl = TextEditingController(text: widget.entry.yearJoined);
    _yearLeftCtrl = TextEditingController(text: widget.entry.yearLeft);
  }

  @override
  void didUpdateWidget(_SchoolCard old) {
    super.didUpdateWidget(old);
    if (widget.entry.yearJoined != old.entry.yearJoined &&
        widget.entry.yearJoined != _yearJoinedCtrl.text) {
      _yearJoinedCtrl.text = widget.entry.yearJoined;
    }
    if (widget.entry.yearLeft != old.entry.yearLeft &&
        widget.entry.yearLeft != _yearLeftCtrl.text) {
      _yearLeftCtrl.text = widget.entry.yearLeft;
    }
  }

  @override
  void dispose() {
    _yearJoinedCtrl.dispose();
    _yearLeftCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.crimson.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.crimson.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card header ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            decoration: BoxDecoration(
              color: AppColors.crimson.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.crimsonDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const HugeIcon(
                    icon: HugeIcons.strokeRoundedBookmark01,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'School ${widget.index + 1}',
                  style: GoogleFonts.playfairDisplay(
                    fontWeight: FontWeight.w700,
                    color: AppColors.crimson,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                if (widget.canDelete)
                  InkWell(
                    onTap: widget.onDelete,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.crimson.withValues(alpha: 0.25),
                        ),
                      ),
                      child: const HugeIcon(
                        icon: HugeIcons.strokeRoundedDelete02,
                        size: 18,
                        color: AppColors.crimson,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Card body ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CrimsonLabel('School Name'),
                const SizedBox(height: 6),
                _SchoolAutocomplete(
                  entry: entry,
                  schools: widget.schools,
                  onChanged: widget.onChanged,
                ),
                const SizedBox(height: 12),

                // FROM / TO CLASS
                Row(
                  children: [
                    Expanded(
                      child: _DropField(
                        label: 'From Class',
                        value: entry.classFrom,
                        items: kClassOptions,
                        labelOf: romanClass,
                        onChanged: (v) => _emit(entry.copyWith(classFrom: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DropField(
                        label: 'To Class',
                        value: entry.classTo,
                        items: kClassOptions,
                        labelOf: romanClass,
                        onChanged: (v) => _emit(
                          entry.copyWith(
                            classTo: v,
                            // Stream only exists from Class 11; drop it when
                            // the entry no longer reaches that far.
                            stream: needsStream(entry.copyWith(classTo: v))
                                ? entry.stream
                                : '',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // STREAM (Class 11-12 only)
                if (needsStream(entry)) ...[
                  _DropField(
                    label: 'Stream (chosen in Class 11)',
                    value: entry.stream,
                    items: kStreams.keys.toList(),
                    labelOf: streamLabel,
                    onChanged: (v) =>
                        widget.onChanged(entry.copyWith(stream: v)),
                  ),
                  const SizedBox(height: 12),
                ],

                // SECTION / YEAR JOINED / YEAR LEFT
                Row(
                  children: [
                    Expanded(
                      child: _DropField(
                        label: 'Section',
                        optional: true,
                        icon: HugeIcons.strokeRoundedUserGroup,
                        value: entry.section,
                        items: kSectionChoices,
                        labelOf: sectionLabel,
                        onChanged: (v) =>
                            widget.onChanged(entry.copyWith(section: v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _YearField(
                        label: 'Year Joined',
                        controller: _yearJoinedCtrl,
                        onChanged: _onYearJoined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _YearField(
                        label: 'Year Left',
                        controller: _yearLeftCtrl,
                        onChanged: _onYearLeft,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // FAVOURITE school row (stored as isMostMissed)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFBE4E4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: entry.isMostMissed,
                          activeColor: AppColors.crimson,
                          checkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                          onChanged: (v) => widget.onChanged(
                            entry.copyWith(isMostMissed: v ?? false),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'This was my favourite APS school',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.crimson,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      HugeIcon(
                        icon: entry.isMostMissed
                            ? HugeIcons.strokeRoundedHeart
                            : HugeIcons.strokeRoundedHeart,
                        size: 20,
                        color: AppColors.crimson,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── School autocomplete field ─────────────────────────────────────────────────

class _SchoolAutocomplete extends StatelessWidget {
  const _SchoolAutocomplete({
    required this.entry,
    required this.schools,
    required this.onChanged,
  });

  final SchoolHistoryDraft entry;
  final List<Map<String, dynamic>> schools;
  final ValueChanged<SchoolHistoryDraft> onChanged;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<Map<String, dynamic>>(
      initialValue: TextEditingValue(text: entry.schoolName),
      displayStringForOption: (s) => s['name']?.toString() ?? '',
      optionsBuilder: (tv) {
        final q = tv.text.trim().toLowerCase();
        if (q.isEmpty) return schools.take(50);
        return schools.where((s) {
          final name = (s['name'] ?? '').toString().toLowerCase();
          final city = (s['city'] ?? '').toString().toLowerCase();
          return name.contains(q) || city.contains(q);
        });
      },
      onSelected: (school) {
        onChanged(
          entry.copyWith(
            schoolId: school['id']?.toString() ?? '',
            schoolName: school['name']?.toString() ?? '',
          ),
        );
      },
      fieldViewBuilder: (context, ctrl, focusNode, onSubmitted) {
        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          style: const TextStyle(fontSize: 13),
          decoration: _fieldDecoration(
            hintText: 'APS school name',
            prefixIcon: _fieldIcon(HugeIcons.strokeRoundedBuilding06),
            suffixIcon: _fieldIcon(HugeIcons.strokeRoundedSearch01),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final s = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(s),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s['name']?.toString() ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (s['city'] != null)
                            Text(
                              s['city'].toString(),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Add school button ─────────────────────────────────────────────────────────

class _AddSchoolButton extends StatelessWidget {
  const _AddSchoolButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const HugeIcon(
          icon: HugeIcons.strokeRoundedAddCircle,
          size: 18,
          color: AppColors.crimson,
        ),
        label: const Text(
          'Add another APS school',
          style: TextStyle(
            color: AppColors.crimson,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.crimson.withValues(alpha: 0.6),
            width: 1.5,
          ),
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }
}

// ── Field widgets ─────────────────────────────────────────────────────────────

class _CrimsonLabel extends StatelessWidget {
  const _CrimsonLabel(this.text, {this.optional = false});

  final String text;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.crimson,
        ),
        children: [
          TextSpan(text: text),
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w400,
                color: Color(0xFF8A8A8A),
              ),
            )
          else
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
        ],
      ),
    );
  }
}

class _DropField extends StatelessWidget {
  const _DropField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelOf,
    this.icon = HugeIcons.strokeRoundedMortarboard01,
    this.optional = false,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final AppIconData icon;
  final bool optional;

  /// Optional display text per item (items themselves are the stored codes).
  final String Function(String)? labelOf;

  @override
  Widget build(BuildContext context) {
    // A value the dropdown does not know (e.g. old data) shows as unselected
    // instead of crashing the dropdown.
    final selected = items.contains(value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CrimsonLabel(label, optional: optional),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          menuMaxHeight: 300,
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(14),
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: AppColors.crimson,
          ),
          items: items
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: v == selected
                          ? const Color(0xFFFBE4E4)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        _fieldIcon(icon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            labelOf?.call(v) ?? v,
                            style: const TextStyle(fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (v == selected)
                          const HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                            size: 18,
                            color: AppColors.crimson,
                          ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          selectedItemBuilder: (context) => items
              .map(
                (v) => Row(
                  children: [
                    _fieldIcon(icon),
                    const SizedBox(width: 10),
                    Text(
                      labelOf?.call(v) ?? v,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          decoration: _fieldDecoration(),
        ),
      ],
    );
  }
}

class _YearField extends StatelessWidget {
  const _YearField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CrimsonLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 14),
          onTap: () async {
            final year = await showSchoolYearPicker(
              context,
              int.tryParse(controller.text),
            );
            if (year != null) onChanged('$year');
          },
          decoration: _fieldDecoration(
            hintText: 'YYYY',
            prefixIcon: _fieldIcon(HugeIcons.strokeRoundedCalendar04),
          ),
        ),
      ],
    );
  }
}

/// Opens the year wheel (1950 to now) and returns the chosen year.
Future<int?> showSchoolYearPicker(BuildContext context, int? current) {
  const minYear = 1950;
  final maxYear = DateTime.now().year;
  var selected = (current ?? maxYear).clamp(minYear, maxYear);
  final wheel = FixedExtentScrollController(initialItem: selected - minYear);

  return showDialog<int>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Select Year',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.crimson,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: Stack(
                  children: [
                    // Highlight sits under the wheel so the year stays visible.
                    IgnorePointer(
                      child: Center(
                        child: Container(
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFC76D68),
                              width: 1.5,
                            ),
                            color: const Color(0xFFFDECE3),
                          ),
                        ),
                      ),
                    ),
                    ListWheelScrollView.useDelegate(
                      controller: wheel,
                      itemExtent: 40,
                      physics: const FixedExtentScrollPhysics(),
                      onSelectedItemChanged: (i) =>
                          setDialog(() => selected = minYear + i),
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: maxYear - minYear + 1,
                        builder: (c, i) => Center(
                          child: Text(
                            '${minYear + i}',
                            style: i == selected - minYear
                                ? const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5C0F13),
                                  )
                                : const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF9A9A9A),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(selected),
                child: Container(
                  width: double.infinity,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.crimsonDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ).whenComplete(wheel.dispose);
}

// ── Error card ────────────────────────────────────────────────────────────────

class _NetworkError extends StatelessWidget {
  const _NetworkError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    String message = 'Failed to load schools';
    if (error is DioException) {
      message = (error as DioException).message ?? message;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.redAccent),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── Shared input decoration ───────────────────────────────────────────────────

InputDecoration _fieldDecoration({
  String? hintText,
  Widget? prefixIcon,
  Widget? suffixIcon,
}) {
  const border = Color(0xFFE6D5BD);
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFF9A8F84), fontSize: 13),
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: border, width: 1.2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: border, width: 1.2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
    ),
  );
}

/// Small maroon icon used inside the school fields.
Widget _fieldIcon(AppIconData icon) =>
    HugeIcon(icon: icon, size: 18, color: AppColors.crimson);
