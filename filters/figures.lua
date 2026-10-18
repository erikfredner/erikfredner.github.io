-- Runs AFTER pandoc-crossref, which is what writes the "Figure 1:" label into
-- each caption, and after filters/wrap-lists.lua, whose list of figures strips
-- that label by looking for a bare Str ending in a colon. Once it is inside
-- the span below, wrap-lists no longer finds it and every entry comes out
-- empty.
--
-- Wraps that label in <span class="figure-label"> so style.css can set it apart
-- from the caption text. The label is found as the run of inlines up to the
-- first Str ending in a colon (crossref's default titleDelim), within the first
-- few; a caption that does not start that way is left as it is.
--
-- The image's alt gets the same span (it stringifies away in the attribute).
-- Pandoc marks the <figcaption> aria-hidden only when the caption is identical
-- to the alt, and without that a screen reader reads the caption twice. For
-- the same reason the figure's content must stay a bare image: the tap-to-
-- enlarge control is added by the script in templates/base.html, not here,
-- because wrapping the image in anything (a link, say) also defeats the match.

local function wrap_label(inlines)
  for i = 1, math.min(#inlines, 4) do
    local el = inlines[i]
    if el.t == "Str" and el.text:match(":$") then
      local label, out = pandoc.Inlines({}), pandoc.Inlines({})
      for j, x in ipairs(inlines) do
        (j <= i and label or out):insert(x)
      end
      out:insert(1, pandoc.Span(label, { class = "figure-label" }))
      return out
    end
  end
  return nil
end

function Figure(fig)
  local long = fig.caption.long
  local labelled = #long > 0 and (long[1].t == "Plain" or long[1].t == "Para")
    and wrap_label(long[1].content)
  if not labelled then
    return nil
  end
  long[1].content = labelled
  fig.content = fig.content:walk({
    Image = function(img)
      img.caption = wrap_label(img.caption) or img.caption
      return img
    end,
  })
  return fig
end
