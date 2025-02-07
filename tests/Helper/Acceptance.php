<?php

namespace Psalm\PhpUnitPlugin\Tests\Helper;

use Codeception\Exception\Skip;
use Codeception\Exception\TestRuntimeException;
use Composer\InstalledVersions;
use Composer\Semver\Comparator;
use Composer\Semver\VersionParser;

// here you can define custom actions
// all public methods declared in helper class will be available in $I

class Acceptance extends \Codeception\Module
{
    /** @var array<string,string> */
    public const VERSION_OPERATORS = [
        'newer than' => '>',
        'older than' => '<',
    ];

    /**
     * @Given /I have PHPUnit (newer than|older than) "([0-9.]+)" \(because of "([^"]+)"\)/
     *
     * @return void
     */
    public function havePHPUnitOfACertainVersionRangeBecauseOf(string $operator, string $version, string $reason)
    {
        if (!isset(self::VERSION_OPERATORS[$operator])) {
            throw new TestRuntimeException("Unknown operator: $operator");
        }

        $op = (string) self::VERSION_OPERATORS[$operator];

        $currentVersion = (string) InstalledVersions::getPrettyVersion('phpunit/phpunit');
        $this->debug(sprintf("Current version: %s", $currentVersion));

        $parser = new VersionParser();

        $currentVersion = $parser->normalize($currentVersion);
        $version = $parser->normalize($version);

        $result = Comparator::compare($currentVersion, $op, $version);
        $this->debug("Comparing $currentVersion $op $version => $result");
        if (!$result) {
            throw new Skip("This scenario requires PHPUnit $op $version because of $reason");
        }
    }
}
