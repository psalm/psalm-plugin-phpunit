<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use Psalm\CodeLocation;
use Psalm\IssueBuffer;
use Psalm\PhpUnitPlugin\DocblockSpecials;
use Psalm\PhpUnitPlugin\Issue\IgnoredDocblockMetadata;
use Psalm\PhpUnitPlugin\PhpUnitVersion;
use Psalm\Plugin\EventHandler\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeAnalysisEvent;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;

use function sprintf;
use function strtolower;

/**
 * PHPUnit 12 and newer ignore metadata in doc-comments, so a tag there silently stops doing anything.
 */
final class DocblockMetadataHandler implements AfterClassLikeAnalysisInterface
{
    /** @var array<string, string> every tag PHPUnit 11 reads from a doc-comment => the attribute to use instead */
    private const ATTRIBUTES = [
        'after' => '#[After]',
        'afterClass' => '#[AfterClass]',
        'backupGlobals' => '#[BackupGlobals]',
        'backupStaticAttributes' => '#[BackupStaticProperties]',
        'backupStaticProperties' => '#[BackupStaticProperties]',
        'before' => '#[Before]',
        'beforeClass' => '#[BeforeClass]',
        'covers' => '#[CoversClass], #[CoversMethod] or #[CoversFunction]',
        'coversDefaultClass' => '#[CoversClass]',
        'coversNothing' => '#[CoversNothing]',
        'dataProvider' => '#[DataProvider] or #[DataProviderExternal]',
        'depends' => '#[Depends] or #[DependsExternal]',
        'doesNotPerformAssertions' => '#[DoesNotPerformAssertions]',
        'excludeGlobalVariableFromBackup' => '#[ExcludeGlobalVariableFromBackup]',
        'excludeStaticPropertyFromBackup' => '#[ExcludeStaticPropertyFromBackup]',
        'group' => '#[Group]',
        'large' => '#[Large]',
        'medium' => '#[Medium]',
        'postCondition' => '#[PostCondition]',
        'preCondition' => '#[PreCondition]',
        'preserveGlobalState' => '#[PreserveGlobalState]',
        'requires' => '#[RequiresPhp], #[RequiresPhpExtension], #[RequiresOperatingSystem] or another #[Requires*]',
        'runClassInSeparateProcess' => '#[RunClassInSeparateProcess]',
        'runInSeparateProcess' => '#[RunInSeparateProcess]',
        'runTestsInSeparateProcesses' => '#[RunTestsInSeparateProcesses]',
        'small' => '#[Small]',
        'test' => '#[Test]',
        'testdox' => '#[TestDox]',
        'testWith' => '#[TestWith] or #[TestWithJson]',
        'ticket' => '#[Ticket]',
        'uses' => '#[UsesClass], #[UsesMethod] or #[UsesFunction]',
        'usesDefaultClass' => '#[UsesClass]',
    ];

    #[\Override]
    public static function afterStatementAnalysis(AfterClassLikeAnalysisEvent $event)
    {
        $class_node    = $event->getStmt();
        $class_storage = $event->getClasslikeStorage();
        $codebase      = $event->getCodebase();
        $source        = $event->getStatementsSource();

        $is_test_case = $codebase->classExtends($class_storage->name, 'PHPUnit\Framework\TestCase');
        if (!PhpUnitVersion::ignoresDocblockMetadata() || !$is_test_case) {
            return null;
        }

        self::report(
            $class_node,
            $class_storage->stmt_location ?? $class_storage->location,
            self::suppressions($class_storage->location, [], $class_storage, $source),
        );

        // PHPUnit 11 also reads the class docblock of every trait the test case uses.
        foreach ($class_storage->used_traits as $trait_name) {
            $trait_storage = $codebase->classlike_storage_provider->get($trait_name);
            $suppressions = self::suppressions(
                $trait_storage->location,
                $trait_storage->suppressed_issues,
                $class_storage,
                $source,
            );
            self::report(
                $codebase->classlikes->getTraitNode($trait_storage->name),
                $trait_storage->stmt_location ?? $trait_storage->location,
                $suppressions,
            );
        }

        // Inherited methods are reported with the class that declares them. A trait docblock or method is reported
        // once for every class using it, at the same location with the same message, which Psalm deduplicates.
        foreach ($class_storage->declaring_method_ids as $declaring_method_id) {
            $declaring_class = $codebase->classlike_storage_provider->get($declaring_method_id->fq_class_name);
            $declaring_class_node = match (true) {
                strtolower($declaring_class->name) === strtolower($class_storage->name) => $class_node,
                $declaring_class->is_trait => $codebase->classlikes->getTraitNode($declaring_class->name),
                default => null,
            };
            $method_node = $declaring_class_node?->getMethod($declaring_method_id->method_name);
            if ($method_node === null) {
                continue;
            }

            $method_storage = $codebase->methods->getStorage($declaring_method_id);
            self::report(
                $method_node,
                $method_storage->stmt_location ?? $method_storage->location,
                self::suppressions(
                    $method_storage->location,
                    $method_storage->suppressed_issues + $declaring_class->suppressed_issues,
                    $class_storage,
                    $source,
                ),
            );
        }

        return null;
    }

    /**
     * Suppression keys are source offsets: those of the analysed class mean nothing in another file.
     *
     * @param array<array-key, string> $own suppressions of the declaration itself
     * @return array<array-key, string>
     */
    private static function suppressions(
        CodeLocation|null $location,
        array $own,
        ClassLikeStorage $class_storage,
        StatementsSource $source,
    ): array {
        if ($location?->file_path === $source->getFilePath()) {
            $own += $class_storage->suppressed_issues + $source->getSuppressedIssues();
        }

        return $own;
    }

    /** @param array<array-key, string> $suppressed_issues */
    private static function report(
        ClassLike|ClassMethod $node,
        CodeLocation|null $location,
        array $suppressed_issues,
    ): void {
        if ($location === null) {
            return;
        }

        foreach (DocblockSpecials::all($node) as $tag => $entries) {
            if (!isset(self::ATTRIBUTES[$tag])) {
                continue;
            }

            foreach ($entries as [$line]) {
                $message = sprintf(
                    'PHPUnit 12 ignores the @%s docblock tag, use %s instead',
                    $tag,
                    self::ATTRIBUTES[$tag],
                );
                IssueBuffer::accepts(
                    new IgnoredDocblockMetadata($message, $location->setCommentLine($line)),
                    $suppressed_issues,
                );
            }
        }
    }
}
