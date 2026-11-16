import 'dart:async';

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/data/career_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _border = Color(0xFFE2DDD5);

/// The look shared by every field in the career form: white fill, a maroon
/// icon on the left, and an optional chevron on the right.
InputDecoration _careerDecoration(
  String hint, {
  AppIconData? icon,
  bool chevron = false,
  bool enabled = true,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9A8F84), fontSize: 13),
    prefixIcon: icon == null
        ? null
        : HugeIcon(icon: icon, size: 18, color: AppColors.crimson),
    suffixIcon: chevron
        ? const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowDown01,
            color: AppColors.crimson,
          )
        : null,
    filled: true,
    fillColor: enabled ? Colors.white : const Color(0xFFF3F0EC),
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
    ),
  );
}

/// The fields for one job or one degree. Used by the signup "After school"
/// step and by the profile's add/edit sheet, so both look and behave the same.
class CareerForm extends StatefulWidget {
  const CareerForm({
    super.key,
    required this.initial,
    required this.onChanged,
    this.showHiddenToggle = false,
  });

  final CareerDraft initial;
  final ValueChanged<CareerDraft> onChanged;

  /// Only on the profile; at signup everything starts visible.
  final bool showHiddenToggle;

  @override
  State<CareerForm> createState() => _CareerFormState();
}

class _CareerFormState extends State<CareerForm> {
  late CareerDraft _draft = widget.initial;
  late final _orgCtrl = TextEditingController(text: _draft.organizationName);
  late final _titleCtrl = TextEditingController(text: _draft.title);
  late final _fieldCtrl = TextEditingController(text: _draft.fieldOfStudy);
  final _orgFocus = FocusNode();

  @override
  void dispose() {
    _orgCtrl.dispose();
    _titleCtrl.dispose();
    _fieldCtrl.dispose();
    _orgFocus.dispose();
    super.dispose();
  }

  void _update(CareerDraft next) {
    setState(() => _draft = next);
    widget.onChanged(next);
  }

  /// "Mar 2019" for a job, "2019" for a degree. Null while nothing is picked.
  String? _formatDate(int? month, int? year, {required bool withMonth}) {
    if (year == null) return null;
    if (!withMonth) return '$year';
    return '${_months[(month ?? 1) - 1]} $year';
  }

  Future<void> _pickStart(bool work) async {
    final picked = await _pickMonthYear(
      context,
      title: work ? 'Start date' : 'Start year',
      withMonth: work,
      month: _draft.startMonth,
      year: _draft.startYear,
    );
    if (picked != null) {
      _update(
        _draft.copyWith(startMonth: picked.month, startYear: picked.year),
      );
    }
  }

  Future<void> _pickEnd(bool work) async {
    final picked = await _pickMonthYear(
      context,
      title: work ? 'End date' : 'End year',
      withMonth: work,
      month: _draft.endMonth,
      year: _draft.endYear,
    );
    if (picked != null) {
      _update(_draft.copyWith(endMonth: picked.month, endYear: picked.year));
    }
  }

