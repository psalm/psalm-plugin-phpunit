Feature: MissingConstructor in stateful test cases

  Background:
    Given PHPUnit identifies as version "11.5.0"

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

  Scenario: A trait providing setUp produces no MissingConstructor
    Given I have the following code
      """
      trait Init {
        private int $x;

        protected function setUp(): void {
          $this->x = 1;
        }
      }

      final class MyTestCase extends TestCase {
        use Init;

        public function testSomething(): void {
          $this->assertSame(1, $this->x);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A trait providing a #[Before] method produces no MissingConstructor
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Before;

      trait Init {
        private int $x;

        #[Before]
        protected function init(): void {
          $this->x = 1;
        }
      }

      final class MyTestCase extends TestCase {
        use Init;

        public function testSomething(): void {
          $this->assertSame(1, $this->x);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A trait used by a trait providing setUp produces no MissingConstructor
    Given I have the following code
      """
      trait Init {
        private int $x;

        protected function setUp(): void {
          $this->x = 1;
        }
      }

      trait Wrapper {
        use Init;
      }

      final class MyTestCase extends TestCase {
        use Wrapper;

        public function testSomething(): void {
          $this->assertSame(1, $this->x);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A trait method aliased as setUp produces no MissingConstructor
    Given I have the following code
      """
      trait Init {
        private int $x;

        protected function init(): void {
          $this->x = 1;
        }
      }

      final class MyTestCase extends TestCase {
        use Init {
          init as protected setUp;
        }

        public function testSomething(): void {
          $this->assertSame(1, $this->x);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Descendant of a test case whose trait provides setUp produces no MissingConstructor
    Given I have the following code
      """
      trait Init {
        protected int $x;

        protected function setUp(): void {
          $this->x = 1;
        }
      }

      abstract class BaseTestCase extends TestCase {
        use Init;
      }

      final class MyTestCase extends BaseTestCase {
        public function testSomething(): void {
          $this->assertSame(1, $this->x);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A trait without initializers still produces MissingConstructor
    Given I have the following code
      """
      trait State {
        private int $x;
      }

      final class MyTestCase extends TestCase {
        use State;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type               | Message |
      | MissingConstructor | NS\MyTestCase has an uninitialized property NS\State::$x, but no constructor |
    And I see no other errors

  Scenario: @before next to a PHPUnit attribute is not an initializer
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\Group;

      final class MyTestCase extends TestCase
      {
        private int $cents;

        /**
         * @before
         */
        #[Group('money')]
        public function initCents(): void {
          $this->cents = 100;
        }

        public function testCents(): void {
          $this->assertSame(100, $this->cents);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type               | Message                                                                              |
      | MissingConstructor | NS\MyTestCase has an uninitialized property NS\MyTestCase::$cents, but no constructor |
    And I see no other errors
