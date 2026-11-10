Feature: DataProviderClosure

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

  Scenario: Dataset of a #[DataProviderClosure] that does not match the parameters is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [['not an int']])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'not an int' provided by #[DataProviderClosure]:(list{list{'not an int'}}) | 8 |
    And I see no other errors

  Scenario: Dataset of a #[DataProviderClosure] that matches the parameters is allowed
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [[1], 'named' => [2]])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Dataset of a #[DataProviderClosure] declared as a closure with a body is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static function (): iterable {
          return [['not an int']];
        })]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'not an int' provided by #[DataProviderClosure]:(list{list{'not an int'}}) | 8 |
    And I see no other errors

  Scenario: Missing values in a dataset of a #[DataProviderClosure] are reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [[1]])]
        public function testSum(int $a, int $b): void {
          $this->assertSame($a + $b, $b + $a);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | TooFewArguments | Too few arguments for NS\MyTestCase::testSum - expecting at least 2, but saw 1 provided by #[DataProviderClosure]:(list{list{1}}) | 8 |
    And I see no other errors

  Scenario: String-keyed datasets of a #[DataProviderClosure] are matched to parameters by name
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [['value' => 1, 'typo' => 2]])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message | Line |
      | InvalidNamedArgument | Parameter $typo does not exist on NS\MyTestCase::testDouble, provided by #[DataProviderClosure]:(list{array{typo: 2, value: 1}}) | 8 |
    And I see no other errors

  Scenario: String-keyed datasets of a #[DataProviderClosure] are reported when #[Depends] passes a value
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;
      use PHPUnit\Framework\Attributes\Depends;

      final class MyTestCase extends TestCase {
        public function testOne(): string {
          $this->assertTrue(true);
          return 'bar';
        }

        #[DataProviderClosure(static fn (): iterable => [['foo' => 'foo']])]
        #[Depends('testOne')]
        public function testSecond(string $foo, string $bar): void {
          $this->assertSame($foo, $bar);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message | Line |
      | InvalidNamedArgument | Cannot use positional argument after named argument in NS\MyTestCase::testSecond: PHPUnit appends the return value of a depended-upon test to dataset #[DataProviderClosure]:(list{array{foo: 'foo'}}) | 14 |
    And I see no other errors

  Scenario: A #[DataProviderClosure] that does not return an iterable is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): int => 1)]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type              | Message | Line |
      | InvalidReturnType | Providers must return iterable<array-key, array<array-key, mixed>>, 1 provided | 8 |
    And I see no other errors

  Scenario: Every #[DataProviderClosure] and #[DataProvider] of a test is checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['not an int']];
        }

        #[DataProviderClosure(static fn (): iterable => [[1]])]
        #[DataProviderClosure(static fn (): iterable => [['also not an int']])]
        #[DataProvider('provide')]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string}>) | 19 |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'also not an int' provided by #[DataProviderClosure]:(list{list{'also not an int'}}) | 18 |
    And I see no other errors

  Scenario: Datasets of a #[DataProviderClosure] in a test of a trait are checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      trait DoubleTests {
        #[DataProviderClosure(static fn (): iterable => [['not an int']])]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }

      final class MyTestCase extends TestCase {
        use DoubleTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, 'not an int' provided by #[DataProviderClosure]:(list{list{'not an int'}}) | 8 |
    And I see no other errors

  Scenario: A #[DataProviderClosure] argument that is not a literal closure is not checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['not an int']];
        }

        #[DataProviderClosure(self::provide(...))]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: An empty #[DataProviderClosure] does not stop the other providers from being checked
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        /**
         * @return iterable<int, array{string}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return [['not an int']];
        }

        #[DataProviderClosure(static fn (): iterable => [])]
        #[DataProviderClosure(static fn (): iterable => [[1]])]
        #[DataProvider('provide')]
        public function testDouble(int $value): void {
          $this->assertSame($value * 2, $value + $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message | Line |
      | InvalidArgument | Argument 1 of NS\MyTestCase::testDouble expects int, string provided by NS\MyTestCase::provide():(iterable<int, list{string}>) | 19 |
    And I see no other errors

  Scenario: A positional entry after a named one in a #[DataProviderClosure] dataset is reported
    Given PHPUnit identifies as version "13.1.0"
    And PHPUnit declares the DataProviderClosure attribute
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProviderClosure;

      final class MyTestCase extends TestCase {
        #[DataProviderClosure(static fn (): iterable => [['b' => 2, 0 => 1]])]
        public function testFoo(int $a, int $b): void {
          $this->assertSame($a, $b);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                 | Message |
      | InvalidNamedArgument | Cannot use positional argument after named argument in a dataset provided by #[DataProviderClosure] |
    And I see no other errors
