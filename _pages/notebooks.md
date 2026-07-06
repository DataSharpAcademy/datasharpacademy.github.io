---
layout: default
title: Getting started with Reverie
permalink: /notebooks/
---

# Notebooks

Each notebook documents an investigation from its initial idea to its conclusions.

Some are currently underway, others are complete, and a few are still waiting for the right moment to begin.

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
             → Explore notebook
        </a>
    </p>

    <p>

    </p>
        </div>
</div>

{% endfor %}
{% endif %}
{% endfor %}
