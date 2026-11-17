-- Scholarly-article apparatus, driven by frontmatter. Runs on site pages (in
-- PAGE_FILTER_OPTS) and on the article PDFs; does nothing on a page with
-- neither `abstract:` nor `article:`.
--
--   abstract: |              # rendered under the title; also the description
--     ...
--   article:
--     authors:               # in order; url and orcid are optional
--       - name: Erik Fredner
--         orcid: "0000-0002-2993-4961"
--       - name: Luca Messarra
--         url: https://...
--     journal: American Literary History
--     special-issue: Cultural AI   # optional
--     volume: 38
--     issue: 4
--     pages: 386–413         # optional
--     year: 2026
--     month: 12              # optional
--     status: published      # or forthcoming
--     doi: 10.1093/alh/ajag058     # optional
--     data: https://...      # optional: data and code
--     notice: "..."          # optional: the publisher's required wording, verbatim
--     full-text: false       # optional: the page holds only an abstract
--
-- HTML: sets `description` from the abstract (it outranks a frontmatter
-- description), and builds the values templates/base.html renders: the byline
-- (co-authored articles only), the Chicago bibliography citation (the CV's
-- form), the status line, the PDF/BibTeX/RIS links, and the Highwire
-- `citation_*` meta tags that Google Scholar and Zotero read. The tags are
-- emitted only when the page holds the full text: Scholar indexes an
-- author-hosted manuscript as a version of the article, but an abstract-only
-- page offers it nothing to index.
--
-- LaTeX (the article PDFs, `make articles`): sets pandoc's own `author`,
-- `date` (the status line and citation), and `thanks` (the notice); drops the
-- web-only `toc`/`lof`/`lot`; and points images at what pdfLaTeX can read:
-- an SVG at its PDF conversion in build/article/figs/, anything else at
-- src/images/ itself.
--
-- The BibTeX and RIS files come from scripts/build_citations.py, which reads
-- the same frontmatter; keep the two in step.

local stringify = pandoc.utils.stringify

local function str(v)
  if v == nil then return nil end
  local s = stringify(v)
  if s == "" then return nil end
  return s
end

local function stem()
  local f = PANDOC_STATE.input_files[1] or ""
  return (f:match("([^/]+)%.md$"))
end

local function inl(v)
  if v == nil then return pandoc.Inlines({}) end
  if pandoc.utils.type(v) == "Inlines" then return v:clone() end
  if pandoc.utils.type(v) == "Blocks" then return pandoc.utils.blocks_to_inlines(v) end
  return pandoc.Inlines({ pandoc.Str(stringify(v)) })
end

local function full_title(meta)
  local t = inl(meta.title)
  if meta.subtitle then
    t:insert(pandoc.Str(":"))
    t:insert(pandoc.Space())
    t:extend(inl(meta.subtitle))
  end
  return t
end

local function authors(a)
  local out = {}
  for _, au in ipairs(a.authors or {}) do
    local name = str(au.name)
    local given, family = name:match("^(.-)%s+(%S+)$")
    out[#out + 1] = {
      name = name,
      given = given or "",
      family = family or name,
      url = str(au.url),
      orcid = str(au.orcid),
    }
  end
  return out
end

local function doi_url(a)
  local doi = str(a.doi)
  return doi and ("https://doi.org/" .. doi) or nil
end

