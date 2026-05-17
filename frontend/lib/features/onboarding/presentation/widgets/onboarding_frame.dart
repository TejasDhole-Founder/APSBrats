import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class OnboardingFrame extends StatefulWidget {
  const OnboardingFrame({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.child,
    this.footer,
    this.headerAction,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? footer;
  final Widget? headerAction;

  @override
  State<OnboardingFrame> createState() => _OnboardingFrameState();
}

class _OnboardingFrameState extends State<OnboardingFrame> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final shellWidth = width < 380 ? width - 24 : 325.0;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: shellWidth),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.phone,
                    border: Border.all(color: AppColors.mud, width: 3),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: AppRadius.phone,
                    child: Column(
                      children: [
                        const _StatusBar(),
                        _Header(
                          step: widget.step,
                          title: widget.title,
                          subtitle: widget.subtitle,
                          headerAction: widget.headerAction,
                        ),
                        widget.child,
                        if (widget.footer != null) widget.footer!,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Status bar ────────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.crimson,
      padding: const EdgeInsets.fromLTRB(20, 11, 20, 8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('9:41', style: TextStyle(fontSize: 11, color: Colors.white)),
          Row(
            children: [
              Icon(Icons.network_cell, color: Colors.white, size: 14),
              SizedBox(width: 4),
              Icon(Icons.battery_full_rounded, color: Colors.white, size: 14),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.step,
    required this.title,
    required this.subtitle,
    this.headerAction,
  });

  final int step;
  final String title;
  final String subtitle;
  final Widget? headerAction;

  static const _steps = [
    (label: 'Profile', index: 1),
    (label: 'Verify', index: 2),
    (label: 'Schools', index: 3),
    (label: 'Socials', index: 4),
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.crimsonDark, AppColors.crimson],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // APS Brat logo row
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'APS',
                      style: TextStyle(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.gold,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      children: [
                        TextSpan(text: 'APS ', style: TextStyle(color: Colors.white)),
                        TextSpan(text: 'Brat', style: TextStyle(color: AppColors.gold)),
                      ],
                    ),
                  ),
                  const Spacer(),
                  ?headerAction,
                ],
              ),
              const SizedBox(height: 14),
              // Title — last word gold
              RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.25),
                  children: _splitTitle(title),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 16),
              // 4-step breadcrumb
              Row(
                children: [
                  for (int i = 0; i < _steps.length; i++) ...[
                    _StepNode(
                      index: _steps[i].index,
                      label: _steps[i].label,
                      active: step == _steps[i].index,
                      done: step > _steps[i].index,
                    ),
                    if (i < _steps.length - 1) const Expanded(child: _StepLine()),
                  ],
                ],
              ),
            ],
          ),
        ),
        // White wave at bottom of header
        Positioned(
          bottom: -1,
          left: 0,
          right: 0,
          child: Container(
            height: 26,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.elliptical(160, 26)),
            ),
          ),
        ),
      ],
    );
  }

  List<TextSpan> _splitTitle(String t) {
    final words = t.trim().split(' ');
    if (words.length <= 1) {
      return [TextSpan(text: t, style: const TextStyle(color: AppColors.gold))];
    }
    final last = words.removeLast();
    return [
      TextSpan(text: '${words.join(' ')} ', style: const TextStyle(color: Colors.white)),
      TextSpan(text: last, style: const TextStyle(color: AppColors.gold)),
    ];
  }
}

class _StepNode extends StatelessWidget {
  const _StepNode({
    required this.index,
    required this.label,
    required this.active,
    required this.done,
  });

  final int index;
  final String label;
  final bool active;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? AppColors.gold
                : done
                    ? AppColors.gold.withValues(alpha: 0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: (active || done)
                ? null
                : Border.all(color: Colors.white38, width: 1.5),
          ),
          child: done
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: active ? AppColors.g1 : Colors.white38,
                  ),
                ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 0.3,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.gold : Colors.white38,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      height: 1.5,
      color: Colors.white24,
    );
  }
}
