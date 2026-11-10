Feature: Data provider return types

  Background:
    Given PHPUnit identifies as version "11.5.0"
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" %s>
        <projectFiles>
          <directory name="."/>
          <ignoreFiles> <directory name="../../vendor"/> </ignoreFiles>
        </projectFiles>
        <plugins>
          <pluginClass class="Psalm\PhpUnitPlugin\Plugin"/>
        </plugins>
        <issueHandlers>
          <MissingClassConstType errorLevel="suppress" />
          <DeprecatedMethod errorLevel="suppress" />
        </issueHandlers>
      </psalm>
      """
    And I have the following code preamble
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      """

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

  @List
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

  @List
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
