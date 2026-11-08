<?php

namespace Psalm\PhpUnitPlugin\Issue;

use Psalm\Issue\PluginIssue;

/**
 * Suggests assertNull() or assertNotNull() over assertSame(null, ...) and assertNotSame(null, ...).
 */
final class PreferAssertNull extends PluginIssue
{
    public const ERROR_LEVEL = 1;
}
