# psalm-plugin-phpunit: working conventions

`master` is the development branch and the base of feature PRs.
Remotes: `origin` = psalm/psalm-plugin-phpunit. PR branches go to your own fork's remote
(find it with `git remote -v` and `gh api user --jq .login`; add it if missing). Never push
PR branches to `origin`.

Layout:
- `src/Plugin.php`: entry point. Registers `stubs/TestCase.phpstub` and `Hooks\TestCaseHandler`.
- `src/Hooks/TestCaseHandler.php`: all the hooks (`AfterClassLikeVisit`,
  `AfterClassLikeAnalysis`, `AfterCodebasePopulated`, `AfterMethodCallAnalysis`).
- `stubs/TestCase.phpstub`: types `prophesize()`.
- `tests/acceptance/TestCase.feature`: the Behat scenarios, the only test suite that CI runs.
- `tools/behat/`: a separate composer project (Behat, azjezz/psl, and Psalm ^6 used only to
  analyse `tools/behat/src/Context.php`). `Context` writes each scenario to
  `tools/behat/run/<random>/` and runs the **root** `vendor/bin/psalm` there.

Domain skills (load them before touching the area):
- `plugin-repro`: scratch-project repros, base vs branch, comparing Psalm versions
- `pr-description`: the PR description format, and reformatting existing descriptions

## Fixing bugs and writing features

These come first, before every other rule here:

1. **Fix the root cause.** Find why the bug happens and fix that, not the symptom or the
   one input that showed it. If the same mistake exists elsewhere (sibling hooks, other
   call sites, the stub), fix it there too.
2. **Think through every way the change could cause bugs**, in edge cases and ordinary
   ones: other callers of the changed code, traits and inherited test cases, PHPUnit
   `#[Attribute]` vs docblock annotations, other PHP and PHPUnit versions, other Psalm
   versions (see "Psalm versions"), analysis of a single file. Check each one by adding
   a scenario.
3. **Add an explicit scenario for each of those cases**, not only for the reported bug.

## Validating changes: CI, then a single scenario locally

CI (`.github/workflows/ci.yml`) is the source of truth:
- `psalm` (PHP 8.2): `COMPOSER_ROOT_VERSION=dev-master composer update --prefer-dist`, then
  `vendor/bin/psalm --output-format=github --shepherd` on `src/`.
- `phpcs`: `vendor/bin/phpcs`. `composer check` runs phpcs and Psalm.
- `test-static-analysis` (PHP 8.2): `cd tools/behat && composer install && vendor/bin/psalm`.
- `tests`: deps high/low/stable × PHP 8.2 and 8.4 on pull requests, PHP 8.2 to 8.4 on pushes,
  the weekly schedule and manual runs (8.4 low excluded). `composer update` (plus
  `--prefer-lowest` or `--prefer-stable`) at the root **and** in `tools/behat`, then
  `tools/behat/behat-parallel.sh`: one Behat process per scenario, one per CPU at a time,
  printing the output of failed scenarios only.

