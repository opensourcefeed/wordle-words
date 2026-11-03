# Rebuilds the front matter of every word page from the project data:
#   _data/wordle-words.yml      all valid Wordle guesses
#   _data/original-answers.yml  the original 2,315-word answer list
#   _data/past-answers.yml      past answers (scripts/update_past_answers.rb)
#   _data/sensitive-words.yml   words that get no ads, noindex and no sitemap entry
#
# Valid guesses (not past or possible answers) with no definition also get
# noindex and no sitemap entry: they are too thin to be worth indexing.
#
# Definitions already on a page are kept. Older pages that store them as an
# HTML `meaning` string are converted to structured `phonetic` + `definitions`.
#
# Usage: bundle exec ruby scripts/build_pages.rb

require 'yaml'
require 'date'
require 'set'
require 'nokogiri'
require_relative 'hub_rules'

def load_list(file, key) = YAML.load_file(file)[key].map(&:to_s)

words      = load_list('_data/wordle-words.yml', 'wordle-words')
originals  = load_list('_data/original-answers.yml', 'original-answers').to_set
sensitive  = load_list('_data/sensitive-words.yml', 'sensitive-words').to_set
today      = Date.today.iso8601
past       = (YAML.load_file('_data/past-answers.yml')['past-answers'] || [])
             .select { |a| a['date'] < today } # never spoil today's puzzle
             .group_by { |a| a['word'] }
word_set   = words.to_set
prefixes   = HubRules.prefixes(words)
suffixes   = HubRules.suffixes(words)
linkable   = words.reject { |w| sensitive.include?(w) }.sort # for previous/next links
position   = linkable.each_with_index.to_h

# ---------------------------------------------------------------- word stats
# Share of original answers that contain each letter.
FREQ = Hash.new(0.0)
originals.each { |w| w.chars.uniq.each { |c| FREQ[c] += 1 } }
FREQ.transform_values! { |v| v / originals.size }

scores = words.to_h { |w| [w, w.chars.uniq.sum { |c| FREQ[c] }] }
ranked = words.sort_by { |w| -scores[w] }
rank   = ranked.each_with_index.to_h

def tier(percentile)
  case percentile
  when 0...2 then 'Excellent'
  when 2...10 then 'Good'
  when 10...40 then 'Average'
  else 'Weak'
  end
end

# Words that differ in exactly one position, grouped by pattern (e.g. "_iger").
patterns = Hash.new { |h, k| h[k] = [] }
words.each { |w| 5.times { |i| patterns[w.dup.tap { |x| x[i] = '_' }] << w } }
anagram_groups = words.group_by { |w| w.chars.sort.join }

# Common answer words first, then alphabetical; never link to sensitive pages.
def pick(list, word, originals, sensitive, limit)
  (list - [word]).reject { |w| sensitive.include?(w) }
                 .sort_by { |w| [originals.include?(w) ? 0 : 1, w] }
                 .first(limit)
end

# ---------------------------------------------------------------- definitions
def parse_meaning_html(html)
  doc = Nokogiri::HTML.fragment(html)
  phonetic = doc.at_css('p')&.text.to_s.sub(/\APhonetics:\s*/, '').strip
  phonetic = nil if phonetic.empty? || phonetic == 'N/A'
  definitions = doc.css('.meanings').map do |m|
    pos = m.css('p').find { |p| p.text.start_with?('Part of Speech:') }&.text.to_s.sub('Part of Speech:', '').strip
    defs = m.css('li').map do |li|
      example = li.at_css('p')&.text.to_s.sub(/\AExample:\s*/, '').strip
      li.css('p').each(&:remove)
      text = li.text.sub(/\ADefinition \d+:\s*/, '').strip
      { 'text' => text, 'example' => (example.empty? ? nil : example) }.compact
    end.reject { |d| d['text'].empty? }
    { 'pos' => pos, 'defs' => defs }
  end.reject { |d| d['defs'].empty? }
  [phonetic, definitions]
end

def human_date(iso) = Date.parse(iso).strftime('%B %-d, %Y')

