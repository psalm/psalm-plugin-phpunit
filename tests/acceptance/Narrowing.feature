Feature: Test parameter narrowing

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Test parameters are narrowed to the types of their data provider
    Given I have the following code
      """
      final class SomeTest extends TestCase {
        /**
         * @return array<string, array{data: array<string, string>}>
         * @psalm-pure
         */
        public static function getData(): array {
          return ['some data' => ['data' => ['foo' => 'bar', 'bar' => 'foo']]];
        }

        /**
         * @dataProvider getData
         */
        public function testSomething(array $data): void {
          /** @psalm-check-type-exact $data = array<string, string> */
          foreach ($data as $key => $value) {
            $this->assertNotEmpty($key . $value);
          }
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed to the types of a #[DataProvider] list shape
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{int, non-empty-string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'dataset' => [1, 'a'];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $count, mixed $name): void {
          /**
           * @psalm-check-type-exact $count = int
           * @psalm-check-type-exact $name = non-empty-string
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed to the types of an external provider
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'dataset' => ['a'];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         */
        public function testSomething(mixed $name): void {
          /** @psalm-check-type-exact $name = string */
          $this->assertTrue(true);
        }

        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testAttribute(mixed $name): void {
          /** @psalm-check-type-exact $name = string */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed to the union of the types of several providers
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function ints(): iterable {
          yield [1];
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function strings(): iterable {
          yield ['a'];
        }

        #[Attributes\DataProvider('ints')]
        #[Attributes\DataProvider('strings')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = int|string */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed by the names of a string-keyed dataset
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{label: string, cents: int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'dataset' => ['label' => 'a', 'cents' => 100];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $cents, mixed $label): void {
          /**
           * @psalm-check-type-exact $cents = int
           * @psalm-check-type-exact $label = string
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Parameters that receive the return value of a depended-upon test are not narrowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array<int, int>>
         * @psalm-pure
         */
        public static function array(): iterable {
          yield [1];
        }

        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function shape(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('array')]
        #[Attributes\Depends('testOne')]
        public function testFromArray(mixed $value, mixed $dependency): void {
          /**
           * @psalm-check-type-exact $value = mixed
           * @psalm-check-type-exact $dependency = mixed
           */
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('shape')]
        #[Attributes\Depends('testOne')]
        public function testFromShape(mixed $value, mixed $dependency): void {
          /**
           * @psalm-check-type-exact $value = int
           * @psalm-check-type-exact $dependency = mixed
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Parameters that a dataset may not provide are not narrowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{label: string, cents?: int}>
         * @psalm-pure
         */
        public static function optionalKey(): iterable {
          yield ['label' => 'a'];
        }

        /**
         * @return iterable<int, array{int, string}>
         * @psalm-pure
         */
        public static function full(): iterable {
          yield [1, 'a'];
        }

        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function short(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('optionalKey')]
        public function testOptionalKey(mixed $label, mixed $cents = null): void {
          /**
           * @psalm-check-type-exact $label = string
           * @psalm-check-type-exact $cents = mixed
           */
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('full')]
        #[Attributes\DataProvider('short')]
        public function testOmittedByOneProvider(mixed $number, mixed $name = null): void {
          /**
           * @psalm-check-type-exact $number = int
           * @psalm-check-type-exact $name = mixed
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Variadic parameters are not narrowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int, string, string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1, 'a', 'b'];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $number, mixed ...$names): void {
          /**
           * @psalm-check-type-exact $number = int
           * @psalm-check-type-exact $names = array<array-key, mixed>
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Ints provided to a float parameter are not narrowed to int
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int, int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1, 2];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(float $float, int|float $either): void {
          /**
           * @psalm-check-type-exact $float = float
           * @psalm-check-type-exact $either = int
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Docblock providers are ignored when the test has a PHPUnit attribute
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        /**
         * @dataProvider provide
         */
        #[Attributes\Test]
        public function something(mixed $number): void {
          /** @psalm-check-type-exact $number = mixed */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed per class that uses a test trait
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      trait MyTestTrait {
        /**
         * @return iterable<int, array{int|string}>
         * @psalm-pure
         */
        abstract public static function provide(): iterable;

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-trace $value */
          $this->assertTrue(true);
        }
      }

      final class IntTestCase extends TestCase {
        use MyTestTrait;

        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        #[\Override]
        public static function provide(): iterable {
          yield [1];
        }
      }

      final class StringTestCase extends TestCase {
        use MyTestTrait;

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        #[\Override]
        public static function provide(): iterable {
          yield ['a'];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type  | Message    |
      | Trace | $value: int    |
      | Trace | $value: string |
    And I see no other errors

  Scenario: Test parameters are narrowed to the provider type of the class that declares the test
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int, array{int|string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-trace $value */
          $this->assertTrue(true);
        }
      }

      final class ChildTestCase extends BaseTestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        #[\Override]
        public static function provide(): iterable {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type  | Message           |
      | Trace | $value: int\|string |
    And I see no other errors

  Scenario: Calling a test method directly is not checked against the provider types
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{data: array<string, string>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'dataset' => ['data' => ['a' => 'b']];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(array $data): void {
          /** @psalm-check-type-exact $data = array<string, string> */
          $this->assertTrue(true);
        }

        public function testCaller(): void {
          $this->testSomething(['a' => 1]);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Narrowed test parameters are still reported as unused
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int, int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1, 2];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $number, mixed $unused): void {
          /** @psalm-check-type-exact $unused = int */
          $this->assertSame(1, $number);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type        | Message                                     |
      | UnusedParam | Param #2 is never referenced in this method |
    And I see no other errors

  Scenario: Test parameters are not narrowed when a provider cannot be read
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        private const STRINGS = 'strings';

        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function ints(): iterable {
          yield [1];
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function strings(): iterable {
          yield ['a'];
        }

        #[Attributes\DataProvider('ints')]
        #[Attributes\DataProvider(self::STRINGS)]
        public function testConstantProvider(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('ints')]
        #[Attributes\DataProviderExternal(MyTestCase::class, self::STRINGS)]
        public function testExternalProvider(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are not narrowed when a provider does not prove them
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function positional(): iterable {
          yield [1];
        }

        /**
         * @return iterable<int, array{5: string}>
         * @psalm-pure
         */
        public static function renumbered(): iterable {
          yield [5 => 'a'];
        }

        #[Attributes\DataProvider('positional')]
        #[Attributes\DataProvider('renumbered')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are not narrowed to values that depended-upon tests may replace
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @return iterable<int, array<int, int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [];
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSomething(mixed $value, mixed $dependency): void {
          /**
           * @psalm-check-type-exact $value = mixed
           * @psalm-check-type-exact $dependency = mixed
           */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are not narrowed outside of test cases
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class NotATestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          echo 1;
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are not narrowed in methods that PHPUnit does not run
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function helper(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('provide')]
        protected function testProtected(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed by the name a trait method is imported with
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      trait MyTestTrait {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function something(mixed $value): void {
          /** @psalm-trace $value */
          $this->assertTrue(true);
        }
      }

      final class AliasedTestCase extends TestCase {
        use MyTestTrait { something as testSomething; }
      }

      final class PlainTestCase extends TestCase {
        use MyTestTrait;
      }

      trait AliasingTrait {
        use MyTestTrait { something as testSomething; }
      }

      final class NestedAliasTestCase extends TestCase {
        use AliasingTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type  | Message         |
      | Trace | $value: int     |
      | Trace | $value: int     |
      | Trace | $value: mixed   |
    And I see no other errors

  Scenario: Test parameters are not narrowed when a PHPUnit attribute makes PHPUnit ignore the @test docblock
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        /**
         * @test
         */
        #[Attributes\DataProvider('provide')]
        public function ignoredDocblock(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }

        /**
         * @test
         * @dataProvider provide
         */
        public function docblockOnly(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters follow the visibility a trait method is imported with
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      trait MyTestTrait {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        protected function something(mixed $value): void {
          /** @psalm-trace $value */
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('provide')]
        public function testHidden(mixed $other): void {
          /** @psalm-trace $other */
          $this->assertTrue(true);
        }
      }

      final class MyTestCase extends TestCase {
        use MyTestTrait {
          something as public testSomething;
          testHidden as private;
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type  | Message        |
      | Trace | $value: int    |
      | Trace | $other: mixed  |
    And I see no other errors

  Scenario: Test parameters are not narrowed in methods whose name only resembles test in another case
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function TestHelper(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test parameters are narrowed to the class that uses a trait provider
    Given I have the following code
      """
      /** @psalm-immutable */
      trait ProviderTrait {
        /**
         * @return iterable<int, array{self}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [new self()];
        }
      }

      /** @psalm-immutable */
      final class Payload {
        use ProviderTrait;
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider Payload::provide
         */
        public function testSomething(mixed $payload): void {
          /** @psalm-check-type-exact $payload = Payload */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors
