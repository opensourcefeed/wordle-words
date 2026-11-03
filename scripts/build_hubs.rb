# Generates static hub pages with real <a> links so every word page is reachable
# by crawlers without JavaScript:
#
#   /browse/                      index of all hubs
#   /starting-with/a/ … /z/       all words by first letter
#   /starting-with/st/            two-letter prefixes (HubRules::MIN_WORDS+ words)
#   /ending-with/e/, /ending-with/er/
#   /containing/q/
#   /past-answers/, /past-answers/a-z/, /possible-answers/
#
# Generated files live in starting-with/, ending-with/, containing/,
# past-answers/ and browse.html / possible-answers.html. They are rebuilt from
# scratch on every run, so don't edit them by hand.
#
# Usage: ruby scripts/build_hubs.rb

require 'yaml'
require 'date'
require 'fileutils'
require_relative 'hub_rules'

LIST_LIMIT = 2000 # above this, "other valid guesses" are only linked via smaller hubs
LETTERS = ('a'..'z').to_a

config    = YAML.load_file('_config.yml')
BASE      = config['baseurl'].to_s.chomp('/')
all_words = YAML.load_file('_data/wordle-words.yml')['wordle-words'].map(&:to_s)
sensitive = YAML.load_file('_data/sensitive-words.yml')['sensitive-words'].map(&:to_s).to_set
originals = YAML.load_file('_data/original-answers.yml')['original-answers'].map(&:to_s).to_set
today     = Date.today.iso8601
past_list = YAML.load_file('_data/past-answers.yml')['past-answers'].select { |a| a['date'] < today }
PAST      = past_list.group_by { |a| a['word'] }
WORDS     = all_words.reject { |w| sensitive.include?(w) }.sort # never link to sensitive pages
POSSIBLE  = originals.reject { |w| PAST.key?(w) || sensitive.include?(w) }.to_set
PREFIXES  = HubRules.prefixes(all_words)
SUFFIXES  = HubRules.suffixes(all_words)

