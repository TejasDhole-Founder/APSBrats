import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();
  final _cityController = TextEditingController();
  final _professionController = TextEditingController();
  String? _gender;
  bool _isStudent = false; // default: Alumni

  @override
  void initState() {
    super.initState();
    final s = ref.read(onboardingFlowProvider);
    _firstNameController.text = s.firstName;
    _lastNameController.text = s.lastName;
    _usernameController.text = s.username;
    _phoneController.text = s.phone;
    _emailController.text = s.email;
    _dobController.text = s.dob;
    _cityController.text = s.city;
    _professionController.text = s.profession;
    _gender = s.gender.isEmpty ? null : s.gender;
    _isStudent = s.isStudent;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    _cityController.dispose();
    _professionController.dispose();
    super.dispose();
  }

  void _next() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref.read(onboardingFlowProvider.notifier).saveIdentity(
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          username: _usernameController.text.trim(),
          phone: _phoneController.text.trim(),
          email: _emailController.text.trim(),
          dob: _dobController.text.trim(),
          city: _cityController.text.trim(),
          profession: _professionController.text.trim(),
          gender: _gender ?? '',
          isStudent: _isStudent,
        );
    context.go('/onboarding/verify');
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
      _dobController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: OnboardingFrame(
        step: 1,
        title: 'First, tell us about yourself.',
        subtitle: 'Your batchmates will use this to find and recognise you.',
        footer: _Footer(onNext: _next, onLogin: () => context.go('/login')),
        child: _FormBody(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          usernameController: _usernameController,
          phoneController: _phoneController,
          emailController: _emailController,
          dobController: _dobController,
          cityController: _cityController,
          professionController: _professionController,
          gender: _gender,
          isStudent: _isStudent,
          onGenderChanged: (v) => setState(() => _gender = v),
          onStatusChanged: (v) => setState(() => _isStudent = v),
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
    required this.phoneController,
    required this.emailController,
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
  final TextEditingController phoneController;
  final TextEditingController emailController;
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
              Expanded(child: _labeledField('FIRST NAME', TextFormField(
                controller: firstNameController,
                decoration: _dec('Arjun'),
                validator: _required,
                textCapitalization: TextCapitalization.words,
              ))),
              const SizedBox(width: 10),
              Expanded(child: _labeledField('LAST NAME', TextFormField(
                controller: lastNameController,
                decoration: _dec('Singh'),
                validator: _required,
                textCapitalization: TextCapitalization.words,
              ))),
            ],
          ),
          const SizedBox(height: 12),

          // Username
          _labeledField(
            'USERNAME',
            TextFormField(
              controller: usernameController,
              decoration: _dec('@arjun.singh'),
              validator: _required,
            ),
            hint: 'Your unique handle — how others find you',
          ),
          const SizedBox(height: 12),

          // Contact Details
          _ContactCard(
            phoneController: phoneController,
            emailController: emailController,
            dec: _dec,
          ),
          const SizedBox(height: 12),

          // DOB + Gender
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _labeledField('DATE OF BIRTH', TextFormField(
                  controller: dobController,
                  readOnly: true,
                  onTap: onPickDob,
                  decoration: _dec('DD / MM / YYYY',
                    suffix: const Icon(Icons.calendar_today_outlined, size: 16, color: _hint),
                  ),
                )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _labeledField('GENDER', DropdownButtonFormField<String>(
                  initialValue: gender,
                  hint: const Text('Select', style: TextStyle(fontSize: 13, color: _hint)),
                  decoration: _dec('').copyWith(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  style: const TextStyle(fontSize: 13, color: Color(0xFF1A0A0A)),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    DropdownMenuItem(value: 'NON_BINARY', child: Text('Non-binary')),
                    DropdownMenuItem(value: 'PREFER_NOT', child: Text('Prefer not to say')),
                  ],
                  onChanged: onGenderChanged,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Current city
          _labeledField('CURRENT CITY', TextFormField(
            controller: cityController,
            decoration: _dec('Where are you based right now?'),
          )),
          const SizedBox(height: 12),

          // Profession
          _labeledField(
            'WHAT ARE YOU UP TO NOW?',
            TextFormField(
              controller: professionController,
              decoration: _dec('NDA, IIT, working at Infosys...'),
            ),
            hint: 'Your batchmates are curious about life after APS',
          ),
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

  Widget _labeledField(String label, Widget field, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _labelStyle),
        const SizedBox(height: 5),
        field,
        if (hint != null) ...[
          const SizedBox(height: 3),
          Text(hint, style: const TextStyle(fontSize: 10, color: Color(0xFF9A9280))),
        ],
      ],
    );
  }

  static String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;
}

// ── Profile photo card ────────────────────────────────────────────────────────

class _PhotoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF8F5),
        borderRadius: AppRadius.md,
        border: Border.all(color: const Color(0xFFE8E2DA), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFEFEBE4),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppColors.crimson.withValues(alpha: 0.2),
                width: 1.5,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_outlined, size: 18, color: Color(0xFF9A9280)),
                Text('PHOTO', style: TextStyle(fontSize: 7, color: Color(0xFF9A9280), letterSpacing: 0.5)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add a profile photo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A0A0A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Help your batchmates recognise you after all these years',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9A9280), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Contact details card ──────────────────────────────────────────────────────

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.phoneController,
    required this.emailController,
    required this.dec,
  });

  final TextEditingController phoneController;
  final TextEditingController emailController;
  final InputDecoration Function(String, {Widget? suffix, String? prefix}) dec;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: AppRadius.md,
        border: Border.all(
          color: AppColors.crimson.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTACT DETAILS',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.crimson,
            ),
          ),
          const SizedBox(height: 8),
          // Phone row
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 16, color: Color(0xFF9A9280)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: dec('Phone number', prefix: '+91 '),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Email row
          Row(
            children: [
              const Icon(Icons.email_outlined, size: 16, color: Color(0xFF9A9280)),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: dec('arjun@example.com'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Used to verify you later — not shown publicly',
            style: TextStyle(fontSize: 10, color: Color(0xFF9A9280)),
          ),
        ],
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
          _Chip(label: 'APS Alumni', active: !isStudent, onTap: () => onChanged(false)),
          _Chip(label: 'Current student', active: isStudent, onTap: () => onChanged(true)),
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
  const _Footer({required this.onNext, required this.onLogin});

  final VoidCallback onNext;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        children: [
          // Next button
          GestureDetector(
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
          const SizedBox(height: 12),
          // Login link
          GestureDetector(
            onTap: onLogin,
            child: RichText(
              text: const TextSpan(
                style: TextStyle(fontSize: 13, color: Color(0xFF9A9280)),
                children: [
                  TextSpan(text: 'Already have an account? '),
                  TextSpan(
                    text: 'Log in',
                    style: TextStyle(
                      color: AppColors.crimson,
                      fontWeight: FontWeight.w700,
                    ),
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
