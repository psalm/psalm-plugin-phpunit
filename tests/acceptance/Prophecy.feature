Feature: Prophecy
  In order to utilize Prophecy in my test cases
  As a Psalm user
  I need Psalm to typecheck my prophecies

  Background:
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm errorLevel="1" %s>
        <projectFiles>
          <directory name="."/>
          <ignoreFiles> <directory name="../../vendor"/> </ignoreFiles>
        </projectFiles>
        <plugins>
          <pluginClass class="Psalm\PhpUnitPlugin\Plugin"/>
        </plugins>
      </psalm>
      """
    And I have the following code preamble
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\TestCase;
      use Prophecy\Argument;

      """

  Scenario: Argument::that() accepts callable with no parameters
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return void */
        public function testSomething() {
          $_argument = Argument::that(function () {
            return true;
          });
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Argument::that() accepts callable with one parameter
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return void */
        public function testSomething() {
          $_argument = Argument::that(function (int $i) {
            return $i > 0;
          });
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Argument::that() accepts callable with multiple parameters
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return void */
        public function testSomething() {
          $_argument = Argument::that(function (int $i, int $j, int $k) {
            return ($i + $j + $k) > 0;
          });
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Argument::that() only accepts callable with boolean return type
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return void */
        public function testSomething() {
          $_argument = Argument::that(function (): string {
            return 'hello';
          });
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                                                                             |
      | InvalidScalarArgument | /Argument 1 of Prophecy\\Argument::that expects callable\(mixed...\):bool, (but )?(pure-)?Closure\(\):(string\(hello\)\|"hello"\|'hello') provided/ |
    And I see no other errors

  Scenario: Argument::that() only accepts callable with boolean return type [Psalm 5]
    Given I have the following code
      """
      class MyTestCase extends TestCase
      {
        /** @return void */
        public function testSomething() {
          $_argument = Argument::that(function (): string {
            return 'hello';
          });
        }
      }
      """
    And I have Psalm newer than "4.99" (because of "changed issue type")
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                                                                                                             |
      | InvalidArgument | /Argument 1 of Prophecy\\Argument::that expects callable\(mixed...\):bool, (but )?(pure-)?Closure\(\):(string\(hello\)\|"hello"\|'hello') provided/ |
    And I see no other errors


  Scenario: prophesize() provided by ProphecyTrait is generic
    Given I have the following code
      """
      use Prophecy\PhpUnit\ProphecyTrait;
      class SUT { public function getString(): string { return "zzz"; } }
      class MyTestCase extends TestCase
      {
        use ProphecyTrait;
        public function testSomething(): void {
          $this->prophesize(SUT::class)->reveal()->getString();
        }
      }
      """
    When I run Psalm
    Then I see no errors
