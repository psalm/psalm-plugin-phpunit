<?php
namespace PHPUnit\Framework;

use PHPUnit\Framework\MockObject\MockObject;
use PHPUnit\Framework\MockObject\MockBuilder;

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
     * Returns a builder object to create mock objects using a fluent interface.
     *
     * @template T
     * @template-typeof T $className
     * @param class-string $className
     *
     * @return MockBuilder<T>
     */
    public function getMockBuilder(string $className) {}

    /**
     * @template T
     * @template-typeof T $classOrInterface
     * @param class-string $classOrInterface
     * @return ObjectProphecy<T>
     */
    public function prophesize($classOrInterface): ObjectProphecy {}
}
