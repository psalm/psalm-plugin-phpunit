<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Expr\Yield_;
use PhpParser\Node\Expr\YieldFrom;
use PhpParser\Node\Stmt\ClassMethod;
use PhpParser\NodeFinder;
use Psalm\Internal\Analyzer\FunctionLike\ReturnTypeCollector;
use Psalm\Internal\Provider\NodeDataProvider;
use Psalm\Internal\TypeVisitor\TypeVariableResolver;
use Psalm\Plugin\EventHandler\AfterFunctionLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterFunctionLikeAnalysisEvent;
use Psalm\Storage\MethodStorage;
use Psalm\Type\Atomic\TGenericObject;
use Psalm\Type\Atomic\TKeyedArray;
use Psalm\Type\Atomic\TMixed;
use Psalm\Type\Atomic\TNever;
use Psalm\Type\Atomic\TNull;
use Psalm\Type\TypeNode;
use Psalm\Type\TypeVisitor;
use Psalm\Type\Union;

/**
 * A data provider with only a native return type (`iterable`, `array`, `Generator`) has no `@return` type to check
 * its datasets against, so the datasets Psalm infers from the body of the provider are kept: one type for each
 * `yield` and for each element of a returned array shape, so that datasets of different shapes are not merged.
 *
 * The storage of a method of a trait is shared by all the classes using it, and the types kept are the ones of the
 * class analysed last. Only read them while a class is analysed that has just analysed the method itself.
 */
final class ProviderReturnTypeHandler implements AfterFunctionLikeAnalysisInterface
{
    /** @var \WeakMap<object, list<Union>>|null */
    private static ?\WeakMap $inferredTypes = null;

    /** Whether the return type of the provider is its native one, with no docblock to override it */
    public static function hasNativeReturnTypeOnly(MethodStorage $storage): bool
    {
        return $storage->signature_return_type !== null
            && !$storage->has_docblock_return_type
            && $storage->inherited_return_type !== true;
    }

    /** @return list<Union>|null the type of each dataset, null when they could not be inferred */
    public static function inferredTypes(MethodStorage $storage): ?array
    {
        return self::$inferredTypes[$storage] ?? null;
    }

    #[\Override]
    public static function afterStatementAnalysis(AfterFunctionLikeAnalysisEvent $event): ?bool
    {
        $method  = $event->getStmt();
        $storage = $event->getFunctionlikeStorage();
        $nodes   = $event->getNodeTypeProvider();
        if (
            !$method instanceof ClassMethod
            || !$method->isStatic()
            || !$storage instanceof MethodStorage
            || !$nodes instanceof NodeDataProvider
            || !self::hasNativeReturnTypeOnly($storage)
        ) {
            return null;
        }

        if (self::$inferredTypes === null) {
            /** @var \WeakMap<object, list<Union>> $types */
            $types               = new \WeakMap();
            self::$inferredTypes = $types;
        }

        unset(self::$inferredTypes[$storage]);

        $codebase   = $event->getCodebase();
        $statements = $method->stmts ?? [];

        $finder = new NodeFinder();
        // Psalm drops what a `yield from` yields
        if ($finder->findFirstInstanceOf($statements, YieldFrom::class) !== null) {
            return null;
        }

        $yield_types  = [];
        $return_types = ReturnTypeCollector::getReturnTypes($codebase, $nodes, $statements, $yield_types);

        $datasets = [];
        if ($finder->findFirstInstanceOf($statements, Yield_::class) !== null) {
            foreach ($yield_types as $yield_type) {
                $generator = $yield_type->isSingle() ? $yield_type->getSingleAtomic() : null;
                if (!$generator instanceof TGenericObject || $generator->value !== 'Generator') {
                    return null;
                }

                $datasets[] = $yield_type;
            }
        } else {
            foreach ($return_types as $return_type) {
                foreach ($return_type->getAtomicTypes() as $atomic) {
                    // `null` is an empty set of datasets, and a guard that throws or skips the test returns nothing
                    if ($atomic instanceof TNull || $atomic instanceof TNever) {
                        continue;
                    }

                    // Anything else than iterables is reported as a wrong return type, which is not known here
                    if (!$atomic->isIterable($codebase)) {
                        return null;
                    }

                    if (!$atomic instanceof TKeyedArray || $atomic->fallback_params !== null) {
                        $datasets[] = new Union([$atomic]);
                        continue;
                    }

                    foreach ($atomic->properties as $key => $dataset) {
                        $datasets[] = new Union([
                            TKeyedArray::make([$key => $dataset->setPossiblyUndefined(false)]),
                        ]);
                    }
                }
            }
        }

        if ($datasets === []) {
            return null;
        }

        $resolver = new TypeVariableResolver($codebase);
        foreach ($datasets as $offset => $dataset) {
            $resolver->traverse($dataset);

            // What is not known about the datasets is not reported, a @return type is asked for instead
            if (self::hasMixed($dataset)) {
                return null;
            }

            $datasets[$offset] = $dataset;
        }

        self::$inferredTypes[$storage] = $datasets;

        return null;
    }

    private static function hasMixed(Union $type): bool
    {
        $visitor = new class extends TypeVisitor {
            public bool $found = false;

            /** @psalm-external-mutation-free */
            #[\Override]
            protected function enterNode(TypeNode $type): ?int
            {
                if ($type instanceof TMixed) {
                    $this->found = true;

                    return self::STOP_TRAVERSAL;
                }

                return null;
            }
        };

        // The last two parameters of a Generator are not the ones of the datasets
        foreach ($type->getAtomicTypes() as $atomic) {
            if ($atomic instanceof TGenericObject && $atomic->value === 'Generator') {
                $visitor->traverse($atomic->type_params[0]);
                $visitor->traverse($atomic->type_params[1]);
            } else {
                $visitor->traverse($atomic);
            }
        }

        return $visitor->found;
    }
}
