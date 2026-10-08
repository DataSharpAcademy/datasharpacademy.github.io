---
layout: default
title: Loose Notes from the Field
permalink: /notebooks/loose-notes/

status: active
order: 2

slug: loose-notes

description: >
  Occasional, personal notes on my work, life and journey as a data scientist. Less data, more feelings, doubts and fears. And some wins.

thumbnail: /images/notebooks/loose-notes/loose-notes-square.png
image: /images/notebooks/loose-notes/loose-notes.png
---

# {{ page.title }}

**Status:** {{ page.status | capitalize }}

<br>

I've recently felt like I wanted to write about some of my experiences since I stopped being a researcher and refocused on data work.

- How I've discovered that I actually enjoy teaching data science;
- How working with data has completely changed over the past couple of years;
- How I deal with the new challenges, constraints, and freedoms of working freelance.

And likely more.

This is a journal. For me to me, and hopefully, to you as well.

There’s no fixed schedule or single storyline here. Entries will appear when I have something I want to share, and you can read them in any order. Think of them as pages gathered over time: sometimes reflective, sometimes unresolved, and always written from where I am now.



{% if page.slug %}

{% assign chapters = site.posts
    | where: "notebook", page.slug
    | sort: "chapter" %}

{% if chapters.size > 0 %}

<h1>Chapters</h1>

<ol class="chapter-list">

{% for chapter in chapters %}

<li>
{% if chapter.status == "published" and chapter.date <= site.time %}

    <a
        href="{{ chapter.url | relative_url }}"
        data-summary="{{ chapter.summary }}"
        class="chapter-link">
        {{ chapter.title }}
    </a>

{% elsif chapter.status == "ongoing"
    or chapter.date > site.time %}

    <em style="color:#888;">
        Coming soon: {{ chapter.title }}
    </em>

{% endif %}
</li>

{% endfor %}

</ol>

{% endif %}
{% endif %}


<img
    class="notebook-banner"
    src="{{ page.image | relative_url }}"
    alt="{{ page.title }}">
