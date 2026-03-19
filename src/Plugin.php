<?php

namespace Psalm\PhpUnitPlugin;

use SimpleXMLElement;
use Psalm\Plugin\PluginEntryPointInterface;
use Psalm\Plugin\RegistrationInterface;

/** @psalm-suppress UnusedClass */
final class Plugin implements PluginEntryPointInterface
{
    #[\Override]
    public function __invoke(RegistrationInterface $psalm, ?SimpleXMLElement $config = null): void
    {
        $psalm->addStubFile(__DIR__ . '/../stubs/TestCase.phpstub');

        class_exists(Hooks\TestCaseHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\TestCaseHandler::class);
    }
}
