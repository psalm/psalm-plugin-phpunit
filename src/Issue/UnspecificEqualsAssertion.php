<?php

namespace Psalm\PhpUnitPlugin\Issue;

use Psalm\Issue\PluginIssue;

/**
 * Suggests assertSame() or assertNotSame() over assertEquals() and assertNotEquals()
 * when both arguments are of the same scalar type.
 */
final class UnspecificEqualsAssertion extends PluginIssue
{
    public const ERROR_LEVEL = 1;
}
