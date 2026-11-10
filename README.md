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
* The datasets of a literal closure in a `#[DataProviderClosure]` (PHPUnit 13.1 and newer, closures in attributes need PHP 8.5) are validated the same way, against the return type Psalm infers for the closure: `#[DataProviderClosure(static fn (): iterable => [['not an int']])]` on `testFoo(int $a)` is an `InvalidArgument`.
* Datasets with string keys (`['cents' => 100, 'currency' => 'EUR']`) are matched to the test parameters by name. Unknown, already used and missing names are reported as `InvalidNamedArgument` and `TooFewArguments`, as is a string-keyed dataset on a test with a `@depends` / `#[Depends]` dependency that passes a value, because PHPUnit appends that value as a positional argument after the named ones. A dependency passes no value when its test is declared `void`. Before PHPUnit 12.5.40 and 13.4.3 (and on PHPUnit 11) PHPUnit stops at the first `void` dependency, so only the first dependency counts, and only when it is a method of the same class. Tests with a size group in a method docblock (`@small`, `@group medium` and so on) are then skipped, since PHPUnit may ignore the values of a larger dependency.
* A positional entry after a named one in a literal dataset (`['b' => 'x', 0 => 1]`, which PHP rejects when PHPUnit unpacks it) is reported as `InvalidNamedArgument`.
* Docblock annotations that PHPUnit ignores because they have no value or no space before it (`/** @dataProvider*/`, `@depends` alone on a line, `@group(slow)`) are reported as `InvalidPhpUnitAnnotation`, not as a missing data provider. This covers the class docblocks of the traits a test case uses directly, which PHPUnit merges into the test class.
* Test parameters take the types their data providers return: with `@return iterable<int, array{int, string}>`, `testFoo(mixed $a, mixed $b)` sees `int $a` and `string $b`, so there is no `MixedAssignment`. Parameters with a default, variadic parameters and parameters that already have a narrower type keep their declared type.
* Coverage targets are validated: a missing class, method or function in `#[CoversMethod]`, `#[UsesMethod]`, `#[CoversFunction]`, `#[UsesFunction]` or a docblock `@covers`, `@uses`, `@coversDefaultClass`, `@usesDefaultClass` is reported as `UndefinedClass`, `UndefinedMethod` or `UndefinedFunction`.
* Test methods, their data providers, and `TestCase` classes are not reported as unused code. As in PHPUnit, only public methods count as tests, for the provider validation above and for this.
* Statements after `$this->expectException()` and its siblings are not reported as `UnusedFunctionCall`, `UnusedMethodCall` or `MissingThrowsDocblock`.
* Exceptions declared by PHPUnit's own API (assertions, `createMock()`, `createStub()` and so on) are not reported as `MissingThrowsDocblock`. Exceptions in your `<ignoreExceptions>` stay ignored.
* `assertSame(null, ...)`, `assertSame(true|false, ...)` and `assertSame(n, count(...))` are reported as `UnspecificNullAssertion`, `UnspecificBooleanAssertion` and `UnspecificCountAssertion` (at `errorLevel="1"`), suggesting `assertNull()`, `assertTrue()`/`assertFalse()` and `assertCount()`. Either argument order is reported (`assertSame($value, null)`, `assertSame(count($items), 3)`).
* `->method('name')` on a mock or stub is reported as `UndefinedMethod` when the mocked class has no such method (`$mock->method('sendInvoce')`). Names covered by `@method` or `__call()` are accepted. When the double is a union of mocks, every mocked class must have the method.
* On PHPUnit 12 and newer, which ignores metadata in docblocks, `@test`, `@dataProvider`, `@covers` and the other docblock tags are reported as `IgnoredDocblockMetadata`, suggesting the attribute to use (`#[Test]`, `#[DataProvider]`, `#[CoversClass]`, ...). They no longer count as test or data provider declarations.
* `assertEquals()` and `assertNotEquals()` with two `int`, `float`, `string` or `bool` arguments (`assertEquals(1, $int)`) are reported as `UnspecificEqualsAssertion` (at `errorLevel="1"`), suggesting `assertSame()` / `assertNotSame()`. Nullable and mixed arguments are not reported. With `true` or `false` as one argument and a `bool` as the other (`assertEquals(true, $flag)`, `assertEquals($flag, true)`) the report is `UnspecificBooleanAssertion` instead, suggesting `assertTrue()` / `assertFalse()` and their `Not` variants.
* `createMockForIntersectionOfInterfaces([A::class, B::class])` and `createStubForIntersectionOfInterfaces(...)` are typed as `A&B&MockObject` and `A&B&Stub`, so the methods of `A` and `B` can be called on the double without `UndefinedInterfaceMethod`.
* `setUp()`, `tearDown()`, `setUpBeforeClass()`, `tearDownAfterClass()`, `assertPreConditions()` and `assertPostConditions()` overrides that never call `parent::` are reported as `MissingParentCall`, unless the parent is `TestCase` itself.
* Magic calls on the `ObjectProphecy` that `ProphecyTrait::prophesize()` returns resolve to `MethodProphecy`.
* `assertNotEmpty($x)` narrows `$x` to its non-empty type (`?Customer` becomes `Customer`, `list<int>|null` becomes `non-empty-list<int>`).

## License

MIT
