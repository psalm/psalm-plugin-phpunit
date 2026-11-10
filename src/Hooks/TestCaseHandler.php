<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node;
use PhpParser\Node\Attribute;
use PhpParser\Node\AttributeGroup;
use PhpParser\Node\Expr;
use PhpParser\Node\Expr\Array_;
use PhpParser\Node\Expr\ClassConstFetch;
use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Expr\Variable;
use PhpParser\Node\Expr\Yield_;
use PhpParser\Node\Expr\YieldFrom;
use PhpParser\Node\Identifier;
use PhpParser\Node\Name;
use PhpParser\Node\Scalar\Int_;
use PhpParser\Node\Scalar\String_;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use PhpParser\Node\Stmt\Return_;
use PhpParser\NodeTraverser;
use PhpParser\NodeVisitor;
use PhpParser\NodeVisitorAbstract;
use PHPUnit\Framework\Attributes\Before;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\DataProviderExternal;
use PHPUnit\Framework\Attributes\Depends;
use PHPUnit\Framework\Attributes\DependsExternal;
use PHPUnit\Framework\Attributes\DependsExternalUsingDeepClone;
use PHPUnit\Framework\Attributes\DependsExternalUsingShallowClone;
use PHPUnit\Framework\Attributes\DependsUsingDeepClone;
use PHPUnit\Framework\Attributes\DependsUsingShallowClone;
use PHPUnit\Framework\Attributes\Test;
use Psalm\Aliases;
use Psalm\Codebase;
use Psalm\CodeLocation;
use Psalm\Internal\Analyzer\ClassLikeAnalyzer;
use Psalm\Internal\MethodIdentifier;
use Psalm\IssueBuffer;
use Psalm\Issue;
use Psalm\PhpUnitPlugin\Dataset\DatasetBinding;
use Psalm\PhpUnitPlugin\DocblockSpecials;
use Psalm\PhpUnitPlugin\Issue\InvalidDataProvider;
use Psalm\PhpUnitPlugin\Issue\InvalidPhpUnitAnnotation;
use Psalm\PhpUnitPlugin\PhpUnitVersion;
use Psalm\PhpUnitPlugin\Suppressions;
use Psalm\Plugin\EventHandler\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\AfterClassLikeVisitInterface;
use Psalm\Plugin\EventHandler\AfterCodebasePopulatedInterface;
use Psalm\Plugin\EventHandler\AfterMethodCallAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeAnalysisEvent;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeVisitEvent;
use Psalm\Plugin\EventHandler\Event\AfterCodebasePopulatedEvent;
use Psalm\Plugin\EventHandler\Event\AfterMethodCallAnalysisEvent;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Storage\MethodStorage;
use Psalm\Type;
use Psalm\Type\Atomic\TNull;
use RuntimeException;

use function array_column;
use function array_filter;
use function array_map;
use function array_merge;
use function array_slice;
use function array_values;
use function count;
use function explode;
use function in_array;
use function is_string;
use function ltrim;
use function max;
use function preg_match;
use function str_contains;
use function str_ends_with;
use function str_starts_with;
use function strtolower;

