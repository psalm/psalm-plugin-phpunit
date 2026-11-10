Feature: Dead code

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

  Scenario: Methods with a hook attribute are used by PHPUnit
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\After;
      use PHPUnit\Framework\Attributes\AfterClass;
      use PHPUnit\Framework\Attributes\Before;
      use PHPUnit\Framework\Attributes\BeforeClass;
      use PHPUnit\Framework\Attributes\PostCondition;
      use PHPUnit\Framework\Attributes\PreCondition;

      final class MyTestCase extends TestCase {
        #[BeforeClass]
        public static function prepareClass(): void {
          self::assertTrue(true);
        }

        #[AfterClass]
        public static function cleanUpClass(): void {
          self::assertTrue(true);
        }

        #[Before]
        public function prepare(): void {
          $this->assertTrue(true);
        }

        #[After]
        protected function cleanUp(): void {
          $this->assertTrue(true);
        }

        #[PreCondition]
        public function checkBefore(): void {
          $this->assertTrue(true);
        }

        #[PostCondition]
        public function checkAfter(): void {
          $this->assertTrue(true);
        }

        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Methods with a hook docblock tag are used by PHPUnit 11
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @beforeClass
         */
        public static function prepareClass(): void {
          self::assertTrue(true);
        }

        /**
         * @afterClass
         */
        public static function cleanUpClass(): void {
          self::assertTrue(true);
        }

        /**
         * @before
         */
        public function prepare(): void {
          $this->assertTrue(true);
        }

        /**
         * @after
         */
        protected function cleanUp(): void {
          $this->assertTrue(true);
        }

        /**
         * @preCondition
         */
        public function checkBefore(): void {
          $this->assertTrue(true);
        }

        /**
         * @postCondition
         */
        public function checkAfter(): void {
          $this->assertTrue(true);
        }

        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: A method with a hook docblock tag is unused on PHPUnit 12
    Given PHPUnit identifies as version "12.5.0"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @before
         */
        public function prepare(): void {
          $this->assertTrue(true);
        }

        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                    | Message                                                            |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @before docblock tag, use #[Before] instead |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::prepare             |
    And I see no other errors

  Scenario: A docblock hook tag is ignored on a method that has a PHPUnit attribute
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Group;

      final class MyTestCase extends TestCase {
        /**
         * @before
         */
        #[Group('hooks')]
        public function prepare(): void {
          $this->assertTrue(true);
        }

        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::prepare |
    And I see no other errors

  Scenario: A hook attribute of a method of a trait used by the test case is used by PHPUnit
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Before;
      use PHPUnit\Framework\Attributes\BeforeClass;

      trait Prepares {
        #[BeforeClass]
        public static function prepareClass(): void {
          self::assertTrue(true);
        }

        #[Before]
        public function prepare(): void {
          $this->assertTrue(true);
        }
      }

      final class MyTestCase extends TestCase {
        use Prepares;

        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: A non-static #[BeforeClass] method is not run by PHPUnit
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\BeforeClass;

      final class MyTestCase extends TestCase {
        #[BeforeClass]
        public function prepareClass(): void {
          $this->assertTrue(true);
        }

        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                     |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::prepareClass |
    And I see no other errors
