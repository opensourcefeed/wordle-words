# Syncs `sensitive: true` / `sitemap: false` front matter on word pages with
# _data/sensitive-words.yml. Sensitive pages get no ads and a noindex tag.
#
# Usage: ruby scripts/flag_sensitive_words.rb

require 'yaml'
require 'set'

FLAG_LINES = "sensitive: true\nsitemap: false\n"

sensitive = YAML.load_file('_data/sensitive-words.yml')['sensitive-words'].map(&:to_s).to_set
listed = YAML.load_file('_data/wordle-words.yml')['wordle-words'].map(&:to_s).to_set
unknown = sensitive - listed
abort "Not in the Wordle list: #{unknown.to_a.sort.join(', ')}" unless unknown.empty?

changed = 0
Dir.glob('word/*.md').each do |path|
  word = File.basename(path, '.md')
  content = File.read(path)
  stripped = content.sub(FLAG_LINES, '')
  updated = sensitive.include?(word) ? stripped.sub(/^(word: .*\n)/) { "#{$1}#{FLAG_LINES}" } : stripped
  next if updated == content

  File.write(path, updated)
  changed += 1
end

puts "#{sensitive.size} sensitive words, #{changed} page(s) updated."
