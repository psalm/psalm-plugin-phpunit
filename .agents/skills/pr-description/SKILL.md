---
name: pr-description
description: Use when writing the description of a psalm/psalm-plugin-phpunit pull request (gh pr create / gh pr edit), or when asked to reformat, tidy or shorten an existing PR description, including PRs opened by other people. Defines the house format (one-line bug + Before/After code blocks taken from Behat scenarios that assert the fix) and how to verify them.
---

# PR descriptions

## Format

As brief as possible: the reader only cares which bug is fixed, shown with code. The shape
(the scenario "Unused calls after expectException are not reported" from #169, which fixed #108):

````markdown
Psalm reports `UnusedFunctionCall` and `UnusedMethodCall` for statements after `expectException()`, although they exist only to throw.

**Before**
```php
<?php
final class MyTestCase extends TestCase {
    public function testAfter(): void {
        $this->expectException(\JsonException::class);
        json_decode('', flags: JSON_THROW_ON_ERROR); // UnusedFunctionCall: The call to json_decode is not used
        (new Value())->get(); // UnusedMethodCall: The call to NS\Value::get is not used
    }
}
```

**After**
```php
        json_decode('', flags: JSON_THROW_ON_ERROR); // no issue
        (new Value())->get(); // no issue
```

Fixes #108
````

- **One sentence** naming the bug, as the user sees it (wrong issue, missed issue, crash,
  wrong inferred type), not the implementation.
- A **Before** block: the code of a scenario of the PR that asserts the fix (see below),
  plus what the base reports, written as trailing `// IssueName` (or `// IssueName: short
  message` when the message matters) comments on the lines where the issue appears.
- An **After** block with **only the lines whose result changes**, commented with the new
  result (`// no issue`, `// InvalidReturnType`, or the new inferred type).
- **Several bugs in one PR:** one short `###` heading per bug, each with its own one-line
  summary and Before/After pair.
- **No PHP example possible** (fixture-only, CI, dependency or tooling changes): one plain
  line, e.g. "Annotate the acceptance fixtures for Psalm 7 purity." Numbers only if they
  *are* the fix.
- A user-visible limitation or behaviour change may get one line at the end.
- Keep closing keywords for issues the PR fixes (`Fixes #1234`) on their own last line, so
  GitHub links and closes them.
- Leave out: background and motivation, design notes, "stacked on / combines / merged
  #…", measurements that aren't the point, review follow-ups, checklists, scenario lists,
  changelog prose, and any AI attribution.

## Every example is a scenario that asserts the fix

- Each Before/After example must correspond to a Behat scenario of the PR, and that
  scenario must **assert the fix**: it fails on `origin/master` and passes on the branch,
  because it checks exactly the result the After block shows (see "Tests must assert the
  change" in AGENTS.md for how scenarios silently fail to do that).
- The example is that scenario's code (the Behat preamble `namespace NS; use
  PHPUnit\Framework\TestCase;` is implied, show `<?php` at most). If the scenario is long,
  the description may show only the lines that matter, as long as the scenario asserts what
  they show. Never show a snippet no scenario covers.
- If no scenario makes a short, clear example, add one to the PR first. Specific,
  easy-to-follow examples beat abstract ones (`Foo`/`bar` is fine).
- **Verify by running that single scenario** on `origin/master` (must fail) and on the
  branch (must pass):
  ```
  cd tools/behat && vendor/bin/behat ../../tests/acceptance/TestCase.feature:<line of Scenario:>
  ```
  To get the base, use a second worktree on `origin/master` (with its own real `vendor/`
  at the root and in `tools/behat`, see skill `plugin-repro`), or
  `git diff "$(git merge-base origin/master HEAD)" -- src stubs > f.patch && git apply -R f.patch`
  (and re-apply with `git apply f.patch` afterwards). Never `git stash`.
- On the base the failing scenario prints the issues Psalm found as JSON (`Psalm failures
  encountered: [...]`). Copy the issue names and messages in the Before comments from there.
  Never write invented or "illustrative" output.
- Check `vendor/bin/psalm --version` first: rc18 and newer Psalm can report different issues
  (skill `plugin-repro`).

## Reformatting an existing description (including other people's PRs)

Only when asked, and only for PRs in repos you may edit (psalm/psalm-plugin-phpunit: editing
someone else's PR body needs maintainer rights). Existing Context/Solution/Limitations
descriptions (e.g. #169 to #172) stay as they are unless asked.

1. Read the current body, title and diff:
   `gh pr view <n> --repo psalm/psalm-plugin-phpunit --json title,body,author,files` and
   `gh pr diff <n> --repo psalm/psalm-plugin-phpunit`.
2. Work out the bug(s) actually fixed from the **diff and the scenarios it adds**, not only
   from the prose. Pick the examples from the PR's scenarios, and check that those scenarios
   assert the fix. If none does, or none makes a usable example, tell the user and suggest a
   scenario to add; don't push scenarios to someone else's PR unless asked.
3. Keep everything the author wrote that matters to reviewers in the new format: the bug
   summary, issue links / closing keywords, and any explicit note about a behaviour change
   users must know about (one line at the end). Drop the rest.
4. Verify the examples by running each one's scenario on `origin/master` and on the PR head
   (`gh pr checkout <n>` in a separate worktree, or `git fetch origin pull/<n>/head`).
5. Show the new body to the user before replacing someone else's. Then:
   `gh pr edit <n> --repo psalm/psalm-plugin-phpunit --body-file <file>`. Don't change the
   title unless asked; if it's misleading, suggest a new one.
6. Don't touch the code or reviews of the PR as part of this.
