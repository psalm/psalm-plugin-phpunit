Feature: Docblock metadata ignored by PHPUnit 12 and newer

  Background:
    Given PHPUnit identifies as version "11.5.0"

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
    And the config uses the autoloader "autoload.php"
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
    And the config uses the autoloader "autoload.php"
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                        | Line |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead | 7    |
    And I see no other errors

  Scenario: A suppression on a trait covers the ignored docblock tags of its methods
    Given PHPUnit identifies as version "12.5.43"
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

  Scenario: PHPUnit 12 reports each docblock tag PHPUnit 11 reads
    Given PHPUnit identifies as version "12.5.43"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        /** @after x */
        public function method1(): void {}

        /** @afterClass x */
        public function method2(): void {}

        /** @backupGlobals x */
        public function method3(): void {}

        /** @backupStaticAttributes x */
        public function method4(): void {}

        /** @backupStaticProperties x */
        public function method5(): void {}

        /** @before x */
        public function method6(): void {}

        /** @beforeClass x */
        public function method7(): void {}

        /** @covers x */
        public function method8(): void {}

        /** @coversDefaultClass x */
        public function method9(): void {}

        /** @coversNothing x */
        public function method10(): void {}

        /** @dataProvider x */
        public function method11(): void {}

        /** @depends x */
        public function method12(): void {}

        /** @doesNotPerformAssertions x */
        public function method13(): void {}

        /** @excludeGlobalVariableFromBackup x */
        public function method14(): void {}

        /** @excludeStaticPropertyFromBackup x */
        public function method15(): void {}

        /** @group x */
        public function method16(): void {}

        /** @large x */
        public function method17(): void {}

        /** @medium x */
        public function method18(): void {}

        /** @postCondition x */
        public function method19(): void {}

        /** @preCondition x */
        public function method20(): void {}

        /** @preserveGlobalState x */
        public function method21(): void {}

        /** @requires x */
        public function method22(): void {}

        /** @runClassInSeparateProcess x */
        public function method23(): void {}

        /** @runInSeparateProcess x */
        public function method24(): void {}

        /** @runTestsInSeparateProcesses x */
        public function method25(): void {}

        /** @small x */
        public function method26(): void {}

        /** @test x */
        public function method27(): void {}

        /** @testdox x */
        public function method28(): void {}

        /** @testWith x */
        public function method29(): void {}

        /** @ticket x */
        public function method30(): void {}

        /** @uses x */
        public function method31(): void {}

        /** @usesDefaultClass x */
        public function method32(): void {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                    | Message                                                                                                                                                |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @after docblock tag, use #[After] instead                                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @afterClass docblock tag, use #[AfterClass] instead                                                                             |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @backupGlobals docblock tag, use #[BackupGlobals] instead                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @backupStaticAttributes docblock tag, use #[BackupStaticProperties] instead                                                     |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @backupStaticProperties docblock tag, use #[BackupStaticProperties] instead                                                     |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @before docblock tag, use #[Before] instead                                                                                     |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @beforeClass docblock tag, use #[BeforeClass] instead                                                                           |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @covers docblock tag, use #[CoversClass], #[CoversMethod] or #[CoversFunction] instead                                          |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @coversDefaultClass docblock tag, use #[CoversClass] instead                                                                    |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @coversNothing docblock tag, use #[CoversNothing] instead                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @dataProvider docblock tag, use #[DataProvider] or #[DataProviderExternal] instead                                              |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @depends docblock tag, use #[Depends] or #[DependsExternal] instead                                                             |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @doesNotPerformAssertions docblock tag, use #[DoesNotPerformAssertions] instead                                                 |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @excludeGlobalVariableFromBackup docblock tag, use #[ExcludeGlobalVariableFromBackup] instead                                   |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @excludeStaticPropertyFromBackup docblock tag, use #[ExcludeStaticPropertyFromBackup] instead                                   |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @group docblock tag, use #[Group] instead                                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @large docblock tag, use #[Large] instead                                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @medium docblock tag, use #[Medium] instead                                                                                     |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @postCondition docblock tag, use #[PostCondition] instead                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @preCondition docblock tag, use #[PreCondition] instead                                                                         |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @preserveGlobalState docblock tag, use #[PreserveGlobalState] instead                                                           |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @requires docblock tag, use #[RequiresPhp], #[RequiresPhpExtension], #[RequiresOperatingSystem] or another #[Requires*] instead |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @runClassInSeparateProcess docblock tag, use #[RunClassInSeparateProcess] instead                                               |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @runInSeparateProcess docblock tag, use #[RunInSeparateProcess] instead                                                         |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @runTestsInSeparateProcesses docblock tag, use #[RunTestsInSeparateProcesses] instead                                           |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @small docblock tag, use #[Small] instead                                                                                       |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @test docblock tag, use #[Test] instead                                                                                         |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @testdox docblock tag, use #[TestDox] instead                                                                                   |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @testWith docblock tag, use #[TestWith] or #[TestWithJson] instead                                                              |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @ticket docblock tag, use #[Ticket] instead                                                                                     |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @uses docblock tag, use #[UsesClass], #[UsesMethod] or #[UsesFunction] instead                                                  |
      | IgnoredDocblockMetadata | PHPUnit 12 ignores the @usesDefaultClass docblock tag, use #[UsesClass] instead                                                                        |
    And I see no other errors
