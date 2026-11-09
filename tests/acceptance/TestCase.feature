Feature: TestCase
  In order to have typed TestCases
  As a Psalm user
  I need Psalm to typecheck my test cases

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

  Scenario: Stateful test case with setUp produces no MissingConstructor
    Given I have the following code
      """
      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      final class MyTestCase extends TestCase
      {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        private $i;

        /** @return void */
        #[\Override]
        public function setUp(): void {
          $this->i = $this->createStub(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Stateful test case with @before produces no MissingConstructor
    Given I have the following code
      """
      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      final class MyTestCase extends TestCase
      {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        private $i;

        /** @before */
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Descendant of a test that has #[Before] produces no MissingConstructor
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      class BaseTestCase extends TestCase {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        protected $i;

        #[Attributes\Before]
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }
      }

      class Intermediate extends BaseTestCase {}

      final class MyTestCase extends Intermediate
      {
        /** @return void */
        public function testSomething() {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Stateful test case without @before or setUp produces MissingConstructor
    Given I have the following code
      """
      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      final class MyTestCase extends TestCase
      {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        private $i;

        /** @return void */
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type               | Message                                                                                                        |
      | MissingConstructor | NS\MyTestCase has an uninitialized property NS\MyTestCase::$i, but no constructor |
    And I see no other errors

  Scenario: Missing data provider is reported
    Given I have the following code
    """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @param mixed $int
         * @return void
         * @psalm-suppress UnusedMethod
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething($int) {
          $this->assertEquals(1, $int);
        }
      }
    """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               |
      | UndefinedMethod | Provider method NS\MyTestCase::provide is not defined |
    And I see no other errors

  Scenario: Missing @dataProvider is reported on the line of the tag
    Given I have the following code
    """
      final class MyTestCase extends TestCase
      {
        /**
         * @param mixed $int
         * @return void
         * @dataProvider provide
         */
        public function testSomething($int) {
          $this->assertEquals(1, $int);
        }
      }
    """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               | Line |
      | UndefinedMethod | Provider method NS\MyTestCase::provide is not defined | 10   |
    And I see no other errors

  Scenario: Missing #[DataProvider] is reported on the line of its own attribute
    Given I have the following code
    """
      final class MyTestCase extends TestCase
      {
        #[\PHPUnit\Framework\Attributes\DataProvider('first')]
        #[\PHPUnit\Framework\Attributes\DataProvider('second')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
    """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                            | Line |
      | UndefinedMethod | Provider method NS\MyTestCase::first is not defined  | 7    |
      | UndefinedMethod | Provider method NS\MyTestCase::second is not defined | 8    |
    And I see no other errors

  Scenario: Invalid iterable data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,int>
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
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                                                                         |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, iterable[pure]<int, int> provided |
    And I see no other errors

  Scenario: Valid iterable data provider is allowed
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
        }

        /**
         * @dataProvider provide
         */
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Valid iterable #[DataProvider] is allowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Non-static @dataProvider is reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }

        /**
         * @dataProvider provide
         */
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: Non-static #[DataProvider] is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: Non-public @dataProvider is reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        protected static function provide() {
          yield [1];
        }

        /**
         * @dataProvider provide
         */
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be public |
    And I see no other errors

  Scenario: Non-public #[DataProvider] is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        private static function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be public |
    And I see no other errors

  Scenario: Non-public non-static data provider is reported for both
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        protected function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be public |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  @ExternalProviders
  Scenario: Non-static external data provider is reported
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         */
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                   |
      | InvalidDataProvider | Data provider method NS\External::provide must be static |
    And I see no other errors

  @ExternalProviders
  Scenario: Non-public external data provider is reported
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        protected static function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         */
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                   |
      | InvalidDataProvider | Data provider method NS\External::provide must be public |
    And I see no other errors

  Scenario: Data provider made public by a trait adaptation is allowed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-pure */
      trait Provides {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        protected static function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase {
        use Provides {
          provide as public;
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Data provider made non-public by a trait adaptation is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-pure */
      trait Provides {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase {
        use Provides {
          provide as protected;
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be public |
    And I see no other errors

  Scenario: Abstract data provider is checked in the implementing class
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract protected static function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public static function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid data provider can be suppressed on the test method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }

        /**
         * @psalm-suppress InvalidDataProvider
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid data provider can be suppressed on the test class
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /**
       * @psalm-suppress InvalidDataProvider
       */
      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid data provider of a trait test can be suppressed on the trait method
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" findUnusedPsalmSuppress="true">
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
    And I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-immutable */
      trait MyTestTrait {
        /**
         * @return void
         * @psalm-suppress InvalidDataProvider
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $_i) {}
      }

      final class MyTestCase extends TestCase {
        use MyTestTrait;

        /**
         * @return iterable<int,array{int}>
         * @psalm-pure
         */
        public function provide() { return [[1]]; }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Docblock data provider is ignored when the test has a #[DataProvider] attribute
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
        }

        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function legacy() {
          yield [1];
        }

        /**
         * @dataProvider legacy
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Docblock data provider is ignored when the test has another PHPUnit attribute
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function legacy() {
          yield [1];
        }

        /**
         * @dataProvider legacy
         */
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Multiple valid iterable @dataProvider are allowed, and all are used
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provider1() {
          yield [1];
        }

        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provider2() {
          yield [1];
        }

        /**
         * @dataProvider provider1
         * @dataProvider provider2
         */
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Multiple valid iterable #[DataProvider]s are allowed, and all are used
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provider1() {
          yield [1];
        }

        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provider2() {
          yield [1];
        }

        #[Attributes\DataProvider('provider1')]
        #[Attributes\DataProvider('provider2')]
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                                 |
      | TooFewArguments |Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: @depends values are not required from the @dataProvider
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @dataProvider provide
         * @depends testOne
         */
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: #[Depends] values are not required from the #[DataProvider]
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;
      use PHPUnit\Framework\Attributes\DependsExternalUsingDeepClone;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        public function testTwo(): int {
          $this->assertTrue(true);
          return 1;
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        #[DependsExternalUsingDeepClone(MyTestCase::class, 'testTwo')]
        public function testSecond(string $foo, string $bar, int $baz): void {
          $this->assertSame($foo, $bar . $baz);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: @depends values are not checked against dataset values of an array provider
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): int {
          $this->assertTrue(true);
          return 1;
        }

        /**
         * @dataProvider provide
         * @depends clone testOne
         */
        public function testSecond(string $foo, int $bar): void {
          $this->assertSame($foo, (string) $bar);
        }

        /**
         * @return iterable<int, array<int, string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Missing provider arguments are still reported when the test has a dependency
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, string $baz, string $bar): void {
          $this->assertSame($foo, $bar . $baz);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Dependencies on void tests pass no value and are still required from the provider
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): void {
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Duplicate dependencies pass a single value
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        #[Depends('testOne')]
        public function testSecond(string $foo, string $baz, string $bar): void {
          $this->assertSame($foo, $bar . $baz);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Named DependsExternal arguments are resolved by name
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DependsExternal;

      final class MyTestCase extends TestCase {
        public function testOne(): void {
          $this->assertTrue(true);
        }

        #[DataProvider('provide')]
        #[DependsExternal(methodName: 'testOne', className: MyTestCase::class)]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Values supplied by the provider for dependency params are still checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): int {
          $this->assertTrue(true);
          return 1;
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, int $bar): void {
          $this->assertSame($foo, (string) $bar);
        }

        /**
         * @return iterable<int, array{string, string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo', 'bad']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                       |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSecond expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string, string}>) |
    And I see no other errors

  Scenario: Dependencies differing only by a negated clone modifier pass a single value
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @dataProvider provide
         * @depends testOne
         * @depends !clone testOne
         * @depends !shallowClone testOne
         */
        public function testSecond(string $foo, string $baz, string $bar): void {
          $this->assertSame($foo, $bar . $baz);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: DependsExternal on the class sentinel passes no value
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DependsExternal;

      final class MyTestCase extends TestCase {
        #[DataProvider('provide')]
        #[DependsExternal(MyTestCase::class, 'class')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Optional dataset offsets are not guaranteed to cover dependency params
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, string $baz, string $bar): void {
          $this->assertSame($foo, $bar . $baz);
        }

        /**
         * @return iterable<int, array{0?: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[]];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSecond is not optional, but possibly undefined string provided by NS\MyTestCase::provide():(iterable<int, array{0?: string}>) |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 1, but saw 0 provided by NS\MyTestCase::provide():(iterable<int, array{0?: string}>) |
    And I see no other errors

  Scenario: @depends is ignored when the test has PHPUnit attributes
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @depends testOne
         */
        #[DataProvider('provide')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                  |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Variadic params are still checked against provider values when the test has a dependency
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @param int ...$values
         */
        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(int ...$values): void {
          $this->assertNotEmpty($values);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['bad']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSecond expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors

  Scenario: Referenced providers are not marked as unused
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
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unreferenced providers are marked as unused
    Given I have the following code
      """
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
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::provide |
    And I see no other errors

  Scenario: Test method are never marked as unused
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        public function testSomething(int $int): void {
          $this->assertEquals(1, $int);
        }

        /**
         * @test
         */
        public function somethingElse(int $int): void {
          $this->assertEquals(1, $int);
        }

        #[Attributes\Test]
        public function somethingElseWithAttribute(int $int): void {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unreferenced non-test methods are marked as unused
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @return void
         */
        public function somethingElse(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                      |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::somethingElse |
    And I see no other errors

  Scenario: Unreferenced TestCase descendants are never marked as unused
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unreferenced non-test classes are marked as unused
    Given I have the following code
      """
      /** @psalm-pure */
      final class UtilityClass
      {
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type        | Message                             |
      | UnusedClass | Class NS\UtilityClass is never used |
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
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
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething is not optional, but possibly undefined int provided by NS\MyTestCase::provide():(iterable<string, array{0?: int}>) |
    And I see no other errors

  Scenario: Stateful grandchild test case with setUp produces no MissingConstructor
    Given I have the following code
      """
      class BaseTestCase extends TestCase {}

      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      final class MyTestCase extends BaseTestCase
      {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        private $i;

        /** @return void */
        #[\Override]
        public function setUp(): void {
          $this->i = $this->createStub(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Descendant of a test that has setUp produces no MissingConstructor
    Given I have the following code
      """
      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      class BaseTestCase extends TestCase {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        protected $i;

        /** @return void */
        #[\Override]
        public function setUp(): void {
          $this->i = $this->createStub(I::class);
        }
      }

      class Intermediate extends BaseTestCase {}

      final class MyTestCase extends Intermediate
      {
        /** @return void */
        public function testSomething() {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Descendant of a test that has @before produces no MissingConstructor
    Given I have the following code
      """
      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      class BaseTestCase extends TestCase {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        protected $i;

        /** @before */
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }
      }

      class Intermediate extends BaseTestCase {}

      final class MyTestCase extends Intermediate
      {
        public function testSomething(): void {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Descendant of a test that has #[Before] produces no MissingConstructor
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      class BaseTestCase extends TestCase {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        protected $i;

        #[Attributes\Before]
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }
      }

      class Intermediate extends BaseTestCase {}

      final class MyTestCase extends Intermediate
      {
        public function testSomething(): void {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Test methods in traits are not marked as unused
    Given I have the following code
      """
      /** @psalm-immutable */
      trait MyTestTrait {
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        public function testSomething() {}
      }
      final class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Test methods marked with #[Test] in a trait are not marked as unused when the consuming class does not import the Test attribute
    Given I have the following code in "MyTestTrait.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\Attributes\Test;
      /** @psalm-immutable */
      trait MyTestTrait {
        /** @psalm-capabilities read-props */
        #[Test]
        public function itDoesSomething(): void {}
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      final class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Test methods marked with a partially-imported #[Attributes\Test] in a trait are not marked as unused when the consuming class does not import the namespace
    Given I have the following code in "MyTestTrait.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\Attributes;
      /** @psalm-immutable */
      trait MyTestTrait {
        /** @psalm-capabilities read-props */
        #[Attributes\Test]
        public function itDoesSomething(): void {}
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      final class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Test methods marked with an aliased #[Test] attribute in a trait are not marked as unused when the consuming class does not import the alias
    Given I have the following code in "MyTestTrait.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\Attributes\Test as PHPUnitTest;
      /** @psalm-immutable */
      trait MyTestTrait {
        /** @psalm-capabilities read-props */
        #[PHPUnitTest]
        public function itDoesSomething(): void {}
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      final class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Test methods marked with a fully-qualified #[Test] attribute are not marked as unused
    Given I have the following code in "BaseTestCase.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      abstract class BaseTestCase extends TestCase {}
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\PHPUnit\Framework\Attributes\Test]
        public function itDoesSomething(): void {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Inherited test methods are not marked as unused
    Given I have the following code
      """
      abstract class IntermediateTest extends TestCase {
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        public function testSomething() {}
      }
      final class MyTestCase extends IntermediateTest {
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Data providers in traits are not marked as unused
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-pure */
      trait MyTestTrait {
        /**
         * @return iterable<int,array{int}>
         * @psalm-pure
         */
        public static function provide() { return [[1]]; }
      }
      final class MyTestCase extends TestCase {
        use MyTestTrait;
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $_i) {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Data providers in test case when test methods are in trait are not marked as unused
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-immutable */
      trait MyTestTrait {
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $_i) {}
      }
      final class MyTestCase extends TestCase {
        use MyTestTrait;
        /**
         * @return iterable<int,array{int}>
         * @psalm-pure
         */
        public static function provide() { return [[1]]; }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Renamed imported test methods are validated
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-immutable */
      trait MyTestTrait {
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function foo(int $_i) {}
      }
      final class MyTestCase extends TestCase {
        use MyTestTrait { foo as testAnything; }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               |
      | UndefinedMethod | Provider method NS\MyTestCase::provide is not defined |
    And I see no other errors

  Scenario: Test methods and providers in trait used by a test case are validated
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-immutable */
      trait MyTestTrait {
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(string $_p) {}
        /**
         * @return iterable<int,int[]>
         * @psalm-pure
         */
        public static function provide() { return [[1]]; }
      }

      final class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                     |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects string, int provided by NS\MyTestTrait::provide():(iterable<int, array<array-key, int>>) |
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

  Scenario: Invalid psalm annotation on a class does not crash psalm
    Given I have the following code
      """
      /** @psalm-ignore Everything */
      final class MyTestCase extends TestCase {}
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message         |
      | InvalidDocblock | Unrecognised annotation @psalm-ignore |
      | InvalidDocblock | Unrecognised annotation @psalm-ignore in docblock for NS\\MyTestCase |

  Scenario: Invalid psalm annotation on an before initializer does not crash psalm
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @before
         * @psalm-rm-Rf-slash
         * @return void
         * @psalm-capabilities read-props
         */
        public function preparation() {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message              |
      | InvalidDocblock | Unrecognised annotation @psalm-rm-Rf-slash |

  Scenario: Invalid psalm annotation on a test does not crash psalm
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         * @psalm-force-push-master
         * @return void
         * @psalm-capabilities read-props
         */
        public function doThings() {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                    |
      | InvalidDocblock | Unrecognised annotation @psalm-force-push-master |

  Scenario: Missing param type on a test with tuple data provider does not crash psalm
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @psalm-suppress MissingParamType
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething($data): void {}

        /**
         * @return iterable<string, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return ['case 1' => [1]];
        }
      }
      """
    When I run Psalm
    Then I see exit code 0
    And I see no errors

  Scenario: Providers referenced in shorthand docblocks are not marked as unused
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
        /**
         * @dataProvider provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors


  @ExternalProviders
  Scenario: External providers are allowed
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  @ExternalProviders
  Scenario: External providers with parens are allowed
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide()
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  @ExternalProviders
  Scenario: External fully qualified providers are allowed
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider \NS\External::provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  @ExternalProviders
  Scenario: External providers are not marked as unused
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  @ExternalProviders
  Scenario: Mismatched external providers are reported
    Given I have the following code
      """
      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array<int,string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => ["1"];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                  |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\External::provide():(iterable[pure]<string, array<int, string>>) |

  @ExternalProviders
  Scenario: External providers are available even when Psalm is asked to analyze single test case
    Given I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    And I have the following code in "ext.php"
      """
      <?php
      namespace NS;

      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<string, array<int,int>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield "dataset name" => [1];
        }
      }
      """
    And I have the following code in "autoload.php"
      """
      <?php
      spl_autoload_register(function(string $class) {
          /** @var ?array<string,string> $classes */
          static $classes = null;

          if (null === $classes) {
              $classes = [
                  'NS\\MyTestCase' => 'test.php',
                  'NS\\External'   => 'ext.php',
              ];
          }

          if (array_key_exists($class, $classes)) {
              /** @psalm-suppress UnresolvableInclude */
              include $classes[$class];
          }
      });
      """
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" autoloader="autoload.php">
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
    When I run Psalm on "test.php"
    Then I see no errors

  @ExternalProviders
  Scenario: Missing external provider classes are reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @dataProvider External::provide
         * @psalm-capabilities read-props
         */
        public function testSomething(int $_p): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type           | Message                          |
      | UndefinedClass | Class NS\External does not exist |

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
      | Type            | Message                                                                                                                              |
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

  Scenario: Unused calls after expectException are not reported
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Value {
        /** @psalm-pure */
        public function get(): int { return 1; }
      }

      final class MyTestCase extends TestCase {
        public function testAfter(): void {
          $this->expectException(\JsonException::class);
          json_decode('', flags: JSON_THROW_ON_ERROR);
          (new Value())->get();
        }

        public function testAfterStaticCall(): void {
          self::expectExceptionMessage('Syntax error');
          json_decode('', flags: JSON_THROW_ON_ERROR);
        }

        public function testReturnValueIsUsed(): void {
          $this->assertSame(1, (new Value())->get());
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unused calls before expectException and in other tests are still reported
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Value {
        /** @psalm-pure */
        public function get(): int { return 1; }
      }

      /** @psalm-immutable */
      final class Other {
        /** @psalm-pure */
        public function get(): int { return 1; }
      }

      final class MyTestCase extends TestCase {
        public function testBefore(): void {
          json_decode('', flags: JSON_THROW_ON_ERROR);
          (new Value())->get();
          $this->expectException(\JsonException::class);
        }

        /** @psalm-capabilities read-props */
        public function testWithoutExpectation(): void {
          json_encode(1);
          (new Other())->get();
        }

        public function testReturnValueIsUsed(): void {
          $this->assertSame(1, (new Value())->get() + (new Other())->get());
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type               | Message                                 |
      | UnusedFunctionCall | The call to json_decode is not used     |
      | UnusedMethodCall   | The call to NS\Value::get is not used   |
      | UnusedFunctionCall | The call to json_encode is not used     |
      | UnusedMethodCall   | The call to NS\Other::get is not used   |
    And I see no other errors

  Scenario: MissingThrowsDocblock is not reported after expectException
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" checkForThrowsDocblock="true">
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
          <MissingPureAnnotation errorLevel="suppress" />
          <InternalMethod errorLevel="suppress" />
        </issueHandlers>
      </psalm>
      """
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testThrows(): void {
          $this->expectException(\InvalidArgumentException::class);
          throw new \InvalidArgumentException('boom');
        }

        public function testStaticExpectation(): void {
          self::expectException(\InvalidArgumentException::class);
          throw new \InvalidArgumentException('boom');
        }

        public function testDocumentedCalls(): void {
          $this->expectException(\InvalidArgumentException::class);
          self::fail2();
          $this->fail3();
        }

        public function testDocumentedCallsWithoutExpectation(): void {
          self::fail2();
          $this->fail3();
        }

        public function testExpectationOnOtherInstance(): void {
          $other = new self('other');
          $other->expectException(\DomainException::class);
          throw new \DomainException('boom');
        }

        public function testWithoutExpectation(): void {
          throw new \RuntimeException('boom');
        }

        /** @throws \InvalidArgumentException */
        private static function fail2(): void { throw new \InvalidArgumentException('boom'); }

        /** @throws \InvalidArgumentException */
        private function fail3(): void { throw new \InvalidArgumentException('boom'); }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                               |
      | MissingThrowsDocblock | InvalidArgumentException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | InvalidArgumentException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | DomainException is thrown but not caught - please either catch or add a @throws annotation            |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation           |
    And I see no other errors

  Scenario: MissingThrowsDocblock is not reported after expectException in a branch
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" checkForThrowsDocblock="true">
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
          <MissingPureAnnotation errorLevel="suppress" />
        </issueHandlers>
      </psalm>
      """
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testIf(bool $fail): void {
          if ($fail) {
            $this->expectException(\InvalidArgumentException::class);
          }
          throw new \InvalidArgumentException('boom');
        }

        public function testBothArms(bool $fail): void {
          if ($fail) {
            $this->expectException(\InvalidArgumentException::class);
          } else {
            $this->expectException(\DomainException::class);
          }
          throw new \InvalidArgumentException('boom');
        }

        public function testCatch(): void {
          try {
            $value = 1;
          } catch (\Throwable) {
            $this->expectException(\InvalidArgumentException::class);
          }
          throw new \InvalidArgumentException('boom');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: MissingThrowsDocblock is not reported for exceptions of PHPUnit's own API
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" checkForThrowsDocblock="true">
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
    And I have the following code
      """
      /** @psalm-mutable */
      interface Repository {
        /** @psalm-impure */
        public function find(): int;
      }

      final class MyTestCase extends TestCase {
        public function testMockBuilder(): void {
          $mock = $this->getMockBuilder(Repository::class)
            ->onlyMethods(['find'])
            ->disableOriginalConstructor()
            ->getMock();
          $mock->method('find')->willReturn(1);
          $this->assertJson('{}');
        }

        public function testAssertionsAndMocks(): void {
          $repository = $this->createMock(Repository::class);
          $stub = $this->createStub(Repository::class);
          $this->assertSame(100, 100);
          self::assertCount(1, [$repository, $stub]);
          $this->assertXmlStringEqualsXmlString('<a/>', '<a/>');
          $this->assertXmlFileNotEqualsXmlFile('a.xml', 'b.xml');
          $this->assertInstanceOf(Repository::class, $repository);
        }

        public function testPhpUnitExceptionsOutsideTestMethods(): void {
          $this->helper();
        }

        /** @psalm-pure */
        public function testOtherExceptionsAreStillReported(): void {
          throw new \RuntimeException('boom');
        }

        private function helper(): void {
          $this->assertTrue(true);
          $this->createMock(Repository::class);
          $this->fail('boom');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                     |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation |
    And I see no other errors

  Scenario: Exceptions configured in ignoreExceptions are still ignored
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" checkForThrowsDocblock="true">
        <projectFiles>
          <directory name="."/>
          <ignoreFiles> <directory name="../../vendor"/> </ignoreFiles>
        </projectFiles>
        <plugins>
          <pluginClass class="Psalm\PhpUnitPlugin\Plugin"/>
        </plugins>
        <ignoreExceptions>
          <classAndDescendants name="DomainException"/>
        </ignoreExceptions>
        <issueHandlers>
          <MissingClassConstType errorLevel="suppress" />
          <DeprecatedMethod errorLevel="suppress" />
        </issueHandlers>
      </psalm>
      """
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testIgnoredByUser(): void {
          $this->assertTrue(true);
          throw new \DomainException('boom');
        }

        /** @psalm-pure */
        public function testNotIgnored(): void {
          throw new \RuntimeException('boom');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                     |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation |
    And I see no other errors

  Scenario: assertNotEmpty removes null from the asserted value
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Customer {
        public string $name = 'Ada';
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        private function find(): ?Customer { return null; }

        public function testFinds(): void {
          $customer = $this->find();
          $this->assertNotEmpty($customer);
          $this->assertSame('Ada', $customer->name);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertNotEmpty narrows arrays and strings to non-empty types
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /** @param list<int>|null $list */
        public function testList(?array $list, string $string): void {
          self::assertNotEmpty($list);
          self::assertNotEmpty($string);
          /** @psalm-check-type-exact $list = non-empty-list<int> */
          /** @psalm-check-type-exact $string = non-falsy-string */
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertNotEmpty on Countable objects is not a redundant condition
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testCountable(\Countable $countable, \ArrayObject $items): void {
          $this->assertNotEmpty($countable);
          self::assertNotEmpty($items);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertSame with a null expectation suggests assertNull
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testNull(): void {
          $value = random_int(0, 1) ? 1 : null;
          $this->assertSame(null, $value);
          $this->assertNotSame(NULL, $value);
          self::assertSame(\null, $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                 |
      | UnspecificNullAssertion | Use assertNull() instead of assertSame(null, ...)       |
      | UnspecificNullAssertion | Use assertNotNull() instead of assertNotSame(null, ...) |
      | UnspecificNullAssertion | Use assertNull() instead of assertSame(null, ...)       |
    And I see no other errors

  Scenario: assertSame with a boolean expectation suggests assertTrue and assertFalse
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testBool(): void {
          $flag = random_int(0, 1) === 1;
          $this->assertSame(true, $flag);
          $this->assertSame(false, $flag);
          $this->assertNotSame(true, $flag);
          self::assertNotSame(FALSE, $flag);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                       | Message                                                   |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertSame(true, ...)         |
      | UnspecificBooleanAssertion | Use assertFalse() instead of assertSame(false, ...)       |
      | UnspecificBooleanAssertion | Use assertNotTrue() instead of assertNotSame(true, ...)   |
      | UnspecificBooleanAssertion | Use assertNotFalse() instead of assertNotSame(false, ...) |
    And I see no other errors

  Scenario: assertSame and assertEquals with count() suggest assertCount
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testCount(): void {
          $lines = ['a', 'b', 'c'];
          $collection = new \ArrayObject($lines);
          $this->assertSame(3, count($lines));
          $this->assertEquals(3, \count($lines));
          $this->assertNotSame(2, count($lines));
          $this->assertNotEquals(2, count($lines));
          $this->assertSame(3, $collection->count());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                          |
      | UnspecificCountAssertion | Use assertCount() instead of assertSame(..., count(...))         |
      | UnspecificCountAssertion | Use assertCount() instead of assertEquals(..., count(...))       |
      | UnspecificCountAssertion | Use assertNotCount() instead of assertNotSame(..., count(...))   |
      | UnspecificCountAssertion | Use assertNotCount() instead of assertNotEquals(..., count(...)) |
      | UnspecificCountAssertion | Use assertCount() instead of assertSame(..., count(...))         |
    And I see no other errors

  Scenario: Assertions without a literal expectation or a plain count are not reported
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Bag {
        /** @psalm-pure */
        public function count(): int { return 1; }
      }

      final class MyTestCase extends TestCase {
        private const NOTHING = null;

        private function maybe(): ?int {
          return random_int(0, 1) ? 1 : null;
        }

        public function testOthers(): void {
          $flag = random_int(0, 1) === 1;
          $lines = [['a'], ['b']];
          $this->assertNull($this->maybe());
          $this->assertTrue($flag);
          $this->assertCount(2, $lines);
          $this->assertSame(1, $this->maybe());
          $this->assertSame(self::NOTHING, $this->maybe());
          $this->assertSame($flag, true);
          $this->assertEquals(null, $this->maybe());
          $this->assertSame(2, count($lines, COUNT_RECURSIVE));
          $this->assertSame(2, (new Bag())->count());
          $this->assertSame(2, strlen('ab'));
          $this->assertNotSame('2', count($lines));
          $this->assertSame(message: 'no', actual: $this->maybe(), expected: null);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: count() that is not the global function is not reported
    Given I have the following code
      """
      use function strlen as count;

      final class MyTestCase extends TestCase {
        public function testAliasedCount(): void {
          $this->assertSame(2, count('ab'));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: count() declared in the test namespace is not reported
    Given I have the following code
      """
      /** @psalm-pure */
      function count(string $text): int {
        return strlen($text);
      }

      final class MyTestCase extends TestCase {
        public function testNamespacedCount(): void {
          $this->assertSame(2, count('ab'));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assertion suggestions can be suppressed
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testSuppressed(): void {
          $value = random_int(0, 1) ? 1 : null;
          $flag = random_int(0, 1) === 1;
          $lines = ['a'];
          /** @psalm-suppress UnspecificNullAssertion */
          $this->assertSame(null, $value);
          /** @psalm-suppress UnspecificBooleanAssertion */
          $this->assertSame(true, $flag);
          /** @psalm-suppress UnspecificCountAssertion */
          $this->assertSame(1, count($lines));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: PHPUnit 12 reports ignored @test and @dataProvider docblock tags
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }

        /**
         * @dataProvider provide
         */
        public function testProvided(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                   | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead                                            | 7    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead | 14   |
    And I see no other errors

  Scenario: PHPUnit 13 reports ignored docblock tags
    Given PHPUnit identifies as version "13.0-dev"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @group slow
         */
        public function testSlow(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports ignored class level docblock tags
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      /**
       * @covers \NS\MyTestCase
       * @group slow
       */
      final class MyTestCase extends TestCase {
        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                       | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @covers docblock tag, use #[CoversClass], #[CoversMethod] or #[CoversFunction] instead | 6    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead                              | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports docblock tags on a method that also has a PHPUnit attribute
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\Test;

      final class MyTestCase extends TestCase {
        /**
         * @group slow
         */
        #[Test]
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 9    |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored docblock tag of a trait method once
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      trait SharedTests {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }

      final class FirstTestCase extends TestCase {
        use SharedTests;
      }

      final class SecondTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored docblock tag of an abstract test case once
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        /**
         * @before
         */
        public function prepare(): void {
          $this->assertTrue(true);
        }
      }

      final class FirstTestCase extends BaseTestCase {
      }

      final class SecondTestCase extends BaseTestCase {
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                            | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @before docblock tag, use #[Before] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored @requires docblock tag
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @psalm-pure
         * @return int
         */
        public static function helper(): int {
          return 1;
        }

        /**
         * @requires PHP 8.0
         */
        public function testHelper(): void {
          $this->assertSame(1, self::helper());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                                | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @requires docblock tag, use #[RequiresPhp], #[RequiresPhpExtension], #[RequiresOperatingSystem] or another #[Requires*] instead | 15   |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored docblock tag of a shared trait once
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      /**
       * @group shared
       */
      trait SharedTests {
        public function testShared(): void {
          $this->assertTrue(true);
        }
      }

      final class FirstTestCase extends TestCase {
        use SharedTests;
      }

      final class SecondTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 6    |
    And I see no other errors

  Scenario: PHPUnit 11 pin survives a config with its own autoloader
    Given PHPUnit identifies as version "11.5.0"
    And I have the following code in "autoload.php"
      """
      <?php
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" autoloader="autoload.php">
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
    When I run Psalm
    Then I see no errors

  Scenario: PHPUnit 12 pin survives a config with its own autoloader
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code in "autoload.php"
      """
      <?php
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" autoloader="autoload.php">
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
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 leaves Psalm and other docblock tags alone
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @param int $number
         * @return void
         * @throws \RuntimeException
         * @Test
         * @testing
         */
        public function testSomething(int $number): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Ignored docblock metadata can be suppressed
    Given PHPUnit identifies as version "12.5.43"
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" findUnusedPsalmSuppress="true">
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
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         * @psalm-suppress IgnoredDocblockMetadata
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: PHPUnit 12 no longer treats docblock tags as test and provider usage
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }

        /**
         * @dataProvider provide
         */
        public function testProvided(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                    | Message                                                                                                   |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead                                            |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::itWorks                                                    |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::provide                                                    |
    And I see no other errors

  Scenario: PHPUnit 12 does not resolve an ignored @dataProvider
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @dataProvider missing
         */
        public function testProvided(int $number): void {
          $this->assertSame(1, $number);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                   |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead |
    And I see no other errors

  Scenario: PHPUnit 12 no longer treats @before as an initializer
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      /** @psalm-mutable */
      interface I {
        /** @psalm-impure */
        public function work(): int;
      }

      final class MyTestCase extends TestCase
      {
        /** @var I&\PHPUnit\Framework\MockObject\Stub */
        private $i;

        /**
         * @before
         */
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }

        public function testSomething(): void {
          $this->i->method('work')->willReturn(1);

          $this->assertEquals(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                            |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @before docblock tag, use #[Before] instead |
      | MissingConstructor      | NS\MyTestCase has an uninitialized property NS\MyTestCase::$i, but no constructor |
    And I see no other errors

  Scenario: PHPUnit 12 keeps attribute metadata working
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Test;

      final class MyTestCase extends TestCase {
        #[Test]
        #[DataProvider('provide')]
        public function itWorks(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: PHPUnit 11 does not report docblock metadata
    Given PHPUnit identifies as version "11.5.0"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         * @dataProvider provide
         * @group slow
         */
        public function itWorks(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors
