import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// The fixed set of social platforms the app knows about.
/// `key` matches the backend `SocialPlatform` enum exactly.
class SocialPlatformInfo {
  const SocialPlatformInfo({
    required this.key,
    required this.name,
    required this.badge,
    required this.badgeColor,
    required this.hint,
  });

  final String key;
  final String name;
  final String badge;
  final Color badgeColor;
  final String hint;
}

const kSocialPlatforms = <SocialPlatformInfo>[
  SocialPlatformInfo(
    key: 'INSTAGRAM',
    name: 'Instagram',
    badge: 'IG',
    badgeColor: Color(0xFFE1306C),
    hint: '@yourhandle',
  ),
  SocialPlatformInfo(
    key: 'LINKEDIN',
    name: 'LinkedIn',
    badge: 'in',
    badgeColor: Color(0xFF0A66C2),
    hint: 'linkedin.com/in/yourname',
  ),
  SocialPlatformInfo(
    key: 'WHATSAPP',
    name: 'WhatsApp',
    badge: 'WA',
    badgeColor: Color(0xFF25D366),
    hint: '+91 your number',
  ),
  SocialPlatformInfo(
    key: 'TWITTER',
    name: 'Twitter / X',
    badge: 'X',
    badgeColor: Colors.black87,
    hint: '@yourx',
  ),
];

const kCustomSocialPlatform = SocialPlatformInfo(
  key: 'CUSTOM',
  name: 'Custom link',
  badge: '↗',
  badgeColor: AppColors.crimson,
  hint: 'url or @username',
);
