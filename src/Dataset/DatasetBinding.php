<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Dataset;

use Psalm\Storage\FunctionLikeParameter;
use Psalm\Type;
use Psalm\Type\Atomic\TKeyedArray;
use Psalm\Type\Union;

use function array_filter;
use function array_values;
use function count;
use function is_string;

/**
 * How PHPUnit unpacks a dataset with string keys into the test call: int keys are positional, string keys name
 * a parameter (or, without a matching parameter, land in the variadic one).
 *
 * @psalm-immutable
 */
final class DatasetBinding
{
    /**
     * @param list<BoundArgument> $arguments entries bound to a parameter, to be checked against its type
     * @param list<string> $unknown names that match no parameter and no variadic parameter
     * @param list<string> $duplicate names of parameters that a positional entry has already filled
     * @param list<string> $missing required parameters that nothing in a sealed dataset can fill
     * @param bool $has_definite_named_key whether a string key is certainly present
     */
    public function __construct(
        public readonly array $arguments,
        public readonly array $unknown,
        public readonly array $duplicate,
        public readonly array $missing,
        public readonly bool $has_definite_named_key,
    ) {
    }

    /**
     * Only entries that are certainly present are reported as unknown or duplicate.
     *
     * @param list<FunctionLikeParameter> $params
     *
     * @psalm-capabilities read-props
     */
    public static function bind(TKeyedArray $dataset, array $params): self
    {
        $positional = [];
        $named      = [];
        foreach ($dataset->properties as $key => $type) {
            if (is_string($key)) {
                $named[$key] = $type;
            } else {
                $positional[] = $type;
            }
        }

        // array_merge() renumbers int keys, so a possibly undefined entry may shift the following ones:
        // only the certainly present entries are guaranteed to fill the first parameters.
        $definite_positional = count(array_filter(
            $positional,
            static fn (Union $type): bool => !$type->possibly_undefined,
        ));

        $offsets_by_name = [];
        $variadic_offset = null;
        $variadic_type   = Type::getMixed();
        foreach ($params as $offset => $param) {
            if ($param->is_variadic) {
                $variadic_offset = $offset;
                $variadic_type   = new Union(array_values(($param->type ?? Type::getMixed())->getAtomicTypes()));
                break;
            }
            $offsets_by_name[$param->name] = $offset;
        }

        $arguments = [];
        $unknown   = [];
        $duplicate = [];

        foreach ($positional as $position => $type) {
            if ($variadic_offset !== null && $position >= $variadic_offset) {
                $arguments[] = new BoundArgument($position, null, $type, $variadic_type, true);
            } elseif (isset($params[$position])) {
                $param       = $params[$position];
                $arguments[] = new BoundArgument(
                    $position,
                    null,
                    $type,
                    $param->type ?? Type::getMixed(),
                    $param->is_optional,
                );
            }
        }

        foreach ($named as $name => $type) {
            $offset = $offsets_by_name[$name] ?? null;

            if ($offset === null) {
                if ($variadic_offset !== null) {
                    $arguments[] = new BoundArgument($variadic_offset, $name, $type, $variadic_type, true);
                } elseif (!$type->possibly_undefined) {
                    $unknown[] = $name;
                }
            } elseif ($offset < $definite_positional) {
                if (!$type->possibly_undefined) {
                    $duplicate[] = $name;
                }
            } else {
                $param       = $params[$offset];
                $arguments[] = new BoundArgument(
                    $offset,
                    $name,
                    $type,
                    $param->type ?? Type::getMixed(),
                    $param->is_optional,
                );
            }
        }

        $missing = [];
        if ($dataset->isSealed()) {
            foreach ($params as $offset => $param) {
                if ($param->is_variadic) {
                    break;
                }
                if (!$param->is_optional && $offset >= count($positional) && !isset($named[$param->name])) {
                    $missing[] = $param->name;
                }
            }
        }

        return new self(
            $arguments,
            $unknown,
            $duplicate,
            $missing,
            array_filter($named, static fn (Union $type): bool => !$type->possibly_undefined) !== [],
        );
    }
}
