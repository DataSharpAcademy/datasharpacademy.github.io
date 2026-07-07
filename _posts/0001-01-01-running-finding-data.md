---
layout: default
title: "Finding the data"
date: 2026-07-07

notebook: running
chapter: 1

project: Running

summary: >
  Choosing the right data is the first challenge of any real data project.

idea: >
  The data you collect determine the questions you can answer.

status: published

keywords:
  - data collection
  - running
  - github
  - API
  - virtual environment
  - JSON
  - Python
  

linkedin:
github:
---


Last week I started a new 18-week running program, which means I started collecting data.

But what data do I have? And more importantly, do I really "have" them?

The answer to the latter is unfortunately "no". At least not directly.

I can open Garmin Connect and see plenty of beautiful graphs about my runs. So I know the data exist. The problem is that seeing data isn’t the same as having data.

I'm starting this project without a clear idea how to get them.

I know it's possible; I just don't know how.

> Most data science projects don’t begin with data. They begin with an idea. Finding the data is often the first challenge.


# The obvious start

My data being collected by my Garmin device, I first started looking for my data on the Garmin websites. And I found this one: [https://www.garmin.com/account/datamanagement/](https://www.garmin.com/account/datamanagement/) where one can request to download all their data.

This isn’t quite what I was hoping for. I don't want to have to make a manual request and wait for a while everytime I want to update my data. But if the data are good, I can live with that.

After perhaps an hour, I receive an email for Garmin to download my data bundle. I diligently do that and open the archive. And here are how the downloaded data look like 👇

<img
    class="post-image"
    src="{{ '/images/notebooks/running/garminConnect-bundle.png' | relative_url }}"
    alt="Garmin dashboard">


The archive contains dozens of folders, themselves filled with hundreds of `JSON` files. If I zoom onto one of these json files, the data look like that:

```json
[
    {"userProfilePK":47820xx,"deviceId":3432548632,"calendarDate":"2023-05-21","timestamp":"2023-05-20T22:05:05.0","altitudeAcclimationTimestamp":"2023-05-20T22:05:05.0","previousAltitudeAcclimationTimestamp":"2023-05-20T22:05:05.0","heatAcclimationTimestamp":"2023-05-20T22:05:05.0","previousHeatAcclimationTimestamp":"2023-05-20T22:05:05.0","altitudeAcclimation":0,"previousAltitudeAcclimation":0,"heatAcclimationPercentage":0,"previousHeatAcclimationPercentage":0,"altitudeAcclimationLocalTimestamp":"2023-05-21T00:05:05.0"},
    {"userProfilePK":47820xx,"deviceId":3432548632,"calendarDate":"2023-05-21","timestamp":"2023-05-21T08:50:09.0","altitudeAcclimationTimestamp":"2023-05-21T08:50:09.0","previousAltitudeAcclimationTimestamp":"2023-05-21T08:50:09.0","heatAcclimationTimestamp":"2023-05-21T08:50:09.0","previousHeatAcclimationTimestamp":"2023-05-21T08:50:09.0","altitudeAcclimation":0,"previousAltitudeAcclimation":0,"heatAcclimationPercentage":0,"previousHeatAcclimationPercentage":0,"altitudeAcclimationLocalTimestamp":"2023-05-21T10:50:09.0"},
    ...
]
```

The data are structured, but not in a format that’s convenient for analysis. To make any analysis, I would have:

1. to make sense of all these files to find the specific information I need for my analysis;
2. write scripts to extract and store it in a tabular format.


That's feasible but only if I don't have any alternative.



# Looking for alternatives

At this point, I know I can access my data. But before diving in head-on, I want to take some time to explore more options.

## The API

Garmin does have an API, i.e. an interface that one can query to extract data. Unfortunately, it is not accessible to those who want to make simple projects such as myself.

Although APIs are often the best way to acquire data, especially when they need to be regularly updated, it cannot be my solution this time.


## You don't have to reinvent the wheel

One of the best things about modern data science is the amount of high-quality open-source software already available.

> When you have to do something that feels quite complex, or at least time comsuming, do a quick search online. Chances are high you'll find a tool that does what you want.

I could have spent several evenings writing code to extract and reorganise the Garmin files myself. But that's not the problem I’m interested in solving.


That's why I started to look for tools and I found the `Python`

[https://github.com/tcgoetz/GarminDB](https://github.com/tcgoetz/GarminDB)




<img
    class="post-image"
    src="{{ '/images/notebooks/running/garminDB-github.png' | relative_url }}"
    alt="Garmin dashboard">


<br>

It does exactly what I was hoping to find. It gets the data from Garmin automatically, compiles all these files on its own, and create tabular relational databases.

But before I can use it, I first need to install it properly and organise the project so that everything remains easy to update over the coming months.

That may sound like a technical detail, but experience has taught me that spending a little time organising a project at the beginning saves a tremendous amount of time later.

That's what we'll do next.
In the next chapter, I will show you how to use this tool.
