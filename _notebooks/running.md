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

**Status:** {{ page.status | capitalize }}

<br>

This notebook started with a simple idea: I wanted to use a personal experience as the basis for a data science project.

I opted to use my new running programme because I collect a lot of data with my connected watch, which provide plenty information to document many of the key steps of a real data science project.

The scientific objectives of this project are rather modest (e.g. can I predict my 5k time?) and likely of little direct interest to the public.

But as with all my notebooks, the interesting part is not the destination, but the journey.

Over the coming weeks, I'll document every important step of the project.

- defining useful questions
- deciding what data to collect
- building a database
- exploring the data
- making mistakes
- changing direction
- and gradually refining the project as new information becomes available.

My promise to you is that I will not hide anything. You will read about every step, whether it leads to something useful or not. As such, most chapters will actually be about data science.

Running is simply the excuse.


{% if page.slug %}

{% assign chapters = site.posts
    | where: "notebook", page.slug
    | sort: "chapter" %}

{% if chapters.size > 0 %}

<h1>Chapters</h1>

The notebook will track my running program and a new chapter documenting a new stage of the investigation will be published each week.


<ol class="chapter-list">

{% for chapter in chapters %}

<li>
    <a
        href="{{ chapter.url | relative_url }}"
        data-summary="{{ chapter.summary }}"
        class="chapter-link">
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
