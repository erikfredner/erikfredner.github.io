-- Runs AFTER pandoc-crossref (so crossref still sees real Table elements for
-- numbering) and after filters/wrap-lists.lua (so its Table walker has already
-- collected captions for the list-of-tables).
--
-- Wraps every Table in <div class="table-scroll">, which is what keeps a table
-- wider than the stylesheet's reading column from letting the overflow fall
-- through to the document and scroll the entire page sideways on a phone.
--
-- role="region" + tabindex="0" + an accessible name is what makes such a box
-- scrollable by keyboard; an overflow container without them is mouse-only.
-- But those three are applied ONLY to tables that can actually overflow (see
-- `overflows` below). A table that fits needs none of it, and adding it anyway
-- costs twice: a dead tab stop on a box with nothing to scroll, and a landmark
-- in the screen reader's region list that leads nowhere.

-- Width, in characters, of the column at the NARROWEST viewport the site
-- supports, not at its desktop width. A 320px viewport — an older phone, or a
-- 1280px desktop window at 400% zoom, which is the WCAG 1.4.10 reflow case —
-- leaves a 288px column. Table text is 0.95 x 1.25rem of EB Garamond, whose
-- non-space glyphs average 0.41em: ~7.8px per character, or ~37ch. The
-- threshold was once 55, sized to the desktop column, which left three tables
-- that do scroll on a phone (ltm, satire, and 104z; estimates 42-55)
-- unreachable from the keyboard. Measured at 320px, every table estimated at
-- 42 or more overflows and every one at 32 or less fits; 33 sits at the low
-- end of that gap, which errs toward marking. (The figures above were first
-- taken with Source Serif 4 at 1.125rem, ~8.55px per character, and re-checked
-- after the switch to EB Garamond: the same five tables overflow.)
--
-- The cost is that a table which scrolls only on narrow screens is also a tab
-- stop on a desktop where it fits. Under-marking is the worse error: it leaves
-- a genuinely scrollable box unreachable from the keyboard.
local WIDE_MIN_CH = 33

-- th/td carry `padding: 0.4em 0.6em`, so each column is ~2 characters wider
-- than its text at the 0.95em table font size.
local COL_PADDING_CH = 2

-- A table's minimum width is the sum of its columns' longest *words*: prose
-- cells wrap, so their full length never forces the table wide. The stylesheet
-- sets `overflow-wrap: break-word` on th/td, which lets an over-wide word
-- break visually but -- unlike `anywhere` -- does not reduce the element's
-- min-content contribution, so the longest word still sets the floor.
local function longest_word(s)
  local longest = 0
  for word in s:gmatch("%S+") do
    local len = utf8.len(word) or #word
    if len > longest then
      longest = len
    end
  end
  return longest
end

-- Two corrections without which the measurement is badly wrong, both because
-- this filter runs before --citeproc (see the Makefile):
--
--   * A Cite still holds its raw key, so stringify yields something like
--     "[@underwoodTransformationGender2019]" -- a 40-character "word" that
--     never reaches the page, since chicago-notes renders it as a footnote
--     marker. An existing Note renders the same way. Both become a
--     two-character stand-in, the width of the superscript that does appear.
--   * LineBreak and SoftBreak stringify to the empty string, welding the words
--     on either side into one token ("PomerantzKrauseIraniPerrigo"). They are
--     turned back into spaces.
--
-- Left uncorrected, both inflate the estimate and mark tables as scrollable
-- that comfortably fit.
local NORMALIZE = {
  LineBreak = function() return pandoc.Space() end,
  SoftBreak = function() return pandoc.Space() end,
  Cite = function() return pandoc.Str("00") end,
  Note = function() return pandoc.Str("00") end,
}

local function cell_text(cell)
  local parts = {}
  for _, block in ipairs(cell.contents) do
    parts[#parts + 1] = pandoc.utils.stringify(pandoc.walk_block(block, NORMALIZE))
  end
  -- Joined with a space: stringify would otherwise butt one block's last word
  -- against the next block's first.
  return table.concat(parts, " ")
end

local function each_row(tbl, fn)
  for _, row in ipairs(tbl.head.rows) do fn(row) end
  for _, body in ipairs(tbl.bodies) do
    for _, row in ipairs(body.head) do fn(row) end
    for _, row in ipairs(body.body) do fn(row) end
  end
  for _, row in ipairs(tbl.foot.rows) do fn(row) end
end

local function overflows(tbl)
  local widest = {}
  each_row(tbl, function(row)
    for i, cell in ipairs(row.cells) do
      local w = longest_word(cell_text(cell))
      if w > (widest[i] or 0) then
        widest[i] = w
      end
    end
  end)

  local total, columns = 0, 0
  for _, w in pairs(widest) do
    total = total + w
    columns = columns + 1
  end
  return total + columns * COL_PADDING_CH > WIDE_MIN_CH
end

local function caption_text(tbl)
  local caption = tbl.caption
  local long = caption and caption.long
  local first = long and long[1]
  if first and first.content then
    local text = pandoc.utils.stringify(first.content)
    if text ~= "" then
      return text
    end
  end
  return nil
end

-- Naming. A caption is the best name a table has. Failing that, the section it
-- sits in identifies it far better than the old "Table" fallback did: three
-- regions all announced as "Table" told a screen reader user nothing about
-- which was which. Only two tables on the whole site carry captions, so in
-- practice the heading is what does the work.
local last_heading = nil
local tables_under_heading = {}

local function name_for(tbl)
  local caption = caption_text(tbl)
  if caption then
    return caption
  end

  if last_heading and last_heading ~= "" then
    local n = (tables_under_heading[last_heading] or 0) + 1
    tables_under_heading[last_heading] = n
    -- Disambiguate when one section holds several unnamed tables, so the names
    -- stay distinct instead of collapsing back into a set of identical labels.
    if n > 1 then
      return last_heading .. ", table " .. n
    end
    return last_heading
  end

  return "Table"
end

local function Header(header)
  last_heading = pandoc.utils.stringify(header.content)
  return nil
end

-- Row headers. Pipe tables have no syntax for a header column, so a table
-- whose first column labels its rows opts in with a class on its caption line,
-- `: {.row-headers}` (reading-lms's Jeopardy clues: Category / Clue / Answer).
-- `row_head_columns` makes pandoc emit those cells as <th>; `scope="row"` is
-- set explicitly rather than left to the browser's inference for a table with
-- no header row.
local function mark_row_headers(tbl)
  if not tbl.classes:includes("row-headers") then
    return
  end
  for _, body in ipairs(tbl.bodies) do
    body.row_head_columns = 1
    for _, row in ipairs(body.body) do
      row.cells[1].attributes.scope = "row"
    end
  end
end

local function Table(tbl)
  mark_row_headers(tbl)
  local attrs = {}
  if overflows(tbl) then
    attrs = {
      {"role", "region"},
      {"tabindex", "0"},
      {"aria-label", name_for(tbl)},
    }
  end
  -- `false` stops the topdown walk from descending into the Div we just built
  -- and re-wrapping the same table forever.
  return pandoc.Div({tbl}, pandoc.Attr("", {"table-scroll"}, attrs)), false
end

-- Topdown, so a Header is seen before the tables that follow it.
return {{traverse = "topdown", Header = Header, Table = Table}}
