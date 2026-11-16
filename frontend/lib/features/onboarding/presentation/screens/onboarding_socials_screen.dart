import 'dart:async';

import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/auth/presentation/providers/auth_provider.dart';
import 'package:apsbrat_frontend/features/career/data/career_models.dart';
import 'package:apsbrat_frontend/features/career/data/career_repository.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/school_history_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/social_link_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/onboarding_frame.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:country_picker/country_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/core/theme/app_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// Page tone behind the socials form (warm, pale).
const _pageBg = Color(0xFFFFF9F6);

/// The calling code shown first, until the person picks another country.
const _defaultCountryCode = '+91';

// ── Screen ────────────────────────────────────────────────────────────────────

class OnboardingSocialsScreen extends ConsumerStatefulWidget {
  const OnboardingSocialsScreen({super.key});

  @override
  ConsumerState<OnboardingSocialsScreen> createState() =>
      _OnboardingSocialsScreenState();
}

class _OnboardingSocialsScreenState
    extends ConsumerState<OnboardingSocialsScreen> {
  final _instagramCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();

  /// The full WhatsApp value ("+91 98765 43210"), built from the code and the
  /// number box. This is what is saved.
  final _whatsappCtrl = TextEditingController();
  final _whatsappNumberCtrl = TextEditingController();
  String _whatsappCode = _defaultCountryCode;
  Set<String> _private = {'WHATSAPP'};

  final _twitterCtrl = TextEditingController();
  final _customLabelCtrl = TextEditingController();
  final _customHandleCtrl = TextEditingController();

  late final OnboardingFlowNotifier _flow;
  Timer? _saveTimer;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final flow = ref.read(onboardingFlowProvider);
    _instagramCtrl.text = flow.instagram;
    _linkedinCtrl.text = flow.linkedin;
    _whatsappCtrl.text = flow.whatsapp;
    _splitWhatsapp(flow.whatsapp);
    _private = flow.privateSocials.toSet();
    _twitterCtrl.text = flow.twitter;
    _customLabelCtrl.text = flow.customLabel;
    _customHandleCtrl.text = flow.customHandle;
    _flow = ref.read(onboardingFlowProvider.notifier);
    _whatsappNumberCtrl.addListener(_composeWhatsapp);
    for (final c in [
      _instagramCtrl,
      _linkedinCtrl,
      _whatsappCtrl,
      _twitterCtrl,
      _customLabelCtrl,
      _customHandleCtrl,
    ]) {
      c.addListener(_scheduleSave);
    }
  }

  /// Splits a saved "+91 98765 43210" into the code and the number box.
  void _splitWhatsapp(String saved) {
    final text = saved.trim();
    final match = RegExp(r'^(\+\d{1,4})\s+(.*)$').firstMatch(text);
    if (match != null) {
      _whatsappCode = match.group(1)!;
      _whatsappNumberCtrl.text = match.group(2)!.trim();
      return;
    }
    _whatsappNumberCtrl.text = text;
  }

  void _composeWhatsapp() {
    final number = _whatsappNumberCtrl.text.trim();
    _whatsappCtrl.text = number.isEmpty ? '' : '$_whatsappCode $number';
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
    final instagram = _instagramCtrl.text.trim();
    final linkedin = _linkedinCtrl.text.trim();
    final whatsapp = _whatsappCtrl.text.trim();
    final twitter = _twitterCtrl.text.trim();
    final customLabel = _customLabelCtrl.text.trim();
    final customHandle = _customHandleCtrl.text.trim();
    final privateSocials = _private.toList();
    final flow = _flow;

    void save() {
      if (!flow.mounted) return;
      flow.saveSocials(
        instagram: instagram,
        linkedin: linkedin,
        whatsapp: whatsapp,
        twitter: twitter,
        customLabel: customLabel,
        customHandle: customHandle,
        privateSocials: privateSocials,
      );
    }

    deferred ? Future(save) : save();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _syncDraft(deferred: true);
    _instagramCtrl.dispose();
    _linkedinCtrl.dispose();
    _whatsappCtrl.dispose();
    _whatsappNumberCtrl.dispose();
    _twitterCtrl.dispose();
    _customLabelCtrl.dispose();
    _customHandleCtrl.dispose();
    super.dispose();
  }

  void _setWhatsappCode(String code) {
    setState(() => _whatsappCode = code);
    _composeWhatsapp();
  }

  /// Public or private for one link, by platform key.
  void _setPublic(String platform, bool isPublic) {
    setState(() {
      if (isPublic) {
        _private.remove(platform);
      } else {
        _private.add(platform);
      }
    });
    _scheduleSave();
  }

  bool get _hasCustomLink => _customHandleCtrl.text.trim().isNotEmpty;

  /// Only one custom link can be saved per person for now.
  Future<void> _addLink() async {
    if (_hasCustomLink) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only one custom link can be added for now.'),
        ),
      );
      return;
    }
    final result = await showDialog<({String title, String url})>(
      context: context,
      builder: (_) => const _AddLinkDialog(),
    );
    if (result != null && result.url.isNotEmpty) {
      setState(() {
        _customLabelCtrl.text = result.title;
        _customHandleCtrl.text = result.url;
      });
    }
  }

  void _removeLink() {
    setState(() {
      _customLabelCtrl.clear();
      _customHandleCtrl.clear();
    });
  }

  /// Skipping leaves every social blank and finishes setup.
  Future<void> _skip() async {
    _instagramCtrl.clear();
    _linkedinCtrl.clear();
    _whatsappNumberCtrl.clear();
    _twitterCtrl.clear();
    _customLabelCtrl.clear();
    _customHandleCtrl.clear();
    _private = {'WHATSAPP'};
    await _finish();
  }

  Future<void> _finish() async {
    ref
        .read(onboardingFlowProvider.notifier)
        .saveSocials(
          instagram: _instagramCtrl.text.trim(),
          linkedin: _linkedinCtrl.text.trim(),
          whatsapp: _whatsappCtrl.text.trim(),
          twitter: _twitterCtrl.text.trim(),
          customLabel: _customLabelCtrl.text.trim(),
          customHandle: _customHandleCtrl.text.trim(),
          privateSocials: _private.toList(),
        );

    final flow = ref.read(onboardingFlowProvider);
    // The account exists from the moment the email (or Google) was verified —
    // this is filling in the profile that account still needs, not creating
    // a new one.
    // Read it from the device, not from memory: after the app is closed or
    // reloaded mid-registration the in-memory login is empty, but the saved
    // session (tokens + user id) is still valid.
    final userId =
        ref.read(authControllerProvider).user?.id ??
        await ref.read(authRepositoryProvider).currentUserId();
    if (userId == null || userId.isEmpty) {
      setState(() => _error = 'Your session expired — please log in again.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final profileRepo = ref.read(profileRepositoryProvider);
      // Only finished cards from "After school" are saved; Skip leaves none.
      final career = flow.career.where((c) => c.problem == null).toList();

      await profileRepo.updateMe(
        fullName: flow.fullName,
        username: flow.username,
        dob: apiDob(flow.dob),
        city: flow.city.isEmpty ? null : flow.city,
        profession: _profession(flow, career),
        gender: flow.gender.isEmpty ? null : flow.gender,
        currentStatus: flow.isStudent ? 'STUDENT' : 'ALUMNI',
      );

      final schoolItems = flow.schoolHistory
          .where((item) => item.schoolId.isNotEmpty)
          .map(SchoolHistoryRegistrationModel.fromDraft)
          .map((item) => item.toJson())
          .toList();
      if (schoolItems.isNotEmpty) {
        await profileRepo.replaceSchoolHistory(userId, schoolItems);
      }

      final links = SocialLinkRegistrationModel.fromFlow(flow);
      for (final social in links) {
        await profileRepo.saveSocialLink(
          userId: userId,
          platform: social.platform,
          handle: social.handle,
          label: social.label,
          isVisible: social.isVisible,
        );
      }
      // A field left empty removes any link saved for it before.
      final filled = {for (final l in links) l.platform};
      for (final platform in const [
        'INSTAGRAM',
        'LINKEDIN',
        'WHATSAPP',
        'TWITTER',
        'CUSTOM',
      ]) {
        if (!filled.contains(platform)) {
          await profileRepo.deleteSocialLink(
            userId: userId,
            platform: platform,
          );
        }
      }

      // Best effort: a job that fails to save must not block finishing
      // registration. It can be added again from the profile's Journey tab.
      var careerSaved = true;
      final careerRepo = ref.read(careerRepositoryProvider);
      for (final draft in career) {
        try {
          await careerRepo.save(draft);
        } catch (_) {
          careerSaved = false;
        }
      }
      ref.invalidate(myCareerProvider);

      await ref.read(authRepositoryProvider).markOnboardingDone();
      ref.read(onboardingFlowProvider.notifier).reset();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            careerSaved
                ? 'Profile completed'
                : "Profile completed. Your work details didn't save, add them "
                      'from the Journey tab.',
          ),
        ),
      );
      context.go('/home');
    } on DioException catch (e) {
      String message = 'Could not save your profile';
      final payload = e.response?.data;
      if (payload is Map<String, dynamic>) {
        final err = payload['error'];
        if (err is String && err.isNotEmpty) message = err;
      }
      setState(() => _error = message);
    } catch (_) {
      setState(() => _error = 'Could not save your profile');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// The one-line "what I do" other screens still read (people cards etc.):
  /// the current job, else the current college, else the latest job.
  String? _profession(OnboardingFlowState flow, List<CareerDraft> career) {
    CareerDraft? pick(bool Function(CareerDraft) test) =>
        career.where(test).firstOrNull;
    final c =
        pick((c) => c.isWork && c.current) ??
        pick((c) => !c.isWork && c.current) ??
        pick((c) => c.isWork);
    if (c != null) {
      return c.isWork
          ? '${c.title.trim()} at ${c.organizationName.trim()}'
          : '${c.title.trim()} student at ${c.organizationName.trim()}';
    }
    final text = flow.profession.trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = ref.watch(onboardingFlowProvider).isStudent;
    return OnboardingFrame(
      step: 4,
      showAfterSchool: !isStudent,
      title: 'Connect your socials',
      subtitle:
          'All fields are optional — add whatever you\'re comfortable sharing with your batchmates.',
      child: _FormBody(
        instagramCtrl: _instagramCtrl,
        linkedinCtrl: _linkedinCtrl,
        whatsappNumberCtrl: _whatsappNumberCtrl,
        whatsappCode: _whatsappCode,
        onWhatsappCode: _setWhatsappCode,
        twitterCtrl: _twitterCtrl,
        customLabel: _customLabelCtrl.text.trim(),
        customHandle: _customHandleCtrl.text.trim(),
        onAddLink: _addLink,
        onRemoveLink: _removeLink,
        privateSocials: _private,
        onVisibility: _setPublic,
      ),
      footer: _Footer(
        submitting: _submitting,
        error: _error,
        onSkip: _skip,
        onFinish: _finish,
      ),
    );
  }
}

