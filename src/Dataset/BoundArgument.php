<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Dataset;

use Psalm\Type\Union;

/**
 * A dataset entry bound to the parameter that receives it.
 *
 * @psalm-immutable
 */
final class BoundArgument
{
    /**
     * @param int $position 0-based position of the receiving parameter. Entries collected by a variadic
     *                      parameter are reported at their own dataset position when positional, and at the
     *                      variadic parameter's position when named.
     * @param string|null $name key of a named entry
     */
    public function __construct(
        public readonly int $position,
        public readonly ?string $name,
        public readonly Union $type,
        public readonly Union $param_type,
        public readonly bool $is_optional,
    ) {
    }
}
