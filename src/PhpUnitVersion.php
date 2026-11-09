<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use PHPUnit\Runner\Version;

use function class_exists;

/**
 * PHPUnit 12 dropped metadata in doc-comments, so the plugin has to stop honouring it there.
 */
final class PhpUnitVersion
{
    private static bool|null $ignoresDocblockMetadata = null;

    /**
     * An unknown version (PHPUnit absent, or a phar that doesn't expose it) keeps docblocks live.
     */
    public static function ignoresDocblockMetadata(): bool
    {
        return self::$ignoresDocblockMetadata ??= class_exists(Version::class) && Version::majorVersionNumber() >= 12;
    }
}
