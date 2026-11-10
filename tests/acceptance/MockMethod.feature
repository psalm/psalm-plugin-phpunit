Feature: Mocked method names

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Mocking an undefined method is reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testMethods(): void {
          $mock = $this->createMock(Mailer::class);
          $mock->expects($this->once())->method('sendInvoce')->willReturn(true);
          $mock->method('sendInvoce')->willReturn(true);
          $mock->method('sendInvoice')->willReturn(true);

          $stub = $this->createStub(Mailer::class);
          $stub->method('sendInvoce')->willReturn(true);

          $configured = $this->createConfiguredMock(Mailer::class, ['sendInvoice' => true]);
          $configured->method('sendInvoce')->willReturn(true);

          $built = $this->getMockBuilder(Mailer::class)->getMock();
          $built->method('sendInvoce')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                    | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 14   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 15   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 19   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 22   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 25   |
    And I see no other errors

  Scenario: Mocking an undefined method is reported on typed properties and for every literal name
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        private const TYPO = 'sendInvoce';

        /** @var Mailer&\PHPUnit\Framework\MockObject\Stub */
        private $docblockStub;

        private \PHPUnit\Framework\MockObject\MockObject&Mailer $nativeMock;

        #[\Override]
        public function setUp(): void {
          $this->docblockStub = $this->createStub(Mailer::class);
          $this->nativeMock = $this->createMock(Mailer::class);
        }

        public function testProperties(): void {
          $this->docblockStub->method('sendInvoce')->willReturn(true);
          $this->nativeMock->method(self::TYPO)->willReturn(true);
        }

        public function testUnion(): void {
          $mailer = $this->createStub(Mailer::class);
          $mailer->method(random_int(0, 1) ? 'sendInvoice' : 'sendInvoce')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                    | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 26   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 27   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce() | 32   |
    And I see no other errors

  Scenario: Mocking a method PHPUnit adds to a Traversable double is not reported
    Given I have the following code
      """
      /**
       * @psalm-mutable
       * @extends \Traversable<int, int>
       */
      interface Numbers extends \Traversable {}

      /**
       * @psalm-mutable
       * @extends \IteratorAggregate<int, string>
       */
      interface Letters extends \IteratorAggregate {}

      final class MyTestCase extends TestCase {
        public function testTraversable(): void {
          $traversable = $this->createMock(\Traversable::class);
          $traversable->method('current')->willReturn(1);
          $traversable->method('nope')->willReturn(1);
        }

        public function testDerivedInterface(): void {
          $numbers = $this->createStub(Numbers::class);
          $numbers->method('current')->willReturn(1);
          $numbers->method('nope')->willReturn(1);
        }

        public function testAggregate(): void {
          $letters = $this->createStub(Letters::class);
          $letters->method('getIterator')->willReturn(new \ArrayIterator([]));
          $letters->method('current')->willReturn(1);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                           | Line |
      | UndefinedMethod | Trying to mock an undefined method Traversable::nope()            | 21   |
      | UndefinedMethod | Trying to mock an undefined method NS\Numbers::nope()             | 27   |
      | UndefinedMethod | Trying to mock an undefined method NS\Letters::current()          | 33   |
    And I see no other errors

  Scenario: Mocking a property hook by name is not reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testHooks(): void {
          $mailer = $this->createMock(Mailer::class);
          $mailer->method('$value::get')->willReturn(true);
          $mailer->method('$value::set')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Mocking an undefined method can be suppressed per call
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testSuppressed(): void {
          $mailer = $this->createStub(Mailer::class);
          /** @psalm-suppress UndefinedMethod */
          $mailer->method('sendInvoce')->willReturn(true);
          $mailer->method('sendInvoise')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                     |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoise() |
    And I see no other errors

  Scenario: Mocking an existing method is not reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Sender {
        /** @psalm-impure */
        public function send(): bool;
      }

      /** @psalm-mutable */
      interface Mailer extends Sender {}

      /** @psalm-immutable */
      trait Logs {
        /** @psalm-pure */
        public function log(): int { return 1; }
      }

      /** @psalm-mutable */
      class Base {
        /** @psalm-impure */
        public function fromBase(): void {}
      }

      /**
       * @psalm-mutable
       * @method int magic()
       */
      final class Child extends Base {
        use Logs;

        /** @psalm-impure */
        final public function finalMethod(): void {}

        /** @psalm-impure */
        private function hidden(): void {}

        /** @psalm-impure */
        public static function make(): void {}
      }

      /**
       * @psalm-mutable
       * @method int magicInterface()
       */
      interface Magic {}

      /** @psalm-mutable */
      final class Dynamic {
        /** @psalm-impure */
        public function __call(string $name, array $arguments): mixed { return null; }
      }

      final class MyTestCase extends TestCase {
        public function testExisting(): void {
          $mailer = $this->createStub(Mailer::class);
          $mailer->method('send')->willReturn(true);
          $mailer->method('SEND')->willReturn(true);

          $child = $this->createMock(Child::class);
          $child->method('fromBase')->willReturn(null);
          $child->method('log')->willReturn(1);
          $child->method('hidden')->willReturn(null);
          $child->method('finalMethod')->willReturn(null);
          $child->method('make')->willReturn(null);
          $child->method('magic')->willReturn(1);

          $this->createStub(Magic::class)->method('magicInterface')->willReturn(1);
          $this->createStub(Dynamic::class)->method('anything')->willReturn(1);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Mock method calls Psalm cannot check are not reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      interface Auditor {
        /** @psalm-impure */
        public function expects(): Rule;
      }

      /** @psalm-mutable */
      interface Dispatcher {
        /** @psalm-impure */
        public function expects(): \PHPUnit\Framework\MockObject\Stub&Mailer;
      }

      /** @psalm-mutable */
      final class Rule {
        /** @psalm-impure */
        public function method(string $name): self { return $this; }
      }

      /** @psalm-mutable */
      final class Configurable {
        /** @psalm-impure */
        public function method(string $name): bool { return true; }
      }

      final class MyTestCase extends TestCase {
        /** @psalm-pure */
        private static function typoName(): string {
          return 'typo';
        }

        public function testUnchecked(string $name): void {
          $mailer = $this->createMock(Mailer::class);
          $mailer->method($name)->willReturn(true);
          $mailer->method(self::typoName())->willReturn(true);
          $mailer->method($this->logicalOr('typo', 'sendInvoice'))->willReturn(true);

          $expectation = $mailer->expects($this->once());
          $expectation->method('typo')->willReturn(true);

          /** @psalm-suppress UndefinedClass, MixedMethodCall */
          $this->createStub(MissingClass::class)->method('typo')->willReturn(true);

          $this->createStub(Configurable::class)->method('typo');
          $this->createStub(Auditor::class)->expects()->method('typo');
          $this->createStub(Dispatcher::class)->expects()->method('sendInvoice');

          $this->assertSame(1, 1);
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: A method that is only mocked by name is still reported as unused
    Given I have the following code
      """
      /** @psalm-mutable */
      abstract class Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool { return true; }
      }

      final class MyTestCase extends TestCase {
        public function testMocked(): void {
          $mailer = $this->createMock(Mailer::class);
          $mailer->method('sendInvoice')->willReturn(true);
          $this->assertSame(1, 1);
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type                 | Message                                                |
      | PossiblyUnusedMethod | Cannot find any calls to method NS\Mailer::sendInvoice |
    And I see no other errors

  Scenario: Mocking an undefined method on a union of mocks is reported for each type lacking it
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function send(): bool;

        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      interface Notifier {
        /** @psalm-impure */
        public function send(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testMissingOnOneType(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->method('sendInvoice')->willReturn(true);
        }

        public function testMissingOnEveryType(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->method('sendInvoce')->willReturn(true);
        }

        public function testDefinedOnEveryType(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->method('send')->willReturn(true);
        }

        public function testExpects(bool $flag): void {
          $mock = $flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class);
          $mock->expects($this->once())->method('sendInvoice')->willReturn(true);
        }

        public function testInlineUnion(bool $flag): void {
          ($flag ? $this->createMock(Mailer::class) : $this->createMock(Notifier::class))->method('sendInvoice');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                        | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 23   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::sendInvoce()    | 28   |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoce()  | 28   |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 38   |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 42   |
    And I see no other errors

  Scenario: Mocking an undefined method on a union of stubs and mocks is reported
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      interface Notifier {
        /** @psalm-impure */
        public function send(): bool;
      }

      final class MyTestCase extends TestCase {
        public function testStubAndMock(bool $flag): void {
          $double = $flag ? $this->createStub(Mailer::class) : $this->createMock(Notifier::class);
          $double->method('sendInvoice')->willReturn(true);
        }

        public function testStubs(bool $flag): void {
          $double = $flag ? $this->createStub(Mailer::class) : $this->createStub(Notifier::class);
          $double->method('send')->willReturn(true);
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type            | Message                                                        | Line |
      | UndefinedMethod | Trying to mock an undefined method NS\Notifier::sendInvoice() | 20   |
      | UndefinedMethod | Trying to mock an undefined method NS\Mailer::send()          | 25   |
    And I see no other errors

  Scenario: Union members Psalm cannot check do not hide the checked ones
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Mailer {
        /** @psalm-impure */
        public function sendInvoice(): bool;
      }

      /** @psalm-mutable */
      final class Configurable {
        /** @psalm-impure */
        public function method(string $name): bool { return true; }
      }

      final class MyTestCase extends TestCase {
        public function testOwnMethod(bool $flag): void {
          $double = $flag ? $this->createMock(Mailer::class) : new Configurable();
          $double->method('typo');
        }

        public function testNotADouble(bool $flag): void {
          $double = $flag ? $this->createMock(Mailer::class) : null;
          $double->method('typo');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                              | Line |
      | UndefinedMethod       | Trying to mock an undefined method NS\Mailer::typo() | 20   |
      | PossiblyNullReference | Cannot call method method on possibly null value     | 25   |
      | UndefinedMethod       | Trying to mock an undefined method NS\Mailer::typo() | 25   |
    And I see no other errors
