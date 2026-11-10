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

  Scenario: An imported type alias in a test parameter is expanded in the provider check
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array<string, string>}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('provide')]
        public function testAlias(array $options): void {
          $this->assertSame('x', $options['host']);
        }

        /**
         * @param array{host: string} $options
         */
        #[DataProvider('provide')]
        public function testShape(array $options): void {
          $this->assertSame('x', $options['host']);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testAlias expects array{host: string}, array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>}>) | 23 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testShape expects array{host: string}, array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>}>) | 31 |
    And I see no other errors

  Scenario: An imported type alias in a test parameter accepts a matching dataset
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array{host: string}}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('provide')]
        public function testSomething(array $options): void {
          $this->assertSame('x', $options['host']);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An imported type alias in a test parameter is expanded for named and unknown length datasets
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{options: array<string, string>}>
         * @psalm-pure
         */
        public static function named(): array {
          return [['options' => ['host' => 'x']]];
        }

        /**
         * @return list<array<int, array<string, string>>>
         * @psalm-pure
         */
        public static function lengthless(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('named')]
        public function testNamed(array $options): void {
          $this->assertSame('x', $options['host']);
        }

        /**
         * @param Options $options
         */
        #[DataProvider('lengthless')]
        public function testLengthless(array $options): void {
          $this->assertSame('x', $options['host']);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message | Line |
      | InvalidArgument | Argument 1 ($options) of NS\MyTestCase::testNamed expects array{host: string}, array<string, string> provided by NS\MyTestCase::named():(list<array{options: array<string, string>}>) | 31 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testLengthless expects array{host: string}, array<string, string> provided by NS\MyTestCase::lengthless():(list<array<int, array<string, string>>>) | 39 |
    And I see no other errors

  Scenario: A test parameter typed with an imported type alias is narrowed to the dataset type
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array{host: 'x'}}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x']]];
        }

        /**
         * @param Options $options
         */
        #[DataProvider('provide')]
        public function testSomething(array $options): void {
          /** @psalm-check-type-exact $options = array{host: 'x'} */
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A variadic parameter typed with an imported type alias is expanded in the provider check
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      /** @psalm-type Options = array{host: string} */
      final class Connection {}

      /** @psalm-import-type Options from Connection */
      final class MyTestCase extends TestCase {
        /**
         * @return list<array{array<string, string>, array<string, string>}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[['host' => 'x'], ['host' => 'y']]];
        }

        /**
         * @param Options ...$options
         */
        #[DataProvider('provide')]
        public function testSomething(array ...$options): void {
          $this->assertNotEmpty($options);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSomething expects array{host: string}, array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>, array<string, string>}>) |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSomething expects array{host: string}, array<string, string> provided by NS\MyTestCase::provide():(list<list{array<string, string>, array<string, string>}>) |
    And I see no other errors