-- Chicago bibliography form, as on the CV:
--   Fredner, Erik, and Luca Messarra. "Title: Subtitle." *Journal* 38, no. 4 (2026): 386–413. https://doi.org/...
local function citation(meta, a, aus)
  local c = pandoc.Inlines({})
  local function words(s) c:extend(pandoc.Inlines(s)) end
  for i, au in ipairs(aus) do
    if i == 1 then
      words(au.family .. (au.given ~= "" and (", " .. au.given) or ""))
    else
      words((#aus > 2 and ", " or ", ") .. (i == #aus and "and " or "") .. au.name)
    end
  end
  words(". ")
  local title = full_title(meta)
  local last = stringify(title):sub(-1)
  c:insert(pandoc.Str("“"))
  c:extend(title)
  c:insert(pandoc.Str((last:match("[%?!]") and "" or ".") .. "”"))
  c:insert(pandoc.Space())
  if a["special-issue"] then
    words("In “" .. str(a["special-issue"]) .. ",” special issue, ")
  end
  c:insert(pandoc.Emph(inl(a.journal)))
  local vol = str(a.volume)
  if vol then words(" " .. vol) end
  local issue = str(a.issue)
  if issue then words(", no. " .. issue) end
  if str(a.status) == "forthcoming" then
    words(" (forthcoming)")
  else
    words(" (" .. str(a.year) .. ")")
    local pages = str(a.pages)
    if pages then words(": " .. pages) end
  end
  words(".")
  local d = doi_url(a)
  if d then
    c:insert(pandoc.Space())
    c:insert(pandoc.Link(d, d))
  end
  return c
end

local function status_line(a)
  local full = a["full-text"] ~= false
  local forthcoming = str(a.status) == "forthcoming"
  if full then
    return forthcoming and "Accepted manuscript of the article forthcoming as"
      or "Accepted manuscript of the article published as"
  end
  return forthcoming and "Forthcoming as" or "Published as"
end

local function html_meta(meta, a, aus)
  local s = stem()
  local site = str(meta["site-url"]) or ""
  local full = a["full-text"] ~= false

  local byline = pandoc.Inlines({})
  if #aus > 1 then
    for i, au in ipairs(aus) do
      if i > 1 then
        byline:extend(pandoc.Inlines(i == #aus and (#aus > 2 and ", and " or " and ") or ", "))
      end
      byline:insert(au.url and pandoc.Link(au.name, au.url) or pandoc.Str(au.name))
    end
    meta["article-byline"] = byline
  end

  meta["article-status"] = pandoc.Inlines(status_line(a) .. ":")
  meta["article-citation"] = citation(meta, a, aus)
  if a.notice then meta["article-notice"] = inl(a.notice) end
  if str(a.data) then meta["article-data"] = str(a.data) end
  if full then meta["article-pdf"] = s .. ".pdf" end
  meta["article-bib"] = s .. ".bib"
  meta["article-ris"] = s .. ".ris"

  if not full then return end
  local tags = {}
  local function tag(name, content)
    if content then tags[#tags + 1] = { name = name, content = content } end
  end
  tag("citation_title", stringify(full_title(meta)))
  for _, au in ipairs(aus) do
    tag("citation_author", au.name)
    if au.orcid then tag("citation_author_orcid", "https://orcid.org/" .. au.orcid) end
  end
  local date = str(a.year)
  if str(a.month) then date = date .. "/" .. string.format("%02d", tonumber(str(a.month))) end
  tag("citation_publication_date", date)
  tag("citation_journal_title", str(a.journal))
  tag("citation_volume", str(a.volume))
  tag("citation_issue", str(a.issue))
  local pages = str(a.pages)
  if pages then
    local first, lastp = pages:match("^(%d+)%D+(%d+)$")
    tag("citation_firstpage", first or pages)
    tag("citation_lastpage", lastp)
  end
  tag("citation_doi", str(a.doi))
  tag("citation_language", "en")
  tag("citation_fulltext_html_url", site .. "/" .. s .. ".html")
  tag("citation_pdf_url", site .. "/" .. s .. ".pdf")
  meta["citation-meta"] = tags
end

local function latex_meta(meta, a, aus)
  local names = {}
  for _, au in ipairs(aus) do names[#names + 1] = pandoc.MetaInlines(pandoc.Inlines(au.name)) end
  meta.author = names
  -- \maketitle sets the date in \large; this is reference matter under the
  -- byline, so take it down to the notes' size (the group ends with the date).
  local date = pandoc.Inlines({ pandoc.RawInline("latex", "\\small ") })
  date:extend(pandoc.Inlines(status_line(a) .. ":"))
  date:insert(pandoc.LineBreak())
  date:extend(citation(meta, a, aus))
  if str(a.data) then
    date:insert(pandoc.LineBreak())
    date:extend(pandoc.Inlines("Data and code: "))
    date:insert(pandoc.Link(str(a.data), str(a.data)))
  end
  meta.date = date
  if a.notice then meta.thanks = inl(a.notice) end
  meta.toc, meta.lof, meta.lot = nil, nil, nil
  meta["pdf-title"] = stringify(full_title(meta))
  meta["pdf-author"] = table.concat((function()
    local t = {}
    for _, au in ipairs(aus) do t[#t + 1] = au.name end
    return t
  end)(), ", ")
end

local function Meta(meta)
  if meta.abstract and FORMAT:match("html") then
    meta.description = (stringify(meta.abstract):gsub("%s+", " "))
  end
  local a = meta.article
  if not a then return meta end
  local aus = authors(a)
  if FORMAT:match("latex") then
    latex_meta(meta, a, aus)
  else
    html_meta(meta, a, aus)
  end
  return meta
end

local function Image(el)
  if not FORMAT:match("latex") then return nil end
  local src = el.src
  if src:match("^%a[%w+.-]*:") or src:match("^//") then return nil end
  local name = src:match("([^/]+)$")
  if name:match("%.svg$") then
    el.src = "figs/" .. name:gsub("%.svg$", ".pdf")
  else
    el.src = "../../src/images/" .. name
  end
  return el
end

-- citeproc writes a cited URL as plain text, which LaTeX cannot break, so a
-- long one ran 160pt into the margin. As a link it becomes \url, which xurl
-- (templates/article-pdf.tex) breaks anywhere. Needs this filter to run after
-- --citeproc in the PDF rule.
local function Str(el)
  if not FORMAT:match("latex") then return nil end
  local url, trail = el.text:match("^(https?://.-)([.,;:]?)$")
  if not url then return nil end
  local out = pandoc.Inlines({ pandoc.Link(url, url) })
  if trail ~= "" then out:insert(pandoc.Str(trail)) end
  return out
end

-- HTML: lift a hero (filters/hero.lua's Div, already a <video> or sized
-- <img> by now) out of the body into `hero-block`, which the template places
-- directly under the page header, above the article box, the abstract, and
-- the Contents box. Left in the body, it landed below all three, a 200-word
-- abstract down from the title it illustrates.
local function lift_hero(doc)
  if not FORMAT:match("html") then return nil end
  local first = doc.blocks[1]
  if not (first and first.t == "Div" and first.classes:includes("hero")) then return nil end
  doc.meta["hero-block"] = pandoc.MetaBlocks({ first })
  doc.blocks:remove(1)
  return doc
end

return {
  { Pandoc = lift_hero },
  { Meta = Meta },
  { Image = Image },
  -- Bottom-up, so the links Str creates are never walked again (a top-down
  -- walk descends into each new link's URL text and wraps it forever). A URL
  -- that was already a link's text comes out as a link inside that link; the
  -- Link handler, which runs after its children, unwraps it.
  {
    Str = Str,
    Link = function(el)
      if not FORMAT:match("latex") then return nil end
      el.content = el.content:walk({ Link = function(inner) return inner.content end })
      return el
    end,
  },
}
