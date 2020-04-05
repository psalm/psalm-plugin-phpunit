<?php

namespace Psalm\PhpUnitPlugin;

use Composer\Semver\Comparator;
use Composer\Semver\VersionParser;
use PackageVersions\Versions;
use SimpleXMLElement;
use Psalm\Plugin\PluginEntryPointInterface;
use Psalm\Plugin\RegistrationInterface;

/** @psalm-suppress UnusedClass */
class Plugin implements PluginEntryPointInterface
{
    /** @return void */
    public function __invoke(RegistrationInterface $psalm, SimpleXMLElement $config = null)
    {
        $psalm->addStubFile(__DIR__ . '/../stubs/Assert_75.phpstub');
        $psalm->addStubFile(__DIR__ . '/../stubs/TestCase.phpstub');
        $psalm->addStubFile(__DIR__ . '/../stubs/MockBuilder.phpstub');
        $psalm->addStubFile(__DIR__ . '/../stubs/InvocationMocker.phpstub');
        $psalm->addStubFile(__DIR__ . '/../stubs/Prophecy.phpstub');

        class_exists(Hooks\TestCaseHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\TestCaseHandler::class);
    }

    private function packageVersionIs(string $package, string $op, string $ref): bool
    {
        $currentVersion = (string) explode('@', Versions::getVersion($package))[0];

        $parser = new VersionParser();

        $currentVersion = $parser->normalize($currentVersion);
        $ref = $parser->normalize($ref);

        return Comparator::compare($currentVersion, $op, $ref);
    }
}
