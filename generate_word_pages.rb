require 'fileutils'
require 'yaml'

# Load the data file
data = YAML.load_file('_data/wordle-words.yml')
words = data['wordle-words']

# Create a directory to store the generated pages
FileUtils.mkdir_p('word')

words.each do |word|
  # Create a Markdown file for each word
  filename = "word/#{word}.md"
  File.open(filename, 'w') do |f|
    f.write("---\n")
    f.write("layout: word\n")
    f.write("title: #{word}\n")
    f.write("word: #{word}\n")
    f.write("---\n")
    f.write("\n") # Add an empty line after the front matter
  end
end