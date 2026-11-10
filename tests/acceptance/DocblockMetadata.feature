Feature: Docblock metadata ignored by PHPUnit 12 and newer

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

  Scenario: PHPUnit 13 reports ignored docblock tags
    Given PHPUnit identifies as version "13.0-dev"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @group slow
         */
        public function testSlow(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports ignored class level docblock tags
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      /**
       * @covers \NS\MyTestCase
       * @group slow
       */
      final class MyTestCase extends TestCase {
        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                       | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @covers docblock tag, use #[CoversClass], #[CoversMethod] or #[CoversFunction] instead | 6    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead                              | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports docblock tags on a method that also has a PHPUnit attribute
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\Test;

      final class MyTestCase extends TestCase {
        /**
         * @group slow
         */
        #[Test]
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 9    |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored docblock tag of a trait method once
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      trait SharedTests {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }

      final class FirstTestCase extends TestCase {
        use SharedTests;
      }

      final class SecondTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored docblock tag of an abstract test case once
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        /**
         * @before
         */
        public function prepare(): void {
          $this->assertTrue(true);
        }
      }

      final class FirstTestCase extends BaseTestCase {
      }

      final class SecondTestCase extends BaseTestCase {
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                            | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @before docblock tag, use #[Before] instead | 7    |
    And I see no other errors

  Scenario: PHPUnit 12 reports a non-static implementation of an abstract #[DataProvider]
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes;

      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        #[Attributes\DataProvider('provide')]
        public function testSomething(int $int): void {
          $this->assertSame(1, $int);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                | Message                                                     |
      | InvalidDataProvider | Data provider method NS\MyTestCase::provide must be static |
    And I see no other errors

  Scenario: PHPUnit 12 ignores a docblock data provider of an inherited test
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      abstract class BaseTestCase extends TestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        abstract public function provide();

        /**
         * @dataProvider provide
         */
        public function testSomething(): void {
          $this->assertTrue(true);
        }
      }

      final class MyTestCase extends BaseTestCase {
        /**
         * @return iterable<int,array<int,int>>
         * @psalm-pure
         */
        #[\Override]
        public function provide() {
          yield [1];
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                    | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead | 13   |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored @requires docblock tag
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @psalm-pure
         * @return int
         */
        public static function helper(): int {
          return 1;
        }

        /**
         * @requires PHP 8.0
         */
        public function testHelper(): void {
          $this->assertSame(1, self::helper());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                                | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @requires docblock tag, use #[RequiresPhp], #[RequiresPhpExtension], #[RequiresOperatingSystem] or another #[Requires*] instead | 15   |
    And I see no other errors

  Scenario: PHPUnit 12 reports an ignored docblock tag of a shared trait once
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      /**
       * @group shared
       */
      trait SharedTests {
        public function testShared(): void {
          $this->assertTrue(true);
        }
      }

      final class FirstTestCase extends TestCase {
        use SharedTests;
      }

      final class SecondTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 6    |
    And I see no other errors

  Scenario: PHPUnit 11 pin survives a config with its own autoloader
    Given PHPUnit identifies as version "11.5.0"
    And I have the following code in "autoload.php"
      """
      <?php
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" autoloader="autoload.php">
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
    When I run Psalm
    Then I see no errors

  Scenario: PHPUnit 12 pin survives a config with its own autoloader
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code in "autoload.php"
      """
      <?php
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" autoloader="autoload.php">
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
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 7    |
    And I see no other errors

  Scenario: A suppression on a trait covers the ignored docblock tags of its methods
    Given PHPUnit identifies as version "12.5.43"
    And I have the following config
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
    And I have the following code in "trait.php"
      """
      <?php
      namespace NS;

      /**
       * @psalm-suppress IgnoredDocblockMetadata
       */
      trait SharedTests {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      final class MyTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A suppression on the test case does not cover ignored docblock tags in a trait file
    Given PHPUnit identifies as version "12.5.43"
    And I have the following config
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
    And I have the following code in "trait.php"
      """
      <?php
      namespace NS;

      trait SharedTests {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    And I have the following code in "test.php"
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;

      /**
       * @psalm-suppress IgnoredDocblockMetadata
       */
      final class MyTestCase extends TestCase {
        use SharedTests;
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 6    |
      | UnusedPsalmSuppress     | This suppression is never used                                 | 6    |
    And I see no other errors

  Scenario: PHPUnit 12 leaves Psalm and other docblock tags alone
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @param int $number
         * @return void
         * @throws \RuntimeException
         * @Test
         * @testing
         */
        public function testSomething(int $number): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Ignored docblock metadata can be suppressed
    Given PHPUnit identifies as version "12.5.43"
    And I have the following config
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
      final class MyTestCase extends TestCase {
        /**
         * @test
         * @psalm-suppress IgnoredDocblockMetadata
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: PHPUnit 12 no longer treats docblock tags as test and provider usage
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         */
        public function itWorks(): void {
          $this->assertTrue(true);
        }

        /**
         * @dataProvider provide
         */
        public function testProvided(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                    | Message                                                                                                   | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead                                            | 7    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead | 14   |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::itWorks                                                    | 9    |
      | PossiblyUnusedMethod    | Cannot find any calls to method NS\MyTestCase::provide                                                    | 24   |
    And I see no other errors

  Scenario: PHPUnit 12 does not resolve an ignored @dataProvider
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @dataProvider missing
         */
        public function testProvided(int $number): void {
          $this->assertSame(1, $number);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                   |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead |
    And I see no other errors

  Scenario: PHPUnit 12 no longer treats @before as an initializer
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
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

        /**
         * @before
         */
        public function myInit(): void {
          $this->i = $this->createStub(I::class);
        }

        public function testSomething(): void {
          $this->i->method('work')->willReturn(1);

          $this->assertSame(1, $this->i->work());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                            |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @before docblock tag, use #[Before] instead |
      | MissingConstructor      | NS\MyTestCase has an uninitialized property NS\MyTestCase::$i, but no constructor |
    And I see no other errors

  Scenario: PHPUnit 12 keeps attribute metadata working
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      use PHPUnit\Framework\Attributes\DataProvider;
      use PHPUnit\Framework\Attributes\Test;

      final class MyTestCase extends TestCase {
        #[Test]
        #[DataProvider('provide')]
        public function itWorks(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: PHPUnit 11 does not report docblock metadata
    Given PHPUnit identifies as version "11.5.0"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         * @dataProvider provide
         * @group slow
         */
        public function itWorks(int $number): void {
          $this->assertSame(1, $number);
        }

        /**
         * @return list<array{int}>
         * @psalm-pure
         */
        public static function provide(): array {
          return [[1]];
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: PHPUnit 12 reports a malformed docblock tag as ignored metadata only
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @group
         */
        public function testSomething(): void {
          $this->expectNotToPerformAssertions();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                          | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead | 7    |
    And I see no other errors
