# Shared rules for which hub pages exist. Used by build_hubs.rb (to create the
# pages) and build_pages.rb (to link word pages to them), so the two always agree.

require 'set'

module HubRules
  MIN_WORDS = 10 # two-letter prefix/suffix hubs need at least this many words

  def self.prefixes(words)
    words.group_by { |w| w[0, 2] }.select { |_, l| l.size >= MIN_WORDS }.keys.to_set
  end

  def self.suffixes(words)
    words.group_by { |w| w[3, 2] }.select { |_, l| l.size >= MIN_WORDS }.keys.to_set
  end

  def self.start_url(key) = "/starting-with/#{key}/"
  def self.end_url(key) = "/ending-with/#{key}/"
  def self.contain_url(letter) = "/containing/#{letter}/"
end
