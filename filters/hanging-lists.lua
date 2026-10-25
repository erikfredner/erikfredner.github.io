-- Runs last among the content filters. On a page whose frontmatter sets
-- `hanging-lists: true`, renders every bullet list as an unmarked list with a
-- hanging indent: `<ul class="hanging-list" role="list">`, styled by style.css.
-- This is the bibliography convention, and the one a CV in literary studies
-- follows; cv.md is the page that uses it.
--
-- Pandoc's BulletList carries no attributes, so the <ul> and <li> tags are
-- emitted as raw HTML around each item's own blocks. Only the tags are raw: the
-- item contents stay in the AST, so links, emphasis, and any citation or
-- footnote inside an item are still rendered by pandoc as usual.
--
-- role="list" is not redundant. WebKit drops list semantics from a list whose
-- markers are hidden with CSS, so without it VoiceOver on Safari reads the
-- entries as loose paragraphs, with no "list, N items" announcement and no
-- way to skip past the list.

local function hanging(list)
  local blocks = pandoc.Blocks({
    pandoc.RawBlock("html", '<ul class="hanging-list" role="list">'),
  })
  for _, item in ipairs(list.content) do
    blocks:insert(pandoc.RawBlock("html", "<li>"))
    blocks:extend(item)
    blocks:insert(pandoc.RawBlock("html", "</li>"))
  end
  blocks:insert(pandoc.RawBlock("html", "</ul>"))
  return blocks
end

-- A Pandoc-level function, because the default traversal visits Meta only
-- after every Block, too late to decide whether to touch the lists.
function Pandoc(doc)
  if not doc.meta["hanging-lists"] then
    return nil
  end
  return doc:walk({ BulletList = hanging })
end
