# Validates that the word list and word pages contain valid Wordle words only.
#
# Usage:
#   ruby scripts/validate_words.rb                 # internal consistency checks
#   ruby scripts/validate_words.rb nyt_valid.txt   # also compare with a reference list (one word per line)
#
# Exits with status 1 if any check fails.

require 'yaml'
require 'set'

DATA_FILE = '_data/wordle-words.yml'
PAGES_DIR = 'word'
WORD_RE = /\A[a-z]{5}\z/

errors = []

# 1. Data file: every entry must be a 5-letter lowercase string, with no duplicates.
raw = YAML.load_file(DATA_FILE)['wordle-words']
raw.each_with_index do |w, i|
  errors << "#{DATA_FILE}: entry #{i + 1} is a #{w.class}, not a string (#{w.inspect}); quote it" unless w.is_a?(String)
  errors << "#{DATA_FILE}: entry #{i + 1} is not a 5-letter word: #{w.inspect}" unless w.to_s.match?(WORD_RE)
end
words = raw.map(&:to_s)
words.tally.each { |w, c| errors << "#{DATA_FILE}: duplicate word #{w} (#{c}x)" if c > 1 }
word_set = words.to_set

sensitive = YAML.load_file('_data/sensitive-words.yml')['sensitive-words'].map(&:to_s).to_set
(sensitive - word_set).sort.each { |w| errors << "_data/sensitive-words.yml: #{w} is not in #{DATA_FILE}" }

# 2. Optional reference list (for example the current official list).
if (ref_path = ARGV[0])
  ref = File.read(ref_path).split.map(&:strip).reject(&:empty?).to_set
  (word_set - ref).sort.each { |w| errors << "#{DATA_FILE}: #{w} is not in the reference list" }
  missing = (ref - word_set).sort
  errors << "#{DATA_FILE}: #{missing.size} reference words missing, e.g. #{missing.first(10).join(', ')}" unless missing.empty?
end

# 3. Word pages: file name must be a listed word, and front matter must match it.
Dir.glob(File.join(PAGES_DIR, '*')).sort.each do |path|
  name = File.basename(path, '.md')
  unless path.end_with?('.md') && name.match?(WORD_RE)
    errors << "#{path}: file name is not a 5-letter word"
    next
  end
  errors << "#{path}: #{name} is not in #{DATA_FILE}" unless word_set.include?(name)

  front = File.read(path)[/\A---\s*\n(.*?)\n---/m, 1]
  if front.nil?
    errors << "#{path}: missing front matter"
    next
  end
  begin
    fm = YAML.safe_load(front) || {}
  rescue Psych::SyntaxError => e
    errors << "#{path}: invalid front matter YAML (#{e.problem})"
    next
  end
  flagged = fm['sensitive'] == true && fm['sitemap'] == false
  if sensitive.include?(name) != flagged
    errors << "#{path}: sensitive flags out of sync; run bundle exec ruby scripts/build_pages.rb"
  end
  expected = { 'word' => name, 'title' => "Is #{name.upcase} a Wordle Word?" }
  expected.each do |key, want|
    value = fm[key]
    errors << "#{path}: #{key} is a #{value.class}, not a string (#{value.inspect}); quote it" unless value.is_a?(String)
    errors << "#{path}: #{key} #{value.inspect} should be #{want.inspect}" unless value.to_s == want
  end
  errors << "#{path}: missing answer status; run bundle exec ruby scripts/build_pages.rb" unless %w[past possible guess].include?(fm['status'])
end

pages = Dir.glob(File.join(PAGES_DIR, '*.md')).size
puts "Words in list: #{words.size}, word pages: #{pages}, words without a page: #{words.size - pages}"

if errors.empty?
  puts 'OK: word list and word pages contain valid Wordle words only.'
else
  puts errors
  puts "FAILED: #{errors.size} problem(s)."
  exit 1
end
