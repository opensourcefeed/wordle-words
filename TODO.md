# Wordle Words – Prioritized TODO

Goal: rank and get clicks for queries like **"is TIGER a wordle word"**, then send those visitors on to the
opensourcefeed.org puzzles (Wordle Unlimited, Decordle, Pentordle, Word Gridle).

Legend: **Impact** H/M/L · **Effort** S (< ½ day) / M (1–2 days) / L (3+ days)

---

## P0 – Blockers (do these before anything else)

The live site still runs the January 2025 commit. Every word page says only *"This page is about the word: tiger"*.
None of the local work has shipped, and the current local config would break the site if it were deployed as-is.

- [ ] **Fix `_config.yml`** (Impact H, Effort S)
  - `url: https://www.opensourcefeed.org` and `baseurl: /wordle-words`. Right now `baseurl: /` builds `/assets/style.css`, which returns 404 on the live domain.
  - Remove the duplicate `url`, `domain` and `plugins` keys. The second `plugins:` block silently overrides the first.
  - `plugins: [jekyll-sitemap, jekyll-seo-tag]` (both are allowed on GitHub Pages).
  - `exclude: [generate_word_pages.rb, processed_words.yml, Gemfile, Gemfile.lock, TODO.md, .ruby-lsp]`. The generator script is currently published in `_site/`.
- [ ] **Replace hard-coded `href="/"` with `{{ '/' | relative_url }}`** in `_includes/header.html` and `_layouts/word.html`. Today "Back to All Words" goes to the opensourcefeed.org homepage. (H, S)
- [ ] **Do NOT delete the 5,727 "skipped" word pages** (the uncommitted `D word/*.md`). They are live URLs today, and the home page links to all 14,855 words, so deleting them creates thousands of internal 404s. Generate a page for **every** word in `_data/wordle-words.yml`. A definition is optional, because the Wordle data from P1 carries the page. (H, M)
- [ ] **Deploy, then verify in production**: CSS loads, `/wordle-words/sitemap.xml` returns 200 (it returns 404 today), and the canonical URLs are correct. (H, S)
- [ ] **Google Search Console**: add the property and submit `https://www.opensourcefeed.org/wordle-words/sitemap.xml`. Also add a `Sitemap:` line for it in the main site's `robots.txt`. (H, S)
- [ ] **Trust and compliance pages** (H, S)
  - Replace the boilerplate `about.markdown` (it still has the Minima/Jekyll placeholder text).
  - Add a Privacy Policy page. AdSense requires one.
  - Add a Google-certified consent banner (CMP) for EEA/UK traffic. AdSense requires this for those regions.
  - Add an attribution line for the definitions: dictionaryapi.dev serves Wiktionary content under **CC BY-SA**.
  - Make the footer brand consistent ("Tahrik Studio" vs OpenSourceFeed).
- [ ] **Offensive words**: about 3+ slurs and profanities are in the list. Flag them in data: no ads, `noindex`, and no example sentences. This protects AdSense standing. (M, S)

## P1 – Answer the search intent better than competitors

Searchers want three facts: (1) Is it an accepted guess? (2) Can it be a daily answer? (3) Has it already been an answer, and when?
Competitors such as fiveletterwords.io already show all three. A bare "Yes, it's a candidate" will not win.

