import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/feed/data/dummy_data.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/batch_tab.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/batchmate_overlay.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/chat_overlay.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/home_tab.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/messages_tab.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/profile_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  AppPerson? _chatPerson;
  AppPerson? _batchmatePerson;

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

  void _messageFromBatchmate(AppPerson p) => setState(() {
        _batchmatePerson = null;
        _chatPerson = p;
      });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
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
                        onGoMessages: () => setState(() => _tab = 2),
                      ),
                      BatchTab(onOpenBatchmate: _openBatchmate),
                      MessagesTab(onOpenChat: _openChat),
                      const ProfileTab(),
                    ],
                  ),
                ),
                _BottomNav(
                  current: _tab,
                  onTap: (i) => setState(() => _tab = i),
                ),
              ],
            ),

            if (_batchmatePerson != null)
              BatchmateOverlay(
                person: _batchmatePerson!,
                onBack: _closeBatchmate,
                onMessage: _messageFromBatchmate,
              ),

            if (_chatPerson != null)
              ChatOverlay(
                person: _chatPerson!,
                onBack: _closeChat,
              ),
          ],
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
    (Icons.home_rounded, Icons.home_outlined, 'Home'),
    (Icons.people_rounded, Icons.people_outline_rounded, 'Batch'),
    (Icons.chat_bubble_rounded, Icons.chat_bubble_outline_rounded, 'Messages'),
    (Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
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
                      Icon(
                        active ? activeIcon : inactiveIcon,
                        size: 22,
                        color: active ? AppColors.crimson : const Color(0xFFAAAAAA),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active ? AppColors.crimson : const Color(0xFFAAAAAA),
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
