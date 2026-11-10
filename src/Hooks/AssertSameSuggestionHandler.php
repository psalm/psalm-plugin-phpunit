<?php

namespace Psalm\PhpUnitPlugin\Hooks;

use function count;

use PhpParser\Node\Arg;
use PhpParser\Node\Expr;
use PhpParser\Node\Expr\ConstFetch;
use PhpParser\Node\Expr\FuncCall;
use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Expr\StaticCall;
use PhpParser\Node\Identifier;
use PhpParser\Node\Name;
use Psalm\CodeLocation;
use Psalm\FileManipulation;
use Psalm\IssueBuffer;
use Psalm\Node\VirtualNode;
use Psalm\PhpUnitPlugin\Issue\UnspecificBooleanAssertion;
use Psalm\PhpUnitPlugin\Issue\UnspecificCountAssertion;
use Psalm\PhpUnitPlugin\Issue\UnspecificEqualsAssertion;
use Psalm\PhpUnitPlugin\Issue\UnspecificNullAssertion;
use Psalm\Plugin\EventHandler\AfterMethodCallAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterMethodCallAnalysisEvent;
use Psalm\Type\Atomic\TNamedObject;
use Psalm\Type\Union;

/**
 * Suggests the dedicated assertion for assertSame(null|true|false, ...) and assertSame(n, count(...)) in either
 * argument order, and assertSame() over assertEquals() when both arguments are of the same scalar type. Psalter
 * fixes the null, boolean and equals suggestions (see Plugin::getFixableIssues()), never the count ones.
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
        $declaringMethodId = \strtolower($event->getDeclaringMethodId());
        if (!\str_starts_with($declaringMethodId, self::ASSERT_CLASS_PREFIX)) {
            return;
        }

        $method = \substr($declaringMethodId, \strlen(self::ASSERT_CLASS_PREFIX));
        $call = $event->getExpr();
        if ($call->isFirstClassCallable()) {
            return;
        }

        $args = $call->getArgs();
        if (\count($args) < 2 || !self::isPositional($args[0]) || !self::isPositional($args[1])) {
            return;
        }

        [$expected, $actual] = [$args[0]->value, $args[1]->value];
        // assertSame($flag, true), assertSame(count($items), 3): the literal goes first, the count() call last
        $swapped = self::literalName($expected) === null
            && (self::literalName($actual) !== null || self::isCountCall($expected, $event));
        if ($swapped) {
            [$expected, $actual] = [$actual, $expected];
        }
        $literal = self::literalName($expected);
        $fixedName = null;
        $dropLiteral = null;

        // assertEquals(true, 1) passes while assertTrue(1) fails, so assertEquals() needs a bool actual
        if (
            $literal !== null
            && (isset(self::SAME_METHODS[$method])
                || ($literal !== 'null'
                    && isset(self::EQUALS_METHODS[$method])
                    && self::scalarFamily($actual, $event) === 'bool'))
        ) {
            [$name, $not] = self::COUNT_METHODS[$method];
            $fixedName = 'assert' . $not . \ucfirst($literal);
            // From the literal to the next argument, or from the previous argument to the literal
            $dropLiteral = $swapped
                ? new FileManipulation($args[0]->getEndFilePos() + 1, $args[1]->getEndFilePos() + 1, '')
                : new FileManipulation($args[0]->getStartFilePos(), $args[1]->getStartFilePos(), '');
            $issueClass = $literal === 'null' ? UnspecificNullAssertion::class : UnspecificBooleanAssertion::class;
            $message = \sprintf(
                'Use %s() instead of %s(%s)',
                $fixedName,
                $name,
                $swapped ? '..., ' . $literal : $literal . ', ...',
            );
        } elseif (isset(self::COUNT_METHODS[$method]) && self::isIntegerCountComparison($expected, $actual, $event)) {
            [$name, $not] = self::COUNT_METHODS[$method];
            $issueClass = UnspecificCountAssertion::class;
            $message = \sprintf(
                'Use assert%sCount() instead of %s(%s)',
                $not,
                $name,
                $swapped ? 'count(...), ...' : '..., count(...)',
            );
        } elseif (
            isset(self::EQUALS_METHODS[$method])
            && ($family = self::scalarFamily($expected, $event)) !== null
            && $family === self::scalarFamily($actual, $event)
        ) {
            [$name, $not] = self::EQUALS_METHODS[$method];
            $fixedName = 'assert' . $not . 'Same';
            $issueClass = UnspecificEqualsAssertion::class;
            $message = \sprintf(
                'Use %s() instead of %s(), both arguments are of type %s',
                $fixedName,
                $name,
                $family,
            );
        } else {
            return;
        }

        $source = $event->getStatementsSource();
        $issue = new $issueClass($message, new CodeLocation($source, $call));
        $replacements = $fixedName === null ? [] : self::replacements($call, $fixedName, $dropLiteral, $event);

        if ($replacements !== [] && $event->getCodebase()->shouldFixIssue($issue, $source->getSuppressedIssues())) {
            $event->setFileReplacements([...$event->getFileReplacements(), ...$replacements]);

            return;
        }

        IssueBuffer::accepts($issue, $source->getSuppressedIssues(), $replacements !== []);
    }

    /**
     * @psalm-mutation-free
     */
    private static function isPositional(Arg $arg): bool
    {
        return !$arg->unpack && $arg->name === null;
    }

    /**
     * @return 'null'|'true'|'false'|null
     * @psalm-mutation-free
     */
    private static function literalName(Expr $expr): ?string
    {
        $name = $expr instanceof ConstFetch ? \strtolower($expr->name->toString()) : null;

        return \in_array($name, ['null', 'true', 'false'], true) ? $name : null;
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
     * The scalar type of an expression, when it is one family only. assertEquals() on two values of one scalar
     * type compares them exactly like assertSame() does. Null is not ignored: assertEquals(0, null) passes,
     * assertSame(0, null) does not.
     *
     * @return 'int'|'float'|'string'|'bool'|null
     */
    private static function scalarFamily(Expr $expr, AfterMethodCallAnalysisEvent $event): ?string
    {
        $type = $event->getStatementsSource()->getNodeTypeProvider()->getType($expr);
        if ($type === null) {
            return null;
        }

        return match (true) {
            $type->isInt() => 'int',
            $type->isFloat() => 'float',
            $type->isString() => 'string',
            $type->isBool() || $type->isTrue() || $type->isFalse() => 'bool',
            default => null,
        };
    }

    private static function isGlobalCount(Name $name, AfterMethodCallAnalysisEvent $event): bool
    {
        if ($name->hasAttribute('resolvedName')) {
            return \strtolower((string) $name->getAttribute('resolvedName')) === 'count';
        }

        if (!$name->isUnqualified() || \strtolower($name->toString()) !== 'count') {
            return false;
        }

        $namespaced = (string) $name->getAttribute('namespacedName', 'count');
        if (\strtolower($namespaced) === 'count') {
            return true;
        }

        try {
            $event->getCodebase()->getFunctionStorageForSymbol(
                $event->getStatementsSource()->getFilePath(),
                $namespaced . '()',
            );
        } catch (\UnexpectedValueException) {
            return true;
        }

        return false;
    }

    /**
     * A union receiver such as TestCase|Helper may reach Helper::assertSame(), which has no assertNull().
     */
    private static function onlyReachesAssert(MethodCall|StaticCall $call, AfterMethodCallAnalysisEvent $event): bool
    {
        if ($call instanceof StaticCall) {
            return $call->class instanceof Name;
        }

        $receiver = $event->getStatementsSource()->getNodeTypeProvider()->getType($call->var);

        return $receiver !== null
            && $event->getCodebase()->isTypeContainedByType(
                $receiver,
                new Union([new TNamedObject('PHPUnit\\Framework\\Assert')]),
            );
    }

    /**
     * @return list<FileManipulation>
     */
    private static function replacements(
        MethodCall|StaticCall $call,
        string $fixedName,
        ?FileManipulation $dropLiteral,
        AfterMethodCallAnalysisEvent $event,
    ): array {
        $methodName = $call->name;
        // Virtual calls are skipped: their positions may not be the call's own
        if (
            !$methodName instanceof Identifier
            || $call instanceof VirtualNode
            || !self::onlyReachesAssert($call, $event)
        ) {
            return [];
        }

        $rename = new FileManipulation($methodName->getStartFilePos(), $methodName->getEndFilePos() + 1, $fixedName);

        return $dropLiteral === null ? [$rename] : [$rename, $dropLiteral];
    }

    private static function isCountCall(Expr $expr, AfterMethodCallAnalysisEvent $event): bool
    {
        if ($expr instanceof FuncCall) {
            return $expr->name instanceof Name
                && self::isGlobalCount($expr->name, $event)
                && !$expr->isFirstClassCallable()
                && \count($expr->getArgs()) === 1
                && !$expr->getArgs()[0]->unpack;
        }

        $isCountMethodCall = $expr instanceof MethodCall
            && $expr->name instanceof Identifier
            && \strtolower($expr->name->name) === 'count'
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

            $isCountable = \strtolower($atomic->value) === 'countable'
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
