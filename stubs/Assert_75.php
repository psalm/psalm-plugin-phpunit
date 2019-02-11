<?php // phpcs:ignoreFile
namespace PHPUnit\Framework;

abstract class Assert
{
    /**
     * @param mixed $actual
     * @psalm-assert array $actual
     */
    public static function assertIsArray($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert bool $actual
     */
    public static function assertIsBool($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert float $actual
     */
    public static function assertIsFloat($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert int $actual
     */
    public static function assertIsInt($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert numeric $actual
     */
    public static function assertIsNumeric($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert object $actual
     */
    public static function assertIsObject($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert resource $actual
     */
    public static function assertIsResource($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert string $actual
     */
    public static function assertIsString($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert scalar $actual
     */
    public static function assertIsScalar($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert callable $actual
     */
    public static function assertIsCallable($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert iterable $actual
     */
    public static function assertIsIterable($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !array $actual
     */
    public static function assertIsNotArray($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !bool $actual
     */
    public static function assertIsNotBool($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !float $actual
     */
    public static function assertIsNotFloat($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !int $actual
     */
    public static function assertIsNotInt($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !numeric $actual
     */
    public static function assertIsNotNumeric($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !object $actual
     */
    public static function assertIsNotObject($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !resource $actual
     */
    public static function assertIsNotResource($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !string $actual
     */
    public static function assertIsNotString($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !scalar $actual
     */
    public static function assertIsNotScalar($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !callable $actual
     */
    public static function assertIsNotCallable($actual, string $message = ''): void {}

    /**
     * @param mixed $actual
     * @psalm-assert !iterable $actual
     */
    public static function assertIsNotIterable($actual, string $message = ''): void {}

}
