document.addEventListener('DOMContentLoaded', () => {
    const header = document.createElement('header');
    const footer = document.createElement('footer');

    header.innerHTML = `
        <div class="header-links">
            <a href="index.html">Index</a>
            <a href="week1.html">Week 1</a>
            <a href="/week2/">Week 2</a>
        </div>
    `;
    footer.innerHTML = `
        <div class="footer-links">
            <a href="https://www.youtube.com/watch?v=dQw4w9WgXcQ" target="_blank">Nano enjoyer? Click here!</a>
        </div>
    `;

    document.body.insertBefore(header, document.body.firstChild);
    document.body.appendChild(footer);

const sectionsToHide = document.querySelectorAll('.whynosudo, .whymulti');
    sectionsToHide.forEach(el => {
        el.style.display = 'none';
    });

    // 3. Your toggle function
    window.toggleSection = function(className) {
        const elements = document.querySelectorAll('.' + className);
        elements.forEach(el => {
            if (el.style.display === 'none' || el.style.display === '') {
                el.style.display = 'block';
            } else {
                el.style.display = 'none';
            }
        });
    };
});
