Feature: Coverage targets

  Background:
    Given PHPUnit identifies as version "11.5.0"

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
    And the config uses the autoloader "autoload.php"
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