  @override
  Widget build(BuildContext context) {
    final work = _draft.isWork;
    final from = _formatDate(
      _draft.startMonth,
      _draft.startYear,
      withMonth: work,
    );
    final to = _draft.current
        ? null
        : _formatDate(_draft.endMonth, _draft.endYear, withMonth: work);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(work ? 'Company' : 'College / Institute'),
        _OrgField(
          controller: _orgCtrl,
          focusNode: _orgFocus,
          type: work ? 'COMPANY' : 'INSTITUTION',
          hint: work
              ? 'e.g. Infosys, TCS, Indian Army'
              : 'e.g. NIT Trichy, NDA, Delhi University',
          onTyped: (text) => _update(
            _draft.copyWith(organizationName: text, organizationId: ''),
          ),
          onPicked: (org) => _update(
            _draft.copyWith(organizationName: org.name, organizationId: org.id),
          ),
        ),
        const SizedBox(height: 12),
        _label(work ? 'Job Title' : 'Degree'),
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 14),
          decoration: _careerDecoration(
            work
                ? 'e.g. Software Engineer, Product Manager'
                : 'e.g. B.Tech, MBBS, B.Com',
            icon: work
                ? HugeIcons.strokeRoundedIdCard
                : HugeIcons.strokeRoundedMedal01,
            chevron: !work,
          ),
          onChanged: (v) => _update(_draft.copyWith(title: v)),
        ),
        if (!work) ...[
          const SizedBox(height: 12),
          _label('Field of Study', required: false),
          TextField(
            controller: _fieldCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(fontSize: 14),
            decoration: _careerDecoration(
              'e.g. Computer Science',
              icon: HugeIcons.strokeRoundedLayers01,
              chevron: true,
            ),
            onChanged: (v) => _update(_draft.copyWith(fieldOfStudy: v)),
          ),
        ],
        const SizedBox(height: 12),
        _label('Duration'),
        Row(
          children: [
            Expanded(
              child: _PickerField(
                text: from,
                hint: work ? 'From Month, Year' : 'From Year',
                icon: HugeIcons.strokeRoundedCalendar04,
                onTap: () => _pickStart(work),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _PickerField(
                text: to,
                hint: _draft.current
                    ? ''
                    : (work ? 'To Month, Year' : 'To Year'),
                icon: work ? null : HugeIcons.strokeRoundedCalendar04,
                enabled: !_draft.current,
                onTap: () => _pickEnd(work),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                work ? 'Currently working here' : 'Currently studying here',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.crimsonDark,
                ),
              ),
            ),
            Switch(
              value: _draft.current,
              activeTrackColor: AppColors.crimson,
              thumbColor: const WidgetStatePropertyAll(Colors.white),
              onChanged: (v) => _update(_draft.copyWith(current: v)),
            ),
          ],
        ),
        if (widget.showHiddenToggle)
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            activeTrackColor: AppColors.crimson,
            title: const Text(
              'Hide from my profile',
              style: TextStyle(fontSize: 13),
            ),
            subtitle: const Text(
              'Only you will see it',
              style: TextStyle(fontSize: 11),
            ),
            value: _draft.isHidden,
            onChanged: (v) => _update(_draft.copyWith(isHidden: v)),
          ),
      ],
    );
  }

  Widget _label(String text, {bool required = true}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(
      TextSpan(
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppColors.crimson,
        ),
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFC62828)),
            ),
        ],
      ),
    ),
  );
}

// ── Company / college field with suggestions ─────────────────────────────────

class _OrgField extends ConsumerStatefulWidget {
  const _OrgField({
    required this.controller,
    required this.focusNode,
    required this.type,
    required this.hint,
    required this.onTyped,
    required this.onPicked,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String type;
  final String hint;
  final ValueChanged<String> onTyped;
  final ValueChanged<OrgOption> onPicked;

  @override
  ConsumerState<_OrgField> createState() => _OrgFieldState();
}

class _OrgFieldState extends ConsumerState<_OrgField> {
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  /// Waits for a short pause in typing before asking the server, so typing
  /// "zomato" sends one request instead of six.
  Future<List<OrgOption>> _search(String text) {
    _debounce?.cancel();
    final done = Completer<List<OrgOption>>();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        done.complete(
          await ref
              .read(careerRepositoryProvider)
              .searchOrganizations(widget.type, text),
        );
      } catch (_) {
        done.complete(const []);
      }
    });
    return done.future;
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<OrgOption>(
      textEditingController: widget.controller,
      focusNode: widget.focusNode,
      displayStringForOption: (o) => o.name,
      optionsBuilder: (value) async {
        final text = value.text.trim();
        if (text.length < 2) return const [];
        final found = await _search(text);
        final exact = found.any(
          (o) => o.name.toLowerCase() == text.toLowerCase(),
        );
        // Last row: keep exactly what was typed (it becomes a new entry).
        return [...found, if (!exact) OrgOption(id: '', name: text)];
      },
      onSelected: (o) =>
          o.id.isEmpty ? widget.onTyped(o.name) : widget.onPicked(o),
      fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 14),
        decoration: _careerDecoration(
          widget.hint,
          icon: HugeIcons.strokeRoundedBuilding06,
        ),
        onChanged: widget.onTyped,
      ),
      optionsViewBuilder: (context, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: AppRadius.sm,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                for (final o in options)
                  ListTile(
                    dense: true,
                    title: Text(
                      o.id.isEmpty ? 'Add "${o.name}"' : o.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: o.id.isEmpty ? AppColors.crimson : null,
                        fontWeight: o.id.isEmpty ? FontWeight.w600 : null,
                      ),
                    ),
                    trailing: o.verified
                        ? const HugeIcon(
                            icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                            size: 16,
                            color: Color(0xFF2E7D32),
                          )
                        : null,
                    onTap: () => onSelected(o),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Date fields ──────────────────────────────────────────────────────────────

/// A field that looks like a dropdown and opens the month/year wheel on tap.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.text,
    required this.hint,
    required this.onTap,
    this.icon,
    this.enabled = true,
  });

  final String? text;
  final String hint;
  final AppIconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(10),
      child: InputDecorator(
        isEmpty: false,
        decoration: _careerDecoration(
          '',
          icon: icon,
          chevron: true,
          enabled: enabled,
        ),
        child: Text(
          text ?? hint,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            color: text == null
                ? const Color(0xFF9A8F84)
                : const Color(0xFF1A0A0A),
          ),
        ),
      ),
    );
  }
}

