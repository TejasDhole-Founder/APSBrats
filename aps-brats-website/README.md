# APS Brats — Landing Page

Marketing site for **APS Brats**, the alumni network that reunites Army Public
School students with their batchmates across postings.

🌐 Single static page — no build step. Open `index.html` in any browser.

## Tech
- HTML + **Tailwind CSS v4** (browser CDN build, custom `@theme` brand tokens)
- **Alpine.js** for light interactivity (mobile menu, contact form, nav state)
- Vanilla JS for scroll-reveal animations (IntersectionObserver)
- Fonts: Cinzel (display) + Mulish (body) via Google Fonts

## Structure
```
.
├── index.html              # the entire landing page
├── assets/
│   ├── aps-brats-logo.svg  # horizontal wordmark (nav)
│   ├── logo.svg            # square crimson mark
│   ├── app-icon*.svg       # app icon + maskable variant
│   ├── favicon.*           # favicons
│   ├── icon-*.png          # store / PWA icons
│   └── screens/            # real app screenshots
├── LICENSE
└── .gitignore
```

## Run locally
Just open `index.html`, or serve it:
```bash
python3 -m http.server 8000   # then visit http://localhost:8000
```

## Deploy
Any static host works — GitHub Pages, Netlify, Vercel, Cloudflare Pages, S3.
For GitHub Pages: push to `main`, then enable Pages → deploy from `main` / root.

## Brand
- Crimson `#7B1414` · Gold `#D4A84A` · Cream `#F8F1E4`

## Contact
tejasdhole.work@gmail.com
