Feature: Data provider return types

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Invalid generator data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return \Generator<int,int,mixed,void>
         * @psalm-pure
         */
        public static function provide() {
          yield 1;
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
      | Type              | Message                                                                                                       |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, Generator[pure]<int, int, mixed, void> provided |
    And I see no other errors

  Scenario: Valid generator data provider is allowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return \Generator<int,array<int,int>,mixed,void>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
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
    Then I see no errors

  Scenario: Invalid array data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return array<int,int>
         * @psalm-pure
         */
        public static function provide() {
          return [1 => 1];
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
      | Type              | Message                                                                                      |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, array<int, int> provided |
    And I see no other errors

  Scenario: Underspecified array data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return array
         * @psalm-pure
         */
        public static function provide() {
          return [1 => [1]];
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
      | Type                    | Message                                                                                                                 |
      | MixedReturnStatement | Providers must return iterable<array-key, array<array-key, mixed>>, possibly different array<array-key, mixed> provided |
    And I see no other errors

  Scenario: Underspecified iterable data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable
         * @psalm-pure
         */
        public static function provide() {
          return [1 => [1]];
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
      | Type                    | Message                                                                                                                |
      | MixedReturnStatement | Providers must return iterable<array-key, array<array-key, mixed>>, possibly different iterable<mixed, mixed> provided |
    And I see no other errors

  Scenario: Underspecified generator data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return \Generator
         * @psalm-pure
         */
        public static function provide() {
          yield 1 => [1];
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
      | Type                    | Message                                                                                                   |
      | MixedReturnStatement | Providers must return iterable<array-key, array<array-key, mixed>>, possibly different Generator[pure]<mixed, mixed, mixed, mixed> provided |
    And I see no other errors

  Scenario: Valid array data provider is allowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return array<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          return [
            "data set name" => [1],
          ];
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
    Then I see no errors

  Scenario: Valid object data provider is allowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return \ArrayObject<string,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          /** @var \ArrayObject<string,array<int,int>> */
          return new \ArrayObject([
            "data set name" => [1],
          ]);
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
    Then I see no errors

  Scenario: Providers returning list are ok
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, non-empty-list<int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
        /**
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers returning mismatching list are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, non-empty-list<string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => ["1"];
        }
        /**
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                              |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable[pure]<string, non-empty-list<string>>) |
    And I see no other errors

  Scenario: Providers returning nullable generator are ok
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return ?\Generator<array-key, array<array-key,int>>
         * @psalm-pure
         */
        public static function provide(): ?\Generator {
          return null;
        }
        /**
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers returning null are flagged
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return null
         * @psalm-pure
         */
        public static function provide() {
          return null;
        }
        /**
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                                                           |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, null provided |
    And I see no other errors

  Scenario: Invalid provider return type can be suppressed on the provider
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @psalm-pure
         * @psalm-suppress InvalidReturnType
         */
        public static function provideCents(): int {
          return 100;
        }

        #[DataProvider('provideCents')]
        public function testCents(int $cents): void {
          $this->assertSame(100, $cents);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An iterable provider without a key type has its datasets checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[DataProvider('provide')]
        public function testSomething(int $i): void {
          $this->assertSame(1, $i);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An iterable provider without a key type reports datasets that do not match the test
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield [1];
        }

        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects string, int provided by NS\MyTestCase::provide():(iterable[pure]<mixed, list{int}>) | 17 |
    And I see no other errors

  Scenario: A generator provider without a key type has its datasets checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase
      {
        /**
         * @return \Generator<array{int}>
         * @psalm-pure
         */
        public static function provide(): \Generator {
          yield [1];
        }

        #[DataProvider('provide')]
        public function testSomething(int $i): void {
          $this->assertSame(1, $i);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An IteratorAggregate provider without a key type has its datasets checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @implements \IteratorAggregate<array{int}>
       * @psalm-immutable
       */
      final class Datasets implements \IteratorAggregate {
        #[\Override]
        public function getIterator(): \Iterator {
          return new \ArrayIterator([[1]]);
        }
      }

      final class MyTestCase extends TestCase
      {
        /**
         * @return Datasets
         * @psalm-pure
         */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(int $i): void {
          $this->assertSame(1, $i);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An iterable provider with an object key type is still reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<object, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield new \stdClass => [1];
        }

        #[DataProvider('provide')]
        public function testSomething(int $i): void {
          $this->assertSame(1, $i);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message | Line |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, iterable[pure]<object, list{int}> provided | 10 |
    And I see no other errors

  Scenario: An iterable provider without a key type and with non-array values is still reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 1;
        }

        #[DataProvider('provide')]
        public function testSomething(int $i): void {
          $this->assertSame(1, $i);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message | Line |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, iterable[pure]<mixed, int> provided | 10 |
    And I see no other errors
