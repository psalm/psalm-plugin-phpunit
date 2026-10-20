# psalm-plugin-phpunit

A [Psalm](https://github.com/vimeo/psalm) plugin for PHPUnit (requires Psalm v4+).

## What it does

Psalm does not understand PHPUnit conventions on its own. This plugin makes Psalm aware of them, so static analysis of your test suite stops flooding you with false positives.

## Features

* **Silences false `MissingConstructor`** on stateful test cases. Properties initialized in `setUp()` or a `@before` / `#[Before]` method are recognized as initialized.
* **Validates data providers.** It checks that a referenced provider exists, returns an `iterable` (array, generator, or object), and that each dataset shape matches the parameters of the test method it feeds (types, count, optional offsets, variadic params, defaults).
* **Reports broken providers.** Missing providers, wrong return types, mismatched dataset types, and providers returning `null` are flagged before the suite ever runs.
* **Fixes unused-code detection for tests.** Test methods, providers referenced from docblocks or attributes, and `TestCase` descendants are no longer reported as unused, while genuinely dead test helpers still are.
* **Types `prophesize()`.** `$this->prophesize(Foo::class)` is inferred as `ObjectProphecy<Foo>`, so calls on the prophecy are type-checked.

## Installation

```
composer require --dev psalm/plugin-phpunit
vendor/bin/psalm-plugin enable psalm/plugin-phpunit
```
