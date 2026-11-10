Feature: Docblock annotation parsing

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
