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
      | InvalidArgument | Argument 1 of NS\MyTestCase::expectexception expects class-string<Throwable>, NS\MyTestCase::class provided |
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
      | InvalidReturnType | Providers must return iterable<array-key, array%>, iterable<int, int> provided |
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
      | Type              | Message                                                                                      |
      | InvalidReturnType | Providers must return iterable<array-key, array%>, Generator<int, int, mixed, void> provided |
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
      | Type              | Message                                                                                        |
      | InvalidReturnType | Providers must return iterable<array-key, array%>, array<int, int> provided |
    And I see no other errors

  Scenario: Underspecified array data provider is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return array */
        public function provide() {
          return [1 => [1]];
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
      | Type              | Message                                                                                                                   |
      | InvalidReturnType | Providers must return iterable<int\|string, array<array-key, mixed>>, possibly different array<array-key, mixed> provided |
    And I see no other errors

  Scenario: Underspecified iterable data provider is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable */
        public function provide() {
          return [1 => [1]];
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
      | Type              | Message                                                                                                                  |
      | InvalidReturnType | Providers must return iterable<int\|string, array<array-key, mixed>>, possibly different iterable<mixed, mixed> provided |
    And I see no other errors

  Scenario: Underspecified generator data provider is reported
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return \Generator */
        public function provide() {
          yield 1 => [1];
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
      | Type              | Message                                                                                                     |
      | InvalidReturnType | Providers must return iterable<int\|string, array<array-key, mixed>>, possibly different Generator provided |
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
      | Type            | Message                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable<string, array%>) |
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
      | Type                    | Message                                                                                                                             |
      | PossiblyInvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string\|int provided by NS\MyTestCase::provide():(iterable<string, array%>) |
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
      | Type            | Message                                                                                                                                         |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<string, %>) |
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
      | Type                 | Message                                                |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::provide |
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
      | Type                 | Message                                                      |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\MyTestCase::somethingElse |
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

  Scenario: Provider returning optional offsets is fine when test method has defaults for those params (specified as constants)
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @var string */
        const S = "s";
        /** @return iterable<string,array{0:int,1?:string}> */
        public function provide() {
          yield "data set name" => rand(0,1) ? [1] : [1, "ss"];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int, string $_str = self::S) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider omitting offsets is fine when test method has defaults for those params (specified as constants)
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @var string */
        const S = "s";
        /** @return iterable<string,array{0:int}> */
        public function provide() {
          yield "data set name" => rand(0,1) ? [1] : [1, "ss"];
        }
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $int, string $_str = self::S) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider returning possibly undefined offset is fine when test method has default for that param
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:int}> */
        public function provide() {
          yield "data set name" => rand(0,1) ? [1] : [];
        }
        /**
         * @return void
         * @dataProvider provide
         */
       public function testSomething(int $int = 2) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider returning possibly undefined offset with mismatching type is reported even when test method has default for that param
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:string}> */
        public function provide() {
          yield "data set name" => rand(0,1) ? ["1"] : [];
        }
        /**
         * @return void
         * @dataProvider provide
         */
       public function testSomething(int $int = 2) {
          $this->assertEquals(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable<string, array%>) |
    And I see no other errors

  Scenario: Provider returning possibly undefined offset is marked when test method has no default for that param
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:int}> */
        public function provide() {
          yield "data set name" => rand(0,1) ? [1] : [];
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
      | Type              | Message                                                                                                                                                     |
      | InvalidArgument   | Argument 1 of NS\MyTestCase::testSomething has no default value, but possibly undefined int provided by NS\MyTestCase::provide():(iterable<string, array%>) |
    And I see no other errors

  Scenario: Stateful grandchild test case with setUp produces no MissingConstructor
    Given I have the following code
      """
      use Prophecy\Prophecy\ObjectProphecy;

      class BaseTestCase extends TestCase {}

      interface I { public function work(): int; }

      class MyTestCase extends BaseTestCase
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

  Scenario: Descendant of a test that has setUp produces no MissingConstructor
    Given I have the following code
      """
      use Prophecy\Prophecy\ObjectProphecy;

      interface I { public function work(): int; }

      class BaseTestCase extends TestCase {
        /** @var ObjectProphecy<I> */
        protected $i;

        /** @return void */
        public function setUp() {
          $this->i = $this->prophesize(I::class);
        }
      }

      class Intermediate extends BaseTestCase {}

      class MyTestCase extends Intermediate
      {
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

  Scenario: Descendant of a test that has @before produces no MissingConstructor
    Given I have the following code
      """
      use Prophecy\Prophecy\ObjectProphecy;

      interface I { public function work(): int; }

      class BaseTestCase extends TestCase {
        /** @var ObjectProphecy<I> */
        protected $i;

        /**
         * @before
         * @return void
         */
        public function myInit() {
          $this->i = $this->prophesize(I::class);
        }
      }

      class Intermediate extends BaseTestCase {}

      class MyTestCase extends Intermediate
      {
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

  Scenario: Test methods in traits are not marked as unused
    Given I have the following code
      """
      trait MyTestTrait {
        /** @return void */
        public function testSomething() {}
      }
      class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Inherited test methods are not marked as unused
    Given I have the following code
      """
      abstract class IntermediateTest extends TestCase {
        /** @return void */
        public function testSomething() {}
      }
      class MyTestCase extends IntermediateTest {
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Data providers in traits are not marked as unused
    Given I have the following code
      """
      trait MyTestTrait {
        /** @return iterable<int,array{int}> */
        public function provide() { return [[1]]; }
      }
      class MyTestCase extends TestCase {
        use MyTestTrait;
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $_i) {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Data providers in test case when test methods are in trait are not marked as unused
    Given I have the following code
      """
      trait MyTestTrait {
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(int $_i) {}
      }
      class MyTestCase extends TestCase {
        use MyTestTrait;
        /** @return iterable<int,array{int}> */
        public function provide() { return [[1]]; }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Renamed imported test methods are validated
    Given I have the following code
      """
      trait MyTestTrait {
        /**
         * @return void
         * @dataProvider provide
         */
        public function foo(int $_i) {}
      }
      class MyTestCase extends TestCase {
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
      trait MyTestTrait {
        /**
         * @return void
         * @dataProvider provide
         */
        public function testSomething(string $_p) {}
        /**
         * @return iterable<int,int[]>
         */
        public function provide() { return [[1]]; }
      }

      class MyTestCase extends TestCase {
        use MyTestTrait;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                       |
      | InvalidArgument | Argument 1 of NS\MyTestTrait::testSomething expects string, int provided by NS\MyTestTrait::provide():(iterable<int, array%>) |
    And I see no other errors

  Scenario: Providers may omit variadic part for variadic tests
    Given I have the following code
      """
      class MyTestCase extends TestCase {
        /** @return iterable<string,array{int}> */
        public function provide() {
          yield "data set" => [1];
        }
        /**
         * @dataProvider provide
         * @param int ...$rest
         * @return void
         */
        public function testSomething(int $i, ...$rest) {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers may omit non-variadic params with default for variadic tests
    Given I have the following code
      """
      class MyTestCase extends TestCase {
        /** @return iterable<string,array{int}> */
        public function provide() {
          yield "data set" => [1];
        }
        /**
         * @dataProvider provide
         * @param int ...$rest
         * @return void
         */
        public function testSomething(int $i, string $s = "", ...$rest) {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers may not omit non-variadic params with no default for variadic tests
    Given I have the following code
      """
      class MyTestCase extends TestCase {
        /** @return iterable<string,array{int}> */
        public function provide() {
          yield "data set" => [1];
        }
        /**
         * @dataProvider provide
         * @param int ...$rest
         * @return void
         */
        public function testSomething(int $i, string $s, ...$rest) {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                              |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable<string, array%>) |
    And I see no other errors

  Scenario: Providers generating incompatible datasets for variadic tests are reported
    Given I have the following code
      """
      class MyTestCase extends TestCase {
        /** @return iterable<string,array{float,1?:string}> */
        public function provide() {
          yield "data set" => [1., "a"];
        }
        /**
         * @dataProvider provide
         * @return void
         */
        public function testSomething(float ...$rest) {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                             |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects float, string provided by NS\MyTestCase::provide():(iterable<string, array{0:float, 1?:string}>) |
    And I see no other errors

  Scenario: Untyped providers returns are not checked against test method signatures
    Given I have the following code
      """
      class MyTestCase extends TestCase {
        /** @psalm-suppress MissingReturnType */
        public function provide() {
          yield "data set" => ["a"];
        }
        /**
         * @dataProvider provide
         * @return void
         */
        public function testSomething(string $_s) {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors
