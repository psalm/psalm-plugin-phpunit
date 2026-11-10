Feature: Intersection mocks and stubs

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Intersection mocks have the type of every listed interface
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      /** @psalm-impure */
      function useClock(Clock $clock): int {
        return $clock->now();
      }

      final class MyTestCase extends TestCase {
        public function testMock(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->method('now')->willReturn(1);
          $mock->expects($this->once())->method('log');
          $mock->log('tick');
          $this->assertSame(1, $mock->now());
          $this->assertSame(1, useClock($mock));
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection stubs have the type of every listed interface
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      /** @psalm-impure */
      function useLogger(Logger $logger): void {
        $logger->log('tick');
      }

      final class MyTestCase extends TestCase {
        public function testStub(): void {
          $stub = self::createStubForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $stub->method('now')->willReturn(1);
          $stub->log('tick');
          $this->assertSame(1, $stub->now());
          useLogger($stub);
        }

        public function testStaticStub(): void {
          $stub = static::createStubForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $this->assertSame(0, $stub->now());
        }

        public function testInstanceStub(): void {
          $stub = $this->createStubForIntersectionOfInterfaces(interfaces: [Clock::class, Logger::class]);
          $stub->log('tick');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks and stubs report methods that no listed interface declares
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        public function testUnknownMethods(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $stub = $this->createStubForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->nope();
          $stub->expects($this->once());
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                                                  |
      | UndefinedInterfaceMethod | Method (NS\Clock&NS\Logger&PHPUnit\Framework\MockObject\MockObject)::nope does not exist |
      | UndefinedInterfaceMethod | Method (NS\Clock&NS\Logger&PHPUnit\Framework\MockObject\Stub)::expects does not exist    |
    And I see no other errors

  Scenario: Intersection mock interfaces can be listed in a variable and number more than two
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        public function testVariable(): void {
          $interfaces = [Clock::class, Logger::class];
          $mock = $this->createMockForIntersectionOfInterfaces($interfaces);
          $mock->log('tick');
          $this->assertSame(1, $mock->now());
        }

        public function testThreeInterfaces(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class, \Countable::class]);
          $this->assertSame(1, $mock->now());
          $this->assertSame(2, $mock->count());
          $mock->log('tick');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks keep the PHPUnit type when the interfaces are not a literal list
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        /** @param list<class-string> $interfaces */
        public function testOpenList(array $interfaces): void {
          $this->createMockForIntersectionOfInterfaces($interfaces)->now();
        }

        public function testSingleInterface(): void {
          $this->createMockForIntersectionOfInterfaces([Clock::class])->now();
        }

        public function testDuplicateInterface(): void {
          $this->createMockForIntersectionOfInterfaces([Clock::class, Clock::class])->now();
        }

        public function testSpread(): void {
          $this->createStubForIntersectionOfInterfaces(...[[Clock::class, Logger::class]])->now();
        }

        public function testFirstClassCallable(): void {
          $factory = $this->createMockForIntersectionOfInterfaces(...);
          $factory([Clock::class, Logger::class])->now();
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                     | Message                                                            | Line |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 20   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 24   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 28   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\Stub::now does not exist       | 32   |
      | UndefinedInterfaceMethod | Method PHPUnit\Framework\MockObject\MockObject::now does not exist | 37   |
    And I see no other errors

  Scenario: Intersection mocks work in traits and abstract test cases
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      trait MocksClock {
        public function mockClock(): int {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->log('tick');
          return $mock->now();
        }
      }

      abstract class BaseTestCase extends TestCase {
        protected static function stubClock(): int {
          return self::createStubForIntersectionOfInterfaces([Clock::class, Logger::class])->now();
        }
      }

      final class MyTestCase extends BaseTestCase {
        use MocksClock;

        public function testTraitAndParent(): void {
          $this->assertSame(1, $this->mockClock());
          $this->assertSame(1, self::stubClock());
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: Intersection mocks are not reported as unused with dead code detection
    Given I have the following code
      """
      /** @psalm-mutable */
      interface Clock {
        /** @psalm-impure */
        public function now(): int;
      }

      /** @psalm-mutable */
      interface Logger {
        /** @psalm-impure */
        public function log(string $message): void;
      }

      final class MyTestCase extends TestCase {
        public function testMock(): void {
          $mock = $this->createMockForIntersectionOfInterfaces([Clock::class, Logger::class]);
          $mock->log('tick');
          $this->assertSame(1, $mock->now());
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors
