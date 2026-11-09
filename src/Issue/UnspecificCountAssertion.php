<?php

namespace Psalm\PhpUnitPlugin\Issue;

use Psalm\Issue\PluginIssue;

/**
 * Suggests assertCount() or assertNotCount() over assertSame(n, count(...)).
 */
final class UnspecificCountAssertion extends PluginIssue
{
    public const ERROR_LEVEL = 1;
}
