import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';

class SocialLinkRegistrationModel {
  const SocialLinkRegistrationModel({
    required this.platform,
    required this.handle,
    this.label,
    this.isVisible = true,
  });

  final String platform;
  final String handle;
  final String? label;
  final bool isVisible;

  static List<SocialLinkRegistrationModel> fromFlow(OnboardingFlowState flow) {
    final list = <SocialLinkRegistrationModel>[];

    void add(
      String platform,
      String handle, {
      String? label,
      bool isVisible = true,
    }) {
      final cleaned = handle.trim();
      if (cleaned.isEmpty) return;
      list.add(
        SocialLinkRegistrationModel(
          platform: platform,
          handle: cleaned,
          label: label,
          isVisible: isVisible,
        ),
      );
    }

    bool shown(String platform) => !flow.privateSocials.contains(platform);

    add('INSTAGRAM', flow.instagram, isVisible: shown('INSTAGRAM'));
    add('LINKEDIN', flow.linkedin, isVisible: shown('LINKEDIN'));
    add('WHATSAPP', flow.whatsapp, isVisible: shown('WHATSAPP'));
    add('TWITTER', flow.twitter, isVisible: shown('TWITTER'));
    add(
      'CUSTOM',
      flow.customHandle,
      label: flow.customLabel.trim().isEmpty
          ? 'Other'
          : flow.customLabel.trim(),
      isVisible: shown('CUSTOM'),
    );

    return list;
  }

  Map<String, dynamic> toJson() {
    return {'handle': handle, 'label': label, 'isVisible': isVisible};
  }
}
