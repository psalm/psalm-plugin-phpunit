<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use Psalm\Codebase;
use Psalm\Internal\Analyzer\MethodAnalyzer;
use Psalm\PhpUnitPlugin\Dataset\DatasetBinding;
use Psalm\Plugin\EventHandler\BeforeStatementAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\BeforeStatementAnalysisEvent;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Storage\FunctionLikeParameter;
use Psalm\Storage\MethodStorage;
use Psalm\Type;
use Psalm\Type\Atomic\TArray;
use Psalm\Type\Atomic\TKeyedArray;
use Psalm\Type\Atomic\TNull;
use Psalm\Type\Union;

/**
 * Narrows the parameters of a test method to the types its data providers return, so that a provider returning
 * array{int, string} makes $a an int and $b a string instead of mixed.
 */
final class DataProviderNarrowingHandler implements BeforeStatementAnalysisInterface
{
    public const METADATA_KEY = self::class;

    private const TEST_CASE = 'PHPUnit\\Framework\\TestCase';

    /** @var \WeakMap<object, bool>|null */
    private static ?\WeakMap $visited = null;

    #[\Override]
    public static function beforeStatementAnalysis(BeforeStatementAnalysisEvent $event): ?bool
    {
        $statements_source = $event->getStatementsSource();
        $method_analyzer = $statements_source->getSource();
        if (!$method_analyzer instanceof MethodAnalyzer) {
            return null;
        }

        // Only the first statement of the method sees the context that holds the parameters
        if (self::$visited === null) {
            /** @var \WeakMap<object, bool> $visited */
            $visited = new \WeakMap();
            self::$visited = $visited;
        }
        if (isset(self::$visited[$statements_source])) {
            return null;
        }
        self::$visited[$statements_source] = true;

        $context = $event->getContext();
        $codebase = $event->getCodebase();
        $storage = $method_analyzer->getFunctionLikeStorage();
        if (!$storage instanceof MethodStorage) {
            return null;
        }

        $metadata = $storage->custom_metadata[self::METADATA_KEY] ?? null;
        $self = $context->self;
        if (!\is_array($metadata) || $self === null || !$codebase->classExtends($self, self::TEST_CASE)) {
            return null;
        }

        $method_id = (string) $method_analyzer->getMethodId();
        $marked = (bool) $metadata['test'];
        $class = $codebase->classlike_storage_provider->get($self);
        if (!self::isTest($codebase, $class, $storage, $method_id, $marked)) {
            return null;
        }

        /** @var list<array{string, string}> $providers */
        $providers = $metadata['providers'];

        $provided = self::providedTypes($codebase, $self, $providers, $storage->params, (bool) $metadata['depends']);
        foreach ($storage->params as $offset => $param) {
            $var_id = '$' . $param->name;
            $old = $context->vars_in_scope[$var_id] ?? null;
            $type = $provided[$offset] ?? null;
            if ($old === null || $type === null || $type->isNever() || $param->by_ref || $old->hasTemplate()) {
                continue;
            }

            // Allowing int for float would turn the int a provider returns into the float PHPUnit passes
            $narrower = $codebase->isTypeContainedByType($type, $old, false, false, false, false);
            if ($narrower && $type->getId() !== $old->getId()) {
                $context->vars_in_scope[$var_id] = $type->setParentNodes($old->parent_nodes);
            }
        }

        return null;
    }

    /**
     * The type every provider of the test passes to a required parameter, by parameter offset.
     *
     * @param list<array{string, string}> $providers
     * @param list<FunctionLikeParameter> $params
     * @return array<int, Union>
     */
    private static function providedTypes(
        Codebase $codebase,
        string $self,
        array $providers,
        array $params,
        bool $has_dependencies,
    ): array {
        /** @var array<int, Union>|null $types */
        $types = null;
        foreach ($providers as [$class, $method]) {
            $dataset_type = self::datasetType($codebase, $class === '' ? $self : $class, $method);
            if ($dataset_type === null) {
                return [];
            }

            $bound = self::bind($codebase, $dataset_type, $params, $has_dependencies);
            if ($types === null) {
                $types = $bound;
                continue;
            }

            // a parameter is only narrowed when every provider proves what it receives
            foreach ($types as $offset => $type) {
                if (isset($bound[$offset])) {
                    $types[$offset] = Type::combineUnionTypes($type, $bound[$offset], $codebase);
                } else {
                    unset($types[$offset]);
                }
            }
        }

        return $types ?? [];
    }

