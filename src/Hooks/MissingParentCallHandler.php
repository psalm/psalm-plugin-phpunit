<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node;
use PhpParser\Node\Expr\StaticCall;
use PhpParser\Node\Identifier;
use PhpParser\Node\Name;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitor;
use PhpParser\NodeVisitorAbstract;
use Psalm\Codebase;
use Psalm\IssueBuffer;
use Psalm\PhpUnitPlugin\Issue\MissingParentCall;
use Psalm\Plugin\EventHandler\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeAnalysisEvent;

use function ltrim;
use function sprintf;
use function strtolower;

/**
 * Reports setUp(), tearDown(), setUpBeforeClass(), tearDownAfterClass(), assertPreConditions() and
 * assertPostConditions() overrides that don't call the parent: the parent class may be a project base test case
 * that sets up shared fixtures.
 */
final class MissingParentCallHandler implements AfterClassLikeAnalysisInterface
{
    private const TEST_CASE = 'phpunit\\framework\\testcase';

    /** @var array<string, string> lowercase method name => method name */
    private const HOOKS = [
        'setup' => 'setUp',
        'teardown' => 'tearDown',
        'setupbeforeclass' => 'setUpBeforeClass',
        'teardownafterclass' => 'tearDownAfterClass',
        'assertpreconditions' => 'assertPreConditions',
        'assertpostconditions' => 'assertPostConditions',
    ];

    #[\Override]
    public static function afterStatementAnalysis(AfterClassLikeAnalysisEvent $event)
    {
        $storage = $event->getClasslikeStorage();
        $codebase = $event->getCodebase();

        if (
            $storage->parent_class === null
            || !$codebase->classExtends($storage->name, 'PHPUnit\\Framework\\TestCase')
        ) {
            return null;
        }

        $parentStorage = $codebase->classlike_storage_provider->get($storage->parent_class);
        $source = $event->getStatementsSource();

        foreach (self::HOOKS as $methodNameLc => $methodName) {
            $declaringId = $storage->declaring_method_ids[$methodNameLc] ?? null;
            $appearingId = $storage->appearing_method_ids[$methodNameLc] ?? null;
            $parentId = $parentStorage->declaring_method_ids[$methodNameLc] ?? null;

            // Inherited hooks appear in an ancestor, which gets checked on its own
            if (
                $declaringId === null
                || $parentId === null
                || $appearingId === null
                || strtolower($appearingId->fq_class_name) !== strtolower($storage->name)
                || strtolower($parentId->fq_class_name) === self::TEST_CASE
                || $codebase->methods->getStorage($parentId)->abstract
            ) {
                continue;
            }

            $methodStorage = $codebase->methods->getStorage($declaringId);
            if ($methodStorage->location === null) {
                continue;
            }

            // A trait's parent:: call resolves against the using class, so it is checked per using class.
            // An aliased trait method (use T { init as setUp; }) is declared under its original name.
            $declaringStorage = $codebase->classlike_storage_provider->get($declaringId->fq_class_name);
            $classNode = $declaringStorage->is_trait
                ? $codebase->classlikes->getTraitNode($declaringStorage->name)
                : $event->getStmt();

            $method = $classNode->getMethod($declaringId->method_name);
            if (
                $method === null
                || $method->stmts === null
                || self::callsParent($method->stmts, $methodNameLc, strtolower((string) $parentId), $codebase)
            ) {
                continue;
            }

            // Keys are source offsets, which array_merge() would renumber
            $suppressions = $methodStorage->suppressed_issues + $declaringStorage->suppressed_issues;
            // The analysed class's offsets mean nothing in a trait's file
            if ($methodStorage->location->file_path === $source->getFilePath()) {
                $suppressions += $storage->suppressed_issues + $source->getSuppressedIssues();
            }

            IssueBuffer::accepts(
                new MissingParentCall(
                    sprintf('Missing call to parent::%s()', $methodName),
                    $methodStorage->location,
                ),
                $suppressions,
            );
        }

        return null;
    }

    /**
     * Calls in nested closures and classes may never run, so they don't count.
     *
     * @param array<Node\Stmt> $stmts
     */
    private static function callsParent(
        array $stmts,
        string $methodNameLc,
        string $parentMethodIdLc,
        Codebase $codebase,
    ): bool {
        $visitor = new class ($methodNameLc, $parentMethodIdLc, $codebase) extends NodeVisitorAbstract {
            public bool $found = false;

            public function __construct(
                private readonly string $methodNameLc,
                private readonly string $parentMethodIdLc,
                private readonly Codebase $codebase,
            ) {
            }

            #[\Override]
            public function enterNode(Node $node)
            {
                if ($node instanceof Node\FunctionLike || $node instanceof Node\Stmt\ClassLike) {
                    return NodeVisitor::DONT_TRAVERSE_CHILDREN;
                }

                if (
                    $node instanceof StaticCall
                    && $node->class instanceof Name
                    && $node->name instanceof Identifier
                    && $node->name->toLowerString() === $this->methodNameLc
                    && !$node->isFirstClassCallable()
                    && $this->resolvesToParentMethod($node->class)
                ) {
                    $this->found = true;

                    return NodeVisitor::STOP_TRAVERSAL;
                }

                return null;
            }

            /**
             * An ancestor's name (A::setUp() in C extends B extends A) is the parent's implementation too
             * when it resolves to the same declaration.
             */
            private function resolvesToParentMethod(Name $name): bool
            {
                $lowerName = $name->toLowerString();
                if ($lowerName === 'parent') {
                    return true;
                }

                // self::setUp() and static::setUp() recurse into the override itself
                if ($lowerName === 'self' || $lowerName === 'static') {
                    return false;
                }

                $class = ltrim((string) $name->getAttribute('resolvedName', ''), '\\');
                if ($class === '') {
                    return false;
                }

                // Psalm reports the unknown class itself, no need to add a second issue on top
                if (!$this->codebase->classOrInterfaceExists($class)) {
                    return true;
                }

                $declaringId = $this->codebase->getDeclaringMethodId($class . '::' . $this->methodNameLc);

                return $declaringId !== null && strtolower($declaringId) === $this->parentMethodIdLc;
            }
        };

        (new NodeTraverser($visitor))->traverse($stmts);

        return $visitor->found;
    }
}
