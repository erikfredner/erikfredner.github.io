-- Tufte CSS margin-figure transform.
--
-- Policy: every Figure becomes a Tufte margin figure by default. To opt out
-- and render a normal full-width figure instead, mark the image (or figure)
-- with `.fullwidth`.
--
-- Input markdown:
--   ![caption](src){#fig:foo}              -> margin figure (default)
--   ![caption](src){#fig:foo .fullwidth}   -> full-width figure (pandoc default;
--                                             picked up by `figure.fullwidth`
--                                             rules in vendor/tufte/tufte.css)
--
-- For the default case this filter rewrites the Figure block as a RawBlock
-- following the upstream Tufte CSS margin-figure pattern:
--
--   <figure id="fig:foo">
--     <label for="mn-fig-foo" class="margin-toggle">&#8853;</label>
--     <input type="checkbox" id="mn-fig-foo" class="margin-toggle"/>
--     <span class="marginnote">Figure N: caption text</span>
--     <img src="src" alt="..." />
--   </figure>
--
-- The marginnote floats into the right sidenote column; the image stays
-- in the main text column. The hidden checkbox + label pair is Tufte
-- CSS's mobile show/hide toggle for marginnotes.
--
-- Must run AFTER pandoc-crossref so the caption already carries the
-- "Figure N:" prefix, and after citeproc so any citations inside captions
-- are resolved before HTML serialization.

local function html_escape_attr(s)
  return (s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function inlines_to_html(inlines)
  if not inlines or #inlines == 0 then return "" end
  local s = pandoc.write(pandoc.Pandoc({pandoc.Plain(inlines)}), "html")
  return (s:gsub("%s+$", ""))
end

local function has_fullwidth(fig)
  if fig.classes and fig.classes:includes("fullwidth") then
    return true
  end
  local found = false
  pandoc.walk_block(fig, {
    Image = function(img)
      if not found and img.classes:includes("fullwidth") then
        found = true
      end
    end,
  })
  return found
end

local function find_first_image(fig)
  local found = nil
  pandoc.walk_block(fig, {
    Image = function(img)
      if not found then found = img end
    end,
  })
  return found
end

function Figure(fig)
  if has_fullwidth(fig) then return nil end

  local img = find_first_image(fig)
  if not img then return nil end

  local fig_id = fig.identifier or ""
  local mn_id = "mn-" .. fig_id:gsub("[^%w%-]", "-")

  local caption_inlines = {}
  if fig.caption and fig.caption.long and fig.caption.long[1] and fig.caption.long[1].content then
    caption_inlines = fig.caption.long[1].content
  end
  local caption_html = inlines_to_html(caption_inlines)

  local alt = pandoc.utils.stringify(img.caption or {})

  local id_attr = fig_id ~= "" and (' id="' .. html_escape_attr(fig_id) .. '"') or ""
  local marginnote = caption_html ~= ""
    and ('<span class="marginnote">' .. caption_html .. '</span>')
    or ''

  local html = '<figure' .. id_attr .. '>'
    .. '<label for="' .. html_escape_attr(mn_id) .. '" class="margin-toggle">&#8853;</label>'
    .. '<input type="checkbox" id="' .. html_escape_attr(mn_id) .. '" class="margin-toggle"/>'
    .. marginnote
    .. '<img src="' .. html_escape_attr(img.src) .. '" alt="' .. html_escape_attr(alt) .. '" />'
    .. '</figure>'

  return pandoc.RawBlock("html", html)
end