    /**
     * PHPUnit runs public methods named test* or marked as tests. A trait method is a test under the name the class
     * imports it with.
     */
    private static function isTest(
        Codebase $codebase,
        ClassLikeStorage $class,
        MethodStorage $method,
        string $method_id,
        bool $marked,
    ): bool {
        $method_id = \strtolower($method_id);
        foreach ($class->declaring_method_ids as $name => $declaring_id) {
            if (\strtolower((string) $declaring_id) !== $method_id) {
                continue;
            }

            if (
                ($marked || \str_starts_with(self::casedName($class, $method, $name), 'test'))
                && TestCaseHandler::isPublicMethod($codebase, $class, $method, $name)
            ) {
                return true;
            }
        }

        return false;
    }

    /**
     * @param lowercase-string $name
     *
     * @psalm-mutation-free
     */
    private static function casedName(ClassLikeStorage $class, MethodStorage $method, string $name): string
    {
        foreach ($class->trait_alias_map_cased as $alias => $_) {
            if (\strtolower($alias) === $name) {
                return $alias;
            }
        }

        return $method->cased_name ?? $name;
    }

    /**
     * Shape of the datasets a provider yields, or null when it is not known precisely.
     */
    private static function datasetType(Codebase $codebase, string $class, string $method): TArray|TKeyedArray|null
    {
        if (!$codebase->classOrInterfaceExists($class)) {
            return null;
        }

        $method_id = $codebase->getDeclaringMethodId($class . '::' . $method);
        if ($method_id === null) {
            return null;
        }

        $overridden_class = null;
        $return_type = $codebase->getMethodReturnType($method_id, $overridden_class);
        if ($return_type === null) {
            return null;
        }

        $return_type = TestCaseHandler::expandForMethod($codebase, $return_type, $class . '::' . $method, $class);
        if ($return_type->hasTemplate()) {
            return null;
        }

        // PHPUnit treats a null return as no datasets
        $iterables = [];
        foreach ($return_type->getAtomicTypes() as $atomic) {
            if ($atomic instanceof TNull) {
                continue;
            }
            if (!$atomic->isIterable($codebase)) {
                return null;
            }
            $iterables[] = $atomic;
        }
        if ($iterables === []) {
            return null;
        }

        $datasets = TestCaseHandler::unionizeIterables($codebase, new Union($iterables))->type_params[1];
        $dataset = $datasets->isSingle() ? $datasets->getSingleAtomic() : null;

        return $dataset instanceof TArray || $dataset instanceof TKeyedArray ? $dataset : null;
    }

    /**
     * The type PHPUnit passes to each required parameter for every dataset of the shape, by parameter offset.
     * PHPUnit fails a test that lacks a required parameter before calling it, so such datasets do not matter.
     * A parameter with a default is left out, as the dataset may leave it to the default.
     *
     * @param list<FunctionLikeParameter> $params
     * @return array<int, Union>
     */
    private static function bind(
        Codebase $codebase,
        TArray|TKeyedArray $dataset,
        array $params,
        bool $has_dependencies,
    ): array {
        $bound = [];
        if ($dataset instanceof TArray) {
            // the return values of depended-upon tests may fill the parameters after a short dataset
            if (!$has_dependencies) {
                foreach ($params as $offset => $param) {
                    if (!$param->is_optional && !$param->is_variadic) {
                        $bound[$offset] = $dataset->type_params[1];
                    }
                }
            }

            return $bound;
        }

        // PHPUnit appends the return values of depended-upon tests, which cannot follow named arguments
        if ($has_dependencies && TestCaseHandler::hasStringKeys($dataset, true)) {
            return [];
        }

        foreach (DatasetBinding::bind($dataset, $params, $codebase)->arguments as $argument) {
            // Outside a list, the declared order of int keys need not be the order of the entries. In a list,
            // only trailing entries may be undefined, so a defined entry is always at its position.
            $position_is_known = $argument->name !== null || $dataset->is_list;
            if ($position_is_known && !$argument->is_optional && !$argument->type->possibly_undefined) {
                $bound[$argument->position] = $argument->type;
            }
        }

        return $bound;
    }
}