// ── Form body ─────────────────────────────────────────────────────────────────

class _FormBody extends StatelessWidget {
  const _FormBody({
    required this.instagramCtrl,
    required this.linkedinCtrl,
    required this.whatsappNumberCtrl,
    required this.whatsappCode,
    required this.onWhatsappCode,
    required this.twitterCtrl,
    required this.customLabel,
    required this.customHandle,
    required this.onAddLink,
    required this.onRemoveLink,
    required this.privateSocials,
    required this.onVisibility,
  });

  final TextEditingController instagramCtrl;
  final TextEditingController linkedinCtrl;
  final TextEditingController whatsappNumberCtrl;
  final String whatsappCode;
  final ValueChanged<String> onWhatsappCode;
  final TextEditingController twitterCtrl;
  final String customLabel;
  final String customHandle;
  final VoidCallback onAddLink;
  final VoidCallback onRemoveLink;
  final Set<String> privateSocials;
  final void Function(String platform, bool isPublic) onVisibility;

  Widget _pill(String platform) => _VisibilityPill(
    isPublic: !privateSocials.contains(platform),
    onChanged: (v) => onVisibility(platform, v),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          _PlatformRow(
            logo: const _InstagramLogo(),
            title: 'Instagram',
            subtitle: 'Username or profile URL',
            trailing: _pill('INSTAGRAM'),
            child: _SocialInput(controller: instagramCtrl, hint: '@yourname'),
          ),
          const _RowDivider(),
          _PlatformRow(
            logo: const _LinkedInLogo(),
            title: 'LinkedIn',
            subtitle: 'Profile URL',
            trailing: _pill('LINKEDIN'),
            child: _SocialInput(
              controller: linkedinCtrl,
              hint: 'linkedin.com/in/yourname',
              keyboardType: TextInputType.url,
            ),
          ),
          const _RowDivider(),
          _PlatformRow(
            logo: const _WhatsAppLogo(),
            title: 'WhatsApp',
            subtitle: 'Phone number',
            trailing: _pill('WHATSAPP'),
            child: Row(
              children: [
                _CountryCodeBox(value: whatsappCode, onChanged: onWhatsappCode),
                const SizedBox(width: 10),
                Expanded(
                  child: _SocialInput(
                    controller: whatsappNumberCtrl,
                    hint: '98765 43210',
                    keyboardType: TextInputType.phone,
                  ),
                ),
              ],
            ),
          ),
          const _RowDivider(),
          _PlatformRow(
            logo: const _XLogo(),
            title: 'X',
            subtitle: 'Username or profile URL',
            trailing: _pill('TWITTER'),
            child: _SocialInput(controller: twitterCtrl, hint: '@yourname'),
          ),
          const SizedBox(height: 16),
          _CustomLinksCard(
            label: customLabel,
            url: customHandle,
            onAdd: onAddLink,
            onRemove: onRemoveLink,
            visibility: _pill('CUSTOM'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Platform row ──────────────────────────────────────────────────────────────

class _PlatformRow extends StatelessWidget {
  const _PlatformRow({
    required this.logo,
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  final Widget logo;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              logo,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.crimson,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _OptionalPill(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8A7A6E),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _OptionalPill extends StatelessWidget {
  const _OptionalPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFBEBD8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Optional',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.crimson,
        ),
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppColors.crimson.withValues(alpha: 0.08),
    );
  }
}

// ── Inputs ────────────────────────────────────────────────────────────────────

const _inputBorder = Color(0xFFE2DDD5);

InputDecoration _socialDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9A8F84), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _inputBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _inputBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.crimson, width: 1.5),
    ),
  );
}

