# Extracts English definitions for a list of words from the kaikki.org
# Wiktionary dump (JSON Lines, CC BY-SA), streamed on STDIN so the 3+ GB file
# is never stored:
#
#   curl -sL https://kaikki.org/dictionary/English/kaikki.org-dictionary-English.jsonl.gz \
#     | gunzip | ruby scripts/extract_kaikki.rb targets.txt > definitions.json
#
# targets.txt: one lowercase word per line. Output: JSON object
#   { word => { "phonetic" => "/…/", "definitions" => [{ "pos", "defs" => [{ "text", "example" }] }] } }
# in the same shape as the word pages' front matter.

require 'json'
require 'set'

MAX_DEFS_PER_POS = 8
POS_NAMES = { 'adj' => 'adjective', 'adv' => 'adverb', 'intj' => 'interjection', 'prep' => 'preposition',
              'conj' => 'conjunction', 'pron' => 'pronoun', 'det' => 'determiner', 'num' => 'numeral' }.freeze
SKIP_POS = %w[name proper-noun character symbol phrase prefix suffix affix infix].to_set
SKIP_TAGS = %w[misspelling].to_set

# --any-length: targets may be any length (used for a second pass that looks up
# the base words of "plural of …" / "past tense of …" entries).
ANY_LENGTH = ARGV.delete('--any-length')
WORD_RE = ANY_LENGTH ? /"word": "([a-z][a-z-]*)"/ : /"word": "([a-z]{5})"/

targets = File.readlines(ARGV[0], chomp: true).map(&:strip).reject(&:empty?).to_set
found = Hash.new { |h, k| h[k] = { 'phonetic' => nil, 'pos' => {} } }
lines = 0

STDIN.each_line do |line|
  lines += 1
  $stderr.print "\r#{lines / 1000}k lines, #{found.size} words found" if (lines % 50_000).zero?
  next unless line.scan(WORD_RE).any? { |(w)| targets.include?(w) }

  e = JSON.parse(line)
  word = e['word']
  next unless targets.include?(word) && e['lang_code'] == 'en'
  next if SKIP_POS.include?(e['pos'])

  pos = POS_NAMES.fetch(e['pos'], e['pos'])
  defs = (e['senses'] || []).filter_map do |s|
    next if (s['tags'] || []).any? { |t| SKIP_TAGS.include?(t) }
    text = s['glosses']&.last.to_s.strip
    next if text.empty?
    ex = s['examples']&.map { |x| x['text'].to_s.strip }&.find { |t| !t.empty? && t.length <= 200 }
    { 'text' => text, 'example' => ex }.compact
  end
  next if defs.empty?

  entry = found[word]
  list = (entry['pos'][pos] ||= [])
  defs.each { |d| list << d unless list.any? { |x| x['text'] == d['text'] } }
  entry['phonetic'] ||= e['sounds']&.map { |s| s['ipa'] }&.compact&.first
end

out = found.sort.to_h do |word, entry|
  defs = entry['pos'].map { |pos, list| { 'pos' => pos, 'defs' => list.first(MAX_DEFS_PER_POS) } }
  [word, { 'phonetic' => entry['phonetic'], 'definitions' => defs }.compact]
end
$stderr.puts "\n#{lines} lines read; definitions for #{out.size} of #{targets.size} words."
puts JSON.pretty_generate(out)