`gh` and the logs show the job names ("Static analysis", "Code style", "Test on 8.2 - high
deps"), not these YAML ids.

Locally:
- Install like CI: `COMPOSER_ROOT_VERSION=dev-master composer update --prefer-dist -n` at the
  root, and the same in `tools/behat`. That rewrites the tracked `tools/behat/composer.lock`:
  `git checkout tools/behat/composer.lock` afterwards.
- **Running a single scenario is fine, and recommended** (~2 s) for reproducing an issue or
  showing that a new scenario fails on the base and passes on the branch:
  - by line of the `Scenario:` header:
    `cd tools/behat && vendor/bin/behat ../../tests/acceptance/TestCase.feature:<line>`
    (a line that isn't a `Scenario:` header prints only Behat's usage, no error);
  - by title: `cd tools/behat && vendor/bin/behat --name 'Missing data provider is reported'`
    is a literal substring match. A regex needs delimiters:
    `--name '/^Missing data provider is reported$/'`. Without them, `.*` etc. match
    nothing ("No scenarios"). Check that the output says `1 scenario`.
- The full suite (a few minutes) at most once, right before pushing. Never between
  iterations, and never sweeps (re-running batches of scenarios, looping over fixtures).
- `vendor/bin/phpcs -q` and `vendor/bin/psalm --no-cache` (~2 s) are cheap and fine at any time.
- Also fine: a scratch-project repro (skill `plugin-repro`).
- When briefing a subagent, spell all of this out ("single scenarios only, no full suite,
  no sweeps"); a vague "don't run the tests" is not enough.

### Psalm versions

The CI low jobs (`--prefer-lowest`) resolve the lowest `vimeo/psalm` that `composer.json`
allows, the high and stable jobs the newest. They can report different issues (from
7.0.0-rc28 the purity suggestions are opt-in via `suggestPurityAnnotations`).
- Always check `vendor/bin/psalm --version` before trusting a result.
- For a change that is sensitive to the Psalm version (issue names, purity, stubs, hook
  events), run the relevant scenarios on both (skill `plugin-repro`).

## Pull requests

- Push the branch to your fork, then
  `gh pr create --repo psalm/psalm-plugin-phpunit --base master`.
- Then poll `gh pr checks <n> --repo psalm/psalm-plugin-phpunit`. For `gh run list`,
  `--commit "$(git rev-parse <sha>)"` is reliable (a short SHA silently lists nothing);
  `--branch` sometimes returns stale runs. A failed job:
  `gh run view <id> --log-failed`.
- Prefer a PR even when asked to fix something on master.
- **Description:** follow skill `pr-description` (one-line bug + Before/After code blocks
  from a scenario of the PR that asserts the fix, nothing else). Use it to write new
  descriptions and to reformat existing ones when asked.

## Merging and releasing (maintainers with merge rights)

- Review the diff yourself, wait for green CI, merge, and **tag a release** (fixture, CI
  and dependency-only changes too). Tags have no `v` prefix (`0.21.1`, `0.21.0`, `0.20.4`).
  Create the release with `gh release create <tag> --generate-notes --repo
  psalm/psalm-plugin-phpunit`; a one-line summary above the generated notes is welcome for
  bigger releases (as in 0.21.0).
- Psalm 7.0.0 and master list `psalm/plugin-phpunit: ^0.21` in `require`: this plugin is
  bundled, so a release of it reaches `psalm.phar` users. Keep dev-only files out of the
  dist archive with `export-ignore` in `.gitattributes` (`tools/` was added in #168), and add
  a line there for every new dev-only path.
- Never use `--admin` to bypass red required checks unless asked for that specific PR.

## Agents and subagents

- Do fixes, reviews and PR work in the main session. Spawn a subagent only when asked to
  or for a genuinely independent, bounded task, and say so first.
- To review several PRs, use one subagent with an ordered target list (most urgent first,
  saying which to drop if time runs short), not one subagent per PR.
- Never use the Workflow tool unless explicitly asked for a workflow.
- Tell subagents the testing rules above explicitly. Give each subagent its own worktree.

## No workarounds

Never hide an issue instead of fixing it:
- no `@psalm-suppress`, `issueHandlers` or baseline entries added to dodge a problem, and no
  suppression in a scenario's config or fixture that hides the issue under test;
- no suppressing purity issues (`Impure*`, `Missing*Annotation`, `ImmutableDependency`) from a
  hook: if Psalm's purity model is wrong for test code, fix it in vimeo/psalm;
- no `ignoreFiles` to dodge `DuplicateClass`, and no `BeforeAddIssue` filtering plugins;
- no changing a fixture to dodge a plugin bug, and no reading Psalm internals via reflection
  because an API is missing. (Annotating fixtures for purity is not a workaround: it is the
  settled approach, #166.)

Fix the root cause in the plugin, its stub, or Psalm itself (report upstream bugs upstream), or
add the missing plugin API. If a proper fix is out of reach, say so and ask. List any
workaround explicitly in the report.

## Analysing this repo (instead of self-analysis)

- `vendor/bin/psalm --no-cache` analyses `src/` per `psalm.xml.dist` (errorLevel 1,
  `findUnusedPsalmSuppress`) with this plugin loaded from the checkout. ~2 s. The Behat
  helper is analysed separately: `cd tools/behat && vendor/bin/psalm` (Psalm ^6).
- With `--output-format=compact` a clean run prints **nothing** and exits 0. Judge compact
  runs by the exit code. The default format prints a "Checks took" summary. Empty output with
  a non-zero exit, or no summary in the default format, means Psalm didn't run.
- `vendor/bin/psalm` decides which checkout's plugin is loaded: use the worktree's own.

## Tests

- **Tests must assert the change.** Every scenario a PR adds or changes for the bug or
  feature itself must fail on the base branch and pass on the PR, because it checks the
  exact behaviour being fixed or added. Prove it by running that single scenario on both
  (see above). Edge-case scenarios that guard the change may pass on the base.
- Step semantics (`tools/behat/src/Context.php`):
  - the Background sets errorLevel 1, `findUnusedCode="false"`, suppresses
    `MissingClassConstType` and `DeprecatedMethod`, and prepends
    `<?php namespace NS; use PHPUnit\Framework\TestCase;` to the code;
  - `Then I see no errors`: the Psalm process exited 0;
  - `Then I see these errors` (table `| Type | Message |`): each row must match an issue's
    exact type **and** exact full message. Matched issues are removed;
  - `And I see no other errors`: nothing is left over. Without it, extra issues pass silently;
  - `When I run Psalm with dead code detection` adds `--find-dead-code`;
    `When I run Psalm on "<file>"` and `Then I see exit code N` also exist.
- Ways a scenario silently asserts nothing:
  - `I see no errors` for a missed-issue fix (it passes on the base): assert the issue with
    `I see these errors` + `I see no other errors`;
  - `I see these errors` without `I see no other errors` (extra issues are ignored);
  - a fixture `@psalm-suppress` or `issueHandlers` hiding the issue under test;
  - dead-code behaviour tested with plain `When I run Psalm` (needs
    `with dead code detection`).
- A failing scenario prints the issues Psalm found as JSON: `Psalm failures encountered:`
  (`I see no errors`), `Some errors didn't match expected ones.` (`I see these errors`) or
  `No further errors expected, found:` (`I see no other errors`). Copy the exact type and
  message from it.
- Fixtures must pass on the lowest and the newest Psalm: annotate them for purity (#166):
  data providers `@psalm-pure`, mocked interfaces `@psalm-mutable` with `@psalm-impure`
  methods. Never suppress the `Missing*Annotation` issues instead.
- Put each docblock tag on its own line, in fixtures and in `src/`. `/** @psalm-pure @param
  ... */` silently drops every tag after the first.
- Never start a docblock line in `src/` with an example `@psalm-...` tag; Psalm parses it as
  a real annotation.

## Code style

- phpcs (`phpcs.xml.dist`): PSR12, short arrays, 120-character absolute line limit, applied
  to `src/`. Run `vendor/bin/phpcs`
  (`vendor/bin/phpcbf` fixes).
- Match the surrounding code: comment density, naming, idiom.
- Comments are concise and only explain what isn't obvious from the code:
  - don't restate the code in prose;
  - don't mention approaches that were tried, considered, replaced or removed, or
    anything that only makes sense in the context of an agent's iteration history;
  - prefer deleting an unnecessary comment over expanding or rewording it;
  - document an idea once, where it naturally belongs.
- Documentation (README, user-facing docblocks): more examples, less text. Show behaviour
  with a code example whose lines end in their result (`// UndefinedMethod`,
  `// no issue`), and keep the prose around it to a sentence. Check each line's result on the
  branch before writing it. No dashes as punctuation in prose: use periods, commas or
  parentheses.

## Debugging pitfalls

- STDERR from analysis gets swallowed: Behat parses Psalm's `--output-format=json` output and
  `--output-format=compact` is usually piped through grep. Debug with
  `file_put_contents('/path', ..., FILE_APPEND)` in the hook.
- Compact output that is empty with exit 0 is clean. Empty output with a non-zero exit, or
  no "Checks took" summary in the default format, means Psalm didn't run (wrong cwd, missing
  `vendor/`, crash). Watch for crashes (exit 11, segfault).
- Behat runs the **root** `vendor/bin/psalm`, so a stale root `vendor/` (or the wrong Psalm
  version) changes scenario results. Check `vendor/bin/psalm --version`.

## Shell, worktrees and git

- Write commands that work in both zsh (macOS default) and bash (usual on Linux); check
  with `echo $0` if unsure:
  - Quote globs meant for the tool, not the shell (`grep --include='*.php'`). In zsh an
    unmatched glob aborts the whole `&&` chain ("no matches found"); in bash it is passed
    on literally, so the command quietly acts on a path that doesn't exist. `ls` repro files
    before concluding anything from an absent issue.
  - Brace variables next to a colon: `"${b}:branch"`. In zsh `$b:l`, `$r:t`, … are history
    modifiers and mangle refspecs; braces are harmless in bash.
  - Word-splitting a variable of args: zsh needs `${=args}`, bash splits unquoted `$args`.
    Prefer an array (`args=(a b); cmd "${args[@]}"`), which behaves the same in both.
- The working directory resets between Bash calls. Start every command that edits,
  commits or runs Psalm in a worktree with `cd <worktree> &&` (or use absolute paths),
  and check `git status` in the intended worktree before committing.
- All worktrees of this repository share one stash list. Never use `git stash`, and never
  pop or drop entries you didn't create. To compare with and without a change to `src/` or
  `stubs/`, reverse only the source change (a new scenario is kept):
  `git diff "$(git merge-base origin/master HEAD)" -- src stubs > f.patch && git apply -R f.patch`,
  run, then restore with `git apply f.patch`. Or use a second worktree on `origin/master` with
  the scenario copied in.
- Keep worktrees outside the repository directory, and scratch repros and probe dirs under
  `/tmp` or the session scratchpad. `/tmp` may be wiped on reboot, so don't keep anything
  there that must survive.
- A worktree needs its **own real `vendor/`** at the root and in `tools/behat`
  (`composer update` as above, or `cp -R`). A symlinked `vendor/` makes Composer's autoloader
  resolve `Psalm\PhpUnitPlugin\` through the real path and load the other checkout's `src/`.
- `composer.lock` at the root is gitignored; `tools/behat/composer.lock` is tracked. A
  `composer update` there rewrites it: don't commit that by accident.

## Platform differences

The instructions here and in `.agents/skills/` target macOS and Linux. Where a command
differs, use the right column for the current OS (`uname` prints `Darwin` or `Linux`):

| Task | macOS | Linux |
|---|---|---|
| Time limit | `timeout` from Homebrew coreutils (`gtimeout` if only that is on PATH) | `timeout` (coreutils, preinstalled) |
| In-place sed | `sed -i '' ...` | `sed -i ...` (or use a short PHP script on both) |
| Temp dir | `/tmp` (= `/private/tmp`) | `/tmp` |