final class TestCaseHandler implements
    AfterClassLikeVisitInterface,
    AfterClassLikeAnalysisInterface,
    AfterCodebasePopulatedInterface,
    AfterMethodCallAnalysisInterface
{
    /** @var array<class-string, bool> attribute class => whether it names the target class explicitly */
    private const DEPENDS_ATTRIBUTES = [
        Depends::class => false,
        DependsUsingDeepClone::class => false,
        DependsUsingShallowClone::class => false,
        DependsExternal::class => true,
        DependsExternalUsingDeepClone::class => true,
        DependsExternalUsingShallowClone::class => true,
    ];

    private const DATA_PROVIDER_CLOSURE = 'PHPUnit\\Framework\\Attributes\\DataProviderClosure';

    private const EXPECT_EXCEPTION_METHODS = [
        'phpunit\\framework\\testcase::expectexception' => true,
        'phpunit\\framework\\testcase::expectexceptioncode' => true,
        'phpunit\\framework\\testcase::expectexceptionmessage' => true,
        'phpunit\\framework\\testcase::expectexceptionmessagematches' => true,
        'phpunit\\framework\\testcase::expectexceptionobject' => true,
    ];

    /**
     * PHPUnit's own exceptions are handled by the test runner, nobody documents or catches them in tests.
     * Psalm matches a thrown class only against listed parent classes, so classes that merely implement one of
     * the interfaces are listed on their own.
     */
    private const IGNORED_EXCEPTIONS = [
        'PHPUnit\\Exception',
        'PHPUnit\\Framework\\Exception',
        'PHPUnit\\Framework\\MockObject\\Exception',
        'PHPUnit\\Framework\\MockObject\\ReflectionException',
        'PHPUnit\\Framework\\MockObject\\RuntimeException',
        'PHPUnit\\Event\\NoPreviousThrowableException',
        'PHPUnit\\Util\\Exception',
        'PHPUnit\\Util\\InvalidJsonException',
        'PHPUnit\\Util\\Xml\\XmlException',
    ];

    /**
     * Statements after expectException*() may exist only to throw, so their results are unused and PHPUnit catches
     * the exception.
     */
    #[\Override]
    public static function afterMethodCallAnalysis(AfterMethodCallAnalysisEvent $event): void
    {
        if (!isset(self::EXPECT_EXCEPTION_METHODS[strtolower($event->getDeclaringMethodId())])) {
            return;
        }

        // PHPUnit stores the expectation on the receiver, so only the current test's own expectations count.
        $expr = $event->getExpr();
        $isOwnExpectation = $expr instanceof MethodCall
            ? $expr->var instanceof Variable && $expr->var->name === 'this'
            : $expr->class instanceof Name
                && in_array(strtolower($expr->class->toString()), ['self', 'static', 'parent'], true);
        if (!$isOwnExpectation) {
            return;
        }

        $event->getStatementsSource()->addSuppressedIssues([
            'UnusedFunctionCall',
            'UnusedMethodCall',
            'MissingThrowsDocblock',
        ]);
    }

    #[\Override]
    public static function afterCodebasePopulated(AfterCodebasePopulatedEvent $event)
    {
        $codebase = $event->getCodebase();

        foreach (self::IGNORED_EXCEPTIONS as $exception) {
            $codebase->config->ignored_exceptions_and_descendants[$exception] = true;
            $codebase->config->ignored_exceptions_and_descendants_in_global_scope[$exception] = true;
        }

        foreach ($codebase->classlike_storage_provider->getAll() as $name => $storage) {
            $meta = (array) ($storage->custom_metadata[__NAMESPACE__] ?? []);
            if ($codebase->classExtends($name, 'PHPUnit\Framework\TestCase') && ($meta['hasInitializers'] ?? false)) {
                $storage->suppressed_issues[] = 'MissingConstructor';

                foreach (self::getDescendants($codebase, $name) as $dependent_name) {
                    $dependent_storage = $codebase->classlike_storage_provider->get($dependent_name);
                    $dependent_storage->suppressed_issues[] = 'MissingConstructor';
                }
            }
        }
    }

    /**
     * @return string[]
     *
     * @psalm-mutation-free
     */
    private static function getDescendants(Codebase $codebase, string $name): array
    {
        if (!$codebase->classlike_storage_provider->has($name)) {
            return [];
        }

        $storage = $codebase->classlike_storage_provider->get($name);
        $ret = [];

        foreach ($storage->dependent_classlikes as $dependent => $_) {
            if ($codebase->classExtends($dependent, $name)) {
                $ret[] = $dependent;
                $ret = array_merge($ret, self::getDescendants($codebase, $dependent));
            }
        }
        return $ret;
    }

    #[\Override]
    public static function afterClassLikeVisit(AfterClassLikeVisitEvent $event)
    {
        $class_node        = $event->getStmt();
        $class_storage     = $event->getStorage();
        $statements_source = $event->getStatementsSource();
        $codebase          = $event->getCodebase();
        $aliases           = $statements_source->getAliases();

        // Psalm 7 seals methods by default, so ObjectProphecy::__call() is ignored
        if (strtolower($class_storage->name) === 'prophecy\\prophecy\\objectprophecy') {
            $class_storage->sealed_methods = false;
        }

        if (self::hasInitializers($class_storage, $class_node, $aliases)) {
            $class_storage->custom_metadata[__NAMESPACE__] = ['hasInitializers' => true];
        }

        $file_path    = $statements_source->getFilePath();
        $file_storage = $codebase->file_storage_provider->get($file_path);

        foreach ($class_node->getMethods() as $method) {
            $providers = self::getDataProviders($method, $aliases, $aliases, $class_storage);
            foreach ($providers as $provider) {
                if ($provider['class'] === null) {
                    continue;
                }
                $codebase->queueClassLikeForScanning($provider['class']);
                $file_storage->referenced_classlikes[strtolower($provider['class'])] = $provider['class'];
            }

            $method_storage = $class_storage->methods[strtolower($method->name->name)] ?? null;
            if (
                $method_storage === null
                || $providers === []
                || count($providers) < self::countProviderAttributes($method, $aliases)
            ) {
                continue;
            }

            $test_specials = self::getSpecials($method, $aliases);
            $method_storage->custom_metadata[DataProviderNarrowingHandler::METADATA_KEY] = [
                // the test's own class is resolved at analysis, where a trait method has the class that uses it
                'providers' => array_map(
                    static fn(array $provider): array => [$provider['class'] ?? '', $provider['method']],
                    $providers,
                ),
                'test'      => isset($test_specials['test']),
                'depends'   => self::getDependencyTargets($method, $aliases, $class_storage) !== [],
            ];
        }
    }

    #[\Override]
    public static function afterStatementAnalysis(AfterClassLikeAnalysisEvent $event)
    {
        $class_node        = $event->getStmt();
        $class_storage     = $event->getClasslikeStorage();
        $codebase          = $event->getCodebase();
        $statements_source = $event->getStatementsSource();
        $aliases           = $statements_source->getAliases();

        if (!$codebase->classExtends($class_storage->name, 'PHPUnit\Framework\TestCase')) {
            return null;
        }

        // This should always pass, we're calling it for the side-effect of adding self-reference
        // in order to
        // 1. Inform Psalm that class is used
        // 2. Make Psalm analyze unused methods
        //
        // Marking class as used is required to get more detailed dead-code analysis (like unused
        // methods). If we instead just suppress UnusedClass, unused methods are not analyzed.
        if (!$codebase->classOrInterfaceExists($class_storage->name, $class_storage->location)) {
            return null;
        }

        $class_location = new CodeLocation($statements_source, $class_node);
        self::reportMalformedTags(
            $class_node,
            $class_location,
            Suppressions::of($class_location, [], $class_storage, $statements_source),
        );

        // PHPUnit merges the class docblocks of the traits used directly by the test case, not of nested ones
        foreach ($class_storage->used_traits as $trait_name) {
            $trait_storage = $codebase->classlike_storage_provider->get($trait_name);
            if (!$trait_storage->location) {
                continue;
            }

            $trait_location = $trait_storage->stmt_location ?? $trait_storage->location;
            self::reportMalformedTags(
                $codebase->classlikes->getTraitNode($trait_name),
                $trait_location,
                Suppressions::of(
                    $trait_location,
                    $trait_storage->suppressed_issues,
                    $class_storage,
                    $statements_source,
                ),
            );
        }

        foreach ($class_storage->declaring_method_ids as $method_name_lc => $declaring_method_id) {
            $method_name    = $codebase->getCasedMethodId($class_storage->name . '::' . $method_name_lc);
            $method_storage = $codebase->methods->getStorage($declaring_method_id);
            [$declaring_method_class, $declaring_method_name] = explode('::', (string)$declaring_method_id);
            $declaring_class_storage = $codebase->classlike_storage_provider->get($declaring_method_class);

            $declaring_class_node = $class_node;
            if ($declaring_class_storage->is_trait) {
                $declaring_class_node = $codebase->classlikes->getTraitNode($declaring_class_storage->name);
            }

            if (!$method_storage->location) {
                continue;
            }

            // The class declaring an inherited test does not see the providers its descendants implement
            if (!$declaring_class_storage->is_trait && $declaring_class_storage->name !== $class_storage->name) {
                self::checkInheritedTestProviders(
                    $codebase,
                    $statements_source,
                    $class_storage,
                    $method_name_lc,
                    $method_storage,
                );
                continue;
            }

            $stmt_method = $declaring_class_node->getMethod($declaring_method_name);

            if (!$stmt_method) {
                continue;
            }

            // Use the declaring class's aliases so trait-declared attributes resolve via the trait's imports.
            $method_aliases = $declaring_class_storage->aliases ?? $aliases;
            $specials = self::getSpecials($stmt_method, $method_aliases);

            $test_suppressions = Suppressions::of(
                $method_storage->location,
                $method_storage->suppressed_issues + $declaring_class_storage->suppressed_issues,
                $class_storage,
                $statements_source,
            );

            self::reportMalformedTags($stmt_method, $method_storage->location, $test_suppressions);

            $is_test = 0 === strpos($method_name_lc, 'test') || isset($specials['test']);
            if (!$is_test) {
                continue; // skip non-test methods
            }

            $codebase->methodExists(
                (string) $declaring_method_id,
                calling_method_id: 'PHPUnit\Framework\TestSuite::run',
            );

            $providers = self::getDataProviders($stmt_method, $method_aliases, $aliases, $class_storage);
            $closure_providers = self::getClosureProviders($stmt_method, $method_aliases);
            if ($providers === [] && $closure_providers === []) {
                continue;
            }

            $dependency_values = self::countDependencyValues(
                $codebase,
                $stmt_method,
                $method_aliases,
                $class_storage,
            );
            $appends_dependency_value = self::appendsDependencyValue(
                $codebase,
                $class_node,
                $class_storage,
                $stmt_method,
                $method_aliases,
            );

            /**
             * @var list<array{
             *     name: string,
             *     type: Type\Union,
             *     location: CodeLocation,
             *     return_type_location: CodeLocation,
             *     return_type_suppressions: array<array-key, string>
             * }> $provided_types
             */
            $provided_types = [];
            foreach ($providers as $provider) {
                $provider_docblock_location = $method_storage->location->setCommentLine($provider['line']);

                if ($provider['class'] !== null) {
                    $fq_class_name = $provider['class'];

                    if (!$codebase->classOrInterfaceExists($fq_class_name, $provider_docblock_location)) {
                        // Psalm reports the missing class of an attribute argument itself
                        if (!$provider['external']) {
                            IssueBuffer::accepts(new Issue\UndefinedClass(
                                'Class ' . $fq_class_name . ' does not exist',
                                $provider_docblock_location,
                                $fq_class_name
                            ), $test_suppressions);
                        }
                        continue;
                    }
                    $apparent_provider_method_name = $fq_class_name . '::' . $provider['method'];
                } else {
                    $apparent_provider_method_name = $class_storage->name . '::' . $provider['method'];
                }

                // getDeclaringMethodId() would truncate "Class::A::b" to "Class::A", so never look such a name up
                $provider_method_id = str_contains($provider['method'], '::')
                    ? null
                    : $codebase->getDeclaringMethodId($apparent_provider_method_name);

                if (null === $provider_method_id) {
                    IssueBuffer::accepts(new Issue\UndefinedMethod(
                        'Provider method ' . $apparent_provider_method_name . ' is not defined',
                        $provider_docblock_location,
                        $apparent_provider_method_name
                    ), $test_suppressions);
                    continue;
                }

                // methodExists also can mark methods as used (weird, but handy)
                $provider_method_exists = $codebase->methodExists(
                    $provider_method_id,
                    calling_method_id: (string) $declaring_method_id,
                    code_location: $provider_docblock_location,
                );

                if (!$provider_method_exists) {
                    IssueBuffer::accepts(new Issue\UndefinedMethod(
                        'Provider method ' . $apparent_provider_method_name . ' is not defined',
                        $provider_docblock_location,
                        $apparent_provider_method_name
                    ), $test_suppressions);
                    continue;
                }

                $provider_id             = MethodIdentifier::wrap($provider_method_id);
                $provider_method_storage = $codebase->methods->getStorage($provider_id);
                $provider_class_storage  = $codebase->classlike_storage_provider->get($provider_id->fq_class_name);

                // Abstract providers are checked on the concrete classes implementing them
                if (!$provider_method_storage->abstract) {
                    self::reportInvalidProviderSignature(
                        $codebase,
                        $provider_method_storage,
                        $apparent_provider_method_name,
                        $provider_docblock_location,
                        $test_suppressions,
                    );

                    // Providers declared elsewhere are not read
                    $provider_node = $provider_id->fq_class_name === $class_storage->name
                        ? $class_node->getMethod($provider_id->method_name)
                        : null;
                    if ($provider_node !== null) {
                        self::reportPositionalAfterNamed(
                            $statements_source,
                            $provider_node->stmts ?? [],
                            'a dataset provided by ' . $provider_method_id . '()',
                            $test_suppressions,
                        );
                    }
                }

                $provider_return_type = $codebase->getMethodReturnType($provider_method_id, $_);

                if (!$provider_return_type) {
                    continue;
                }

                $provider_return_type_location = $codebase->getMethodReturnTypeLocation($provider_method_id);
                assert(null !== $provider_return_type_location);
                $provided_types[] = [
                    'name'                 => $provider_method_id . '()',
                    'type'                 => $provider_return_type,
                    'location'             => $provider_docblock_location,
                    'return_type_location' => $provider_return_type_location,
                    'return_type_suppressions' => Suppressions::of(
                        $provider_return_type_location,
                        $provider_method_storage->suppressed_issues + $provider_class_storage->suppressed_issues,
                        $class_storage,
                        $statements_source,
                    ),
                ];
            }

            foreach ($closure_providers as $closure) {
                // A closure of a trait lives in another file than the one analysed
                if (!$declaring_class_storage->is_trait) {
                    self::reportPositionalAfterNamed(
                        $statements_source,
                        $closure['statements'],
                        'a dataset provided by #[DataProviderClosure]',
                        $test_suppressions,
                    );
                }

                $closure_return_type = DataProviderClosureHandler::returnType($method_storage, $closure['position']);
                if ($closure_return_type === null) {
                    continue;
                }

                $closure_location = $method_storage->location->setCommentLine($closure['line']);
                $provided_types[] = [
                    'name'                 => '#[DataProviderClosure]',
                    'type'                 => $closure_return_type,
                    'location'             => $closure_location,
                    'return_type_location' => $closure_location,
                    'return_type_suppressions' => $test_suppressions,
                ];
            }

            foreach ($provided_types as $provided) {
                $provider_name                 = $provided['name'];
                $provider_return_type          = $provided['type'];
                $provider_docblock_location    = $provided['location'];
                $provider_return_type_location = $provided['return_type_location'];
                $return_type_suppressions      = $provided['return_type_suppressions'];
                $provider_return_type_string   = $provider_return_type->getId();

                $expected_provider_return_type = new Type\Atomic\TIterable([
                    Type::getArrayKey(),
                    Type::getArray(),
                ]);

                $non_null_provider_return_types = [];
                foreach (self::getAtomics($provider_return_type) as $type) {
                    // PHPUnit allows returning null from providers and treats it as an empty set
                    // resulting in the test being skipped
                    if ($type instanceof TNull) {
                        continue;
                    }

                    if (!$type->isIterable($codebase)) {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ), $return_type_suppressions);
                        continue 2;
                    }
                    $non_null_provider_return_types[] = $type;
                }

                if ([] === $non_null_provider_return_types) {
                    IssueBuffer::accepts(new Issue\InvalidReturnType(
                        'Providers must return ' . $expected_provider_return_type->getId()
                        . ', ' . $provider_return_type_string . ' provided',
                        $provider_return_type_location
                    ), $return_type_suppressions);
                    continue;
                }

                // unionize iterable so that instead of array<int,string>|Traversable<object|int>
                // we get iterable<int|object,string|int>
                //
                // TODO: this may get implemented in a future Psalm version, remove it then
                $provider_return_type = self::unionizeIterables(
                    $codebase,
                    new Type\Union($non_null_provider_return_types)
                );

                $provider_key_type_is_compatible = $codebase->isTypeContainedByType(
                    $provider_return_type->type_params[0],
                    $expected_provider_return_type->type_params[0]
                );

                if (!$provider_key_type_is_compatible) {
                    // XXX: isn't array key allowed by the $expected_provider_return_type ?
                    $provider_key_type_is_uncertain =
                        $provider_return_type->type_params[0]->hasMixed()
                        || $provider_return_type->type_params[0]->hasArrayKey();

                    if ($provider_key_type_is_uncertain) {
                        IssueBuffer::accepts(new Issue\MixedReturnStatement(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', possibly different ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ), $return_type_suppressions);
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ), $return_type_suppressions);
                    }
                    continue;
                }

                $provider_value_type_is_compatible = $codebase->isTypeContainedByType(
                    $provider_return_type->type_params[1],
                    $expected_provider_return_type->type_params[1]
                );

                if (!$provider_value_type_is_compatible) {
                    if ($provider_return_type->type_params[1]->hasMixed()) {
                        IssueBuffer::accepts(new Issue\MixedReturnStatement(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', possibly different ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ), $return_type_suppressions);
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ), $return_type_suppressions);
                    }
                    continue;
                }

                // An empty array has no datasets to check
                if ($provider_return_type->type_params[1]->isNever()) {
                    continue;
                }

                $checkParam =
                static function (
                    Type\Union $potential_argument_type,
                    Type\Union $param_type,
                    bool $is_optional,
                    int $param_offset,
                    ?string $param_name = null
                ) use (
                    $codebase,
                    $method_name,
                    $provider_name,
                    $provider_return_type_string,
                    $provider_docblock_location,
                    $test_suppressions
                ): void {
                    $argument = 'Argument ' . ($param_offset + 1)
                        . ($param_name === null ? '' : ' ($' . $param_name . ')');
                    if ($is_optional) {
                        $param_type = $param_type->setPossiblyUndefined(true);
                    }
                    if ($codebase->isTypeContainedByType($potential_argument_type, $param_type)) {
                        // ok
                    } elseif ($codebase->canTypeBeContainedByType($potential_argument_type, $param_type)) {
                        IssueBuffer::accepts(new Issue\PossiblyInvalidArgument(
                            $argument . ' of ' . $method_name
                            . ' expects ' . $param_type->getId() . ', '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_name . ':(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ), $test_suppressions);
                    } elseif ($potential_argument_type->possibly_undefined && !$is_optional) {
                        IssueBuffer::accepts(new Issue\InvalidArgument(
                            $argument . ' of ' . $method_name
                            . ' is not optional, but possibly undefined '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_name . ':(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ), $test_suppressions);
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidArgument(
                            $argument . ' of ' . $method_name
                            . ' expects ' . $param_type->getId() . ', '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_name . ':(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ), $test_suppressions);
                    }
                };

                /** @var Type\Atomic\TArray|Type\Atomic\TKeyedArray $dataset_type */
                $dataset_type = self::getAtomics($provider_return_type->type_params[1])['array'];

                if ($dataset_type instanceof Type\Atomic\TArray) {
                    // The dataset length is unknown, so assume the trailing params receive the return values
                    // of depended-upon tests, unless a variadic param could consume them.
                    $last_param      = array_slice($method_storage->params, -1)[0] ?? null;
                    $provider_params = array_slice(
                        $method_storage->params,
                        0,
                        $last_param !== null && $last_param->is_variadic
                            ? null
                            : max(0, count($method_storage->params) - $dependency_values),
                    );
                    // check that all of the required (?) params accept value type
                    $potential_argument_type = $dataset_type->type_params[1];
                    foreach ($provider_params as $param_offset => $param) {
                        if (!$param->type) {
                            continue;
                        }
                        $checkParam($potential_argument_type, $param->type, $param->is_optional, $param_offset);
                    }
                } elseif (self::hasStringKeys($dataset_type)) {
                    $provided_by = $provider_name . ':(' . $provider_return_type_string . ')';
                    $binding     = DatasetBinding::bind($dataset_type, $method_storage->params, $codebase);

                    foreach ($binding->arguments as $argument) {
                        $checkParam(
                            $argument->type,
                            $argument->param_type,
                            $argument->is_optional,
                            $argument->position,
                            $argument->name,
                        );
                    }

                    foreach ($binding->unknown as $name) {
                        IssueBuffer::accepts(new Issue\InvalidNamedArgument(
                            'Parameter $' . $name . ' does not exist on ' . $method_name
                            . ', provided by ' . $provided_by,
                            $provider_docblock_location,
                            $method_name
                        ), $test_suppressions);
                    }

                    foreach ($binding->duplicate as $name) {
                        IssueBuffer::accepts(new Issue\InvalidNamedArgument(
                            'Parameter $' . $name . ' has already been used in ' . $method_name
                            . ', provided by ' . $provided_by,
                            $provider_docblock_location,
                            $method_name
                        ), $test_suppressions);
                    }

                    if ($appends_dependency_value && self::hasStringKeys($dataset_type, required_only: true)) {
                        IssueBuffer::accepts(new Issue\InvalidNamedArgument(
                            'Cannot use positional argument after named argument in ' . $method_name
                            . ': PHPUnit appends the return value of a depended-upon test to dataset ' . $provided_by,
                            $provider_docblock_location,
                            $method_name
                        ), $test_suppressions);

                        continue;
                    }

                    // the return values of depended-upon tests fill the first parameters the dataset leaves open
                    $missing = array_slice($binding->missing, $dependency_values);
                    if ($missing !== []) {
                        IssueBuffer::accepts(new Issue\TooFewArguments(
                            'Too few arguments for ' . $method_name . ' - parameter $' . $missing[0]
                            . ' is not provided by ' . $provided_by,
                            $provider_docblock_location,
                            $method_name
                        ), $test_suppressions);
                    }
                } else { // TKeyedArray
                    // iterate over all params checking if corresponding value type is acceptable
                    // let's hope properties are sorted in array order
                    $potential_argument_types = array_values($dataset_type->properties);

                    foreach ($method_storage->params as $param_offset => $param) {
                        if (!isset($potential_argument_types[$param_offset])) {
                            // variadics are never required
                            // and they always come last
                            if ($param->is_variadic) {
                                break;
                            }
                            // reached default params, so it's fine, but let's continue
                            // because MisplacedRequiredParam could be suppressed
                            if ($param->is_optional) {
                                continue;
                            }
                            // the return values of depended-upon tests follow the provider values
                            if ($param_offset < $dataset_type->getMinCount() + $dependency_values) {
                                continue;
                            }

                            IssueBuffer::accepts(new Issue\TooFewArguments(
                                'Too few arguments for ' . $method_name
                                . ' - expecting at least ' . ($param_offset + 1 - $dependency_values)
                                . ', but saw ' . $dataset_type->getMinCount()
                                . ' provided by ' . $provider_name
                                .  ':(' . $provider_return_type_string . ')',
                                $provider_docblock_location,
                                $method_name
                            ), $test_suppressions);
                            break;
                        }
                        $potential_argument_type = $potential_argument_types[$param_offset];

                        $param_type = $param->type === null ? Type::getMixed() : $param->type;
                        if ($param->is_variadic) {
                            $param_types = self::getAtomics($param_type);
                            $variadic_param_type = new Type\Union(array_values($param_types));

                            // check remaining argument types
                            for (; $param_offset < count($potential_argument_types); $param_offset++) {
                                $potential_argument_type = $potential_argument_types[$param_offset];
                                $checkParam(
                                    $potential_argument_type,
                                    $variadic_param_type,
                                    true,
                                    $param_offset
                                );
                            }
                            break;
                        }

                        $checkParam($potential_argument_type, $param_type, $param->is_optional, $param_offset);
                    }
                }
            }
        }
    }

    /**
     * Checks the providers of a test inherited from an ancestor that the class implements or overrides itself.
     *
     * @param lowercase-string $test_name_lc
     */
    private static function checkInheritedTestProviders(
        Codebase $codebase,
        StatementsSource $statements_source,
        ClassLikeStorage $class_storage,
        string $test_name_lc,
        MethodStorage $test_storage
    ): void {
        $metadata = $test_storage->custom_metadata[DataProviderNarrowingHandler::METADATA_KEY] ?? null;
        if (
            $class_storage->parent_class === null
            || !is_array($metadata)
            || !((bool) $metadata['test'] || str_starts_with($test_name_lc, 'test'))
        ) {
            return;
        }

        /** @var list<array{string, string}> $providers */
        $providers = $metadata['providers'];
        foreach ($providers as [$provider_class, $provider_name]) {
            if ($provider_class !== '' || str_contains($provider_name, '::')) {
                continue;
            }

            // The parent already checked the provider it resolves
            $provider_method_id = $codebase->getDeclaringMethodId($class_storage->name . '::' . $provider_name);
            if (
                $provider_method_id === null
                || $provider_method_id === $codebase->getDeclaringMethodId(
                    $class_storage->parent_class . '::' . $provider_name
                )
            ) {
                continue;
            }

            $provider_id      = MethodIdentifier::wrap($provider_method_id);
            $provider_storage = $codebase->methods->getStorage($provider_id);
            if ($provider_storage->abstract || $provider_storage->location === null) {
                continue;
            }

            self::reportInvalidProviderSignature(
                $codebase,
                $provider_storage,
                $class_storage->name . '::' . $provider_name,
                $provider_storage->location,
                Suppressions::of(
                    $provider_storage->location,
                    $provider_storage->suppressed_issues
                        + $codebase->classlike_storage_provider->get($provider_id->fq_class_name)->suppressed_issues,
                    $class_storage,
                    $statements_source,
                ),
            );
        }
    }

    /** @param array<array-key, string> $suppressed_issues */
    private static function reportInvalidProviderSignature(
        Codebase $codebase,
        MethodStorage $provider_method_storage,
        string $apparent_provider_method_name,
        CodeLocation $location,
        array $suppressed_issues
    ): void {
        $provider_visibility   = $provider_method_storage->visibility;
        $appearing_provider_id = $codebase->methods->getAppearingMethodId(
            MethodIdentifier::wrap($apparent_provider_method_name)
        );
        if (null !== $appearing_provider_id) {
            $provider_visibility = $codebase->classlike_storage_provider
                ->get($appearing_provider_id->fq_class_name)
                ->trait_visibility_map[$appearing_provider_id->method_name]
                ?? $provider_visibility;
        }

        if (ClassLikeAnalyzer::VISIBILITY_PUBLIC !== $provider_visibility) {
            IssueBuffer::accepts(new InvalidDataProvider(
                'Data provider method ' . $apparent_provider_method_name . ' must be public',
                $location
            ), $suppressed_issues);
        }

        if (!$provider_method_storage->is_static) {
            IssueBuffer::accepts(new InvalidDataProvider(
                'Data provider method ' . $apparent_provider_method_name . ' must be static',
                $location
            ), $suppressed_issues);
        }
    }

    /**
     * PHPUnit passes string dataset keys as named arguments, and PHP rejects a positional argument after them.
     * Only literal datasets are read: Psalm's array shapes do not keep the key order.
     *
     * @param array<array-key, Node\Stmt> $statements the body of a provider method or closure
     * @param array<array-key, string> $suppressed_issues
     */
    private static function reportPositionalAfterNamed(
        StatementsSource $source,
        array $statements,
        string $provided_by,
        array $suppressed_issues
    ): void {
        $visitor = new class extends NodeVisitorAbstract {
            public bool $generator = false;

            /** @var list<Array_> */
            public array $returned = [];

            /** @var list<Array_> */
            public array $yielded = [];

            #[\Override]
            public function enterNode(Node $node)
            {
                if ($node instanceof Node\FunctionLike || $node instanceof ClassLike) {
                    return NodeVisitor::DONT_TRAVERSE_CHILDREN;
                }

                $sets = $node instanceof Return_ || $node instanceof YieldFrom ? $node->expr : null;
                foreach ($sets instanceof Array_ ? $sets->items : [] as $item) {
                    if (!$item->unpack && $item->value instanceof Array_) {
                        if ($node instanceof Return_) {
                            $this->returned[] = $item->value;
                        } else {
                            $this->yielded[] = $item->value;
                        }
                    }
                }

                if ($node instanceof YieldFrom || $node instanceof Yield_) {
                    $this->generator = true;
                }

                if ($node instanceof Yield_ && $node->value instanceof Array_) {
                    $this->yielded[] = $node->value;
                }

                return null;
            }
        };
        (new NodeTraverser($visitor))->traverse($statements);

        // PHPUnit ignores the return value of a generator
        foreach ($visitor->generator ? $visitor->yielded : $visitor->returned as $dataset) {
            $named    = false;
            $violated = false;
            $seen     = [];
            $next     = 0;
            foreach ($dataset->items as $item) {
                $key = $item->key;
                if ($item->unpack || ($key !== null && !$key instanceof String_ && !$key instanceof Int_)) {
                    continue 2;
                }

                // PHP casts keys like '1' to int
                if ($key instanceof String_ && (string) (int) $key->value !== $key->value) {
                    $named = true;
                    continue;
                }

                $position = $key === null ? $next : (int) $key->value;
                $next     = max($next, $position + 1);

                // An array keeps the place of a key's first insertion, so overwriting a positional key is harmless
                if ($named && !isset($seen[$position])) {
                    $violated = true;
                }

                $seen[$position] = true;
            }

            if ($violated) {
                IssueBuffer::accepts(new Issue\InvalidNamedArgument(
                    'Cannot use positional argument after named argument in ' . $provided_by,
                    new CodeLocation($source, $dataset)
                ), $suppressed_issues);
            }
        }
    }

    /** @psalm-pure */
    public static function hasStringKeys(Type\Atomic\TKeyedArray $dataset_type, bool $required_only = false): bool
    {
        foreach ($dataset_type->properties as $key => $type) {
            if (is_string($key) && !($required_only && $type->possibly_undefined)) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return non-empty-array<string,Type\Atomic>
     *
     * @psalm-pure
     */
    private static function getAtomics(Type\Union $union): array
    {
        return $union->getAtomicTypes();
    }

    public static function unionizeIterables(Codebase $codebase, Type\Union $iterables): Type\Atomic\TIterable
    {
        /** @var Type\Union[] $key_types */
        $key_types = [];

        /** @var Type\Union[] $value_types */
        $value_types = [];

        foreach (self::getAtomics($iterables) as $type) {
            if (!$type->isIterable($codebase)) {
                throw new RuntimeException('should be iterable');
            }

            if ($type instanceof Type\Atomic\TArray) {
                $key_types[]   = $type->type_params[0] ?? Type::getMixed();
                $value_types[] = $type->type_params[1] ?? Type::getMixed();
            } elseif ($type instanceof Type\Atomic\TKeyedArray) {
                $key_types[]   = $type->getGenericKeyType();
                $value_types[] = $type->getGenericValueType();
            } elseif ($type instanceof Type\Atomic\TNamedObject || $type instanceof Type\Atomic\TIterable) {
                [$key_types[], $value_types[]] = $codebase->getKeyValueParamsForTraversableObject($type);
            } else {
                throw new RuntimeException('unexpected type');
            }
        }

        $combine =
            /**
             * @param null|Type\Union $a
             *
             * @psalm-external-mutation-free
             */
            static function ($a, Type\Union $b) use ($codebase): Type\Union {
                return $a ? Type::combineUnionTypes($a, $b, $codebase) : $b;
            };

        return new Type\Atomic\TIterable([
            array_reduce($key_types, $combine),
            array_reduce($value_types, $combine),
        ]);
    }


    private static function hasInitializers(ClassLikeStorage $storage, ClassLike $stmt, Aliases $aliases): bool
    {
        if (isset($storage->methods['setup'])) {
            return true;
        }

        foreach ($storage->methods as $method => $_) {
            $stmt_method = $stmt->getMethod($method);
            if (!$stmt_method) {
                continue;
            }
            if (self::isBeforeInitializer($stmt_method, $aliases)) {
                return true;
            }
        }
        return false;
    }

    private static function isBeforeInitializer(ClassMethod $method, Aliases $aliases): bool
    {
        return isset(self::getSpecials($method, $aliases)['before']);
    }

    /**
     * The docblock metadata PHPUnit reads: none on PHPUnit 12, and, like PHPUnit's ParserChain, none on a method
     * that has any PHPUnit attribute.
     *
     * @return array<string, list<array{int, string}>> Each entry is [file line, value]
     */
    private static function docblockSpecials(ClassMethod $method, Aliases $aliases): array
    {
        return PhpUnitVersion::ignoresDocblockMetadata() || self::hasPhpUnitAttribute($method, $aliases)
            ? []
            : DocblockSpecials::of($method);
    }

    /** @return array<string, list<array{int, string}>> Each entry is [file line, value] */
    private static function getSpecials(ClassMethod $method, Aliases $aliases): array
    {
        return array_merge(
            self::docblockSpecials($method, $aliases),
            self::getAttributeSpecials($method, $aliases),
        );
    }

    /**
     * @template T of object
     * @param class-string<T> $attributeClass
     * @return list<array{int, string}>|null
     */
    private static function attributeValue(ClassMethod $method, Aliases $aliases, string $attributeClass): array|null
    {
        $onlyStringLiteralExpressions = static fn (Attribute $attribute): array => array_map(
            static fn(String_ $string): array => [$string->getStartLine(), $string->value],
            array_filter(
                array_column($attribute->args, 'value'),
                // For our purposes, we only care about string literals: everything else is currently out of scope.
                // If you need more complex expressions supported, add a constant expression evaluator here.
                static fn(Expr $expression): bool => $expression instanceof String_,
            ),
        );
        $attributesInGroupMatchingRequestedAttributeName = static fn(AttributeGroup $group): array => array_filter(
            $group->attrs,
            static fn(Attribute $attribute): bool => $attributeClass === Type::getFQCLNFromString(
                // toCodeString() keeps the leading backslash toString() strips, so fully-qualified attributes resolve.
                $attribute->name->toCodeString(),
                $aliases,
            ),
        );
        $matchingAttributes = array_merge(...array_values(array_map(
            $attributesInGroupMatchingRequestedAttributeName,
            $method->getAttrGroups(),
        )));

        if ($matchingAttributes === []) {
            return null;
        }

        return array_merge(...array_values(array_map(
            $onlyStringLiteralExpressions,
            $matchingAttributes,
        )));
    }

    /**
     * $aliases resolve the attribute names and the arguments of #[DataProviderExternal]. The "Class::method"
     * references of docblock tags are resolved with $reference_aliases (of the analysed file).
     *
     * @return list<array{line: int, class: string|null, method: string, external: bool}>
     *     class is null for a provider of the test's own class
     */
    private static function getDataProviders(
        ClassMethod $method,
        Aliases $aliases,
        Aliases $reference_aliases,
        ClassLikeStorage $class
    ): array {
        return [
            ...self::getAttributeDataProviders($method, $aliases, $class),
            ...array_map(
                static fn(array $entry): array => self::parseProviderReference(
                    $entry[0],
                    $entry[1],
                    $reference_aliases,
                ),
                self::docblockSpecials($method, $aliases)['dataProvider'] ?? [],
            ),
        ];
    }

    /** @return list<array{line: int, class: string|null, method: string, external: bool}> */
    private static function getAttributeDataProviders(
        ClassMethod $method,
        Aliases $aliases,
        ClassLikeStorage $class
    ): array {
        $references = self::attributeValue($method, $aliases, DataProvider::class);
        // PHPUnit takes a #[DataProvider] argument literally as a method name of the test class
        $providers = array_map(
            static fn(array $entry): array => [
                'line'     => $entry[0],
                'class'    => null,
                'method'   => $entry[1],
                'external' => false,
            ],
            $references ?? [],
        );

        foreach ($method->getAttrGroups() as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                if ($attribute_class !== DataProviderExternal::class) {
                    continue;
                }

                $args           = self::attributeArguments($attribute);

                $class_name  = self::classFromExpression($args['className'] ?? $args[0] ?? null, $aliases, $class);
                $method_name = $args['methodName'] ?? $args[1] ?? null;
                if ($class_name === null || !$method_name instanceof String_) {
                    continue;
                }

                $providers[] = [
                    'line'     => $attribute->getStartLine(),
                    'class'    => $class_name,
                    'method'   => $method_name->value,
                    'external' => true,
                ];
            }
        }

        return $providers;
    }

    /**
     * The closure of each #[DataProviderClosure] whose argument is a literal closure, by the start offset that
     * DataProviderClosureHandler keys its return type by.
     *
     * @return list<array{line: int, position: int, statements: array<array-key, Node\Stmt>}>
     */
    private static function getClosureProviders(ClassMethod $method, Aliases $aliases): array
    {
        $closures = [];
        foreach ($method->getAttrGroups() as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                if ($attribute_class !== self::DATA_PROVIDER_CLOSURE) {
                    continue;
                }

                $args    = self::attributeArguments($attribute);
                $closure = $args['closure'] ?? $args[0] ?? null;
                if ($closure instanceof Expr\Closure || $closure instanceof Expr\ArrowFunction) {
                    $closures[] = [
                        'line'       => $attribute->getStartLine(),
                        'position'   => $closure->getStartFilePos(),
                        'statements' => $closure instanceof Expr\Closure
                            ? $closure->stmts
                            : [new Return_($closure->expr)],
                    ];
                }
            }
        }

        return $closures;
    }

    /**
     * "Class::method" or "method" (optionally with trailing parentheses), as written in a dataProvider
     * docblock tag.
     *
     * @psalm-mutation-free
     *
     * @return array{line: int, class: string|null, method: string, external: bool}
     */
    private static function parseProviderReference(int $line, string $reference, Aliases $aliases): array
    {
        $parts  = explode('::', $reference, 2);
        $method = preg_replace('/\(\s*\)$/', '', $parts[1] ?? $parts[0]);
        assert($method !== null);

        return [
            'line'     => $line,
            'class'    => isset($parts[1]) ? Type::getFQCLNFromString($parts[0], $aliases) : null,
            'method'   => $method,
            'external' => false,
        ];
    }

    /**
     * PHPUnit appends the return value of every distinct depended-upon test that is not declared void or never
     * to the data provider values. Depending on a whole class passes no value.
     */
    private static function countDependencyValues(
        Codebase $codebase,
        ClassMethod $method,
        Aliases $aliases,
        ClassLikeStorage $class
    ): int {
        $count = 0;
        $seen  = [];
        foreach (self::getDependencyTargets($method, $aliases, $class) as $target) {
            if ($target !== null) {
                if (isset($seen[strtolower($target)])) {
                    continue;
                }
                $seen[strtolower($target)] = true;

                if (self::dependencyReturnsValue($codebase, $target) === false) {
                    continue;
                }
            }
            $count++;
        }

        return $count;
    }

    /**
     * Up to PHPUnit 12.5.39 and 13.4.2 (and on 11.5) only the first dependency counts: collecting stops at the first
     * void dependency and at the first one larger than this test. A test of the same class shares its class-level
     * size, so only size groups in the two method docblocks (PHPUnit 11) can make it larger. Newer releases skip
     * both and pass the value of any later dependency.
     */
    private static function appendsDependencyValue(
        Codebase $codebase,
        ClassLike $class_node,
        ClassLikeStorage $class,
        ClassMethod $method,
        Aliases $aliases
    ): bool {
        $targets = self::getDependencyTargets($method, $aliases, $class);

        if (!PhpUnitVersion::stopsCollectingDependencyValuesEarly()) {
            foreach ($targets as $target) {
                if ($target !== null && self::dependencyReturnsValue($codebase, $target) === true) {
                    return true;
                }
            }

            return false;
        }

        $first = $targets[0] ?? null;
        if ($first === null || self::dependencyReturnsValue($codebase, $first) !== true) {
            return false;
        }

        [$target_class, $target_method] = explode('::', $first);
        $target_node = strtolower($target_class) === strtolower($class->name)
            ? $class_node->getMethod($target_method)
            : null;
        if ($target_node === null) {
            return false;
        }

        $size_group = '/@(?:(?:group|ticket)\s+)?(?:small|medium|large)\b/';
        foreach ([$method->getDocComment(), $target_node->getDocComment()] as $docblock) {
            if ($docblock !== null && preg_match($size_group, $docblock->getText()) === 1) {
                return false;
            }
        }

        return true;
    }

    /**
     * @return bool|null null when the target method cannot be resolved
     */
    private static function dependencyReturnsValue(Codebase $codebase, string $target): ?bool
    {
        $target_class = explode('::', $target)[0];
        $target_id    = $codebase->classOrInterfaceExists($target_class)
            ? $codebase->getDeclaringMethodId($target)
            : null;
        if ($target_id === null) {
            return null;
        }

        $return_type = $codebase->methods->getStorage(MethodIdentifier::wrap($target_id))->signature_return_type;

        return $return_type === null || !($return_type->isVoid() || $return_type->isNever());
    }

    /**
     * getAttributeDataProviders() leaves out the attributes it cannot read, such as #[DataProvider(self::NAME)] and
     * #[DataProviderClosure], which is named by string as not every supported PHPUnit version has it.
     */
    private static function countProviderAttributes(ClassMethod $method, Aliases $aliases): int
    {
        $provider_attributes = [
            DataProvider::class,
            DataProviderExternal::class,
            self::DATA_PROVIDER_CLOSURE,
        ];
        $count = 0;
        foreach ($method->getAttrGroups() as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                if (in_array($attribute_class, $provider_attributes, true)) {
                    $count++;
                }
            }
        }

        return $count;
    }

    /**
     * PHPUnit's ParserChain ignores docblock annotations on a class or method that has any PHPUnit attribute.
     *
     * @internal
     */
    public static function hasPhpUnitAttribute(ClassLike|ClassMethod $node, Aliases $aliases): bool
    {
        foreach ($node->attrGroups as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                if (str_starts_with($attribute_class, 'PHPUnit\\Framework\\Attributes\\')) {
                    return true;
                }
            }
        }

        return false;
    }

    /**
     * @return list<string|null> "Class::method" per method dependency, null when the target is not a literal
     */
    private static function getDependencyTargets(ClassMethod $method, Aliases $aliases, ClassLikeStorage $class): array
    {
        $targets = [];
        foreach ($method->getAttrGroups() as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                if (!isset(self::DEPENDS_ATTRIBUTES[$attribute_class])) {
                    continue;
                }

                $args = self::attributeArguments($attribute);

                $is_external  = self::DEPENDS_ATTRIBUTES[$attribute_class];
                $target_name  = $args['methodName'] ?? $args[$is_external ? 1 : 0] ?? null;
                $target_class = $is_external
                    ? self::classFromExpression($args['className'] ?? $args[0] ?? null, $aliases, $class)
                    : $class->name;
                if ($target_name instanceof String_ && $target_name->value === 'class') {
                    continue; // PHPUnit treats this as a class dependency, which passes no value
                }

                $targets[]    = $target_class !== null && $target_name instanceof String_
                    ? $target_class . '::' . $target_name->value
                    : null;
            }
        }

        foreach (self::docblockSpecials($method, $aliases)['depends'] ?? [] as [, $value]) {
            $is_target = preg_match('/^(?:!?(?:clone|shallowClone)\s+)?(\S+)/', $value, $matches) === 1;
            if (!$is_target || str_ends_with(strtolower($matches[1]), '::class')) {
                continue;
            }

            $target    = $matches[1];
            $targets[] = str_contains($target, '::') ? ltrim($target, '\\') : $class->name . '::' . $target;
        }

        return $targets;
    }

    /**
     * @return array<array-key, Expr> named arguments by name, the others by position
     * @psalm-mutation-free
     * @internal
     */
    public static function attributeArguments(Attribute $attribute): array
    {
        $args = [];
        foreach ($attribute->args as $position => $arg) {
            $args[$arg->name?->toString() ?? $position] = $arg->value;
        }

        return $args;
    }

    /** @internal */
    public static function classFromExpression(
        Expr|null $expression,
        Aliases $aliases,
        ClassLikeStorage $class
    ): string|null {
        if ($expression instanceof String_) {
            return ltrim($expression->value, '\\');
        }

        $is_class_fetch = $expression instanceof ClassConstFetch
            && $expression->class instanceof Name
            && $expression->name instanceof Identifier
            && $expression->name->toLowerString() === 'class';
        if (!$is_class_fetch) {
            return null;
        }

        if ($expression->class->isSpecialClassName()) {
            return $expression->class->toLowerString() === 'parent' ? $class->parent_class : $class->name;
        }

        return Type::getFQCLNFromString($expression->class->toCodeString(), $aliases);
    }
    /** @return array<string, list<array{int, string}>> */
    private static function getAttributeSpecials(ClassMethod $method, Aliases $aliases): array
    {
        return array_filter([
            'before'       => self::attributeValue($method, $aliases, Before::class),
            'test'         => self::attributeValue($method, $aliases, Test::class),
        ], static fn(array|null $special): bool => $special !== null);
    }

    /** @param array<array-key, string> $suppressed_issues */
    private static function reportMalformedTags(
        ClassLike|ClassMethod $node,
        CodeLocation $location,
        array $suppressed_issues,
    ): void {
        // Nothing is read from a docblock on PHPUnit 12, malformed or not
        if (PhpUnitVersion::ignoresDocblockMetadata()) {
            return;
        }

        foreach (DocblockSpecials::malformed($node) as ['tag' => $tag, 'line' => $line, 'problem' => $problem]) {
            IssueBuffer::accepts(new InvalidPhpUnitAnnotation(
                'Annotation "@' . $tag . '" ' . $problem,
                $location->setCommentLine($line),
            ), $suppressed_issues);
        }
    }
}
