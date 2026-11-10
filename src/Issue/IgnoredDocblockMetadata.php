<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Issue;

use Psalm\Issue\PluginIssue;

/**
 * PHPUnit 12 and newer ignore metadata in doc-comments such as @test, @dataProvider or @covers.
 */
final class IgnoredDocblockMetadata extends PluginIssue {}
