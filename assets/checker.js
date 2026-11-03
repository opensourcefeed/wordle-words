// Wordle word checker, shared by the home page and the 404 page.
//
// Markup: <form data-checker data-words="…/words.json" data-base="…/word/"
//               [data-live] [data-from-path]> with an <input>, plus elements
// #checker-title (optional), #checker-result and #checker-suggest.
//   data-live       show matching words while typing
//   data-from-path  check the word in the URL (/word/xyzzq) on load
(function () {
  const form = document.querySelector('form[data-checker]');
  if (!form) return;

  const input = form.querySelector('input');
  const title = document.getElementById('checker-title');
  const result = document.getElementById('checker-result');
  const suggest = document.getElementById('checker-suggest');
  const base = form.dataset.base;
  const esc = s => s.replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const link = w => '<li><a href="' + base + w + '">' + w.toUpperCase() + '</a></li>';
  const chips = list => '<ul class="word-chips">' + list.map(link).join('') + '</ul>';
  let words = null;

  function load() {
    if (!words) {
      words = fetch(form.dataset.words)
        .then(r => r.json())
        .then(list => { const all = list.map(String); return { all, set: new Set(all) }; });
    }
    return words;
  }

  // Valid words that differ from `w` by exactly one letter.
  function neighbours(w, set) {
    const out = [];
    for (let i = 0; i < 5; i++) {
      for (const c of 'abcdefghijklmnopqrstuvwxyz') {
        const n = w.slice(0, i) + c + w.slice(i + 1);
        if (n !== w && set.has(n)) out.push(n);
      }
    }
    return out.slice(0, 12);
  }

  // Result styling: a placeholder while the word list loads, then a ✓ or ✕.
  const mark = state => {
    result.classList.remove('is-yes', 'is-no', 'is-loading');
    if (state) { void result.offsetWidth; result.classList.add('is-' + state); } // restart the animation
  };

  function check(raw) {
    const w = raw.trim().toLowerCase();
    if (!w) return;
    const slow = setTimeout(() => mark('loading'), 80); // only if the list isn't ready yet
    load().then(({ set }) => {
      clearTimeout(slow);
      const W = esc(w.toUpperCase());
      suggest.innerHTML = '';
      mark(set.has(w) ? 'yes' : 'no');
      if (set.has(w)) {
        if (title) title.textContent = 'Yes, ' + w.toUpperCase() + ' is a Wordle word';
        result.innerHTML = '<strong>Yes.</strong> ' + W + ' is a valid Wordle word. ' +
          '<a href="' + base + w + '">See if it has been the answer, and what it means &rarr;</a>';
        return;
      }
      if (title) title.textContent = 'Is ' + w.toUpperCase() + ' a Wordle word?';
      if (!/^[a-z]+$/.test(w)) {
        result.innerHTML = '<strong>No.</strong> Wordle words use only the letters A to Z.';
      } else if (w.length !== 5) {
        result.innerHTML = '<strong>No.</strong> ' + W + ' has ' + w.length + ' letter' + (w.length === 1 ? '' : 's') +
          ', and Wordle only accepts 5-letter words.';
      } else {
        result.innerHTML = '<strong>No.</strong> ' + W + ' is not in the list of words Wordle accepts.';
        const near = neighbours(w, set);
        if (near.length) suggest.innerHTML = '<p>Valid words one letter away:</p>' + chips(near);
      }
    });
  }

  // While typing: list words that start with the letters so far.
  function live() {
    const q = input.value.trim().toLowerCase();
    if (!/^[a-z]{1,4}$/.test(q)) {
      if (q.length === 5) check(q); else { mark(); result.innerHTML = ''; suggest.innerHTML = ''; }
      return;
    }
    load().then(({ all }) => {
      if (input.value.trim().toLowerCase() !== q) return; // a newer keystroke won
      mark();
      const matches = all.filter(w => w.startsWith(q));
      result.innerHTML = matches.length.toLocaleString() + ' valid word' + (matches.length === 1 ? '' : 's') +
        ' start with ' + esc(q.toUpperCase()) + '. Keep typing, or pick one:';
      suggest.innerHTML = chips(matches.slice(0, 30));
    });
  }

  form.addEventListener('submit', e => { e.preventDefault(); check(input.value); });
  if (form.hasAttribute('data-live')) input.addEventListener('input', live);
  input.addEventListener('focus', load, { once: true }); // start downloading early

  if (form.hasAttribute('data-from-path')) {
    const m = location.pathname.match(/\/word\/([^/]+?)(?:\.html)?\/?$/);
    if (m) {
      let w = m[1];
      try { w = decodeURIComponent(w); } catch (e) { /* keep raw */ }
      input.value = w;
      check(w);
    }
  }
})();
