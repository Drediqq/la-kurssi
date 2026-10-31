document.addEventListener('DOMContentLoaded', () => {
    const header = document.createElement('header');
    const footer = document.createElement('footer');

    header.innerHTML = `
        <div class="header-links">
            <a href="index.html">Index</a>
            <a href="week1.html">Week 1 Assignment</a>
        </div>
    `;
    footer.innerHTML = `
        <div class="footer-links">
            <a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ" target="_blank">Nano enjoyer? Click here!</a>
        </div>
    `;

    document.body.insertBefore(header, document.body.firstChild);
    document.body.appendChild(footer);
});