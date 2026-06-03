-- Runs AFTER --citeproc, BEFORE pandoc-sidenote.
-- chicago-notes is a notes-only style: every rendered citation gets wrapped
-- in <a href="#ref-..."> as a back-link to a bibliography entry that this
-- site does not produce. The wrapper renders as a link (styled, focusable)
-- but goes nowhere, and it also swallows DOIs / JSTOR URLs so they aren't
-- clickable. This filter strips the dead #ref- wrapper, keeping its inline
-- content as plain text, and promotes any bare-URL child to its own
-- external Link so the URL is clickable.

local function is_url(s)
  if not s then return false end
  return s:match("^https?://") ~= nil
      or s:match("^doi:")     ~= nil
end

function Link(link)
  if not link.target or link.target:sub(1, 5) ~= "#ref-" then
    return nil
  end

  local out = {}
  for _, el in ipairs(link.content) do
    local txt = pandoc.utils.stringify(el)
    if txt and txt:match("^%S+$") and is_url(txt) then
      table.insert(out, pandoc.Link({pandoc.Str(txt)}, txt))
    else
      table.insert(out, el)
    end
  end
  return out
end
