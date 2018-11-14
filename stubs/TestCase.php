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
}