Feature: Exceptions

  Background:
    Given PHPUnit identifies as version "11.5.0"

  Scenario: Unused calls after expectException are not reported
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Value {
        /** @psalm-pure */
        public function get(): int { return 1; }
      }

      final class MyTestCase extends TestCase {
        public function testAfter(): void {
          $this->expectException(\JsonException::class);
          json_decode('', flags: JSON_THROW_ON_ERROR);
          (new Value())->get();
        }

        public function testAfterStaticCall(): void {
          self::expectExceptionMessage('Syntax error');
          json_decode('', flags: JSON_THROW_ON_ERROR);
        }

        public function testReturnValueIsUsed(): void {
          $this->assertSame(1, (new Value())->get());
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see no errors

  Scenario: Unused calls before expectException and in other tests are still reported
    Given I have the following code
      """
      /** @psalm-immutable */
      final class Value {
        /** @psalm-pure */
        public function get(): int { return 1; }
      }

      /** @psalm-immutable */
      final class Other {
        /** @psalm-pure */
        public function get(): int { return 1; }
      }

      final class MyTestCase extends TestCase {
        public function testBefore(): void {
          json_decode('', flags: JSON_THROW_ON_ERROR);
          (new Value())->get();
          $this->expectException(\JsonException::class);
        }

        /** @psalm-capabilities read-props */
        public function testWithoutExpectation(): void {
          json_encode(1);
          (new Other())->get();
        }

        public function testReturnValueIsUsed(): void {
          $this->assertSame(1, (new Value())->get() + (new Other())->get());
        }
      }
      """
    When I run Psalm with dead code detection
    Then I see these errors
      | Type               | Message                               |
      | UnusedFunctionCall | The call to json_decode is not used   |
      | UnusedMethodCall   | The call to NS\Value::get is not used |
      | UnusedFunctionCall | The call to json_encode is not used   |
      | UnusedMethodCall   | The call to NS\Other::get is not used |
    And I see no other errors

  Scenario: MissingThrowsDocblock is not reported after expectException
    Given Psalm checks for throws docblocks
    And the config suppresses the issue "MissingPureAnnotation"
    And the config suppresses the issue "InternalMethod"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testThrows(): void {
          $this->expectException(\InvalidArgumentException::class);
          throw new \InvalidArgumentException('boom');
        }

        public function testStaticExpectation(): void {
          self::expectException(\InvalidArgumentException::class);
          throw new \InvalidArgumentException('boom');
        }

        public function testDocumentedCalls(): void {
          $this->expectException(\InvalidArgumentException::class);
          self::fail2();
          $this->fail3();
        }

        public function testDocumentedCallsWithoutExpectation(): void {
          self::fail2();
          $this->fail3();
        }

        public function testExpectationOnOtherInstance(): void {
          $other = new self('other');
          $other->expectException(\DomainException::class);
          throw new \DomainException('boom');
        }

        public function testWithoutExpectation(): void {
          throw new \RuntimeException('boom');
        }

        /** @throws \InvalidArgumentException */
        private static function fail2(): void { throw new \InvalidArgumentException('boom'); }

        /** @throws \InvalidArgumentException */
        private function fail3(): void { throw new \InvalidArgumentException('boom'); }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                             |
      | MissingThrowsDocblock | InvalidArgumentException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | InvalidArgumentException is thrown but not caught - please either catch or add a @throws annotation |
      | MissingThrowsDocblock | DomainException is thrown but not caught - please either catch or add a @throws annotation          |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation         |
    And I see no other errors

  Scenario: MissingThrowsDocblock is not reported after expectException in a branch
    Given Psalm checks for throws docblocks
    And the config suppresses the issue "MissingPureAnnotation"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testIf(bool $fail): void {
          if ($fail) {
            $this->expectException(\InvalidArgumentException::class);
          }
          throw new \InvalidArgumentException('boom');
        }

        public function testBothArms(bool $fail): void {
          if ($fail) {
            $this->expectException(\InvalidArgumentException::class);
          } else {
            $this->expectException(\DomainException::class);
          }
          throw new \InvalidArgumentException('boom');
        }

        public function testCatch(): void {
          try {
            $value = 1;
          } catch (\Throwable) {
            $this->expectException(\InvalidArgumentException::class);
          }
          throw new \InvalidArgumentException('boom');
        }
      }
      """
    When I run Psalm
    Then I see no errors

  Scenario: MissingThrowsDocblock is not reported for exceptions of PHPUnit's own API
    Given Psalm checks for throws docblocks
    And I have the following code
      """
      /** @psalm-mutable */
      interface Repository {
        /** @psalm-impure */
        public function find(): int;
      }

      final class MyTestCase extends TestCase {
        public function testMockBuilder(): void {
          $mock = $this->getMockBuilder(Repository::class)
            ->onlyMethods(['find'])
            ->disableOriginalConstructor()
            ->getMock();
          $mock->method('find')->willReturn(1);
          $this->assertJson('{}');
        }

        public function testAssertionsAndMocks(): void {
          $repository = $this->createMock(Repository::class);
          $stub = $this->createStub(Repository::class);
          $this->assertSame(100, 100);
          self::assertCount(1, [$repository, $stub]);
          $this->assertXmlStringEqualsXmlString('<a/>', '<a/>');
          $this->assertXmlFileNotEqualsXmlFile('a.xml', 'b.xml');
          $this->assertInstanceOf(Repository::class, $repository);
        }

        public function testPhpUnitExceptionsOutsideTestMethods(): void {
          $this->helper();
        }

        /** @psalm-pure */
        public function testOtherExceptionsAreStillReported(): void {
          throw new \RuntimeException('boom');
        }

        private function helper(): void {
          $this->assertTrue(true);
          $this->createMock(Repository::class);
          $this->fail('boom');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                     |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation |
    And I see no other errors

  Scenario: Exceptions configured in ignoreExceptions are still ignored
    Given Psalm checks for throws docblocks
    And Psalm ignores the exception "DomainException"
    And I have the following code
      """
      final class MyTestCase extends TestCase {
        public function testIgnoredByUser(): void {
          $this->assertTrue(true);
          throw new \DomainException('boom');
        }

        /** @psalm-pure */
        public function testNotIgnored(): void {
          throw new \RuntimeException('boom');
        }
      }
      """
    When I run Psalm
    Then I see these errors
      | Type                  | Message                                                                                     |
      | MissingThrowsDocblock | RuntimeException is thrown but not caught - please either catch or add a @throws annotation |
    And I see no other errors
