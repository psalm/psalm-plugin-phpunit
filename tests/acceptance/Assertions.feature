Feature: Assertions

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

  Scenario: assertNotEmpty removes null from the asserted value
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Customer {
        public string $name = 'Ada';
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        private function find(): ?Customer { return null; }

        public function testFinds(): void {
          $customer = $this->find();
          $this->assertNotEmpty($customer);
          $this->assertSame('Ada', $customer->name);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertNotEmpty narrows arrays and strings to non-empty types
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /** @param list<int>|null $list */
        public function testList(?array $list, string $string): void {
          self::assertNotEmpty($list);
          self::assertNotEmpty($string);
          /** @psalm-check-type-exact $list = non-empty-list<int> */
          /** @psalm-check-type-exact $string = non-falsy-string */
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertNotEmpty on Countable objects is not a redundant condition
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testCountable(\Countable $countable, \ArrayObject $items): void {
          $this->assertNotEmpty($countable);
          self::assertNotEmpty($items);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertSame with a null expectation suggests assertNull
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testNull(): void {
          $value = random_int(0, 1) ? 1 : null;
          $this->assertSame(null, $value);
          $this->assertNotSame(NULL, $value);
          self::assertSame(\null, $value);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                 |
      | UnspecificNullAssertion | Use assertNull() instead of assertSame(null, ...)       |
      | UnspecificNullAssertion | Use assertNotNull() instead of assertNotSame(null, ...) |
      | UnspecificNullAssertion | Use assertNull() instead of assertSame(null, ...)       |
    And I see no other errors

  Scenario: assertSame with a boolean expectation suggests assertTrue and assertFalse
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testBool(): void {
          $flag = random_int(0, 1) === 1;
          $this->assertSame(true, $flag);
          $this->assertSame(false, $flag);
          $this->assertNotSame(true, $flag);
          self::assertNotSame(FALSE, $flag);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                       | Message                                                   |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertSame(true, ...)         |
      | UnspecificBooleanAssertion | Use assertFalse() instead of assertSame(false, ...)       |
      | UnspecificBooleanAssertion | Use assertNotTrue() instead of assertNotSame(true, ...)   |
      | UnspecificBooleanAssertion | Use assertNotFalse() instead of assertNotSame(false, ...) |
    And I see no other errors

  Scenario: assertSame and assertEquals with count() suggest assertCount
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testCount(): void {
          $lines = ['a', 'b', 'c'];
          $collection = new \ArrayObject($lines);
          $this->assertSame(3, count($lines));
          $this->assertEquals(3, \count($lines));
          $this->assertNotSame(2, count($lines));
          $this->assertNotEquals(2, count($lines));
          $this->assertSame(3, $collection->count());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                          |
      | UnspecificCountAssertion | Use assertCount() instead of assertSame(..., count(...))         |
      | UnspecificCountAssertion | Use assertCount() instead of assertEquals(..., count(...))       |
      | UnspecificCountAssertion | Use assertNotCount() instead of assertNotSame(..., count(...))   |
      | UnspecificCountAssertion | Use assertNotCount() instead of assertNotEquals(..., count(...)) |
      | UnspecificCountAssertion | Use assertCount() instead of assertSame(..., count(...))         |
    And I see no other errors

  Scenario: assertEquals with both arguments of the same scalar type suggests assertSame
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testScalars(): void {
          $int = random_int(0, 1);
          $text = (string) $int;
          $float = (float) $int;
          $flag = $int === 1;
          $choice = $int ? 'a' : 'b';
          $this->assertEquals(1, $int);
          $this->assertNotEquals($int, 2);
          self::assertEquals($int, $int);
          static::assertEquals($int, $int);
          \PHPUnit\Framework\Assert::assertEquals($int, $int);
          $this->assertEquals('a', $text);
          $this->assertNotEquals($text, strrev($text));
          $this->assertEquals($choice, $text);
          $this->assertEquals(0.5, $float);
          $this->assertEquals($float, $float);
          $this->assertEquals($flag, !$flag);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                      | Message                                                                             | Line |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 12   |
      | UnspecificEqualsAssertion | Use assertNotSame() instead of assertNotEquals(), both arguments are of type int    | 13   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 14   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 15   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type int          | 16   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type string       | 17   |
      | UnspecificEqualsAssertion | Use assertNotSame() instead of assertNotEquals(), both arguments are of type string | 18   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type string       | 19   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type float        | 20   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type float        | 21   |
      | UnspecificEqualsAssertion | Use assertSame() instead of assertEquals(), both arguments are of type bool         | 22   |
    And I see no other errors

  Scenario: assertEquals with a boolean expectation suggests assertTrue and assertFalse
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testBool(): void {
          $flag = random_int(0, 1) === 1;
          $this->assertEquals(true, $flag);
          $this->assertEquals(FALSE, $flag);
          $this->assertNotEquals(true, $flag);
          self::assertNotEquals(false, $flag);
          $this->assertEquals(true, true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                       | Message                                                     | Line |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertEquals(true, ...)         | 8    |
      | UnspecificBooleanAssertion | Use assertFalse() instead of assertEquals(false, ...)       | 9    |
      | UnspecificBooleanAssertion | Use assertNotTrue() instead of assertNotEquals(true, ...)   | 10   |
      | UnspecificBooleanAssertion | Use assertNotFalse() instead of assertNotEquals(false, ...) | 11   |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertEquals(true, ...)         | 12   |
    And I see no other errors

  Scenario: Assertion suggestions do not depend on the argument order
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testOrder(): void {
          $value = random_int(0, 1) ? 1 : null;
          $flag = random_int(0, 1) === 1;
          $int = random_int(0, 1);
          $text = (string) $int;
          $lines = ['a', 'b', 'c'];
          $collection = new \ArrayObject($lines);
          $this->assertSame($value, null);
          $this->assertNotSame($value, null);
          $this->assertSame($flag, true);
          $this->assertNotSame($flag, false);
          $this->assertEquals($flag, true);
          $this->assertNotEquals($flag, false);
          $this->assertSame(count($lines), 3);
          $this->assertEquals(\count($lines), 3);
          $this->assertNotEquals($collection->count(), 2);
          $this->assertEquals($int, true);
          $this->assertEquals($int, null);
          $this->assertEquals($text, false);
          $this->assertEquals($int ? true : null, true);
          $this->assertSame(count($lines), '3');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                       | Message                                                          | Line |
      | UnspecificNullAssertion    | Use assertNull() instead of assertSame(..., null)                | 13   |
      | UnspecificNullAssertion    | Use assertNotNull() instead of assertNotSame(..., null)          | 14   |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertSame(..., true)                | 15   |
      | UnspecificBooleanAssertion | Use assertNotFalse() instead of assertNotSame(..., false)        | 16   |
      | UnspecificBooleanAssertion | Use assertTrue() instead of assertEquals(..., true)              | 17   |
      | UnspecificBooleanAssertion | Use assertNotFalse() instead of assertNotEquals(..., false)      | 18   |
      | UnspecificCountAssertion   | Use assertCount() instead of assertSame(count(...), ...)         | 19   |
      | UnspecificCountAssertion   | Use assertCount() instead of assertEquals(count(...), ...)       | 20   |
      | UnspecificCountAssertion   | Use assertNotCount() instead of assertNotEquals(count(...), ...) | 21   |
    And I see no other errors

  Scenario: assertEquals with different, mixed, nullable or non-scalar arguments is not reported
    Given I have the following code
      """
      enum Suit: string {
        case Hearts = 'h';
      }

      final class MyTestCase extends TestCase {
        public function testOthers(): void {
          $int = random_int(0, 1);
          $text = (string) $int;
          $float = (float) $int;
          $maybeInt = $int ? 1 : null;
          $intOrText = $int ? 1 : 'a';
          $this->assertEquals(1, $text);
          $this->assertEquals(1, $float);
          $this->assertEquals(true, $int);
          $this->assertNotEquals(false, $text);
          $this->assertEquals(true, $int ? true : null);
          $this->assertEquals(0, $maybeInt);
          $this->assertEquals($maybeInt, $int);
          $this->assertEquals(null, $int);
          $this->assertEquals(1, $intOrText);
          $this->assertEquals($intOrText, $intOrText);
          $this->assertEquals(1, json_decode('1'));
          $this->assertEquals([1], [1]);
          $this->assertEquals(new \stdClass(), new \stdClass());
          $this->assertEquals(Suit::Hearts, Suit::Hearts);
          $this->assertEqualsWithDelta(1.0, $float, 0.1);
          $this->assertEqualsIgnoringCase('a', $text);
          $this->assertEquals(expected: 1, actual: $int);
          $this->assertEquals(...[1, $int]);
          $check = $this->assertEquals(...);
          $check(1, $int);
          $this->assertSame(1, $int);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertEquals suggestion is only reported at error level 1
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="2" findUnusedCode="false" >
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
      final class MyTestCase extends TestCase {
        public function testEquals(): void {
          $this->assertEquals(1, random_int(0, 1));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: assertEquals suggestion can be suppressed in the config
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" >
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
          <PluginIssue name="UnspecificEqualsAssertion" errorLevel="suppress" />
        </issueHandlers>
      </psalm>
      """
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testEquals(): void {
          $this->assertEquals(1, random_int(0, 1));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assertions without a literal expectation or a plain count are not reported
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Bag {
        /** @psalm-pure */
        public function count(): int { return 1; }
      }

      final class MyTestCase extends TestCase {
        private const NOTHING = null;

        private function maybe(): ?int {
          return random_int(0, 1) ? 1 : null;
        }

        public function testOthers(): void {
          $flag = random_int(0, 1) === 1;
          $lines = [['a'], ['b']];
          $this->assertNull($this->maybe());
          $this->assertTrue($flag);
          $this->assertCount(2, $lines);
          $this->assertSame(1, $this->maybe());
          $this->assertSame(self::NOTHING, $this->maybe());
          $this->assertEquals(null, $this->maybe());
          $this->assertSame(2, count($lines, COUNT_RECURSIVE));
          $this->assertSame(2, (new Bag())->count());
          $this->assertSame(2, strlen('ab'));
          $this->assertNotSame('2', count($lines));
          $this->assertSame(message: 'no', actual: $this->maybe(), expected: null);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: count() that is not the global function is not reported
    Given I have the following code
      """
      use function strlen as count;

      final class MyTestCase extends TestCase {
        public function testAliasedCount(): void {
          $this->assertSame(2, count('ab'));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: count() declared in the test namespace is not reported
    Given I have the following code
      """
      /** @psalm-pure */
      function count(string $text): int {
        return strlen($text);
      }

      final class MyTestCase extends TestCase {
        public function testNamespacedCount(): void {
          $this->assertSame(2, count('ab'));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assertion suggestions can be suppressed
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testSuppressed(): void {
          $value = random_int(0, 1) ? 1 : null;
          $flag = random_int(0, 1) === 1;
          $lines = ['a'];
          /** @psalm-suppress UnspecificNullAssertion */
          $this->assertSame(null, $value);
          /** @psalm-suppress UnspecificBooleanAssertion */
          $this->assertSame(true, $flag);
          /** @psalm-suppress UnspecificCountAssertion */
          $this->assertSame(1, count($lines));
          /** @psalm-suppress UnspecificEqualsAssertion */
          $this->assertEquals(1, random_int(0, 1));
        }
      }
      """
    When I run Psalm
    Then I see no errors
