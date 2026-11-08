---
name: plugin-repro
description: Use when reproducing a psalm-plugin-phpunit bug from the CLI, showing a new Behat scenario fails on the base branch, comparing plugin behaviour between a branch and origin/master, or comparing Psalm versions (7.0.0-rc18 vs dev-master), or reading CI logs.
---

# Plugin repros and version comparisons

## Scratch-project repro

1. Make a fresh dir under `/tmp` (or the scratchpad) with a `src/` and a minimal
   `psalm.xml`:

   ```xml
   <?xml version="1.0"?>
   <psalm errorLevel="1" findUnusedCode="false">
       <projectFiles><directory name="src"/></projectFiles>
       <plugins><pluginClass class="Psalm\PhpUnitPlugin\Plugin"/></plugins>
   </psalm>
   ```

   - Dead-code behaviour (unused methods, providers, `UnusedMethodCall`) needs
     `findUnusedCode="true"` or `--find-dead-code`.
   - Put the repro under `src/` as a `*Test.php` file with `namespace NS;` and
     `use PHPUnit\Framework\TestCase;`, like a Behat scenario does.
2. Run
   `cd <dir> && <worktree>/vendor/bin/psalm --no-cache --no-progress --output-format=compact`.
   The `vendor/bin/psalm` path decides which checkout's plugin `src/` is loaded, so use
   the worktree under test.
   Example output line (exit code 2 when there are errors):
   `ERROR src/FooTest.php:7:28 MissingPureAnnotation: ...`
3. `ls` the repro files first: an unmatched glob can abort the rest of the command (zsh)
   or be passed on literally so the command acts on a nonexistent path (bash), and a
   missing file looks exactly like "no issue". A clean `compact` run prints nothing and
   exits 0; empty output with a non-zero exit means Psalm didn't run. In the default format
   a real run prints "Checks took ...".
4. Delete the scratch dir when done.

To show a new scenario fails on the base, either use a CLI repro or run **just that
scenario** in a base worktree (skill `pr-description`, AGENTS.md "Validating changes"):

```
cd tools/behat && vendor/bin/behat ../../tests/acceptance/TestCase.feature:<line of Scenario:>
```

Never run the whole suite for this.

## Comparing branch and base

- Second worktree on `origin/master`: `git worktree add <dir> origin/master`, outside the
  repo directory. Give it its **own real `vendor/`** at the root and in `tools/behat`
  (`COMPOSER_ROOT_VERSION=dev-master composer update --prefer-dist -n` in each, or
  `cp -R`). Never a symlink: Composer's autoloader would resolve `Psalm\PhpUnitPlugin\`
  through the real path and load the other checkout's `src/`.
- Or, without a second worktree, reverse only the source change (a new scenario is kept):
  `git diff "$(git merge-base origin/master HEAD)" -- src stubs > f.patch && git apply -R f.patch`,
  run, then restore with `git apply f.patch`. Never `git stash` (the stash list is shared by all
  worktrees).
- Run each checkout's `vendor/bin/psalm` on the same scratch project and diff the outputs.
- Always `cd <worktree> &&` in the same command.

## Comparing Psalm versions

Check `vendor/bin/psalm --version` before trusting any result.

- `COMPOSER_ROOT_VERSION=dev-master composer update` resolves `vimeo/psalm` to
  **7.0.0-rc18** (what CI tests): later releases require `psalm/plugin-phpunit ^0.21`,
  which the root package `dev-master` doesn't satisfy. Prove it with
  `COMPOSER_ROOT_VERSION=dev-master composer why-not vimeo/psalm 7.0.1`.
- `COMPOSER_ROOT_VERSION=0.21.99 composer update` resolves `vimeo/psalm` dev-master.
- To compare both, use two worktrees (or two scratch copies of the checkout), each with its
  own `vendor/` installed with one of the two commands, and run the same scenario or
  scratch repro in each. Behat runs the root `vendor/bin/psalm`, so the root install
  decides the version.
- A difference between them is either a plugin bug on one version or a Psalm change (for
  example, from 7.0.0-rc28 the purity suggestions `MissingPureAnnotation` and three others
  are opt-in, skill `purity-capabilities`). Report which it is.

## Reading CI logs

- `gh run list --repo psalm/psalm-plugin-phpunit --commit <sha>` rather than `--branch`,
  which can be stale.
- `gh run view <id> --repo psalm/psalm-plugin-phpunit --log-failed`.
- The `psalm` and `tests` jobs both start with `composer update`: check which Psalm version
  they resolved before reading the failure.
