<?php

namespace PHPUnit\Framework;

abstract class Assert
{
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
     * @psalm-assert true $condition
     */
    public static function assertTrue($condition, $message = '') {}

    /**
     * Asserts that a condition is not true.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert !true $condition
     */
    public static function assertNotTrue($condition, $message = '') {}

    /**
     * Asserts that a condition is false.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert false $condition
     */
    public static function assertFalse($condition, $message = '') {}

    /**
     * Asserts that a condition is not false.
     *
     * @param bool   $condition
     * @param string $message
     *
     * @throws AssertionFailedError
     * @psalm-assert !false $condition
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
    
    /**
     * Asserts that two variables are the same.
     *
     * @template T
     * @param T      $expected
     * @param mixed  $actual
     * @psalm-assert =T $actual
     */
    function assertSame($expected, $actual) : void {}
    
    /**
     * Asserts that two variables are loosely equal to each other
     *
     * @template T
     * @param T      $expected
     * @param mixed  $actual
     * @psalm-assert ~T $actual
     */
    function assertEquals($expected, $actual) : void {}
}
