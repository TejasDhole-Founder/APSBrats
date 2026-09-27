import 'package:apsbrat_frontend/core/models/person.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Full page: connection requests I received and sent.
class RequestsScreen extends StatelessWidget {
  const RequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            CrimsonHeader(
              waveColor: Colors.white,
              child: Row(
                children: [
                  FeedIconBtn(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Connection requests',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(child: RequestsSheet(asPage: true)),
          ],
        ),
      ),
    );
  }
}

/// Received / Sent lists with Accept · Decline · Withdraw. Used as the body
/// of [RequestsScreen]; [asPage] hides the sheet handle and title.
class RequestsSheet extends ConsumerStatefulWidget {
  const RequestsSheet({super.key, this.asPage = false});

  final bool asPage;

  @override
  ConsumerState<RequestsSheet> createState() => _RequestsSheetState();
}

class _RequestsSheetState extends ConsumerState<RequestsSheet> {
  bool _showReceived = true;

  /// Ids answered in this sheet, so the card disappears at once.
  final _done = <String>{};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(pendingConnectionsProvider);
      ref.invalidate(sentConnectionsProvider);
    });
  }

  Future<void> _act(Person p, Future<void> Function() call) async {
    setState(() => _done.add(p.id));
    try {
      await call();
      refreshConnections(ref, otherUserId: p.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _done.remove(p.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(connectionRepositoryProvider);
    final received = ref.watch(pendingConnectionsProvider);
    final sent = ref.watch(sentConnectionsProvider);
    final receivedCount = received.valueOrNull
        ?.where((p) => !_done.contains(p.id))
        .length;
    final sentCount = sent.valueOrNull
        ?.where((p) => !_done.contains(p.id))
        .length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.asPage) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Connection requests',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTxt,
                ),
              ),
              const SizedBox(height: 10),
            ],
            _Toggle(
              left:
                  'Received${receivedCount == null ? '' : ' · $receivedCount'}',
              right: 'Sent${sentCount == null ? '' : ' · $sentCount'}',
              leftActive: _showReceived,
              onChanged: (v) => setState(() => _showReceived = v),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: (_showReceived ? received : sent).when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.crimson),
                  ),
                ),
                error: (_, __) => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Could not load requests.'),
                ),
                data: (list) {
                  final people = list
                      .where((p) => !_done.contains(p.id))
                      .toList();
                  if (people.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28),
                      child: Center(
                        child: Text(
                          _showReceived
                              ? 'No new requests.'
                              : 'No pending requests from you.',
                          style: const TextStyle(color: kTxt3),
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final p = people[i];
                      return _RequestCard(
                        person: p,
                        received: _showReceived,
                        onOpen: () => context.go('/home/profile/${p.id}'),
                        onAccept: () => _act(p, () => repo.accept(p.id)),
                        onEnd: () => _act(p, () => repo.end(p.id)),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.left,
    required this.right,
    required this.leftActive,
    required this.onChanged,
  });

  final String left;
  final String right;
  final bool leftActive;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, bool active, bool value) => GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.crimson : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : kTxt2,
          ),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F2),
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [seg(left, leftActive, true), seg(right, !leftActive, false)],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.person,
    required this.received,
    required this.onOpen,
    required this.onAccept,
    required this.onEnd,
  });

  final Person person;
  final bool received;
  final VoidCallback onOpen;
  final VoidCallback onAccept;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (person.detail.isNotEmpty) person.detail,
      if (person.school.isNotEmpty) person.school,
      if (person.mutualCount > 0) '${person.mutualCount} mutual',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border.all(color: kBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Row(
              children: [
                AvatarCircle(
                  initials: person.initials,
                  bg: person.bg,
                  fg: person.fg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        person.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: kTxt,
                        ),
                      ),
                      Text(
                        meta,
                        style: const TextStyle(fontSize: 11, color: kTxt3),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (received) ...[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.crimson,
                      minimumSize: const Size(0, 36),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: onAccept,
                    child: const Text('Accept'),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTxt2,
                    minimumSize: const Size(0, 36),
                    side: const BorderSide(color: kBorder, width: 1.5),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  onPressed: onEnd,
                  child: Text(received ? 'Decline' : 'Withdraw'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
