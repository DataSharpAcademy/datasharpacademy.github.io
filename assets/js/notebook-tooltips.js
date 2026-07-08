document.addEventListener("DOMContentLoaded", () => {

    const tooltip = document.createElement("div");
    tooltip.className = "chapter-tooltip";
    document.body.appendChild(tooltip);

    document.querySelectorAll(".chapter-link").forEach(link => {

        link.addEventListener("mouseenter", () => {

            const summary = link.dataset.summary?.trim();

            if (!summary) return;

            tooltip.textContent = summary;
            tooltip.style.opacity = "1";
        });

        link.addEventListener("mouseleave", () => {
            tooltip.style.opacity = "0";
        });

        link.addEventListener("mousemove", (e) => {

            tooltip.style.left = (e.clientX + 18) + "px";
            tooltip.style.top  = (e.clientY + 18) + "px";

        });

    });

});
