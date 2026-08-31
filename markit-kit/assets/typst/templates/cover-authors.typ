  #v(2.4em)
  #let cover-authors = ({{AUTHOR_ARRAY}})
  #let cover-author-gap = 14pt
  #let cover-author-row-gap = 0.6em
  #let cover-author-cell(author) = box[#text(size: {{FONT_SIZE}}, fill: rgb("#334155"))[#author]]
  #let cover-author-line(authors, justify: false) = {
    let parts = ()
    for (index, author) in authors.enumerate() {
      parts.push(cover-author-cell(author))
      if index != authors.len() - 1 {
        if justify {
          parts.push(h(1fr))
        } else {
          parts.push(h(cover-author-gap))
        }
      }
    }
    box(width: 100%)[#parts.join()]
  }
  #let split-cover-author-rows(authors, line-width) = {
    let rows = ()
    let current-row = ()
    let current-width = 0pt
    for author in authors {
      let cell-width = measure(cover-author-cell(author)).width
      let next-width = if current-row.len() == 0 {
        current-width + cell-width
      } else {
        current-width + cover-author-gap + cell-width
      }

      if current-row.len() > 0 and next-width > line-width {
        rows.push(current-row)
        current-row = (author,)
        current-width = cell-width
      } else {
        current-row.push(author)
        current-width = next-width
      }
    }

    if current-row.len() > 0 {
      rows.push(current-row)
    }
    rows
  }
  #align(center)[
    #block(width: 88%)[
      #layout(size => {
        let rows = split-cover-author-rows(cover-authors, size.width)
        let rendered-rows = ()
        for (index, row) in rows.enumerate() {
          rendered-rows.push(cover-author-line(row, justify: index != rows.len() - 1))
        }
        stack(dir: ttb, spacing: cover-author-row-gap, ..rendered-rows)
      })
    ]
  ]
