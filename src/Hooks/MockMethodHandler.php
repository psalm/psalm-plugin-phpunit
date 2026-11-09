<?php

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Identifier;
use Psalm\CodeLocation;
use Psalm\Issue\UndefinedMethod;
use Psalm\IssueBuffer;
use Psalm\Plugin\EventHandler\AfterExpressionAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterExpressionAnalysisEvent;
use Psalm\Type\Atomic\TLiteralString;
use Psalm\Type\Atomic\TNamedObject;
use Psalm\Type\Union;

use function array_values;
use function count;
use function implode;
use function in_array;
use function sprintf;
use function strtolower;

/**
 * Reports ->method('name') on a test double when the doubled class has no such method:
 * PHPUnit throws MethodCannotBeConfiguredException for it at runtime.
 *
 * Methods declared with @method and methods served by __call() are accepted, as PHPUnit 11 has no way
 * to tell them apart from real ones in a type (the same trade-off phpstan-phpunit makes).
 */
final class MockMethodHandler implements AfterExpressionAnalysisInterface
{
    private const DOUBLE_CLASSES = [
        'phpunit\\framework\\mockobject\\mockobject',
        'phpunit\\framework\\mockobject\\stub',
    ];

    /** What expects() returns: PHPUnit 11 (Builder\*), PHPUnit 12 and 13 */
    private const EXPECTATION_BUILDERS = [
        'phpunit\\framework\\mockobject\\builder\\invocationmocker',
        'phpunit\\framework\\mockobject\\builder\\invocationstubber',
        'phpunit\\framework\\mockobject\\invocationmocker',
        'phpunit\\framework\\mockobject\\invocationstubber',
    ];

    #[\Override]
    public static function afterExpressionAnalysis(AfterExpressionAnalysisEvent $event): ?bool
    {
        $call = $event->getExpr();
        if (!$call instanceof MethodCall || !self::isNamed($call, 'method') || $call->isFirstClassCallable()) {
            return null;
        }

        $args = $call->getArgs();
        if (count($args) !== 1 || $args[0]->unpack || $args[0]->name !== null) {
            return null;
        }

        $source = $event->getStatementsSource();
        $typeProvider = $source->getNodeTypeProvider();

        // PHPUnit's expects() returns an InvocationMocker that no longer knows the doubled class
        $double = $call->var;
        if (
            $double instanceof MethodCall
            && self::isNamed($double, 'expects')
            && self::isExpectationBuilder($typeProvider->getType($double))
        ) {
            $double = $double->var;
        }

        $mockedClasses = self::mockedClasses($typeProvider->getType($double));
        $argType = $typeProvider->getType($args[0]->value);
        if ($mockedClasses === [] || $argType === null) {
            return null;
        }

        $codebase = $event->getCodebase();
        foreach ($mockedClasses as $mockedClass) {
            // a doubled class with its own method() is not configured through PHPUnit's method()
            if (
                !$codebase->classOrInterfaceExists($mockedClass)
                || $codebase->methodExists($mockedClass . '::method')
            ) {
                return null;
            }
        }

        $methodNames = [];
        foreach ($argType->getAtomicTypes() as $atomic) {
            if (!$atomic instanceof TLiteralString) {
                return null;
            }

            $methodNames[] = $atomic->value;
        }

        foreach ($methodNames as $methodName) {
            foreach ($mockedClasses as $mockedClass) {
                // No code location or source on purpose: mocking a method by name is not a call, so it must
                // not make the method "used" for dead code detection.
                if (
                    $codebase->methodExists($mockedClass . '::' . $methodName, with_pseudo: true)
                    || $codebase->methodExists($mockedClass . '::__call')
                ) {
                    continue 2;
                }
            }

            IssueBuffer::accepts(
                new UndefinedMethod(
                    sprintf('Trying to mock an undefined method %s::%s()', implode('&', $mockedClasses), $methodName),
                    new CodeLocation($source, $args[0]->value),
                    $mockedClasses[0] . '::' . $methodName,
                ),
                $source->getSuppressedIssues(),
            );
        }

        return null;
    }

    /**
     * @return list<string> the doubled classes of a "Foo&MockObject" / "Stub&Foo" type, or [] if it is not
     *                      a test double (or a union or template whose doubled classes are not known)
     * @psalm-pure
     */
    private static function mockedClasses(?Union $type): array
    {
        if ($type === null || !$type->isSingle()) {
            return [];
        }

        $atomic = $type->getSingleAtomic();
        if (!$atomic instanceof TNamedObject) {
            return [];
        }

        $isDouble = false;
        $mocked = [];
        foreach ([$atomic, ...array_values($atomic->getIntersectionTypes())] as $part) {
            if (!$part instanceof TNamedObject) {
                return [];
            }

            if (in_array(strtolower($part->value), self::DOUBLE_CLASSES, true)) {
                $isDouble = true;
            } else {
                $mocked[] = $part->value;
            }
        }

        return $isDouble ? $mocked : [];
    }

    /**
     * Tells PHPUnit's expectation builders apart from a domain class that has its own expects() and method().
     *
     * @psalm-pure
     */
    private static function isExpectationBuilder(?Union $type): bool
    {
        if ($type === null || !$type->isSingle()) {
            return false;
        }

        $atomic = $type->getSingleAtomic();

        return $atomic instanceof TNamedObject
            && in_array(strtolower($atomic->value), self::EXPECTATION_BUILDERS, true);
    }

    /**
     * @psalm-mutation-free
     */
    private static function isNamed(MethodCall $call, string $name): bool
    {
        return $call->name instanceof Identifier && strtolower($call->name->name) === $name;
    }
}