def n(num) = num.to_s.reverse.scan(/\d{1,3}/).join(',').reverse
def url(path) = "#{BASE}#{path}"
def word_link(w) = %(<a href="#{url("/word/#{w}")}">#{w.upcase}</a>)
def hub_link(path, label) = %(<a href="#{url(path)}">#{label}</a>)

def grid(words, numbers: false)
  items = words.map do |w|
    nums = numbers ? PAST[w].map { |a| "##{a['number']}" }.join(' ') : nil
    "<li>#{word_link(w)}#{nums ? %(<small>#{nums}</small>) : ''}</li>"
  end
  %(<ul class="word-grid">#{items.join}</ul>)
end

def links(pairs) = %(<ul class="hub-links">#{pairs.map { |path, label| "<li>#{hub_link(path, label)}</li>" }.join}</ul>)

def ad
  <<~HTML
    <div class="ad-slot">{% include ad.html %}</div>
  HTML
end

$written = []
# filter: show the sticky "find a word on this page" bar (pages that list words).
def write_page(path, permalink:, title:, short:, description:, crumbs:, body:, filter: true)
  FileUtils.mkdir_p(File.dirname(path))
  fm = { 'layout' => 'hub', 'title' => title, 'short' => short, 'description' => description,
         'permalink' => permalink, 'crumbs' => crumbs }
  fm['filter'] = true if filter
  File.write(path, "#{fm.to_yaml}---\n#{body}")
  $written << path
end

BROWSE = { 'name' => 'Browse', 'url' => '/browse/' }.freeze

# A word-list hub: past answers, possible answers, then other valid guesses.
def word_hub(path:, permalink:, title:, short:, phrase:, words:, crumbs:, related:, other_groups: nil, other_fallback: nil)
  past = words.select { |w| PAST.key?(w) }
  possible = words.select { |w| POSSIBLE.include?(w) }
  other = words - past - possible
  total = words.size

  intro = +"<p class=\"lead\">There #{total == 1 ? 'is' : 'are'} <strong>#{n(total)}</strong> five-letter " \
           "word#{total == 1 ? '' : 's'} #{phrase} that Wordle accepts."
  intro << " #{n(past.size)} #{past.size == 1 ? 'has' : 'have'} been the Wordle answer" if past.any?
  intro << (past.any? ? ', and ' : ' ') << "#{n(possible.size)} more could be future answers" if possible.any?
  intro << '.' if past.any? || possible.any?
  intro << " The other #{n(other.size)} are valid guesses that are unlikely to be the answer." if other.any?
  intro << '</p>'

  body = +intro
  body << ad
  body << %(<section><h2>Past Wordle answers #{phrase} (#{n(past.size)})</h2>#{grid(past, numbers: true)}</section>) if past.any?
  if possible.any?
    body << %(<section><h2>Possible future answers (#{n(possible.size)})</h2>) +
            %(<p class="note">Words on the original Wordle answer list that haven't been used yet.</p>#{grid(possible)}</section>)
  end
  if other.any?
    body << %(<section><h2>Other valid guesses (#{n(other.size)})</h2>)
    if other_groups
      other.group_by(&other_groups[:key]).sort.each do |key, list|
        label = key.upcase
        heading = other_groups[:hubs].include?(key) ? hub_link(other_groups[:url].call(key), label) : label
        body << %(<h3>#{heading} <small>(#{n(list.size)})</small></h3>#{grid(list)})
      end
    elsif other.size <= LIST_LIMIT
      body << grid(other)
    else
      body << %(<p>That's too many to list on one page. #{other_fallback}</p>)
    end
    body << '</section>'
  end
  body << %(<section><h2>More word lists</h2>#{links(related)}</section>) if related.any?

  description = "All #{n(total)} five-letter Wordle words #{phrase}" \
                "#{past.any? ? ", including #{n(past.size)} past answers" : ''}. Find your next guess and check which could be the answer."
  write_page(path, permalink: permalink, title: title, short: short, description: description, crumbs: crumbs, body: body)
end

# Generated folders are fully owned by this script.
%w[starting-with ending-with containing past-answers].each { |d| FileUtils.rm_rf(d) }

# ---------------------------------------------------------------- starting with
LETTERS.each do |l|
  words = WORDS.select { |w| w.start_with?(l) }
  prefixes = PREFIXES.select { |p| p.start_with?(l) }.sort
  word_hub(path: "starting-with/#{l}.html", permalink: HubRules.start_url(l),
           title: "5 Letter Words Starting with #{l.upcase}", short: l.upcase,
           phrase: "starting with #{l.upcase}", words: words, crumbs: [BROWSE],
           other_groups: { key: ->(w) { w[0, 2] }, hubs: PREFIXES, url: ->(k) { HubRules.start_url(k) } },
           related: prefixes.map { |p| [HubRules.start_url(p), "Starting with #{p.upcase}"] } +
                    [[HubRules.end_url(l), "Ending with #{l.upcase}"], [HubRules.contain_url(l), "Containing #{l.upcase}"]])
end

PREFIXES.sort.each do |p|
  words = WORDS.select { |w| w.start_with?(p) }
  siblings = PREFIXES.select { |x| x[0] == p[0] && x != p }.sort
  word_hub(path: "starting-with/#{p}.html", permalink: HubRules.start_url(p),
           title: "5 Letter Words Starting with #{p.upcase}", short: p.upcase,
           phrase: "starting with #{p.upcase}", words: words,
           crumbs: [BROWSE, { 'name' => "Starting with #{p[0].upcase}", 'url' => HubRules.start_url(p[0]) }],
           related: siblings.map { |x| [HubRules.start_url(x), "Starting with #{x.upcase}"] })
end

# ---------------------------------------------------------------- ending with
LETTERS.each do |l|
  words = WORDS.select { |w| w.end_with?(l) }
  next if words.empty?

  suffixes = SUFFIXES.select { |s| s.end_with?(l) }.sort
  fallback = suffixes.any? ? "Narrow it down: #{suffixes.map { |s| hub_link(HubRules.end_url(s), "-#{s.upcase}") }.join(', ')}." : ''
  word_hub(path: "ending-with/#{l}.html", permalink: HubRules.end_url(l),
           title: "5 Letter Words Ending in #{l.upcase}", short: l.upcase,
           phrase: "ending in #{l.upcase}", words: words, crumbs: [BROWSE], other_fallback: fallback,
           related: suffixes.map { |s| [HubRules.end_url(s), "Ending in #{s.upcase}"] } +
                    [[HubRules.start_url(l), "Starting with #{l.upcase}"], [HubRules.contain_url(l), "Containing #{l.upcase}"]])
end

SUFFIXES.sort.each do |s|
  words = WORDS.select { |w| w.end_with?(s) }
  siblings = SUFFIXES.select { |x| x[1] == s[1] && x != s }.sort
  word_hub(path: "ending-with/#{s}.html", permalink: HubRules.end_url(s),
           title: "5 Letter Words Ending in #{s.upcase}", short: s.upcase,
           phrase: "ending in #{s.upcase}", words: words,
           crumbs: [BROWSE, { 'name' => "Ending in #{s[1].upcase}", 'url' => HubRules.end_url(s[1]) }],
           related: siblings.map { |x| [HubRules.end_url(x), "Ending in #{x.upcase}"] })
end

# ---------------------------------------------------------------- containing
LETTERS.each do |l|
  words = WORDS.select { |w| w.include?(l) }
  fallback = "Narrow it down by #{hub_link(HubRules.start_url(l), "words starting with #{l.upcase}")} or " \
             "#{hub_link(HubRules.end_url(l), "ending in #{l.upcase}")}."
  word_hub(path: "containing/#{l}.html", permalink: HubRules.contain_url(l),
           title: "5 Letter Words with #{l.upcase}", short: "With #{l.upcase}",
           phrase: "containing #{l.upcase}", words: words, crumbs: [BROWSE], other_fallback: fallback,
           related: (LETTERS - [l]).map { |x| [HubRules.contain_url(x), "Containing #{x.upcase}"] })
end

# ---------------------------------------------------------------- answers
last = past_list.last
repeats = past_list.group_by { |a| a['word'] }.count { |_, l| l.size > 1 }
rows = past_list.reverse.map do |a|
  %(<tr><td>#{Date.parse(a['date']).strftime('%b %-d, %Y')}</td><td>##{a['number']}</td><td>#{word_link(a['word'])}</td></tr>)
end
body = +%(<p class="lead">Every Wordle answer from the first puzzle on June 19, 2021 to ) +
       %(#{Date.parse(last['date']).strftime('%B %-d, %Y')} (##{last['number']}): #{n(past_list.size)} puzzles.) +
       %( Since February 2026 Wordle has reused some answers; #{repeats} words have now been the answer twice.</p>) +
       %(<p class="note">Today's answer is never listed, so this page won't spoil today's puzzle. ) +
       %(See the #{hub_link('/past-answers/a-z/', 'alphabetical list')} or the #{hub_link('/possible-answers/', 'possible future answers')}.</p>)
body << ad
body << %(<table class="answers"><thead><tr><th>Date</th><th>Puzzle</th><th>Answer</th></tr></thead><tbody>#{rows.join}</tbody></table>)
write_page('past-answers/index.html', permalink: '/past-answers/', title: 'All Past Wordle Answers',
           short: 'Past answers', crumbs: [BROWSE], body: body,
           description: "All #{n(past_list.size)} past Wordle answers by date, from #0 to ##{last['number']}, with no spoilers for today's puzzle.")

answer_words = PAST.keys.sort
body = +%(<p class="lead">All #{n(answer_words.size)} different words that have been the Wordle answer, A to Z, ) +
       %(with their puzzle numbers. For dates, see #{hub_link('/past-answers/', 'past answers by date')}.</p>)
body << ad
answer_words.group_by { |w| w[0] }.each do |l, list|
  body << %(<section><h2>#{l.upcase} <small>(#{list.size})</small></h2>#{grid(list, numbers: true)}</section>)
end
write_page('past-answers/a-z.html', permalink: '/past-answers/a-z/', title: 'Past Wordle Answers A to Z',
           short: 'A to Z', crumbs: [BROWSE, { 'name' => 'Past answers', 'url' => '/past-answers/' }], body: body,
           description: "Alphabetical list of all #{n(answer_words.size)} words that have been the Wordle answer, with puzzle numbers.")

possible = POSSIBLE.to_a.sort
body = +%(<p class="lead">#{n(possible.size)} words from the original Wordle answer list haven't been the answer yet. ) +
       %(They are the most likely future answers. The New York Times also chooses some answers that aren't on this list, ) +
       %(and since February 2026 it sometimes reuses #{hub_link('/past-answers/', 'past answers')}.</p>)
body << ad
possible.group_by { |w| w[0] }.each do |l, list|
  body << %(<section><h2>#{l.upcase} <small>(#{list.size})</small></h2>#{grid(list)}</section>)
end
write_page('possible-answers.html', permalink: '/possible-answers/', title: 'Possible Future Wordle Answers',
           short: 'Possible answers', crumbs: [BROWSE], body: body,
           description: "The #{n(possible.size)} words from the original Wordle answer list that haven't been used yet: the most likely future answers.")

# ---------------------------------------------------------------- browse index
letter_links = ->(fmt) { LETTERS.map { |l| [fmt.call(l), l.upcase] } }
body = +%(<p class="lead">Browse all #{n(all_words.size)} five-letter words that Wordle accepts, by letter, ) +
       %(or see the #{hub_link('/past-answers/', 'past answers')}, #{hub_link('/possible-answers/', 'possible future answers')} and #{hub_link('/not-in-word-list/', 'common words Wordle does not accept')}.</p>)
body << %(<section><h2>Words starting with</h2>#{links(letter_links.call(->(l) { HubRules.start_url(l) })).sub('hub-links', 'hub-links letters')}</section>)
body << %(<section><h2>Words ending in</h2>#{links(LETTERS.select { |l| WORDS.any? { |w| w.end_with?(l) } }.map { |l| [HubRules.end_url(l), l.upcase] }).sub('hub-links', 'hub-links letters')}</section>)
body << %(<section><h2>Words containing</h2>#{links(letter_links.call(->(l) { HubRules.contain_url(l) })).sub('hub-links', 'hub-links letters')}</section>)
body << %(<section><h2>Starting with two letters</h2>#{links(PREFIXES.sort.map { |p| [HubRules.start_url(p), p.upcase] }).sub('hub-links', 'hub-links letters')}</section>)
body << %(<section><h2>Ending in two letters</h2>#{links(SUFFIXES.sort.map { |s| [HubRules.end_url(s), "-#{s.upcase}"] }).sub('hub-links', 'hub-links letters')}</section>)
write_page('browse.html', permalink: '/browse/', title: 'Browse All Wordle Words', short: 'Browse', crumbs: [], filter: false,
           description: "Browse all #{n(all_words.size)} valid Wordle words by first letter, last letter, letters they contain, and past answers.",
           body: body)

puts "#{$written.size} hub pages written."
