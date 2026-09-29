-- Runs BEFORE filters/webp.lua, so every src still names the file that exists
-- in src/images/ (fig.png, not the fig.webp it will be published as; cwebp
-- keeps the pixel dimensions, so either answers the same question).
--
-- Gives each local image its intrinsic `width` and `height`. Without them the
-- browser lays the page out with a zero-height box and reflows when the image
-- arrives: a layout shift, and on the-ends-of-reading a jump to #fig:... that
-- lands a screen away from the figure, because the figures above it had not
-- loaded yet. With them, `height: auto` in style.css derives the box from the
-- aspect ratio before a single byte of the image is fetched. The attributes do
-- not pin the rendered size — `max-width: 100%` still scales wide images down
-- to the column.
--
-- Every image after the first also gets `loading="lazy"`. The first is left
-- eager because it is the one most likely to be above the fold (and to be the
-- page's LCP element); the rest of the-ends-of-reading's five SVGs are ~260 KB
-- a phone need not fetch until the reader scrolls toward them.
--
-- An image whose size cannot be read (remote, missing, an unhandled format, an
-- SVG sized in % or em) is left without dimensions rather than guessed at, as
-- are images whose markdown already sets width or height.

local function read_file(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local data = f:read("a")
  f:close()
  return data
end

local function u16be(s, i) local a, b = s:byte(i, i + 1); return a * 256 + b end
local function u32be(s, i) return u16be(s, i) * 65536 + u16be(s, i + 2) end
local function u16le(s, i) local a, b = s:byte(i, i + 1); return b * 256 + a end
local function u24le(s, i) local a, b, c = s:byte(i, i + 2); return c * 65536 + b * 256 + a end

local function png_size(s)
  if s:sub(1, 8) ~= "\137PNG\r\n\26\n" or #s < 24 then return nil end
  return u32be(s, 17), u32be(s, 21)
end

-- Walk the marker segments to the first start-of-frame (SOF0-SOF15, excluding
-- the DHT/JPG/DAC markers C4, C8, CC that share the range).
local function jpeg_size(s)
  if s:sub(1, 2) ~= "\255\216" then return nil end
  local i = 3
  while i + 8 <= #s do
    if s:byte(i) ~= 0xFF then return nil end
    local marker = s:byte(i + 1)
    if marker >= 0xC0 and marker <= 0xCF and marker ~= 0xC4
        and marker ~= 0xC8 and marker ~= 0xCC then
      return u16be(s, i + 7), u16be(s, i + 5)
    end
    i = i + 2 + u16be(s, i + 2)
  end
  return nil
end

local function webp_size(s)
  if s:sub(1, 4) ~= "RIFF" or s:sub(9, 12) ~= "WEBP" then return nil end
  local chunk = s:sub(13, 16)
  if chunk == "VP8 " then
    return u16le(s, 27) & 0x3FFF, u16le(s, 29) & 0x3FFF
  elseif chunk == "VP8L" then
    local b1, b2, b3, b4 = s:byte(22, 25)
    return 1 + (((b2 & 0x3F) << 8) | b1), 1 + (((b4 & 0x0F) << 10) | (b3 << 2) | ((b2 & 0xC0) >> 6))
  elseif chunk == "VP8X" then
    return 1 + u24le(s, 25), 1 + u24le(s, 28)
  end
  return nil
end

-- CSS px per unit. Matplotlib writes its SVGs in pt, and 576pt is 768px: using
-- the bare number would make a figure narrower than the column it used to fill.
local SVG_UNITS = { [""] = 1, px = 1, pt = 4 / 3, pc = 16, ["in"] = 96, cm = 96 / 2.54, mm = 96 / 25.4 }

local function svg_length(v)
  if not v then return nil end
  local num, unit = v:match("^%s*([%d%.]+)%s*(%a*)%s*$")
  local scale = unit and SVG_UNITS[unit]
  if not num or not scale then return nil end
  return tonumber(num) * scale
end

local function svg_size(s)
  local tag = s:match("<svg[%s>].-%f[>]")
  if not tag then return nil end
  local w = svg_length(tag:match('%swidth="([^"]*)"'))
  local h = svg_length(tag:match('%sheight="([^"]*)"'))
  if not (w and h) then
    local vb = tag:match('viewBox="([^"]*)"')
    if not vb then return nil end
    local _, _, vw, vh = vb:match("([-%d%.]+)[%s,]+([-%d%.]+)[%s,]+([%d%.]+)[%s,]+([%d%.]+)")
    w, h = tonumber(vw), tonumber(vh)
    if not (w and h) then return nil end
  end
  return math.floor(w + 0.5), math.floor(h + 0.5)
end

local READERS = { png = png_size, jpg = jpeg_size, jpeg = jpeg_size, webp = webp_size, svg = svg_size }

local function image_size(src)
  if src:match("^%a[%w+.-]*:") or src:match("^//") then return nil end
  local ext = src:match("%.(%w+)$")
  local reader = ext and READERS[ext:lower()]
  if not reader then return nil end
  -- Relative to the source file, which is also how the built page resolves it:
  -- src/foo.md's images/x and src/blog/post.md's ../images/x both land in
  -- src/images/, mirroring docs/images/.
  local input = PANDOC_STATE.input_files[1]
  local base = input and pandoc.path.directory(input) or "."
  local data = read_file(pandoc.path.normalize(pandoc.path.join({ base, src })))
  if not data then return nil end
  return reader(data)
end

function Pandoc(doc)
  local seen = 0
  return doc:walk({
    Image = function(el)
      seen = seen + 1
      local attrs = el.attributes
      if not attrs.width and not attrs.height then
        local w, h = image_size(el.src)
        if w and h and w > 0 and h > 0 then
          attrs.width = tostring(w)
          attrs.height = tostring(h)
        end
      end
      if seen > 1 and not attrs.loading then
        attrs.loading = "lazy"
      end
      return el
    end,
  })
end
