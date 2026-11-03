const wordsPerPage = 1000; // Adjust the number of activeWords per page
let currentPage = 1;
let activeWords = words;

function renderWords() {
    const start = (currentPage - 1) * wordsPerPage;
    const end = start + wordsPerPage;
    const paginatedWords = activeWords.slice(start, end);

    const wordList = document.getElementById('word-list');
    wordList.innerHTML = paginatedWords.map(word => `
        <div class="word-item">
          <a href="word/${word}">${word}</a>
        </div>
      `).join('');
}

function renderPagination() {
    const totalPages = Math.ceil(activeWords.length / wordsPerPage);
    const paginationControls = document.getElementsByClassName('pagination-controls');

    let buttons = '';
    for (let i = 1; i <= totalPages; i++) {
        buttons += `<li onclick="goToPage(${i})" class="page-item ${i === currentPage ? 'active' : ''}">
        <a class="page-link" href="#pagination">${i}</a></li>`;
    }

    for (const pc of paginationControls) {
        pc.innerHTML = `
        <ul class="pagination">
        <li class="page-item ${currentPage === 1 ? 'disabled' : ''}" onclick="prevPage()"><a class="page-link" href="#pagination">Previous</a></li>
        ${buttons}
        <li class="page-item ${currentPage === totalPages ? 'disabled' : ''}" onclick="nextPage()"><a class="page-link" href="#pagination">Next</a></li>
        </ul>
      `;
    }

}

function goToPage(page) {
    currentPage = page;
    renderWords();
    renderPagination();
}

function prevPage() {
    if (currentPage > 1) {
        currentPage--;
        renderWords();
        renderPagination();
    }
}

function nextPage() {
    const totalPages = Math.ceil(activeWords.length / wordsPerPage);
    if (currentPage < totalPages) {
        currentPage++;
        renderWords();
        renderPagination();
    }
}

// Initial rendering
renderWords();
renderPagination();

const searchField = document.getElementById('search-word');

if (searchField) {
  searchField.addEventListener('input', (e) => {
    const searchQuery = e.target.value.toLowerCase(); // Search query in lowercase

    if (!searchQuery) {
        activeWords = words;
    } else {
        activeWords = words.filter(w => String(w).includes(searchQuery))
    }
    currentPage = 1;
    renderWords();
    renderPagination();
  });
}