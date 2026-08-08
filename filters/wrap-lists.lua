-- Runs AFTER pandoc-crossref.
-- 1. Collects (id, caption) for all Figures with id starting "fig:" and
--    all Tables with id starting "tbl:", in document order. The captions
--    arrive with a pandoc-crossref-applied "Figure N:" / "Table N:" prefix,
--    which is stripped so only the human-readable caption remains.
-- 2. Replaces pandoc-crossref's Header + Div(list-of-fig|list-of-tbl) pairs
--    with a <details class="toc-box ..."> wrapping an <ol> of links. The
--    details/summary chrome matches the TOC; each entry links to its
--    corresponding figure/table id.

-- The figure and table paths are identical apart from the id prefix pandoc-crossref
-- uses ("fig:"/"tbl:"), the class it marks its placeholder Div with, and the
-- stylesheet hook on the resulting box. Keeping the three in one table means a
-- new kind of list is one entry rather than a fourth copy of the same code.
local KINDS = {
  {prefix = "fig:", placeholder = "list-of-fig", box = "list-of-figures-box"},
  {prefix = "tbl:", placeholder = "list-of-tbl", box = "list-of-tables-box"},
}

-- Collected captions, in document order, keyed by placeholder class.
local collected = {}
for _, kind in ipairs(KINDS) do
  collected[kind.placeholder] = {}
end

local function strip_caption_prefix(inlines)
  local i, n = 1, #inlines
  while i <= n do
    local el = inlines[i]
    if el.t == "Str" and el.text:sub(-1) == ":" then
      i = i + 1
      if inlines[i] and inlines[i].t == "Space" then
        i = i + 1
      end
      break
    end
    i = i + 1
  end
  local out = {}
  while i <= n do
    table.insert(out, inlines[i])
    i = i + 1
  end
  return out
end

local function caption_inlines(caption)
  if not caption then return {} end
  local long = caption.long or {}
  local first = long[1]
  if not first or not first.content then return {} end
  return first.content
end

-- One collector for both element types: crossref numbers Figures and Tables the
-- same way, and only the id prefix distinguishes one it numbered from one the
-- author gave an unrelated id.
local function collect(el, kind)
  if el.identifier and el.identifier:sub(1, #kind.prefix) == kind.prefix then
    table.insert(collected[kind.placeholder], {
      id = el.identifier,
      caption = strip_caption_prefix(caption_inlines(el.caption)),
    })
  end
end

function Figure(fig) collect(fig, KINDS[1]) end

function Table(tbl) collect(tbl, KINDS[2]) end

local function build_details(items, label_text, extra_class)
  local list_items = {}
  for _, item in ipairs(items) do
    local link = pandoc.Link(item.caption, "#" .. item.id)
    table.insert(list_items, {pandoc.Plain({link})})
  end
  return {
    pandoc.RawBlock("html",
      '<details class="toc-box ' .. extra_class .. '">'
      .. '<summary class="toc-label">' .. label_text .. '</summary>'),
    pandoc.OrderedList(list_items),
    pandoc.RawBlock("html", '</details>'),
  }
end

-- crossref renders each requested list as a Header followed by an empty Div
-- carrying the placeholder class. Return the matching KIND for such a pair.
local function placeholder_kind(block, next_block)
  if block.t ~= "Header" or not next_block or next_block.t ~= "Div" then
    return nil
  end
  for _, kind in ipairs(KINDS) do
    if next_block.classes:includes(kind.placeholder) then
      return kind
    end
  end
  return nil
end

local function transform(blocks)
  local out = {}
  local i = 1
  while i <= #blocks do
    local kind = placeholder_kind(blocks[i], blocks[i + 1])
    if kind then
      -- The Header supplies the label, so it is consumed along with the Div.
      local label = pandoc.utils.stringify(blocks[i].content)
      for _, blk in ipairs(build_details(collected[kind.placeholder], label, kind.box)) do
        table.insert(out, blk)
      end
      i = i + 2
    else
      table.insert(out, blocks[i])
      i = i + 1
    end
  end
  return out
end

function Pandoc(doc)
  doc.blocks = transform(doc.blocks)
  return doc
end
