Feature: Dead code

  Background:
    Given PHPUnit identifies as version "11.5.0"

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

  Scenario: Providers named only by a docblock that PHPUnit ignores are marked as unused
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Group;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<string, array{int}>
         * @psalm-pure
         */
        public static function provideCents(): iterable {
          yield 'one euro' => [100];
        }

        /**
         * @dataProvider provideCents
         */
        #[Group('money')]
        public function testCents(int $cents = 100): void {
          $this->assertSame(100, $cents);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                     |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::provideCents |
    And I see no other errors

  Scenario: @test next to a PHPUnit attribute does not make a method a test
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Group;

      final class MyTestCase extends TestCase
      {
        /**
         * @test
         */
        #[Group('money')]
        public function centsAreCounted(): void {
          $this->assertSame(100, 50 + 50);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                        |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::centsAreCounted |
    And I see no other errors
