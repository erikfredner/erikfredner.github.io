-- Runs AFTER pandoc-crossref (so crossref still sees real Table elements for
-- numbering) and after filters/wrap-lists.lua (so its Table walker has already
-- collected captions for the list-of-tables).
--
-- Wraps every Table in <div class="table-scroll">. The syllabus tables run 8-9
-- columns, which is wider than the stylesheet's 65ch column; with no wrapper
-- the overflow falls through to the document and the entire page scrolls
-- sideways on a phone.
--
-- role="region" + tabindex="0" + an accessible name is what makes the box
-- scrollable by keyboard. An overflow container without them can only be
-- scrolled with a pointer, so the content is unreachable without a mouse.
-- The name comes from the table's own caption when it has one, so the landmark
-- is identifiable in a screen reader's landmark list.

local function label_for(tbl)
  local caption = tbl.caption
  local long = caption and caption.long
  local first = long and long[1]
  if first and first.content then
    local text = pandoc.utils.stringify(first.content)
    if text ~= "" then
      return text
    end
  end
  return "Table"
end

function Table(tbl)
  return pandoc.Div({tbl}, pandoc.Attr("", {"table-scroll"}, {
    {"role", "region"},
    {"tabindex", "0"},
    {"aria-label", label_for(tbl)},
  }))
end
