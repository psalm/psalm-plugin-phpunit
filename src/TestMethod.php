<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use Psalm\Internal\Analyzer\ClassLikeAnalyzer;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Storage\MethodStorage;

/**
 * PHPUnit only runs public methods as tests, whatever their name or #[Test] says.
 */
final class TestMethod
{
    /**
     * A trait method has the visibility the class imports it with.
     *
     * @param lowercase-string $name_lc the name the class knows the method by
     *
     * @psalm-mutation-free
     */
    public static function isPublic(ClassLikeStorage $class, MethodStorage $method, string $name_lc): bool
    {
        $visibility = $class->trait_visibility_map[$name_lc] ?? $method->visibility;

        return $visibility === ClassLikeAnalyzer::VISIBILITY_PUBLIC;
    }
}
