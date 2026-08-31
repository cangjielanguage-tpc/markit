#let markit-chapter-cn = ({{CHAPTER_NUMBER_LITERALS}})
#let markit-heading-level1-label = "{{CHAPTER_LABEL}}"
#let markit-heading-numbering(..nums) = {
  let values = nums.pos()
  if values.len() == 1 and values.at(0) > 0 {
    {{LEVEL1_NUMBERING}}
  } else {
    numbering("1.1.1.1.1.1", ..values)
  }
}
#let markit-heading-size(level) = {
  if level == 1 { 22pt }
  else if level == 2 { 19pt }
  else if level == 3 { 17pt }
  else if level == 4 { 15pt }
  else if level == 5 { 14pt }
  else { 13pt }
}
#let markit-heading-gap(level) = {
  if level == 1 { 0.8em }
  else if level == 2 { 0.7em }
  else { 0.55em }
}
#set heading(numbering: markit-heading-numbering)
#show heading: it => context [
  #set par(first-line-indent: 0em)
  #v(if it.level == 1 { 1.1em } else { 0.85em })
  #align(center)[
    #set text(font: ("HarmonyOS Sans SC", "Libertinus Serif"), fill: rgb("#111827"), size: markit-heading-size(it.level), weight: "semibold")
    #counter(heading).display(markit-heading-numbering)
    #h(markit-heading-gap(it.level))
    #it.body
  ]
  #v(if it.level == 1 { 0.8em } else if it.level == 2 { 0.6em } else { 0.45em })
]
