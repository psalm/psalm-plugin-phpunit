Feature: Dependencies

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: @depends values are not required from the @dataProvider
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @dataProvider provide
         * @depends testOne
         */
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
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
    Then I see no errors

  Scenario: #[Depends] values are not required from the #[DataProvider]
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;
      use PHPUnit\Framework\Attributes\DependsExternalUsingDeepClone;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        public function testTwo(): int {
          $this->assertTrue(true);
          return 1;
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        #[DependsExternalUsingDeepClone(MyTestCase::class, 'testTwo')]
        public function testSecond(string $foo, string $bar, int $baz): void {
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
    Then I see no errors

  Scenario: @depends values are not checked against dataset values of an array provider
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): int {
          $this->assertTrue(true);
          return 1;
        }

        /**
         * @dataProvider provide
         * @depends clone testOne
         */
        public function testSecond(string $foo, int $bar): void {
          $this->assertSame($foo, (string) $bar);
        }

        /**
         * @return iterable<int, array<int, string>>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo']];
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Missing provider arguments are still reported when the test has a dependency
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, string $baz, string $bar): void {
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
    And I see no other errors

  Scenario: Dependencies on void tests pass no value and are still required from the provider
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): void {
          $this->assertTrue(true);
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
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
    And I see no other errors

  Scenario: Duplicate dependencies pass a single value
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[DataProvider('provide')]
        #[Depends('testOne')]
        #[Depends('testOne')]
        public function testSecond(string $foo, string $baz, string $bar): void {
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
    And I see no other errors

  Scenario: Named DependsExternal arguments are resolved by name
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DependsExternal;

      final class MyTestCase extends TestCase {
        public function testOne(): void {
          $this->assertTrue(true);
        }

        #[DataProvider('provide')]
        #[DependsExternal(methodName: 'testOne', className: MyTestCase::class)]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
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
    And I see no other errors

  Scenario: Values supplied by the provider for dependency params are still checked
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): int {
          $this->assertTrue(true);
          return 1;
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, int $bar): void {
          $this->assertSame($foo, (string) $bar);
        }

        /**
         * @return iterable<int, array{string, string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['foo', 'bad']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                                       |
      | InvalidArgument | Argument 2 of NS\MyTestCase::testSecond expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string, string}>) |
    And I see no other errors

  Scenario: Dependencies differing only by a negated clone modifier pass a single value
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @dataProvider provide
         * @depends testOne
         * @depends !clone testOne
         * @depends !shallowClone testOne
         */
        public function testSecond(string $foo, string $baz, string $bar): void {
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
    And I see no other errors

  Scenario: DependsExternal on the class sentinel passes no value
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DependsExternal;

      final class MyTestCase extends TestCase {
        #[DataProvider('provide')]
        #[DependsExternal(MyTestCase::class, 'class')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
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
    And I see no other errors

  Scenario: Optional dataset offsets are not guaranteed to cover dependency params
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(string $foo, string $baz, string $bar): void {
          $this->assertSame($foo, $bar . $baz);
        }

        /**
         * @return iterable<int, array{0?: string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [[]];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSecond is not optional, but possibly undefined string provided by NS\MyTestCase::provide():(iterable<int, array{0?: string}>) |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSecond - expecting at least 1, but saw 0 provided by NS\MyTestCase::provide():(iterable<int, array{0?: string}>) |
    And I see no other errors

  Scenario: @depends is ignored when the test has PHPUnit attributes
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @depends testOne
         */
        #[DataProvider('provide')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
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
    And I see no other errors

  Scenario: Variadic params are still checked against provider values when the test has a dependency
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        /**
         * @param int ...$values
         */
        #[Attributes\DataProvider('provide')]
        #[Attributes\Depends('testOne')]
        public function testSecond(int ...$values): void {
          $this->assertNotEmpty($values);
        }

        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['bad']];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                                        |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testSecond expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string}>) |
    And I see no other errors
