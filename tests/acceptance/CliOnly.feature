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

  Scenario: A class that is not a test case calls code that only runs from the command line
    Given I have the following code
      """
      /** @psalm-cli-only */
      final class ImportCommand
      {
          public function handle(): void {}
      }

      final class ImportController
      {
          public function store(): void
          {
              (new ImportCommand())->handle();
          }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type        | Message |
      | CliOnlyCall | The class NS\ImportCommand only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first |
      | CliOnlyCall | The method NS\ImportCommand::handle() only runs from the command line (@psalm-cli-only), but this code may run outside of it: mark it @psalm-cli-only too, or check that PHP_SAPI === 'cli' first |
    And I see no other errors
