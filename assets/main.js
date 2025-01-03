const searchField = document.getElementById('search-word');

if (searchField) {
  searchField.addEventListener('input', (e) => {
    const searchQuery = e.target.value.toLowerCase(); // Search query in lowercase
    const wordElements = document.querySelectorAll('.words a'); // Select all anchor tags within .words

    for (const wordElement of wordElements) {
      const wordText = wordElement.textContent.toLowerCase(); // Word text in lowercase
      if (!searchQuery || wordText.includes(searchQuery)) {
        wordElement.style.display = 'auto';
      } else {
        wordElement.style.display = 'none';
      }
    }
  });
}