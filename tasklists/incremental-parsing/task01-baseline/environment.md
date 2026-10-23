# Task 01 本机执行环境与保护回归

更新：2026-10-23。结果仅代表本机当前工具链，不代表最低版兼容通过。

- 初始分支 `codex/vscode-live-preview`，HEAD `c510aee2e5bbbdb04402cb26bbca6679515a16f4`，`git status --short` 与 `git diff --stat` 为空。
- 当前 `cjc --version`：`1.3.0-alpha.20260920003052 (cjnative)`，target `x86_64-w64-mingw32`。
- 当前 `cjpm --version`：`1.3.0-alpha.05`。
- `markit/cjpm.toml` 保持 `cjc-version = "1.1.0"`，compile-option `-O2 -Woff unused`，SeaJson 声明 `1.5.0`。
- 测试依赖分析曾警告旧锁 `1.4.8` 冲突，实际使用 `1.5.0`；当前 `markit/cjpm.lock` 的 requires 记录 `1.5.0`。该文件被忽略，无跟踪生产文件变化。

## 已有 SDK 有界清点

只检查实际 SDK 父目录、读取版本，没有安装、修改 PATH 或安全设置。

| 编译器路径 | 实际版本 |
|---|---|
| `C:\Program Files (x86)\Cangjie\bin\cjc.exe` | 1.3.0-alpha.20260920003052 |
| `D:\Cagnjie_SDK\cangjie-0.58.3-windows_x64\cangjie\bin\cjc.exe` | 0.58.3 |
| `D:\cangjie\bin\cjc.exe` | 1.0.0 |
| `C:\Users\Shawn\.cangjie-sdk\5.0\cangjie\compiler\bin\cjc.exe` | 0.53.18 |
| `C:\Users\Shawn\.cangjie-sdk\6.0\cangjie\build-tools\bin\cjc.exe` | 1.1.0-beta.10 |
| `C:\Users\Shawn\.cangjie-sdk\6.1\cangjie\build-tools\bin\cjc.exe` | 1.1.0-beta.22 |

所有上述版本命令 exit 0；6.0/6.1 的 cjpm 也分别报告 beta.10/beta.22。尚未找到正式 1.1.0；beta 与 alpha 不能代替 G01 所需的正式最低版证据。

## 当前保护回归证据

- `npm.cmd test`：exit 1，72 tests，42 pass / 24 fail / 6 skip，见 `extension-test.log`。`progressive-session.test.js` 把带 POSIX shebang 的无扩展名 `fake-markit` 直接作为 executable，实际 Windows spawn ENOENT；不能把整套标通过。
- 排除 native/progressive/chromium 的 45 项子集：exit 1，39 pass / 2 fail / 4 skip，见 `extension-platform-independent.log`。两项 `heading-numbering` 原子 rename 在 sandbox 临时目录报 EPERM，不能全部归为 shebang 问题。
- 纯保护子集：exit 0，36 tests，34 pass / 0 fail / 2 skip，见 `extension-pure-protection.log`。覆盖 source map、复制、selection、动画及 preview frame 纯逻辑；被跳过的原生/DOM场景未被证明。
- 后续 Windows fixture 修复与完整扩展回归由独立 owner `windows_test_harness` 执行，证据位于 `../task01-windows-harness/`；本 owner 不改扩展生产或测试文件。

## 文件所有权与共享构建

- `legacy_fixtures`：仅 `editing_legacy_fixture.cj` / `editing_legacy_baseline_test.cj` 与 `../task01-legacy/`。
- `oracle_tools`：仅 `editing_oracle_kit.cj` / `editing_oracle_test.cj` 与 `../task01-oracle/`。
- `perf_baseline`：仅 `editing_batch_baseline_benchmarks.cj` 与 `../task01-performance/`。
- Task 01 owner 串行管理共享 cjpm target、验收集成及 Task01 / verification-log / verification-gaps；README 仅由 root 更新。
- 原有 full 基线编译后才安装新增源，正在执行的旧测试 binary 不作为新增设施通过证据。正式性能测量必须避开 build/test，受干扰 A/A 结果只保留为设施探索。
