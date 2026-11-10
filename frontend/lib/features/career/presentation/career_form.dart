import 'dart:async';

import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/data/career_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  Widget build(BuildContext context) {
    final work = _draft.isWork;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(work ? 'COMPANY' : 'COLLEGE / INSTITUTE'),
        _OrgField(
          controller: _orgCtrl,
          focusNode: _orgFocus,
          type: work ? 'COMPANY' : 'INSTITUTION',
          hint: work ? 'Infosys, Indian Army, AIIMS…' : 'NIT Trichy, NDA, DU…',
          onTyped: (text) => _update(
            _draft.copyWith(organizationName: text, organizationId: ''),
          ),
          onPicked: (org) => _update(
            _draft.copyWith(organizationName: org.name, organizationId: org.id),
          ),
        ),
        const SizedBox(height: 12),
        _label(work ? 'JOB TITLE' : 'DEGREE'),
        TextField(
          controller: _titleCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: appInputDecoration(
            work ? 'Software Engineer, Major, Doctor…' : 'B.Tech, MBBS, B.Com…',
          ),
          onChanged: (v) => _update(_draft.copyWith(title: v)),
        ),
        if (!work) ...[
          const SizedBox(height: 12),
          _label('FIELD OF STUDY (OPTIONAL)'),
          TextField(
            controller: _fieldCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: appInputDecoration('Computer Science'),
            onChanged: (v) => _update(_draft.copyWith(fieldOfStudy: v)),
          ),
        ],
        const SizedBox(height: 12),
        _label(_draft.current ? 'SINCE' : 'FROM'),
        _DateRow(
          showMonth: work,
          month: _draft.startMonth,
          year: _draft.startYear,
          onMonth: (m) => _update(_draft.copyWith(startMonth: m)),
          onYear: (y) => _update(_draft.copyWith(startYear: y)),
        ),
        const SizedBox(height: 4),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          dense: true,
          activeTrackColor: AppColors.crimson,
          title: Text(
            work ? 'I currently work here' : 'I currently study here',
            style: const TextStyle(fontSize: 13),
          ),
          value: _draft.current,
          onChanged: (v) => _update(_draft.copyWith(current: v)),
        ),
        if (!_draft.current) ...[
          _label('TO'),
          _DateRow(
            showMonth: work,
            month: _draft.endMonth,
            year: _draft.endYear,
            onMonth: (m) => _update(_draft.copyWith(endMonth: m)),
            onYear: (y) => _update(_draft.copyWith(endYear: y)),
          ),
        ],
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: appFieldLabelStyle),
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
        decoration: appInputDecoration(widget.hint),
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
                        ? const Icon(
                            Icons.verified_rounded,
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

// ── Month + year pickers ─────────────────────────────────────────────────────

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.showMonth,
    required this.month,
    required this.year,
    required this.onMonth,
    required this.onYear,
  });

  final bool showMonth;
  final int? month;
  final int? year;
  final ValueChanged<int?> onMonth;
  final ValueChanged<int?> onYear;

  @override
  Widget build(BuildContext context) {
    final thisYear = DateTime.now().year;
    return Row(
      children: [
        if (showMonth) ...[
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: month,
              decoration: appInputDecoration('Month'),
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(value: m, child: Text(_months[m - 1])),
              ],
              onChanged: onMonth,
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: DropdownButtonFormField<int>(
            initialValue: year,
            decoration: appInputDecoration('Year'),
            menuMaxHeight: 300,
            items: [
              for (var y = thisYear; y >= 1950; y--)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: onYear,
          ),
        ),
      ],
    );
  }
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
