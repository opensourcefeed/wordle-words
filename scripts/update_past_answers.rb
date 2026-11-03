# Updates _data/past-answers.yml with every Wordle answer from the first puzzle
# (2021-06-19) up to YESTERDAY. Today's answer is never stored, so the site can't
# spoil the current puzzle. Only missing dates are fetched, so re-runs are cheap.
#
# Usage: ruby scripts/update_past_answers.rb

require 'yaml'
require 'json'
require 'net/http'
require 'date'
require 'set'

FILE = '_data/past-answers.yml'
FIRST_DAY = Date.new(2021, 6, 19)
last_day = Date.today - 1

answers = File.exist?(FILE) ? (YAML.load_file(FILE)['past-answers'] || []) : []
known = answers.map { |a| a['date'] }.to_set

def fetch(date)
  uri = URI("https://www.nytimes.com/svc/wordle/v2/#{date.iso8601}.json")
  3.times do |attempt|
    res = Net::HTTP.get_response(uri, { 'User-Agent' => 'wordle-words-site-builder' })
    return JSON.parse(res.body) if res.is_a?(Net::HTTPSuccess)

    sleep(2**attempt)
  end
  nil
rescue StandardError => e
  warn "#{date}: #{e.message}"
  nil
end

missing = (FIRST_DAY..last_day).reject { |d| known.include?(d.iso8601) }
puts "Fetching #{missing.size} missing day(s)..."
missing.each_with_index do |date, i|
  data = fetch(date)
  if data.nil? || !data['solution'].to_s.match?(/\A[a-z]{5}\z/)
    warn "#{date}: no answer found"
    next
  end
  answers << { 'date' => date.iso8601, 'number' => data['days_since_launch'], 'word' => data['solution'] }
  puts "#{i + 1}/#{missing.size} #{date} ##{data['days_since_launch']}" if ((i + 1) % 100).zero?
  sleep 0.15
end

answers.sort_by! { |a| a['date'] }
File.write(FILE, "# Past Wordle answers (up to yesterday). Updated by scripts/update_past_answers.rb\n" +
                 { 'past-answers' => answers }.to_yaml.sub(/\A---\n/, ''))
puts "#{answers.size} past answers saved to #{FILE} (latest: #{answers.last&.fetch('date')})."
