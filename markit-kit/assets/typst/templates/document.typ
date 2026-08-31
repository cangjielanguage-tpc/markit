#set document(title: [{{ESCAPED_TITLE}}])
#set page(
  margin: (left: 2cm, right: 1.5cm, top: 2cm, bottom: 2cm){{PAGE_NUMBER_CONFIG}}
)
#set text(font: {{BODY_FONTS}}, size: 11pt, fill: rgb("#111827"){{TEXT_LANG_CONFIG}})
{{PARAGRAPH_STYLE_CONFIG}}{{HEADING_STYLE_CONFIG}}#set list(indent: 2em)
#set enum(indent: 2em, numbering: "1.")
#show list: it => [
  #it
  #par()[#text(size: 0.0em)[#h(0.0em)]]
  #v(-12pt)
]
#show enum: it => [
  #it
  #par()[#text(size: 0.0em)[#h(0.0em)]]
  #v(-12pt)
]
#show strong: set text(font: {{EMPHASIS_FONTS}})
#show emph: set text(style: "italic")
{{RAW_CONFIG}}#let markit-inline-code-fill = rgb("#f3f4f6")
#let markit-inline-code-mark-fill = rgb("#94a3b8")
#let markit-inline-code-mark-gap = 3pt
#let markit-inline-code-line-gap = 7pt
#let markit-inline-code-safety-padding = 4pt
#let markit-inline-code-content-width-adjust = 8pt
#let markit-inline-code-final-operator-overflow = 20pt
#let markit-is-space(ch) = ch == " " or ch == "\t"
#let markit-is-inline-code-soft-break-at(chars, i) = {
  let ch = chars.at(i)
  let prev = if i > 0 { chars.at(i - 1) } else { none }
  let next = if i + 1 < chars.len() { chars.at(i + 1) } else { none }
  if ch == "." {
    if prev == "." or next == "." or next == "=" {
      return false
    }
    return true
  }
  if ch == "=" {
    if (
      prev == "."
      or prev == "+"
      or prev == "-"
      or prev == "*"
      or prev == "/"
      or prev == "%"
      or prev == "|"
      or prev == "&"
      or prev == "?"
    ) {
      return true
    }
    return false
  }
  if ch == "+" or ch == "-" or ch == "*" or ch == "/" or ch == "%" {
    if prev == ch or next == ch or next == "=" {
      return false
    }
    return true
  }
  if ch == "|" or ch == "&" or ch == "?" {
    if prev == ch or next == ch or next == "=" {
      return false
    }
    return true
  }

  return (
    ch == "/"
    or ch == "\\"
    or ch == "_"
    or ch == ","
    or ch == ";"
    or ch == ":"
    or ch == ">"
    or ch == "<"
    or ch == "|"
    or ch == "("
    or ch == "{"
    or ch == ")"
    or ch == "]"
    or ch == "}"
  )
}
#let markit-inline-code-breakpoints(chars, predicate) = {
  let points = ()
  let i = 0
  while i < chars.len() {
    if predicate(chars.at(i)) {
      points.push(i + 1)
    }
    i += 1
  }
  points
}
#let markit-inline-code-soft-breakpoints(chars) = {
  let points = ()
  let i = 0
  while i < chars.len() {
    if markit-is-inline-code-soft-break-at(chars, i) {
      points.push(i + 1)
    }
    i += 1
  }
  points
}
#let markit-inline-code-operator-breakpoints(chars) = {
  let points = ()
  let i = 0
  while i < chars.len() {
    let ch = chars.at(i)
    let prev = if i > 0 { chars.at(i - 1) } else { none }
    let next = if i + 1 < chars.len() { chars.at(i + 1) } else { none }
    if ch == "." and next == "." {
      if i + 2 < chars.len() and chars.at(i + 2) == "=" {
        points.push(i + 3)
        i += 3
        continue
      }
      points.push(i + 2)
      i += 2
      continue
    }
    if ch == "+" and next == "+" {
      points.push(i + 2)
      i += 2
      continue
    }
    if ch == "-" and next == "-" {
      points.push(i + 2)
      i += 2
      continue
    }
    if (ch == "+" or ch == "-" or ch == "*" or ch == "/" or ch == "%" or ch == "=") and next == "=" {
      points.push(i + 2)
      i += 2
      continue
    }
    if (ch == "|" or ch == "&" or ch == "?") and next == ch {
      if i + 2 < chars.len() and chars.at(i + 2) == "=" {
        points.push(i + 3)
        i += 3
        continue
      }
      points.push(i + 2)
      i += 2
      continue
    }
    i += 1
  }
  points
}
#let markit-is-ascii-lower(ch) = ch >= "a" and ch <= "z"
#let markit-is-ascii-upper(ch) = ch >= "A" and ch <= "Z"
#let markit-inline-code-camel-breakpoints(chars) = {
  let points = ()
  let i = 1
  while i < chars.len() {
    let prev = chars.at(i - 1)
    let curr = chars.at(i)
    if markit-is-ascii-lower(prev) and markit-is-ascii-upper(curr) {
      points.push(i)
    }
    i += 1
  }
  points
}
#let markit-inline-code-bracket-breakpoints(chars) = {
  let points = ()
  let i = 0
  while i < chars.len() {
    let ch = chars.at(i)
    if ch == "[" {
      points.push(i + 1)
    } else if ch == "]" and i > 0 {
      points.push(i)
    }
    i += 1
  }
  points
}
#let markit-inline-code-assignment-group-breakpoints(chars) = {
  let points = ()
  let i = 0
  while i < chars.len() {
    if chars.at(i) == " " and i + 3 < chars.len() {
      let op = chars.at(i + 1)
      let next = chars.at(i + 2)
      let has-rhs = i + 3 < chars.len() and chars.at(i + 3) != " "
      if op == "=" and next == " " and has-rhs {
        points.push(i)
        i += 2
        continue
      }
      if (op == "+" or op == "-" or op == "*" or op == "/" or op == "%") and next == "=" {
        if i + 4 < chars.len() and chars.at(i + 3) == " " and chars.at(i + 4) != " " {
          points.push(i)
          i += 3
          continue
        }
      }
      if (op == "|" or op == "&" or op == "?") and next == op {
        if i + 4 < chars.len() and chars.at(i + 3) == " " and chars.at(i + 4) != " " {
          points.push(i)
          i += 3
          continue
        }
        if i + 5 < chars.len() and chars.at(i + 3) == "=" and chars.at(i + 4) == " " and chars.at(i + 5) != " " {
          points.push(i)
          i += 4
          continue
        }
      }
    }
    i += 1
  }
  points
}
#let markit-inline-code-starts-with-assignment-fragment(chars, start) = {
  if start >= chars.len() {
    return false
  }
  let ch = chars.at(start)
  let next = if start + 1 < chars.len() { chars.at(start + 1) } else { none }
  let after-next = if start + 2 < chars.len() { chars.at(start + 2) } else { none }
  let after-after-next = if start + 3 < chars.len() { chars.at(start + 3) } else { none }
  if ch == "=" {
    next == " "
  } else if ch == "+" or ch == "-" or ch == "*" or ch == "/" or ch == "%" {
    next == "=" and after-next == " "
  } else if ch == "|" or ch == "&" or ch == "?" {
    if next == ch and after-next == " " {
      true
    } else {
      next == ch and after-next == "=" and after-after-next == " "
    }
  } else {
    false
  }
}
#let markit-inline-code-merge-operator-line(line, next) = {
  if line == " = " or line == " =" or line == "= " or line == "=" {
    "= " + next
  } else if line == " += " or line == " +=" or line == "+= " or line == "+=" {
    "+= " + next
  } else if line == " -= " or line == " -=" or line == "-= " or line == "-=" {
    "-= " + next
  } else if line == " *= " or line == " *=" or line == "*= " or line == "*=" {
    "*= " + next
  } else if line == " /= " or line == " /=" or line == "/= " or line == "/=" {
    "/= " + next
  } else if line == " %= " or line == " %=" or line == "%= " or line == "%=" {
    "%= " + next
  } else if line == " || " or line == " ||" or line == "|| " or line == "||" {
    "|| " + next
  } else if line == " && " or line == " &&" or line == "&& " or line == "&&" {
    "&& " + next
  } else if line == " ?? " or line == " ??" or line == "?? " or line == "??" {
    "?? " + next
  } else if line == " ||= " or line == " ||=" or line == "||= " or line == "||=" {
    "||= " + next
  } else if line == " &&= " or line == " &&=" or line == "&&= " or line == "&&=" {
    "&&= " + next
  } else if line == " ??= " or line == " ??=" or line == "??= " or line == "??=" {
    "??= " + next
  } else {
    none
  }
}
#let markit-inline-code-collapse-lines(lines) = {
  let collapsed = ()
  let i = 0
  while i < lines.len() {
    if i + 1 < lines.len() {
      let merged = markit-inline-code-merge-operator-line(lines.at(i), lines.at(i + 1))
      if merged != none {
        collapsed.push(merged)
        i += 2
        continue
      }
    }
    collapsed.push(lines.at(i))
    i += 1
  }
  collapsed
}
#let markit-inline-code-slice(chars, start, end) = {
  let segment = ""
  let i = start
  while i < end {
    segment += chars.at(i)
    i += 1
  }
  segment
}
#let markit-inline-code-piece(segment) = highlight(fill: markit-inline-code-fill)[#segment]
#let markit-inline-code-marker() = box(inset: (top: 0pt, bottom: 0pt, left: 0pt, right: 0pt))[#image("{{WRAP_MARKER_PATH}}", height: 0.62em)]
#let markit-measure-inline-code-piece(segment) = measure(
  markit-inline-code-piece(segment)
).width
#let markit-inline-code-piece-with-marker(segment) = box[
  #grid(
    columns: (auto, auto),
    column-gutter: 3pt,
    align: (left, bottom),
    markit-inline-code-piece(segment),
    markit-inline-code-marker(),
  )
]
#let markit-measure-inline-code-piece-with-marker(segment) = measure(
  markit-inline-code-piece-with-marker(segment)
).width
#let markit-inline-code-measured-width(segment, reserve-marker: false) = {
  if reserve-marker {
    markit-measure-inline-code-piece-with-marker(segment)
  } else {
    markit-measure-inline-code-piece(segment)
  }
}
#let markit-inline-code-find-break-in-points(chars, points, start, width, reserve-marker: false) = {
  let target-width = if width > markit-inline-code-safety-padding { width - markit-inline-code-safety-padding } else { width }
  let low = 0
  let high = points.len() - 1
  let best = -1

  while low <= high {
    let mid = calc.floor((low + high) / 2)
    let endpoint = points.at(mid)
    if endpoint <= start {
      low = mid + 1
    } else {
      let candidate = markit-inline-code-slice(chars, start, endpoint)
      let candidate-width = markit-inline-code-measured-width(candidate, reserve-marker: reserve-marker)
      if candidate-width <= target-width {
        best = mid
        low = mid + 1
      } else {
        high = mid - 1
      }
    }
  }

  if best >= 0 {
    return points.at(best)
  }

  none
}
#let markit-inline-code-find-max-end(chars, start, width, reserve-marker: false) = {
  let all-points = ()
  let i = start + 1
  while i <= chars.len() {
    all-points.push(i)
    i += 1
  }
  let max-end = markit-inline-code-find-break-in-points(chars, all-points, start, width, reserve-marker: reserve-marker)
  if max-end != none {
    return max-end
  }
  start + 1
}
#let markit-inline-code-find-point-before(points, start, max-end) = {
  let found = none
  for point in points {
    if point > start and point <= max-end {
      found = point
    }
  }
  found
}
#let markit-inline-code-lines(body, width) = {
  let chars = body.clusters()
  let space-points = markit-inline-code-breakpoints(chars, markit-is-space)
  let assignment-group-points = markit-inline-code-assignment-group-breakpoints(chars)
  let operator-points = markit-inline-code-operator-breakpoints(chars)
  let soft-points = markit-inline-code-soft-breakpoints(chars)
  let bracket-points = markit-inline-code-bracket-breakpoints(chars)
  let camel-points = markit-inline-code-camel-breakpoints(chars)
  let lines = ()
  let start = 0
  while start < chars.len() {
    let remaining = markit-inline-code-slice(chars, start, chars.len())
    let remaining-width = markit-inline-code-measured-width(remaining)
    let operator-overflow-fit = (
      markit-inline-code-starts-with-assignment-fragment(chars, start)
      and remaining-width <= width + markit-inline-code-final-operator-overflow
    )
    let end = if remaining-width <= width or operator-overflow-fit {
      chars.len()
    } else {
      let max-end = markit-inline-code-find-max-end(chars, start, width, reserve-marker: true)
      let preferred-assignment-group = markit-inline-code-find-point-before(assignment-group-points, start, max-end)
      let preferred-space = markit-inline-code-find-point-before(space-points, start, max-end)
      let preferred-operator = markit-inline-code-find-point-before(operator-points, start, max-end)
      let preferred-bracket = markit-inline-code-find-point-before(bracket-points, start, max-end)
      let preferred-camel = markit-inline-code-find-point-before(camel-points, start, max-end)
      let preferred-soft = markit-inline-code-find-point-before(soft-points, start, max-end)
      if preferred-assignment-group != none {
        preferred-assignment-group
      } else if preferred-space != none {
        preferred-space
      } else if preferred-operator != none {
        preferred-operator
      } else if preferred-bracket != none {
        preferred-bracket
      } else if preferred-camel != none {
        preferred-camel
      } else if preferred-soft != none {
        preferred-soft
      } else {
        max-end
      }
    }
    lines.push(markit-inline-code-slice(chars, start, end))
    start = end
  }
  markit-inline-code-collapse-lines(lines)
}
#let markit-inline-code-fit(body, width) = context {
  set text(font: {{CODE_FONTS}}, size: 0.91em{{CODE_TEXT_CONFIG}})
  let effective-width = if width > markit-inline-code-content-width-adjust {
    width - markit-inline-code-content-width-adjust
  } else {
    width
  }
  let lines = markit-inline-code-lines(body, effective-width)
  let rendered-lines = ()
  for (index, line-text) in lines.enumerate() {
    if index + 1 < lines.len() {
      rendered-lines.push(block(width: 100%)[#markit-inline-code-piece-with-marker(line-text)])
    } else {
      rendered-lines.push(block(width: 100%)[#box[#markit-inline-code-piece(line-text)]])
    }
  }
  stack(dir: ttb, spacing: markit-inline-code-line-gap, ..rendered-lines)
}
#let markit-inline-code(body) = {
  set text(font: {{CODE_FONTS}}, size: 0.91em{{CODE_TEXT_CONFIG}})
  highlight(fill: rgb("#f3f4f6"))[#body]
}
#let markit-inline-code-table(body) = box(layout(size => markit-inline-code-fit(body, size.width)))
#show quote: it => [
  #v(0.3em)
  #block(fill: rgb("#f8fafc"), stroke: 0.8pt + rgb("#cbd5e1"), inset: (left: 1em, right: 1em, top: 0.75em, bottom: 0.75em), radius: 4pt)[
    #set text(font: {{BODY_FONTS}}, fill: rgb("#334155"))
    #set par(first-line-indent: 0em, leading: 1em, spacing: 0.25em)
    #it
  ]
  #v(0.3em)
]
#show link: set text(fill: rgb("#2563eb"))
#show raw.where(block: true): block.with(width: 100%, fill: luma(240), inset: 10pt, radius: 5pt)
#show raw.where(block: true): set par(leading: 0.7em)
#show raw: set text(font: {{CODE_FONTS}}, size: 10pt{{CODE_TEXT_CONFIG}})
#show raw.where(block: false): it => highlight(fill: rgb("#f3f4f6"))[#it]

{{NORMALIZED_BODY}}
