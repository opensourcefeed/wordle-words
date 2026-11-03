# Fetches definitions from the Free Dictionary API (Wiktionary data, CC BY-SA)
# for word pages that don't have one yet, and stores them as structured
# `phonetic` + `definitions` front matter.
#
# Afterwards, run `bundle exec ruby scripts/build_pages.rb` to rebuild titles,
# answer status, stats and related words for every page.
#
# Usage: ruby generate_word_pages.rb

require 'yaml'
require 'json'
require 'net/http'

PROCESSED_FILE = 'processed_words.yml' # words already tried: "processed" or "skipped"

def fetch_definitions(word)
  uri = URI("https://api.dictionaryapi.dev/api/v2/entries/en/#{word}")
  res = Net::HTTP.get_response(uri, { 'User-Agent' => 'wordle-words-site-builder' })
  return nil unless res.is_a?(Net::HTTPSuccess)

  entry = JSON.parse(res.body).first
  return nil unless entry.is_a?(Hash) && entry['meanings']

  definitions = entry['meanings'].map do |m|
    defs = m['definitions'].map { |d| { 'text' => d['definition'].to_s.strip, 'example' => d['example'] }.compact }
    { 'pos' => m['partOfSpeech'], 'defs' => defs.reject { |d| d['text'].empty? } }
  end.reject { |m| m['defs'].empty? }
  return nil if definitions.empty?

  phonetic = entry['phonetic'] || entry['phonetics']&.map { |p| p['text'] }&.compact&.first
  [phonetic, definitions]
rescue StandardError => e
  warn "#{word}: #{e.message}"
  nil
end

words = YAML.load_file('_data/wordle-words.yml')['wordle-words'].map(&:to_s)
invalid = words.reject { |w| w.match?(/\A[a-z]{5}\z/) }
abort "Refusing to run. Invalid entries: #{invalid.inspect}" unless invalid.empty?

processed = File.exist?(PROCESSED_FILE) ? (YAML.load_file(PROCESSED_FILE) || {}) : {}

todo = words.reject do |w|
  path = "word/#{w}.md"
  processed.key?(w) || (File.exist?(path) && File.read(path).match?(/^definitions:/))
end
puts "#{todo.size} word(s) to look up."

todo.each_with_index do |word, i|
  path = "word/#{word}.md"
  fm = File.exist?(path) ? (YAML.safe_load(File.read(path)[/\A---\s*\n(.*?)\n---/m, 1].to_s) || {}) : {}
  phonetic, definitions = fetch_definitions(word)

  if definitions
    fm.merge!('layout' => 'word', 'word' => word, 'definitions' => definitions)
    fm['phonetic'] = phonetic if phonetic
    File.write(path, "#{fm.to_yaml}---\n")
    processed[word] = 'processed'
  else
    processed[word] = 'skipped'
  end
  puts "#{i + 1}/#{todo.size} #{word}: #{processed[word]}"
  File.write(PROCESSED_FILE, processed.to_yaml) if ((i + 1) % 25).zero?
  sleep 0.2 # be gentle with the free API
end

File.write(PROCESSED_FILE, processed.to_yaml)
puts 'Done. Now run: bundle exec ruby scripts/build_pages.rb'
