-- Turns src/cv.md into the body of a PDF CV, for templates/cv.latex. The
-- `cv-variant` metadata picks which one:
--
--   full   every entry on the web CV
--   short  only entries marked `[]{.short}`, and only the sections that have
--          one; a section heading may carry `pdf-short="Selected X"` to be
--          retitled in this version
--
-- src/cv.md is written for the web (filters/cv-web.lua strips the PDF markup
-- there), so this filter also adapts it to the conventions of the former
-- standalone LaTeX CV:
--
--   - Entry text, punctuation included, is exactly the web's: one-line
--     entries end without a period ("Oregon State University, 2025--") in both.
--   - Every run of entries is one `entries` list. `###` subheadings (the years
--     under Presentations, the parts of Public Humanities) become italic
--     \subsection headings. The short CV keeps a subheading only when an entry
--     under it is kept, and drops every other non-list block.
--   - A list whose entries all end without punctuation is a one-line list,
--     set with no space between items; a list with any entry ending in a
--     period, question mark, or exclamation point is a prose list and gets the
--     template's default 2pt.
--   - Under a heading with the `.pdf-urls` class (Publications), each entry's
--     first link is also printed as a URL at the end of the entry, since a
--     printed CV cannot follow the hyperlinked title.
--   - Relative links resolve against `site-url`; inline code becomes plain
--     text (the template loads no monospace face).
--
-- `::: pdf-only` blocks are kept and `::: web-only` blocks are dropped.

local variant = "full"
local site_url = "https://fredner.org"

local function latex(inlines)
  local out = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "latex")
  return (out:gsub("%s+$", ""))
end

local function absolute(url)
  if url:match("^%a[%w+.-]*:") or url:match("^#") then
    return url
  end
  return site_url .. "/" .. url:gsub("^/", "")
end

local function is_marker(el)
  return el.t == "Span" and #el.content == 0 and el.classes:includes("short")
end

-- An entry's blocks flattened to inlines, with the short marker removed.
-- Returns the inlines and whether the marker was present.
local function entry_inlines(blocks)
  local out = pandoc.Inlines({})
  local short = false
  for _, b in ipairs(blocks) do
    if b.t == "Plain" or b.t == "Para" then
      if #out > 0 then out:insert(pandoc.Space()) end
      out:extend(b.content)
    end
  end
  local kept = pandoc.Inlines({})
  for _, el in ipairs(out) do
    if is_marker(el) then
      short = true
    else
      kept:insert(el)
    end
  end
  while #kept > 0 and kept[1].t == "Space" do kept:remove(1) end
  while #kept > 0 and kept[#kept].t == "Space" do kept:remove(#kept) end
  return kept, short
end

local function ends_in_punctuation(inlines)
  local text = pandoc.utils.stringify(inlines)
  -- stringify renders Quoted as curly quotes, so look past any closing ones.
  -- (They are multibyte, so they cannot go in a Lua character class.)
  local prev
  repeat
    prev = text
    text = text:gsub("”$", ""):gsub("’$", ""):gsub("[\"']$", "")
  until text == prev
  return text:match("[%.%?!]$") ~= nil
end

local function first_link(inlines)
  local found
  pandoc.Inlines(inlines):walk({
    Link = function(l)
      found = found or l.target
    end,
  })
  return found
end

local function heading_title(h)
  if variant == "short" and h.attributes["pdf-short"] then
    return pandoc.Inlines({ pandoc.Str(h.attributes["pdf-short"]) })
  end
  return h.content
end

