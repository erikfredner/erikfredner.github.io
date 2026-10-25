-- Runs FIRST, before filters/image-size.lua. Turns `hero:` frontmatter into an
-- image at the very top of the body, wrapped in <div class="hero">:
--
--   hero: ../images/chart.svg
--   hero-alt: "Line chart of ..."
--
-- The path is written exactly as an image in the same file's body would be
-- (`../images/...` from a blog post, `images/...` from a top-level page), and
-- `make prune-images` finds it there like any other reference. `hero-alt` is
-- optional; without it the image is treated as decorative (alt="").
--
-- It is inserted into the AST rather than placed by the template so that every
-- later filter treats it as an ordinary image: image-size reserves its box,
-- webp.lua rewrites a .png/.jpg src, og-image.lua picks it up as the page's
-- first image, and in the feed fragments absolutize.lua makes its URL absolute.
-- The template would have had to repeat each of those.
--
-- It sits in a Div, not a Figure, so it gets no "Figure N:" number, no List of
-- Figures entry, and no tap-to-enlarge button (the template's script only wraps
-- `figure > img`).
--
-- A video hero (.mp4/.webm) also names a still to stand in for it:
--
--   hero: ../images/nyc_map_animation.mp4
--   hero-poster: ../images/nyc_map_animation-poster.png
--
-- Here the poster is the Image, linked to the video. That keeps the still on
-- every image filter's path (sized, converted to WebP, the page's og:image, a
-- format link previews can actually show) and leaves the feed, whose readers
-- mostly strip <video>, a still that opens the video. filters/hero-video.lua,
-- run on site pages only, then swaps the link for a real <video>.

local VIDEO_EXTS = { mp4 = true, webm = true }

local function meta_string(v)
  if not v then return nil end
  local s = pandoc.utils.stringify(v)
  return s ~= "" and s or nil
end

function Pandoc(doc)
  local src = meta_string(doc.meta.hero)
  if not src then return nil end

  local ext = src:match("%.(%w+)$")
  local is_video = ext and VIDEO_EXTS[ext:lower()]
  local poster = is_video and meta_string(doc.meta["hero-poster"])
  if is_video and not poster then
    io.stderr:write("hero.lua: video hero " .. src .. " needs a hero-poster; skipped\n")
    return nil
  end

  -- Pandoc omits `alt` entirely when the description is empty, and an <img>
  -- with no alt at all is announced by its filename; decorative needs alt="".
  local alt = meta_string(doc.meta["hero-alt"])
  local img_src = poster or src
  local img
  if alt then
    img = pandoc.Image(alt, img_src)
  else
    img = pandoc.Image({}, img_src, "", { alt = "" })
  end

  local content = is_video and pandoc.Link({ img }, src) or img
  doc.blocks:insert(1, pandoc.Div({ pandoc.Plain({ content }) }, { class = "hero" }))
  return doc
end
