---
layout: default
title: Search
permalink: /search/
sitemap: false ## Turn to true when published
---

<div id="search-container">
    <input type="text" id="search-input" placeholder="Search through the blog posts...">
    <ul id="results-container"></ul>
</div>

<script src="{{ site.baseurl }}/assets/simple-jekyll-search.min.js" type="text/javascript"></script>

<script>
SimpleJekyllSearch({
    searchInput: document.getElementById('search-input'),
    resultsContainer: document.getElementById('results-container'),

    searchResultTemplate: `
        <div class="search-result">
            <h2><a href="{url}">{title}</a></h2>
            {summary}
            {keywords}
        </div>
    `,

    templateMiddleware: function(prop, value) {

        if (prop === "summary") {
            return value ? `<p>${value}</p>` : "";
        }

        if (prop === "keywords") {
            return value ? `<p><em>Keywords: ${value}</em></p>` : "";
        }

        if (prop === "title") {
            return value ? `<p>${value}</p>` : "";
        }


        return value;
    },

    json: '{{ site.baseurl }}/search.json'
});
</script>
