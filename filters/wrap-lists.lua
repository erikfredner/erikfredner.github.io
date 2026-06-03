-- Runs AFTER pandoc-crossref.
-- 1. Collects (id, caption) for all Figures with id starting "fig:" and
--    all Tables with id starting "tbl:", in document order. The captions
--    arrive with a pandoc-crossref-applied "Figure N:" / "Table N:" prefix,
--    which is stripped so only the human-readable caption remains.
-- 2. Replaces pandoc-crossref's Header + Div(list-of-fig|list-of-tbl) pairs
--    with a <details class="toc-box ..."> wrapping an <ol> of links. The
--    details/summary chrome matches the TOC; each entry links to its
--    corresponding figure/table id.

local figures = {}
local tables = {}

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

function Figure(fig)
  if fig.identifier and fig.identifier:sub(1, 4) == "fig:" then
    table.insert(figures, {
      id = fig.identifier,
      caption = strip_caption_prefix(caption_inlines(fig.caption)),
    })
  end
end

function Table(tbl)
  if tbl.identifier and tbl.identifier:sub(1, 4) == "tbl:" then
    table.insert(tables, {
      id = tbl.identifier,
      caption = strip_caption_prefix(caption_inlines(tbl.caption)),
    })
  end
end

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

local function transform(blocks)
  local out = {}
  local i = 1
  while i <= #blocks do
    local b, nxt = blocks[i], blocks[i + 1]
    local replaced = false
    if b.t == "Header" and nxt and nxt.t == "Div" then
      local label = pandoc.utils.stringify(b.content)
      if nxt.classes:includes("list-of-fig") then
        for _, blk in ipairs(build_details(figures, label, "list-of-figures-box")) do
          table.insert(out, blk)
        end
        i = i + 2
        replaced = true
      elseif nxt.classes:includes("list-of-tbl") then
        for _, blk in ipairs(build_details(tables, label, "list-of-tables-box")) do
          table.insert(out, blk)
        end
        i = i + 2
        replaced = true
      end
    end
    if not replaced then
      table.insert(out, b)
      i = i + 1
    end
  end
  return out
end

function Pandoc(doc)
  doc.blocks = transform(doc.blocks)
  return doc
end
