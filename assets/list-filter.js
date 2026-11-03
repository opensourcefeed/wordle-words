// Sticky "find a word on this page" filter for the word-list hub pages.
//
// Typing letters hides the words on the page that don't start with them (and
// any heading or section left empty). Submitting a 5-letter word, or a prefix
// that matches exactly one word, opens that word's page.
(function () {
  const form = document.querySelector('form[data-list-filter]');
  if (!form) return;

  const input = form.querySelector('input');
  const status = form.parentElement.querySelector('.filter-status');
  const items = Array.from(document.querySelectorAll('.word-grid li, .answers tbody tr')).map(el => {
    const a = el.querySelector('a');
    return { el, word: a ? a.textContent.trim().toLowerCase() : '' };
  });
  const groups = Array.from(document.querySelectorAll('.word-grid, .answers'));
  const sections = Array.from(document.querySelectorAll('.hub section')).filter(s => s.querySelector('.word-grid, .answers'));
  let matches = [];

  function apply() {
    const q = input.value.trim().toLowerCase().replace(/[^a-z]/g, '');
    matches = [];
    for (const it of items) {
      const show = !q || it.word.startsWith(q);
      it.el.hidden = !show;
      if (show && q) matches.push(it.word);
    }
    for (const g of groups) {
      const empty = !!q && !g.querySelector('li:not([hidden]), tbody tr:not([hidden])');
      g.hidden = empty;
      const h = g.previousElementSibling;
      if (h && h.tagName === 'H3') h.hidden = empty;
    }
    for (const s of sections) s.hidden = !!q && !s.querySelector('.word-grid:not([hidden]), .answers:not([hidden])');

    const unique = new Set(matches).size;
    status.textContent = !q ? '' : unique
      ? unique.toLocaleString() + ' word' + (unique === 1 ? '' : 's') + ' on this page start' + (unique === 1 ? 's' : '') + ' with ' + q.toUpperCase() + '.'
      : 'No words on this page start with ' + q.toUpperCase() + '.' + (q.length === 5 ? ' Press Go to check ' + q.toUpperCase() + '.' : '');
    return q;
  }

  input.addEventListener('input', apply);
  form.addEventListener('submit', e => {
    e.preventDefault();
    const q = apply();
    const unique = Array.from(new Set(matches));
    const target = q.length === 5 ? q : unique.length === 1 ? unique[0] : null;
    if (target) location.href = form.dataset.base + target;
  });
})();
