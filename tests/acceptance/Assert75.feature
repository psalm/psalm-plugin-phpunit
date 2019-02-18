Feature: Assert (PHPUnit 7.5+)
  In order to use PHPUnit safely
  As a Psalm user
  I need Psalm to typecheck asserts

  Background:
    Given I have the following config
      """
      <?xml version="1.0"?>
      <psalm>
        <projectFiles><directory name="." /></projectFiles>
        <plugins>
          <pluginClass class="Psalm\PhpUnitPlugin\Plugin"/>
        </plugins>
      </psalm>
      """
    And I have the following code preamble
      """
      <?php
      namespace NS;
      use PHPUnit\Framework\Assert;

      /** 
       * @return mixed 
       * @psalm-suppress InvalidReturnType
       */
      function mixed() {}

      """
    And I have PHPUnit newer than "7.4.99999" (because of "new features in 7.5")

  Scenario: Assert::assertIsArray()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $a = mixed();
      Assert::assertIsArray($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsBool()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $b = mixed();

      Assert::assertIsBool($b);
      microtime($b);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsFloat()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $f = mixed();

      Assert::assertIsFloat($f);
      atan($f);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsInt()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $i = mixed();

      Assert::assertIsInt($i);
      substr('foo', $i);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNumeric()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $n = mixed();

      Assert::assertIsNumeric($n);
      $n + $n;
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsObject()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $o = mixed();

      Assert::assertIsObject($o);
      $o->foo = 1;
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsResource()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $r = mixed();

      Assert::assertIsResource($r);
      get_resource_type($r);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsString()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $s = mixed();

      Assert::assertIsString($s);
      strlen($s);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsScalar()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $s = mixed();

      Assert::assertIsScalar($s); // int|string|float|bool
      // all of the following should cause errors
      if (is_array($s)) {}
      if (is_resource($s)) {}
      if (is_object($s)) {}
      if (is_null($s)) {}
      """
    When I run Psalm
    Then I see these errors
      | Type                      | Message                                                                                                               |
      | DocblockTypeContradiction | Cannot resolve types for $s - docblock-defined type scalar does not contain array<%, mixed>                           |
      | DocblockTypeContradiction | Cannot resolve types for $s - docblock-defined type scalar does not contain resource                                  |
      | DocblockTypeContradiction | Found a contradiction with a docblock-defined type when evaluating $s and trying to reconcile type 'scalar' to object |
      | DocblockTypeContradiction | Cannot resolve types for $s - docblock-defined type scalar does not contain null                                      |

  Scenario: Assert::assertIsCallable()
    Given I have the following code
      """
      /** @psalm-suppress MixedAssignment */
      $s = mixed();

      Assert::assertIsCallable($s);
      \Closure::fromCallable($s);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsIterable()
    Given I have the following code
      """
      /** @return iterable */
      function () {
        /** @psalm-suppress MixedAssignment */
        $s = mixed();

        Assert::assertIsIterable($s);
        return $s;
      };
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotArray()
    Given I have the following code
      """
      $i = rand(0, 1) ? 1 : [1];
      Assert::assertIsNotArray($i);
      substr("foo", $i);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotBool()
    Given I have the following code
      """
      $i = rand(0, 1) ? 1 : true;
      Assert::assertIsNotBool($i);
      substr("foo", $i);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotFloat()
    Given I have the following code
      """
      $i = rand(0, 1) ? 1 : 0.1;
      Assert::assertIsNotFloat($i);
      substr("foo", $i);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotInt()
    Given I have the following code
      """
      $a = rand(0, 1) ? 1 : [1];
      Assert::assertIsNotInt($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotNumeric()
    Given I have the following code
      """
      /** @return numeric|array */
      function f() { return rand(0,1) ? 1 : [1]; }
      $a = f();
      Assert::assertIsNotNumeric($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotObject()
    Given I have the following code
      """
      $a = rand(0, 1) ? ((object)[]) : [1];
      Assert::assertIsNotObject($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotResource()
    Given I have the following code
      """
      $a = rand(0, 1) ? STDIN : [1];
      Assert::assertIsNotResource($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotString()
    Given I have the following code
      """
      $a = rand(0, 1) ? "foo" : [1];
      Assert::assertIsNotString($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotScalar()
    Given I have the following code
      """
      $a = rand(0, 1) ? "foo" : [1];
      Assert::assertIsNotScalar($a);
      array_pop($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotCallable()
    Given I have the following code
      """
      /** @return callable|float */
      function f() { return rand(0,1) ? 'f' : 1.1; }
      $a = f();
      Assert::assertIsNotCallable($a);
      atan($a);
      """
    When I run Psalm
    Then I see no errors

  Scenario: Assert::assertIsNotIterable()
    Given I have the following code
      """
      /** @var string|iterable $s */
      $s = rand(0, 1) ? "foo" : [1];
      Assert::assertIsNotIterable($s);
      strlen($s);
      """
    When I run Psalm
    Then I see no errors

