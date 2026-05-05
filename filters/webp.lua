-- Rewrite .jpg/.jpeg/.png image src attributes to .webp
function Image(el)
  el.src = el.src:gsub("%.[jJ][pP][eE]?[gG]$", ".webp"):gsub("%.[pP][nN][gG]$", ".webp")
  return el
end
