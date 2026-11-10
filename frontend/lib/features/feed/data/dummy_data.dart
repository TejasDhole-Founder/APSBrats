import 'package:flutter/material.dart';

/// Master switch for the hardcoded demo content.
/// false = the app looks like it does for a brand-new user (empty states).
/// true  = screens are filled with the demo people/messages below.
const bool kShowDemoContent = false;

class AppPerson {
  const AppPerson({
    required this.initials,
    required this.name,
    required this.school,
    required this.detail,
    required this.city,
    required this.job,
    required this.bg,
    required this.fg,
    this.tags = const [],
    this.online = false,
  });

  final String initials;
  final String name;
  final String school;
  final String detail;
  final String city;
  final String job;
  final Color bg;
  final Color fg;
  final List<String> tags;
  final bool online;
}

// ── People ────────────────────────────────────────────────────────────────────

const _pk = AppPerson(
  initials: 'PK',
  name: 'Priya Khanna',
  school: 'APS Patiala',
  detail: '12A · Class 2022',
  city: 'Bengaluru',
  job: 'Software Engineer, Wipro',
  bg: Color(0xFFFEE2E2),
  fg: Color(0xFF991B1B),
  tags: ['12A Patiala', 'Alumni'],
);
const _rs = AppPerson(
  initials: 'RS',
  name: 'Rohit Singh',
  school: 'APS Patiala',
  detail: '12A · Class 2022',
  city: 'Pune',
  job: 'NDA Cadet',
  bg: Color(0xFFD1FAE5),
  fg: Color(0xFF065F46),
  tags: ['12A Patiala', 'Alumni'],
  online: true,
);
const _vk = AppPerson(
  initials: 'VK',
  name: 'Vikram Kumar',
  school: 'APS Patiala',
  detail: '12A · Class 2022',
  city: 'Hyderabad',
  job: 'BITS Pilani',
  bg: Color(0xFFFEF3C7),
  fg: Color(0xFF78350F),
  tags: ['12A Patiala', 'Alumni'],
);
const _sm = AppPerson(
  initials: 'SM',
  name: 'Sneha Mehta',
  school: 'APS Pune',
  detail: '9C · Class 2019',
  city: 'Mumbai',
  job: 'IIT Bombay',
  bg: Color(0xFFEDE9FE),
  fg: Color(0xFF4C1D95),
  tags: ['9C Pune', 'Alumni'],
);
const _at = AppPerson(
  initials: 'AT',
  name: 'Aakash Tiwari',
  school: 'APS Delhi Cantt',
  detail: '11B · Class 2021',
  city: 'Delhi',
  job: 'DU Student',
  bg: Color(0xFFDBEAFE),
  fg: Color(0xFF1E40AF),
  tags: ['11B Delhi', 'Alumni'],
);
const _mj = AppPerson(
  initials: 'MJ',
  name: 'Meera Joshi',
  school: 'APS Patiala',
  detail: '12A · Class 2022',
  city: 'Chennai',
  job: 'Working at TCS',
  bg: Color(0xFFFCE7F3),
  fg: Color(0xFF9D174D),
  tags: ['12A Patiala', 'Alumni'],
);
const _kr = AppPerson(
  initials: 'KR',
  name: 'Karan Rao',
  school: 'APS Pune',
  detail: '9C · Class 2019',
  city: 'Bengaluru',
  job: 'Infosys',
  bg: Color(0xFFFEF9C3),
  fg: Color(0xFF713F12),
  tags: ['9C Pune', 'Alumni'],
);
const _dn = AppPerson(
  initials: 'DN',
  name: 'Divya Nair',
  school: 'APS Delhi Cantt',
  detail: '10A · Class 2020',
  city: 'Kochi',
  job: 'NIT Calicut',
  bg: Color(0xFFCCFBF1),
  fg: Color(0xFF065F46),
  tags: ['10A Delhi', 'Alumni'],
);
const _ap = AppPerson(
  initials: 'AP',
  name: 'Amit Prasad',
  school: 'APS Patiala',
  detail: '12B · Class 2022',
  city: 'Jaipur',
  job: 'Army officer',
  bg: Color(0xFFFEE2E2),
  fg: Color(0xFF7F1D1D),
  tags: ['12B Patiala', 'Alumni'],
);
const _rv = AppPerson(
  initials: 'RV',
  name: 'Riya Verma',
  school: 'APS Pune',
  detail: '8A · Class 2018',
  city: 'Nagpur',
  job: 'MBBS, GMC Nagpur',
  bg: Color(0xFFE0E7FF),
  fg: Color(0xFF3730A3),
  tags: ['8A Pune', 'Alumni'],
);

final dummyBatchmates = kShowDemoContent ? _batchmates : <AppPerson>[];
final dummyRecentJoins = kShowDemoContent ? _recentJoins : <AppPerson>[];
final dummyChatHistory = kShowDemoContent ? _chatHistory : <(String, String)>[];

const _batchmates = <AppPerson>[
  _pk,
  _rs,
  _vk,
  _sm,
  _at,
  _mj,
  _kr,
  _dn,
  _ap,
  _rv,
];
const _recentJoins = <AppPerson>[_pk, _rs, _vk, _sm, _at, _mj];

const _chatHistory = <(String, String)>[
  ('them', "Arjun! Oh my god, I can't believe you're on here too! 😭"),
  ('me', "Priya!! It's been 3 years yaar 😭 How are you? Where are you now?"),
  ('them', "In Bengaluru now! Working at Wipro. You??"),
  ('me', "NDA Dehradun! Can you believe it 😅 Remember PT period in Class 11?"),
  ('them', "HAHAHA yes!! Sir used to make us run 5 rounds if anyone talked 😂"),
];

const dummyAutoReplies = <String>[
  'Haha yes exactly! 😄',
  'Those were the best days honestly 😭',
  'Do you still talk to anyone else from our batch?',
  'APS Brat is the best thing that happened 🔥',
  'Come to Bengaluru sometime yaar!',
];
