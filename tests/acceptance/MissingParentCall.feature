Feature: Missing parent calls

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
