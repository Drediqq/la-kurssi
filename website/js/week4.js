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
        
    } catch (error) {
        console.error(`Failed to load ${filename}:`, error);
        const td = document.getElementById(elementId);
        if (td) td.textContent = "Error loading";
    }
}

// load stats
function loadAllStats() {
    updateVariables("stats/lastbu.txt", "val-backup-time");
}

window.addEventListener("DOMContentLoaded", () => {
    loadAllStats();

    // 10000ms = 10s
    setInterval(() => {
        loadAllStats();
    }, 10000);
});
