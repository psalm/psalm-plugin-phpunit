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
    And I see no other errors

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
    And I see no other errors

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
          $this->assertEquals(1, $int);
        }
      }
    """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                               |
      | UndefinedMethod | Provider method NS\MyTestCase::provide is not defined |
    And I see no other errors

  Scenario: Invalid iterable data provider is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<int,int> */
        public function provide() {
          yield 1;
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                                                                           |
      | InvalidReturnType | Providers must return iterable<int\|string, array<array-key, mixed>>, iterable<int, int> provided |
    And I see no other errors

  Scenario: Valid iterable data provider is allowed
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<int,array<int,int>> */
        public function provide() {
          yield [1];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid generator data provider is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return \Generator<int,int,mixed,void> */
        public function provide() {
          yield 1;
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                                                                                         |
      | InvalidReturnType | Providers must return iterable<int\|string, array<array-key, mixed>>, Generator<int, int, mixed, void> provided |
    And I see no other errors

  Scenario: Valid generator data provider is allowed
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return \Generator<int,array<int,int>,mixed,void> */
        public function provide() {
          yield [1];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid array data provider is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return array<int,int> */
        public function provide() {
          return [1 => 1];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message                                                                                                           |
      | InvalidReturnType | Providers must return iterable<int\|string, array<array-key, mixed>>, possibly different array<int, int> provided |
    And I see no other errors

  Scenario: Valid array data provider is allowed
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return array<string, array<int,int>> */
        public function provide() {
          return [
            "data set name" => [1],
          ];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Valid object data provider is allowed
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return \ArrayObject<string,array<int,int>> */
        public function provide() {
          return new \ArrayObject([
            "data set name" => [1],
          ]);
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Invalid dataset shape is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{string}> */
        public function provide() {
          yield "data set name" => ["str"];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable<string, array{0:string}>) |
    And I see no other errors

  Scenario: Invalid dataset array is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array<int, string|int>> */
        public function provide() {
          yield "data set name" => ["str"];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                                                              |
      | PossiblyInvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string\|int provided by NS\MyTestCase::provide():(iterable<string, array<int, string\|int>>) |
    And I see no other errors

  Scenario: Shape dataset with missing params is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{int}> */
        public function provide() {
          yield "data set name" => [1];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int, int $i) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                          |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - expecting 2 but saw 1 provided by NS\MyTestCase::provide():(iterable<string, array{0:int}>) |
    And I see no other errors

  Scenario: Referenced providers are not marked as unused
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{int}> */
        public function provide() {
          yield "data set name" => [1];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unreferenced providers are marked as unused
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{int}> */
        public function provide() {
          yield "data set name" => [1];
        }
        /**
         * @return void
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                   |
      | PossiblyUnusedMethod | Cannot find public calls to method NS\MyTestCase::provide |
    And I see no other errors

  Scenario: Test method are never marked as unused
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /**
         * @return void
         */
        public function testSomething(int $int) {
          $this->assertEquals(1, $int);
        }
        /**
         * @return void
         * @test
         */
        public function somethingElse(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unreferenced non-test methods are marked as unused
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /**
         * @return void
         */
        public function somethingElse(int $int) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                         |
      | PossiblyUnusedMethod | Cannot find public calls to method NS\MyTestCase::somethingElse |
    And I see no other errors

  Scenario: Unreferenced TestCase descendants are never marked as unused
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unreferenced non-test classes are marked as unused
    Given I have the following code
      """
      class UtilityClass
      {
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type        | Message                             |
      | UnusedClass | Class NS\UtilityClass is never used |
    And I see no other errors
