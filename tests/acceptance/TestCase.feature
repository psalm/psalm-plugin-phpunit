Feature: TestCase
  In order to have typed TestCases
  As a Psalm user
  I need Psalm to typecheck my test cases

  Background:
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm>
        <projectFiles>
          <directory name="."/>
          <ignoreFiles> <directory name="../../vendor"/> </ignoreFiles>
        </projectFiles>
        <plugins>
          <pluginClass class="Psalm\PhpUnitPlugin\Plugin"/>
        </plugins>
      </psalm>
      """
    And I have the following code preamble
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      """

  Scenario: TestCase::expectException() rejects non-throwables
    Given I have Psalm newer than "3.0.12" (because of "missing functionality")
    Given I have the following code
      """
      class MyTestCase extends TestCase 
      {
        /** @return void */
        public function testSomething() {
          $this->expectException(MyTestCase::class);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                  |
      | InvalidArgument | Argument 1 of PHPUnit\Framework\TestCase::expectException expects class-string<Throwable>, NS\MyTestCase::class provided |

  Scenario: TestCase::expectException() accepts throwables
    Given I have the following code
      """
      class MyTestCase extends TestCase 
      {
        /** @return void */
        public function testSomething() {
          $this->expectException(\InvalidArgumentException::class);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Stateful test case with setUp produces no MissingConstructor
    Given I have the following code
      """
      use Prophecy\Prophecy\ObjectProphecy;

      interface I { public function work(): int; }

      class MyTestCase extends TestCase
      {
        /** @var ObjectProphecy<I> */
        private $i;

        /** @return void */
        public function setUp() {
          $this->i = $this->prophesize(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->work()->willReturn(1);;
          $i = $this->i->reveal();
          $this->assertEquals(1, $i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Stateful test case with @before produces no MissingConstructor
    Given I have the following code
      """
      use Prophecy\Prophecy\ObjectProphecy;

      interface I { public function work(): int; }

      class MyTestCase extends TestCase
      {
        /** @var ObjectProphecy<I> */
        private $i;

        /**
         * @before
         * @return void
         */
        public function myInit() {
          $this->i = $this->prophesize(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->work()->willReturn(1);;
          $i = $this->i->reveal();
          $this->assertEquals(1, $i->work());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Stateful test case without @before or setUp produces MissingConstructor
    Given I have the following code
      """
      use Prophecy\Prophecy\ObjectProphecy;

      interface I { public function work(): int; }

      class MyTestCase extends TestCase 
      {
        /** @var ObjectProphecy<I> */
        private $i;

        /** @return void */
        public function myInit() {
          $this->i = $this->prophesize(I::class);
        }

        /** @return void */
        public function testSomething() {
          $this->i->work()->willReturn(1);;
          $i = $this->i->reveal();
          $this->assertEquals(1, $i->work());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type               | Message                                                                  |
      | MissingConstructor | NS\MyTestCase has an uninitialized variable $this->i, but no constructor | 

  Scenario: Missing data provider is reported
    Given I have the following code
    """
      class MyTestCase extends TestCase
      {
        /**
         * @param mixed $int
         * @return void
         * @psalm-suppress UnusedMethod
         * @dataProvider provide
         */
        public function testSomething($int) {
          $this->assertIsInt($int);
        }
      }
      new MyTestCase;
    """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               |
      | UndefinedMethod | Provider method NS\MyTestCase::provide is not defined |
    And I see no other errors
