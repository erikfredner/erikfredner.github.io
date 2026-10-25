-- Runs on site pages only, after filters/webp.lua and filters/og-image.lua, and
-- is deliberately left out of the feed fragments. Turns the linked poster that
-- filters/hero.lua leaves for a video hero into the video itself:
--
--   <div class="hero"><a href="x.mp4"><img src="x-poster.webp" ...></a></div>
--   becomes
--   <div class="hero"><video src="x.mp4" poster="x-poster.webp" ...></video></div>
--
-- By now the poster's src is the published .webp and it carries image-size's
-- width/height, which the <video> reuses to reserve its box.
--
-- The video has `controls` (pause and replay; an animation longer than five
-- seconds needs a way to stop it) and no `autoplay`: the template's script
-- starts it unless the reader prefers reduced motion. Without the script, or
-- with reduced motion, it waits on its poster, and `preload="metadata"` keeps
-- it from downloading the whole file until someone presses play. `muted` is
-- what lets a script start playback without a click.

local function attr(s)
  return (s:gsub("&", "&amp;"):gsub('"', "&quot;"):gsub("<", "&lt;"))
end

function Div(el)
  if not el.classes:includes("hero") then return nil end
  local plain = el.content[1]
  local link = plain and plain.t == "Plain" and plain.content[1]
  local img = link and link.t == "Link" and link.content[1]
  if not (img and img.t == "Image") then return nil end

  local parts = {
    '<video src="' .. attr(link.target) .. '"',
    ' poster="' .. attr(img.src) .. '"',
  }
  local w, h = img.attributes.width, img.attributes.height
  if w and h then
    parts[#parts + 1] = ' width="' .. attr(w) .. '" height="' .. attr(h) .. '"'
  end
  local alt = pandoc.utils.stringify(img.caption)
  if alt ~= "" then
    parts[#parts + 1] = ' aria-label="' .. attr(alt) .. '"'
  end
  parts[#parts + 1] = ' controls muted playsinline preload="metadata"></video>'

  return pandoc.Div({ pandoc.RawBlock("html", table.concat(parts)) }, el.attr)
end
