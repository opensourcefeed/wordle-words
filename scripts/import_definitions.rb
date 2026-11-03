# Adds definitions extracted by scripts/extract_kaikki.rb to word pages that
# have none. Existing definitions are never changed.
#
#   ruby scripts/import_definitions.rb defs.json [bases.json]
#
# bases.json (optional, from a second --any-length extraction pass) holds the
# base words of "plural of tift"-style entries; their first real definition is
# appended, e.g. "Plural of tift: A fit of temper."
# Afterwards run scripts/build_pages.rb to refresh titles and descriptions.

require 'json'
require 'yaml'
require 'date'

# "Plural of tift", "Alternative form of eschar"… The short prefix limit keeps
# real sentences such as "…thought to be a form of ruby" out.
FORM_OF = /\A(?=.{0,40}\bof [a-z][a-z-]*\.?\z)(?:.*\b(?:past|plural|participle|third-person|comparative|superlative|form|spelling|clipping|abbreviation|initialism|contraction) )?of ([a-z][a-z-]*)\.?\z/i

defs = JSON.parse(File.read(ARGV.fetch(0)))
bases = ARGV[1] ? JSON.parse(File.read(ARGV[1])) : {}

def cap(text) = text.sub(/\A[a-z]/, &:upcase)

# First definition of a base word that isn't itself a "form of" pointer.
def base_meaning(entry)
  entry && entry['definitions'].flat_map { |d| d['defs'] }.map { |d| d['text'] }.find { |t| t !~ FORM_OF }
end

added = enriched = 0
defs.each do |word, entry|
  path = "word/#{word}.md"
  next unless File.exist?(path)

  text = File.read(path)
  fm = YAML.safe_load(text[/\A---\n(.*?)\n---\n/m, 1], permitted_classes: [Date])
  next if fm['definitions']&.any? # never overwrite

  definitions = entry['definitions'].map do |d|
    list = d['defs'].map do |x|
      t = cap(x['text'])
      if (base = t[FORM_OF, 1]) && (meaning = base_meaning(bases[base.downcase]))
        t = "#{t.chomp('.')}: #{cap(meaning)}"
        enriched += 1
      end
      { 'text' => t, 'example' => x['example'] }.compact
    end
    { 'pos' => d['pos'], 'defs' => list }
  end

  fm['phonetic'] = entry['phonetic'] if entry['phonetic'] && !fm['phonetic']
  fm['definitions'] = definitions
  File.write(path, "#{fm.to_yaml}---\n#{text.sub(/\A---\n.*?\n---\n/m, '')}")
  added += 1
end

puts "Definitions added to #{added} pages; #{enriched} 'form of' entries got their base word's meaning."
