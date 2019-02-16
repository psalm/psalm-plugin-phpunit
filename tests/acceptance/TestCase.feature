Feature: TestCase
  In order to have typed TestCases
  As a Psalm user
  I need Psalm to typecheck my test cases

  Background:
    Given I have the following code preamble
      """
      <?php
      use PHPUnit\Framework\TestCase;

      """

  Scenario: TestCase::expectException() rejects non-throwables
    Given I have Psalm newer than "3.0.12" (because of "missing functionality")
    Given I have the following code
      """
      class MyTestCase extends TestCase 
      {
        /** @return void */
        public function testSomething() {
          $this->expectException(MyTestCase::class);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message               |
      | InvalidArgument | Argument 1 of PHPUnit\Framework\TestCase::expectException expects class-string<Throwable>, MyTestCase::class provided |

  Scenario: TestCase::expectException() accepts throwables
    Given I have the following code
      """
      class MyTestCase extends TestCase 
      {
        /** @return void */
        public function testSomething() {
          $this->expectException(\InvalidArgumentException::class);
        }
      }
      """
    When I run Psalm
    Then I see no errors
