// header + footer generator
document.addEventListener('DOMContentLoaded', () => {
    const header = document.createElement('header');
    const footer = document.createElement('footer');

    header.innerHTML = `
        <div class="header-links">
            <a href="/index.html">Index</a>
            <a href="/week1/week1.html">Week 1</a>
            <a href="/week2/">Week 2</a>
            <a href="/week3/week3.html">Week 3</a>
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

// fetch updated values for table
async function updateVariables(filename, elementId, suffix = "") {
    try {
        const response = await fetch(filename);
        if (!response.ok) throw new Error("Network not responding");
        const text = await response.text();
        document.getElementById(elementId).textContent = text.trim() + suffix;
    } catch (error) {
        console.error(`Failed to load ${filename}:`, error);
        document.getElementById(elementId).textContent = "Error loading";
    }
}

// load stats
window.addEventListener("DOMContentLoaded", () => {
    updateVariables("generated.txt", "val-generated");
    updateVariables("tz.txt", "val-tz")
    updateVariables("uptime.txt", "val-uptime", " days");
    updateVariables("diskspace.txt", "val-disk-usage");
    updateVariables("diskusage.txt", "val-disk-status");
    updateVariables("totalram.txt", "val-total-ram", " MiB");
    updateVariables("availableram.txt", "val-avail-ram", " MiB");
});