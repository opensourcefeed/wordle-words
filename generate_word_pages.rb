# Fetches definitions from the Free Dictionary API (Wiktionary data, CC BY-SA)
# for word pages that don't have one yet, and stores them as structured
# `phonetic` + `definitions` front matter.
#
# processed_words.yml records the outcome per word:
#   processed  – definitions saved
#   not_found  – the API has no entry (HTTP 404); not retried
#   skipped    – legacy status from older runs (may hide API errors);
#                retried only with --retry-skipped
# Temporary API errors (429/5xx) are retried and never recorded, so the next
# run picks those words up again.
#
# Afterwards, run `bundle exec ruby scripts/build_pages.rb` to rebuild titles,
# answer status, stats and related words for every page.
#
# Usage: ruby generate_word_pages.rb [--retry-skipped]

require 'yaml'
require 'json'
require 'net/http'

PROCESSED_FILE = 'processed_words.yml'
THREADS = 2 # stays under the API limit of 450 requests per 5 minutes

def fetch_definitions(word)
  uri = URI("https://api.dictionaryapi.dev/api/v2/entries/en/#{word}")
  4.times do |attempt|
    res = Net::HTTP.get_response(uri, { 'User-Agent' => 'wordle-words-site-builder' })
    case res
    when Net::HTTPNotFound then return :not_found
    when Net::HTTPSuccess
      entry = JSON.parse(res.body).first
      return :not_found unless entry.is_a?(Hash) && entry['meanings']

      definitions = entry['meanings'].map do |m|
        defs = m['definitions'].map { |d| { 'text' => d['definition'].to_s.strip, 'example' => d['example'] }.compact }
        { 'pos' => m['partOfSpeech'], 'defs' => defs.reject { |d| d['text'].empty? } }
      end.reject { |m| m['defs'].empty? }
      return :not_found if definitions.empty?

      phonetic = entry['phonetic'] || entry['phonetics']&.map { |p| p['text'] }&.compact&.first
      return [phonetic, definitions]
    end
    sleep(2 * (attempt + 1)) # 429 or 5xx: back off and retry
  end
  :error
rescue StandardError => e
  warn "#{word}: #{e.message}"
  :error
end

words = YAML.load_file('_data/wordle-words.yml')['wordle-words'].map(&:to_s)
invalid = words.reject { |w| w.match?(/\A[a-z]{5}\z/) }
abort "Refusing to run. Invalid entries: #{invalid.inspect}" unless invalid.empty?

retry_skipped = ARGV.include?('--retry-skipped')
processed = File.exist?(PROCESSED_FILE) ? (YAML.load_file(PROCESSED_FILE) || {}) : {}

todo = words.reject do |w|
  path = "word/#{w}.md"
  next true if File.exist?(path) && File.read(path).match?(/^definitions:/)

  processed[w] == 'not_found' || (processed[w] == 'skipped' && !retry_skipped)
end
puts "#{todo.size} word(s) to look up."

queue = Queue.new
todo.each { |w| queue << w }
mutex = Mutex.new
done = 0
counts = Hash.new(0)

workers = Array.new(THREADS) do
  Thread.new do
    while (word = (queue.pop(true) rescue nil))
      result = fetch_definitions(word)
      mutex.synchronize do
        if result.is_a?(Array)
          path = "word/#{word}.md"
          fm = File.exist?(path) ? (YAML.safe_load(File.read(path)[/\A---\s*\n(.*?)\n---/m, 1].to_s) || {}) : {}
          fm.merge!('layout' => 'word', 'word' => word, 'definitions' => result[1])
          fm['phonetic'] = result[0] if result[0]
          File.write(path, "#{fm.to_yaml}---\n")
          processed[word] = 'processed'
        elsif result == :not_found
          processed[word] = 'not_found'
        end
        counts[result.is_a?(Array) ? :processed : result] += 1
        done += 1
        if (done % 50).zero?
          File.write(PROCESSED_FILE, processed.to_yaml)
          puts "#{done}/#{todo.size} #{counts}"
        end
      end
      sleep 0.4
    end
  end
end
workers.each(&:join)

File.write(PROCESSED_FILE, processed.to_yaml)
puts "Done: #{counts}. Now run: bundle exec ruby scripts/build_pages.rb"
