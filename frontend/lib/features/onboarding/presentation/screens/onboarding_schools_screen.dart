import 'package:apsbrat_frontend/core/constants/api_endpoints.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingSchoolsScreen extends ConsumerStatefulWidget {
  const OnboardingSchoolsScreen({super.key});

  @override
  ConsumerState<OnboardingSchoolsScreen> createState() =>
      _OnboardingSchoolsScreenState();
}

class _OnboardingSchoolsScreenState
    extends ConsumerState<OnboardingSchoolsScreen> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(onboardingFlowProvider);
    final schoolsAsync = ref.watch(_schoolsProvider);

    return OnboardingFrame(
      step: 3,
      title: 'Which APS schools did you call home?',
      subtitle:
          'Add every school you attended — even one year counts. Your batchmates are waiting.',
      footer: _Footer(
        onNext: () {
          final valid = ref
              .read(onboardingFlowProvider.notifier)
              .validateSchoolDrafts();
          if (!valid) {
            setState(
              () => _error =
                  'Please select a school, class from, and class to for each card.',
            );
            return;
          }
          setState(() => _error = null);
          context.go('/onboarding/verify/schools/socials');
        },
        error: _error,
      ),
      child: schoolsAsync.when(
        data: (schools) => _SchoolsList(
          flow: flow,
          schools: schools,
          onAdd: () =>
              ref.read(onboardingFlowProvider.notifier).addSchoolDraft(),
          onRemove: (i) =>
              ref.read(onboardingFlowProvider.notifier).removeSchoolDraft(i),
          onUpdate: (i, draft) => ref
              .read(onboardingFlowProvider.notifier)
              .updateSchoolDraft(i, draft),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.crimson),
          ),
        ),
        error: (e, _) => _NetworkError(error: e),
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

final _schoolsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>(
  (ref) async {
    final dio = ref.read(dioProvider);
    final response = await dio.get<dynamic>(
      ApiEndpoints.schools,
      queryParameters: const {'page': 0, 'size': 200},
    );
    final payload = response.data as Map<String, dynamic>;
    final raw = payload['data'] as List<dynamic>? ?? [];
    return raw.whereType<Map<String, dynamic>>().toList();
  },
);

const _classes = [
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

const _sections = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

// ── Schools list ──────────────────────────────────────────────────────────────

class _SchoolsList extends StatelessWidget {
  const _SchoolsList({
    required this.flow,
    required this.schools,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
  });

  final OnboardingFlowState flow;
  final List<Map<String, dynamic>> schools;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, SchoolHistoryDraft) onUpdate;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          for (int i = 0; i < flow.schoolHistory.length; i++) ...[
            _SchoolCard(
              key: ValueKey(i),
              index: i,
              entry: flow.schoolHistory[i],
              schools: schools,
              canDelete: flow.schoolHistory.length > 1,
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
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            decoration: BoxDecoration(
              color: AppColors.crimson.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.crimsonDark,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'School ${widget.index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.crimsonDark,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                if (widget.canDelete)
                  IconButton(
                    onPressed: widget.onDelete,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.crimson.withValues(alpha: 0.6),
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
                        value: entry.classFrom.isEmpty ? null : entry.classFrom,
                        items: _classes,
                        onChanged: (v) =>
                            widget.onChanged(entry.copyWith(classFrom: v)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DropField(
                        label: 'To Class',
                        value: entry.classTo.isEmpty ? null : entry.classTo,
                        items: _classes,
                        onChanged: (v) =>
                            widget.onChanged(entry.copyWith(classTo: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // SECTION / YEAR JOINED / YEAR LEFT
                Row(
                  children: [
                    Expanded(
                      child: _DropField(
                        label: 'Section',
                        value: entry.section.isEmpty ? null : entry.section,
                        items: _sections,
                        onChanged: (v) =>
                            widget.onChanged(entry.copyWith(section: v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _YearField(
                        label: 'Year Joined',
                        controller: _yearJoinedCtrl,
                        onChanged: (v) =>
                            widget.onChanged(entry.copyWith(yearJoined: v)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _YearField(
                        label: 'Year Left',
                        controller: _yearLeftCtrl,
                        onChanged: (v) =>
                            widget.onChanged(entry.copyWith(yearLeft: v)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // MOST MISSED checkbox
                Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: entry.isMostMissed,
                        activeColor: AppColors.crimson,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (v) => widget.onChanged(
                          entry.copyWith(isMostMissed: v ?? false),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This is the school I miss the most',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.crimsonDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
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
          decoration: _fieldDecoration(hintText: 'Search from APS schools...'),
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
        icon: const Icon(
          Icons.add_circle_outline_rounded,
          size: 16,
          color: AppColors.crimson,
        ),
        label: const Text(
          'I went to another APS school too',
          style: TextStyle(
            color: AppColors.crimson,
            fontWeight: FontWeight.w700,
            fontSize: 12,
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

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.onNext, this.error});

  final VoidCallback onNext;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(17, 4, 17, 20),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.crimsonDark,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size(double.infinity, 0),
            ),
            onPressed: onNext,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next — connect my socials',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Field widgets ─────────────────────────────────────────────────────────────

class _CrimsonLabel extends StatelessWidget {
  const _CrimsonLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: AppColors.crimson,
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
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CrimsonLabel(label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          items: items
              .map(
                (v) => DropdownMenuItem<String>(
                  value: v,
                  child: Text(v, style: const TextStyle(fontSize: 13)),
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
          keyboardType: TextInputType.number,
          onChanged: (v) => onChanged(v.trim()),
          style: const TextStyle(fontSize: 13),
          decoration: _fieldDecoration(hintText: 'YYYY'),
        ),
      ],
    );
  }
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

InputDecoration _fieldDecoration({String? hintText}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 13),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFFDDDDDD)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
    ),
  );
}
