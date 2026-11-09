<?php

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Arg;
use PhpParser\Node\Expr;
use PhpParser\Node\Expr\ConstFetch;
use PhpParser\Node\Expr\FuncCall;
use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Identifier;
use PhpParser\Node\Name;
use Psalm\CodeLocation;
use Psalm\IssueBuffer;
use Psalm\Plugin\EventHandler\AfterMethodCallAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterMethodCallAnalysisEvent;
use Psalm\PhpUnitPlugin\Issue\UnspecificBooleanAssertion;
use Psalm\PhpUnitPlugin\Issue\UnspecificCountAssertion;
use Psalm\PhpUnitPlugin\Issue\UnspecificEqualsAssertion;
use Psalm\PhpUnitPlugin\Issue\UnspecificNullAssertion;
use Psalm\Type\Atomic\TBool;
use Psalm\Type\Atomic\TFloat;
use Psalm\Type\Atomic\TInt;
use Psalm\Type\Atomic\TNamedObject;
use Psalm\Type\Atomic\TString;
use UnexpectedValueException;

use function count;
use function in_array;
use function sprintf;
use function str_starts_with;
use function strlen;
use function strtolower;
use function substr;
use function ucfirst;

/**
 * Suggests the dedicated assertion for assertSame(null|true|false, ...) and assertSame(n, count(...)),
 * and assertSame() over assertEquals() when both arguments are of the same scalar type.
 */
final class AssertSameSuggestionHandler implements AfterMethodCallAnalysisInterface
{
    private const ASSERT_CLASS_PREFIX = 'phpunit\\framework\\assert::';

    /** @var array<string, array{string, string}> lowercase method name => [name, negation infix] */
    private const SAME_METHODS = [
        'assertsame' => ['assertSame', ''],
        'assertnotsame' => ['assertNotSame', 'Not'],
    ];

    /** @var array<string, array{string, string}> */
    private const EQUALS_METHODS = [
        'assertequals' => ['assertEquals', ''],
        'assertnotequals' => ['assertNotEquals', 'Not'],
    ];

    /** @var array<string, array{string, string}> */
    private const COUNT_METHODS = self::SAME_METHODS + self::EQUALS_METHODS;

    #[\Override]
    public static function afterMethodCallAnalysis(AfterMethodCallAnalysisEvent $event): void
    {
        $declaringMethodId = strtolower($event->getDeclaringMethodId());
        if (!str_starts_with($declaringMethodId, self::ASSERT_CLASS_PREFIX)) {
            return;
        }

        $method = substr($declaringMethodId, strlen(self::ASSERT_CLASS_PREFIX));
        $call = $event->getExpr();
        if ($call->isFirstClassCallable()) {
            return;
        }

        $args = $call->getArgs();
        if (count($args) < 2 || !self::isPositional($args[0]) || !self::isPositional($args[1])) {
            return;
        }

        [$expected, $actual] = [$args[0]->value, $args[1]->value];
        $literal = $expected instanceof ConstFetch ? strtolower($expected->name->toString()) : null;

        if (isset(self::SAME_METHODS[$method]) && in_array($literal, ['null', 'true', 'false'], true)) {
            [$name, $not] = self::SAME_METHODS[$method];
            $issueClass = $literal === 'null' ? UnspecificNullAssertion::class : UnspecificBooleanAssertion::class;
            $message = sprintf('Use assert%s%s() instead of %s(%s, ...)', $not, ucfirst($literal), $name, $literal);
        } elseif (isset(self::COUNT_METHODS[$method]) && self::isIntegerCountComparison($expected, $actual, $event)) {
            [$name, $not] = self::COUNT_METHODS[$method];
            $issueClass = UnspecificCountAssertion::class;
            $message = sprintf('Use assert%sCount() instead of %s(..., count(...))', $not, $name);
        } elseif (
            isset(self::EQUALS_METHODS[$method])
            && ($family = self::sameScalarFamily($expected, $actual, $event)) !== null
        ) {
            [$name, $not] = self::EQUALS_METHODS[$method];
            $issueClass = UnspecificEqualsAssertion::class;
            $message = sprintf(
                'Use assert%sSame() instead of %s(), both arguments are of type %s',
                $not,
                $name,
                $family,
            );
        } else {
            return;
        }

        $source = $event->getStatementsSource();
        IssueBuffer::accepts(
            new $issueClass($message, new CodeLocation($source, $call)),
            $source->getSuppressedIssues(),
        );
    }

