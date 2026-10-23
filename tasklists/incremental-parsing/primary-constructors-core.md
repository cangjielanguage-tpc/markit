# Primary constructors: core/render, parse values, bundles and DSL

Status: Source Ready and frozen. Prior batch passed accepted Task05 whole3/full692; the final eight style-only constructor renames await Task06 normal compilation coverage.
Owner: `/root/task04_tree`; explicit root assignment, separate from Task05 storage acceptance.

Converted 17 single constructors in 13 files by replacing `init` with the containing type name. Existing fields, assignment statements, default/named parameters, visibility, clone/validation calls, callback defaults, and initialization order are unchanged.

- `core/render/{html_writer,text_writer,markdown_renderer,typst_renderer,render_registry}.cj`: six constructors.
- `{parse_callbacks,parse_output}.cj`: two constructors.
- `bundles/{commonmark_bundle,gfm_bundle,standard_markdown_bundle}.cj`: three constructors.
- `dsl/build_context.cj`, `dsl/options.cj`, `dsl/types.cj`: six constructors. DslBuildContext retains its heading-state, renderer, and source creation order; existing mutable counters/maps retain their declarations and initializers.

`dsl/document.cj` currently retains both constructors while the shared syntax check establishes whether secondary delegation can preserve one initialization of `blockSpecs` and the `blocks` insertion order. Files with no explicit constructor need no synthetic one. `core/render/html_config.cj` is outside this assigned five-file render set and was not edited.

`git diff --check` for this assigned range exited0. Source is frozen for the normal whole-project build; no compiler/test process was started by this owner and no new test framework was added.

The three storage files remain at the tested aux4/atomic9 freeze for this first whole build. Their separate primary-constructor inventory and semantic constraints are in `task05-engine/atomic-store.md`; conversion will use the same coordinated compiler syntax result and normal edit window.

First normal whole-project compile succeeded: `task05-verification/integrated-compile-1.log` reports `cjpm test success` and `TASK05_WHOLE_COMPILE_EXIT=0`. This validates the 17 same-name primary constructors with ordinary parameters and explicit assignment bodies on the installed SDK. Runtime regression is still scheduled by the build owner; storage primary-constructor conversion has not started.

The next normal repair window also converted the options constructor of DslDocument to a same-name primary constructor; its blocks secondary constructor retains its original body verbatim. Whole1 had already compiled this primary/secondary coexistence shape in I18nPostProcessor, so no new delegation or double initialization was introduced. This brings this nonhot assigned range to18 primary constructors in14 files. Storage separately converted18 single constructors plus one primary in each of three multi-constructor types; all original secondary bodies remain. Whole2 is currently the ordinary compilation/runtime validation for this batch.

Whole2 normal compilation passed (`task05-verification/integrated-compile-2.log`, `TASK05_WHOLE2_COMPILE_EXIT=0`), including DslDocument primary/secondary coexistence and the21 storage primary constructors. No overload, default parameter, constructor body, field mutability or inheritance delegation was merged/reordered. Runtime regression remains with the build owner.

The normal whole2 runtime regression passed the complete137-case main unit binary, including atomic/aux storage cases. Across27 packages it reported691 passed and one legacy anchor failure (nestedParagraphs extra blockquote span attributes), under investigation by the main/kernel owner. This report does not claim full regression success; source stays frozen for the coordinated correction.

## Remaining nodes/document style inventory (not written during whole3)

Root extended this owner to all remaining `core/nodes/` and `core/document/` constructor spelling. Read-only inventory found seven safe same-name primary conversions in five files: `nodes/node.cj` (Node), `nodes/document_node.cj` (DocumentNode), `nodes/text_node.cj` (TextNode), `nodes/persistent_text.cj` (PersistentTextSegment, TextBranch, PersistentTextPayload), and `document/document_snapshot.cj` (DocumentSnapshot). Constructor bodies, validation/string clone, explicit super calls, TextBranch leaf/branch representation and DocumentSnapshot.index(root) order will stay verbatim; each multi-constructor type selects one primary and retains its other init bodies.

NodeCodec has no explicit constructor; its implicit no-argument initialization already preserves its private codec collection, so no synthetic constructor will be introduced. NodeRenderHooks and codec/reference capability declarations are interfaces, not value constructors. Previously converted primary classes retain legitimate secondary init bodies.

The build owner began whole3 before this new style batch. None of these seven constructors has been edited yet. Root instructed keeping whole3 frozen and using a subsequent normal Task06 compilation window, without delaying Task05 acceptance or adding a style-only build/test phase.

## Final short style batch: Source Ready for Task06

After root accepted Task05 and its timing work finished, the build owner confirmed no compiler was reading the affected sources. Applied exactly eight constructor-header renames in six files: Node, DocumentNode, TextNode, PersistentTextSegment, TextBranch, PersistentTextPayload, DocumentSnapshot, and the newly explicitly assigned HtmlConfig empty constructor. All bodies, field declarations/default initializers, super calls, parameter defaults and secondary init bodies remain unchanged. NodeCodec still has no explicit constructor; no synthetic one was added.

`git diff --check` on nodes/document/html_config exited0. The only remaining init declarations in nodes/document are legitimate secondary constructors of types that now have a primary constructor. Source is frozen and handed SOURCE_READY to the build owner for the normal Task06 compilation; no separate style compiler/test run was launched.

Historical Task05 whole3 succeeded (`task05-verification/integrated-compile-3.log`), and `task01-baseline/task05-full-console-2/summary.json` records27/27 package exit0 with692 passed,0 skipped/error/failed. Root accepted Task05 after same-O2 evidence. Those accepted binary results precede these last eight header renames and are not claimed as verification of this new source batch. Current owner total:47 primary constructor conversions across the assigned scopes (39 earlier,8 final).
