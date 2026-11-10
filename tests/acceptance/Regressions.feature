Feature: Regressions

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Invalid psalm annotation on a class does not crash psalm
    Given I have the following code
      """
      /** @psalm-ignore Everything */
      final class MyTestCase extends TestCase {}
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message         |
      | InvalidDocblock | Unrecognised annotation @psalm-ignore |
      | InvalidDocblock | Unrecognised annotation @psalm-ignore in docblock for NS\\MyTestCase |
    And I see no other errors

  Scenario: Invalid psalm annotation on an before initializer does not crash psalm
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @before
         * @psalm-rm-Rf-slash
         * @return void
         * @psalm-capabilities read-props
         */
        public function preparation() {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message              |
      | InvalidDocblock | Unrecognised annotation @psalm-rm-Rf-slash |
    And I see no other errors

  Scenario: Invalid psalm annotation on a test does not crash psalm
    Given I have the following code
      """
      final class MyTestCase extends TestCase {
        /**
         * @test
         * @psalm-force-push-master
         * @return void
         * @psalm-capabilities read-props
         */
        public function doThings() {}
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                    |
      | InvalidDocblock | Unrecognised annotation @psalm-force-push-master |
    And I see no other errors

  Scenario: Missing param type on a test with tuple data provider does not crash psalm
    Given I have the following code
      """
      use PHPUnit\Framework\Attributes;

      final class MyTestCase extends TestCase {
        /**
         * @psalm-suppress MissingParamType
         * @psalm-capabilities read-props
         */
        #[Attributes\DataProvider('provide')]
        public function testSomething($data): void {}

        /**
         * @return iterable<string, array{int}>
         * @psalm-pure
         */
        public static function provide(): iterable {
          return ['case 1' => [1]];
        }
      }
      """
    When I run Psalm
    Then I see exit code 0
    And I see no errors
