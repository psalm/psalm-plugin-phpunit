---
name: plugin-repro
description: Use when reproducing a psalm-plugin-phpunit bug from the CLI, showing a new Behat scenario fails on the base branch, comparing plugin behaviour between a branch and origin/master, or comparing Psalm versions (lowest vs newest), or reading CI logs.
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
     `--find-dead-code`. Keep `findUnusedCode="false"`, as Behat does: `"true"` adds
     `PossiblyUnusedReturnValue` noise.
   - Put the repro under `src/` as a `*Test.php` file with `namespace NS;` and
     `use PHPUnit\Framework\TestCase;`, like a Behat scenario does. Declare the class
     `final` (otherwise `ClassMustBeFinal`).
2. Run
   `cd <dir> && <worktree>/vendor/bin/psalm --no-cache --no-progress --output-format=compact`.
   The `vendor/bin/psalm` path decides which checkout's plugin `src/` is loaded, so use
   the worktree under test.
   Example output line (exit code 2 when there are errors):
   `ERROR src/FooTest.php:7:28 MissingPureAnnotation: ...`
3. `ls` the repro files first: a missing file looks exactly like "no issue". A clean
   `compact` run prints nothing and exits 0; empty output with a non-zero exit means Psalm
   didn't run.
4. Delete the scratch dir when done.

To show a new scenario fails on the base, either use a CLI repro or run **just that
scenario** in a base worktree (skill `pr-description`, AGENTS.md "Validating changes"):

```
cd tools/behat && vendor/bin/behat ../../tests/acceptance/TestCase.feature:<line of Scenario:>
```

Never run the whole suite for this.

## Comparing branch and base

- Second worktree on `origin/master`: `git worktree add <dir> origin/master`, outside the
  repo directory, with its own real `vendor/` at the root and in `tools/behat`.
- Or reverse only the source change in the same worktree (AGENTS.md "Shell, worktrees and
  git").
- Run each checkout's `vendor/bin/psalm` on the same scratch project and diff the outputs.
- Always `cd <worktree> &&` in the same command.

## Comparing Psalm versions

Check `vendor/bin/psalm --version` before trusting any result.

- To compare the lowest and the newest, use two worktrees (or two scratch copies of the
  checkout), each with its own `vendor/`: one installed with
  `composer update --prefer-lowest --prefer-stable`, one with plain `composer update`
  (as AGENTS.md "Locally"), and run the same scenario or scratch repro in each. Behat runs
  the root `vendor/bin/psalm`, so the root install decides the version.
- A difference between them is either a plugin bug on one version or a Psalm change
  (AGENTS.md "Psalm versions"). Report which it is.

## Reading CI logs

- `gh run list --repo psalm/psalm-plugin-phpunit --commit "$(git rev-parse <sha>)"`: a short
  SHA silently lists nothing, and `--branch` can be stale.
- `gh run view <id> --repo psalm/psalm-plugin-phpunit --log-failed`.
- Check which Psalm each job resolved before reading a failure:
  `gh run view <id> --repo psalm/psalm-plugin-phpunit --log | grep 'Locking vimeo/psalm'`
  (a plain `vimeo/psalm` grep also matches the Psalm 6 that `tools/behat` installs).
