<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node;
use PhpParser\Node\Expr\StaticCall;
use PhpParser\Node\Identifier;
use PhpParser\Node\Name;
use PhpParser\Node\Stmt\ClassMethod;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitor;
use PhpParser\NodeVisitorAbstract;
use Psalm\IssueBuffer;
use Psalm\PhpUnitPlugin\Issue\MissingParentCall;
use Psalm\Plugin\EventHandler\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeAnalysisEvent;

use function array_merge;
use function ltrim;
use function sprintf;
use function strtolower;

/**
 * Reports setUp(), tearDown(), setUpBeforeClass() and tearDownAfterClass() overrides that don't call the parent:
 * the parent class may be a project base test case that sets up shared fixtures.
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

            // A trait's parent:: call resolves against the using class, so it is checked per using class
            $declaringStorage = $codebase->classlike_storage_provider->get($declaringId->fq_class_name);
            $classNode = $declaringStorage->is_trait
                ? $codebase->classlikes->getTraitNode($declaringStorage->name)
                : $event->getStmt();

            $method = $classNode->getMethod($methodName);
            if ($method === null || $method->stmts === null || self::callsParent($method, $storage->parent_class)) {
                continue;
            }

            IssueBuffer::accepts(
                new MissingParentCall(
                    sprintf('Missing call to parent::%s()', $methodName),
                    $methodStorage->location,
                ),
                array_merge(
                    $methodStorage->suppressed_issues,
                    $storage->suppressed_issues,
                    $source->getSuppressedIssues(),
                ),
            );
        }

        return null;
    }

    /**
     * Calls in nested closures and classes may never run, so they don't count.
     */
    private static function callsParent(ClassMethod $method, string $parentClass): bool
    {
        $visitor = new class ($method->name->toLowerString(), strtolower($parentClass)) extends NodeVisitorAbstract {
            public bool $found = false;

            public function __construct(private readonly string $methodNameLc, private readonly string $parentLc)
            {
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
                    && $this->namesParent($node->class)
                ) {
                    $this->found = true;

                    return NodeVisitor::STOP_TRAVERSAL;
                }

                return null;
            }

            private function namesParent(Name $name): bool
            {
                if ($name->toLowerString() === 'parent') {
                    return true;
                }

                return strtolower(ltrim((string) $name->getAttribute('resolvedName', ''), '\\')) === $this->parentLc;
            }
        };

        (new NodeTraverser($visitor))->traverse($method->stmts ?? []);

        return $visitor->found;
    }
}
