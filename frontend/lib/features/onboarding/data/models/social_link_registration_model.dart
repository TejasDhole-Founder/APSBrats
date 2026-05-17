import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';

class SocialLinkRegistrationModel {
  const SocialLinkRegistrationModel({
    required this.platform,
    required this.handle,
    this.label,
  });

  final String platform;
  final String handle;
  final String? label;

  static List<SocialLinkRegistrationModel> fromFlow(OnboardingFlowState flow) {
    final list = <SocialLinkRegistrationModel>[];

    void add(String platform, String handle, {String? label}) {
      final cleaned = handle.trim();
      if (cleaned.isEmpty) return;
      list.add(SocialLinkRegistrationModel(platform: platform, handle: cleaned, label: label));
    }

    add('INSTAGRAM', flow.instagram);
    add('LINKEDIN', flow.linkedin);
    add('WHATSAPP', flow.whatsapp);
    add('TWITTER', flow.twitter);
    add(
      'CUSTOM',
      flow.customHandle,
      label: flow.customLabel.trim().isEmpty ? 'Other' : flow.customLabel.trim(),
    );

    return list;
  }

  Map<String, dynamic> toJson() {
    return {
      'handle': handle,
      'label': label,
      'isVisible': true,
    };
  }
}
