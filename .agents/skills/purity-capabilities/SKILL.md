---
name: purity-capabilities
description: Use when Psalm 7 purity touches this plugin, i.e. a Behat scenario or fixture hitting MissingPureAnnotation / MissingInterfaceImmutableAnnotation / MissingAbstractPureAnnotation / ImpureMethodCall, annotating fixtures with @psalm-pure / @psalm-impure / @psalm-mutable, purity of stubs/TestCase.phpstub, the iterable purity of provider types built in TestCaseHandler, or hooks that add suppressed issues. Records the settled decisions, which must not be relitigated.
---

# Purity and capabilities in this plugin

The purity model itself (capability bitmask, purity templates, bracket syntax, SPL stubs,
memoization) lives in vimeo/psalm. Read it there, not here:
- skill: https://github.com/vimeo/psalm/blob/master/.agents/skills/purity-capabilities/SKILL.md
- docs: https://psalm.dev/docs/annotating_code/purity_model/
  (`docs/annotating_code/purity_model.md` in vimeo/psalm)

This skill only covers where the model touches *this* repo.

## Where purity shows up here

- `tests/acceptance/TestCase.feature`: fixtures are analysed at errorLevel 1, so unannotated
  code gets purity suggestions (below).
- `stubs/TestCase.phpstub`: the only stub (types `prophesize()`).
- `src/Hooks/TestCaseHandler.php`: builds `TIterable` types for provider checks, adds
  suppressed issues, and has two legacy `@psalm-mutation-free` /
  `@psalm-external-mutation-free` tags (`getDescendants` and the `$combine` closure in
  `unionizeIterables`).

## Settled decisions: don't propose reverting them

- **Annotate fixtures, never suppress.** Decided in #166. Fixtures in `TestCase.feature`
  carry purity annotations instead of `issueHandlers` or `@psalm-suppress` for the
  `Missing*Annotation` issues. The patterns:
  - data providers: `@psalm-pure` and `static`;
  - interfaces that fixtures mock: `/** @psalm-mutable */` on the interface and
    `/** @psalm-impure */` on its methods.
  ```php
  /** @psalm-mutable */
  interface I {
    /** @psalm-impure */
    public function work(): int;
  }
  ```
- **rc18 vs newer Psalm.** On 7.0.0-rc18 (what CI resolves, see "Psalm version trap" in
  AGENTS.md) unannotated fixture code at errorLevel 1 reports:
  - `MissingInterfaceImmutableAnnotation` (an interface);
  - `MissingAbstractPureAnnotation` (an interface method);
  - `MissingPureAnnotation` (e.g. a plain static provider: `plain must be marked
    @psalm-pure ...`).

  From 7.0.0-rc28 these three and `MissingImmutableAnnotation` are opt-in
  (`suggestPurityAnnotations="true"`, default false; vimeo/psalm cc2b759a3, #12835). So
  fixtures must pass on both, which means annotating them. A scenario that passes only
  because the suggestions are off on newer Psalm can still fail on rc18.
- **PHPUnit is impure for Psalm.** PHPUnit ships no purity annotations and Psalm has no
  PHPUnit stubs, so every PHPUnit method counts as impure. A `@psalm-pure` provider that
  calls `self::assertTrue(true)` reports
  `ImpureMethodCall: The context is pure but method NS\FooTest::assertTrue requires impure`.
  Test methods are unannotated (impure) and may call anything. Don't try to make that
  quiet from the plugin.
- **Never suppress purity issues from a hook.** The hooks suppress `MissingConstructor`
  (`$storage->suppressed_issues`), and `UnusedFunctionCall` / `UnusedMethodCall`
  (`addSuppressedIssues` after `expectException*()`). Never add `Impure*`,
  `Missing*Annotation` or `ImmutableDependency` to those lists: if Psalm's purity model is
  wrong for test code, fix it in vimeo/psalm.
- **Annotation names in `src/` and fixtures:** `@psalm-pure`, `@psalm-impure`,
  `@psalm-capabilities <names>`, `@psalm-immutable`, `@psalm-mutable`.
  `@psalm-mutation-free` and `@psalm-external-mutation-free` are parse-only aliases in
  Psalm 7 (never printed, suggested or documented). Don't add new ones. Replacing the two
  that `src/` still has is a separate change: don't touch them in an unrelated PR.
- Psalm maintainer decisions listed in vimeo/psalm's purity-capabilities skill are settled
  and apply here too. Don't relitigate them, and don't work around them in the plugin.

## Stubs

- Capability checks use only what the callee declares. Inference feeds only the
  suggestions, never the checks ("Inferring annotations" in `purity_model.md`). So a method in
  `stubs/TestCase.phpstub` without a purity annotation is impure, whatever the vendor's
  docblock said: a stub must redeclare purity (`@psalm-pure`, `@psalm-capabilities`, purity
  templates) if the original has any.
- Prefer a hook over a stub that redeclares a vendor class: stubs drift and drop the
  vendor's `@throws` and signatures (#171).

## Provider types

Psalm 7's `TIterable` has a `Union $purity` that defaults to impure (constructor in
`vendor/vimeo/psalm/src/Psalm/Type/Atomic/TIterable.php`). `TestCaseHandler` builds
`new TIterable([...])` for the expected provider type (`iterable<array-key, array>`) and in
`unionizeIterables`. Keep that default for "accepts any provider" types, so pure generators
and iterables of any purity are accepted. A provider message such as
`iterable[pure]<int, int> provided` shows the purity of the *provided* type.

## Pitfalls

- One docblock tag per line in fixtures and in `src/`: `/** @psalm-pure @param ... */`
  drops every tag after the first.
- Never start a docblock line in `src/` with an example `@psalm-...` tag; Psalm parses it
  as a real annotation.
- A fixture that is "fixed" by adding `@psalm-suppress` for a purity issue is wrong, see
  above. A fixture that stays clean on newer Psalm may still fail on rc18: run both
  (skill `plugin-repro`).

## Known gaps

- PHPUnit's own methods are all impure for capability checks, so pure helpers in tests
  can't call assertions. This is Psalm's model with unannotated vendors, not a plugin bug.
- The two legacy `@psalm-mutation-free` tags in `src/Hooks/TestCaseHandler.php` remain
  until a dedicated change replaces them.