class _SocialInput extends StatelessWidget {
  const _SocialInput({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: _socialDecoration(hint),
    );
  }
}

class _CountryCodeBox extends StatelessWidget {
  const _CountryCodeBox({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showCountryPicker(
        context: context,
        showPhoneCode: true,
        searchAutofocus: false,
        onSelect: (country) => onChanged('+${country.phoneCode}'),
        countryListTheme: CountryListThemeData(
          backgroundColor: const Color(0xFFFFFBF6),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          bottomSheetHeight: MediaQuery.sizeOf(context).height * 0.7,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          textStyle: const TextStyle(fontSize: 14, color: Color(0xFF1A0A0A)),
          searchTextStyle: const TextStyle(
            fontSize: 14,
            color: Color(0xFF1A0A0A),
          ),
          inputDecoration: _socialDecoration('Search country or code'),
        ),
      ),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(fontSize: 14, color: Color(0xFF1A0A0A)),
            ),
            const SizedBox(width: 4),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              color: AppColors.crimson,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logos ─────────────────────────────────────────────────────────────────────

class _InstagramLogo extends StatelessWidget {
  const _InstagramLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFFFEDA75),
            Color(0xFFFA7E1E),
            Color(0xFFD62976),
            Color(0xFF962FBF),
            Color(0xFF4F5BD5),
          ],
        ),
      ),
      child: const Center(
        child: FaIcon(
          FontAwesomeIcons.instagram,
          size: 22,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LinkedInLogo extends StatelessWidget {
  const _LinkedInLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF0A66C2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const FaIcon(
        FontAwesomeIcons.linkedinIn,
        size: 19,
        color: Colors.white,
      ),
    );
  }
}

