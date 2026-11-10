import 'package:apsbrat_frontend/core/network/dio_client.dart';
import 'package:apsbrat_frontend/features/profile/presentation/widgets/profile_photo.dart';
import 'package:apsbrat_frontend/core/theme/app_inputs.dart';
import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_models.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/availability_model.dart';
import 'package:apsbrat_frontend/features/onboarding/data/services/onboarding_registration_service.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/availability_checker.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Edits the logged-in user's own details (PUT /users/me).
/// The phone number is the login credential, so it is shown but locked.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _displayDate = 'dd/MM/yyyy';
  static const _apiDate = 'yyyy-MM-dd';

  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _dob = TextEditingController();
  final _city = TextEditingController();
  final _profession = TextEditingController();
  final _bio = TextEditingController();
  late final AvailabilityChecker _usernameCheck;

  String? _gender;
  String _status = 'ALUMNI';
  String? _phone;
  String? _originalUsername;
  bool _loaded = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCheck = AvailabilityChecker(
      controller: _username,
      fetch: (value) {
        // Keeping your own current username is always fine.
        if (value == _originalUsername) {
          return Future.value(const Availability(available: true));
        }
        return const OnboardingRegistrationService().usernameAvailability(
          ref.read(dioProvider),
          value,
        );
      },
    )..addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _usernameCheck.dispose();
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _dob.dispose();
    _city.dispose();
    _profession.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final me = await ref.read(meProvider.future);
    if (!mounted) return;
    if (me != null) _fill(me);
    setState(() => _loaded = true);
  }

  void _fill(AuthUser me) {
    _fullName.text = me.fullName ?? '';
    _username.text = me.username ?? '';
    _originalUsername = me.username;
    _email.text = me.email ?? '';
    _dob.text = _toDisplayDate(me.dob);
    _city.text = me.city ?? '';
    _profession.text = me.profession ?? '';
    _bio.text = me.bio ?? '';
    _gender = me.gender;
    _status = me.currentStatus ?? 'ALUMNI';
    _phone = me.phone;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final current = _tryParseDisplay(_dob.text);
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime(now.year - 20),
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 5),
    );
    if (picked != null) {
      _dob.text = DateFormat(_displayDate).format(picked);
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!await _usernameCheck.passes()) {
      _usernameCheck.focus.requestFocus();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(profileRepositoryProvider)
          .updateMe(
            fullName: _fullName.text.trim(),
            username: _username.text.trim(),
            city: _nullIfEmpty(_city.text),
            profession: _nullIfEmpty(_profession.text),
            gender: _gender,
            dob: _toApiDate(_dob.text),
            bio: _nullIfEmpty(_bio.text),
            currentStatus: _status,
          );
      ref.invalidate(meProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
      context.pop();
    } on DioException catch (e) {
      final payload = e.response?.data;
      var message = 'Could not save. Please try again.';
      if (payload is Map<String, dynamic> && payload['error'] is String) {
        message = payload['error'] as String;
      }
      if (mounted) setState(() => _error = message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
                  const Text(
                    'Edit profile',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !_loaded
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.crimson,
                      ),
                    )
                  : Form(
                      key: _formKey,
                      // Errors show as soon as a field is edited, not only after Save.
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: _buildForm(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Center(
          child: Column(
            children: [
              const ProfilePhotoButton(size: 88, onDarkBackground: false),
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => changeProfilePhoto(context, ref),
                style: TextButton.styleFrom(foregroundColor: AppColors.crimson),
                child: const Text('Change photo'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _field(
          'PHONE · USED TO LOG IN',
          TextFormField(
            initialValue: _phone ?? '',
            readOnly: true,
            enabled: false,
            style: const TextStyle(fontSize: 13, color: kTxt3),
            decoration: appInputDecoration(
              '',
              suffix: const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: kTxt3,
              ),
            ),
          ),
          hint: 'Your phone is your login and cannot be changed here.',
        ),
        _field(
          'FULL NAME',
          TextFormField(
            controller: _fullName,
            textCapitalization: TextCapitalization.words,
            decoration: appInputDecoration('Arjun Singh'),
            validator: _required,
          ),
        ),
        _field(
          'USERNAME',
          TextFormField(
            controller: _username,
            focusNode: _usernameCheck.focus,
            inputFormatters: usernameInputFormatters,
            decoration: appInputDecoration(
              'arjun.singh',
              suffix: _usernameSuffix,
            ).copyWith(errorText: _usernameCheck.error),
            validator: _required,
          ),
          hint: _usernameHint,
          hintColor: _usernameCheck.confirmed ? Colors.green : null,
        ),
        _field(
          'EMAIL',
          TextFormField(
            controller: _email,
            readOnly: true,
            enabled: false,
            style: const TextStyle(fontSize: 13, color: kTxt3),
            decoration: appInputDecoration(
              '',
              suffix: const Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: kTxt3,
              ),
            ),
          ),
          hint: "Email can't be changed.",
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                'DATE OF BIRTH',
                TextFormField(
                  controller: _dob,
                  readOnly: true,
                  onTap: _pickDob,
                  validator: _required,
                  decoration: appInputDecoration(
                    'DD / MM / YYYY',
                    suffix: const Icon(
                      Icons.calendar_today_outlined,
                      size: 16,
                      color: kTxt3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                'GENDER',
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  isDense: true,
                  isExpanded: true,
                  hint: const Text(
                    'Select',
                    style: TextStyle(fontSize: 13, color: kTxt3),
                  ),
                  decoration: appInputDecoration(''),
                  style: const TextStyle(fontSize: 13, color: kTxt),
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
                  onChanged: (v) => setState(() => _gender = v),
                ),
              ),
            ),
          ],
        ),
        _field(
          'CURRENT CITY',
          TextFormField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: appInputDecoration('Where are you based right now?'),
          ),
        ),
        _field(
          'WHAT ARE YOU UP TO NOW?',
          TextFormField(
            controller: _profession,
            decoration: appInputDecoration('NDA, IIT, working at Infosys...'),
          ),
        ),
        _field(
          'BIO',
          TextFormField(
            controller: _bio,
            maxLines: 3,
            maxLength: 500,
            decoration: appInputDecoration('A line or two about you'),
          ),
        ),
        const Text('I AM A', style: appFieldLabelStyle),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'STUDENT', label: Text('Student')),
            ButtonSegment(value: 'ALUMNI', label: Text('Alumni')),
          ],
          selected: {_status},
          onSelectionChanged: (s) => setState(() => _status = s.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: AppColors.crimson,
            selectedForegroundColor: Colors.white,
            foregroundColor: kTxt2,
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.redAccent),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.crimson,
            minimumSize: const Size(double.infinity, 48),
            shape: const StadiumBorder(),
          ),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Save changes',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
      ],
    );
  }

  Widget _field(String label, Widget child, {String? hint, Color? hintColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: appFieldLabelStyle),
          const SizedBox(height: 5),
          child,
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
      ),
    );
  }

  Widget? get _usernameSuffix {
    if (_usernameCheck.checking) {
      return const Padding(
        padding: EdgeInsets.all(13),
        child: SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2, color: kTxt3),
        ),
      );
    }
    if (_usernameCheck.confirmed) {
      return const Icon(
        Icons.check_circle_rounded,
        size: 18,
        color: Colors.green,
      );
    }
    return null;
  }

  String? get _usernameHint {
    if (_usernameCheck.error != null) return null;
    if (_usernameCheck.checking) return 'Checking availability…';
    if (_usernameCheck.confirmed) return 'Username is available';
    return 'Your unique handle — how others find you';
  }

  static String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  static String? _nullIfEmpty(String v) => v.trim().isEmpty ? null : v.trim();

  static DateTime? _tryParseDisplay(String text) {
    try {
      return DateFormat(_displayDate).parseStrict(text.trim());
    } catch (_) {
      return null;
    }
  }

  static String _toDisplayDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? '' : DateFormat(_displayDate).format(parsed);
  }

  static String? _toApiDate(String display) {
    final parsed = _tryParseDisplay(display);
    return parsed == null ? null : DateFormat(_apiDate).format(parsed);
  }
}
