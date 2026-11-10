// Generates one Figma-pasteable SVG per flow into ../figma-svg/ and a local preview page.
// Run: node make_flow_svgs.mjs   (no dependencies)
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const out = join(dirname(fileURLToPath(import.meta.url)), '..', 'figma-svg');
mkdirSync(out, { recursive: true });

const C = { crimson: '#7B1414', dark: '#5C0F0F', gold: '#D4A84A', cream: '#FBF8F6', line: '#EADCDC', ink: '#1A0606', mute: '#9A7070', tint: '#F3ECEC' };
const W = 200, H = 58, DH = 104, GX = 40, GY = 60, PAD = 80;

// type: s=start, p=step, d=decision, e=end/result, x=problem/blocked
const flows = [
  {
    id: '01-entry-and-onboarding', title: 'Entry and onboarding',
    nodes: {
      sp: ['s', 'Splash'], lg: ['p', 'Login: enter email'], gg: ['p', 'Continue with Google'],
      cd: ['p', 'Enter 6-digit code'], ob: ['d', 'Name + username saved?'],
      id: ['p', 'Identity: name, username, date of birth, status'], sc: ['p', 'Schools (optional to fill)'],
      st: ['d', 'Student or alumni?'], ca: ['p', 'Life after school (skippable)'], so: ['p', 'Socials (optional)'],
      hm: ['e', 'Home'], gt: ['x', 'Social features locked: "Finish setting up your profile first"'],
    },
    edges: [['sp', 'lg', 'Get Started / Log In'], ['lg', 'cd', 'Send Code'], ['lg', 'gg', 'or'], ['cd', 'ob', 'Verify'], ['gg', 'ob'],
      ['ob', 'hm', 'Yes'], ['ob', 'id', 'No'], ['ob', 'gt', 'No, tries a feature'], ['id', 'sc'], ['sc', 'st'], ['st', 'ca', 'Alumni'], ['st', 'so', 'Student'], ['ca', 'so'], ['so', 'hm']],
  },
  {
    id: '02-main-navigation', title: 'Main navigation (5 tabs)',
    nodes: {
      h: ['s', 'Home shell'], t1: ['p', 'Home'], t2: ['p', 'Batchmates'], t3: ['p', 'Communities'], t4: ['p', 'Messages'], t5: ['p', 'Profile'],
      no: ['p', 'Notifications'], rq: ['p', 'Connection requests'], op: ['p', "Someone's profile"], ch: ['p', '1:1 Chat'],
      cp: ['p', 'Community page'], ev: ['p', 'Event'], po: ['p', 'Post + comments'], cc: ['p', 'Community chat'], jr: ['p', 'Join requests (owner)'],
      ep: ['p', 'Edit profile / schools / career / socials'], se: ['p', 'Settings sheet'], bl: ['p', 'Blocked users'],
    },
    edges: [['h', 't1'], ['h', 't2'], ['h', 't3'], ['h', 't4'], ['h', 't5'], ['t1', 'no'], ['no', 'rq'], ['t1', 'po'], ['t2', 'op'], ['op', 'ch'], ['t4', 'ch'],
      ['t3', 'cp'], ['cp', 'ev'], ['cp', 'po'], ['cp', 'cc'], ['cp', 'jr'], ['t5', 'ep'], ['t5', 'se'], ['se', 'bl']],
  },
  {
    id: '03-join-a-community', title: 'Join a community',
    nodes: {
      d: ['s', 'Discover / search'], p: ['d', 'Public or private?'], j: ['p', 'Tap Join'], r: ['p', 'Tap Request'],
      m: ['e', 'Member: Feed, Chat, Events, Members'], w: ['p', 'Requested: waiting for the owner'], ap: ['d', 'Owner decides'],
      rj: ['x', 'Rejected: back to Discover'], sc: ['p', 'School community: join from "Your schools"'],
    },
    edges: [['d', 'p'], ['p', 'j', 'Public'], ['p', 'r', 'Private'], ['j', 'm'], ['r', 'w'], ['w', 'ap'], ['ap', 'm', 'Approve'], ['ap', 'rj', 'Reject'], ['rj', 'd'], ['sc', 'm']],
  },
  {
    id: '04-create-a-post', title: 'Create a post',
    nodes: {
      a: ['s', 'Tap "Share a memory or update"'], b: ['p', 'New post sheet'], c: ['p', 'Write text and/or add up to 10 photos'],
      s: ['d', 'School community and photos?'], m: ['p', 'Optional: mark as school memory (year + category)'],
      e: ['d', 'Opened from an event?'], ev: ['p', 'Post is tagged to the event (photos tab)'],
      pb: ['e', 'Posted: appears in Feed and Home'], lim: ['x', 'Over 10 posts/hour: "You\'re posting a lot"'], rp: ['p', 'Others: like, comment, share, report; owner/staff: pin'],
    },
    edges: [['a', 'b'], ['b', 'c'], ['c', 's'], ['s', 'm', 'Yes'], ['s', 'e', 'No'], ['m', 'e'], ['e', 'ev', 'Yes'], ['e', 'pb', 'No'], ['ev', 'pb'], ['c', 'lim', 'Too many'], ['pb', 'rp']],
  },
  {
    id: '05-event-lifecycle', title: 'Event lifecycle',
    nodes: {
      c: ['s', 'Owner/staff: Create event (title, venue, start AND end)'], u: ['p', 'Upcoming list: soonest first'], r: ['p', 'Members RSVP: Going / Interested'],
      st: ['d', 'Start time reached?'], ph: ['p', 'Members can share photos (tagged post)'], en: ['d', 'End time passed?'], pa: ['e', 'Moves to Past list (RSVP closed)'],
      ed: ['p', 'Owner edits time or venue: RSVPd people notified'], cx: ['x', 'Owner cancels: RSVPd people notified, shown crossed out'],
    },
    edges: [['c', 'u'], ['u', 'r'], ['r', 'st'], ['st', 'ph', 'Yes'], ['st', 'ed', 'No, edit'], ['ed', 'u'], ['ph', 'en'], ['en', 'pa', 'Yes'], ['u', 'cx', 'Cancel']],
  },
  {
    id: '06-community-chat', title: 'Community chat',
    nodes: {
      a: ['s', 'Member opens Chat (tab, or header button for schools)'], b: ['p', 'Messages load, newest at bottom, older on scroll'],
      c: ['p', 'Send text or one photo'], d: ['p', 'Live push to every connected member'], e: ['p', 'Unread count on header Chat button'],
      f: ['d', 'Bad message?'], g: ['p', 'Long-press: Report, or Delete (author / owner / staff)'], h: ['x', '3 different reporters: auto-hidden, removal pushed live'],
      l: ['x', 'Over 120 messages/hour: slow down'],
    },
    edges: [['a', 'b'], ['b', 'c'], ['c', 'd'], ['d', 'e'], ['c', 'l', 'Too many'], ['b', 'f'], ['f', 'g', 'Yes'], ['g', 'h']],
  },
  {
    id: '07-connect-and-message', title: 'Connect and message a batchmate',
    nodes: {
      a: ['s', 'Batchmates card, Members row or Profile'], b: ['d', 'Relation?'], c: ['p', 'Connect: request sent'], rq: ['p', 'Requested'],
      ac: ['p', 'Other person accepts'], cn: ['e', 'Connected: Message button, photos allowed, 4000 chars'],
      ms: ['p', 'Message without connecting'], lm: ['x', 'Not connected: 300 chars, no photos, one message until they reply'],
      pi: ['p', 'Incoming request: Accept or Decline'],
    },
    edges: [['a', 'b'], ['b', 'c', 'None'], ['b', 'pi', 'They asked me'], ['b', 'cn', 'Connected'], ['c', 'rq'], ['rq', 'ac'], ['ac', 'cn'], ['pi', 'cn', 'Accept'], ['a', 'ms'], ['ms', 'lm']],
  },
  {
    id: '08-block-and-report-a-person', title: 'Block or report a person',
    nodes: {
      a: ['s', "Open someone's profile, tap the menu"], b: ['d', 'Choose'], r: ['p', 'Report user: pick a reason'], rs: ['e', 'Report filed (repeats count once)'],
      k: ['p', 'Block user: confirm'], bk: ['e', 'Hidden both ways: search, members, chat, profile'], ul: ['p', 'Settings > Blocked users > Unblock'],
      se: ['x', 'Cannot report or block yourself'],
    },
    edges: [['a', 'b'], ['b', 'r', 'Report'], ['b', 'k', 'Block'], ['r', 'rs'], ['k', 'bk'], ['bk', 'ul'], ['b', 'se', 'Self']],
  },
  {
    id: '09-report-a-post-comment-message', title: 'Report content',
    nodes: {
      a: ['s', 'Post / comment / chat message: menu or long-press'], b: ['p', 'Report: pick a reason'], c: ['d', 'Own content?'], x: ['x', 'Not allowed: "You can\'t report your own post"'],
      d: ['p', 'Report saved (one per person per item)'], e: ['d', 'Reached 3 different reporters?'], f: ['x', 'Auto-hidden for everyone until staff review'], g: ['e', 'Stays visible'],
      h: ['p', 'Staff can restore from admin'],
    },
    edges: [['a', 'b'], ['b', 'c'], ['c', 'x', 'Yes'], ['c', 'd', 'No'], ['d', 'e'], ['e', 'f', 'Yes'], ['e', 'g', 'No'], ['f', 'h']],
  },
  {
    id: '10-create-a-community', title: 'Create a community',
    nodes: {
      a: ['s', 'Communities tab: tap + or "Create one"'], b: ['p', 'Name (3+), description, Public or Private'], c: ['d', 'Valid?'],
      e1: ['x', 'Name already taken'], e2: ['x', 'Limit: 5 communities per person'], ok: ['e', 'Created: you are the Owner'],
      jr: ['p', 'Private: approve or reject join requests'], ev: ['p', 'Owner can create events, pin posts, remove members'],
    },
    edges: [['a', 'b'], ['b', 'c'], ['c', 'e1', 'Taken'], ['c', 'e2', 'Too many'], ['c', 'ok', 'Valid'], ['ok', 'jr'], ['ok', 'ev']],
  },
  {
    id: '11-delete-account-and-data', title: 'Delete account and download data',
    nodes: {
      a: ['s', 'Profile > Settings > Account'], b: ['d', 'Choose'], dl: ['p', 'Download my data (share sheet, JSON)'], dd: ['p', 'Delete account: confirm dialog'],
      so: ['e', 'Signed out'], af: ['p', 'Others see: name kept on posts, profile "Unknown user", no message or connect'],
      wp: ['p', 'Removed: email, phone, bio, city, photo, schools, socials'],
    },
    edges: [['a', 'b'], ['b', 'dl', 'Download'], ['b', 'dd', 'Delete'], ['dd', 'so'], ['so', 'wp'], ['so', 'af']],
  },
];

