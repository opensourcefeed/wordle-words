require 'fileutils'
require 'yaml'
require 'net/http'
require 'json'
require 'thread'

def fetch_word_meaning_html(word)
  url = URI("https://api.dictionaryapi.dev/api/v2/entries/en/#{word}")

  html_content = ''

  begin
    # Make the API request
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    if data.is_a?(Array) && data[0]["meanings"]
      html_content = "<div class=\'dictionary-entry\'>"
      html_content += "<p><strong>Phonetics:</strong> #{data[0]['phonetic'] || 'N/A'}</p>"

      data[0]["meanings"].each_with_index do |meaning, index|
        html_content += "<div class=\'meanings\'>"
        html_content += "<h3>Meaning #{index + 1}</h3>"
        html_content += "<p><strong>Part of Speech:</strong> #{meaning['partOfSpeech']}</p>"
        html_content += "<ul>"
        meaning['definitions'].each_with_index do |definition, def_index|
          html_content += "<li><strong>Definition #{def_index + 1}:</strong> #{definition['definition']}"
          if definition['example']
            html_content += "<p><strong>Example:</strong> #{definition['example']}</p>"
          end
          html_content += "</li>"
        end
        html_content += "</ul>"
        html_content += "</div>"
      end

      html_content += "</div>"
    else
      html_content = "No meanings found for the word: #{word}"
    end
  rescue StandardError => e
    puts "An error occurred: #{e.message}"
  end
  return html_content
end

# Load the data file. Words are coerced to strings because YAML parses
# bare words such as `false` as booleans.
data = YAML.load_file('_data/wordle-words.yml')
words = data['wordle-words'].map(&:to_s)

# Only ever generate pages for valid Wordle words: 5 lowercase letters, no duplicates.
invalid = words.reject { |w| w.match?(/\A[a-z]{5}\z/) }
duplicates = words.tally.select { |_, count| count > 1 }.keys
unless invalid.empty? && duplicates.empty?
  abort "Refusing to generate pages. Invalid entries: #{invalid.inspect}, duplicates: #{duplicates.inspect}"
end

# Create a directory to store the generated pages
FileUtils.mkdir_p('word')

# Load processed words if the file exists
processed_file = 'processed_words.yml'
processed_words = if File.exist?(processed_file)
                    YAML.load_file(processed_file) || {}
                  else
                    {}
                  end

$total_words = words.size

def process_word(word, index, processed_words, mutex)
  filename = "word/#{word}.md"
  if File.exist?(filename)
    existing_content = File.read(filename)
    if existing_content.match?(/^meaning:\s*"[^"]+"/)
      puts "#{index + 1}/#{$total_words} words processed: #{word}... (Skipping - file exists and meaning is not empty)"
      mutex.synchronize { processed_words[word] = "skipped" }
      return
    end
  end

  html_content = fetch_word_meaning_html(word)
  if html_content.include?("No meanings found for the word:")
    puts "#{index + 1}/#{$total_words} words processed: #{word}... (Skipping - no meanings found)"
    mutex.synchronize { processed_words[word] = "skipped" }
    return
  end

  puts "#{index + 1}/#{$total_words} words processed: #{word}..."
  File.open(filename, 'w') do |f|
    f.write("---\n")
    f.write("layout: word\n")
    # Quote values so words like "false" stay strings in front matter.
    f.write("title: \"#{word}\"\n")
    f.write("word: \"#{word}\"\n")
    # Escape backslashes first (definitions can contain LaTeX like \operatorname), then quotes.
    f.write("meaning: \"#{html_content.gsub('\\') { '\\\\' }.gsub('"') { '\\"' }}\"\n")
    f.write("---\n")
    f.write("\n") # Add an empty line after the front matter
  end

  mutex.synchronize { processed_words[word] = "processed" }
end

# Thread pool
num_threads = 2
queue = Queue.new
words.each_with_index { |word, index| queue << [word, index] }

mutex = Mutex.new

threads = Array.new(num_threads) do
  Thread.new do
    until queue.empty?
      word, index = queue.pop(true) rescue nil
      next if word.nil? || processed_words.key?(word)

      process_word(word, index, processed_words, mutex)

      # Save processed words
      mutex.synchronize do
        File.open(processed_file, 'w') { |f| f.write(processed_words.to_yaml) }
      end
    end
  end
end

threads.each(&:join)
