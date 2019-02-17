<?php
namespace Psalm\PhpUnitPlugin\Hooks;

use PHPUnit\Framework\TestCase;
use PhpParser\Comment\Doc;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use Psalm\Codebase;
use Psalm\DocComment;
use Psalm\FileSource;
use Psalm\Plugin\Hook\AfterClassLikeVisitInterface;
use Psalm\Storage\ClassLikeStorage;

class TestCaseHandler implements AfterClassLikeVisitInterface
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
        if ($codebase->classExtends($classStorage->name, TestCase::class)) {
            if (self::hasInitializers($classStorage, $classNode)) {
                $classStorage->suppressed_issues[] = 'MissingConstructor';
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
        /** @var string[] $comments */
        $comments = $method->getAttribute('comments', []);

        foreach ($comments as $comment) {
            if (!$comment instanceof Doc) {
                continue;
            }

            $parsed_comment = DocComment::parse((string)$comment->getReformattedText());
            if (isset($parsed_comment['specials']['before'])) {
                return true;
            }
        }

        return false;
    }
}
