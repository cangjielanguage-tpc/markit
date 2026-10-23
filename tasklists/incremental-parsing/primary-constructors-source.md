# Source primary constructors

Owner: Task05 source lifecycle / Task06 local view owner. Scope is the 13 self-owned `markit/src/core/source/*.cj` files. This is a syntax-only cleanup following the user's repository-wide primary-constructor instruction; no new test stage or probe is introduced. The seven Task06 view tests and their product remain frozen separately.

## Prepared scope

The reviewed patch covers 11 files / 23 explicit-constructor types. It preserves constructor access, parameter order and names, named defaults, member visibility and mutability. It does not replace clones with aliases, combine overloads, reorder validation or resource work, or add wrapper constructors.

| File | Promoted member parameters | Explicit body retained |
|---|---|---|
| `cursor.cj` | `CursorCheckpoint`, `Cursor` | Cursor positions still derive from the supplied view in the same body |
| `editable_rope.cj` | none | `RopeNode`: leaf text is cloned; all other metrics derive from text or child nodes; second overload retained |
| `editable_source_map.cj` | `ComposedSourceMap`, `MappedText`, `MappedTextBuilder` | `SegmentSourceMap`: validate ordered ranges before cloning the input array |
| `editable_source.cj` | `EditableRopeVersion` internal root constructor, `RopeEditDelta`, `RopeEditBatch`, `RopeAnchorProjection`, `EditableSourceLease` | `RopeAnchorKey` derives three fields from one anchor; `EditableRopeStore` derives accepted root/floor; public rope-version overload remains unchanged |
| `line_index.cj` | `LineIndexSnapshot` final sourceView parameter | `IndexedLineNode` derives optional children/metrics; snapshot earlier root/flat parameters must remain ordinary because size precedes the final promoted parameter |
| `line_scanner.cj` | `DecodedLine` | none |
| `source_buffer.cj` | `SourceSegment` | `SourceBuffer` preserves its published retentionMode-before-editableSource parameter order; the later ordinary editableSource prevents promotion of the earlier retentionMode on this SDK |
| `source_line.cj` | `SourceLine` | none |
| `source_span.cj` | `SourceSpan` | none |
| `synthetic_source_builder.cj` | `SyntheticSourceParseInput` | none |
| `text_view.cj` | `TextView` | none |

`source_retention_mode.cj` and `utf8_stream_decoder.cj` have no explicit constructor to convert. Seventeen types fold direct fields into member parameters; six types retain their required explicit calculation/clone body and use a named primary constructor. Multi-constructor types keep their secondary `init` overloads rather than changing the public API.

## Coordination and evidence

Prepared exact replacements in Temp while 02 reads the source package for the Task06 base closure. Each live file is hash-checked against the reviewed original before application. No source write occurs until 02 releases its source read window. Normal Task06 package/project compilation and regressions cover this cleanup; previously passed view7/index6 evidence remains scoped to its earlier frozen closure.

Status: patch prepared; waiting for the source-package safe write window. No product source has yet been modified by this cleanup.