class _WhatsAppLogo extends StatelessWidget {
  const _WhatsAppLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF25D366),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const FaIcon(
        FontAwesomeIcons.whatsapp,
        size: 22,
        color: Colors.white,
      ),
    );
  }
}

class _XLogo extends StatelessWidget {
  const _XLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const FaIcon(
        FontAwesomeIcons.xTwitter,
        size: 19,
        color: Colors.white,
      ),
    );
  }
}

// ── Custom links ──────────────────────────────────────────────────────────────

class _CustomLinksCard extends StatelessWidget {
  const _CustomLinksCard({
    required this.label,
    required this.url,
    required this.onAdd,
    required this.onRemove,
    required this.visibility,
  });

  final String label;
  final String url;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  /// The Public / Private pill shown beside the saved link.
  final Widget visibility;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4EE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.crimson.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedLink01,
                size: 28,
                color: AppColors.crimson,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Custom links',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.crimson,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Add other links like portfolio, YouTube, GitHub, etc.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF8A7A6E)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (url.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _inputBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label.isEmpty ? 'Link' : label,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A0A0A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6E5E52),
                          ),
                        ),
                      ],
                    ),
                  ),
                  visibility,
                  IconButton(
                    tooltip: 'Remove link',
                    onPressed: onRemove,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAdd,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedAddCircle,
                size: 18,
                color: AppColors.crimson,
              ),
              label: const Text(
                'Add a link',
                style: TextStyle(
                  color: AppColors.crimson,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: AppColors.crimson.withValues(alpha: 0.6),
                  width: 1.5,
                ),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy banner ────────────────────────────────────────────────────────────

/// Small Public / Private button with a menu, shown beside each link.
class _VisibilityPill extends StatelessWidget {
  const _VisibilityPill({required this.isPublic, required this.onChanged});

  final bool isPublic;
  final ValueChanged<bool> onChanged;

  PopupMenuItem<bool> _item(
    bool value,
    AppIconData icon,
    String title,
    String subtitle,
  ) {
    final selected = value == isPublic;
    return PopupMenuItem<bool>(
      value: value,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Container(
        constraints: const BoxConstraints(minWidth: 190),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFBE4E4) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 18, color: AppColors.crimson),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.crimson,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6E5E52),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const HugeIcon(
                icon: HugeIcons.strokeRoundedTick02,
                size: 18,
                color: AppColors.crimson,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: 'Who can see this',
      onSelected: onChanged,
      offset: const Offset(0, 40),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (_) => [
        _item(
          true,
          HugeIcons.strokeRoundedEye,
          'Public',
          'Visible to all batchmates',
        ),
        _item(
          false,
          HugeIcons.strokeRoundedLockKey,
          'Private',
          'Only you can see it',
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isPublic ? Colors.white : const Color(0xFFFBEBD8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isPublic
                ? AppColors.crimson.withValues(alpha: 0.4)
                : const Color(0xFFE3C9A4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: isPublic
                  ? HugeIcons.strokeRoundedEye
                  : HugeIcons.strokeRoundedLockKey,
              size: 16,
              color: AppColors.crimson,
            ),
            const SizedBox(width: 6),
            Text(
              isPublic ? 'Public' : 'Private',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.crimson,
              ),
            ),
            const SizedBox(width: 2),
            const HugeIcon(
              icon: HugeIcons.strokeRoundedArrowDown01,
              size: 18,
              color: AppColors.crimson,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  const _Footer({
    required this.submitting,
    required this.onSkip,
    required this.onFinish,
    this.error,
  });

  final bool submitting;
  final VoidCallback onSkip;
  final VoidCallback onFinish;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _pageBg,
      padding: const EdgeInsets.fromLTRB(17, 4, 17, 20),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error!,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.crimson,
                    side: const BorderSide(
                      color: AppColors.crimson,
                      width: 1.5,
                    ),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: submitting ? null : onSkip,
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.crimsonDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.crimsonDark.withValues(
                      alpha: 0.5,
                    ),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: submitting ? null : onFinish,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (submitting) ...[
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      const Text(
                        'Finish setup  →',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add-a-link dialog in the app's style. It owns its controllers, so closing it
/// at any point (Cancel, back, tap outside) is safe.
class _AddLinkDialog extends StatefulWidget {
  const _AddLinkDialog();

  @override
  State<_AddLinkDialog> createState() => _AddLinkDialogState();
}

class _AddLinkDialogState extends State<_AddLinkDialog> {
  final _titleCtrl = TextEditingController();
  final _urlCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBF6),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add a link',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.crimson,
              ),
            ),
            const SizedBox(height: 16),
            const _DialogLabel('Title'),
            const SizedBox(height: 6),
            TextField(
              controller: _titleCtrl,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(fontSize: 14),
              decoration: _socialDecoration('e.g. Portfolio'),
            ),
            const SizedBox(height: 12),
            const _DialogLabel('Link'),
            const SizedBox(height: 6),
            TextField(
              controller: _urlCtrl,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 14),
              decoration: _socialDecoration('https://yoursite.dev'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.crimson,
                      side: const BorderSide(
                        color: AppColors.crimson,
                        width: 1.5,
                      ),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.crimsonDark,
                      foregroundColor: Colors.white,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    onPressed: () => Navigator.of(context).pop((
                      title: _titleCtrl.text.trim(),
                      url: _urlCtrl.text.trim(),
                    )),
                    child: const Text(
                      'Add',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.crimson,
      ),
    );
  }
}

/// The form shows the birthday as 10/01/2006 (day/month/year); the API wants
/// 2006-01-10. Anything unreadable is left out rather than failing signup.
String? apiDob(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  try {
    return DateFormat(
      'yyyy-MM-dd',
    ).format(DateFormat('dd/MM/yyyy').parseStrict(t));
  } on FormatException {
    // Already in API form (e.g. an older saved draft)?
    final iso = DateTime.tryParse(t);
    return iso == null ? null : DateFormat('yyyy-MM-dd').format(iso);
  }
}