# ---------------------------------------------------------------- build pages
updated = 0
words.each do |word|
  path = "word/#{word}.md"
  old = File.exist?(path) ? (YAML.safe_load(File.read(path)[/\A---\s*\n(.*?)\n---/m, 1].to_s) || {}) : {}
  phonetic, definitions = old['meaning'] ? parse_meaning_html(old['meaning']) : [old['phonetic'], old['definitions']]

  up = word.upcase
  answers = (past[word] || []).sort_by { |a| a['date'] }
  original = originals.include?(word)
  status = if answers.any? then 'past'
           elsif original then 'possible'
           else 'guess'
           end

  short = { 'past' => "Past Answer ##{answers.last&.dig('number')}", 'possible' => 'Possible Answer',
            'guess' => 'Valid Guess' }[status]
  head_title = "Is #{up} a Wordle Word? Yes – #{short}#{definitions&.any? ? ' & Meaning' : ''}"

  answer_text = case status
                when 'past'
                  dates = answers.map { |a| "#{human_date(a['date'])} (##{a['number']})" }.join(' and ')
                  "It was the Wordle answer on #{dates}."
                when 'possible'
                  'It is on the original Wordle answer list and has not been an answer yet, so it could be a future answer.'
                else
                  'It is not on the Wordle answer list, so it is unlikely to be a daily answer.'
                end
  description = "Yes, #{up} is a valid Wordle word. #{answer_text}" \
                " See its #{definitions&.any? ? 'meaning, ' : ''}starter rating and similar words."

  rule_note = if status == 'guess' && word.end_with?('ed')
                'Past-tense words ending in ED are almost never chosen as Wordle answers.'
              elsif status == 'guess' && word.end_with?('s') && !word.end_with?('ss')
                'Plurals ending in S are almost never chosen as Wordle answers.'
              end

  percentile = (rank[word] * 100.0 / words.size)
  letters = word.chars
  trap_pattern, trap_words = 5.times.map { |i| w = word.dup; w[i] = '_'; [w, patterns[w]] }.max_by { |_, l| l.size }

  fm = {
    'layout' => 'word',
    'title' => "Is #{up} a Wordle Word?",
    'head_title' => head_title,
    'word' => word,
    'description' => description,
  }
  if sensitive.include?(word)
    fm.merge!('sensitive' => true, 'sitemap' => false)
  elsif status == 'guess' && !definitions&.any?
    # Thin page: an obscure valid guess with no definition. Kept for visitors
    # and the checker, but kept out of Google's index and the sitemap.
    fm.merge!('noindex' => true, 'sitemap' => false)
  end
  fm['status'] = status
  fm['answer_text'] = answer_text
  fm['past_answers'] = answers.map { |a| { 'date' => a['date'], 'number' => a['number'] } } if answers.any?
  fm['rule_note'] = rule_note if rule_note
  # The NYT began reusing past answers in February 2026 (CIGAR returned on 2026-02-02).
  fm['repeat_note'] = 'Since February 2026, Wordle sometimes reuses past answers, so it could be the answer again.' if status == 'past'
  fm['stats'] = {
    'vowels' => letters.select { |c| 'aeiou'.include?(c) }.uniq.map(&:upcase),
    'unique_letters' => letters.uniq.size,
    'repeated' => letters.tally.select { |_, n| n > 1 }.keys.map(&:upcase),
    'common' => letters.uniq.select { |c| FREQ[c] >= 0.27 }.map(&:upcase),
    'rare' => letters.uniq.select { |c| FREQ[c] <= 0.06 }.map(&:upcase),
    'starter_tier' => tier(percentile),
    'starter_top_percent' => [percentile.ceil, 1].max,
  }
  fm['neighbours'] = pick(5.times.flat_map { |i| patterns[word.dup.tap { |x| x[i] = '_' }] }.uniq,
                          word, originals, sensitive, 12)
  fm['anagrams'] = pick(anagram_groups[word.chars.sort.join], word, originals, sensitive, 12)
  fm['trap'] = { 'pattern' => trap_pattern.upcase, 'count' => trap_words.size } if trap_words.size >= 6
  fm['phonetic'] = phonetic if phonetic
  fm['definitions'] = definitions if definitions&.any?
  if (i = position[word])
    fm['prev_word'] = linkable[i - 1] if i.positive?
    fm['next_word'] = linkable[i + 1] if linkable[i + 1]
  end
  hubs = [[HubRules.start_url(word[0]), "Starting with #{word[0].upcase}"]]
  hubs << [HubRules.start_url(word[0, 2]), "Starting with #{word[0, 2].upcase}"] if prefixes.include?(word[0, 2])
  hubs << [HubRules.end_url(word[3, 2]), "Ending in #{word[3, 2].upcase}"] if suffixes.include?(word[3, 2])
  hubs << [HubRules.end_url(word[-1]), "Ending in #{word[-1].upcase}"]
  fm['hubs'] = hubs.map { |url, label| { 'url' => url, 'label' => label } }
  fm.delete('neighbours') if fm['neighbours'].empty?
  fm.delete('anagrams') if fm['anagrams'].empty?

  content = "#{fm.to_yaml}---\n"
  next if File.exist?(path) && File.read(path) == content

  File.write(path, content)
  updated += 1
end

stale = Dir.glob('word/*.md').reject { |p| word_set.include?(File.basename(p, '.md')) }
warn "Pages for words not in the list (delete them): #{stale.join(', ')}" unless stale.empty?
puts "#{words.size} words, #{updated} page(s) written, #{past.size} past answers used."
