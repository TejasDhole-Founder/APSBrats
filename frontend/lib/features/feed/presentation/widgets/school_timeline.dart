import 'dart:math' as math;

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:flutter/material.dart';

/// LinkedIn-style "Experience" list for the profile page:
/// Army Public School is the parent entry (with the total span), and every
/// school attended is a dated item on a vertical timeline, newest first.
class SchoolTimeline extends StatelessWidget {
  const SchoolTimeline({super.key, required this.schools});

  final List<SchoolHistory> schools;

  @override
  Widget build(BuildContext context) {
    if (schools.isEmpty) {
      return const EmptyState(
        icon: Icons.school_outlined,
        title: 'No schools yet',
        message:
            'The APS schools you add during onboarding will be listed here.',
      );
    }

    final sorted = [...schools]
      ..sort((a, b) => b.batchEnd.compareTo(a.batchEnd));
    final firstYear = sorted.map((s) => s.batchStart).reduce(math.min);
    final lastYear = sorted.map((s) => s.batchEnd).reduce(math.max);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kBorder, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ParentEntry(
            schoolCount: sorted.length,
            firstYear: firstYear,
            lastYear: lastYear,
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < sorted.length; i++)
            _TimelineItem(school: sorted[i], isLast: i == sorted.length - 1),
        ],
      ),
    );
  }
}

// ── Parent entry ("Army Public School · 12 yrs") ──────────────────────────────

class _ParentEntry extends StatelessWidget {
  const _ParentEntry({
    required this.schoolCount,
    required this.firstYear,
    required this.lastYear,
  });

  final int schoolCount;
  final int firstYear;
  final int lastYear;

  @override
  Widget build(BuildContext context) {
    final schoolsLabel = schoolCount == 1 ? '1 school' : '$schoolCount schools';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: _gutterWidth,
          height: _gutterWidth,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.crimson,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'APS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Army Public School',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTxt,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_yearsLabel(lastYear - firstYear)} · $schoolsLabel',
                style: const TextStyle(fontSize: 12, color: kTxt2),
              ),
              Text(
                '$firstYear – $lastYear',
                style: const TextStyle(fontSize: 11, color: kTxt3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── One school on the timeline ────────────────────────────────────────────────

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.school, required this.isLast});

  final SchoolHistory school;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final classLabel = StringBuffer(
      'Class ${school.classFrom} – ${school.classTo}',
    );
    if (school.section.isNotEmpty) {
      classLabel.write(' · Section ${school.section}');
    }
    final years = _yearsLabel(math.max(1, school.batchEnd - school.batchStart));

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Gutter: dot + connecting line, centred under the APS logo.
          SizedBox(
            width: _gutterWidth,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: school.isPrimary
                        ? AppColors.crimson
                        : const Color(0xFFD9CFCF),
                    shape: BoxShape.circle,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          school.schoolName ?? 'APS',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTxt,
                          ),
                        ),
                      ),
                      if (school.isPrimary)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: kGoldLight,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'Most missed',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: kGoldDark,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    classLabel.toString(),
                    style: const TextStyle(fontSize: 12, color: kTxt2),
                  ),
                  Text(
                    '${school.batchStart} – ${school.batchEnd} · $years',
                    style: const TextStyle(fontSize: 11, color: kTxt3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const double _gutterWidth = 44;

String _yearsLabel(int years) => years == 1 ? '1 yr' : '$years yrs';
