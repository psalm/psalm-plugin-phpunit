<?php

namespace PHPUnit\Framework;

use PHPUnit\Framework\MockObject\MockObject;

abstract class TestCase extends Assert implements Test, SelfDescribing
{
    /**
     * @template T
     * @template-typeof T $class
     * @param class-string $class
     * @return MockObject&T
     */
    public function createMock($class) {}

    /**
     * Asserts that a variable is of a given type.
     *
     * @param class-string $expected
     * @param mixed  $actual
     * @param string $message
     *
     * @template T
     * @template-typeof T $expected
     * @psalm-assert T $actual
     */
    public static function assertInstanceOf($expected, $actual, $message = '') {}

    /**
     * Asserts that a variable is of a given type.
     *
     * @param class-string $expected
     * @param mixed  $actual
     * @param string $message
     *
     * @template T
     * @template-typeof T $expected
     * @psalm-assert !T $actual
     */
    public static function assertNotInstanceOf($expected, $actual, $message = '') {}

    /**
     * Asserts that a condition is true.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert true $actual
     */
    public static function assertTrue($condition, $message = '') {}

    /**
     * Asserts that a condition is not true.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert !true $actual
     */
    public static function assertNotTrue($condition, $message = '') {}

    /**
     * Asserts that a condition is false.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert false $actual
     */
    public static function assertFalse($condition, $message = '') {}

    /**
     * Asserts that a condition is not false.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert !false $actual
     */
    public static function assertNotFalse($condition, $message = '') {}

    /**
     * Asserts that a variable is null.
     *
     * @param mixed  $actual
     * @param string $message
     * @psalm-assert null $actual
     */
    public static function assertNull($actual, $message = '') {}

    /**
     * Asserts that a variable is not null.
     *
     * @param mixed  $actual
     * @param string $message
     * @psalm-assert !null $actual
     */
    public static function assertNotNull($actual, $message = '') {}
}