import 'dart:async';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:apsbrat_frontend/features/profile/presentation/widgets/profile_photo.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';

import 'package:dio/dio.dart';
import 'package:apsbrat_frontend/core/location/location_service.dart';
import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_registration_service.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/availability_checker.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/dob_picker_sheet.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// First onboarding screen. The account (and its email) already exist by the
/// time you land here — this only collects the rest: name, handle, dob, etc.
class OnboardingIdentityScreen extends ConsumerStatefulWidget {
  const OnboardingIdentityScreen({super.key});

  @override
  ConsumerState<OnboardingIdentityScreen> createState() =>
      _OnboardingIdentityScreenState();
}

class _OnboardingIdentityScreenState
    extends ConsumerState<OnboardingIdentityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  late final AvailabilityChecker _usernameCheck;
  final _dobController = TextEditingController();
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  String? _gender;
  bool _isStudent = false; // default: Alumni

  late final OnboardingFlowNotifier _flow;
  Timer? _saveTimer;

  /// The login email: from the live session, or from the saved draft right
  /// after the app was reopened (the session is not loaded yet then).
  String _email = '';

  @override
  void initState() {
    super.initState();
    final s = ref.read(onboardingFlowProvider);
    _firstNameController.text = s.firstName;
    _lastNameController.text = s.lastName;
    _usernameController.text = s.username;
    _dobController.text = s.dob;
    _cityController.text = s.city;
    _professionController.text = s.profession;
    _gender = s.gender.isEmpty ? null : s.gender;
    _isStudent = s.isStudent;
    _flow = ref.read(onboardingFlowProvider.notifier);
    _email = ref.read(authControllerProvider).user?.email ?? s.email;
    for (final c in [
      _firstNameController,
      _lastNameController,
      _usernameController,
      _dobController,
      _cityController,
      _professionController,
    ]) {
      c.addListener(_scheduleSave);
    }
    const service = OnboardingRegistrationService();
    _usernameCheck = AvailabilityChecker(
      controller: _usernameController,
      fetch: (v) => service.usernameAvailability(ref.read(dioProvider), v),
    )..addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Saves what has been typed so far, shortly after the user pauses.
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), _syncDraft);
  }

  /// [deferred] is for dispose: Riverpod does not allow changing state while a
  /// screen is being torn down, so the values are read now and saved a moment
  /// later, after the frame.
  void _syncDraft({bool deferred = false}) {
    final first = _firstNameController.text.trim();
    final last = _lastNameController.text.trim();
    final username = _usernameController.text.trim();
    final dob = _dobController.text.trim();
    final city = _cityController.text.trim();
    final profession = _professionController.text.trim();
    final gender = _gender ?? 'PREFER_NOT';
    final isStudent = _isStudent;
    final email = _email;
    final flow = _flow;

    void save() {
      if (!flow.mounted) return;
      flow.syncIdentity(
        firstName: first,
        lastName: last,
        username: username,
        dob: dob,
        city: city,
        profession: profession,
        gender: gender,
        isStudent: isStudent,
        email: email,
      );
    }

    deferred ? Future(save) : save();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _syncDraft(deferred: true);
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameCheck.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _usernameCheck.passes()) {
      _usernameCheck.focus.requestFocus();
      return;
    }
    final email = ref.read(authControllerProvider).user?.email ?? _email;
    ref
        .read(onboardingFlowProvider.notifier)
        .saveIdentity(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          username: _usernameController.text.trim(),
          email: email,
          dob: _dobController.text.trim(),
          city: _cityController.text.trim(),
          profession: _professionController.text.trim(),
          gender: _gender ?? 'PREFER_NOT',
          isStudent: _isStudent,
        );
    _flow.markStep(2);
    if (mounted) context.go('/onboarding/schools');
  }

  final _location = LocationService();

  /// Asks for location only when tapped, reads the position, and fills the city
  /// from the server's reverse lookup.
  Future<void> _useMyLocation() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final point = await _location.currentRounded();
      final response = await ref
          .read(dioProvider)
          .get<dynamic>(
            '/places/reverse',
            queryParameters: {'lat': point.latitude, 'lon': point.longitude},
          );
      final data = (response.data as Map)['data'] as Map?;
      final city = data?['city'] as String?;
      if (city == null) {
        throw const LocationException(
          'Could not find your city. Type it instead.',
        );
      }
      _cityController.text = city;
    } on LocationException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } on DioException {
      messenger.showSnackBar(
        const SnackBar(
          content: Text("Couldn't find your city right now. Type it instead."),
        ),
      );
    }
  }

  Future<void> _pickDob() async {
    DateTime? current;
    try {
      current = DateFormat('dd/MM/yyyy').parseStrict(_dobController.text);
    } on FormatException {
      current = null;
    }
    final picked = await showDobSheet(context, initial: current);
    if (picked != null) {
      _dobController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).user?.email ?? _email;
    return Form(
      key: _formKey,
      // Errors show as soon as a field is edited, not only after Continue.
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: OnboardingFrame(
        step: 1,
        showAfterSchool: !_isStudent,
        title: 'First, tell us about yourself.',
        subtitle: 'Your batchmates will use this to find and recognise you.',
        footer: _Footer(onNext: _next),
        child: _FormBody(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          usernameController: _usernameController,
          usernameCheck: _usernameCheck,
          email: email,
          dobController: _dobController,
          cityController: _cityController,
          professionController: _professionController,
          gender: _gender,
          isStudent: _isStudent,
          onGenderChanged: (v) {
            setState(() => _gender = v);
            _scheduleSave();
          },
          onStatusChanged: (v) {
            setState(() => _isStudent = v);
            _scheduleSave();
          },
          onPickDob: _pickDob,
          onUseLocation: _useMyLocation,
        ),
      ),
    );
  }
}

