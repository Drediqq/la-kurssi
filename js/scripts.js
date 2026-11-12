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
async function updateVariables(filename, elementId) {
    try {
        const response = await fetch(filename, { cache: 'no-store' });
        if (!response.ok) throw new Error("Network not responding");
        const text = (await response.text()).trim();

        const td = document.getElementById(elementId);
        if (!td) return;

        td.textContent = text;

        // disk status color changer (defines td first, then resets and applies classes)
        td.className = '';
        if (elementId === 'val-disk-status') {
            const status = text.toUpperCase();

            if (status === 'CRITICAL') {
                td.classList.add('diskcrit');
            } else if (status === 'WARNING') {
                td.classList.add('diskwarn');    
            } else if (status === 'OK') {
                td.classList.add('diskok');     
            }
        }
    } catch (error) {
        console.error(`Failed to load ${filename}:`, error);
        const td = document.getElementById(elementId);
        if (td) td.textContent = "Error loading";
    }
}

// load stats
function loadAllStats() {
    updateVariables("stats/generated.txt", "val-generated");
    updateVariables("stats/tz.txt", "val-tz");
    updateVariables("stats/uptime.txt", "val-uptime");
    updateVariables("stats/diskspace.txt", "val-disk-usage");
    updateVariables("stats/diskusage.txt", "val-disk-status");
    updateVariables("stats/totalram.txt", "val-total-ram");
    updateVariables("stats/availableram.txt", "val-avail-ram");
}

// disk tests
async function loadDiskTests() {
    const testIds = ['val-disk-usage-50', 'val-disk-usage-80', 'val-disk-usage-95'];

    for (const id of testIds) {
        try {
            const response = await fetch(`stats/${id}.txt`, { cache: 'no-store' });
            let text = (await response.text()).trim();
            
            const tdStatus = document.getElementById(id);
            if (!tdStatus) continue;
            
            const row = tdStatus.closest('tr');
            const firstCell = row.cells[0]; 
            
            // split the text
            const parts = text.split(/\s+/);
            const percentStr = parts[0];      
            const expectedLabel = parts[1] || "OK";
            
            // put percentage to first col
            if (firstCell) firstCell.textContent = percentStr;
            
            // update last col
            tdStatus.textContent = expectedLabel;
            tdStatus.className = ''; // reset class
            // set class 
            if (expectedLabel === 'CRITICAL') {
                tdStatus.classList.add('diskcrit');
            } else if (expectedLabel === 'WARNING') {
                tdStatus.classList.add('diskwarn');
            } else {
                tdStatus.classList.add('diskok');
            }
            // debug
        } catch (error) {
            console.error(`Failed to load test data for ${id}:`, error);
            const tdStatus = document.getElementById(id);
            if (tdStatus) {
                tdStatus.textContent = 'Error';
                tdStatus.className = 'diskcrit';
            }
        }
    }
}

// auto refresh
window.addEventListener("DOMContentLoaded", () => {
    loadDiskTests();
    loadAllStats();

    // 10000ms = 10s
    setInterval(() => {
        loadAllStats();
        loadDiskTests();
    }, 10000);
});
