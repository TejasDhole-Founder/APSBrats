import 'dart:async';
import 'package:apsbrat_frontend/features/profile/presentation/widgets/profile_photo.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';

import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_registration_service.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/availability_checker.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
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
    final gender = _gender ?? '';
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
          gender: _gender ?? '',
          isStudent: _isStudent,
        );
    _flow.markStep(2);
    if (mounted) context.go('/onboarding/schools');
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 5),
    );
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

  static const _crimson = AppColors.crimson;
  static const _border = Color(0xFFE2DDD5);
  static const _hint = Color(0xFFBBB4A8);

  static const _labelStyle = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w800,
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
                  'FIRST NAME',
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
                  'LAST NAME',
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
                'arjun.singh',
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
                  const Icon(
                    Icons.verified_rounded,
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
                  TextFormField(
                    controller: dobController,
                    readOnly: true,
                    onTap: onPickDob,
                    decoration: _dec(
                      'DD / MM / YYYY',
                      suffix: const Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: _hint,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _labeledField(
                  'GENDER',
                  DropdownButtonFormField<String>(
                    initialValue: gender,
                    isDense: true,
                    isExpanded: true,
                    hint: const Text(
                      'Select',
                      style: TextStyle(fontSize: 13, color: _hint),
                    ),
                    decoration: _dec(''),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A0A0A),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MALE', child: Text('Male')),
                      DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                      DropdownMenuItem(
                        value: 'NON_BINARY',
                        child: Text('Non-binary'),
                      ),
                      DropdownMenuItem(
                        value: 'PREFER_NOT',
                        child: Text('Prefer not to say'),
                      ),
                    ],
                    onChanged: onGenderChanged,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current city
          _labeledField(
            'CURRENT CITY',
            TextFormField(
              controller: cityController,
              decoration: _dec('Where are you based right now?'),
            ),
          ),
          // "What do you do now" moved to its own step (alumni only).
          const SizedBox(height: 14),

          // I AM A toggle
          const Text('I AM A', style: _labelStyle),
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
        Text(label, style: _labelStyle),
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
    return const Icon(
      Icons.check_circle_rounded,
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
class _PhotoCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasPhoto =
        (ref.watch(meProvider).valueOrNull?.profilePicUrl ?? '').isNotEmpty;
    return InkWell(
      borderRadius: AppRadius.md,
      onTap: () => changeProfilePhoto(context, ref),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAF8F5),
          borderRadius: AppRadius.md,
          border: Border.all(color: const Color(0xFFE8E2DA), width: 1.5),
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
                        : 'Optional. Helps your batchmates recognise you after all these years',
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
        border: Border.all(color: const Color(0xFFE2DDD5), width: 1.5),
        borderRadius: AppRadius.sm,
      ),
      child: Row(
        children: [
          _Chip(
            label: 'APS Alumni',
            active: !isStudent,
            onTap: () => onChanged(false),
          ),
          _Chip(
            label: 'Current student',
            active: isStudent,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.crimson : Colors.white,
            borderRadius: AppRadius.sm,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF9A9280),
            ),
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
                'Next — add my schools',
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
