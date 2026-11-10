<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use PHPUnit\Runner\Version;

/**
 * PHPUnit 12 dropped metadata in doc-comments, so the plugin has to stop honouring it there.
 */
final class PhpUnitVersion
{
    private static ?bool $ignoresDocblockMetadata = null;
    private static ?bool $stopsCollectingDependencyValuesEarly = null;

    /**
     * An unknown version (PHPUnit absent, or a phar that doesn't expose it) keeps docblocks live.
     */
    public static function ignoresDocblockMetadata(): bool
    {
        return self::$ignoresDocblockMetadata ??= \class_exists(Version::class) && Version::majorVersionNumber() >= 12;
    }

    /**
     * Collecting dependency values stops at the first dependency that is void or larger than the test, up to PHPUnit
     * 12.5.39 and 13.4.2. An unknown version counts as an old one, which reports less.
     */
    public static function stopsCollectingDependencyValuesEarly(): bool
    {
        if (self::$stopsCollectingDependencyValuesEarly !== null) {
            return self::$stopsCollectingDependencyValuesEarly;
        }

        if (!\class_exists(Version::class)) {
            return self::$stopsCollectingDependencyValuesEarly = true;
        }

        return self::$stopsCollectingDependencyValuesEarly = match (Version::majorVersionNumber()) {
            12 => \version_compare(Version::id(), '12.5.40', '<'),
            13 => \version_compare(Version::id(), '13.4.3', '<'),
            default => Version::majorVersionNumber() < 12,
        };
    }
}
