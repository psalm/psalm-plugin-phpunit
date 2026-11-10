Feature: Prophecy
  In order to use Prophecy in my test cases
  As a Psalm user
  I need Psalm to understand the magic method calls on object prophecies

  Background:
    Given Psalm ignores the vendor package "phpspec/prophecy-phpunit"
    And I have the following code preamble
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      use Prophecy\PhpUnit\ProphecyTrait;

      /** @psalm-mutable */
      interface Resp {
        /** @psalm-impure */
        public function getStatusCode(): int;
      }

      /** @psalm-impure */
      function takesResp(Resp $_r): void {}

      """

  Scenario: Magic method call on a prophecy is a MethodProphecy
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        use ProphecyTrait;

        public function testSomething(): void {
          $response = $this->prophesize(Resp::class);
          $response->getStatusCode()->shouldBeCalled()->willReturn(202);
          $response->getStatusCode()->willReturn(200);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: reveal() returns the prophesized type
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        use ProphecyTrait;

        public function testSomething(): void {
          $response = $this->prophesize(Resp::class);
          takesResp($response->reveal());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Real ObjectProphecy methods are still known
    Given I have the following code
      """
      interface Extra {}

      final class MyTestCase extends TestCase
      {
        use ProphecyTrait;

        public function testSomething(): void {
          $response = $this->prophesize(Resp::class);
          $response->willImplement(Extra::class);
          $response->willBeConstructedWith([]);
          $response->getStatusCode()->willReturn(200);
          $response->checkProphecyMethodsPredictions();
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Vendor @throws contracts of ObjectProphecy stay visible
    Given Psalm checks for throws docblocks
    And I have the following code
      """
      final class MyTestCase extends TestCase
      {
        use ProphecyTrait;

        public function testSomething(): void {
          $response = $this->prophesize(Resp::class);
          takesResp($response->reveal());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                                                              |
      | MissingThrowsDocblock | Prophecy\Exception\Doubler\DoubleException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | Prophecy\Exception\Doubler\InterfaceNotFoundException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | Prophecy\Exception\Prophecy\ObjectProphecyException is thrown but not caught - please either catch or add a @throws annotation |
    And I see no other errors

  Scenario: prophesize() without ProphecyTrait is reported
    Given I have the following code
      """
      final class MyTestCase extends TestCase
      {
        public function testSomething(): void {
          $this->prophesize(Resp::class);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                        |
      | UndefinedMethod | Method NS\MyTestCase::prophesize does not exist |
    And I see no other errors
