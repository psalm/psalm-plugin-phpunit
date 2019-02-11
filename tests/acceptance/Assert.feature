Feature: Assert
  In order to use PHPUnit safely
  As a Psalm user
  I need Psalm to typecheck asserts

  Background:
    Given I have the following code preamble
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\Assert;

      """

  Scenario: Assert::assertInstanceOf()
    Given I have the following code
      """
      function f(): \Exception {
        return rand(0,1) ? new \RuntimeException : new \InvalidArgumentException;
      }
      function acceptsRuntimeException(\RuntimeException $_e): void {}

      $e = f();
      Assert::assertInstanceOf(\RuntimeException::class, $e);
      acceptsRuntimeException($e);
      """
    When I run Psalm
    Then I see no errors