- [ ] **Page title and meta, built from the query wording** (H, S)
  - `<title>Is TIGER a Wordle Word? Yes – Valid Guess, Answer History & Meaning</title>`
  - Meta description with the direct answer in the first 150 chars.
  - `<h1>Is TIGER a Wordle word?</h1>`, followed immediately by a one-line answer box (✅ Valid guess · ✅/❌ Possible answer · 📅 Past answer #NNN on DATE).
  - Add `jekyll-seo-tag` for canonical, Open Graph and Twitter tags.
- [ ] **Add Wordle status data** (H, M)
  - Split the list into *answer pool* (about 2.3k) and *allowed guesses only*.
  - Add a `past_answers.yml` file (date, puzzle #, word). Make the update scriptable.
  - Show the answer rules in plain language, for example "Plurals ending in S and past-tense -ED words are almost never answers."
- [ ] **Compute unique per-word content** (offline in the generator, no API needed) (H, M). This turns 15k templated pages into pages that are useful, which also lowers the risk under Google's "scaled content" policy.
  - Vowel and consonant breakdown, repeated letters, a letter-frequency score, and a starter-word rating with a short reason.
  - **Neighbours**: words one letter different (TIGER → TILER, TIMER, TIDER…). These double as internal links.
  - Anagrams, plus "same pattern" words (`_IGER`), with a hard-mode trap warning when there are many.
- [ ] **Clean up definitions**: show at most 3 short senses, drop the "Meaning 1 / Definition 1" labels, and use `<ol>`/`<dl>`. Keep the phonetic and part of speech. (M, S)
- [ ] **Structured data**: `BreadcrumbList` plus `DefinedTerm`/`WebPage` JSON-LD on word pages, and `WebSite` with `SearchAction` on home. (M, S)
- [ ] **"No" answers**: the 404 page should run a JS lookup on the requested word and say *"XYZZY is not a valid Wordle word"*, then suggest close valid words. Also consider static pages for frequently searched invalid words (4- and 6-letter words, proper nouns), once Search Console shows that demand exists. (M, M)

## P2 – Crawlability, internal linking and hub pages

The home page's word list is built entirely by JavaScript from 120 KB of inline JSON, so word pages are close to orphaned for crawlers.

- [ ] **Static browse pages in the HTML**: `/letter/a/` … `/letter/z/` with real `<a>` links. Paginate when a page would have more than about 500 links. (H, M)
- [ ] **"5 letter words starting with / ending with / containing X" hub pages**: these are high-volume queries that fit this dataset exactly. Start with the 26 starting letters and the top 2-letter prefixes and suffixes, then expand based on Search Console data. (H, M)
- [ ] **Word page links**: breadcrumb (Home › T › TIGER), the neighbour and anagram blocks, previous/next alphabetical word, and a link to the starting-letter hub. (H, S)
- [ ] **Hub pages for answers**: "All past Wordle answers" (by date and A–Z) and "Possible Wordle answers". (M, M)
- [ ] **Rework the home page**: put a real H1 and a **word checker** box above the fold (type a word, get an instant ✅/❌ plus a link). Move the ad below the checker. Remove the duplicate `class` attributes on the pagination divs. (M, S)

## P3 – User experience, device friendliness and speed

- [ ] Drop the full Bootstrap CDN (about 230 KB of CSS for a navbar and buttons). Write about 3 KB of custom CSS instead, and inline the critical CSS. (M, S)
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

- [ ] Rewrite `generate_word_pages.rb` so that it:
  - Builds from local data (status, stats, neighbours).
  - Stores definitions as structured YAML instead of escaped HTML.
  - Never overwrites or deletes existing URLs.
  - Uses rate-limit and retry for the API.
  (M, M)
- [ ] Consider a GitHub Actions build (custom plugins become possible, for example data-page generation instead of 15k `.md` files), plus a scheduled job that appends each day's answer. (M, M)
- [ ] Refresh the word list against the current NYT accepted list. NYT has added words since the original 14,855. (M, S)
- [ ] Replace or complement Ahrefs analytics with an analytics tool that records in-page events (checker use and puzzle click-through). (M, S)

---

## Success checkpoint (about 12 weeks after the P0 + P1 deploy)

Review Search Console filtered on queries containing `wordle word`:

- **Continue investing** (P2–P4) if impressions are growing week over week and word pages are indexed (more than 50% of the sitemap).
- **Rethink** if pages show "Crawled – currently not indexed" in bulk. That points to a perceived thin/duplicate-content problem, so deepen the per-word content before adding any more pages.