const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
function wrap(text, max) {
  const words = text.split(' '); const lines = []; let cur = '';
  for (const w of words) { if ((cur + ' ' + w).trim().length > max) { lines.push(cur); cur = w; } else cur = (cur + ' ' + w).trim(); }
  if (cur) lines.push(cur); return lines;
}

function layout(f) {
  const ids = Object.keys(f.nodes); const level = {}; const first = ids[0];
  level[first] = 0; const q = [first]; const back = new Set();
  const out = (id) => f.edges.filter((e) => e[0] === id);
  while (q.length) {
    const u = q.shift();
    for (const [, v] of out(u)) {
      if (level[v] === undefined) { level[v] = level[u] + 1; q.push(v); }
    }
  }
  // push nodes down so every forward edge points to a deeper level
  let changed = true; let guard = 0;
  while (changed && guard++ < 50) {
    changed = false;
    for (const [a, b] of f.edges) {
      if (level[b] <= level[a] && !isBack(f, level, a, b)) { level[b] = level[a] + 1; changed = true; }
    }
  }
  function isBack(fl, lv, a, b) { return lv[b] < lv[a] && reach(fl, b, a); }
  function reach(fl, from, to, seen = new Set()) {
    if (from === to) return true; if (seen.has(from)) return false; seen.add(from);
    return fl.edges.filter((e) => e[0] === from).some(([, v]) => reach(fl, v, to, seen));
  }
  const rows = {};
  for (const id of ids) { (rows[level[id] ?? 0] ??= []).push(id); }
  const maxCols = Math.max(...Object.values(rows).map((r) => r.length));
  const width = PAD * 2 + maxCols * W + (maxCols - 1) * GX;
  const pos = {};
  for (const [lv, row] of Object.entries(rows)) {
    const total = row.length * W + (row.length - 1) * GX;
    row.forEach((id, i) => { pos[id] = { x: (width - total) / 2 + i * (W + GX), y: PAD + 40 + Number(lv) * (DH + GY), lv: Number(lv) }; });
  }
  const height = PAD * 2 + 40 + (Math.max(...Object.keys(rows).map(Number)) + 1) * (DH + GY);
  return { pos, width, height, level, isBack: (a, b) => isBack(f, level, a, b) };
}

