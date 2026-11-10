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

        class_exists(Hooks\AssertSameSuggestionHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\AssertSameSuggestionHandler::class);

        class_exists(Hooks\MockMethodHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\MockMethodHandler::class);

        class_exists(Hooks\IntersectionMockReturnTypeProvider::class, true);
        $psalm->registerHooksFromClass(Hooks\IntersectionMockReturnTypeProvider::class);

        class_exists(Hooks\CoversTargetHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\CoversTargetHandler::class);

        class_exists(Hooks\DocblockMetadataHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\DocblockMetadataHandler::class);

        class_exists(Hooks\MissingParentCallHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\MissingParentCallHandler::class);

        class_exists(Hooks\DataProviderNarrowingHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\DataProviderNarrowingHandler::class);

        class_exists(Hooks\DataProviderClosureHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\DataProviderClosureHandler::class);

        class_exists(Hooks\ProviderReturnTypeHandler::class, true);
        $psalm->registerHooksFromClass(Hooks\ProviderReturnTypeHandler::class);
    }
}
