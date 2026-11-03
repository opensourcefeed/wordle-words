# Read-only Google Search Console client (standard library only).
#
# Authenticates as a service account with the `webmasters.readonly` scope, so
# it can read data but never change anything in Search Console.
#
# Setup: add the service account's email in Search Console → Settings → Users
# and permissions with "Restricted" permission. Keep the JSON key OUTSIDE this
# repository, and point to it with GSC_KEY_FILE (or GOOGLE_APPLICATION_CREDENTIALS).
#
# Usage:
#   ruby scripts/gsc.rb sites                          # properties the account can read
#   ruby scripts/gsc.rb performance [days] [out.json]  # queries/pages for /wordle-words/
#   ruby scripts/gsc.rb sitemaps                       # submitted sitemaps and their status
#   ruby scripts/gsc.rb inspect URL [URL...]           # index status of specific URLs
#   ruby scripts/gsc.rb candidates [days] [min_impr]    # searched-for words Wordle rejects
#
# Optional: GSC_SITE overrides the property (e.g. "sc-domain:opensourcefeed.org").

require 'json'
require 'net/http'
require 'openssl'
require 'base64'
require 'date'
require 'uri'
require 'set'

SCOPE = 'https://www.googleapis.com/auth/webmasters.readonly'
PATH_FILTER = '/wordle-words/'

def key_file
  path = ENV['GSC_KEY_FILE'] || ENV['GOOGLE_APPLICATION_CREDENTIALS']
  abort 'Set GSC_KEY_FILE to the service account JSON key path.' unless path && File.exist?(path)
  path
end

def b64(data) = Base64.urlsafe_encode64(data, padding: false)

def access_token
  @access_token ||= begin
    key = JSON.parse(File.read(key_file))
    now = Time.now.to_i
    header = b64({ alg: 'RS256', typ: 'JWT' }.to_json)
    claims = b64({ iss: key['client_email'], scope: SCOPE, aud: key['token_uri'], iat: now, exp: now + 3600 }.to_json)
    signature = OpenSSL::PKey::RSA.new(key['private_key']).sign(OpenSSL::Digest::SHA256.new, "#{header}.#{claims}")
    res = Net::HTTP.post_form(URI(key['token_uri']),
                              'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
                              'assertion' => "#{header}.#{claims}.#{b64(signature)}")
    abort "Token request failed (#{res.code}): #{res.body}" unless res.is_a?(Net::HTTPSuccess)
    JSON.parse(res.body)['access_token']
  end
end

def api(method, url, body = nil)
  uri = URI(url)
  req = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
  req['Authorization'] = "Bearer #{access_token}"
  if body
    req['Content-Type'] = 'application/json'
    req.body = body.to_json
  end
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true) { |h| h.request(req) }
  abort "#{method.upcase} #{uri.path} failed (#{res.code}): #{res.body}" unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def sites = api(:get, 'https://www.googleapis.com/webmasters/v3/sites')['siteEntry'] || []

# Prefer the GSC_SITE override, then a domain property, then the URL-prefix property.
def site
  @site ||= ENV['GSC_SITE'] || begin
    urls = sites.map { |s| s['siteUrl'] }
    urls.find { |u| u == 'sc-domain:opensourcefeed.org' } ||
      urls.find { |u| u.start_with?('https://www.opensourcefeed.org') } ||
      abort("No opensourcefeed.org property is shared with this account. Readable: #{urls.inspect}")
  end
end

def search_analytics(dimensions, days, row_limit: 25_000,
                     filters: [{ dimension: 'page', operator: 'contains', expression: PATH_FILTER }])
  url = "https://www.googleapis.com/webmasters/v3/sites/#{URI.encode_www_form_component(site)}/searchAnalytics/query"
  end_date = Date.today - 2 # Search Console data lags about two days
  api(:post, url, {
        startDate: (end_date - days).iso8601, endDate: end_date.iso8601,
        dimensions: dimensions, rowLimit: row_limit,
        dimensionFilterGroups: [{ filters: filters }],
      })['rows'] || []
end

