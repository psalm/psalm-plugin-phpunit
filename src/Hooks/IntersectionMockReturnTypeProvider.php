<?php

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Arg;
use PHPUnit\Framework\TestCase;
use Psalm\Plugin\EventHandler\Event\MethodReturnTypeProviderEvent;
use Psalm\Plugin\EventHandler\MethodReturnTypeProviderInterface;
use Psalm\Type\Atomic\TKeyedArray;
use Psalm\Type\Atomic\TLiteralClassString;
use Psalm\Type\Atomic\TNamedObject;
use Psalm\Type\Union;

use function array_key_first;
use function count;
use function strtolower;

/**
 * Types createMockForIntersectionOfInterfaces() and createStubForIntersectionOfInterfaces() as
 * `A&B&MockObject` and `A&B&Stub` when the interfaces are given as a literal list of `X::class`.
 */
final class IntersectionMockReturnTypeProvider implements MethodReturnTypeProviderInterface
{
    private const DOUBLE_CLASSES = [
        'createmockforintersectionofinterfaces' => 'PHPUnit\\Framework\\MockObject\\MockObject',
        'createstubforintersectionofinterfaces' => 'PHPUnit\\Framework\\MockObject\\Stub',
    ];

    /**
     * @return list<string>
     * @psalm-pure
     */
    #[\Override]
    public static function getClassLikeNames(): array
    {
        return [TestCase::class];
    }

    #[\Override]
    public static function getMethodReturnType(MethodReturnTypeProviderEvent $event): ?Union
    {
        $doubleClass = self::DOUBLE_CLASSES[$event->getMethodNameLowercase()] ?? null;
        $call = $event->getStmt();
        if ($doubleClass === null || $call->isFirstClassCallable()) {
            return null;
        }

        $args = $call->getArgs();
        if (count($args) !== 1) {
            return null;
        }

        /** @var Arg $arg */
        $arg = $args[0];
        if ($arg->unpack || ($arg->name !== null && strtolower($arg->name->name) !== 'interfaces')) {
            return null;
        }

        $argType = $event->getSource()->getNodeTypeProvider()->getType($arg->value);
        if ($argType === null || !$argType->isSingle()) {
            return null;
        }

        $list = $argType->getSingleAtomic();
        if (!$list instanceof TKeyedArray || !$list->isSealed() || count($list->properties) < 2) {
            return null;
        }

        $names = [];
        foreach ($list->properties as $property) {
            $element = $property->possibly_undefined || !$property->isSingle() ? null : $property->getSingleAtomic();
            if (!$element instanceof TLiteralClassString || isset($names[$element->value])) {
                return null;
            }

            $names[$element->value] = new TNamedObject($element->value);
        }

        $names[$doubleClass] = new TNamedObject($doubleClass);
        $head = array_key_first($names);
        unset($names[$head]);

        return new Union([new TNamedObject($head, extra_types: $names)]);
    }
}
