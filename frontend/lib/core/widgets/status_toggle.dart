import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum UserStatusOption { student, alumni }

class StatusToggle extends StatelessWidget {
  const StatusToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final UserStatusOption value;
  final ValueChanged<UserStatusOption> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UserStatusOption>(
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.card,
        foregroundColor: AppColors.textSecondary,
        selectedBackgroundColor: AppColors.g2,
        selectedForegroundColor: AppColors.goldLight,
      ),
      showSelectedIcon: false,
      segments: const [
        ButtonSegment(
          value: UserStatusOption.student,
          label: Text('Student'),
        ),
        ButtonSegment(
          value: UserStatusOption.alumni,
          label: Text('Alumni'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}
