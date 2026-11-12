-- Removes the PDF-only markup from src/cv.md so the web page renders exactly
-- as if it were not there. src/cv.md is the single source for both the web CV
-- and the two PDF CVs (see filters/cv-pdf.lua, which reads this markup):
--
--   - []{.short} Entry text    an empty span marking an entry for the short
--                              PDF. Removed here, with the space after it.
--   ## Heading {.pdf-urls pdf-short="Selected X"}
--                              classes and attributes beginning with `pdf-`
--                              on a heading. Removed here, so neither reaches
--                              the <section> that --section-divs builds.
--   ::: pdf-only               a block only the PDFs show. Dropped here.
--   ::: web-only               a block only the web page shows. Unwrapped.
--
-- Runs first among the content filters, so no later filter ever sees the
-- markup. On every page other than cv.md it finds nothing to do.

local function is_marker(el)
  return el and el.t == "Span" and #el.content == 0 and el.classes:includes("short")
end

local function strip_markers(inlines)
  local out = pandoc.Inlines({})
  local i = 1
  while i <= #inlines do
    local el = inlines[i]
    if is_marker(el) then
      -- Swallow one adjacent space: the one after a leading marker, or the one
      -- already emitted before a trailing marker.
      if inlines[i + 1] and inlines[i + 1].t == "Space" then
        i = i + 1
      elseif #out > 0 and out[#out].t == "Space" then
        out:remove(#out)
      end
    else
      out:insert(el)
    end
    i = i + 1
  end
  return out
end

local function strip_pdf_attrs(attr)
  local classes = pandoc.List({})
  for _, c in ipairs(attr.classes) do
    if not c:match("^pdf%-") then classes:insert(c) end
  end
  attr.classes = classes
  local attributes = {}
  for k, v in pairs(attr.attributes) do
    if not k:match("^pdf%-") then attributes[k] = v end
  end
  attr.attributes = attributes
  return attr
end

return {
  {
    Inlines = strip_markers,
    Header = function(h)
      h.attr = strip_pdf_attrs(h.attr)
      return h
    end,
    Div = function(div)
      if div.classes:includes("pdf-only") then
        return {}
      elseif div.classes:includes("web-only") then
        return div.content
      end
    end,
  },
}
