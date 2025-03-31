<?php

declare(strict_types=1);

namespace PsalmTest\PhpUnitPlugin;

use Behat\Behat\Context\Context as BehatContext;
use Behat\Gherkin\Node\PyStringNode;
use Behat\Gherkin\Node\TableNode;
use Behat\Hook\AfterScenario;
use Behat\Hook\BeforeScenario;
use Behat\Step\Given;
use Behat\Step\Then;
use Behat\Step\When;
use Psl\Filesystem;
use Psl\File;
use Psl\Json;
use Psl\SecureRandom;
use Psl\Shell;
use Psl\Shell\ErrorOutputBehavior;
use Psl\Shell\Exception\FailedExecutionException;
use Psl\Str;
use Psl\Type;

use function Psl\invariant;
use function sprintf;

/** @psalm-suppress UnusedClass psalm does not understand Behat context marker interfaces (yet) */
final class Context implements BehatContext
{
    /** @var non-empty-string|null */
    private string|null $scenarioDirectory = null;
    private string $codePreamble = '';
    private string|null $processOutput = null;
    /** @var int<0, 255> */
    private int $exitCode = 0;
    private bool $processFailed = false;
    /** @var list<array{type: non-empty-string, message: non-empty-string}> */
    private array $errors = [];

    #[BeforeScenario]
    public function makeScenarioDirectory(): void
    {
        $name = __DIR__ . '/../run/' . SecureRandom\string(10, Str\ALPHABET);

        // @TODO really want azjezz/psl to avoid dealing with this stuff.
        Filesystem\create_directory($name);

        $this->scenarioDirectory = $name;
    }

    #[AfterScenario]
    public function cleanUpScenario(): void
    {
        Filesystem\delete_directory($this->scenarioDirectory(), true);
    }

    /** @return non-empty-string */
    private function scenarioDirectory(): string
    {
        $directory = $this->scenarioDirectory;

        invariant($directory !== null, "Scenario directory missing");

        return $directory;
    }

    private function processOutput(): string
    {
        $output = $this->processOutput;

        invariant($output !== null, "No process output produced: did Psalm run?");

        return $output;
    }

    private function writeFile(string $file, string $contents): void
    {
        File\write($this->scenarioDirectory() . '/' . $file, $contents);
    }

    /** @param list<non-empty-string> $additionalFlags */
    private function runPsalm(array $additionalFlags): void
    {
        try {
            $this->processOutput = Shell\execute(
                __DIR__ . '/../../../vendor/bin/psalm',
                \array_merge(
                    [
                        '--no-progress',
                        '--output-format=json',
                    ],
                    $additionalFlags,
                ),
                $this->scenarioDirectory(),
                error_output_behavior: ErrorOutputBehavior::Discard,
            );
        } catch (FailedExecutionException $failed) {
            $output              = $failed->getOutput();
            $this->processOutput = $output;
            $this->processFailed = true;
            $this->exitCode      = Type\u8()->coerce($failed->getCode());
            $this->errors        = Json\typed(
                $output,
                Type\vec(Type\shape([
                    'type'    => Type\non_empty_string(),
                    'message' => Type\non_empty_string(),
                ])),
            );
        }
    }

    #[Given('I have the following config')]
    public function iHaveTheFollowingConfig(PyStringNode $config): void
    {
        $this->writeFile('psalm.xml', sprintf($config->getRaw(), ''));
    }

    #[Given('I have the following code preamble')]
    public function iHaveTheFollowingCodePreamble(PyStringNode $preamble): void
    {
        $this->codePreamble = $preamble->getRaw();
    }

    #[Given('I have the following code')]
    public function iHaveTheFollowingCode(PyStringNode $code): void
    {
        $this->writeFile('code.php', $this->codePreamble . "\n" . $code->getRaw());
    }

    #[When('I run Psalm')]
    public function iRunPsalm(): void
    {
        $this->runPsalm([]);
    }

    #[Then('I see no errors')]
    public function iSeeNoErrors(): void
    {
        invariant(
            !$this->processFailed,
            "Psalm failures encountered: %s",
            $this->processOutput(),
        );
    }

    #[Then('I see these errors')]
    public function iSeeTheseErrors(TableNode $table): void
    {
        // Just some fancy translation: wanted to avoid doing it the procedural way
        $expectedErrors = Type\vec(Type\converted(
            Type\shape([
                'Type'    => Type\non_empty_string(),
                'Message' => Type\non_empty_string(),
            ]),
            Type\shape([
                'type'    => Type\non_empty_string(),
                'message' => Type\non_empty_string(),
            ]),
            static fn(array $coerced) => [
                'type'    => $coerced['Type'],
                'message' => $coerced['Message'],
            ]
        ))->coerce($table->getColumnsHash());

        /**
         * @template T of array{type: non-empty-string, message: non-empty-string}
         *
         * @param T $a
         * @param T $b
         */
        $equals = function (array $a, array $b): int {
            return (int)($a !== $b);
        };

        /** @psalm-suppress InvalidArgument `array_uintersect` variadic type is not well-stubbed (yet) */
        $intersection = array_uintersect($expectedErrors, $this->errors, $equals);

        invariant(
            count($expectedErrors) === count($intersection),
            "Some errors didn't match expected ones.\nExpected:\n%s\n\nActual:\n\n%s",
            Json\encode($expectedErrors, true),
            Json\encode($this->errors, true),
        );

        /**
         * @psalm-suppress InvalidArgument `array_udiff` variadic type is not well-stubbed (yet)
         * @psalm-suppress PropertyTypeCoercion `array_udiff` return type is not well-stubbed (yet)
         */
        $this->errors = array_udiff($this->errors, $expectedErrors, $equals);
    }

    #[Then('I see no other errors')]
    public function iSeeNoOtherErrors(): void
    {
        invariant(
            $this->errors === [],
            "No further errors expected, found: %s",
            Json\encode($this->errors, true),
        );
    }

    #[When('I run Psalm with dead code detection')]
    public function iRunPsalmWithDeadCodeDetection(): void
    {
        $this->runPsalm(['--find-dead-code']);
    }

    #[Then('I see exit code :exitCode')]
    public function iSeeExitCode(int $exitCode): void
    {
        invariant(
            $exitCode === $this->exitCode,
            "Exit code for psalm expected to be %d, found %d",
            $exitCode,
            $this->exitCode,
        );
    }

    #[Given('I have the following code in :arg1')]
    public function iHaveTheFollowingCodeIn(string $file, PyStringNode $code): void
    {
        $this->writeFile($file, $code->getRaw());
    }

    #[When('I run Psalm on :file')]
    public function iRunPsalmOn(string $file): void
    {
        $this->runPsalm([
            Type\non_empty_string()
                ->coerce($file),
        ]);
    }
}
