# dochir example

This example exercises `dochir` as a cjpm build-script dependency and CHIR compiler plugin.

`cjpm.toml` enables the plugin from the script-dependency cache with target-specific `compile-option` entries. `build.cj` calls `dochirBuild` after compilation to read `.dochir/model`, generate Markdown, and render the website through `markit-kit`.

Set `sourceRepository` and `sourceBranch` in `build.cj` when the generated API pages should link to a hosted source repository.
Set `languages` to the language variants that should be generated. `defaultLang` controls which language bare `@description` comments represent.

Run from this directory after the local Cangjie SDK and matching stdx binaries are available:

```powershell
cjpm build -V
```

Expected outputs:

- `.dochir/model`
- `dochir-output/markdown`
  - language directories such as `en` and `zh` when multiple languages are configured
  - project and package indexes
  - type pages such as `packages/dochir_example/chir/Expression.md`
  - member pages such as `packages/dochir_example/chir/Expression/constructors/init-ty-type.md`
  - `pages.json` symbol index
- `dochir-output/site`
  - root landing page
  - language-specific website directories such as `en` and `zh`