/// The month/year (or year only) wheel dialog. Returns null if dismissed.
Future<({int? month, int year})?> _pickMonthYear(
  BuildContext context, {
  required String title,
  required bool withMonth,
  int? month,
  int? year,
}) {
  const minYear = 1950;
  final maxYear = DateTime.now().year;
  var m = month ?? DateTime.now().month;
  var y = (year ?? maxYear).clamp(minYear, maxYear);
  final monthWheel = FixedExtentScrollController(initialItem: m - 1);
  final yearWheel = FixedExtentScrollController(initialItem: y - minYear);

  Widget wheel({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required String Function(int) label,
    required ValueChanged<int> onChanged,
  }) {
    return Stack(
      children: [
        // Highlight sits under the wheel so the value stays visible.
        IgnorePointer(
          child: Center(
            child: Container(
              height: 40,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFC76D68), width: 1.5),
                color: const Color(0xFFFDECE3),
              ),
            ),
          ),
        ),
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 40,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: count,
            builder: (context, i) => Center(
              child: Text(
                label(i),
                style: i == selected
                    ? GoogleFonts.playfairDisplay(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF5C0F13),
                      )
                    : GoogleFonts.playfairDisplay(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9A9A9A),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  return showDialog<({int? month, int year})>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialog) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBF6),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.crimson,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    if (withMonth)
                      Expanded(
                        child: wheel(
                          controller: monthWheel,
                          count: 12,
                          selected: m - 1,
                          label: (i) => _months[i],
                          onChanged: (i) => setDialog(() => m = i + 1),
                        ),
                      ),
                    Expanded(
                      child: wheel(
                        controller: yearWheel,
                        count: maxYear - minYear + 1,
                        selected: y - minYear,
                        label: (i) => '${minYear + i}',
                        onChanged: (i) => setDialog(() => y = minYear + i),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => Navigator.of(
                  ctx,
                ).pop((month: withMonth ? m : null, year: y)),
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
  ).whenComplete(() {
    monthWheel.dispose();
    yearWheel.dispose();
  });
}

// ── Add / edit sheet on the profile ──────────────────────────────────────────

/// Opens the add/edit sheet. Returns after the user saves, deletes or closes it.
Future<void> showCareerSheet(BuildContext context, CareerDraft initial) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CareerSheet(initial: initial),
  );
}

class _CareerSheet extends ConsumerStatefulWidget {
  const _CareerSheet({required this.initial});

  final CareerDraft initial;

  @override
  ConsumerState<_CareerSheet> createState() => _CareerSheetState();
}

class _CareerSheetState extends ConsumerState<_CareerSheet> {
  late CareerDraft _draft = widget.initial;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(myCareerProvider);
      if (mounted) Navigator.of(context).pop();
    } on DioException catch (e) {
      final payload = e.response?.data;
      final message = payload is Map<String, dynamic> ? payload['error'] : null;
      setState(
        () => _error = message is String && message.isNotEmpty
            ? message
            : "Couldn't save. Check your connection and try again.",
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _save() {
    final problem = _draft.problem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    _run(() => ref.read(careerRepositoryProvider).save(_draft));
  }

  void _delete() =>
      _run(() => ref.read(careerRepositoryProvider).delete(_draft.id!));

  @override
  Widget build(BuildContext context) {
    final editing = _draft.id != null;
    final noun = _draft.isWork ? 'job' : 'college';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              editing ? 'Edit $noun' : 'Add $noun',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            CareerForm(
              initial: _draft,
              showHiddenToggle: true,
              onChanged: (d) => setState(() {
                _draft = d;
                _error = null;
              }),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.crimsonDark,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save'),
            ),
            if (editing)
              TextButton(
                onPressed: _busy ? null : _delete,
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
