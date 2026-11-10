Feature: Datasets

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

  Scenario: Invalid dataset shape is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<string,array{string}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set name" => ["str"];
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
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{string}>) |
    And I see no other errors

  Scenario: Invalid dataset array is reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /**
         * @return iterable<string,array<int, string|int>>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set name" => ["str"];
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
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                                                              |
      | PossiblyInvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, int\|string provided by NS\MyTestCase::provide():(iterable[pure]<string, array<int, int\|string>>) |
    And I see no other errors

  Scenario: Shape dataset with missing params is reported
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
        public function testSomething(int $int, int $i) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                                 |
      | TooFewArguments |Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: Provider returning optional offsets is fine when test method has defaults for those params (specified as constants)
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @var string */
        const S = "s";
        /** @return iterable<string,array{0:int,1?:string}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [1, "ss"];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int, string $_str = self::S) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider omitting offsets is fine when test method has defaults for those params (specified as constants)
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @var string */
        const S = "s";
        /** @return iterable<string,list{int,...}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [1, "ss"];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int, string $_str = self::S) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider returning possibly undefined offset is fine when test method has default for that param
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:int}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
       public function testSomething(int $int = 2) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Provider returning possibly undefined offset with mismatching type is reported even when test method has default for that param
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:string}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? ["1"] : [];
        }
        /**
         * @return void
         */
        #[Attributes\DataProvider('provide')]
       public function testSomething(int $int = 2) {
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                   |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects int, string provided by NS\MyTestCase::provide():(iterable<string, array{0?: string}>) |
    And I see no other errors

  Scenario: Provider returning possibly undefined offset is marked when test method has no default for that param
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase
      {
        /** @return iterable<string,array{0?:int}> */
        public static function provide() {
          yield "data set name" => rand(0,1) ? [1] : [];
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
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething is not optional, but possibly undefined int provided by NS\MyTestCase::provide():(iterable<string, array{0?: int}>) |
    And I see no other errors

  Scenario: Providers may omit variadic part for variadic tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1];
        }
        /**
         * @param int ...$rest
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $i, ...$rest) {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers may omit non-variadic params with default for variadic tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1];
        }
        /**
         * @param int ...$rest
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $i, string $s = "", ...$rest) {}
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Providers may not omit non-variadic params with no default for variadic tests
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{int}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1];
        }
        /**
         * @param int ...$rest
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(int $i, string $s, ...$rest) {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                                 |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSomething - expecting at least 2, but saw 1 provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: Providers generating incompatible datasets for variadic tests are reported
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string,array{0: float, 1?:string}>
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => [1., "a"];
        }
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(float ...$rest) {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                               |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects float, string provided by NS\MyTestCase::provide():(iterable[pure]<string, array{0: float, 1?: string}>) |
    And I see no other errors

  Scenario: Untyped providers returns are not checked against test method signatures
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @psalm-suppress MissingReturnType
         * @psalm-pure
         */
        public static function provide() {
          yield "data set" => ["a"];
        }
        /**
         * @return void
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething(string $_s) {}
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: A provider value that is a parent type of the parameter type is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['a'];
        }

        /** @param non-empty-string $s */
        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertNotSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects non-empty-string, but parent type string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{string}>) |
    And I see no other errors

  Scenario: A nullable provider value that is a parent type of the nullable parameter type is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{null|string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [null];
        }

        /** @param ?non-empty-string $s */
        #[DataProvider('provide')]
        public function testSomething(?string $s): void {
          $this->assertNull($s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects non-empty-string\|null, but parent type null\|string provided by NS\MyTestCase::provide():(iterable[pure]<string, list{null\|string}>) |
    And I see no other errors

  Scenario: A named dataset value that is a parent type of the parameter type is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, array{s: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => ['s' => 'a'];
        }

        /** @param non-empty-string $s */
        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertNotSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | ArgumentTypeCoercion | Argument 1 ($s) of NS\MyTestCase::testSomething expects non-empty-string, but parent type string provided by NS\MyTestCase::provide():(iterable[pure]<string, array{s: string}>) |
    And I see no other errors

  Scenario: A provider value that does not fit the parameter type at all stays an invalid argument
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [1];
        }

        #[DataProvider('provide')]
        public function testSomething(string $s): void {
          $this->assertSame('', $s);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects string, int provided by NS\MyTestCase::provide():(iterable[pure]<string, list{int}>) |
    And I see no other errors

  Scenario: A possibly false provider value is still reported when the rest is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<int, int>|false}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param list<int> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects list<int>, but parent type array<int, int>\|false provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|false}>) |
      | PossiblyFalseArgument | Argument 1 of NS\MyTestCase::testSomething cannot be false, possibly list<int> value expected by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|false}>) |
    And I see no other errors

  Scenario: A possibly null provider value is still reported when the rest is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<int, int>|null}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param list<int> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects list<int>, but parent type array<int, int>\|null provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|null}>) |
      | PossiblyNullArgument | Argument 1 of NS\MyTestCase::testSomething cannot be null, possibly null value provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int>\|null}>) |
    And I see no other errors

  Scenario: A nullable list provider value is an argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<int, ?int>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param list<?int> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | ArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects list<int\|null>, but parent type array<int, int\|null> provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<int, int\|null>}>) |
    And I see no other errors

  Scenario: A mixed array value is a mixed argument type coercion
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<string, list{array<string, mixed>}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          yield 'x' => [[]];
        }

        /** @param array<string, string> $a */
        #[DataProvider('provide')]
        public function testSomething(array $a): void {
          $this->assertCount(0, $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type | Message |
      | MixedArgumentTypeCoercion | Argument 1 of NS\MyTestCase::testSomething expects array<string, string>, but parent type array<string, mixed> provided by NS\MyTestCase::provide():(iterable[pure]<string, list{array<string, mixed>}>) |
    And I see no other errors
