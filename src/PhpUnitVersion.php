<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use PHPUnit\Runner\Version;

use function class_exists;
use function explode;

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
        return self::$ignoresDocblockMetadata ??= self::majorVersion() >= 12;
    }

    private static function majorVersion(): int
    {
        return class_exists(Version::class) ? (int) explode('.', Version::id())[0] : 0;
    }
}
