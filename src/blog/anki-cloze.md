---
title: "Memorize poems with Anki"
date: 2026-04-06
description: "A tool to automatically create cloze tests for memorizing poems."
---

I often challenge my students to memorize poems. And I have long found [Anki](https://apps.ankiweb.net/) to be the most effective tool for memorizing information. However, using Anki to memorize poetry is tricky because it is time-consuming to make good flashcards by hand.

So I created a tool to make good poetry memorization flashcards for Anki. You can find the code at [this repository](https://github.com/erikfredner/anki-poems).

This will automatically generate cards that treat each line of the poem as a [cloze test](https://en.wikipedia.org/wiki/Cloze_test). Each card shows the test line within the context of thirteen lines of the poem (a number chosen so that it would work well on phones, but also because [thirteen is a good number](https://en.wikipedia.org/wiki/Thirteen_Ways_of_Looking_at_a_Blackbird)).

You can make cards directly from [Poetry Foundation](https://www.poetryfoundation.org/) URLs, or you can make custom cards. [See the README](https://github.com/erikfredner/anki-poems/blob/main/README.md) for details.