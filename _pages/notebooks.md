---
layout: default
title: My dusty shelf
permalink: /notebooks/
---

# Notebooks

Each notebook follows an investigation from its initial idea to wherever it eventually leads.

Some are currently underway, others are complete, and a few are still brewing, waiting for the right moment.

<br>

Each notebook tells a story. Each chapter captures one stage of that story. While there is continuity between chapters, feel free to jump straight to the ones that interest you most. The notebooks are meant to be explored, not necessarily read from beginning to end.


{% assign statuses = "active,planned,complete" | split: "," %}
    {% for status in statuses %}
        {% assign notebooks = site.notebooks
            | where: "status", status
            | sort: "order" %}

            {% if notebooks.size > 0 %}
                {% case status %}
                    {% when "active" %}
# Active investigations

                    {% when "planned" %}
# Planned investigations

                    {% when "complete" %}
# Completed investigations

                {% endcase %}

{% for notebook in notebooks %}

<div class="notebook-card">
    <div class="notebook-image">
        <img src="{{ notebook.image | relative_url }}"
        alt="{{ notebook.title }}">
    </div>

    <div class="notebook-content">
    <h2>
        <a href="{{ notebook.url | relative_url }}">
            {{ notebook.title }}
        </a>
    </h2>

    <p>
        {{ notebook.description }} <a href="{{ notebook.url | relative_url }}">
             → Grab notebook 📓
        </a>
    </p>

    <p>

    </p>
        </div>
</div>

{% endfor %}
{% endif %}
{% endfor %}