// ── Form body ─────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.firstNameController,
    required this.lastNameController,
    required this.usernameController,
    required this.usernameCheck,
    required this.email,
    required this.dobController,
    required this.cityController,
    required this.professionController,
    required this.gender,
    required this.isStudent,
    required this.onGenderChanged,
    required this.onStatusChanged,
    required this.onPickDob,
    required this.onUseLocation,
  });

  final TextEditingController firstNameController;
  final TextEditingController lastNameController;
  final TextEditingController usernameController;
  final AvailabilityChecker usernameCheck;
  final String email;
  final TextEditingController dobController;
  final TextEditingController cityController;
  final TextEditingController professionController;
  final String? gender;
  final bool isStudent;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<bool> onStatusChanged;
  final VoidCallback onPickDob;
  final VoidCallback onUseLocation;

  static const _crimson = AppColors.crimson;
  static const _border = Color(0xFFE2DDD5);
  static const _hint = Color(0xFFBBB4A8);

  static const _labelStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: _crimson,
  );

  static InputDecoration _dec(String hint, {Widget? suffix, String? prefix}) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(fontSize: 13, color: _hint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: _border, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: _border, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: _crimson, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppRadius.sm,
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile photo card
          _PhotoCard(),
          const SizedBox(height: 14),

          // First Name + Last Name
          Row(
            children: [
              Expanded(
                child: _labeledField(
                  'FIRST NAME *',
                  TextFormField(
                    controller: firstNameController,
                    decoration: _dec('Arjun'),
                    validator: _required,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _labeledField(
                  'LAST NAME *',
                  TextFormField(
                    controller: lastNameController,
                    decoration: _dec('Singh'),
                    validator: _required,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Username
          _labeledField(
            'USERNAME',
            TextFormField(
              controller: usernameController,
              focusNode: usernameCheck.focus,
              inputFormatters: usernameInputFormatters,
              decoration: _dec(
                'arjun_singh',
                suffix: _availabilitySuffix(usernameCheck),
              ).copyWith(errorText: usernameCheck.error),
              validator: _required,
            ),
            hint: _availabilityHint(
              usernameCheck,
              idle: 'Your unique handle — how others find you',
              ok: 'Username is available',
            ),
            hintColor: usernameCheck.confirmed ? Colors.green : null,
          ),
          const SizedBox(height: 12),

          // Email — already verified at login, shown for confirmation only.
          _labeledField(
            'EMAIL',
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF8F5),
                borderRadius: AppRadius.sm,
                border: Border.all(color: _border, width: 1.5),
              ),
              child: Row(
                children: [
                  const HugeIcon(
                    icon: HugeIcons.strokeRoundedCheckmarkBadge01,
                    size: 16,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF1A0A0A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            hint: 'Verified — this is how you\'ll log back in',
          ),
          const SizedBox(height: 12),

          // DOB + Gender
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _labeledField(
                  'DATE OF BIRTH',
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextFormField(
                      controller: dobController,
                      readOnly: true,
                      onTap: onPickDob,
                      decoration: _dec(
                        'DD / MM / YYYY',
                        suffix: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCalendar03,
                          size: 16,
                          color: _hint,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _GenderPicker(value: gender, onChanged: onGenderChanged),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current city
          _labeledField(
            'CURRENT CITY *',
            TextFormField(
              controller: cityController,
              decoration: _dec('Where are you based right now?'),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onUseLocation,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedTarget01,
                size: 16,
              ),
              label: const Text('Use my location'),
            ),
          ),
          // "What do you do now" moved to its own step (alumni only).
          const SizedBox(height: 14),

          // I AM A toggle
          Text.rich(
            TextSpan(
              style: _labelStyle,
              children: [
                TextSpan(text: 'I AM A'),
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFC62828)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _StatusToggle(isStudent: isStudent, onChanged: onStatusChanged),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _labeledField(
    String label,
    Widget field, {
    String? hint,
    Color? hintColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            style: _labelStyle,
            children: [
              TextSpan(text: label.replaceAll(' *', '')),
              if (label.endsWith(' *'))
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: Color(0xFFC62828)),
                ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        field,
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(
            hint,
            style: TextStyle(
              fontSize: 10,
              color: hintColor ?? const Color(0xFF9A9280),
            ),
          ),
        ],
      ],
    );
  }

  static String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ── Availability helpers ────────────────────────────────────────────────────

/// Spinner while checking, green tick when confirmed available, else nothing.
Widget? _availabilitySuffix(AvailabilityChecker check) {
  if (check.checking) {
    return const Padding(
      padding: EdgeInsets.all(13),
      child: SizedBox(
        width: 14,
        height: 14,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _FormBody._hint,
        ),
      ),
    );
  }
  if (check.confirmed) {
    return const HugeIcon(
      icon: HugeIcons.strokeRoundedCheckmarkCircle01,
      size: 18,
      color: Colors.green,
    );
  }
  return null;
}

/// Helper text under the field. Null while an error is showing (the red error
/// text takes its place); otherwise checking / [ok] / the normal [idle] hint.
String? _availabilityHint(
  AvailabilityChecker check, {
  required String idle,
  required String ok,
}) {
  if (check.error != null) return null;
  if (check.checking) return 'Checking availability…';
  if (check.confirmed) return ok;
  return idle;
}

// ── Profile photo card ────────────────────────────────────────────────────────

/// Optional: add a profile photo during registration. It's saved straight
/// away (the account already exists), so it's there even if they stop here.
/// Gender as two tappable picture cards. Leaving both unselected saves
/// "Prefer not to say".
class _GenderPicker extends StatelessWidget {
  const _GenderPicker({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text.rich(
          TextSpan(
            style: _FormBody._labelStyle,
            children: [
              TextSpan(text: 'GENDER '),
              TextSpan(
                text: '(Optional)',
                style: TextStyle(
                  color: Color(0xFF8A8A8A),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GenderCard(
                label: 'Female',
                asset: 'assets/images/gender_female.png',
                compact: true,
                selected: value == 'FEMALE',
                onTap: () => onChanged(value == 'FEMALE' ? null : 'FEMALE'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GenderCard(
                label: 'Male',
                asset: 'assets/images/gender_male.png',
                compact: true,
                selected: value == 'MALE',
                onTap: () => onChanged(value == 'MALE' ? null : 'MALE'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderCard extends StatelessWidget {
  const _GenderCard({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  static const _maroon = Color(0xFF7B1414);
  static const _tan = Color(0xFFE3C9A4);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _maroon : _tan,
                width: selected ? 3 : 2,
              ),
            ),
            child: Image.asset(
              asset,
              width: compact ? 46 : 120,
              height: compact ? 46 : 120,
              semanticLabel: label,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto =
        (ref.watch(meProvider).valueOrNull?.profilePicUrl ?? '').isNotEmpty;
    return InkWell(
      borderRadius: AppRadius.md,
      onTap: () => changeProfilePhoto(context, ref),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF7EFE4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6D5BD), width: 1),
        ),
        child: Row(
          children: [
            const ProfilePhotoButton(size: 52, onDarkBackground: false),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasPhoto ? 'Looking good!' : 'Add a profile photo',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A0A0A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasPhoto
                        ? 'Tap to change it anytime'
                        : 'Optional • Helps your batchmates recognise you after all these years.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9A9280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Status toggle ─────────────────────────────────────────────────────────────

class _StatusToggle extends StatelessWidget {
  const _StatusToggle({required this.isStudent, required this.onChanged});

  final bool isStudent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5EBDD),
        border: Border.all(color: const Color(0xFFE6D5BD), width: 1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _Chip(
            label: 'APS Alumni',
            icon: HugeIcons.strokeRoundedMortarboard01,
            active: !isStudent,
            onTap: () => onChanged(false),
          ),
          _Chip(
            label: 'Current student',
            icon: HugeIcons.strokeRoundedUserGroup,
            active: isStudent,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final AppIconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.crimson : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HugeIcon(
                icon: icon,
                size: 16,
                color: active ? Colors.white : AppColors.crimson,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : const Color(0xFF2A1A14),
                  ),
                ),
              ),
              if (active) ...[
                const SizedBox(width: 6),
                const HugeIcon(
                  icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                  size: 16,
                  color: AppColors.gold,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: GestureDetector(
        onTap: onNext,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: const Color(0xFF2A0808),
            borderRadius: AppRadius.sm,
            border: Border.all(
              color: AppColors.crimson.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppColors.gold.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Save and continue',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
