# Wordle Words – Prioritized TODO

Goal: rank and get clicks for queries like **"is TIGER a wordle word"**, then send those visitors on to the
opensourcefeed.org puzzles (Wordle Unlimited, Decordle, Pentordle, Word Gridle).

Legend: **Impact** H/M/L · **Effort** S (< ½ day) / M (1–2 days) / L (3+ days)

---

## P0 – Blockers (do these before anything else)

The live site still runs the January 2025 commit. Every word page says only *"This page is about the word: tiger"*.
None of the local work has shipped, and the current local config would break the site if it were deployed as-is.

- [x] **Fix `_config.yml`** (Impact H, Effort S)
  - `url: https://www.opensourcefeed.org` and `baseurl: /wordle-words`. Right now `baseurl: /` builds `/assets/style.css`, which returns 404 on the live domain.
  - Remove the duplicate `url`, `domain` and `plugins` keys. The second `plugins:` block silently overrides the first.
  - `plugins: [jekyll-sitemap, jekyll-seo-tag]` (both are allowed on GitHub Pages).
  - `exclude: [generate_word_pages.rb, processed_words.yml, Gemfile, Gemfile.lock, TODO.md, .ruby-lsp]`. The generator script is currently published in `_site/`.
- [x] **Replace hard-coded `href="/"` with `{{ '/' | relative_url }}`** in `_includes/header.html` and `_layouts/word.html`. Today "Back to All Words" goes to the opensourcefeed.org homepage. (H, S)
- [x] **Do NOT delete the 5,727 "skipped" word pages** (the uncommitted `D word/*.md`). They are live URLs today, and the home page links to all 14,855 words, so deleting them creates thousands of internal 404s. Generate a page for **every** word in `_data/wordle-words.yml`. A definition is optional, because the Wordle data from P1 carries the page. (H, M)
- [x] **Deploy, then verify in production**: CSS loads, `/wordle-words/sitemap.xml` returns 200 (it returns 404 today), and the canonical URLs are correct. (H, S)
- [ ] **Google Search Console** *(your action, needs account access)*: add the property and submit `https://www.opensourcefeed.org/wordle-words/sitemap.xml`. Also add `Sitemap: https://www.opensourcefeed.org/wordle-words/sitemap.xml` to the main site's `robots.txt` (that file lives in the main site repo; crawlers ignore `/wordle-words/robots.txt`). (H, S)
- [x] **Trust and compliance pages** (H, S)
  - [x] Rewrote `about.markdown`: what the site is, word-list and definition sources, who runs it, contact, NYT disclaimer.
  - [x] Privacy Policy: footer links to the main site's existing `/privacy-policy/`, which already covers AdSense, Google cookies and Ahrefs.
  - [ ] *(your action)* Confirm the Google-certified consent message (CMP) for EEA/UK is turned on in AdSense under **Privacy & messaging**. That setting is per account, so it's not set in this repo.
  - [x] Attribution line on every word page with a definition (Wiktionary via the Free Dictionary API, CC BY-SA).
  - [x] Footer: About, Privacy Policy and OpenSourceFeed links, an NYT trademark disclaimer, and a current-year "© Tahrik Studio" (same owner name as the main site).
  - [x] Added `jekyll-seo-tag` (canonical, meta description, Open Graph and Twitter tags), and made word-page canonical and sitemap URLs extensionless (`/word/tiger`).
- [x] **Offensive words**: 60 slurs, strong profanities and explicit sexual terms are listed in `_data/sensitive-words.yml`. Their pages have no ads, a `noindex` tag and no sitemap entry. To keep the page flags in sync, run `ruby scripts/flag_sensitive_words.rb`; `scripts/validate_words.rb` checks it. Review the list from time to time. (M, S)

## P1 – Answer the search intent better than competitors

Searchers want three facts: (1) Is it an accepted guess? (2) Can it be a daily answer? (3) Has it already been an answer, and when?
Competitors such as fiveletterwords.io already show all three. A bare "Yes, it's a candidate" will not win.

