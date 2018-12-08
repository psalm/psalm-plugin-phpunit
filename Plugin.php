<?php
namespace Psalm\PhpUnitPlugin;

use SimpleXMLElement;
use Psalm\Plugin\PluginEntryPointInterface;
use Psalm\Plugin\RegistrationInterface;

class Plugin implements PluginEntryPointInterface
{
    /** @return void */
    public function __invoke(RegistrationInterface $psalm, SimpleXMLElement $config = null)
    {
        $psalm->addStubFile(__DIR__ . '/stubs/Assert.php');
        $psalm->addStubFile(__DIR__ . '/stubs/TestCase.php');
        $psalm->addStubFile(__DIR__ . '/stubs/MockBuilder.php');
        $psalm->addStubFile(__DIR__ . '/stubs/InvocationMocker.php');
        $psalm->addStubFile(__DIR__ . '/stubs/Prophecy.php');
    }
}