function render(f) {
  const { pos, width, height, isBack } = layout(f);
  const parts = [];
  parts.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}" font-family="Roboto, Arial, sans-serif">`);
  parts.push(`<defs><marker id="ar" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M0,0 L10,5 L0,10 z" fill="${C.mute}"/></marker></defs>`);
  parts.push(`<rect width="${width}" height="${height}" fill="${C.cream}"/>`);
  parts.push(`<text x="${PAD}" y="${PAD + 8}" font-size="22" font-weight="700" fill="${C.crimson}">${esc(f.title)}</text>`);
  // edges first (under the nodes)
  for (const [a, b, label] of f.edges) {
    const A = pos[a], B = pos[b]; const ah = f.nodes[a][0] === 'd' ? DH : H; const bh = f.nodes[b][0] === 'd' ? DH : H;
    let d, lx, ly;
    if (isBack(a, b) || B.lv <= A.lv) {
      const x1 = A.x, y1 = A.y + ah / 2, x2 = B.x, y2 = B.y + bh / 2; const bulge = Math.min(x1, x2) - 50;
      d = `M${x1},${y1} C${bulge},${y1} ${bulge},${y2} ${x2},${y2}`; lx = bulge - 4; ly = (y1 + y2) / 2;
    } else {
      const x1 = A.x + W / 2, y1 = A.y + ah, x2 = B.x + W / 2, y2 = B.y; const my = (y1 + y2) / 2;
      d = `M${x1},${y1} C${x1},${my} ${x2},${my} ${x2},${y2}`; lx = (x1 + x2) / 2; ly = my - 4;
    }
    parts.push(`<path d="${d}" fill="none" stroke="${C.mute}" stroke-width="1.5" marker-end="url(#ar)"/>`);
    if (label) parts.push(`<text x="${lx}" y="${ly}" font-size="11" fill="${C.dark}" text-anchor="middle" paint-order="stroke" stroke="${C.cream}" stroke-width="4">${esc(label)}</text>`);
  }
  for (const [id, [type, label]] of Object.entries(f.nodes)) {
    const p = pos[id]; const lines = wrap(label, type === "d" ? 15 : 26); const h = type === 'd' ? DH : H;
    const cy = p.y + h / 2;
    let shape, fill, textFill = C.ink;
    if (type === 'd') { shape = `<polygon points="${p.x + W / 2},${p.y} ${p.x + W},${cy} ${p.x + W / 2},${p.y + h} ${p.x},${cy}" fill="#F6E7BF" stroke="${C.gold}" stroke-width="1.5"/>`; }
    else if (type === 's') { shape = `<rect x="${p.x}" y="${p.y}" width="${W}" height="${h}" rx="29" fill="${C.crimson}"/>`; textFill = '#fff'; }
    else if (type === 'e') { shape = `<rect x="${p.x}" y="${p.y}" width="${W}" height="${h}" rx="12" fill="#E9F3E4" stroke="#6BA35A" stroke-width="1.5"/>`; }
    else if (type === 'x') { shape = `<rect x="${p.x}" y="${p.y}" width="${W}" height="${h}" rx="12" fill="#FDEBEB" stroke="#D86060" stroke-width="1.5"/>`; }
    else { shape = `<rect x="${p.x}" y="${p.y}" width="${W}" height="${h}" rx="12" fill="#fff" stroke="${C.line}" stroke-width="1.5"/>`; }
    parts.push(shape);
    const startY = cy - ((lines.length - 1) * 15) / 2 + 4;
    lines.forEach((ln, i) => parts.push(`<text x="${p.x + W / 2}" y="${startY + i * 15}" font-size="12.5" font-weight="500" fill="${textFill}" text-anchor="middle">${esc(ln)}</text>`));
  }
  // legend
  const ly = height - 24; let lx = PAD;
  for (const [fill, stroke, name] of [[C.crimson, C.crimson, 'Start'], ['#fff', C.line, 'Step'], ['#F6E7BF', C.gold, 'Decision'], ['#E9F3E4', '#6BA35A', 'Result'], ['#FDEBEB', '#D86060', 'Blocked / limit']]) {
    parts.push(`<rect x="${lx}" y="${ly - 10}" width="14" height="14" rx="3" fill="${fill}" stroke="${stroke}"/><text x="${lx + 20}" y="${ly + 2}" font-size="11" fill="${C.mute}">${name}</text>`);
    lx += 100;
  }
  parts.push('</svg>');
  return parts.join('\n');
}

const index = [];
for (const f of flows) {
  writeFileSync(join(out, `${f.id}.svg`), render(f));
  index.push(f);
}
writeFileSync(join(out, 'index.html'), `<!doctype html><meta charset="utf-8"><title>APS Brats flows</title>
<body style="margin:0;background:#FBF8F6;font-family:Arial,sans-serif;color:#1A0606;padding:24px">
<h1 style="color:#7B1414">APS Brats: user flows</h1><p>Each SVG pastes into Figma: open the .svg file, select all, copy, and paste on a Figma canvas.</p>
${index.map((f) => `<h2>${f.title}</h2><img src="${f.id}.svg" style="max-width:100%;border:1px solid #EADCDC;border-radius:8px;background:#fff">`).join('\n')}
</body>`);
console.log(`wrote ${flows.length} svgs + index.html to ${out}`);
