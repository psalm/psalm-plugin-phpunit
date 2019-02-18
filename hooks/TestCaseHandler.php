<?php
namespace Psalm\PhpUnitPlugin\Hooks;

use PHPUnit\Framework\TestCase;
use PhpParser\Comment\Doc;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use Psalm\CodeLocation;
use Psalm\Codebase;
use Psalm\DocComment;
use Psalm\FileSource;
use Psalm\IssueBuffer;
use Psalm\Issue\UndefinedMethod;
use Psalm\Plugin\Hook\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\Hook\AfterClassLikeVisitInterface;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;

class TestCaseHandler implements AfterClassLikeVisitInterface, AfterClassLikeAnalysisInterface
{
    /**
     * {@inheritDoc}
     */
    public static function afterClassLikeVisit(
        ClassLike $classNode,
        ClassLikeStorage $classStorage,
        FileSource $statements_source,
        Codebase $codebase,
        array &$file_replacements = []
    ) {
        if (!$codebase->classExtends($classStorage->name, TestCase::class)) {
            return;
        }

        if (self::hasInitializers($classStorage, $classNode)) {
            $classStorage->suppressed_issues[] = 'MissingConstructor';
        }
    }

    /**
     * {@inheritDoc}
     */
    public static function afterStatementAnalysis(
        ClassLike $classNode,
        ClassLikeStorage $classStorage,
        StatementsSource $statements_source,
        Codebase $codebase,
        array &$file_replacements = []
    ) {
        foreach ($classStorage->methods as $method_name => $method_storage) {
            if (!$method_storage->location) {
                continue;
            }

            $stmt_method = $classNode->getMethod($method_name);

            if (!$stmt_method) {
                throw new \RuntimeException('Failed to find ' . $method_name);
            }

            $specials = self::getSpecials($stmt_method);

            if (!isset($specials['dataProvider'])) {
                continue;
            }

            foreach ($specials['dataProvider'] as $line => $provider) {
                $provider_method_id = $classStorage->name . '::' . (string) $provider;

                if (!$codebase->methodExists($provider_method_id)) {
                    $location = clone $method_storage->location;
                    $location->setCommentLine($line);

                    IssueBuffer::accepts(new UndefinedMethod(
                        'Provider method ' . $provider_method_id . ' is not defined',
                        $location,
                        $provider_method_id
                    ));
                }
            }
        }
    }


    private static function hasInitializers(ClassLikeStorage $storage, ClassLike $stmt): bool
    {
        if (isset($storage->methods['setup'])) {
            return true;
        }

        foreach ($storage->methods as $method => $_) {
            $stmt_method = $stmt->getMethod($method);
            if (!$stmt_method) {
                throw new \RuntimeException('Failed to find ' . $method);
            }
            if (self::isBeforeInitializer($stmt_method)) {
                return true;
            }
        }
        return false;
    }

    private static function isBeforeInitializer(ClassMethod $method): bool
    {
        $specials = self::getSpecials($method);
        return isset($specials['before']);
    }

    /** @return array<string, array<int,string>> */
    private static function getSpecials(ClassMethod $method): array
    {
        $docblock = $method->getDocComment();

        if ($docblock) {
            $parsed_comment = DocComment::parse((string)$docblock->getReformattedText(), $docblock->getLine());
            if (isset($parsed_comment['specials'])) {
                return $parsed_comment['specials'];
            }
        }
        return [];
    }
}
