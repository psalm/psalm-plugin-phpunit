<p align="center">
  <a href="https://psalm.dev"><img src=".github/img/psalm.svg" alt="Psalm" height="64"></a>
  &nbsp;&nbsp;
  <a href="https://phpunit.de"><img src=".github/img/phpunit.svg" alt="PHPUnit" height="64"></a>
</p>

<h1 align="center">Psalm PHPUnit plugin</h1>

<p align="center">
  <a href="https://github.com/psalm/psalm-plugin-phpunit/actions/workflows/ci.yml"><img src="https://github.com/psalm/psalm-plugin-phpunit/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <a href="https://shepherd.dev/github/psalm/psalm-plugin-phpunit"><img src="https://shepherd.dev/github/psalm/psalm-plugin-phpunit/coverage.svg" alt="Type coverage"></a>
</p>

Teaches [Psalm](https://psalm.dev) the conventions of [PHPUnit](https://phpunit.de), so analysing your test suite stops producing false positives.

## Installation

**Psalm 7:** nothing to install. The plugin ships with Psalm and is enabled automatically when your `composer.json` requires `phpunit/phpunit` (see [`loadLibraryPlugins`](https://psalm.dev/docs/running_psalm/configuration/#loadlibraryplugins)).

**Psalm 6 and older:**

```bash
composer require --dev psalm/plugin-phpunit
vendor/bin/psalm-plugin enable psalm/plugin-phpunit
```

## Features

* Properties initialized in `setUp()` or a `@before` / `#[Before]` method count as initialized, so no false `MissingConstructor`.
* Data providers are validated: the provider exists, is `public static` (`InvalidDataProvider`), returns an `iterable`, and its datasets match the parameters of the test method.
* Test methods, their data providers, and `TestCase` classes are not reported as unused code.
* Statements after `expectException()` and its siblings are not reported as `UnusedFunctionCall` or `UnusedMethodCall`.
* `$this->prophesize(Foo::class)` is typed as `ObjectProphecy<Foo>`, and magic calls on it resolve to `MethodProphecy`.

## License

MIT
