-- Rewrite every relative link and image target to an absolute URL.
--
-- Used only for the Atom feed fragments (build/feed/*.html), never for the site
-- itself. A feed entry is read outside the page it came from, so a relative
-- `images/foo.webp` resolves against the reader's own origin and a bare `#fn1`
-- footnote anchor either dangles or collides with another entry's notes.
--
-- Needs `post-url` (the absolute URL of the page the fragment came from) in
-- addition to `site-url`, because relative paths resolve against the post's
-- directory (/blog/) rather than the site root.

local function stringify_meta(v)
  if v == nil then return nil end
  if type(v) == "string" then return v end
  return pandoc.utils.stringify(v)
end

local site_url, post_url, post_dir

local function absolutize(target)
  if target == nil or target == "" then return target end
  -- Already absolute, or a scheme we must not touch (mailto:, data:, tel:).
  if target:match("^%a[%w+.-]*:") or target:match("^//") then return target end

  if target:sub(1, 1) == "#" then
    return post_url .. target
  end
  if target:sub(1, 1) == "/" then
    return site_url .. target
  end

  local rel = target:gsub("^%./", "")
  local base = post_dir
  -- Walk `../` segments up from the post's directory.
  while rel:match("^%.%./") do
    rel = rel:gsub("^%.%./", "")
    base = base:gsub("[^/]*/$", "")
  end
  return base .. rel
end

function Pandoc(doc)
  site_url = (stringify_meta(doc.meta["site-url"]) or ""):gsub("/+$", "")
  post_url = stringify_meta(doc.meta["post-url"]) or ""
  post_dir = post_url:gsub("[^/]*$", "")

  return doc:walk({
    Link = function(el)
      el.target = absolutize(el.target)
      return el
    end,
    Image = function(el)
      el.src = absolutize(el.src)
      return el
    end,
  })
end
