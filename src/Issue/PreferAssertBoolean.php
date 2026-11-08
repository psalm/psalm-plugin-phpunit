<?php

namespace Psalm\PhpUnitPlugin\Issue;

use Psalm\Issue\PluginIssue;

/**
 * Suggests assertTrue() and assertFalse() (or their Not variants) over assertSame(true|false, ...).
 */
final class PreferAssertBoolean extends PluginIssue
{
    public const ERROR_LEVEL = 1;
}
