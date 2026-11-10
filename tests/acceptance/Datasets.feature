Feature: Datasets

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Invalid dataset shape is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<string,array{string}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set name" => ["str"];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{string}>) |
    And I see no other errors

  Scenario: Invalid dataset array is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<string,array<int, string|int>>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set name" => ["str"];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                                                              |
      | PossiblyInvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, int\|string provided by NS\MyTestCase::provide():(iterable[pure]<string, array<int, int\|string>>) |
    And I see no other errors

  Scenario: Shape dataset with missing params is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set name" => [1];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int, int $i) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                                 |
      | TooFewArguments |Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: Provider returning optional offsets is fine when test method has defaults for those params (specified as constants)
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @var string */
        const S = "s";
        /** @return iterable<string,array{0:int,1?:string}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [1, "ss"];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int, string $_str = self::S) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider omitting offsets is fine when test method has defaults for those params (specified as constants)
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @var string */
        const S = "s";
        /** @return iterable<string,list{int,...}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [1, "ss"];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int, string $_str = self::S) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider returning possibly undefined offset is fine when test method has default for that param
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:int}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
       public function testSomething(int $int = 2) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider returning possibly undefined offset with mismatching type is reported even when test method has default for that param
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:string}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? ["1"] : [];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
       public function testSomething(int $int = 2) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                   |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable<string, array{0?: string}>) |
    And I see no other errors

  Scenario: Provider returning possibly undefined offset is marked when test method has no default for that param
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:int}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
       public function testSomething(int $int) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething is not optional, but possibly undefined int provided by NS\MyTestCase::provide():(iterable<string, array{0?: int}>) |
    And I see no other errors

  Scenario: Providers may omit variadic part for variadic tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1];
        }
        /**
         * @param int ...$rest
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $i, ...$rest) {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers may omit non-variadic params with default for variadic tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1];
        }
        /**
         * @param int ...$rest
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $i, string $s = "", ...$rest) {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers may not omit non-variadic params with no default for variadic tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1];
        }
        /**
         * @param int ...$rest
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $i, string $s, ...$rest) {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                                 |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: Providers generating incompatible datasets for variadic tests are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{0: float, 1?:string}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1., "a"];
        }
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(float ...$rest) {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                               |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects float, string provided by NS\MyTestCase::provide():(iterable[pure]<string, array{0: float, 1?: string}>) |
    And I see no other errors

  Scenario: Untyped providers returns are not checked against test method signatures
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @psalm-suppress MissingReturnType
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => ["a"];
        }
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(string $_s) {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Mismatched datasets can be suppressed on the test method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{string}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => ['100'];
        }

        /**
         * @psalm-suppress InvalidArgument
         */
        #[DataProvider('provideCents')]
        public function testCents(int $cents): void {
          $this->assertSame(100, $cents);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Mismatched datasets can be suppressed on the test class
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-suppress InvalidArgument
       */
      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{string}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => ['100'];
        }

        #[DataProvider('provideCents')]
        public function testCents(int $cents): void {
          $this->assertSame(100, $cents);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A suppression on one test does not hide the mismatched datasets of another
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{string}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => ['100'];
        }

        /**
         * @psalm-suppress InvalidArgument
         */
        #[DataProvider('provideCents')]
        public function testCents(int $cents): void {
          $this->assertSame(100, $cents);
        }

        #[DataProvider('provideCents')]
        public function testPositiveCents(int $cents): void {
          $this->assertGreaterThan(0, $cents);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testPositiveCents expects int, string provided by NS\MyTestCase::providecents():(iterable[pure]<string, list{string}>) | 24 |
    And I see no other errors

  Scenario: Mismatched datasets of a trait test can be suppressed on the trait method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      trait CentsTests {
        /**
         * @return iterable<string, array{string}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => ['100'];
        }

        /**
         * @psalm-suppress InvalidArgument
         */
        #[DataProvider('provideCents')]
        public function testCents(int $cents): void {
          $this->assertSame(100, $cents);
        }
      }

      final class MyTestCase extends TestCase {
        use CentsTests;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A suppression on the test class does not reach a trait test from another file
    Given I have the following code in "CentsTests.php"
      """
      <?php
      namespace NS;

      use PHPUnit\Framework\Attributes\DataProvider;

      trait CentsTests {
        /**
         * @return iterable<string, array{string}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => ['100'];
        }

        #[DataProvider('provideCents')]
        public function testCents(int $cents): void {
          $this->assertSame(100, $cents);
        }
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      /**
       * @psalm-suppress InvalidArgument
       */
      final class MyTestCase extends TestCase {
        use CentsTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message | Line |
      | InvalidArgument     | Argument 1 of NS\MyTestCase::testCents expects int, string provided by NS\CentsTests::providecents():(iterable[pure]<string, list{string}>) | 15 |
      | UnusedPsalmSuppress | This suppression is never used | 6 |
    And I see no other errors

  Scenario: Missing dataset values can be suppressed on the test method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{int}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => [100];
        }

        /**
         * @psalm-suppress TooFewArguments
         */
        #[DataProvider('provideCents')]
        public function testCents(int $cents, string $currency): void {
          $this->assertSame('100 EUR', $cents . ' ' . $currency);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A non-empty-list dataset can supply any number of parameters
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, non-empty-list<string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a', 'b'];
        }

        #[DataProvider('provide')]
        public function testSomething(string $a, string $b): void {
          $this->assertSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: The values of an open list dataset are checked against the parameters they can fill
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, non-empty-list<int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [1, 2];
        }

        #[DataProvider('provide')]
        public function testSomething(string $a, string $b): void {
          $this->assertSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects string, int provided by NS\MyTestCase::provide():(iterable[pure]<string, non-empty-list<int>>) |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects string, int provided by NS\MyTestCase::provide():(iterable[pure]<string, non-empty-list<int>>) |
    And I see no other errors

  Scenario: A possibly empty list dataset is reported for a required first parameter only
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list<string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a', 'b'];
        }

        #[DataProvider('provide')]
        public function testSomething(string $a, string $b): void {
          $this->assertSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething is not optional, but possibly undefined string provided by NS\MyTestCase::provide():(iterable[pure]<string, list<string>>) |
    And I see no other errors

  Scenario: The values of an open list dataset are checked against a variadic parameter
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, non-empty-list<string>>
         * @psalm-pure
         */
        public static function ok(): iterable {
          yield 'x' => ['a', 'b', 'c'];
        }

        /**
         * @return iterable<string, non-empty-list<int>>
         * @psalm-pure
         */
        public static function wrong(): iterable {
          yield 'x' => [1, 2, 3];
        }

        #[DataProvider('ok')]
        public function testOk(string $a, string ...$rest): void {
          $this->assertSame($a, $rest[0] ?? $a);
        }

        #[DataProvider('wrong')]
        public function testWrong(string $a, string ...$rest): void {
          $this->assertSame($a, $rest[0] ?? $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testWrong expects string, int provided by NS\MyTestCase::wrong():(iterable[pure]<string, non-empty-list<int>>) |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testWrong expects string, int provided by NS\MyTestCase::wrong():(iterable[pure]<string, non-empty-list<int>>) |
    And I see no other errors

  Scenario: The values of an open list dataset are checked against optional parameters
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, non-empty-list<string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a', 'b'];
        }

        #[DataProvider('provide')]
        public function testSomething(string $a, int $b = 1): void {
          $this->assertSame($a, (string) $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable[pure]<string, non-empty-list<string>>) |
    And I see no other errors

  Scenario: An open list dataset leaves the last parameters to the values of depended-upon tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): int {
          $this->assertTrue(true);
          return 1;
        }

        /**
         * @return iterable<string, non-empty-list<string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a', 'b'];
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        public function testSecond(string $a, string $b, int $one): void {
          $this->assertSame($a . $b, (string) $one);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An open list dataset leaves optional parameters after the dependency params unchecked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): int {
          $this->assertTrue(true);
          return 1;
        }

        /**
         * @return iterable<string, non-empty-list<string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a'];
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        public function testSecond(string $a, int $one, bool $unused = false): void {
          $this->assertSame($a, (string) $one);
          $this->assertFalse($unused);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A provider value that is a parent type of the parameter type is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a'];
        }

        /** @param non-empty-string $s */
        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertNotSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects non-empty-string, but parent type string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{string}>) |
    And I see no other errors

  Scenario: A nullable provider value that is a parent type of the nullable parameter type is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{null|string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [null];
        }

        /** @param ?non-empty-string $s */
        #[DataProvider('provide')]
        public function testSomething(?string $s): void {
          $this->assertNull($s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects non-empty-string\|null, but parent type null\|string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{null\|string}>) |
    And I see no other errors

  Scenario: A named dataset value that is a parent type of the parameter type is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{s: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['s' => 'a'];
        }

        /** @param non-empty-string $s */
        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertNotSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | ArgumentTypeCoercion | Argument 1 ($s) of NS\MyTestCase::testSomething expects non-empty-string, but parent type string provided by NS\MyTestCase::provide():(iterable[pure]<string, array{s: string}>) |
    And I see no other errors

  Scenario: A provider value that does not fit the parameter type at all stays an invalid argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [1];
        }

        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects string, int provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: A possibly false provider value is still reported when the rest is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<int, int>|false}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param list<int> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects list<int>, but parent type array<int, int>\|false provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|false}>) |
      | PossiblyFalseArgument | Argument 1 of NS\MyTestCase::testSomething cannot be false, possibly list<int> value expected by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|false}>) |
    And I see no other errors

  Scenario: A possibly null provider value is still reported when the rest is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<int, int>|null}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param list<int> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects list<int>, but parent type array<int, int>\|null provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|null}>) |
      | PossiblyNullArgument | Argument 1 of NS\MyTestCase::testSomething cannot be null, possibly null value provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|null}>) |
    And I see no other errors

  Scenario: A nullable list provider value is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<int, ?int>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param list<?int> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects list<int\|null>, but parent type array<int, int\|null> provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int\|null>}>) |
    And I see no other errors

  Scenario: A mixed array value is a mixed argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<string, mixed>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param array<string, string> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | MixedArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects array<string, string>, but parent type array<string, mixed> provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<string, mixed>}>) |
    And I see no other errors

  Scenario: A mixed dataset value is a mixed argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return array<array-key, array<array-key, mixed>>
         * @psalm-pure
         */
        public static function provide(): array {
          return [['a']];
        }

        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('a', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | MixedArgument | Argument 1 of NS\MyTestCase::testSomething cannot be mixed, expecting string provided by NS\MyTestCase::provide():(array<array-key, array<array-key, mixed>>) |
    And I see no other errors

  Scenario: A mixed dataset value is accepted by a mixed or untyped parameter
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return array<array-key, array<array-key, mixed>>
         * @psalm-pure
         */
        public static function provide(): array {
          return [['a', 'b']];
        }

        /** @psalm-suppress MissingParamType */
        #[DataProvider('provide')]
        public function testSomething(mixed $a, $b): void {
          $this->assertNotNull($a);
          $this->assertNotNull($b);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A mixed value of a string-keyed dataset is a mixed argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{s: mixed}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['s' => 'a'];
        }

        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('a', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | MixedArgument | Argument 1 ($s) of NS\MyTestCase::testSomething cannot be mixed, expecting string provided by NS\MyTestCase::provide():(iterable[pure]<string, array{s: mixed}>) |
    And I see no other errors

  Scenario: A mixed argument of the datasets can be suppressed on the test method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return array<array-key, array<array-key, mixed>>
         * @psalm-pure
         */
        public static function provide(): array {
          return [['a']];
        }

        /** @psalm-suppress MixedArgument */
        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('a', $s);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A possibly undefined mixed dataset value for a required parameter is an invalid argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{0: string, 1?: mixed}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a'];
        }

        #[DataProvider('provide')]
        public function testSomething(string $a, string $b): void {
          $this->assertNotSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething is not optional, but possibly undefined mixed provided by NS\MyTestCase::provide():(iterable[pure]<string, array{0: string, 1?: mixed}>) |
    And I see no other errors

  Scenario: A mixed value of a positional list dataset is a mixed argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{mixed}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a'];
        }

        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('a', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | MixedArgument | Argument 1 of NS\MyTestCase::testSomething cannot be mixed, expecting string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{mixed}>) |
    And I see no other errors

  Scenario: A mixed dataset value for a typed variadic parameter is a mixed argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{mixed}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a'];
        }

        #[DataProvider('provide')]
        public function testSomething(string ...$s): void {
          $this->assertNotEmpty($s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | MixedArgument | Argument 1 of NS\MyTestCase::testSomething cannot be mixed, expecting string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{mixed}>) |
    And I see no other errors

  Scenario: An argument type coercion of the datasets can be suppressed on the test method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['x'];
        }

        /**
         * @psalm-suppress ArgumentTypeCoercion
         * @param non-empty-string $s
         */
        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertNotEmpty($s);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An imported type alias in a test parameter is expanded in the provider check
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array<string, string>}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('provide')]
        public function testAlias(array $options): void {
          $this->assertSame('x', $options['host']);
        }

        /**
         * @param array{host: string} $options
         */
        #[DataProvider('provide')]
        public function testShape(array $options): void {
          $this->assertSame('x', $options['host']);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message | Line |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testAlias expects array{host: string}, but parent type array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>}>) | 23 |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testShape expects array{host: string}, but parent type array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>}>) | 31 |
    And I see no other errors

  Scenario: An imported type alias in a test parameter accepts a matching dataset
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array{host: string}}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('provide')]
        public function testSomething(array $options): void {
          $this->assertSame('x', $options['host']);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An imported type alias in a test parameter is expanded for named and unknown length datasets
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{options: array<string, string>}>
         * @psalm-pure
         */
        public static function named(): array {
          return [['options' => ['host' => 'x']]];
        }

        /**
         * @return list<array<int, array<string, string>>>
         * @psalm-pure
         */
        public static function lengthless(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('named')]
        public function testNamed(array $options): void {
          $this->assertSame('x', $options['host']);
        }

        /**
         * @param Options $options
         */
        #[DataProvider('lengthless')]
        public function testLengthless(array $options): void {
          $this->assertSame('x', $options['host']);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message | Line |
      | ArgumentTypeCoercion | Argument 1 ($options) of NS\MyTestCase::testNamed expects array{host: string}, but parent type array<string, string> provided by NS\MyTestCase::named():(list<array{options: array<string, string>}>) | 31 |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testLengthless expects array{host: string}, but parent type array<string, string> provided by NS\MyTestCase::lengthless():(list<array<int, array<string, string>>>) | 39 |
    And I see no other errors

  Scenario: A test parameter typed with an imported type alias is narrowed to the dataset type
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array{host: 'x'}}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('provide')]
        public function testSomething(array $options): void {
          /** @psalm-check-type-exact $options = array{host: 'x'} */
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A variadic parameter typed with an imported type alias is expanded in the provider check
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array<string, string>, array<string, string>}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x'], ['host' => 'y']]];
        }

        /**
         * @param Options ...$options
         */
        #[DataProvider('provide')]
        public function testSomething(array ...$options): void {
          $this->assertNotEmpty($options);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects array{host: string}, but parent type array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>, array<string, string>}>) |
      | ArgumentTypeCoercion | Argument 2 of NS\MyTestCase::testSomething expects array{host: string}, but parent type array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>, array<string, string>}>) |
    And I see no other errors

  Scenario: self in a trait test and its provider means the class using the trait
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      trait ProvidesSelf {
        /**
         * @return list<array{class-string<self>}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[self::class]];
        }

        /**
         * @param class-string<self> $class
         */
        #[DataProvider('provide')]
        public function testSomething(string $class): void {
          $this->assertSame(self::class, $class);
        }
      }

      final class MyTestCase extends TestCase {
        use ProvidesSelf;
      }
      """
    When I run Psalm
    Then I see no errors
