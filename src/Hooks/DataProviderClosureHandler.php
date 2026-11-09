<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Expr\ArrowFunction;
use PhpParser\Node\Expr\Closure;
use Psalm\Internal\Analyzer\MethodAnalyzer;
use Psalm\Plugin\EventHandler\AfterExpressionAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterExpressionAnalysisEvent;
use Psalm\Type\Atomic\TClosure;
use Psalm\Type\Union;

/**
 * Psalm analyses the closure of a #[DataProviderClosure(...)] argument but throws the node types away, so the
 * return type of each closure in an attribute of a method is kept in the method's storage, by the start offset of
 * the closure in its file.
 */
final class DataProviderClosureHandler implements AfterExpressionAnalysisInterface
{
    public const METADATA_KEY = self::class;

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

        $return_type = null;
        foreach ($statements_source->getNodeTypeProvider()->getType($closure)?->getAtomicTypes() ?? [] as $atomic) {
            if ($atomic instanceof TClosure) {
                $return_type = $atomic->return_type;
            }
        }

        if ($return_type === null) {
            return null;
        }

        $storage  = $method_analyzer->getFunctionLikeStorage();
        $metadata = $storage->custom_metadata[self::METADATA_KEY] ?? [];

        /** @var array<int, Union> $metadata */
        $metadata[$closure->getStartFilePos()] = $return_type;
        $storage->custom_metadata[self::METADATA_KEY] = $metadata;

        return null;
    }
}
