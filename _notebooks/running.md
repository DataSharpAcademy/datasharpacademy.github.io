---
layout: default
title: Running
permalink: /notebooks/running/

status: active          # active | planned | complete
order: 1

slug: running

description: >
  Sixteen weeks of rebuilding a running routine while documenting
  every step of a complete data project, from data collection,
  interpretation, and race time predictions.


image: /images/notebooks/running/main-square.png
banner: /images/notebooks/running/main.png
---

# {{ page.title }}

After taking a one-year break from running, I wanted to rebuild my fitness while documenting every decision involved in a complete data science project.

Rather than jumping directly into modelling, I'll start by defining the questions, collecting the data, deciding what to record, and only then move towards exploration and analysis.

The goal is not to optimise my running.

The goal is to document how a data scientist thinks.

<br>

**Status:** {{ page.status | capitalize }}



{% if page.slug %}

{% assign chapters = site.posts
    | where: "notebook", page.slug
    | sort: "chapter" %}

{% if chapters.size > 0 %}

<h1>Contents</h1>

<ol class="chapter-list">

{% for chapter in chapters %}

<li>
    <a href="{{ chapter.url | relative_url }}">
        {{ chapter.title }}
    </a>
</li>

{% endfor %}

</ol>

{% endif %}
{% endif %}


<img
    class="notebook-banner"
    src="{{ page.banner | relative_url }}"
    alt="{{ page.title }}">
