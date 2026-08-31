# dochir

`dochir` is a CHIR compiler plugin and build-script helper for generating Cangjie API reference documentation.

The compiler plugin collects public `stdx.chir.Package` data into an intermediate model under `.dochir/model`. The `build.cj` helper reads that model after compilation, aggregates all packages into one project, and renders documentation formats such as Markdown and website output.

## Usage

Add `dochir` as a build script dependency:

```toml
[script-dependencies]
  dochir = { path = "path/to/dochir" }
```

Enable the dynamic CHIR plugin in `compile-option`. When `dochir` is built as a script dependency, cjpm places the plugin under `build-script-cache`:

```toml
[target.x86_64-w64-mingw32]
compile-option = "--plugin=build-script-cache/release/my_package/libs/release/dochir/libdochir.plugin.dll"
```

Use the platform suffix for the current target: `.dll` on Windows, `.so` on Linux, and `.dylib` on macOS. `stdx.chir` and `stdx.plugin` binaries must match the Cangjie compiler that loads the plugin because CHIR serialization is compiler-version sensitive.

Add a `build.cj` file:

```cangjie
import dochir.*

main(): Int64 {
    return dochirBuild(DocChirConfig(
        projectName: "my_package",
        outputRoot: "dochir-output",
        formats: ["markdown", "website"],
        defaultLang: "en",
        languages: ["en", "zh"],
        sourceRepository: "https://github.com/org/repo",
        sourceBranch: "main",
        assetRoot: "path/to/markit-kit/assets"
    ))
}
```

`assetRoot` is supplied by the build script so `dochir` and `markit-kit` do not guess where assets live. `languages` selects every rendered API description language, while `defaultLang` tells `dochir` which language bare `@description` tags represent. `sourceRepository` and `sourceBranch` are optional; when both are set, generated API pages include `Source` links into that repository branch.

Declaration comments follow the stdx source style for all tags except descriptions:

```cangjie
/**
 * @description Add two numbers.
 * @description-zh 两个数字相加
 * @description-ja 二つの数値を加算する
 * @param a Left input.
 * @param b Right input.
 * @return Sum of both inputs.
 * @type { Int64 }
 */
```

Use `@description` for the `defaultLang` text and `@description-<lang>` for localized variants. Other tags use the current `cangjie_stdx` source format: `@param name text`, `@return text`, and `@type { Type }`.

`modelDir` defaults to `.dochir/model`. `dochirBuild` writes this value during `pre-build`, and the compiler plugin reads it while collecting CHIR packages.

Package directories can provide a `markit.md` file. Content after a `<!-- homepage -->` marker is used as that package's generated `index.md` introduction before the API tables:

```markdown
- [Guide](guide.md)

<!-- homepage -->

## Package Guide

This package provides ...
```

## Output

- `.dochir/model`: compiler-plugin model snapshots.
- `dochir-output/markdown`: Markdown pages and `markit.md` navigation for a single language.
- `dochir-output/markdown/<lang>`: Markdown pages for each language when multiple `languages` are configured.
  - `index.md`: project landing page with package summary.
  - `packages/index.md`: package index.
  - `packages/<package>/index.md`: package homepage plus package-level declarations.
  - `packages/<package>/<Type>.md`: type page with declaration, description, relationships, member summaries, and optional source link.
  - `packages/<package>/<Type>/<kind>/<member>.md`: member pages for constructors, properties, methods, and enum constructors.
  - `pages.json`: symbol index with `name`, `description`, `location`, and `searchKeys`.
- `dochir-output/site`: rendered website output when `website` is requested, including a root landing page and language-specific directories such as `site/en` and `site/zh`.

Website mode keeps the Markdown intermediate so other renderers can reuse the same project model.
