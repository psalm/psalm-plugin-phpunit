<?php

declare(strict_types=1);

/**
 * Reports scenarios that silently assert less than they seem to.
 * Arguments: feature files (default: all of tests/acceptance).
 */

/** @var list<string> $argv */
$paths = array_slice($argv, 1);
if ($paths === []) {
    $paths = glob(__DIR__ . '/../../tests/acceptance/*.feature');
    if ($paths === false) {
        $paths = [];
    }
}

$problems = [];
$titles   = [];

foreach ($paths as $path) {
    $lines = file($path, FILE_IGNORE_NEW_LINES);
    if ($lines === false) {
        $problems[] = "$path: cannot be read";
        continue;
    }

    $name     = basename($path);
    $scenario = null;
    $expects  = false;
    $checkScenario = static function (?string $scenario, bool $expects) use (&$problems): void {
        if ($scenario !== null && $expects) {
            $problems[] = $scenario . ': "I see these errors" without "I see no other errors"'
                . ' lets extra issues pass';
        }
    };

    foreach ($lines as $index => $line) {
        $at = $name . ':' . ($index + 1);

        if (preg_match('/^\s*Scenario(?: Outline)?:\s*(.+?)\s*$/', $line, $matches) === 1) {
            $checkScenario($scenario, $expects);
            $scenario = $at;
            $expects  = false;

            $title = $matches[1];
            if (isset($titles[$title])) {
                $problems[] = "$at: duplicate scenario title, also at {$titles[$title]}";
            } else {
                $titles[$title] = $at;
            }
            continue;
        }

        if (preg_match('/^\s*(?:Then|And) I see these errors\s*$/', $line) === 1) {
            $expects = true;
        } elseif (preg_match('/^\s*(?:Then|And) I see no other errors\s*$/', $line) === 1) {
            $expects = false;
        }

        // Psalm drops every tag after the first one of a single-line docblock
        if (preg_match('~/\*\*(?:(?!\*/).)*?\s@[\w-]+(?:(?!\*/).)*?\s@[\w-]+~', ' ' . $line) === 1) {
            $problems[] = "$at: put each docblock tag on its own line";
        }
    }

    $checkScenario($scenario, $expects);
}

foreach ($problems as $problem) {
    fwrite(STDERR, $problem . "\n");
}

exit($problems === [] ? 0 : 1);
