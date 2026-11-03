# Builds static "No, it isn't a Wordle word" pages for words people search for
# that Wordle rejects (_data/invalid-words.yml), plus a list page that links to
# them. Pages live in invalid/ and are served at /word/<word>/, the same URL
# pattern as valid words, so a visitor who types /word/burpy gets an answer.
#
# Usage: ruby scripts/build_invalid_pages.rb

require 'yaml'
require 'set'
require 'fileutils'
require_relative 'hub_rules'

def load_list(file, key) = YAML.load_file(file)[key].map(&:to_s)

VALID = load_list('_data/wordle-words.yml', 'wordle-words')
VALID_SET = VALID.to_set
ORIGINALS = load_list('_data/original-answers.yml', 'original-answers').to_set
SENSITIVE = load_list('_data/sensitive-words.yml', 'sensitive-words').to_set
ENTRIES = YAML.load_file('_data/invalid-words.yml')['invalid-words'] || []
ALPHA = ('a'..'z').to_a
LIMIT = 12

# Common answer-list words first, then alphabetical; never sensitive words.
def rank(words) = words.uniq.reject { |w| SENSITIVE.include?(w) }.sort_by { |w| [ORIGINALS.include?(w) ? 0 : 1, w] }.first(LIMIT)

def one_letter_changed(w) = rank(w.length.times.flat_map { |i| ALPHA.map { |c| w.dup.tap { |x| x[i] = c } } }.select { |x| x != w && VALID_SET.include?(x) })
def one_letter_added(w) = rank((0..w.length).flat_map { |i| ALPHA.map { |c| w.dup.insert(i, c) } }.select { |x| VALID_SET.include?(x) })
def one_letter_removed(w) = rank(w.length.times.map { |i| w.dup.tap { |x| x.slice!(i) } }.select { |x| VALID_SET.include?(x) })
ANAGRAMS = VALID.group_by { |w| w.chars.sort.join }
PREFIXES = HubRules.prefixes(VALID)
SUFFIXES = HubRules.suffixes(VALID)

FileUtils.rm_rf('invalid')
FileUtils.mkdir_p('invalid')
errors = []
written = []

ENTRIES.each do |e|
  word = e['word'].to_s.downcase.strip
  up = word.upcase
  errors << "#{word}: is a valid Wordle word; remove it from _data/invalid-words.yml" if VALID_SET.include?(word)
  errors << "#{word}: use letters a-z only" unless word.match?(/\A[a-z]+\z/)
  next if errors.any?

  n = word.length
  reason, suggestions = if n == 5
    ['It is not in the list of words Wordle accepts, so the game rejects it with "Not in word list".',
     [["Valid words one letter away from #{up}", one_letter_changed(word)],
      ["Anagrams of #{up}", rank(ANAGRAMS.fetch(word.chars.sort.join, []))]]]
  elsif n < 5
    ["It has #{n} letter#{n == 1 ? '' : 's'}, and Wordle only accepts five-letter words.",
     n == 4 ? [["Five-letter words made by adding one letter to #{up}", one_letter_added(word)]] : []]
  else
    ["It has #{n} letters, and Wordle only accepts five-letter words.",
     n == 6 ? [["Five-letter words made by removing one letter from #{up}", one_letter_removed(word)]] : []]
  end
  suggestions = suggestions.reject { |_, list| list.empty? }.map { |label, list| { 'label' => label, 'words' => list } }

  first = suggestions.first&.dig('words')&.first(3)&.map(&:upcase)
  hubs = [[HubRules.start_url(word[0]), "Words starting with #{word[0].upcase}"]]
  hubs << [HubRules.start_url(word[0, 2]), "Words starting with #{word[0, 2].upcase}"] if PREFIXES.include?(word[0, 2])
  hubs << [HubRules.end_url(word[3, 2]), "Words ending in #{word[3, 2].upcase}"] if n == 5 && SUFFIXES.include?(word[3, 2])

  fm = {
    'layout' => 'invalid',
    'title' => "Is #{up} a Wordle Word?",
    'head_title' => "Is #{up} a Wordle Word? No – #{n == 5 ? 'Not in Word List' : "#{n} Letters"}",
    'word' => word,
    'description' => "No, #{up} is not a valid Wordle word. #{reason}" +
                     (first ? " Try #{first.join(', ')} instead." : ''),
    'reason' => reason,
    'note' => e['note'],
    'suggestions' => suggestions,
    'hubs' => hubs.map { |url, label| { 'url' => url, 'label' => label } },
  }.compact
  File.write("invalid/#{word}.md", "#{fm.to_yaml}---\n")
  written << word
end

abort("Errors:\n  " + errors.join("\n  ")) if errors.any?

# List page linking every invalid-word page, so crawlers can reach them.
links = written.sort.map { |w| %(<li><a href="{{ '/word/#{w}' | relative_url }}">#{w.upcase}</a></li>) }.join
body = +%(<p class="lead">People often ask whether these words work in Wordle. They don't: Wordle rejects each of them. ) +
       %(Each page explains why and suggests valid words that are close.</p>)
body << %(<ul class="word-grid">#{links}</ul>) if written.any?
fm = { 'layout' => 'hub', 'title' => 'Words Wordle Does Not Accept', 'short' => 'Not accepted',
       'description' => "#{written.size} commonly searched words that are not valid in Wordle, with the reason and close valid alternatives.",
       'permalink' => '/not-in-word-list/', 'crumbs' => [{ 'name' => 'Browse', 'url' => '/browse/' }], 'filter' => true }
File.write('not-in-word-list.html', "#{fm.to_yaml}---\n#{body}\n")

puts "#{written.size} invalid-word pages written, plus /not-in-word-list/."
