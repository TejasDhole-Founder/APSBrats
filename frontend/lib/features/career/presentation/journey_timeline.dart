import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/presentation/career_form.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/school_timeline.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A person's whole story on one line, newest first: work, then college,
/// then their APS schools. `editable` adds the + / pencil controls for the
/// owner's own profile.
class JourneyTimeline extends StatelessWidget {
  const JourneyTimeline({
    super.key,
    required this.career,
    required this.schools,
    this.editable = false,
    this.onEditSchools,
  });

  final List<CareerEntry> career;
  final List<SchoolHistory> schools;
  final bool editable;
  final VoidCallback? onEditSchools;

  @override
  Widget build(BuildContext context) {
    final work = career.where((e) => e.isWork).toList();
    final study = career.where((e) => !e.isWork).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (editable || work.isNotEmpty) ...[
          _Heading(
            label: 'Work',
            action: editable ? 'Add' : null,
            onAction: () =>
                showCareerSheet(context, const CareerDraft(kind: kWork)),
          ),
          _Entries(entries: work, editable: editable, empty: 'Add your jobs'),
          const SizedBox(height: 18),
        ],
        if (editable || study.isNotEmpty) ...[
          _Heading(
            label: 'College',
            action: editable ? 'Add' : null,
            onAction: () =>
                showCareerSheet(context, const CareerDraft(kind: kEducation)),
          ),
          _Entries(
            entries: study,
            editable: editable,
            empty: 'Add your college or institute',
          ),
          const SizedBox(height: 18),
        ],
        _Heading(
          label: 'School',
          action: editable ? 'Edit' : null,
          onAction: onEditSchools,
        ),
        SchoolTimeline(schools: schools),
      ],
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.label, this.action, this.onAction});

  final String label;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(child: SectionLabel(label)),
          if (action != null)
            TextButton.icon(
              onPressed: onAction,
              icon: HugeIcon(
                icon: action == 'Add'
                    ? HugeIcons.strokeRoundedAdd01
                    : HugeIcons.strokeRoundedPencilEdit01,
                size: 16,
              ),
              label: Text(action!),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.crimson,
                visualDensity: VisualDensity.compact,
              ),
            ),
        ],
      ),
    );
  }
}

class _Entries extends StatelessWidget {
  const _Entries({
    required this.entries,
    required this.editable,
    required this.empty,
  });

  final List<CareerEntry> entries;
  final bool editable;
  final String empty;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Text(empty, style: const TextStyle(fontSize: 12, color: kTxt3));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++)
            _EntryRow(
              entry: entries[i],
              isLast: i == entries.length - 1,
              onTap: editable
                  ? () => showCareerSheet(
                      context,
                      CareerDraft.fromEntry(entries[i]),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.entry, required this.isLast, this.onTap});

  final CareerEntry entry;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      entry.organizationName,
      if ((entry.fieldOfStudy ?? '').isNotEmpty) entry.fieldOfStudy!,
      if ((entry.location ?? '').isNotEmpty) entry.location!,
    ].join(' · ');

    return InkWell(
      onTap: onTap,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icon + the line down to the next entry.
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: entry.isCurrent
                          ? AppColors.crimson
                          : kCrimsonLight,
                      shape: BoxShape.circle,
                    ),
                    child: HugeIcon(
                      icon: entry.isWork
                          ? HugeIcons.strokeRoundedBriefcase01
                          : HugeIcons.strokeRoundedMortarboard01,
                      size: 15,
                      color: entry.isCurrent ? Colors.white : AppColors.crimson,
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: kBorder,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 10 : 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTxt,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: kTxt2),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _range(entry),
                          style: const TextStyle(fontSize: 11, color: kTxt3),
                        ),
                        if (entry.isCurrent) const _Pill('Current'),
                        if (entry.isHidden) const _Pill('Hidden', muted: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedPencilEdit01,
                  size: 16,
                  color: kTxt3,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "Jun 2022 – Present" for work, "2017 – 2021" for college.
  static String _range(CareerEntry e) {
    String fmt(DateTime d) =>
        e.isWork ? '${_month[d.month - 1]} ${d.year}' : '${d.year}';
    return '${fmt(e.startDate)} – ${e.endDate == null ? 'Present' : fmt(e.endDate!)}';
  }

  static const _month = [
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
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, {this.muted = false});

  final String text;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF3F0EC) : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: muted ? kTxt3 : const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}
