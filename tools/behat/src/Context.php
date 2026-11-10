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
use Psl\File;
use Psl\Filesystem;

use function Psl\invariant;

use Psl\Json;
use Psl\SecureRandom;
use Psl\Shell;
use Psl\Shell\ErrorOutputBehavior;
use Psl\Shell\Exception\FailedExecutionException;
use Psl\Str;
use Psl\Type;

/** @psalm-suppress UnusedClass psalm does not understand Behat context marker interfaces (yet) */
final class Context implements BehatContext
{
    /** @var non-empty-string|null */
    private ?string $scenarioDirectory = null;
    private const DEFAULT_PREAMBLE = "<?php\nnamespace NS;\nuse PHPUnit\\Framework\\TestCase;\n";

    private int $errorLevel = 1;
    private bool $checksForThrowsDocblock = false;
    private ?string $autoloader = null;
    /** @var list<string> */
    private array $suppressedIssues = [];
    /** @var list<string> */
    private array $suppressedPluginIssues = [];
    /** @var list<string> */
    private array $ignoredExceptions = [];
    /** @var list<string> */
    private array $ignoredPackages = [];
    private ?string $phpunitVersion = null;
    private bool $declaresDataProviderClosure = false;
    private string $codePreamble = self::DEFAULT_PREAMBLE;
    private ?string $processOutput = null;
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

        $shim = $this->versionShimFile();
        if (Filesystem\is_file($shim)) {
            Filesystem\delete_file($shim);
        }
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
        $this->writeConfig();

        try {
            $this->processOutput = Shell\execute(
                __DIR__ . '/../../../vendor/bin/psalm',
                \array_merge(
                    [
                        '--no-progress',
                        '--no-cache',
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

    #[Given('the error level is :level')]
    public function theErrorLevelIs(int $level): void
    {
        $this->errorLevel = $level;
    }

    #[Given('Psalm checks for throws docblocks')]
    public function psalmChecksForThrowsDocblocks(): void
    {
        $this->checksForThrowsDocblock = true;
    }

    #[Given('the config uses the autoloader :file')]
    public function theConfigUsesTheAutoloader(string $file): void
    {
        $this->autoloader = $file;
    }

    #[Given('the config suppresses the issue :issue')]
    public function theConfigSuppressesTheIssue(string $issue): void
    {
        $this->suppressedIssues[] = $issue;
    }

    #[Given('the config suppresses the plugin issue :issue')]
    public function theConfigSuppressesThePluginIssue(string $issue): void
    {
        $this->suppressedPluginIssues[] = $issue;
    }

    #[Given('Psalm ignores the exception :class')]
    public function psalmIgnoresTheException(string $class): void
    {
        $this->ignoredExceptions[] = $class;
    }

    /**
     * Psalm reports the issues of a vendor trait in the class that uses it, unless the trait's files are ignored, as
     * a project config usually does.
     */
    #[Given('Psalm ignores the vendor package :package')]
    public function psalmIgnoresTheVendorPackage(string $package): void
    {
        $this->ignoredPackages[] = $package;
    }

    /** Psalm loads the config's autoloader before analysis, and the plugin reads the version from PHPUnit\Runner\Version. */
    #[Given('PHPUnit identifies as version :version')]
    public function phpunitIdentifiesAsVersion(string $version): void
    {
        $this->phpunitVersion = $version;
    }

    /**
     * PHPUnit declares the attribute since 13.1, and the CI matrix also runs older releases: a stub makes the
     * scenario independent of the installed PHPUnit.
     */
    #[Given('PHPUnit declares the DataProviderClosure attribute')]
    public function phpunitDeclaresTheDataProviderClosureAttribute(): void
    {
        $this->declaresDataProviderClosure = true;
    }

    /**
     * The shim lives beside the scenario directory, so it is not part of the analysed project.
     *
     * @return non-empty-string
     */
    private function versionShimFile(): string
    {
        return $this->scenarioDirectory() . '-phpunit-version.php';
    }

    /**
     * Unused suppressions are reported, so a scenario that suppresses an issue also proves that it is raised.
     */
    private function writeConfig(): void
    {
        $autoloader = $this->autoloader;
        $version    = $this->phpunitVersion;
        if ($version !== null) {
            $autoloader = $this->writeVersionShim($version);
        }

        $attributes = \sprintf('errorLevel="%d" findUnusedCode="false" findUnusedPsalmSuppress="true"', $this->errorLevel);
        if ($this->checksForThrowsDocblock) {
            $attributes .= ' checkForThrowsDocblock="true"';
        }
        if ($autoloader !== null) {
            $attributes .= \sprintf(' autoloader="%s"', self::xml($autoloader));
        }

        $issueHandlers = '';
        foreach (['MissingClassConstType', 'DeprecatedMethod', ...$this->suppressedIssues] as $issue) {
            $issueHandlers .= \sprintf("    <%s errorLevel=\"suppress\"/>\n", $issue);
        }
        foreach ($this->suppressedPluginIssues as $issue) {
            $issueHandlers .= \sprintf("    <PluginIssue name=\"%s\" errorLevel=\"suppress\"/>\n", self::xml($issue));
        }

        $extra = '';
        if ($this->ignoredExceptions !== []) {
            $extra .= "  <ignoreExceptions>\n";
            foreach ($this->ignoredExceptions as $class) {
                $extra .= \sprintf("    <classAndDescendants name=\"%s\"/>\n", self::xml($class));
            }
            $extra .= "  </ignoreExceptions>\n";
        }
        if ($this->declaresDataProviderClosure) {
            $extra .= \sprintf(
                "  <stubs><file name=\"%s\"/></stubs>\n",
                self::xml(__DIR__ . '/../stubs/DataProviderClosure.phpstub'),
            );
        }

        $ignoredFiles = '<directory name="../../vendor"/>';
        foreach ($this->ignoredPackages as $package) {
            $ignoredFiles .= \sprintf(' <directory name="%s"/>', self::xml(\dirname(__DIR__, 3) . '/vendor/' . $package));
        }

        $this->writeFile('psalm.xml', <<<XML
            <?xml version="1.0"?>
            <psalm {$attributes}>
              <projectFiles>
                <directory name="."/>
                <ignoreFiles> {$ignoredFiles} </ignoreFiles>
              </projectFiles>
              <plugins>
                <pluginClass class="Psalm\PhpUnitPlugin\Plugin"/>
              </plugins>
              <issueHandlers>
            {$issueHandlers}  </issueHandlers>
            {$extra}</psalm>

            XML);
    }

    /**
     * Declares PHPUnit\Runner\Version and then requires the scenario's own autoloader, if any.
     *
     * @return non-empty-string the autoloader to configure
     */
    private function writeVersionShim(string $version): string
    {
        $own  = $this->autoloader;
        $shim = $this->versionShimFile();
        File\write($shim, \sprintf(
            "<?php\nnamespace PHPUnit\\Runner {\n    final class Version\n    {\n"
            . "        public static function id(): string\n        {\n            return %s;\n        }\n\n"
            . "        public static function majorVersionNumber(): int\n        {\n            return %d;\n        }\n    }\n}\n"
            . "namespace {\n%s}\n",
            \var_export($version, true),
            (int) $version,
            $own === null ? '' : \sprintf(
                "    require_once %s;\n",
                \var_export(\str_starts_with($own, '/') ? $own : $this->scenarioDirectory() . '/' . $own, true),
            ),
        ));

        return $shim;
    }

    private static function xml(string $value): string
    {
        return \htmlspecialchars($value, \ENT_XML1 | \ENT_QUOTES);
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
            ],
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
