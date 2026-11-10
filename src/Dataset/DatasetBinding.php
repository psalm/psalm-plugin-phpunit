<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Dataset;

use Psalm\Codebase;
use Psalm\Storage\FunctionLikeParameter;
use Psalm\Storage\MethodStorage;
use Psalm\Type;
use Psalm\Type\Atomic\TKeyedArray;
use Psalm\Type\Union;

/**
 * How PHPUnit unpacks a dataset with string keys into the test call: int keys are positional, string keys name
 * a parameter (or, without a matching parameter, land in the variadic one).
 */
final class DatasetBinding
{
    /**
     * @param list<BoundArgument> $arguments entries bound to a parameter, to be checked against its type
     * @param list<string> $unknown names that match no parameter and no variadic parameter
     * @param list<string> $duplicate names of parameters that a positional entry has already filled
     * @param list<string> $missing required parameters that nothing in a sealed dataset can fill
     */
    public function __construct(
        public readonly array $arguments,
        public readonly array $unknown,
        public readonly array $duplicate,
        public readonly array $missing,
    ) {}

    /**
     * Only entries that are certainly present are reported as unknown or duplicate. An int-keyed entry is bound to
     * a parameter only if every position it can land in, given the entries that may be absent before it, belongs to
     * that parameter.
     *
     * @param list<FunctionLikeParameter> $params
     * @param Codebase $codebase decides whether the values of an unsealed dataset can fill missing parameters
     * @param MethodStorage|null $method owns the templates that the parameter types may use
     */
    public static function bind(
        TKeyedArray $dataset,
        array $params,
        Codebase $codebase,
        ?MethodStorage $method = null,
    ): self {
        $positional = [];
        $named = [];
        foreach ($dataset->properties as $key => $type) {
            if (\is_string($key)) {
                $named[$key] = $type;
            } else {
                $positional[] = $type;
            }
        }

        // array_merge() renumbers int keys, so a possibly undefined entry may shift the following ones:
        // only the certainly present entries are guaranteed to fill the first parameters.
        $definite_positional = \count(\array_filter(
            $positional,
            static fn(Union $type): bool => !$type->possibly_undefined,
        ));

        $offsets_by_name = [];
        $variadic_offset = null;
        $variadic_type = Type::getMixed();
        foreach ($params as $offset => $param) {
            if ($param->is_variadic) {
                $variadic_offset = $offset;
                $variadic_type = new Union(\array_values(($param->type ?? Type::getMixed())->getAtomicTypes()));
                break;
            }
            $offsets_by_name[$param->name] = $offset;
        }

        $arguments = [];
        $unknown = [];
        $duplicate = [];

        // The parameter an offset maps to: every offset from the variadic one on lands in the variadic parameter.
        $slot = static fn(int $offset): int => $variadic_offset !== null && $offset >= $variadic_offset
            ? $variadic_offset
            : $offset;

        // The offset of the possibly undefined entry that decides alone whether its parameter is provided
        $optional_offset = null;
        $definite_before = 0;

        foreach ($positional as $index => $type) {
            // array_merge() renumbers int keys: an entry lands at the position after the entries certainly present
            // before it at the earliest, and at its own index at the latest. Bind it only if that range is within
            // one parameter (the first possibly undefined entry always is).
            $lowest = $definite_before;
            $definite_before += $type->possibly_undefined ? 0 : 1;
            if ($slot($lowest) !== $slot($index)) {
                continue;
            }

            if ($variadic_offset !== null && $index >= $variadic_offset) {
                $arguments[] = new BoundArgument($index, null, $type, $variadic_type, true);
            } elseif (isset($params[$index])) {
                $param = $params[$index];
                if ($type->possibly_undefined) {
                    // a later entry takes its place if it is absent, and the named entry supplies it either way
                    if ($index < $definite_positional || isset($named[$param->name])) {
                        $type = $type->setPossiblyUndefined(false);
                    } else {
                        $optional_offset = $index;
                    }
                }
                $arguments[] = new BoundArgument(
                    $index,
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
                $param = $params[$offset];
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
        foreach ($params as $offset => $param) {
            if ($param->is_variadic) {
                break;
            }
            if (
                !$param->is_optional
                && $offset >= $definite_positional
                && $offset !== $optional_offset
                && !isset($named[$param->name])
                && !self::mayBeSuppliedByFallback($codebase, $method, $dataset, $param)
            ) {
                $missing[] = $param->name;
            }
        }

        return new self($arguments, $unknown, $duplicate, $missing);
    }

    /**
     * An unsealed dataset may carry further string keys, which can supply the parameter if one of them can be named
     * after it and its value can be passed to it.
     */
    private static function mayBeSuppliedByFallback(
        Codebase $codebase,
        ?MethodStorage $method,
        TKeyedArray $dataset,
        FunctionLikeParameter $param,
    ): bool {
        if ($dataset->fallback_params === null) {
            return false;
        }

        [$key_type, $value_type] = $dataset->fallback_params;
        $param_type = $param->type ?? Type::getMixed();

        return $codebase->canTypeBeContainedByType(Type::getString($param->name), $key_type)
            && $codebase->canTypeBeContainedByType(
                $value_type,
                $method === null
                    ? $param_type
                    : TemplateInference::resolve($codebase, $method, $param_type, $value_type),
            );
    }
}
