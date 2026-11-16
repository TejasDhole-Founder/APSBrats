import 'dart:async';
import 'package:hugeicons/hugeicons.dart';

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_repository.dart';
import 'package:apsbrat_frontend/features/chat/data/chat_socket.dart';
import 'package:apsbrat_frontend/features/community/data/community_repository.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/batch_tab.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/batchmate_overlay.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/chat_overlay.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/home_tab.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/messages_tab.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:apsbrat_frontend/features/connections/data/circle_repository.dart';
import 'package:apsbrat_frontend/features/connections/data/connection_repository.dart';
import 'package:apsbrat_frontend/features/search/data/search_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

/// Tab positions; must match the order of [_BottomNav._items].
const _messagesTab = 2;

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _tab = 0;

  /// A tab is built (and fetches its data) on first visit, then kept alive
  /// in the IndexedStack so switching back is instant.
  final _visited = <int>{0};

  void _goTo(int i) {
    // Returning to Batchmates refreshes only what that tab shows, so a request
    // answered on another device isn't shown stale. A first visit fetches anyway.
    if (i == 1 && _tab != 1 && _visited.contains(1)) {
      ref
        ..invalidate(circleSummaryProvider)
        ..invalidate(batchmatesProvider)
        ..invalidate(peopleSearchProvider);
    }
    setState(() {
      _visited.add(i);
      _tab = i;
    });
  }

  AppPerson? _chatPerson;
  AppPerson? _batchmatePerson;
  StreamSubscription? _chatSocketSubscription;
  StreamSubscription? _communitySocketSubscription;

  @override
  void initState() {
    super.initState();
    // One socket for the whole app session -- connecting here covers both a
    // fresh login (this screen is the redirect target) and a cold start with
    // an already-valid session (the router sends straight here too).
    final socket = ref.read(chatSocketProvider);
    socket.connect();
    // A push for a conversation whose screen isn't open right now still
    // needs to update the Messages tab's previews/unread badges live.
    _chatSocketSubscription = socket.messages.listen(
      (_) => ref.invalidate(conversationsProvider),
    );
    _communitySocketSubscription = socket.communityMessages.listen(
      (_) => ref.invalidate(myCommunityChatsProvider),
    );
  }

  @override
  void dispose() {
    _chatSocketSubscription?.cancel();
    _communitySocketSubscription?.cancel();
    super.dispose();
  }

  void _openChat(AppPerson p) => setState(() {
    _chatPerson = p;
    _batchmatePerson = null;
  });

  void _openBatchmate(AppPerson p) => setState(() {
    _batchmatePerson = p;
    _chatPerson = null;
  });

  void _closeChat() => setState(() => _chatPerson = null);
  void _closeBatchmate() => setState(() => _batchmatePerson = null);

  @override
  Widget build(BuildContext context) {
    // System back: close an open overlay first, then return to the Home tab,
    // and only leave the app when already on the Home tab.
    final canLeave =
        _tab == 0 && _batchmatePerson == null && _chatPerson == null;
    return PopScope(
      canPop: canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_chatPerson != null) {
          _closeChat();
        } else if (_batchmatePerson != null) {
          _closeBatchmate();
        } else {
          _goTo(0);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: IndexedStack(
                      index: _tab,
                      children: [
                        HomeTab(
                          onOpenBatchmate: _openBatchmate,
                          onOpenChat: _openChat,
                          onGoMessages: () => _goTo(_messagesTab),
                        ),
                        _visited.contains(1)
                            ? const BatchTab()
                            : const SizedBox.shrink(),
                        _visited.contains(2)
                            ? const MessagesTab()
                            : const SizedBox.shrink(),
                        _visited.contains(3)
                            ? const ProfileTab()
                            : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                  _BottomNav(current: _tab, onTap: _goTo),
                ],
              ),

              if (_batchmatePerson != null)
                BatchmateOverlay(
                  person: _batchmatePerson!,
                  onBack: _closeBatchmate,
                  onMessage: _openChat,
                ),

              if (_chatPerson != null)
                ChatOverlay(person: _chatPerson!, onBack: _closeChat),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Bottom nav ────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});

  final int current;
  final ValueChanged<int> onTap;

  static const _items = [
    (HugeIcons.strokeRoundedHome01, HugeIcons.strokeRoundedHome01, 'Home'),
    (
      HugeIcons.strokeRoundedUserMultiple,
      HugeIcons.strokeRoundedUserGroup02,
      'Batchmates',
    ),
    (
      HugeIcons.strokeRoundedComment01,
      HugeIcons.strokeRoundedComment01,
      'Social',
    ),
    (HugeIcons.strokeRoundedUser, HugeIcons.strokeRoundedUser, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(_items.length, (i) {
              final (activeIcon, inactiveIcon, label) = _items[i];
              final active = i == current;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      HugeIcon(
                        icon: active ? activeIcon : inactiveIcon,
                        size: 22,
                        color: active
                            ? AppColors.crimson
                            : const Color(0xFFAAAAAA),
                      ),
                      const SizedBox(height: 3),
                      // Five tabs share the width: on a narrow phone a long
                      // label ("Communities") shrinks a little instead of
                      // wrapping onto a second line.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: active
                                ? AppColors.crimson
                                : const Color(0xFFAAAAAA),
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: active ? 18 : 0,
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
