-- Capture the first Image on the page and expose its absolute URL
-- as `og-image` metadata so the template can emit <meta property="og:image">.
-- Runs after webp.lua so JPG/PNG sources have already been rewritten to .webp.

local function stringify_meta(v)
  if v == nil then return nil end
  if type(v) == "string" then return v end
  return pandoc.utils.stringify(v)
end

function Pandoc(doc)
  local site_url = stringify_meta(doc.meta["site-url"]) or ""
  site_url = site_url:gsub("/+$", "")

  local first_src = nil
  doc:walk({
    Image = function(el)
      if not first_src then first_src = el.src end
    end,
  })

  if not first_src or first_src == "" then return nil end

  local url
  if first_src:match("^https?://") then
    url = first_src
  else
    local rel = first_src
    rel = rel:gsub("^/+", "")
    while rel:match("^%.%./") do rel = rel:gsub("^%.%./", "") end
    rel = rel:gsub("^%./", "")
    if site_url ~= "" then
      url = site_url .. "/" .. rel
    else
      url = "/" .. rel
    end
  end

  doc.meta["og-image"] = pandoc.MetaString(url)
  return doc
end