# The word a query asks about, only for genuine "is it a valid word" questions:
# "is pizza a wordle word", "is zebras a valid word in wordle",
# "paris a wordle word", "is tiger in wordle" → pizza, zebras, paris, tiger.
# Game names ("unlimited wordle") and "is today's wordle X" don't match.
ASK_FILLER = '(?:(?:a|an|valid|real|allowed|accepted|word|in|the) )+'
def asked_word(query)
  q = query.downcase.gsub(/[^a-z ]/, ' ').squeeze(' ').strip
  q[/\Ais (?:the word )?([a-z]{2,12}) #{ASK_FILLER}wordle(?: word| game)?\z/, 1] ||
    q[/\A([a-z]{2,12}) (?:a |an )?(?:valid )?wordle word\z/, 1] ||
    q[/\Ais ([a-z]{2,12}) (?:a )?(?:valid |real )?word in wordle\z/, 1]
end

def pct(x) = format('%.1f%%', x.to_f * 100)

case ARGV[0]
when 'sites'
  sites.each { |s| puts "#{s['siteUrl']}  (#{s['permissionLevel']})" }
when 'performance'
  days = (ARGV[1] || 90).to_i
  by_query = search_analytics(['query'], days)
  by_page = search_analytics(['page'], days)
  by_date = search_analytics(['date'], days)
  totals = by_date.each_with_object(Hash.new(0)) { |r, t| t[:clicks] += r['clicks']; t[:impressions] += r['impressions'] }
  puts "Property: #{site} | last #{days} days | pages containing #{PATH_FILTER}"
  puts "Clicks: #{totals[:clicks]}  Impressions: #{totals[:impressions]}  Queries: #{by_query.size}  Pages: #{by_page.size}"
  puts "\nTop queries by impressions:"
  by_query.sort_by { |r| -r['impressions'] }.first(30).each do |r|
    puts format('  %-45s clicks %4d  impr %6d  ctr %6s  pos %5.1f', r['keys'][0][0, 45], r['clicks'], r['impressions'], pct(r['ctr']), r['position'])
  end
  puts "\nTop pages by impressions:"
  by_page.sort_by { |r| -r['impressions'] }.first(30).each do |r|
    puts format('  %-70s clicks %4d  impr %6d  pos %5.1f', r['keys'][0].sub(%r{https?://[^/]+}, '')[0, 70], r['clicks'], r['impressions'], r['position'])
  end
  if ARGV[2]
    File.write(ARGV[2], JSON.pretty_generate(site: site, days: days, queries: by_query, pages: by_page, dates: by_date))
    puts "\nFull data written to #{ARGV[2]}"
  end
when 'candidates'
  # Words people search for ("is X a wordle word") that Wordle does NOT accept:
  # candidates for scripts/build_invalid_pages.rb. Looks at the whole property,
  # since these searches may land on the 404 page or other sections.
  require 'yaml'
  days = (ARGV[1] || 90).to_i
  min = (ARGV[2] || 10).to_i
  valid = YAML.load_file(File.join(__dir__, '../_data/wordle-words.yml'))['wordle-words'].map(&:to_s).to_set
  rows = search_analytics(['query'], days, filters: [{ dimension: 'query', operator: 'contains', expression: 'wordle' }])
  found = Hash.new { |h, k| h[k] = { impressions: 0, clicks: 0, queries: [] } }
  rows.each do |r|
    w = asked_word(r['keys'][0])
    next if w.nil? || valid.include?(w) || %w[it this that a the].include?(w)
    found[w][:impressions] += r['impressions']
    found[w][:clicks] += r['clicks']
    found[w][:queries] << r['keys'][0]
  end
  list = found.select { |_, v| v[:impressions] >= min }.sort_by { |_, v| -v[:impressions] }
  puts "Property: #{site} | last #{days} days | #{rows.size} Wordle queries | invalid words with >= #{min} impressions: #{list.size}"
  list.each { |w, v| puts format('  %-12s impr %6d  clicks %4d  e.g. "%s"', w, v[:impressions], v[:clicks], v[:queries].first) }
  puts "\nAdd the ones worth a page to _data/invalid-words.yml, then run scripts/build_invalid_pages.rb." if list.any?
when 'sitemaps'
  list = api(:get, "https://www.googleapis.com/webmasters/v3/sites/#{URI.encode_www_form_component(site)}/sitemaps")['sitemap'] || []
  puts "Property: #{site}"
  puts '  (no sitemaps submitted)' if list.empty?
  list.each do |s|
    submitted = (s['contents'] || []).sum { |c| c['submitted'].to_i }
    puts "  #{s['path']}  last downloaded #{s['lastDownloaded'] || 'never'}  submitted URLs #{submitted}  " \
         "errors #{s['errors'] || 0}  warnings #{s['warnings'] || 0}#{s['isPending'] ? '  (pending)' : ''}"
  end
when 'inspect'
  abort 'Give one or more full URLs to inspect.' if ARGV.size < 2
  ARGV[1..].each do |url|
    r = api(:post, 'https://searchconsole.googleapis.com/v1/urlInspection/index:inspect',
            { inspectionUrl: url, siteUrl: site })['inspectionResult']['indexStatusResult']
    puts "#{url}\n  verdict: #{r['verdict']}  coverage: #{r['coverageState']}  " \
         "last crawl: #{r['lastCrawlTime'] || 'never'}  google canonical: #{r['googleCanonical'] || '-'}"
  end
else
  puts File.read(__FILE__).lines.drop(1).take_while { |l| l.start_with?('#') }.map { |l| l.sub(/^# ?/, '') }
end