- [x] **Page title and meta, built from the query wording** (H, S)
  - `<title>` such as *Is TIGER a Wordle Word? Yes – Past Answer #200 & Meaning* (or *Possible Answer* / *Valid Guess*).
  - Per-word meta description that gives the answer first, e.g. *"Yes, TIGER is a valid Wordle word. It was the Wordle answer on January 5, 2022 (#200)…"*.
  - `<h1>Is TIGER a Wordle Word?</h1>`, then an answer card with letter tiles, a verdict and badges (Accepted guess · Past answer #N · date / Possible future answer / Not on the answer list).
- [x] **Wordle status data** (H, M)
  - `_data/original-answers.yml`: the original 2,315-word answer list. If a word on it hasn't been used yet, the page shows it as a "possible future answer".
  - `_data/past-answers.yml`: every answer up to **yesterday**, with date and puzzle number (today's answer is never shown, so there are no spoilers). Refresh with `ruby scripts/update_past_answers.rb`.
  - Plain-language answer rules on guess-only words ending in -S or -ED.
- [x] **Unique per-word content**, computed offline by `scripts/build_pages.rb` (H, M)
  - Starter-word rating (tier and top-%) based on letter frequency in answers, plus vowels, unique and repeated letters, and common and rare letters.
  - Up to 12 neighbours (words one letter away, common answer words first) and anagrams, all as internal links. Sensitive words are never linked.
  - Hard-mode trap warning when 6+ words share a pattern (e.g. `_ATCH`: 10 words).
- [x] **Cleaned-up definitions**: stored as structured `phonetic` + `definitions` front matter (no raw HTML, output escaped). The page shows up to 3 definitions per part of speech, with the rest in a "more definitions" toggle, and examples in italics. (M, S)
- [x] **Structured data**: `BreadcrumbList` + `DefinedTerm` JSON-LD on word pages, alongside `jekyll-seo-tag`'s `WebPage`. Skipped `WebSite`/`SearchAction`, because Google retired the sitelinks search box in late 2024. (M, S)
- [x] **"No" answers**: the 404 page checks the requested word (`/word/xyzzq`) against `assets/words.json`. It says why it isn't valid (not in the list, wrong length, non-letters), suggests valid words one letter away, and includes a check-another-word box. (M, M)
- [ ] **Static pages for popular invalid words** (4- and 6-letter words, proper nouns): wait for Search Console data to show which ones people actually search. (M, M)
- [ ] **Keep data fresh**: run `ruby scripts/update_past_answers.rb && bundle exec ruby scripts/build_pages.rb` weekly. Best automated with a scheduled GitHub Action (see P5). (M, S)

**Page-data workflow:** `generate_word_pages.rb` (fetch missing definitions) → `scripts/update_past_answers.rb` → `scripts/build_pages.rb` → `scripts/validate_words.rb`.

## P2 – Crawlability, internal linking and hub pages

The home page's word list is built entirely by JavaScript from 120 KB of inline JSON, so word pages are close to orphaned for crawlers.

- [ ] **Static browse pages in the HTML**: `/letter/a/` … `/letter/z/` with real `<a>` links. Paginate when a page would have more than about 500 links. (H, M)
- [ ] **"5 letter words starting with / ending with / containing X" hub pages**: these are high-volume queries that fit this dataset exactly. Start with the 26 starting letters and the top 2-letter prefixes and suffixes, then expand based on Search Console data. (H, M)
- [ ] **Word page links**: breadcrumb (Home › T › TIGER), the neighbour and anagram blocks, previous/next alphabetical word, and a link to the starting-letter hub. (H, S)
- [ ] **Hub pages for answers**: "All past Wordle answers" (by date and A–Z) and "Possible Wordle answers". (M, M)
- [ ] **Rework the home page**: put a real H1 and a **word checker** box above the fold (type a word, get an instant ✅/❌ plus a link). Move the ad below the checker. ~~Remove the duplicate `class` attributes on the pagination divs~~ (done: pagination never rendered before, so only the first 1,000 words were browsable). (M, S)

## P3 – User experience, device friendliness and speed

- [x] Dropped the Bootstrap CDN (~230 KB CSS, ~30 KB gzipped, render-blocking). `_includes/site.scss` now defines only what the site uses (reset, container, navbar, buttons, form input, pagination, utilities) plus the site styles: 5.9 KB minified, ~2 KB gzipped. It is compiled once per build and inlined on every page through `{% include_cached inline-css.html %}`, so pages make no stylesheet request. (M, S)
- [ ] Remove the empty `assets/main.js` request. Load `home.js` with `defer`. (L, S)
- [ ] Reserve a fixed min-height for ad slots to avoid layout shift (CLS). Keep only one ad above the fold on mobile. (M, S)
- [ ] Mobile: 48 px tap targets on word tiles, a sticky search on the browse pages, and replace the 15-button pagination with prev/next plus a page select. (M, S)
- [ ] Add dark mode (`prefers-color-scheme`), a favicon and touch icons, and a `theme-color` meta tag. (L, S)
- [ ] Accessibility: a label on the search input, a visible focus state, and colour contrast that passes WCAG AA. (M, S)
- [ ] Target Lighthouse mobile ≥ 90 for Performance, SEO and Accessibility on the home page and a word page. (M, S)

### Premium look and feel

Users judge a site's trust and quality in the first few seconds. A polished design raises dwell time, return visits and click-through to the puzzles. Do this alongside dropping Bootstrap, so the new design is built once.

- [ ] **Design tokens**: define colours, spacing, radius and shadows as CSS variables, with light and dark sets. Use Wordle-like status colours (green/yellow/grey) as accents only, in your own shades, not NYT's exact palette. (M, S)
- [ ] **Typography**: one distinctive display font for headings and word tiles, plus a clean system or Inter-style body font. Self-host the fonts or use `font-display: swap`. Use a consistent type scale. (M, S)
- [ ] **Hero word tiles on word pages**: show TIGER as 5 letter tiles with a subtle flip-in animation, colour-coded by answer status. Respect `prefers-reduced-motion`. (H, S)
- [ ] **Status badges and answer card**: pill badges for "Valid guess", "Possible answer" and "Past answer #NNN · date", in one prominent card at the top of the page. (H, S)
- [ ] **Card-based layout**: separate cards for Definition, Wordle stats, Neighbours and Anagrams, and Play. Use generous whitespace, keep body text to a max width of about 720 px, and add small icons (inline SVG, no icon font). (M, M)
- [ ] **Branded header and footer**: logo or wordmark, nav (Browse A–Z, Past answers, Solver, Play puzzles), and a footer with About, Privacy, Attribution and links to the other puzzles. Replace the plain Bootstrap dark navbar. (M, S)
- [ ] **Micro-interactions**: hover and press states on word tiles, instant checker feedback (✅/❌ animation), skeleton or placeholder states, smooth scrolling for pagination. (M, S)
- [ ] **Tidy ad integration**: ads in clearly labelled, consistently styled slots between content cards, never between the H1 and the answer. Cluttered ad placement is the fastest way to look cheap. (H, S)
- [ ] **Per-word social share images** (Open Graph): a tile-style image of the word, so links shared on social and chat apps look polished. Start with one generic branded image, then generate per-word images in the CI build. (M, M)
- [ ] **Consistency pass**: use the same components on the home, browse, word, 404 and About pages. Check at 360 px, 768 px and 1280 px widths, in both light and dark mode. (M, S)

## P4 – Engagement and funnel into the puzzles

- [ ] **Call to action on every word page**: "Practice with TIGER → Play Wordle Unlimited", plus links to Decordle, Pentordle and Word Gridle. If the puzzle supports a seeded word, deep-link to a game that uses this word. (H, S–M)
- [ ] **Wordle helper/solver tool**: enter green, yellow and grey letters to filter candidates, with every result linking to its word page. (H, L)
- [ ] **Small interactive extras**: "Copy word", a share button, and a "Random word" link (both pageviews and crawl paths). (L, S)
- [ ] Optional daily "Today's Wordle hint" page. Demand is very high but the query is dominated by large publishers, so do this only after P1–P2 show traction. (M, M)

## P5 – Maintenance and tooling

- [x] Rewrote `generate_word_pages.rb`: stores structured definitions, retries API errors (429/5xx), records real "not found" results separately, and never deletes pages. `scripts/build_pages.rb` builds everything else from local data. (M, M)
- [ ] **Build speed** (measured 2026-11-03). The full build takes **~142 s** on Jekyll 3.10. All of it is rendering 14,855 pages: word layout ~65 s, default layout ~50 s, read/write ~2.3 ms/page. Benchmarks on 3,000 pages (CPU time):

  | Change | Build | Saving |
  |---|---|---|
  | Baseline (Jekyll 3.10, `github-pages` gem) | 40.3 s | – |
  | Replace `{% seo %}` with a hand-written meta include | 35.1 s | −13% |
  | + `{% include_cached %}` for header, footer, tracking, play buttons (`jekyll-include-cache`, allowed on GitHub Pages) | 32.1 s | −8% |
  | + precompute `relative_url`/`absolute_url` once per page instead of per link | 29.8 s | −7% |
  | + **Jekyll 4.3** (same templates, identical HTML) | **9.2 s** | **−69%** |
  | Ruby GC tuning env vars | no change | – |
  | YJIT | n/a: Debian's Ruby is built without it | – |

  - [ ] Template optimisations (the first three rows): about −26% on Jekyll 3. They work with the current GitHub Pages builder. (H, S)
  - [ ] `_config_dev.yml` for `jekyll serve`: `exclude: ["word/[b-z]*.md", …]`, so only the ~870 A-words are built. Jekyll 3.10 accepts the glob. Local rebuild drops to ~10 s, or ~3 s on Jekyll 4. Note that it replaces the main `exclude` list, so it must repeat those entries. (H, S)
  - [ ] Move to a **GitHub Actions** Pages build with Jekyll 4.3 (`actions/jekyll-build-pages` is Jekyll 3; use `ruby/setup-ruby` + `bundle exec jekyll build` + `actions/deploy-pages`). This enables Jekyll 4, any plugin (e.g. data-page generation instead of 15k `.md` files), and a scheduled job that runs `update_past_answers.rb` + `build_pages.rb`. Requires switching the repo's Pages source to "GitHub Actions". (H, M)
- [x] Word list verified against the current NYT accepted list on 2026-11-03: exactly 14,855 words, all with a page. Re-check periodically with `ruby scripts/validate_words.rb <reference-list.txt>`. (M, S)
- [ ] Replace or complement Ahrefs analytics with an analytics tool that records in-page events (checker use and puzzle click-through). (M, S)

---

## Success checkpoint (about 12 weeks after the P0 + P1 deploy)

Review Search Console filtered on queries containing `wordle word`:

- **Continue investing** (P2–P4) if impressions are growing week over week and word pages are indexed (more than 50% of the sitemap).
- **Rethink** if pages show "Crawled – currently not indexed" in bulk. That points to a perceived thin/duplicate-content problem, so deepen the per-word content before adding any more pages.
