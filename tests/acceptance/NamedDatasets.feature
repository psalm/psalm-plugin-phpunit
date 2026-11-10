Feature: Named datasets

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: String-keyed datasets are matched to parameters by name
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{cents: int, currency: string}>
         * @psalm-pure
         */
        public static function prices(): iterable {
          return [['cents' => 100, 'currency' => 'EUR']];
        }

        /**
         * @return iterable<int, array{currency: string, cents: int}>
         * @psalm-pure
         */
        public static function reordered(): iterable {
          return [['currency' => 'EUR', 'cents' => 100]];
        }

        /**
         * @return iterable<int, array{b: int}>
         * @psalm-pure
         */
        public static function skippingDefault(): iterable {
          return [['b' => 3]];
        }

        /**
         * @return iterable<int, array{0: int, currency: string}>
         * @psalm-pure
         */
        public static function mixed(): iterable {
          return [[100, 'currency' => 'EUR']];
        }

        /**
         * @return iterable<int, array{a: int, x: string}>
         * @psalm-pure
         */
        public static function variadic(): iterable {
          return [['a' => 1, 'x' => 'foo']];
        }

        #[DataProvider('prices')]
        #[DataProvider('reordered')]
        #[DataProvider('mixed')]
        public function testPrice(int $cents, string $currency): void {
          $this->assertNotEmpty($currency . $cents);
        }

        #[DataProvider('skippingDefault')]
        public function testDefaults(string $a = 'x', int $b = 2): void {
          $this->assertNotEmpty($a . $b);
        }

        #[DataProvider('variadic')]
        public function testVariadic(int $a, string ...$rest): void {
          $this->assertNotEmpty($a . implode($rest));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed dataset entries are checked against the parameter they name
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{currency: int, cents: string}>
         * @psalm-pure
         */
        public static function swapped(): iterable {
          return [['currency' => 1, 'cents' => 'x']];
        }

        /**
         * @return iterable<int, array{a: int, x: bool}>
         * @psalm-pure
         */
        public static function variadic(): iterable {
          return [['a' => 1, 'x' => true]];
        }

        #[DataProvider('swapped')]
        public function testPrice(int $cents, string $currency): void {
          $this->assertNotEmpty($currency . $cents);
        }

        #[DataProvider('variadic')]
        public function testVariadic(int $a, string ...$rest): void {
          $this->assertNotEmpty($a . implode($rest));
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 2 ($currency) of NS\MyTestCase::testPrice expects string, int provided by NS\MyTestCase::swapped():(iterable<int, array{cents: string, currency: int}>) |
      | InvalidArgument | Argument 1 ($cents) of NS\MyTestCase::testPrice expects int, string provided by NS\MyTestCase::swapped():(iterable<int, array{cents: string, currency: int}>) |
      | InvalidArgument | Argument 2 ($x) of NS\MyTestCase::testVariadic expects string, bool provided by NS\MyTestCase::variadic():(iterable<int, array{a: int, x: bool}>) |
    And I see no other errors

  Scenario: Unknown, already used and missing named parameters are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{cents: int, nope: string}>
         * @psalm-pure
         */
        public static function unknown(): iterable {
          return [['cents' => 1, 'nope' => 'EUR']];
        }

        /**
         * @return iterable<int, array{0: int, cents: int}>
         * @psalm-pure
         */
        public static function overwriting(): iterable {
          return [[1, 'cents' => 2]];
        }

        /**
         * @return iterable<int, array{cents: int}>
         * @psalm-pure
         */
        public static function missing(): iterable {
          return [['cents' => 1]];
        }

        #[DataProvider('unknown')]
        #[DataProvider('overwriting')]
        #[DataProvider('missing')]
        public function testPrice(int $cents, string $currency): void {
          $this->assertNotEmpty($currency . $cents);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidNamedArgument | Parameter $nope does not exist on NS\MyTestCase::testPrice, provided by NS\MyTestCase::unknown():(iterable<int, array{cents: int, nope: string}>) |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testPrice - parameter $currency is not provided by NS\MyTestCase::unknown():(iterable<int, array{cents: int, nope: string}>) |
      | InvalidNamedArgument | Parameter $cents has already been used in NS\MyTestCase::testPrice, provided by NS\MyTestCase::overwriting():(iterable<int, array{0: int, cents: int}>) |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testPrice - parameter $currency is not provided by NS\MyTestCase::overwriting():(iterable<int, array{0: int, cents: int}>) |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testPrice - parameter $currency is not provided by NS\MyTestCase::missing():(iterable<int, array{cents: int}>) |
    And I see no other errors

  Scenario: Named dataset keys that cannot be checked precisely are not reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      trait HasPriceTest {
        #[DataProvider('prices')]
        public function testTraitPrice(int $cents, string $currency): void {
          $this->assertNotEmpty($currency . $cents);
        }
      }

      final class MyTestCase extends TestCase {
        use HasPriceTest;

        /**
         * @return iterable<int, array{cents: int, currency: string}>
         * @psalm-pure
         */
        public static function prices(): iterable {
          return [['cents' => 100, 'currency' => 'EUR']];
        }

        /**
         * @return iterable<int, array{a: int, ...<string, int>}>
         * @psalm-pure
         */
        public static function unsealed(): iterable {
          return [['a' => 1, 'b' => 2]];
        }

        /**
         * @return iterable<int, array<string, int>>
         * @psalm-pure
         */
        public static function generic(): iterable {
          return [['a' => 1, 'b' => 2]];
        }

        #[DataProvider('unsealed')]
        #[DataProvider('generic')]
        public function testUnsealed(int $a, int $b): void {
          $this->assertNotSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Docblock data providers with string keys are matched to parameters by name
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{currency: string, cents: int}>
         * @psalm-pure
         */
        public static function reordered(): iterable {
          return [['currency' => 'EUR', 'cents' => 100]];
        }

        /**
         * @dataProvider reordered
         */
        public function testDocblock(int $cents, string $currency): void {
          $this->assertNotEmpty($currency . $cents);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Possibly undefined named dataset keys are reported once
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{a?: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a): void {
          $this->assertNotEmpty($a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 ($a) of NS\MyTestCase::testSomething is not optional, but possibly undefined int provided by NS\MyTestCase::provide():(iterable<int, array{a?: int}>) |
    And I see no other errors

  Scenario: Possibly undefined positional entries do not fill parameters
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0?: int, a: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['a' => 1]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a = 0): void {
          $this->assertNotEmpty($a);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Optional named entries for parameters filled by a positional entry are not checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, a?: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[1]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a): void {
          $this->assertNotEmpty($a);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Int-keyed entries after a possibly undefined one are not bound to fixed parameters
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{tag: int, 0?: int, 1: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[1 => 2, 'tag' => 1]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a, int $b = 0, int $tag = 0): void {
          $this->assertNotEmpty($a . $b . $tag);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: The first possibly undefined positional entry is checked against its own parameter
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0?: int, tag: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['tag' => 1]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a, int $tag): void {
          $this->assertNotSame($a, $tag);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething is not optional, but possibly undefined int provided by NS\MyTestCase::provide():(iterable<int, array{0?: int, tag: int}>) |
    And I see no other errors

  Scenario: Optional positional entries that can only land in a variadic parameter are checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, 1?: bool, x: string}>
         * @psalm-pure
         */
        public static function optional(): iterable {
          return [[1, 'x' => 'foo']];
        }

        /**
         * @return iterable<int, array{0: int, 1?: string, 2: bool, x: string}>
         * @psalm-pure
         */
        public static function shifting(): iterable {
          return [[1, 'a', true, 'x' => 'foo']];
        }

        #[DataProvider('optional')]
        #[DataProvider('shifting')]
        public function testSomething(int $a, string ...$rest): void {
          $this->assertNotEmpty($a . implode($rest));
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects string, bool provided by NS\MyTestCase::optional():(iterable<int, array{0: int, 1?: bool, x: string}>) |
      | InvalidArgument | Argument 3 of NS\MyTestCase::testSomething expects string, bool provided by NS\MyTestCase::shifting():(iterable<int, array{0: int, 1?: string, 2: bool, x: string}>) |
    And I see no other errors

  Scenario: Unsealed datasets whose values cannot fill a missing parameter are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{a: int, ...<string, int>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['a' => 1, 'x' => 2]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a, array $b): void {
          $this->assertNotEmpty($a);
          $this->assertNotEmpty($b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - parameter $b is not provided by NS\MyTestCase::provide():(iterable<int, array{a: int, ...<string, int>}>) |
    And I see no other errors

  Scenario: Unsealed datasets whose extra keys cannot name a missing parameter are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{a: int, ...<'other', int>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['a' => 1, 'other' => 2]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a, int $b): void {
          $this->assertNotSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - parameter $b is not provided by NS\MyTestCase::provide():(iterable<int, array{a: int, ...<'other', int>}>) |
    And I see no other errors

  Scenario: A positional dataset entry after a named one is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [
            ['b' => 'x', 0 => 1],
            [0 => 2, 'b' => 'y'],
            ['b' => 'z', '0' => 3],
          ];
        }

        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function generated(): iterable {
          yield ['b' => 'x', 1];
          yield from [['b' => 'y', 2]];
        }

        #[DataProvider('provide')]
        #[DataProvider('generated')]
        public function testSomething(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }

        #[DataProvider('provide')]
        public function testSharingProvider(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message | Line |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by NS\MyTestCase::provide() | 14 |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by NS\MyTestCase::provide() | 16 |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by NS\MyTestCase::generated() | 25 |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by NS\MyTestCase::generated() | 26 |
    And I see no other errors

  Scenario: A positional dataset entry after a named one is reported for docblock providers
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['b' => 'x', 0 => 1]];
        }

        /**
         * @dataProvider provide
         */
        public function testSomething(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by NS\MyTestCase::provide() |
    And I see no other errors

  Scenario: A positional dataset entry after a named one is not reported when the test suppresses it
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['b' => 'x', 0 => 1]];
        }

        /**
         * @psalm-suppress InvalidNamedArgument
         */
        #[DataProvider('provide')]
        public function testSomething(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Datasets that the plugin cannot read in order are not reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        private const NAME = 'b';

        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function positionalFirst(): iterable {
          return [[0 => 1, 'b' => 'x'], [1, 'b' => 'y']];
        }

        /**
         * @return iterable<int, array{0: int, 1: string}>
         * @psalm-pure
         */
        public static function allPositional(): iterable {
          return [[1, 'x'], [0 => 2, 1 => 'y']];
        }

        /**
         * @return iterable<int, array{a: int, b: string}>
         * @psalm-pure
         */
        public static function allNamed(): iterable {
          yield ['a' => 1, 'b' => 'x'];
        }

        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function unknownKey(): iterable {
          return [[self::NAME => 'x', 0 => 1]];
        }

        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function unpacked(): iterable {
          $named = ['b' => 'x'];

          return [[...$named, 0 => 1]];
        }

        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function built(): iterable {
          $dataset = ['b' => 'x', 0 => 1];

          return [$dataset];
        }

        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function delegating(): iterable {
          return self::built();
        }

        /**
         * @return iterable<array-key, array{0: int, 1: string}>
         * @psalm-pure
         */
        public static function spreadReturn(): iterable {
          return [...['case' => [1, 'x'], [2, 'y']]];
        }

        /**
         * @return \Generator<array-key, array{0: int, 1: string}, mixed, mixed>
         * @psalm-pure
         */
        public static function spreadYield(): \Generator {
          yield from [...['case' => [1, 'x'], [2, 'y']]];
        }

        /**
         * @return iterable<int, array{0: int, 1: int}>
         * @psalm-pure
         */
        public static function numericKeys(): iterable {
          return [['1' => 2, 0 => 1]];
        }

        /**
         * @return \Generator<int, array{0: int, b: string}, mixed, mixed>
         * @psalm-pure
         */
        public static function generator(): \Generator {
          yield [0 => 1, 'b' => 'x'];

          return [['b' => 'x', 0 => 1]];
        }

        #[DataProvider('positionalFirst')]
        #[DataProvider('allPositional')]
        #[DataProvider('allNamed')]
        #[DataProvider('unknownKey')]
        #[DataProvider('unpacked')]
        #[DataProvider('built')]
        #[DataProvider('delegating')]
        #[DataProvider('generator')]
        #[DataProvider('spreadReturn')]
        #[DataProvider('spreadYield')]
        public function testSomething(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }

        #[DataProvider('numericKeys')]
        public function testNumericKeys(int $a, int $b): void {
          $this->assertNotSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Overwriting a positional dataset key after a named one is not reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, b: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [
            [0 => 1, 'b' => 'x', 0 => 2],
            [1, 'b' => 'x', '0' => 2],
            [1, 'b' => 'x', 0 => 2],
          ];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | DuplicateArrayKey    | Key '0' already exists on array |
      | DuplicateArrayKey    | Key '0' already exists on array |
      | DuplicateArrayKey    | Key '0' already exists on array |
    And I see no other errors

  Scenario: A new positional dataset key after an overwritten one is still reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{0: int, 1: int, b: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[0 => 1, 'b' => 'x', 0 => 2, 3]];
        }

        #[DataProvider('provide')]
        public function testSomething(int $a, int $c, string $b): void {
          $this->assertNotSame($a, $c);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | DuplicateArrayKey    | Key '0' already exists on array |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by NS\MyTestCase::provide() |
    And I see no other errors

  Scenario: Dependency values still count when a possibly undefined string key is the only key
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{x?: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[]];
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        public function testSecond(int $a, string $b): void {
          $this->assertNotEmpty($a . $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - parameter $b is not provided by NS\MyTestCase::provide():(iterable<int, array{x?: int}>) | 22 |
    And I see no other errors

  Scenario: String-keyed datasets are reported when #[Depends] passes a value
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset NS\MyTestCase::provide():(iterable<int, array{foo: string}>) |
    And I see no other errors

  Scenario: String-keyed datasets are reported when @depends passes a value
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        /**
         * @dataProvider provide
         * @depends testOne
         */
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset NS\MyTestCase::provide():(iterable<int, array{foo: string}>) |
    And I see no other errors

  Scenario: String-keyed datasets are reported when a value dependency is followed by a void one
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testValue(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        public function testVoid(): void {
          $this->assertTrue(true);
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testValue')]
        #[Depends('testVoid')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset NS\MyTestCase::provide():(iterable<int, array{foo: string}>) |
    And I see no other errors

  Scenario: String-keyed datasets are not reported when the only dependency is void
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): void {
          $this->assertTrue(true);
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        public function testSecond(string $foo): void {
          $this->assertSame('foo', $foo);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed datasets are not reported when a void dependency precedes a value dependency on PHPUnit 11
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testVoid(): void {
          $this->assertTrue(true);
        }

        public function testValue(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testVoid')]
        #[Depends('testValue')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed datasets are reported when a void dependency precedes a value dependency on PHPUnit 12.5.40
    Given PHPUnit identifies as version "12.5.40"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testVoid(): void {
          $this->assertTrue(true);
        }

        public function testValue(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testVoid')]
        #[Depends('testValue')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset NS\MyTestCase::provide():(iterable<int, array{foo: string}>) |
    And I see no other errors

  Scenario: String-keyed datasets are reported when a void dependency precedes a value dependency on PHPUnit 13.4.3
    Given PHPUnit identifies as version "13.4.3"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testVoid(): void {
          $this->assertTrue(true);
        }

        public function testValue(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testVoid')]
        #[Depends('testValue')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset NS\MyTestCase::provide():(iterable<int, array{foo: string}>) |
    And I see no other errors

  Scenario: String-keyed datasets are not reported when a void dependency precedes a value dependency on PHPUnit 12.5.39
    Given PHPUnit identifies as version "12.5.39"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testVoid(): void {
          $this->assertTrue(true);
        }

        public function testValue(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testVoid')]
        #[Depends('testValue')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed datasets are not reported when a void dependency precedes a value dependency on PHPUnit 13.4.2
    Given PHPUnit identifies as version "13.4.2"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testVoid(): void {
          $this->assertTrue(true);
        }

        public function testValue(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[Depends('testVoid')]
        #[Depends('testValue')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed datasets are reported when the dependency is in another class on PHPUnit 12.5.40
    Given PHPUnit identifies as version "12.5.40"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DependsExternal;

      final class OtherTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[DependsExternal(OtherTestCase::class, 'testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset NS\MyTestCase::provide():(iterable<int, array{foo: string}>) |
    And I see no other errors

  Scenario: String-keyed datasets are not reported when a docblock provider is ignored next to #[Depends]
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        /**
         * @dataProvider provide
         */
        #[Depends('testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed datasets are not reported when the dependency is in another class on PHPUnit 11
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DependsExternal;

      final class OtherTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }
      }

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        #[DataProvider('provide')]
        #[DependsExternal(OtherTestCase::class, 'testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: String-keyed datasets are not reported when the test has a size group
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array{foo: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo' => 'foo']];
        }

        /**
         * @dataProvider provide
         * @depends testOne
         * @group small
         */
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see no errors
