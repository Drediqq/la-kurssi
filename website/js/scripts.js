// header + footer generator
document.addEventListener('DOMContentLoaded', () => {
    const header = document.createElement('header');
    const footer = document.createElement('footer');

    header.innerHTML = `
        <div class="header-links">
            <a class="gitlink" href="https://github.com/Drediqq/la-kurssi" target="_blank"><i class="fa-brands fa-github"></i> Git</a>
            <a href="/index.html">Index</a>
            <a href="/week1/">Week 1</a>
            <a href="/week2/">Week 2</a>
            <a href="/week3/">Week 3</a>
            <a href="http://195.148.23.228/week4/">Week 4</a>
            <a href="/week5/">Week 5</a>
        </div>
    `;
    footer.innerHTML = `
        <div class="footer-links">
            <a class="gitlink" href="https://github.com/Drediqq/la-kurssi" target="_blank"><i class="fa-brands fa-github"></i>Git</a>
            
            <a class="ytlink" href="https://www.youtube.com/watch?v=dQw4w9WgXcQ" target="_blank">Nano enjoyer? Click here!</a>
        </div>
    `;

    document.body.insertBefore(header, document.body.firstChild);
    document.body.appendChild(footer);

    const sectionsToHide = document.querySelectorAll('.whynosudo, .whymulti');
    sectionsToHide.forEach(el => {
        el.style.display = 'none';
    });

    // toggle w1
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