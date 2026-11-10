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

          $this->assertSame(1, $this->i->work());
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

          $this->assertSame(1, $this->i->work());
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

          $this->assertSame(1, $this->i->work());
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

          $this->assertSame(1, $this->i->work());
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                   |
      | InvalidDataProvider | Data provider method NS\External::provide must be public |
    And I see no other errors

  @ExternalProviders
  Scenario: #[DataProvider] naming another class is reported, as PHPUnit looks it up on the test class
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

      final class MyTestCase extends TestCase {
        #[Attributes\DataProvider('External::provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                         |
      | UndefinedMethod | Provider method NS\MyTestCase::External::provide is not defined |
    And I see no other errors

  Scenario: #[DataProvider] naming another class is reported even if the test class has a method named like the class
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function External() {
          yield [1];
        }

        #[Attributes\DataProvider('External::provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                         |
      | UndefinedMethod | Provider method NS\MyTestCase::External::provide is not defined |
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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

  Scenario: Non-static implementation of an abstract #[DataProvider] is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: Non-public implementation of an abstract #[DataProvider] is reported
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
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        protected static function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be public |
    And I see no other errors

  Scenario: Non-static implementation of an abstract @dataProvider is reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        /**
         * @dataProvider provide
         */
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: Static implementation of an abstract @dataProvider is not reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public static function provide();

        /**
         * @dataProvider provide
         */
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
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

  Scenario: Invalid implementation of an abstract data provider is reported for both the inherited and the own test
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testInherited(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testOwn(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     | Line |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static | 26   |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static | 30   |
    And I see no other errors

  Scenario: Invalid implementation of an abstract data provider is reported once for a deeper subclass
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      abstract class MiddleTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends MiddleTestCase {}

      final class OtherTestCase extends MiddleTestCase {}
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                         |
      | InvalidDataProvider | Data provider method NS\MiddleTestCase::provide must be static |
    And I see no other errors

  Scenario: Invalid implementation of an abstract data provider can be suppressed on the provider
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         * @psalm-suppress InvalidDataProvider
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid implementation of an abstract data provider can be suppressed on the test class
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      /**
       * @psalm-suppress InvalidDataProvider
       */
      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Non-static data provider of an inherited test is reported once
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {}
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                       |
      | InvalidDataProvider | Data provider method NS\BaseTestCase::provide must be static |
    And I see no other errors

  Scenario: Non-static trait implementation of an abstract data provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      /** @psalm-pure */
      trait Provides {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }
      }

      final class MyTestCase extends BaseTestCase {
        use Provides;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: Non-static trait implementation of an abstract data provider can be suppressed on the test class
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

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      /** @psalm-pure */
      trait Provides {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public function provide() {
          yield [1];
        }
      }

      /**
       * @psalm-suppress InvalidDataProvider
       */
      final class MyTestCase extends BaseTestCase {
        use Provides;
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
        }

        /**
         * @test
         */
        public function somethingElse(int $int): void {
          $this->assertSame(1, $int);
        }

        #[Attributes\Test]
        public function somethingElseWithAttribute(int $int): void {
          $this->assertSame(1, $int);
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
          $this->assertSame(1, $int);
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

          $this->assertSame(1, $this->i->work());
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

          $this->assertSame(1, $this->i->work());
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

          $this->assertSame(1, $this->i->work());
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

          $this->assertSame(1, $this->i->work());
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

  @ExternalProviders
  Scenario: Unreferenced external providers are still marked as unused
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

        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function other() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase {
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                            |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\External::other |
    And I see no other errors

  @ExternalProviders
  Scenario: Mismatched #[DataProviderExternal] providers are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

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
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\External::provide():(iterable[pure]<string, array<int, string>>) |
    And I see no other errors

  @ExternalProviders
  Scenario: Missing #[DataProviderExternal] method is reported on the line of its own attribute
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

      final class MyTestCase extends TestCase {
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        #[Attributes\DataProviderExternal(External::class, 'missing')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                             | Line |
      | UndefinedMethod | Provider method NS\External::missing is not defined | 20   |
    And I see no other errors

  @ExternalProviders
  Scenario: Non-static #[DataProviderExternal] provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

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
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                  |
      | InvalidDataProvider | Data provider method NS\External::provide must be static |
    And I see no other errors

  @ExternalProviders
  Scenario: Non-public #[DataProviderExternal] provider is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

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
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                  |
      | InvalidDataProvider | Data provider method NS\External::provide must be public |
    And I see no other errors

  @ExternalProviders
  Scenario: Invalid #[DataProviderExternal] provider can be suppressed on the test method
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

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
         * @psalm-suppress InvalidDataProvider
         */
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  @ExternalProviders
  Scenario: #[DataProviderExternal] with a class name string is checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

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
        #[Attributes\DataProviderExternal('NS\External', 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message                                                                                                                                        |
      | InvalidArgument      | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\External::provide():(iterable[pure]<string, array<int, string>>) |
      | ArgumentTypeCoercion | Argument 1 of PHPUnit\Framework\Attributes\DataProviderExternal::__construct expects class-string, but parent type 'NS\\\\External' provided   |
    And I see no other errors

  @ExternalProviders
  Scenario: #[DataProviderExternal] class is resolved through an import alias and named arguments
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderExternal as Ext;
      use NS\External as Provider;

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

      final class MyTestCase extends TestCase {
        #[Ext(methodName: 'provide', className: Provider::class)]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  @ExternalProviders
  Scenario: #[DataProviderExternal] accepts self::class and parent::class
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function base() {
          yield [1];
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function own() {
          yield [1];
        }

        #[Attributes\DataProviderExternal(self::class, 'own')]
        #[Attributes\DataProviderExternal(parent::class, 'base')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  @ExternalProviders
  Scenario: #[DataProviderExternal] can be repeated and mixed with #[DataProvider]
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      /** @psalm-pure */
      final class External {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function first() {
          yield [1];
        }

        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function second() {
          yield [1];
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function own() {
          yield [1];
        }

        #[Attributes\DataProviderExternal(External::class, 'first')]
        #[Attributes\DataProvider('own')]
        #[Attributes\DataProviderExternal(External::class, 'second')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  @ExternalProviders
  Scenario: #[DataProviderExternal] of a trait test method is checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

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

      trait MyTestTrait {
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testInTrait(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                      |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testInTrait expects int, string provided by NS\External::provide():(iterable[pure]<string, array<int, string>>) |
    And I see no other errors

  @ExternalProviders
  Scenario: Docblock providers of a trait test are resolved relative to the test case, not the trait
    Given I have the following code in "trait.php"
      """
      <?php
      namespace Shared;

      trait MyTestTrait {
        /**
         * @dataProvider Fixtures::provide
         */
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    And I have the following code in "fixtures.php"
      """
      <?php

      /** @psalm-pure */
      final class Fixtures {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function provide() {
          yield [1];
        }
      }
      """
    And I have the following code in "test.php"
      """
      <?php

      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        use Shared\MyTestTrait;
      }
      """
    When I run Psalm
    Then I see no errors

  @ExternalProviders
  Scenario: Docblock data provider is unused when the test has a #[DataProviderExternal] attribute
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

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        public static function legacy() {
          yield [1];
        }

        /**
         * @dataProvider legacy
         */
        #[Attributes\DataProviderExternal(External::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                               |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::legacy |
    And I see no other errors

  @ExternalProviders
  Scenario: Missing #[DataProviderExternal] class is reported once by Psalm
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        #[Attributes\DataProviderExternal(Missing::class, 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type           | Message                                                  |
      | UndefinedClass | Class, interface or enum named NS\Missing does not exist |
    And I see no other errors

  @ExternalProviders
  Scenario: #[DataProviderExternal] with a class name string is available even when Psalm is asked to analyze single test case
    Given I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      use PHPUnit\Framework\Attributes\DataProviderExternal;

      final class MyTestCase extends TestCase {
        #[DataProviderExternal('NS\External', 'provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
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
        public static function provide() {
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
    Then I see these errors
      | Type                 | Message                                                                                                                                      |
      | ArgumentTypeCoercion | Argument 1 of PHPUnit\Framework\Attributes\DataProviderExternal::__construct expects class-string, but parent type 'NS\\\\External' provided |
    And I see no other errors

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
      | Type               | Message                               |
      | UnusedFunctionCall | The call to json_decode is not used   |
      | UnusedMethodCall   | The call to NS\Value::get is not used |
      | UnusedFunctionCall | The call to json_encode is not used   |
      | UnusedMethodCall   | The call to NS\Other::get is not used |
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
      | Type                  | Message                                                                                             |
      | MissingThrowsDocblock | InvalidArgumentException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | InvalidArgumentException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | DomainException is thrown but not caught - please either catch or add a @throws annotation          |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation         |
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

  Scenario: assertEquals with both arguments of the same scalar type suggests assertSame
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testScalars(): void {
          $int = random_int(0, 1);
          $text = (string) $int;
          $float = (float) $int;
          $flag = $int === 1;
          $choice = $int ? 'a' : 'b';
          $this->assertEquals(1, $int);
          $this->assertNotEquals($int, 2);
          self::assertEquals($int, $int);
          static::assertEquals($int, $int);
          \PHPUnit\Framework\Assert::assertEquals($int, $int);
          $this->assertEquals('a', $text);
          $this->assertNotEquals($text, strrev($text));
          $this->assertEquals($choice, $text);
          $this->assertEquals(0.5, $float);
          $this->assertEquals($float, $float);
          $this->assertEquals($flag, !$flag);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                      | Message                                                                             | Line |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 12   |
      | UnspecificEqualsAssertion | Use assertNotSame() instead of assertNotEquals(), both arguments are of type int    | 13   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 14   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 15   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 16   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type string       | 17   |
      | UnspecificEqualsAssertion | Use assertNotSame() instead of assertNotEquals(), both arguments are of type string | 18   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type string       | 19   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type float        | 20   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type float        | 21   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type bool         | 22   |
    And I see no other errors

  Scenario: assertEquals with a boolean expectation suggests assertTrue and assertFalse
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testBool(): void {
          $flag = random_int(0, 1) === 1;
          $this->assertEquals(true, $flag);
          $this->assertEquals(FALSE, $flag);
          $this->assertNotEquals(true, $flag);
          self::assertNotEquals(false, $flag);
          $this->assertEquals(true, true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                       | Message                                                     | Line |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertEquals(true, ...)         | 8    |
      | UnspecificBooleanAssertion | Use assertFalse() instead of assertEquals(false, ...)       | 9    |
      | UnspecificBooleanAssertion | Use assertNotTrue() instead of assertNotEquals(true, ...)   | 10   |
      | UnspecificBooleanAssertion | Use assertNotFalse() instead of assertNotEquals(false, ...) | 11   |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertEquals(true, ...)         | 12   |
    And I see no other errors

  Scenario: assertEquals with different, mixed, nullable or non-scalar arguments is not reported
    Given I have the following code
      """
      enum Suit: string {
        case Hearts = 'h';
      }

      final class MyTestCase extends TestCase {
        public function testOthers(): void {
          $int = random_int(0, 1);
          $text = (string) $int;
          $float = (float) $int;
          $maybeInt = $int ? 1 : null;
          $intOrText = $int ? 1 : 'a';
          $this->assertEquals(1, $text);
          $this->assertEquals(1, $float);
          $this->assertEquals(true, $int);
          $this->assertNotEquals(false, $text);
          $this->assertEquals(true, $int ? true : null);
          $this->assertEquals(0, $maybeInt);
          $this->assertEquals($maybeInt, $int);
          $this->assertEquals(null, $int);
          $this->assertEquals(1, $intOrText);
          $this->assertEquals($intOrText, $intOrText);
          $this->assertEquals(1, json_decode('1'));
          $this->assertEquals([1], [1]);
          $this->assertEquals(new \stdClass(), new \stdClass());
          $this->assertEquals(Suit::Hearts, Suit::Hearts);
          $this->assertEqualsWithDelta(1.0, $float, 0.1);
          $this->assertEqualsIgnoringCase('a', $text);
          $this->assertEquals(expected: 1, actual: $int);
          $this->assertEquals(...[1, $int]);
          $check = $this->assertEquals(...);
          $check(1, $int);
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertEquals suggestion is only reported at error level 1
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="2" findUnusedCode="false" >
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
        public function testEquals(): void {
          $this->assertEquals(1, random_int(0, 1));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertEquals suggestion can be suppressed in the config
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" >
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
          <PluginIssue name="UnspecificEqualsAssertion" errorLevel="suppress" />
        </issueHandlers>
      </psalm>
      """
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testEquals(): void {
          $this->assertEquals(1, random_int(0, 1));
        }
      }
      """
    When I run Psalm
    Then I see no errors

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
          /** @psalm-suppress UnspecificEqualsAssertion */
          $this->assertEquals(1, random_int(0, 1));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks have the type of every listed interface
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      /** @psalm-impure */
      function useClock(Clock $clock): int {
        return $clock->now();
      }

      final class MyTestCase extends TestCase {
        public function testMock(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->method('now')->willReturn(1);
          $mock->expects($this->once())->method('log');
          $mock->log('tick');
          $this->assertSame(1, $mock->now());
          $this->assertSame(1, useClock($mock));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection stubs have the type of every listed interface
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      /** @psalm-impure */
      function useLogger(Logger $logger): void {
        $logger->log('tick');
      }

      final class MyTestCase extends TestCase {
        public function testStub(): void {
          $stub = self::createStubForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $stub->method('now')->willReturn(1);
          $stub->log('tick');
          $this->assertSame(1, $stub->now());
          useLogger($stub);
        }

        public function testStaticStub(): void {
          $stub = static::createStubForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $this->assertSame(0, $stub->now());
        }

        public function testInstanceStub(): void {
          $stub = $this->createStubForIntersectionOfInterfaces(interfaces: [Clock::class, Logger::class]);
          $stub->log('tick');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks and stubs report methods that no listed interface declares
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        public function testUnknownMethods(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $stub = $this->createStubForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->nope();
          $stub->expects($this->once());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                                                  |
      | UndefinedInterfaceMethod | Method (NS\Clock&NS\Logger&PHPUnit\Framework\MockObject\MockObject)::nope does not exist |
      | UndefinedInterfaceMethod | Method (NS\Clock&NS\Logger&PHPUnit\Framework\MockObject\Stub)::expects does not exist    |
    And I see no other errors

  Scenario: Intersection mock interfaces can be listed in a variable and number more than two
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        public function testVariable(): void {
          $interfaces = [Clock::class, Logger::class];
          $mock = $this->createMockForIntersectionOfInterfaces($interfaces);
          $mock->log('tick');
          $this->assertSame(1, $mock->now());
        }

        public function testThreeInterfaces(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class, \Countable::class]);
          $this->assertSame(1, $mock->now());
          $this->assertSame(2, $mock->count());
          $mock->log('tick');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks keep the PHPUnit type when the interfaces are not a literal list
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        /** @param list<class-string> $interfaces */
        public function testOpenList(array $interfaces): void {
          $this->createMockForIntersectionOfInterfaces($interfaces)->now();
        }

        public function testSingleInterface(): void {
          $this->createMockForIntersectionOfInterfaces([Clock::class])->now();
        }

        public function testDuplicateInterface(): void {
          $this->createMockForIntersectionOfInterfaces([Clock::class, Clock::class])->now();
        }

        public function testSpread(): void {
          $this->createStubForIntersectionOfInterfaces(...[[Clock::class, Logger::class]])->now();
        }

        public function testFirstClassCallable(): void {
          $factory = $this->createMockForIntersectionOfInterfaces(...);
          $factory([Clock::class, Logger::class])->now();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                            | Line |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 20   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 24   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 28   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\Stub::now does not exist       | 32   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 37   |
    And I see no other errors

  Scenario: Intersection mocks work in traits and abstract test cases
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      trait MocksClock {
        public function mockClock(): int {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->log('tick');
          return $mock->now();
        }
      }

      abstract class BaseTestCase extends TestCase {
        protected static function stubClock(): int {
          return self::createStubForIntersectionOfInterfaces([Clock::class, Logger::class])->now();
        }
      }

      final class MyTestCase extends BaseTestCase {
        use MocksClock;

        public function testTraitAndParent(): void {
          $this->assertSame(1, $this->mockClock());
          $this->assertSame(1, self::stubClock());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks are not reported as unused with dead code detection
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        public function testMock(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->log('tick');
          $this->assertSame(1, $mock->now());
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Annotation without a value is reported instead of a provider error
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /** @dataProvider*/
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                               | Line |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" has no value | 7    |
    And I see no other errors

  Scenario: Annotation alone on its line is reported on that line, not merged with the description below
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @dataProvider
         * Some description of the test
         */
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                               | Line |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" has no value | 8    |
    And I see no other errors

  Scenario: Other value annotations and class docblocks are checked too
    Given I have the following code
      """
      /** @covers*/
      final class MyTestCase extends TestCase
      {
        /**
         * @depends
         * @group
         * @dataProvider(provide)
         */
        public function testFirst(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                              | Line |
      | InvalidPhpUnitAnnotation | Annotation "@covers" has no value                                  | 5    |
      | InvalidPhpUnitAnnotation | Annotation "@depends" has no value                                 | 9    |
      | InvalidPhpUnitAnnotation | Annotation "@group" has no value                                   | 10   |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" must be followed by a space and a value | 11   |
    And I see no other errors

  Scenario: Description lines below a valid provider annotation are not part of the provider name
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @dataProvider provide
         * more words about it
         */
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }

        /**
         * @psalm-pure
         * @return list<array{int}>
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Annotations on methods that are not tests are checked
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @psalm-pure
         * @dataProvider
         */
        public function helper(): int {
          return 1;
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                 | Line |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" has no value | 9    |
    And I see no other errors

  Scenario: Malformed annotations can be suppressed on the method and on the class
    Given I have the following code
      """
      /**
       * @psalm-suppress InvalidPhpUnitAnnotation
       * @covers
       */
      final class SuppressedClassTest extends TestCase
      {
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }

      final class SuppressedMethodTest extends TestCase
      {
        /**
         * @psalm-suppress InvalidPhpUnitAnnotation
         * @depends
         */
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Malformed annotation in a trait method is reported on the trait's line
    Given I have the following code
      """
      trait HelperTrait
      {
        /** @dataProvider*/
        public function testFromTrait(): void {
          $this->expectNotToPerformAssertions();
        }
      }

      final class MyTestCase extends TestCase
      {
        use HelperTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                               | Line |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" has no value | 7    |
    And I see no other errors

  Scenario: Malformed annotation next to a PHPUnit attribute is reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /** @depends*/
        #[\PHPUnit\Framework\Attributes\Test]
        public function checkSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                             | Line |
      | InvalidPhpUnitAnnotation | Annotation "@depends" has no value  | 7    |
    And I see no other errors

  Scenario: Well formed value annotations are not reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /** @dataProvider provide*/
        public function testWithProvider(int $int): void {
          $this->assertSame(1, $int);
        }

        /**
         * @depends	testWithProvider
         * @group	slow
         */
        public function testAfter(): void {
          $this->expectNotToPerformAssertions();
        }

        /**
         * @psalm-pure
         * @return list<array{int}>
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A testWith annotation with its datasets on the following lines is not reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @testWith
         *   [1]
         *   [2]
         */
        public function testMultiline(int $int): void {
          $this->assertSame(1, $int % 2);
        }

        /**
         * @testWith [1]
         *           [3]
         */
        public function testSameLine(int $int): void {
          $this->assertSame(1, $int % 2);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A testWith annotation without datasets is reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        /**
         * @testWith
         */
        public function testEmpty(int $int): void {
          $this->assertSame(1, $int);
        }

        /** @testWith[1] */
        public function testGlued(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                         | Line |
      | InvalidPhpUnitAnnotation | Annotation "@testWith" has no value                             | 8    |
      | InvalidPhpUnitAnnotation | Annotation "@testWith" must be followed by a space and a value | 14   |
    And I see no other errors

  Scenario: Malformed annotation in a trait method is suppressed on the test class using the trait
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
      /** @psalm-immutable */
      trait HelperTrait
      {
        /**
         * @return void
         * @psalm-capabilities read-props
         * @dataProvider*/
        public function testFromTrait() {}
      }

      /**
       * @psalm-suppress InvalidPhpUnitAnnotation
       */
      final class MyTestCase extends TestCase
      {
        use HelperTrait;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Malformed annotation in a trait from another file is suppressed on the trait
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
    And I have the following code in "HelperTrait.php"
      """
      <?php
      namespace NS;

      /**
       * @psalm-immutable
       * @psalm-suppress InvalidPhpUnitAnnotation
       */
      trait HelperTrait
      {
        /**
         * @return void
         * @psalm-capabilities read-props
         * @dataProvider*/
        public function testFromTrait() {}
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

final class MyTestCase extends TestCase
      {
        use HelperTrait;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Suppression on the test class does not reach a trait method from another file
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
    And I have the following code in "HelperTrait.php"
      """
      <?php
      namespace NS;

      /**
       * @psalm-immutable
       */
      trait HelperTrait
      {
        /**
         * @return void
         * @psalm-capabilities read-props
         * @dataProvider*/
        public function testFromTrait() {}
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      /**
       * @psalm-suppress InvalidPhpUnitAnnotation
       */
final class MyTestCase extends TestCase
      {
        use HelperTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                 | Line |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" has no value | 12   |
      | UnusedPsalmSuppress      | This suppression is never used          | 6    |
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

  Scenario: PHPUnit 12 reports a non-static implementation of an abstract #[DataProvider]
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: PHPUnit 12 ignores a docblock data provider of an inherited test
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        /**
         * @dataProvider provide
         */
        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                    | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead | 13   |
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

  Scenario: A suppression on a trait covers the ignored docblock tags of its methods
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
    And I have the following code in "trait.php"
      """
      <?php
      namespace NS;

      /**
       * @psalm-suppress IgnoredDocblockMetadata
       */
      trait SharedTests {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A suppression on the test case does not cover ignored docblock tags in a trait file
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
    And I have the following code in "trait.php"
      """
      <?php
      namespace NS;

      trait SharedTests {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      /**
       * @psalm-suppress IgnoredDocblockMetadata
       */
      final class MyTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 6    |
      | UnusedPsalmSuppress     | This suppression is never used                                 | 6    |
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
      | Type                    | Message                                                                                                   | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead                                            | 7    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead | 14   |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::itWorks                                                    | 9    |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::provide                                                    | 24   |
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

          $this->assertSame(1, $this->i->work());
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

  Scenario: PHPUnit 12 reports a malformed docblock tag as ignored metadata only
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @group
         */
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 7    |
    And I see no other errors

  Scenario: Mocking an undefined method is reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testMethods(): void {
          $mock = $this->createMock(Mailer::class);
          $mock->expects($this->once())->method('sendInvoce')->willReturn(true);
          $mock->method('sendInvoce')->willReturn(true);
          $mock->method('sendInvoice')->willReturn(true);

          $stub = $this->createStub(Mailer::class);
          $stub->method('sendInvoce')->willReturn(true);

          $configured = $this->createConfiguredMock(Mailer::class, ['sendInvoice' => true]);
          $configured->method('sendInvoce')->willReturn(true);

          $built = $this->getMockBuilder(Mailer::class)->getMock();
          $built->method('sendInvoce')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                    | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 14   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 15   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 19   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 22   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 25   |
    And I see no other errors

  Scenario: Mocking an undefined method is reported on typed properties and for every literal name
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        private const TYPO = 'sendInvoce';

        /** @var Mailer&\PHPUnit\Framework\MockObject\Stub */
        private $docblockStub;

        private \PHPUnit\Framework\MockObject\MockObject&Mailer $nativeMock;

        #[\Override]
        public function setUp(): void {
          $this->docblockStub = $this->createStub(Mailer::class);
          $this->nativeMock = $this->createMock(Mailer::class);
        }

        public function testProperties(): void {
          $this->docblockStub->method('sendInvoce')->willReturn(true);
          $this->nativeMock->method(self::TYPO)->willReturn(true);
        }

        public function testUnion(): void {
          $mailer = $this->createStub(Mailer::class);
          $mailer->method(random_int(0, 1) ? 'sendInvoice' : 'sendInvoce')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                    | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 26   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 27   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 32   |
    And I see no other errors

  Scenario: Mocking a method PHPUnit adds to a Traversable double is not reported
    Given I have the following code
      """
      /**
       * @psalm-mutable
       * @extends \Traversable<int, int>
       */
      interface Numbers extends \Traversable {}

      /**
       * @psalm-mutable
       * @extends \IteratorAggregate<int, string>
       */
      interface Letters extends \IteratorAggregate {}

      final class MyTestCase extends TestCase {
        public function testTraversable(): void {
          $traversable = $this->createMock(\Traversable::class);
          $traversable->method('current')->willReturn(1);
          $traversable->method('nope')->willReturn(1);
        }

        public function testDerivedInterface(): void {
          $numbers = $this->createStub(Numbers::class);
          $numbers->method('current')->willReturn(1);
          $numbers->method('nope')->willReturn(1);
        }

        public function testAggregate(): void {
          $letters = $this->createStub(Letters::class);
          $letters->method('getIterator')->willReturn(new \ArrayIterator([]));
          $letters->method('current')->willReturn(1);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                           | Line |
      | UndefinedMethod | Trying to mock an undefined method Traversable::nope()            | 21   |
      | UndefinedMethod | Trying to mock an undefined method NS\Numbers::nope()             | 27   |
      | UndefinedMethod | Trying to mock an undefined method NS\Letters::current()          | 33   |
    And I see no other errors

  Scenario: Mocking a property hook by name is not reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testHooks(): void {
          $mailer = $this->createMock(Mailer::class);
          $mailer->method('$value::get')->willReturn(true);
          $mailer->method('$value::set')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Mocking an undefined method can be suppressed per call
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testSuppressed(): void {
          $mailer = $this->createStub(Mailer::class);
          /** @psalm-suppress UndefinedMethod */
          $mailer->method('sendInvoce')->willReturn(true);
          $mailer->method('sendInvoise')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                     |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoise() |
    And I see no other errors

  Scenario: Mocking an existing method is not reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Sender {
        /** @psalm-impure */
        public function send(): bool;
      }

      /** @psalm-mutable */
      interface Mailer extends Sender {}

      /** @psalm-immutable */
      trait Logs {
        /** @psalm-pure */
        public function log(): int { return 1; }
      }

      /** @psalm-mutable */
      class Base {
        /** @psalm-impure */
        public function fromBase(): void {}
      }

      /**
       * @psalm-mutable
       * @method int magic()
       */
      final class Child extends Base {
        use Logs;

        /** @psalm-impure */
        final public function finalMethod(): void {}

        /** @psalm-impure */
        private function hidden(): void {}

        /** @psalm-impure */
        public static function make(): void {}
      }

      /**
       * @psalm-mutable
       * @method int magicInterface()
       */
      interface Magic {}

      /** @psalm-mutable */
      final class Dynamic {
        /** @psalm-impure */
        public function __call(string $name, array $arguments): mixed { return null; }
      }

      final class MyTestCase extends TestCase {
        public function testExisting(): void {
          $mailer = $this->createStub(Mailer::class);
          $mailer->method('send')->willReturn(true);
          $mailer->method('SEND')->willReturn(true);

          $child = $this->createMock(Child::class);
          $child->method('fromBase')->willReturn(null);
          $child->method('log')->willReturn(1);
          $child->method('hidden')->willReturn(null);
          $child->method('finalMethod')->willReturn(null);
          $child->method('make')->willReturn(null);
          $child->method('magic')->willReturn(1);

          $this->createStub(Magic::class)->method('magicInterface')->willReturn(1);
          $this->createStub(Dynamic::class)->method('anything')->willReturn(1);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Mock method calls Psalm cannot check are not reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      interface Auditor {
        /** @psalm-impure */
        public function expects(): Rule;
      }

      /** @psalm-mutable */
      interface Dispatcher {
        /** @psalm-impure */
        public function expects(): \PHPUnit\Framework\MockObject\Stub&Mailer;
      }

      /** @psalm-mutable */
      final class Rule {
        /** @psalm-impure */
        public function method(string $name): self { return $this; }
      }

      /** @psalm-mutable */
      final class Configurable {
        /** @psalm-impure */
        public function method(string $name): bool { return true; }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        private static function typoName(): string {
          return 'typo';
        }

        public function testUnchecked(string $name): void {
          $mailer = $this->createMock(Mailer::class);
          $mailer->method($name)->willReturn(true);
          $mailer->method(self::typoName())->willReturn(true);
          $mailer->method($this->logicalOr('typo', 'sendInvoice'))->willReturn(true);

          $expectation = $mailer->expects($this->once());
          $expectation->method('typo')->willReturn(true);

          /** @psalm-suppress UndefinedClass, MixedMethodCall */
          $this->createStub(MissingClass::class)->method('typo')->willReturn(true);

          $this->createStub(Configurable::class)->method('typo');
          $this->createStub(Auditor::class)->expects()->method('typo');
          $this->createStub(Dispatcher::class)->expects()->method('sendInvoice');

          $this->assertSame(1, 1);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A method that is only mocked by name is still reported as unused
    Given I have the following code
      """
      /** @psalm-mutable */
      abstract class Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool { return true; }
      }

      final class MyTestCase extends TestCase {
        public function testMocked(): void {
          $mailer = $this->createMock(Mailer::class);
          $mailer->method('sendInvoice')->willReturn(true);
          $this->assertSame(1, 1);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\Mailer::sendInvoice |
    And I see no other errors

  Scenario: setUp without a call to the parent is reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                         |
      | MissingParentCall | Missing call to parent::setUp() |
    And I see no other errors

  Scenario: tearDown, setUpBeforeClass and tearDownAfterClass without a call to the parent are reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }

        #[\Override]
        public static function setUpBeforeClass(): void {
          parent::setUpBeforeClass();
        }

        #[\Override]
        public static function tearDownAfterClass(): void {
          parent::tearDownAfterClass();
        }
      }

      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }

        /** @psalm-capabilities read-props */
        #[\Override]
        public static function setUpBeforeClass(): void {
        }

        /** @psalm-capabilities read-props */
        #[\Override]
        public static function tearDownAfterClass(): void {
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                      |
      | MissingParentCall | Missing call to parent::tearDown()           |
      | MissingParentCall | Missing call to parent::setUpBeforeClass()   |
      | MissingParentCall | Missing call to parent::tearDownAfterClass() |
    And I see no other errors

  Scenario: A hook inherited from a shared trait without a call to the parent is reported once, at the trait
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      /** @psalm-immutable */
      trait NoParentSetUp {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
        }
      }

      final class FirstTestCase extends BaseTestCase {
        use NoParentSetUp;
      }

      final class SecondTestCase extends BaseTestCase {
        use NoParentSetUp;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                         |
      | MissingParentCall | Missing call to parent::setUp() |
    And I see no other errors

  Scenario: A setUp from a trait that calls the parent is not reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      trait CallsParentSetUp {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      final class MyTestCase extends BaseTestCase {
        use CallsParentSetUp;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A parent whose setUp comes from a trait is checked
    Given I have the following code
      """
      trait SharedSetUp {
        protected function setUp(): void {
        }
      }

      abstract class BaseTestCase extends TestCase {
        use SharedSetUp;
      }

      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                         |
      | MissingParentCall | Missing call to parent::setUp() |
    And I see no other errors

  Scenario: Calls to the parent in any position of the method are accepted
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }

        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }

        #[\Override]
        public static function setUpBeforeClass(): void {
          parent::setUpBeforeClass();
        }

        #[\Override]
        public static function tearDownAfterClass(): void {
          parent::tearDownAfterClass();
        }
      }

      final class FinallyTestCase extends BaseTestCase {
        #[\Override]
        protected function tearDown(): void {
          try {
            $this->assertTrue(true);
          } finally {
            parent::tearDown();
          }
        }
      }

      final class CaseInsensitiveTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
          PARENT::SETUP();
        }
      }

      final class BranchTestCase extends BaseTestCase {
        #[\Override]
        public static function setUpBeforeClass(): void {
          if (random_int(0, 1) === 1) {
            parent::setUpBeforeClass();
          }
        }
      }

      final class NamedParentTestCase extends BaseTestCase {
        #[\Override]
        public static function tearDownAfterClass(): void {
          BaseTestCase::tearDownAfterClass();
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A parent call inside a closure or a first class callable does not count
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }

        #[\Override]
        public static function setUpBeforeClass(): void {
          parent::setUpBeforeClass();
        }

        #[\Override]
        public static function tearDownAfterClass(): void {
          parent::tearDownAfterClass();
        }
      }

      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
          $later = function (): void {
            parent::setUp();
          };
        }

        /** @psalm-capabilities read-props */
        #[\Override]
        public static function setUpBeforeClass(): void {
          $callable = parent::setUpBeforeClass(...);
        }

        /** @psalm-capabilities read-props */
        #[\Override]
        public static function tearDownAfterClass(): void {
          $later = static fn(): mixed => parent::tearDownAfterClass();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                      |
      | MissingParentCall | Missing call to parent::setUp()              |
      | MissingParentCall | Missing call to parent::setUpBeforeClass()   |
      | MissingParentCall | Missing call to parent::tearDownAfterClass() |
    And I see no other errors

  Scenario: Hooks that have no parent implementation to call are not reported
    Given I have the following code
      """
      abstract class AbstractBaseTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        abstract protected function setUp(): void;
      }

      final class AbstractParentTestCase extends AbstractBaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
        }
      }

      final class DirectTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
        }

        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }
      }

      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      final class InheritingTestCase extends BaseTestCase {
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: MissingParentCall can be suppressed on the method and on the class
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
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }
      }

      final class MethodSuppressedTestCase extends BaseTestCase {
        /**
         * @psalm-suppress MissingParentCall
         * @psalm-capabilities read-props
         */
        #[\Override]
        protected function tearDown(): void {
        }
      }

      /** @psalm-suppress MissingParentCall */
      final class ClassSuppressedTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: MissingParentCall can be suppressed on the trait
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
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }
      }

      /**
       * @psalm-suppress MissingParentCall
       * @psalm-immutable
       */
      trait NoParentTearDown {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }
      }

      final class MyTestCase extends BaseTestCase {
        use NoParentTearDown;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A call to the ancestor that declares the hook counts as the parent call
    Given I have the following code
      """
      abstract class GrandparentTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }

        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }
      }

      abstract class ParentTestCase extends GrandparentTestCase {
      }

      final class NamedAncestorTestCase extends ParentTestCase {
        #[\Override]
        protected function setUp(): void {
          GrandparentTestCase::setUp();
        }
      }

      final class InheritedParentTestCase extends ParentTestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      final class MissingTestCase extends ParentTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                            |
      | MissingParentCall | Missing call to parent::tearDown() |
    And I see no other errors

  Scenario: A trait method aliased to a hook without a call to the parent is reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      /** @psalm-immutable */
      trait Initializer {
        /** @psalm-capabilities read-props */
        protected function initialize(): void {
        }
      }

      final class MyTestCase extends BaseTestCase {
        use Initializer {
          initialize as setUp;
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                         |
      | MissingParentCall | Missing call to parent::setUp() |
    And I see no other errors

  Scenario: A trait method aliased to a hook that calls the parent is not reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      trait Initializer {
        protected function initialize(): void {
          parent::setUp();
        }
      }

      final class MyTestCase extends BaseTestCase {
        use Initializer {
          initialize as setUp;
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A call to self or static instead of the parent does not count
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }

        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }
      }

      final class SelfTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
          self::setUp();
        }
      }

      final class StaticTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
          static::tearDown();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                            |
      | MissingParentCall | Missing call to parent::setUp()    |
      | MissingParentCall | Missing call to parent::tearDown() |
    And I see no other errors

  Scenario: A call on an unknown class is left to UndefinedClass
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function setUp(): void {
          parent::setUp();
        }
      }

      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function setUp(): void {
          UnknownTestCase::setUp();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type           | Message                                              |
      | UndefinedClass | Class, interface or enum named NS\UnknownTestCase does not exist |
    And I see no other errors

  Scenario: A suppression on a trait from another file applies
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
    And I have the following code in "MyTrait.php"
      """
      <?php
      namespace NS;

      /**
       * @psalm-immutable
       * @psalm-suppress MissingParentCall
       */
      trait MyTrait {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }
      }

      final class MyTestCase extends BaseTestCase {
        use MyTrait;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A class suppression does not apply to a trait method from another file
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
    And I have the following code in "MyTrait.php"
      """
      <?php
      namespace NS;

      /** @psalm-immutable */
      trait MyTrait {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function tearDown(): void {
        }
      }
      """
    And I have the following code in "code.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function tearDown(): void {
          parent::tearDown();
        }
      }

      /** @psalm-suppress MissingParentCall */
      final class MyTestCase extends BaseTestCase {
        use MyTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message                              |
      | MissingParentCall    | Missing call to parent::tearDown()   |
      | UnusedPsalmSuppress  | This suppression is never used       |
    And I see no other errors

  Scenario: assertPreConditions and assertPostConditions without a call to the parent are reported
    Given I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        #[\Override]
        protected function assertPreConditions(): void {
          parent::assertPreConditions();
        }

        #[\Override]
        protected function assertPostConditions(): void {
          parent::assertPostConditions();
        }
      }

      final class MyTestCase extends BaseTestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function assertPreConditions(): void {
        }

        /** @psalm-capabilities read-props */
        #[\Override]
        protected function assertPostConditions(): void {
        }
      }

      final class DirectTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        #[\Override]
        protected function assertPreConditions(): void {
        }
      }

      final class CallingTestCase extends BaseTestCase {
        #[\Override]
        protected function assertPreConditions(): void {
          parent::assertPreConditions();
        }

        #[\Override]
        protected function assertPostConditions(): void {
          parent::assertPostConditions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                         |
      | MissingParentCall | Missing call to parent::assertPreConditions()  |
      | MissingParentCall | Missing call to parent::assertPostConditions() |
    And I see no other errors

  Scenario: Mocking an undefined method on a union of mocks is reported for each type lacking it
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function send(): bool;

        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      interface Notifier {
        /** @psalm-impure */
        public function send(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testMissingOnOneType(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->method('sendInvoice')->willReturn(true);
        }

        public function testMissingOnEveryType(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->method('sendInvoce')->willReturn(true);
        }

        public function testDefinedOnEveryType(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->method('send')->willReturn(true);
        }

        public function testExpects(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->expects($this->once())->method('sendInvoice')->willReturn(true);
        }

        public function testInlineUnion(bool $flag): void {
          ($flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class))->method('sendInvoice');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                        | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 23   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce()    | 28   |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoce()  | 28   |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 38   |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 42   |
    And I see no other errors

  Scenario: Mocking an undefined method on a union of stubs and mocks is reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      interface Notifier {
        /** @psalm-impure */
        public function send(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testStubAndMock(bool $flag): void {
          $double = $flag ? $this->createStub(Mailer::class) : $this->createMock(Notifier::class);
          $double->method('sendInvoice')->willReturn(true);
        }

        public function testStubs(bool $flag): void {
          $double = $flag ? $this->createStub(Mailer::class) : $this->createStub(Notifier::class);
          $double->method('send')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                        | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 20   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::send()          | 25   |
    And I see no other errors

  Scenario: Union members Psalm cannot check do not hide the checked ones
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      final class Configurable {
        /** @psalm-impure */
        public function method(string $name): bool { return true; }
      }

      final class MyTestCase extends TestCase {
        public function testOwnMethod(bool $flag): void {
          $double = $flag ? $this->createMock(Mailer::class) : new Configurable();
          $double->method('typo');
        }

        public function testNotADouble(bool $flag): void {
          $double = $flag ? $this->createMock(Mailer::class) : null;
          $double->method('typo');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                              | Line |
      | UndefinedMethod       | Trying to mock an undefined method NS\Mailer::typo() | 20   |
      | PossiblyNullReference | Cannot call method method on possibly null value     | 25   |
      | UndefinedMethod       | Trying to mock an undefined method NS\Mailer::typo() | 25   |
    And I see no other errors

  Scenario: Unknown @psalm tag does not hide a missing @dataProvider
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @psalm-foo
         * @dataProvider provide
         */
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               |
      | InvalidDocblock | Unrecognised annotation @psalm-foo                    |
      | UndefinedMethod | Provider method NS\MyTestCase::provide is not defined |
    And I see no other errors

  Scenario: Unknown @psalm tag does not hide @depends
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @psalm-foo
         * @dataProvider provide
         * @depends testOne
         */
        public function testSecond(string $foo, string $bar, string $baz): void {
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
      | InvalidDocblock | Unrecognised annotation @psalm-foo                                                                                                                       |
    And I see no other errors

  Scenario: Unknown @psalm tag does not hide @test
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @psalm-foo
         * @test
         */
        public function somethingElse(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type            | Message                            |
      | InvalidDocblock | Unrecognised annotation @psalm-foo |
    And I see no other errors

  Scenario: Unknown @psalm tag does not hide @before
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        private int $value;

        /**
         * @psalm-foo
         * @before
         */
        public function myInit(): void {
          $this->value = 1;
        }

        public function testSomething(): void {
          $this->assertSame(1, $this->value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                            |
      | InvalidDocblock | Unrecognised annotation @psalm-foo |
    And I see no other errors

  Scenario: Unknown @psalm tag does not hide an ignored docblock tag
    Given PHPUnit identifies as version "13.0-dev"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @psalm-foo
         * @group slow
         */
        public function testSlow(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 8    |
      | InvalidDocblock         | Unrecognised annotation @psalm-foo                               | 10   |
    And I see no other errors

  Scenario: Unknown @psalm tag does not hide a malformed annotation
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @psalm-foo
         * @dataProvider
         */
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                 | Line |
      | InvalidPhpUnitAnnotation | Annotation "@dataProvider" has no value | 8    |
      | InvalidDocblock          | Unrecognised annotation @psalm-foo      | 10   |
    And I see no other errors

  Scenario: Malformed annotation in the class docblock of a used trait is reported
    Given I have the following code
      """
      /**
       * @group
       */
      trait HelperTrait
      {
      }

      final class MyTestCase extends TestCase
      {
        use HelperTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                          | Line |
      | InvalidPhpUnitAnnotation | Annotation "@group" has no value | 6    |
    And I see no other errors

  Scenario: Only malformed annotations in the class docblock of a used trait are reported
    Given I have the following code
      """
      /**
       * @group slow
       */
      trait WellFormedTrait
      {
      }

      /**
       * @group
       */
      trait UnusedTrait
      {
      }

      /**
       * @covers
       */
      trait MalformedTrait
      {
      }

      final class MyTestCase extends TestCase
      {
        use WellFormedTrait, MalformedTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                           | Line |
      | InvalidPhpUnitAnnotation | Annotation "@covers" has no value | 20   |
    And I see no other errors

  Scenario: Malformed annotation in a trait shared by several test cases is reported once
    Given I have the following code
      """
      /**
       * @covers
       */
      trait HelperTrait
      {
      }

      final class FirstTest extends TestCase
      {
        use HelperTrait;
      }

      final class SecondTest extends TestCase
      {
        use HelperTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                           | Line |
      | InvalidPhpUnitAnnotation | Annotation "@covers" has no value | 6    |
    And I see no other errors

  Scenario: Only the class docblocks of the traits a test case uses directly are checked
    Given I have the following code
      """
      /**
       * @group
       */
      trait InnerTrait
      {
      }

      /**
       * @covers
       */
      trait OuterTrait
      {
        use InnerTrait;
      }

      final class MyTestCase extends TestCase
      {
        use OuterTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                           | Line |
      | InvalidPhpUnitAnnotation | Annotation "@covers" has no value | 13   |
    And I see no other errors

  Scenario: Malformed annotation in the class docblock of a used trait can be suppressed on the trait or on the test class
    Given I have the following code
      """
      /**
       * @psalm-suppress InvalidPhpUnitAnnotation
       * @group
       */
      trait SuppressedTrait
      {
      }

      /**
       * @covers
       */
      trait ReportedTrait
      {
      }

      /**
       * @uses
       */
      trait SuppressedByClassTrait
      {
      }

      final class FirstTest extends TestCase
      {
        use SuppressedTrait, ReportedTrait;
      }

      /**
       * @psalm-suppress InvalidPhpUnitAnnotation
       */
      final class SecondTest extends TestCase
      {
        use SuppressedByClassTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                           | Line |
      | InvalidPhpUnitAnnotation | Annotation "@covers" has no value | 14   |
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

  Scenario: Missing methods and functions in #[CoversMethod], #[UsesMethod], #[CoversFunction] and #[UsesFunction] are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\CoversFunction;
      use PHPUnit\Framework\Attributes\CoversMethod;
      use PHPUnit\Framework\Attributes\UsesFunction;
      use PHPUnit\Framework\Attributes\UsesMethod;

      /** @psalm-pure */
      final class Subject {
        /** @psalm-pure */
        public function run(): int {
          return 1;
        }
      }

      /** @psalm-pure */
      function helper(): int {
        return 1;
      }

      #[CoversMethod(Subject::class, 'nope')]
      #[UsesMethod(methodName: 'gone', className: Subject::class)]
      #[CoversFunction('NS\missing')]
      #[UsesFunction('\NS\absent')]
      #[CoversMethod(Missing::class, 'run')]
      final class MyTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                                  | Line |
      | UndefinedMethod   | #[CoversMethod] target NS\Subject::nope is not defined   | 23   |
      | UndefinedMethod   | #[UsesMethod] target NS\Subject::gone is not defined     | 24   |
      | UndefinedFunction | #[CoversFunction] target NS\missing is not defined       | 25   |
      | UndefinedFunction | #[UsesFunction] target NS\absent is not defined          | 26   |
      | UndefinedClass    | Class, interface or enum named NS\Missing does not exist | 27   |
    And I see no other errors

  Scenario: Existing targets of #[CoversMethod] and #[CoversFunction] are not reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\CoversFunction;
      use PHPUnit\Framework\Attributes\CoversMethod;

      /** @psalm-pure */
      abstract class Base {
        /** @psalm-pure */
        public function inherited(): int {
          return 1;
        }
      }

      /** @psalm-pure */
      trait Helper {
        /** @psalm-pure */
        public function fromTrait(): int {
          return 2;
        }
      }

      /** @psalm-pure */
      interface Contract {
        /** @psalm-pure */
        public function declared(): int;
      }

      /** @psalm-pure */
      final class Subject extends Base implements Contract {
        use Helper;

        /** @psalm-pure */
        #[\Override]
        public function declared(): int {
          return 3;
        }

        /** @psalm-pure */
        protected function hidden(): int {
          return 4;
        }

        /** @psalm-pure */
        public function MixedCase(): int {
          return 5;
        }
      }

      /** @psalm-pure */
      function helper(): int {
        return 1;
      }

      #[CoversMethod(Subject::class, 'inherited')]
      #[CoversMethod(Subject::class, 'fromTrait')]
      #[CoversMethod(Contract::class, 'declared')]
      #[CoversMethod(Subject::class, 'hidden')]
      #[CoversMethod(Subject::class, 'mixedcase')]
      #[CoversMethod(methodName: 'declared', className: Subject::class)]
      #[CoversFunction('NS\helper')]
      #[CoversFunction('\NS\helper')]
      final class MyTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Missing @covers and @uses targets are reported on the line of the tag
    Given I have the following code
      """
      /** @psalm-pure */
      final class Subject {
        /** @psalm-pure */
        public function run(): int {
          return 1;
        }
      }

      /** @psalm-pure */
      function helper(): int {
        return 1;
      }

      /**
       * @covers \NS\Typo
       * @uses \NS\Subject::nope
       * @covers ::totl
       * @covers Subject
       * @covers \NS\Subject::run Some description
       * @covers \NS\helper
       */
      final class MyTestCase extends TestCase {
        /**
         * @covers \NS\Gone::method
         * @uses \NS\Subject::run
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                      | Line |
      | UndefinedClass    | @covers target NS\Typo does not exist       | 19   |
      | UndefinedMethod   | @uses target NS\Subject::nope is not defined | 20   |
      | UndefinedFunction | @covers target ::totl is not defined         | 21   |
      | UndefinedClass    | @covers target Subject does not exist        | 22   |
      | UndefinedClass    | @covers target NS\Gone does not exist       | 28   |
    And I see no other errors

  Scenario: @coversDefaultClass and @usesDefaultClass are validated and used for targets starting with ::
    Given I have the following code
      """
      /** @psalm-pure */
      final class Subject {
        /** @psalm-pure */
        public function run(): int {
          return 1;
        }
      }

      /**
       * @coversDefaultClass \NS\Subject
       * @usesDefaultClass \NS\Missing
       */
      final class MyTestCase extends TestCase {
        /**
         * @covers ::run
         * @covers ::run()
         * @covers ::nope
         * @uses ::run
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }

      /**
       * @coversDefaultClass \NS\Typo
       */
      final class OtherTestCase extends TestCase {
        /**
         * @covers ::run
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                         | Line |
      | UndefinedClass  | @usesDefaultClass target NS\Missing does not exist | 15   |
      | UndefinedMethod | @covers target NS\Subject::nope is not defined     | 21   |
      | UndefinedClass  | @coversDefaultClass target NS\Typo does not exist  | 29   |
    And I see no other errors

  Scenario: Malformed default class annotations are reported instead of validated as targets
    Given I have the following code
      """
      /**
       * @coversDefaultClass(Subject)
       * @usesDefaultClass(Subject)
       */
      final class MyTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                                    | Line |
      | InvalidPhpUnitAnnotation | Annotation "@coversDefaultClass" must be followed by a space and a value | 6    |
      | InvalidPhpUnitAnnotation | Annotation "@usesDefaultClass" must be followed by a space and a value   | 7    |
    And I see no other errors

  Scenario: Docblock targets are ignored when PHPUnit attributes are present
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\CoversClass;
      use PHPUnit\Framework\Attributes\Test;

      /** @psalm-pure */
      final class Subject {
      }

      /**
       * @covers \NS\Typo
       */
      #[CoversClass(Subject::class)]
      final class MyTestCase extends TestCase {
        /**
         * @covers ::nope
         * @psalm-capabilities read-props
         */
        #[Test]
        public function something(): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Covers targets can be suppressed
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\CoversFunction;
      use PHPUnit\Framework\Attributes\CoversMethod;

      /** @psalm-pure */
      final class Subject {
      }

      /**
       * @psalm-suppress UndefinedClass
       * @covers \NS\Typo
       */
      final class MyTestCase extends TestCase {
        /**
         * @psalm-suppress UndefinedMethod
         * @covers \NS\Subject::nope
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }

      /**
       * @psalm-suppress UndefinedFunction
       */
      #[CoversFunction('NS\missing')]
      final class OtherTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Docblock covers targets are not marked as used
    Given I have the following code
      """
      /** @psalm-pure */
      final class Subject {
        /** @psalm-pure */
        public function run(): int {
          return 1;
        }
      }

      /**
       * @covers \NS\Subject::run
       */
      final class MyTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        public function testSomething(): void {}
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type        | Message                      |
      | UnusedClass | Class NS\Subject is never used |
    And I see no other errors

  Scenario: Docblock covers targets in another file are found when only the test file is analysed
    Given I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      /**
       * @coversDefaultClass \NS\External
       */
      final class MyTestCase extends TestCase {
        /**
         * @covers ::run
         * @covers \NS\External::run
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }
      """
    And I have the following code in "ext.php"
      """
      <?php
      namespace NS;

      /** @psalm-pure */
      final class External {
        /** @psalm-pure */
        public function run(): int {
          return 1;
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

  Scenario: PHPUnit 12 reports ignored @covers tags instead of validating their targets
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      /**
       * @covers \NS\Missing
       */
      final class MyTestCase extends TestCase {
        /**
         * @covers ::nope
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                    | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @covers docblock tag, use #[CoversClass], #[CoversMethod] or #[CoversFunction] instead | 6    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @covers docblock tag, use #[CoversClass], #[CoversMethod] or #[CoversFunction] instead | 10   |
    And I see no other errors

  Scenario: Default class tags on a method are ignored
    Given I have the following code
      """
      /** @psalm-pure */
      final class Subject {
        /** @psalm-pure */
        public function run(): int {
          return 1;
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @coversDefaultClass \NS\Missing
         * @covers ::run
         * @psalm-capabilities read-props
         */
        public function testFirst(): void {}

        /**
         * @covers ::run
         * @psalm-capabilities read-props
         */
        public function testSecond(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                           | Line |
      | UndefinedFunction | @covers target ::run is not defined | 16   |
      | UndefinedFunction | @covers target ::run is not defined | 22   |
    And I see no other errors

  Scenario: Docblocks of traits and parent classes are read with the default class of the test case that runs them
    Given I have the following code
      """
      /** @psalm-pure */
      final class Subject {
        /** @psalm-pure */
        public function run(): int {
          return 1;
        }
      }

      /** @psalm-pure */
      final class Other {
      }

      /**
       * @coversDefaultClass \NS\Subject
       * @psalm-pure
       */
      trait SubjectDefault {
      }

      /**
       * @coversDefaultClass \NS\Missing
       * @psalm-pure
       */
      trait MissingDefault {
      }

      final class TraitTestCase extends TestCase {
        use SubjectDefault;

        /**
         * @covers ::run
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }

      /**
       * @coversDefaultClass \NS\Subject
       */
      final class OverridingTestCase extends TestCase {
        use MissingDefault;

        /**
         * @covers ::run
         * @psalm-capabilities read-props
         */
        public function testSomething(): void {}
      }

      abstract class BaseTestCase extends TestCase {
        /**
         * @covers ::run
         * @psalm-capabilities read-props
         */
        public function testInherited(): void {}
      }

      /**
       * @coversDefaultClass \NS\Subject
       */
      final class SubjectTestCase extends BaseTestCase {
      }

      /**
       * @coversDefaultClass \NS\Other
       */
      final class OtherTestCase extends BaseTestCase {
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                  | Line |
      | UndefinedMethod | @covers target NS\Other::run is not defined | 56   |
    And I see no other errors

  Scenario: Functions in @covers can be fully qualified
    Given I have the following code
      """
      /** @psalm-pure */
      function helper(): int {
        return 1;
      }

      /**
       * @covers ::\NS\helper
       * @covers \NS\helper
       */
      final class MyTestCase extends TestCase {
        /** @psalm-capabilities read-props */
        public function testSomething(): void {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Suppressions of the class that declares an inherited test method apply to its covers targets
    Given I have the following code
      """
      /**
       * @psalm-suppress UndefinedFunction
       */
      abstract class BaseTestCase extends TestCase {
        /**
         * @covers ::missing
         * @psalm-capabilities read-props
         */
        public function testInherited(): void {}
      }

      final class ConcreteTestCase extends BaseTestCase {
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Dataset of a #[DataProviderClosure] that does not match the parameters is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [['not an int']])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'not an int' provided by #[DataProviderClosure]:(list{list{'not an int'}}) | 8 |
    And I see no other errors

  Scenario: Dataset of a #[DataProviderClosure] that matches the parameters is allowed
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [[1], 'named' => [2]])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Dataset of a #[DataProviderClosure] declared as a closure with a body is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static function (): iterable {
          return [['not an int']];
        })]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'not an int' provided by #[DataProviderClosure]:(list{list{'not an int'}}) | 8 |
    And I see no other errors

  Scenario: Missing values in a dataset of a #[DataProviderClosure] are reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [[1]])]
        public function testSum(int $a, int $b): void {
          $this->assertSame($a + $b, $b + $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSum - expecting at least 2, but saw 1 provided by #[DataProviderClosure]:(list{list{1}}) | 8 |
    And I see no other errors

  Scenario: String-keyed datasets of a #[DataProviderClosure] are matched to parameters by name
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [['value' => 1, 'typo' => 2]])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message | Line |
      | InvalidNamedArgument | Parameter $typo does not exist on NS\MyTestCase::testDouble, provided by #[DataProviderClosure]:(list{array{typo: 2, value: 1}}) | 8 |
    And I see no other errors

  Scenario: String-keyed datasets of a #[DataProviderClosure] are reported when #[Depends] passes a value
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[DataProviderClosure(static fn (): iterable => [['foo' => 'foo']])]
        #[Depends('testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message | Line |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset #[DataProviderClosure]:(list{array{foo: 'foo'}}) | 14 |
    And I see no other errors

  Scenario: A #[DataProviderClosure] that does not return an iterable is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): int => 1)]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message | Line |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, 1 provided | 8 |
    And I see no other errors

  Scenario: Every #[DataProviderClosure] and #[DataProvider] of a test is checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['not an int']];
        }

        #[DataProviderClosure(static fn (): iterable => [[1]])]
        #[DataProviderClosure(static fn (): iterable => [['also not an int']])]
        #[DataProvider('provide')]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string}>) | 19 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'also not an int' provided by #[DataProviderClosure]:(list{list{'also not an int'}}) | 18 |
    And I see no other errors

  Scenario: Datasets of a #[DataProviderClosure] in a test of a trait are checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      trait DoubleTests {
        #[DataProviderClosure(static fn (): iterable => [['not an int']])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }

      final class MyTestCase extends TestCase {
        use DoubleTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'not an int' provided by #[DataProviderClosure]:(list{list{'not an int'}}) | 8 |
    And I see no other errors

  Scenario: A #[DataProviderClosure] argument that is not a literal closure is not checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['not an int']];
        }

        #[DataProviderClosure(self::provide(...))]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An empty #[DataProviderClosure] does not stop the other providers from being checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['not an int']];
        }

        #[DataProviderClosure(static fn (): iterable => [])]
        #[DataProviderClosure(static fn (): iterable => [[1]])]
        #[DataProvider('provide')]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string}>) | 19 |
    And I see no other errors

  Scenario: A positional entry after a named one in a #[DataProviderClosure] dataset is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [['b' => 2, 0 => 1]])]
        public function testFoo(int $a, int $b): void {
          $this->assertSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by #[DataProviderClosure] |
    And I see no other errors

  Scenario: A data provider object whose @implements differs from its getIterator() is not narrowed to @implements
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array<array{mixed}>>
       */
      final class Datasets implements \IteratorAggregate {
        /**
         * @return \Traversable<int, array<mixed>>
         * @psalm-pure
         */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator([[1], ['a'], [null]]);
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          if (is_string($value)) {
            $this->assertNotEmpty($value);
          }
          count($value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                              | Message |
      | LessSpecificImplementedReturnType | The inherited return type 'Traversable[impure]<int, array<array-key, list{mixed}>>' for IteratorAggregate::getIterator is more specific than the implemented return type for NS\\Datasets::getiterator 'Traversable<int, array<array-key, mixed>>' |
      | MixedArgument                     | Argument 1 of count cannot be mixed, expecting Countable\|array<array-key, mixed> |
    And I see no other errors

  Scenario: A data provider object with a precise getIterator() narrows to the type it yields
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array<mixed>>
       */
      final class Datasets implements \IteratorAggregate {
        /**
         * @return \Traversable<int, array{int}>
         * @psalm-pure
         */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator([[1]]);
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A data provider object without a getIterator() docblock narrows to its @implements types
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array{int}>
       */
      final class Datasets implements \IteratorAggregate {
        /** @psalm-pure */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator([[1]]);
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A generic data provider object narrows to the type arguments it is returned with
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @template T of array<mixed>
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array<mixed>>
       */
      final class Datasets implements \IteratorAggregate {
        /**
         * @param list<T> $datasets
         * @psalm-pure
         */
        public function __construct(private array $datasets) {}

        /**
         * @return \Traversable<int, T>
         * @psalm-mutation-free
         */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator($this->datasets);
        }
      }

      final class MyTestCase extends TestCase {
        /**
         * @return Datasets<array{int}>
         * @psalm-pure
         */
        public static function provide(): Datasets {
          return new Datasets([[1]]);
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A data provider Iterator narrows to the type its current() returns
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-mutable
       * @implements \Iterator<int, array<mixed>>
       */
      final class Datasets implements \Iterator {
        /**
         * @return array{int}
         * @psalm-pure
         */
        #[\Override]
        public function current(): array {
          return [1];
        }

        /** @psalm-pure */
        #[\Override]
        public function key(): int {
          return 0;
        }

        /** @psalm-impure */
        #[\Override]
        public function next(): void {}

        /** @psalm-impure */
        #[\Override]
        public function rewind(): void {}

        /** @psalm-pure */
        #[\Override]
        public function valid(): bool {
          return false;
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A data provider object is validated by what getIterator() yields
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array{string}>
       */
      final class Datasets implements \IteratorAggregate {
        /**
         * @return \Traversable<int, array{int}>
         * @psalm-pure
         */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator([[1]]);
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(int $value): void {
          $this->assertSame(1, $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                          | Message |
      | ImplementedReturnTypeMismatch | The inherited return type 'Traversable[impure]<int, list{string}>' for IteratorAggregate::getIterator is different to the implemented return type for NS\\Datasets::getiterator 'Traversable<int, list{int}>' |
    And I see no other errors

  Scenario: A data provider object that wraps another one is read through its getIterator()
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<mixed, mixed>
       */
      final class Inner implements \IteratorAggregate {
        /**
         * @return \Traversable<int, array{int}>
         * @psalm-pure
         */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator([[1]]);
        }
      }

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<mixed, mixed>
       */
      final class Outer implements \IteratorAggregate {
        /** @psalm-pure */
        #[\Override]
        public function getIterator(): Inner {
          return new Inner();
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Outer {
          return new Outer();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A data provider object whose getIterator() returns itself is read without looping
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<mixed, mixed>
       */
      final class Datasets implements \IteratorAggregate {
        /** @psalm-mutation-free */
        #[\Override]
        public function getIterator(): self {
          return $this;
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Datasets {
          return new Datasets();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | MixedReturnStatement | Providers must return iterable<array-key, array<array-key, mixed>>, possibly different NS\\Datasets provided |
    And I see no other errors

  Scenario: A data provider object with a native getIterator() return type is read like foreach reads it
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array{int}>
       */
      final class Generated implements \IteratorAggregate {
        /** @psalm-pure */
        #[\Override]
        public function getIterator(): \Generator {
          yield [1];
        }
      }

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array{int}>
       */
      final class Wrapped implements \IteratorAggregate {
        /** @psalm-pure */
        #[\Override]
        public function getIterator(): \ArrayIterator {
          return new \ArrayIterator([[1]]);
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function generated(): Generated {
          return new Generated();
        }

        /** @psalm-pure */
        public static function wrapped(): Wrapped {
          return new Wrapped();
        }

        #[DataProvider('generated')]
        public function testGenerated(mixed $value): void {
          /** @psalm-check-type-exact $value = mixed */
          $this->assertTrue(true);
        }

        #[DataProvider('wrapped')]
        public function testWrapped(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | MixedReturnStatement | Providers must return iterable<array-key, array<array-key, mixed>>, possibly different NS\\Generated provided |
    And I see no other errors

  Scenario: A data provider typed as an iterator interface narrows to its type arguments
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return \IteratorAggregate<int, array{int}>
         * @psalm-pure
         */
        public static function aggregate(): \IteratorAggregate {
          return new \ArrayObject([[1]]);
        }

        /**
         * @return \Iterator<int, array{string}>
         * @psalm-pure
         */
        public static function iterator(): \Iterator {
          return new \ArrayIterator([['a']]);
        }

        #[DataProvider('aggregate')]
        public function testAggregate(mixed $value): void {
          /** @psalm-check-type-exact $value = int */
          $this->assertTrue(true);
        }

        #[DataProvider('iterator')]
        public function testIterator(mixed $value): void {
          /** @psalm-check-type-exact $value = string */
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A data provider object that wraps an iterator interface is read like foreach reads it
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /**
       * @psalm-immutable
       * @extends \IteratorAggregate<int, array{array{mixed}}>
       */
      interface Inner extends \IteratorAggregate {
        /**
         * @return \Traversable<int, array<mixed>>
         * @psalm-pure
         */
        #[\Override]
        public function getIterator(): \Traversable;
      }

      /** @psalm-immutable */
      final class InnerImplementation implements Inner {
        /**
         * @return \Traversable<int, array<mixed>>
         * @psalm-pure
         */
        #[\Override]
        public function getIterator(): \Traversable {
          return new \ArrayIterator([[1], ['a']]);
        }
      }

      /**
       * @psalm-immutable
       * @implements \IteratorAggregate<int, array<mixed>>
       */
      final class Outer implements \IteratorAggregate {
        /** @psalm-pure */
        #[\Override]
        public function getIterator(): Inner {
          return new InnerImplementation();
        }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        public static function provide(): Outer {
          return new Outer();
        }

        #[DataProvider('provide')]
        public function testSomething(mixed $value): void {
          if (is_string($value)) {
            $this->assertNotEmpty($value);
          }
          count($value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                              | Message |
      | LessSpecificImplementedReturnType | The inherited return type 'Traversable[impure]<int, list{list{mixed}}>' for IteratorAggregate::getIterator is more specific than the implemented return type for NS\\Inner::getiterator 'Traversable<int, array<array-key, mixed>>' |
      | LessSpecificImplementedReturnType | The inherited return type 'Traversable[impure]<int, list{list{mixed}}>' for IteratorAggregate::getIterator is more specific than the implemented return type for NS\\InnerImplementation::getiterator 'Traversable<int, array<array-key, mixed>>' |
      | MixedArgument                     | Argument 1 of count cannot be mixed, expecting Countable\|array<array-key, mixed> |
    And I see no other errors