-- Split the document into level-2 sections of "parts": lists of entries,
-- subheadings, and other blocks.
local function sections_of(blocks)
  local sections = {}
  local cur
  for _, b in ipairs(blocks) do
    if b.t == "Header" and b.level <= 2 then
      cur = { header = b, parts = {} }
      table.insert(sections, cur)
    elseif cur == nil then
      -- Nothing precedes the first heading in cv.md; ignore it if it ever does.
    elseif b.t == "Header" then
      table.insert(cur.parts, { kind = "sub", header = b })
    elseif b.t == "BulletList" then
      local last = cur.parts[#cur.parts]
      if not (last and last.kind == "list") then
        last = { kind = "list", items = {} }
        table.insert(cur.parts, last)
      end
      for _, item in ipairs(b.content) do
        local inlines, short = entry_inlines(item)
        table.insert(last.items, { inlines = inlines, short = short })
      end
    else
      table.insert(cur.parts, { kind = "block", block = b })
    end
  end
  return sections
end

local function render_list(items, pdf_urls)
  local prose = false
  for _, it in ipairs(items) do
    if ends_in_punctuation(it.inlines) then prose = true end
  end
  local out = pandoc.Blocks({
    pandoc.RawBlock("latex", prose and "\\begin{entries}" or "\\begin{entries}[0pt]"),
  })
  for _, it in ipairs(items) do
    local inlines = it.inlines
    if pdf_urls then
      local url = first_link(inlines)
      -- Links into this site are left as hyperlinked titles only: the URL of
      -- a page about the work is no help on paper, and printing them pushes
      -- the short CV onto a third page.
      if url and url:sub(1, #site_url) ~= site_url then
        inlines:extend({ pandoc.Space(), pandoc.Link({ pandoc.Str(url) }, url), pandoc.Str(".") })
      end
    end
    local plain = pandoc.Inlines({ pandoc.RawInline("latex", "\\item ") })
    plain:extend(inlines)
    out:insert(pandoc.Plain(plain))
  end
  out:insert(pandoc.RawBlock("latex", "\\end{entries}"))
  return out
end

local function render(sections)
  local out = pandoc.Blocks({})
  for _, s in ipairs(sections) do
    local parts = {}
    for _, p in ipairs(s.parts) do
      if p.kind == "list" then
        local items = {}
        for _, it in ipairs(p.items) do
          if variant == "full" or it.short then table.insert(items, it) end
        end
        if #items > 0 then table.insert(parts, { kind = "list", items = items }) end
      elseif variant == "full" or p.kind == "sub" then
        table.insert(parts, p)
      end
    end
    -- A subheading survives only if entries follow it (in the short CV, the
    -- years with no marked presentations go).
    for i = #parts, 1, -1 do
      if parts[i].kind == "sub" and not (parts[i + 1] and parts[i + 1].kind == "list") then
        table.remove(parts, i)
      end
    end
    if #parts > 0 then
      local pdf_urls = s.header.classes:includes("pdf-urls")
      out:insert(pandoc.RawBlock("latex", "\\section{" .. latex(heading_title(s.header)) .. "}"))
      for _, p in ipairs(parts) do
        if p.kind == "list" then
          out:extend(render_list(p.items, pdf_urls))
        elseif p.kind == "sub" then
          out:insert(pandoc.RawBlock("latex", "\\subsection{" .. latex(p.header.content) .. "}"))
        else
          out:insert(p.block)
        end
      end
    end
  end
  return out
end

function Pandoc(doc)
  if doc.meta["cv-variant"] then
    variant = pandoc.utils.stringify(doc.meta["cv-variant"])
  end
  if doc.meta["site-url"] then
    site_url = pandoc.utils.stringify(doc.meta["site-url"])
  end
  assert(variant == "full" or variant == "short", "cv-variant must be full or short")

  doc = doc:walk({
    Div = function(div)
      if div.classes:includes("web-only") then
        return {}
      elseif div.classes:includes("pdf-only") then
        return div.content
      end
    end,
    Code = function(c) return pandoc.Str(c.text) end,
    -- Tie "no. 1" and spaced initials ("J. D. Porter") with a no-break space,
    -- which the LaTeX writer emits as ~, as the LaTeX CV did by hand.
    Inlines = function(inlines)
      for i = #inlines - 2, 1, -1 do
        local a, sp, b = inlines[i], inlines[i + 1], inlines[i + 2]
        if a.t == "Str" and sp.t == "Space" and b.t == "Str"
            and (a.text:match("^no%.$") or (a.text:match("^%u%.$") and b.text:match("^%u%."))) then
          inlines[i] = pandoc.Str(a.text .. "\u{a0}" .. b.text)
          inlines:remove(i + 2)
          inlines:remove(i + 1)
        end
      end
      return inlines
    end,
    Link = function(l)
      l.target = absolute(l.target)
      return l
    end,
  })

  doc.blocks = render(sections_of(doc.blocks))
  doc.meta["pdf-title"] = variant == "short" and "Erik Fredner CV" or "Erik Fredner CV (Full)"
  return doc
end
