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
    /** @var list<array{type: non-empty-string, message: non-empty-string, line: int|null}> */
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
            $this->errors        = \array_map(
                // Psalm >= 7.0.1 reports "seems to have no effect, its result is not used"
                // for unused pure calls: older versions say "is not used". The suite runs on both.
                static fn(array $error): array => [
                    'type'    => $error['type'],
                    'message' => Type\non_empty_string()->coerce(
                        \str_replace(' seems to have no effect, its result is not used', ' is not used', $error['message']),
                    ),
                    'line'    => $error['line_from'],
                ],
                Json\typed(
                    $output,
                    Type\vec(Type\shape([
                        'type'      => Type\non_empty_string(),
                        'message'   => Type\non_empty_string(),
                        'line_from' => Type\int(),
                    ])),
                ),
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
        // Just some fancy translation: wanted to avoid doing it the procedural way.
        // The Line column is optional: a missing line matches any line.
        $expectedErrors = Type\vec(Type\converted(
            Type\shape([
                'Type'    => Type\non_empty_string(),
                'Message' => Type\non_empty_string(),
                'Line'    => Type\optional(Type\int()),
            ]),
            Type\shape([
                'type'    => Type\non_empty_string(),
                'message' => Type\non_empty_string(),
                'line'    => Type\nullable(Type\int()),
            ]),
            static fn(array $coerced) => [
                'type'    => $coerced['Type'],
                'message' => $coerced['Message'],
                'line'    => $coerced['Line'] ?? null,
            ]
        ))->coerce($table->getColumnsHash());

        /**
         * @param array{type: non-empty-string, message: non-empty-string, line: int|null} $expected
         * @param array{type: non-empty-string, message: non-empty-string, line: int|null} $actual
         */
        $matches = static fn(array $expected, array $actual): bool => $expected['type'] === $actual['type']
            && $expected['message'] === $actual['message']
            && ($expected['line'] === null || $expected['line'] === $actual['line']);

        // Explicit matching: a wildcard line makes the comparison non-transitive, so it must not drive a sort.
        $unmatchedExpected = array_filter(
            $expectedErrors,
            fn(array $expected): bool => [] === array_filter(
                $this->errors,
                static fn(array $actual): bool => $matches($expected, $actual),
            ),
        );

        invariant(
            [] === $unmatchedExpected,
            "Some errors didn't match expected ones.\nExpected:\n%s\n\nActual:\n\n%s",
            Json\encode($expectedErrors, true),
            Json\encode($this->errors, true),
        );

        $this->errors = array_values(array_filter(
            $this->errors,
            static fn(array $actual): bool => [] === array_filter(
                $expectedErrors,
                static fn(array $expected): bool => $matches($expected, $actual),
            ),
        ));
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
