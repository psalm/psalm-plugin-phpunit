<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use Psalm\Plugin\EventHandler\BeforeFileAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\BeforeFileAnalysisEvent;

/**
 * The top-level code and the closures of a test suite file only run under PHPUnit, from the command line. That
 * includes Pest tests, which are closures bound to a test case.
 */
final class TestSuiteFileHandler implements BeforeFileAnalysisInterface
{
    #[\Override]
    public static function beforeAnalyzeFile(BeforeFileAnalysisEvent $event): void
    {
        $test_paths = TestCaseHandler::getTestSuitePaths($event->getCodebase()->config->base_dir);

        if (TestCaseHandler::isInPaths($event->getStatementsSource()->getFilePath(), $test_paths)) {
            $event->markFileAsCliOnly();
        }
    }
}
