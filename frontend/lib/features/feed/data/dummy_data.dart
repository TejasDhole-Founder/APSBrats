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

class AppChatMsg {
  const AppChatMsg({
    required this.person,
    required this.preview,
    required this.time,
    this.unread = false,
    this.unreadCount = 0,
  });

  final AppPerson person;
  final String preview;
  final String time;
  final bool unread;
  final int unreadCount;
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
final dummyMessages = kShowDemoContent ? _messages : <AppChatMsg>[];
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

const _messages = <AppChatMsg>[
  AppChatMsg(
    person: _rs,
    preview: 'Yaar remember the canteen?? 😭',
    time: '2 min ago',
    unread: true,
    unreadCount: 3,
  ),
  AppChatMsg(
    person: _pk,
    preview: 'Hahaha yes!! Sir used to make us...',
    time: '1 hr',
  ),
  AppChatMsg(
    person: _vk,
    preview: 'Bhai this app is insane 🔥',
    time: 'Yesterday',
    unread: true,
    unreadCount: 1,
  ),
  AppChatMsg(
    person: _sm,
    preview: 'Do you remember Mam from science?',
    time: '2 days',
  ),
  AppChatMsg(person: _kr, preview: 'Pune cantt gang 🫡', time: '3 days'),
];

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

// ── Communities ───────────────────────────────────────────────────────────────

class AppCommunity {
  const AppCommunity({
    required this.name,
    required this.members,
    required this.online,
    required this.lastSender,
    required this.lastMessage,
    required this.time,
    required this.avatars,
    required this.unreadCount,
    required this.autoJoinLabel,
    this.isYourSection = false,
    this.isYourSchool = false,
  });

  final String name;
  final int members;
  final int online;
  final String lastSender;
  final String lastMessage;
  final String time;
  final List<AppPerson> avatars;
  final int unreadCount;
  final String autoJoinLabel;
  final bool isYourSection;
  final bool isYourSchool;
}

class AppDiscoverCommunity {
  const AppDiscoverCommunity({
    required this.name,
    required this.memberCount,
    required this.subtitle,
  });

  final String name;
  final String memberCount;
  final String subtitle;
}

final dummyCommunities = kShowDemoContent ? _communities : <AppCommunity>[];
final dummyDiscoverCommunities = kShowDemoContent
    ? _discoverCommunities
    : <AppDiscoverCommunity>[];

const _communities = <AppCommunity>[
  AppCommunity(
    name: '12A · APS Patiala · 2022',
    members: 34,
    online: 8,
    lastSender: 'Rohit',
    lastMessage: 'guys remember PT period in Class 11? 🤣 those ...',
    time: '2 min ago',
    avatars: [_pk, _rs, _vk, _mj, _ap],
    unreadCount: 12,
    autoJoinLabel: 'AUTO-JOINED',
    isYourSection: true,
  ),
  AppCommunity(
    name: '9C · APS Pune · 2019',
    members: 28,
    online: 3,
    lastSender: 'Sneha',
    lastMessage: 'Pune cantt CSD canteen was the best 😍',
    time: '1 hr ago',
    avatars: [_sm, _kr, _rv],
    unreadCount: 4,
    autoJoinLabel: 'AUTO-JOINED',
    isYourSection: true,
  ),
  AppCommunity(
    name: 'APS Delhi Cantt · 2010–2015',
    members: 19,
    online: 1,
    lastSender: 'Aakash',
    lastMessage: 'Anyone remember the annual sports day? 😄',
    time: 'Yesterday',
    avatars: [_at, _dn],
    unreadCount: 0,
    autoJoinLabel: 'AUTO-JOINED',
    isYourSchool: true,
  ),
];

const _discoverCommunities = <AppDiscoverCommunity>[
  AppDiscoverCommunity(
    name: 'APS Patiala — All years',
    memberCount: '312 members',
    subtitle: 'Everyone who attended',
  ),
  AppDiscoverCommunity(
    name: 'APS Brats — All India',
    memberCount: '4,200+ members',
    subtitle: 'All 137 schools',
  ),
];
