@psalm7
Feature: Prophecy
  In order to use Prophecy in my test cases
  As a Psalm user
  I need Psalm to understand the magic method calls on object prophecies

  Background:
    Given I have the following config
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
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" findUnusedCode="false" checkForThrowsDocblock="true" %s>
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
      final class MyTestCase extends TestCase
      {
        public function testSomething(): void {
          $response = $this->prophesize(Resp::class);
          takesResp($response->reveal());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                                                              |
      | MissingThrowsDocblock | Prophecy\Exception\Prophecy\ObjectProphecyException is thrown but not caught - please either catch or add a @throws annotation |
    And I see no other errors
