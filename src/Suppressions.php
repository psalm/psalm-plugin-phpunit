<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use Psalm\CodeLocation;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;

/**
 * @internal
 */
final class Suppressions
{
    /**
     * The suppressions that cover an issue of a declaration: its own and those of its class, plus those of the
     * analysed class and file when the declaration is in the analysed file. Keys are source offsets, which mean
     * nothing in another file and which array_merge() would renumber.
     *
     * @param array<array-key, string> $own
     * @return array<array-key, string>
     */
    public static function of(
        ?CodeLocation $location,
        array $own,
        ClassLikeStorage $class_storage,
        StatementsSource $source,
    ): array {
        if ($location?->file_path === $source->getFilePath()) {
            $own += $class_storage->suppressed_issues + $source->getSuppressedIssues();
        }

        return $own;
    }
}
