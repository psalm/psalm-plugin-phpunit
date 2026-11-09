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

**Psalm 7:**

```bash
# nothing to install.
# The plugin ships with Psalm and is enabled automatically when your `composer.json` requires `phpunit/phpunit`
```

(see [`loadLibraryPlugins`](https://psalm.dev/docs/running_psalm/configuration/#loadlibraryplugins)).

**Psalm 6 and older:**

```bash
composer require --dev psalm/plugin-phpunit
vendor/bin/psalm-plugin enable psalm/plugin-phpunit
```

## Features

* Properties initialized in `setUp()` or a `@before` / `#[Before]` method count as initialized, so no false `MissingConstructor`.
* Data providers (`@dataProvider`, `#[DataProvider]`, `#[DataProviderExternal]`) are validated: the provider exists, is `public static` (`InvalidDataProvider`), returns an `iterable`, and its datasets match the parameters of the test method.
* Docblock annotations that PHPUnit ignores because they have no value or no space before it (`/** @dataProvider*/`, `@depends` alone on a line, `@group(slow)`) are reported as `InvalidPhpUnitAnnotation`, not as a missing data provider.
* Test methods, their data providers, and `TestCase` classes are not reported as unused code.
* Statements after `$this->expectException()` and its siblings are not reported as `UnusedFunctionCall`, `UnusedMethodCall` or `MissingThrowsDocblock`.
* Exceptions declared by PHPUnit's own API (assertions, `createMock()`, `createStub()` and so on) are not reported as `MissingThrowsDocblock`. Exceptions in your `<ignoreExceptions>` stay ignored.
* `assertSame(null, ...)`, `assertSame(true|false, ...)` and `assertSame(n, count(...))` are reported as `UnspecificNullAssertion`, `UnspecificBooleanAssertion` and `UnspecificCountAssertion` (at `errorLevel="1"`), suggesting `assertNull()`, `assertTrue()`/`assertFalse()` and `assertCount()`.
* `->method('name')` on a mock or stub is reported as `UndefinedMethod` when the mocked class has no such method (`$mock->method('sendInvoce')`). Names covered by `@method` or `__call()` are accepted.
* On PHPUnit 12 and newer, which ignores metadata in docblocks, `@test`, `@dataProvider`, `@covers` and the other docblock tags are reported as `IgnoredDocblockMetadata`, suggesting the attribute to use (`#[Test]`, `#[DataProvider]`, `#[CoversClass]`, ...). They no longer count as test or data provider declarations.
* `assertEquals()` and `assertNotEquals()` with two `int`, `float`, `string` or `bool` arguments (`assertEquals(1, $int)`) are reported as `UnspecificEqualsAssertion` (at `errorLevel="1"`), suggesting `assertSame()` / `assertNotSame()`. Nullable and mixed arguments are not reported.
* `createMockForIntersectionOfInterfaces([A::class, B::class])` and `createStubForIntersectionOfInterfaces(...)` are typed as `A&B&MockObject` and `A&B&Stub`, so the methods of `A` and `B` can be called on the double without `UndefinedInterfaceMethod`.
* `$this->prophesize(Foo::class)` is typed as `ObjectProphecy<Foo>`, and magic calls on it resolve to `MethodProphecy`.
* `assertNotEmpty($x)` narrows `$x` to its non-empty type (`?Customer` becomes `Customer`, `list<int>|null` becomes `non-empty-list<int>`).

## License

MIT
