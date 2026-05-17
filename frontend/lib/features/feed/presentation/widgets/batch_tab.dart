import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';

class BatchTab extends StatefulWidget {
  const BatchTab({super.key, required this.onOpenBatchmate});

  final ValueChanged<AppPerson> onOpenBatchmate;

  @override
  State<BatchTab> createState() => _BatchTabState();
}

class _BatchTabState extends State<BatchTab> {
  String _schoolFilter = 'all';
  String _query = '';
  final _connected = <String>{};

  List<AppPerson> get _filtered {
    Iterable<AppPerson> list = dummyBatchmates;
    if (_schoolFilter != 'all') {
      list = list.where(
        (p) => p.school.toLowerCase().contains(_schoolFilter),
      );
    }
    if (_query.isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where(
        (p) =>
            p.name.toLowerCase().contains(q) ||
            p.city.toLowerCase().contains(q) ||
            p.school.toLowerCase().contains(q),
      );
    }
    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Column(
      children: [
        CrimsonHeader(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      children: [
                        TextSpan(text: 'Your '),
                        TextSpan(
                          text: 'batchmates',
                          style: TextStyle(color: AppColors.gold),
                        ),
                      ],
                    ),
                  ),
                  FeedIconBtn(icon: Icons.tune_rounded),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _SchoolTab(
                      label: 'All schools',
                      value: 'all',
                      selected: _schoolFilter,
                      onTap: (v) => setState(() => _schoolFilter = v),
                    ),
                    const SizedBox(width: 7),
                    _SchoolTab(
                      label: 'APS Patiala',
                      value: 'patiala',
                      selected: _schoolFilter,
                      onTap: (v) => setState(() => _schoolFilter = v),
                    ),
                    const SizedBox(width: 7),
                    _SchoolTab(
                      label: 'APS Pune',
                      value: 'pune',
                      selected: _schoolFilter,
                      onTap: (v) => setState(() => _schoolFilter = v),
                    ),
                    const SizedBox(width: 7),
                    _SchoolTab(
                      label: 'APS Delhi',
                      value: 'delhi',
                      selected: _schoolFilter,
                      onTap: (v) => setState(() => _schoolFilter = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
          child: FeedSearchBar(
            hint: 'Search by name, city, section...',
            onChanged: (q) => setState(() => _query = q.trim()),
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
          child: Row(
            children: const [
              _FilterChip(label: 'All classes', active: true),
              SizedBox(width: 8),
              _FilterChip(label: 'Class 12'),
              SizedBox(width: 8),
              _FilterChip(label: 'Class 11'),
              SizedBox(width: 8),
              _FilterChip(label: 'Class 10'),
              SizedBox(width: 8),
              _FilterChip(label: 'Alumni'),
            ],
          ),
        ),

        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final p = filtered[i];
              final isConnected = _connected.contains(p.name);
              return _BatchmateCard(
                person: p,
                connected: isConnected,
                onTap: () => widget.onOpenBatchmate(p),
                onConnect: () => setState(() {
                  if (isConnected) {
                    _connected.remove(p.name);
                  } else {
                    _connected.add(p.name);
                  }
                }),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── School tab chip ───────────────────────────────────────────────────────────

class _SchoolTab extends StatelessWidget {
  const _SchoolTab({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final String selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final active = selected == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
          border: Border.all(
            color: active ? AppColors.gold : Colors.white.withValues(alpha: 0.25),
          ),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, this.active = false});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? kCrimsonLight : Colors.white,
        border: Border.all(
          color: active ? const Color(0x3F7B1414) : kBorder,
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active ? kCrimsonMed : kTxt2,
        ),
      ),
    );
  }
}

// ── Batchmate card ────────────────────────────────────────────────────────────

class _BatchmateCard extends StatelessWidget {
  const _BatchmateCard({
    required this.person,
    required this.connected,
    required this.onTap,
    required this.onConnect,
  });

  final AppPerson person;
  final bool connected;
  final VoidCallback onTap;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kBorder, width: 1.5),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AvatarCircle(
              initials: person.initials,
              bg: person.bg,
              fg: person.fg,
              size: 48,
              fontSize: 16,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTxt,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${person.detail} · ${person.school}',
                    style: const TextStyle(fontSize: 11, color: kTxt3),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: person.tags
                        .map(
                          (t) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kCrimsonLight,
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: kCrimsonMed,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: onConnect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: connected ? kCrimsonLight : AppColors.crimson,
                      border: connected
                          ? Border.all(color: const Color(0x2F7B1414))
                          : null,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      connected ? 'Connected' : 'Connect',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: connected ? kCrimsonMed : Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 11, color: kTxt3),
                    const SizedBox(width: 2),
                    Text(
                      person.city,
                      style: const TextStyle(fontSize: 10, color: kTxt3),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
