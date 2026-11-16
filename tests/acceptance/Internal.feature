Feature: Internal test code

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Test code may use the test code of another namespace
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
    And I have the following code in "tests/Fixtures/Helper.php"
      """
      <?php
      namespace Fixtures;

      final class Helper
      {
        public function help(): void {}
      }
      """
    And I have the following code
      """
      final class MyTestCase extends TestCase
      {
        public function testSomething(): void
        {
          (new \Fixtures\Helper())->help();
          $this->assertTrue(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Library code using the code of the test suites is reported
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
    And I have the following code in "tests/Helper.php"
      """
      <?php
      namespace Tests;

      final class Helper {}
      """
    And I have the following code
      """
      final class Client
      {
        public function send(): void
        {
          new \Tests\Helper();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type          | Message                                                          |
      | InternalClass | Tests\Helper is internal to Tests but called from NS\Client::send |
    And I see no other errors

  Scenario: Library code using a test case is reported
    Given I have the following code in "tests/MyTestCase.php"
      """
      <?php
      namespace Tests;

      final class MyTestCase extends \PHPUnit\Framework\TestCase
      {
        public function testSomething(): void
        {
          $this->assertTrue(true);
        }

        public static function help(): void {}
      }
      """
    And I have the following code
      """
      /** @psalm-cli-only */
      final class Client
      {
        public function send(): void
        {
          \Tests\MyTestCase::help();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type          | Message                                                              |
      | InternalClass | Tests\MyTestCase is internal to Tests but called from NS\Client::send |
    And I see no other errors

  Scenario: Library code may use an abstract test case outside the test suites
    Given I have the following code in "testing/KernelTestCase.php"
      """
      <?php
      namespace Testing;

      abstract class KernelTestCase extends \PHPUnit\Framework\TestCase
      {
        public static function bootKernel(): void {}
      }
      """
    And I have the following code
      """
      /** @psalm-cli-only */
      final class Client
      {
        public function send(): void
        {
          \Testing\KernelTestCase::bootKernel();
        }
      }
      """
    When I run Psalm
    Then I see no errors
