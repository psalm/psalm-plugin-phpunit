Feature: CliOnly

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: A test case calls code that only runs from the command line
    Given I have the following code
      """
      /** @psalm-cli-only */
      final class ImportCommand
      {
          public function handle(): void {}
      }

      final class ImportCommandTest extends TestCase
      {
          public function testItImports(): void
          {
              (new ImportCommand())->handle();
          }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A test case extending an abstract test case calls code that only runs from the command line
    Given I have the following code
      """
      /** @psalm-cli-only */
      final class ImportCommand
      {
          public function handle(): void {}
      }

      abstract class CommandTestCase extends TestCase
      {
          protected function import(): void
          {
              (new ImportCommand())->handle();
          }
      }

      final class ImportCommandTest extends CommandTestCase
      {
          public function testItImports(): void
          {
              $this->import();
              (new ImportCommand())->handle();
          }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A trait of a test case calls code that only runs from the command line
    Given I have the following code
      """
      /** @psalm-cli-only */
      final class ImportCommand
      {
          public function handle(): void {}
      }

      trait ImportsData
      {
          protected function import(): void
          {
              (new ImportCommand())->handle();
          }
      }

      final class ImportCommandTest extends TestCase
      {
          use ImportsData;

          public function testItImports(): void
          {
              $this->import();
          }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A test suite file calls a test case at top level and in a closure
    Given I have the following code in "phpunit.xml"
      """
      <phpunit>
        <testsuites>
          <testsuite name="unit">
            <directory>tests</directory>
          </testsuite>
        </testsuites>
      </phpunit>
      """
    And I have the following code in "tests/helpers.php"
      """
      <?php
      namespace NS;

      $basePath = ExampleTest::applicationBasePath();
      $render = static fn (): string => ExampleTest::applicationBasePath();
      $nested = static function (): string {
          return (static fn (): string => ExampleTest::applicationBasePath())();
      };
      """
    And I have the following code
      """
      final class ExampleTest extends TestCase
      {
          public static function applicationBasePath(): string
          {
              return __DIR__;
          }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A closure of a test suite file bound to a test case calls its methods
    Given I have the following code in "phpunit.xml"
      """
      <phpunit>
        <testsuites>
          <testsuite name="unit">
            <directory>tests</directory>
          </testsuite>
        </testsuites>
      </phpunit>
      """
    And I have the following code in "tests/ExampleTest.php"
      """
      <?php
      namespace NS;

      /** @param \Closure(): void $test */
      function it(\Closure $test): void {}

      /** @psalm-scope-this ExampleTest */
      it(function (): void {
          $this->render();
          $this->assertTrue(true);
      });
      """
    And I have the following code
      """
      final class ExampleTest extends TestCase
      {
          public function render(): string
          {
              return '';
          }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A file outside the test suites calling a test case is reported
    Given I have the following code in "phpunit.xml"
      """
      <phpunit>
        <testsuites>
          <testsuite name="unit">
            <directory>tests</directory>
          </testsuite>
        </testsuites>
      </phpunit>
      """
    And I have the following code in "src/helpers.php"
      """
      <?php
      namespace NS;

      $basePath = ExampleTest::applicationBasePath();
      $render = static fn (): string => ExampleTest::applicationBasePath();
      """
    And I have the following code
      """
      final class ExampleTest extends TestCase
      {
          public static function applicationBasePath(): string
          {
              return __DIR__;
          }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type        | Message | Line |
      | CliOnlyCall | The method NS\\ExampleTest::applicationBasePath() only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first | 4 |
      | CliOnlyCall | The method NS\\ExampleTest::applicationBasePath() only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first | 5 |
    And I see no other errors

  Scenario: A test suite listing files marks only those files
    Given I have the following code in "phpunit.xml"
      """
      <phpunit>
        <testsuites>
          <testsuite name="unit">
            <file>tests/listed.php</file>
          </testsuite>
        </testsuites>
      </phpunit>
      """
    And I have the following code in "tests/listed.php"
      """
      <?php
      namespace NS;

      $basePath = ExampleTest::applicationBasePath();
      """
    And I have the following code in "tests/other.php"
      """
      <?php
      namespace NS;

      $name = 'other';
      $basePath = ExampleTest::applicationBasePath();
      """
    And I have the following code
      """
      final class ExampleTest extends TestCase
      {
          public static function applicationBasePath(): string
          {
              return __DIR__;
          }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type        | Message | Line |
      | CliOnlyCall | The method NS\\ExampleTest::applicationBasePath() only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first | 5 |
    And I see no other errors

  Scenario: A test suite directory with a wildcard marks the files of the matching directories
    Given I have the following code in "phpunit.xml"
      """
      <phpunit>
        <testsuites>
          <testsuite name="unit">
            <directory>tests/*/Feature</directory>
          </testsuite>
        </testsuites>
      </phpunit>
      """
    And I have the following code in "tests/Admin/Feature/helpers.php"
      """
      <?php
      namespace NS;

      $basePath = ExampleTest::applicationBasePath();
      """
    And I have the following code in "tests/Admin/Unit/helpers.php"
      """
      <?php
      namespace NS;

      $name = 'other';
      $basePath = ExampleTest::applicationBasePath();
      """
    And I have the following code
      """
      final class ExampleTest extends TestCase
      {
          public static function applicationBasePath(): string
          {
              return __DIR__;
          }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type        | Message | Line |
      | CliOnlyCall | The method NS\\ExampleTest::applicationBasePath() only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first | 5 |
    And I see no other errors

  Scenario: Without a phpunit.xml a file calling a test case is reported
    Given I have the following code in "tests/helpers.php"
      """
      <?php
      namespace NS;

      $basePath = ExampleTest::applicationBasePath();
      """
    And I have the following code
      """
      final class ExampleTest extends TestCase
      {
          public static function applicationBasePath(): string
          {
              return __DIR__;
          }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type        | Message | Line |
      | CliOnlyCall | The method NS\\ExampleTest::applicationBasePath() only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first | 4 |
    And I see no other errors
