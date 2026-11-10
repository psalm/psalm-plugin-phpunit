Feature: External data providers

  Background:
    Given PHPUnit identifies as version "11.5.0"

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
    And the config uses the autoloader "autoload.php"
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
    And the config uses the autoloader "autoload.php"
    When I run Psalm on "test.php"
    Then I see these errors
      | Type                 | Message                                                                                                                                      |
      | ArgumentTypeCoercion | Argument 1 of PHPUnit\Framework\Attributes\DataProviderExternal::__construct expects class-string, but parent type 'NS\\\\External' provided |
    And I see no other errors
