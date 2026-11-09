<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Expr\ArrowFunction;
use PhpParser\Node\Expr\Closure;
use Psalm\Internal\Analyzer\MethodAnalyzer;
use Psalm\Plugin\EventHandler\AfterExpressionAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterExpressionAnalysisEvent;
use Psalm\Storage\MethodStorage;
use Psalm\Type\Atomic\TClosure;
use Psalm\Type\Union;
use WeakMap;

/**
 * Psalm analyses the closure of a #[DataProviderClosure(...)] argument but throws the node types away, so the
 * return type of each closure in an attribute of a method is kept by the start offset of the closure in its file.
 *
 * A method's attributes and its class are analysed by the same process, and custom_metadata only holds scalars,
 * so the types are kept per method storage here.
 */
final class DataProviderClosureHandler implements AfterExpressionAnalysisInterface
{
    /** @var WeakMap<MethodStorage, array<int, Union>>|null */
    private static ?WeakMap $returnTypes = null;

    public static function returnType(MethodStorage $storage, int $position): ?Union
    {
        $types = self::$returnTypes === null ? [] : (self::$returnTypes[$storage] ?? []);

        return $types[$position] ?? null;
    }

    #[\Override]
    public static function afterExpressionAnalysis(AfterExpressionAnalysisEvent $event): ?bool
    {
        $closure = $event->getExpr();
        if (
            !($closure instanceof Closure || $closure instanceof ArrowFunction)
            || !$event->getContext()->inside_attribute
        ) {
            return null;
        }

        $statements_source = $event->getStatementsSource();
        $method_analyzer   = $statements_source->getSource();
        if (!$method_analyzer instanceof MethodAnalyzer) {
            return null;
        }

        $storage = $method_analyzer->getFunctionLikeStorage();
        if (!$storage instanceof MethodStorage) {
            return null;
        }

        $return_type = null;
        foreach ($statements_source->getNodeTypeProvider()->getType($closure)?->getAtomicTypes() ?? [] as $atomic) {
            if ($atomic instanceof TClosure) {
                $return_type = $atomic->return_type;
            }
        }

        if ($return_type === null) {
            return null;
        }

        self::$returnTypes ??= new WeakMap();
        $types = self::$returnTypes[$storage] ?? [];

        $types[$closure->getStartFilePos()] = $return_type;
        self::$returnTypes[$storage]        = $types;

        return null;
    }
}
