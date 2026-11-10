Feature: Data providers

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

  Scenario: The data provider of a private test-named method is not checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase
      {
        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function ints(): array {
          return [[1]];
        }

        #[DataProvider('ints')]
        private function testHelper(string $s): void {
          $this->assertSame('a', $s);
        }

        public function testUses(): void {
          $this->testHelper('a');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: The data provider of a protected method marked with #[Test] is not checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Test;

      final class MyTestCase extends TestCase
      {
        #[Test]
        #[DataProvider('missing')]
        protected function helper(string $s): void {
          $this->assertSame('a', $s);
        }

        public function testUses(): void {
          $this->helper('a');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: The provider of an inherited protected test-named method is not checked against the child's provider
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      abstract class BaseTestCase extends TestCase
      {
        /**
         * @return iterable<int, array<int, int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[DataProvider('provide')]
        protected function testHelper(int $int): void {
          $this->assertSame(1, $int);
        }

        public function testUses(): void {
          $this->testHelper(1);
        }
      }

      final class MyTestCase extends BaseTestCase
      {
        /**
         * @return iterable<int, array<int, int>>
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

  Scenario: The data provider of a trait test method imported as protected is not checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      trait HelperTrait
      {
        #[DataProvider('missing')]
        public function testHelper(string $s): void {
          $this->assertSame('a', $s);
        }
      }

      final class MyTestCase extends TestCase
      {
        use HelperTrait {
          testHelper as protected;
        }

        public function testUses(): void {
          $this->testHelper('a');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A trait test method imported as public by an abstract parent is checked in a child
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      trait HelperTrait
      {
        #[DataProvider('provide')]
        protected function testHelper(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      abstract class BaseTestCase extends TestCase
      {
        use HelperTrait {
          testHelper as public;
        }

        /**
         * @return iterable<int, array<int, int>>
         * @psalm-pure
         */
        abstract public function provide();
      }

      final class MyTestCase extends BaseTestCase
      {
        /**
         * @return iterable<int, array<int, int>>
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

  Scenario: A public test of the class replaces a trait method imported as protected
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      trait HelperTrait
      {
        public function testSomething(): void {
          $this->assertSame(1, 1);
        }
      }

      final class MyTestCase extends TestCase
      {
        use HelperTrait {
          testSomething as protected;
        }

        #[DataProvider('missing')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               |
      | UndefinedMethod | Provider method NS\MyTestCase::missing is not defined |
    And I see no other errors

  Scenario: An unused private test-named method is not marked as used by PHPUnit
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        private function testHelper(): void {
          $this->assertSame(1, 1);
        }

        public function testSomething(): void {
          $this->assertSame(1, 1);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type         | Message |
      | UnusedMethod | Cannot find any calls to private method NS\MyTestCase::testHelper |
    And I see no other errors