    /**
     * @psalm-mutation-free
     */
    private static function isPositional(Arg $arg): bool
    {
        return !$arg->unpack && $arg->name === null;
    }

    /**
     * assertCount() takes an int, while assertSame('2', count(...)) compares strictly and never passes.
     */
    private static function isIntegerCountComparison(
        Expr $expected,
        Expr $actual,
        AfterMethodCallAnalysisEvent $event,
    ): bool {
        $expectedType = $event->getStatementsSource()->getNodeTypeProvider()->getType($expected);

        return $expectedType !== null && $expectedType->isInt() && self::isCountCall($actual, $event);
    }

    /**
     * assertEquals() on two values of one scalar type compares them exactly like assertSame() does. Null is not
     * ignored: assertEquals(0, null) passes, assertSame(0, null) does not.
     *
     * @return 'int'|'float'|'string'|'bool'|null
     */
    private static function sameScalarFamily(
        Expr $expected,
        Expr $actual,
        AfterMethodCallAnalysisEvent $event,
    ): ?string {
        $family = self::scalarFamily($expected, $event);

        return $family !== null && $family === self::scalarFamily($actual, $event) ? $family : null;
    }

    /**
     * @return 'int'|'float'|'string'|'bool'|null
     */
    private static function scalarFamily(Expr $expr, AfterMethodCallAnalysisEvent $event): ?string
    {
        $type = $event->getStatementsSource()->getNodeTypeProvider()->getType($expr);
        if ($type === null) {
            return null;
        }

        $family = null;
        foreach ($type->getAtomicTypes() as $atomic) {
            $atomicFamily = match (true) {
                $atomic instanceof TInt => 'int',
                $atomic instanceof TFloat => 'float',
                $atomic instanceof TString => 'string',
                $atomic instanceof TBool => 'bool',
                default => null,
            };
            if ($atomicFamily === null || ($family !== null && $family !== $atomicFamily)) {
                return null;
            }

            $family = $atomicFamily;
        }

        return $family;
    }

    private static function isGlobalCount(Name $name, AfterMethodCallAnalysisEvent $event): bool
    {
        if ($name->hasAttribute('resolvedName')) {
            return strtolower((string) $name->getAttribute('resolvedName')) === 'count';
        }

        if (!$name->isUnqualified() || strtolower($name->toString()) !== 'count') {
            return false;
        }

        $namespaced = (string) $name->getAttribute('namespacedName', 'count');
        if (strtolower($namespaced) === 'count') {
            return true;
        }

        try {
            $event->getCodebase()->getFunctionStorageForSymbol(
                $event->getStatementsSource()->getFilePath(),
                $namespaced . '()',
            );
        } catch (UnexpectedValueException) {
            return true;
        }

        return false;
    }

    private static function isCountCall(Expr $expr, AfterMethodCallAnalysisEvent $event): bool
    {
        if ($expr instanceof FuncCall) {
            return $expr->name instanceof Name
                && self::isGlobalCount($expr->name, $event)
                && !$expr->isFirstClassCallable()
                && count($expr->getArgs()) === 1
                && !$expr->getArgs()[0]->unpack;
        }

        $isCountMethodCall = $expr instanceof MethodCall
            && $expr->name instanceof Identifier
            && strtolower($expr->name->name) === 'count'
            && !$expr->isFirstClassCallable()
            && $expr->getArgs() === [];
        if (!$isCountMethodCall) {
            return false;
        }

        $codebase = $event->getCodebase();
        $receiver = $event->getStatementsSource()->getNodeTypeProvider()->getType($expr->var);
        if ($receiver === null) {
            return false;
        }

        foreach ($receiver->getAtomicTypes() as $atomic) {
            if (!$atomic instanceof TNamedObject) {
                return false;
            }

            $isCountable = strtolower($atomic->value) === 'countable'
                || $codebase->classImplements($atomic->value, 'Countable')
                || ($codebase->interfaceExists($atomic->value)
                    && $codebase->interfaceExtends($atomic->value, 'Countable'));
            if (!$isCountable) {
                return false;
            }
        }

        return true;
    }
}
