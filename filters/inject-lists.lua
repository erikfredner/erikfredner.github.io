-- Inject raw \listoffigures / \listoftables blocks at the top of the document
-- when metadata sets lof: true / lot: true. Must run BEFORE pandoc-crossref,
-- which converts the placeholders into HTML lists.

local function truthy(v)
  if v == nil then return false end
  if type(v) == "boolean" then return v end
  if type(v) == "table" and v.t == "MetaBool" then return v.c end
  local s = pandoc.utils.stringify(v):lower()
  return s == "true" or s == "yes" or s == "1"
end

function Pandoc(doc)
  local additions = {}
  if truthy(doc.meta.lof) then
    table.insert(additions, pandoc.RawBlock("latex", "\\listoffigures"))
  end
  if truthy(doc.meta.lot) then
    table.insert(additions, pandoc.RawBlock("latex", "\\listoftables"))
  end
  for i = #additions, 1, -1 do
    table.insert(doc.blocks, 1, additions[i])
  end
  return doc
end
