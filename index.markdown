---
layout: default
title: Home
---
<script>
  const words = {{ site.data.wordle-words.wordle-words | jsonify }};
</script>

<div class="intro">
<h2>All Wordle Words</h2>
<hr>
<p><strong>Enhance</strong> your Wordle skill with this comprehensive list of all possible 5-letter words.</p> 

<p>Easily search for any word you're stuck on or simply browse the complete list. Click on any word to instantly reveal its definition and enhance your Wordle gameplay. Find the perfect word to conquer that elusive daily challenge.</p>
</div>

<script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-6380671811722843"
     crossorigin="anonymous"></script>
<!-- Wordle Words - Home -->
<ins class="adsbygoogle"
     style="display:block"
     data-ad-client="ca-pub-6380671811722843"
     data-ad-slot="6641359186"
     data-ad-format="auto"
     data-full-width-responsive="true"></ins>
<script>
     (adsbygoogle = window.adsbygoogle || []).push({});
</script>

<br><br>

{% include playButtons.html %}

<input placeholder="Search for words" type="text" class="form-control" id="search-word">
<div class="words">
  <div id="pagination" class="pagination" class="pagination-controls"></div>
  <div id="word-list" class="word-list"></div>
  <div class="pagination" class="pagination-controls"></div>
</div>
<script src="{{ '/assets/home.js' | relative_url }}"></script>