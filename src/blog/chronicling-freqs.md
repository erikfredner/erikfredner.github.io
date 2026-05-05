---
title: "Chronicling America Word Frequencies"
date: 2026-04-21
description: "Estimating nineteenth-century American English word distributions."
draft: true
---

Computational literary studies often analyzes word frequencies over time. Consistent increases or decreases in word frequencies suggest that interesting changes may be happening. But one of the correct and difficult objections that observations of such trends raises is, "Change relative to what?"

"The past" is the implicit rejoinder. It is one thing to observe differences in word frequencies between the Henry James of the 1870s and the Henry James of the 1900s and claim a change within the same author. It is another to observe differences in novels published in the 1870s and novels published in the 1900s because there are so many possible explanations for the observed differences: Different authors, changes in the form and function of the novel, changes in language, etc.

For literatures in English, some have compared American and British word frequencies in the same period, which reveals obvious differences (*color* vs. *colour*), as well as interpretively tantalizing differences of uncertain statistical significance (e.g., American authors appear to be much more likely to use the word *black*, though not always in the context of race). Within a national tradition, comparing the present to the recent past is another common technique that is freighted with difficult assumptions depending on the research question. [Like Scottish soldiers' chest sizes](https://www.jstor.org/stable/48593834), there is no particular reason to think that an unusually high prevalence of *vampire* in 1897 predicts a comparable distribution in 1898 and beyond. These remain hard problems, and I am not aware of anyone who thinks they have finally solved them.

One thing that we can do is compare trends in works of fiction to trends in comparable corpora. This allows us to evaluate the extent to which changes observed in one corpus (e.g., [Gale American Fiction](https://www.gale.com/product-catalog/primary-sources/american-fiction)) are distinctive. Such comparisons yield a bit more information to disambiguate whether a change is attributable to shifts in language usage generally, or to changes internal to a particular form. A good example is the struggle between *supper* and *dinner* in American English over the ninteenth century. The increase of *dinner* and the decrease of *supper* in works of American literature is better explained by an ongoing linguistic shift than a transformation of how often the last meal of the day is represented in fiction.

Word frequencies from periodicals represent a good basis for comparison. As the [Viral Texts project](https://viraltexts.org/) has demonstrated, while nineteenth century periodicals contain extensive reprintings of works of literature, they also contain large swaths of ordinary reporting on current events, and plainly factored into the reading and writing of literary authors.

According to the Library of Congress,

> [Chronicling America](https://guides.loc.gov/chronicling-america/about-the-collection) currently contains millions of newspaper pages published through 1963 from all 50 states, the District of Columbia, Puerto Rico, and the U.S. Virgin Islands.

The LC has also recently (i.e., in mid-2026) updated their data sets to include many new periodicals collected from around the country.

I have used it to generate a database containing annualized word frequencies derived from the OCR data associated with the page images. The database is quite large (128 GB), so I can't host it here, but I can share [the code used to generate it](https://github.com/erikfredner/chronicling-freqs). For those interested in running this themselves, due to the LC's API rate limits, be forewarned that this took about five days to run on my computer, and requires at least a few hundred gigabytes of free space to download, process, and delete the structured text files.