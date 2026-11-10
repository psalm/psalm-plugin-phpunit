<?php

namespace Psalm\PhpUnitPlugin\Hooks;

use Iterator;
use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Identifier;
use Psalm\Codebase;
use Psalm\CodeLocation;
use Psalm\Issue\UndefinedMethod;
use Psalm\IssueBuffer;
use Psalm\Plugin\EventHandler\AfterExpressionAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterExpressionAnalysisEvent;
use Psalm\Type\Atomic;
use Psalm\Type\Atomic\TNamedObject;
use Psalm\Type\Union;
use Traversable;

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
        if (\count($args) !== 1 || $args[0]->unpack || $args[0]->name !== null) {
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

        $doubleType = $typeProvider->getType($double);
        $argType = $typeProvider->getType($args[0]->value);
        if ($doubleType === null || $argType === null || !$argType->allStringLiterals()) {
            return null;
        }

        $codebase = $event->getCodebase();
        // any member of a union can be the runtime object, so each one has to define the method
        foreach ($doubleType->getAtomicTypes() as $doubleAtomic) {
            $mockedClasses = self::mockedClasses($doubleAtomic);
            if ($mockedClasses === []) {
                continue;
            }

            foreach ($mockedClasses as $mockedClass) {
                // a doubled class with its own method() is not configured through PHPUnit's method()
                if (
                    !$codebase->classOrInterfaceExists($mockedClass)
                    || $codebase->methodExists($mockedClass . '::method')
                ) {
                    continue 2;
                }
            }

            // PHPUnit adds Iterator's methods to a double of Traversable and of an interface that extends only it
            $lookupClasses = $mockedClasses;
            foreach ($mockedClasses as $mockedClass) {
                if (self::getsIteratorMethods($codebase, $mockedClass)) {
                    $lookupClasses[] = \Iterator::class;
                }
            }

            foreach ($argType->getLiteralStrings() as $literal) {
                $methodName = $literal->value;

                // PHPUnit configures property hooks as '$name::get' and '$name::set', which Psalm cannot look up
                if (\str_starts_with($methodName, '$')) {
                    continue;
                }

                foreach ($lookupClasses as $lookupClass) {
                    // No code location or source on purpose: mocking a method by name is not a call, so it must
                    // not make the method "used" for dead code detection.
                    if (
                        $codebase->methodExists($lookupClass . '::' . $methodName, with_pseudo: true)
                        || $codebase->methodExists($lookupClass . '::__call')
                    ) {
                        continue 2;
                    }
                }

                IssueBuffer::accepts(
                    new UndefinedMethod(
                        \sprintf(
                            'Trying to mock an undefined method %s::%s()',
                            \implode('&', $mockedClasses),
                            $methodName,
                        ),
                        new CodeLocation($source, $args[0]->value),
                        $mockedClasses[0] . '::' . $methodName,
                    ),
                    $source->getSuppressedIssues(),
                );
            }
        }

        return null;
    }

    /**
     * @return list<string> the doubled classes of a "Foo&MockObject" / "Stub&Foo" type, or [] if it is not
     *                      a test double (or a template whose doubled classes are not known)
     * @psalm-pure
     */
    private static function mockedClasses(Atomic $atomic): array
    {
        if (!$atomic instanceof TNamedObject) {
            return [];
        }

        $isDouble = false;
        $mocked = [];
        foreach ([$atomic, ...$atomic->getIntersectionTypes()] as $part) {
            if (!$part instanceof TNamedObject) {
                return [];
            }

            if (\in_array(\strtolower($part->value), self::DOUBLE_CLASSES, true)) {
                $isDouble = true;
            } else {
                $mocked[] = $part->value;
            }
        }

        return $isDouble ? $mocked : [];
    }

    /**
     * Mirrors PHPUnit's Generator::testDouble() and generateCodeForTestDoubleClass().
     */
    private static function getsIteratorMethods(Codebase $codebase, string $class): bool
    {
        if (\strtolower($class) === 'traversable') {
            return true;
        }

        return $codebase->interfaceExists($class)
            && $codebase->interfaceExtends($class, \Traversable::class)
            && !$codebase->interfaceExtends($class, \Iterator::class)
            && !$codebase->interfaceExtends($class, \IteratorAggregate::class);
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
            && \in_array(\strtolower($atomic->value), self::EXPECTATION_BUILDERS, true);
    }

    /**
     * @psalm-mutation-free
     */
    private static function isNamed(MethodCall $call, string $name): bool
    {
        return $call->name instanceof Identifier && \strtolower($call->name->name) === $name;
    }
}
