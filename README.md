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

Plugin issues are suppressed by name: `<PluginIssue name="MissingParentCall" errorLevel="suppress"/>`.

### Data providers and datasets

Providers (`#[DataProvider]`, `#[DataProviderExternal]`, `#[DataProviderClosure]`, `@dataProvider`) and their datasets are checked against the test method. A provider that is not `public static` is an `InvalidDataProvider`. Named datasets are matched to parameters by name (`InvalidNamedArgument`, `TooFewArguments`). Parameters take the types of the datasets.

```php
public static function amounts(): iterable
{
    yield [100];
    yield ['100'];
}

#[DataProvider('amounts')] // InvalidArgument
public function testAmount(int $cents): void {}

#[DataProvider('amunts')] // UndefinedMethod
public function testTypo(int $cents): void {}
```

### Test discovery and unused code

Tests, providers and `TestCase` classes are not unused code. Properties set in `setUp()` or a `#[Before]` method are initialized (no `MissingConstructor`). Exceptions declared by PHPUnit's API are not `MissingThrowsDocblock`.

```php
$this->expectException(InvalidArgumentException::class);
strtoupper($name); // no UnusedFunctionCall
```

### Coverage targets

Classes, methods and functions in coverage attributes (and `@covers` on PHPUnit 11 and older) must exist.

```php
#[CoversMethod(Invoice::class, 'totl')] // UndefinedMethod
#[CoversFunction('format_money')] // UndefinedFunction
```

### Assertion suggestions

Assertions that a dedicated one expresses better are reported as `UnspecificNullAssertion`, `UnspecificBooleanAssertion`, `UnspecificCountAssertion` and `UnspecificEqualsAssertion`, at `errorLevel="1"` only.

```php
self::assertSame(null, $maybe); // UnspecificNullAssertion
self::assertSame(true, $flag); // UnspecificBooleanAssertion
self::assertSame(3, count($items)); // UnspecificCountAssertion
self::assertEquals(1, $int); // UnspecificEqualsAssertion
```

### Mocks and doubles

Methods configured on a mock or stub must exist on the mocked class. Intersection doubles and Prophecy calls get their proper types.

```php
$mailer = $this->createMock(Mailer::class);
$mailer->method('sendd'); // UndefinedMethod
```

### Docblock metadata

PHPUnit 12 and newer ignore docblock metadata, so it is an `IgnoredDocblockMetadata`. On older versions, annotations PHPUnit cannot parse (`@dataProvider` with no value) are an `InvalidPhpUnitAnnotation`.

```php
/** @test */ // IgnoredDocblockMetadata
public function itWorks(): void {}
```

### Parent calls in hooks

When a base test case declares `setUp()`, `tearDown()` or another fixture hook, overrides must call `parent::`, or they are a `MissingParentCall`.

```php
final class OrderTest extends DatabaseTestCase
{
    protected function setUp(): void {} // MissingParentCall
}
```

### Type narrowing

`assertNotEmpty()` narrows its argument (`?Customer` becomes `Customer`).

```php
self::assertNotEmpty($customer);
$customer->name(); // no issue
```

## License

MIT
