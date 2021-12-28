<?php

namespace Psalm\PhpUnitPlugin;

use Composer\InstalledVersions;
use Composer\Semver\Comparator;

abstract class VersionUtils
{
    /** @param "!="|"<"|"<="|"<>"|"="|"=="|">"|">=" $op */
    public static function packageVersionIs(string $package, string $op, string $ref): bool
    {
        $currentVersion = InstalledVersions::getVersion($package);
        if (is_null($currentVersion)) {
            return false;
        }

        return Comparator::compare($currentVersion, $op, $ref);
    }
}
