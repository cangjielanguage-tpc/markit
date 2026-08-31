#show outline.entry: set par(first-line-indent: 0em, leading: 1em, spacing: 0.45em)
#show outline.entry.where(level: 1): it => {
  v(0.55em)
  strong(it)
  v(0.1em)
}
#set outline.entry(fill: repeat("  ·"))
#align(center)[
  #set text(font: ("HarmonyOS Sans SC", "Libertinus Serif"), fill: rgb("#111827"), size: 22pt, weight: "semibold")
  {{TOC_TITLE}}
]
#v(1.15em)
#outline(title: none, depth: {{TOC_MAX_LEVEL}})

#pagebreak()
#counter(page).update(1)
