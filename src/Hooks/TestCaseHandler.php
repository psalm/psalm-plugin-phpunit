<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Comment\Doc;
use PhpParser\Node\Attribute;
use PhpParser\Node\AttributeGroup;
use PhpParser\Node\Expr;
use PhpParser\Node\Expr\ClassConstFetch;
use PhpParser\Node\Expr\MethodCall;
use PhpParser\Node\Expr\Variable;
use PhpParser\Node\Identifier;
use PhpParser\Node\Name;
use PhpParser\Node\Scalar\String_;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use PHPUnit\Framework\Attributes\Before;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\Attributes\Depends;
use PHPUnit\Framework\Attributes\DependsExternal;
use PHPUnit\Framework\Attributes\DependsExternalUsingDeepClone;
use PHPUnit\Framework\Attributes\DependsExternalUsingShallowClone;
use PHPUnit\Framework\Attributes\DependsUsingDeepClone;
use PHPUnit\Framework\Attributes\DependsUsingShallowClone;
use PHPUnit\Framework\Attributes\Test;
use Psalm\Aliases;
use Psalm\Codebase;
use Psalm\DocComment;
use Psalm\Exception\DocblockParseException;
use Psalm\Internal\Analyzer\ClassLikeAnalyzer;
use Psalm\Internal\MethodIdentifier;
use Psalm\IssueBuffer;
use Psalm\Issue;
use Psalm\PhpUnitPlugin\Issue\InvalidDataProvider;
use Psalm\Plugin\EventHandler\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\AfterClassLikeVisitInterface;
use Psalm\Plugin\EventHandler\AfterCodebasePopulatedInterface;
use Psalm\Plugin\EventHandler\AfterMethodCallAnalysisInterface;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeAnalysisEvent;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeVisitEvent;
use Psalm\Plugin\EventHandler\Event\AfterCodebasePopulatedEvent;
use Psalm\Plugin\EventHandler\Event\AfterMethodCallAnalysisEvent;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Type;
use Psalm\Type\Atomic\TNull;
use Psalm\Type\Union;
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
use function ltrim;
use function max;
use function preg_match;
use function str_contains;
use function str_ends_with;
use function str_starts_with;
use function strtolower;
use function substr_count;
use function trim;

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

    private const EXPECT_EXCEPTION_METHODS = [
        'phpunit\\framework\\testcase::expectexception' => true,
        'phpunit\\framework\\testcase::expectexceptioncode' => true,
        'phpunit\\framework\\testcase::expectexceptionmessage' => true,
        'phpunit\\framework\\testcase::expectexceptionmessagematches' => true,
        'phpunit\\framework\\testcase::expectexceptionobject' => true,
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
            $specials = self::getSpecials($method, $aliases);
            if (!isset($specials['dataProvider'])) {
                continue;
            }
            foreach ($specials['dataProvider'] as [, $provider]) {
                if (false !== strpos($provider, '::')) {
                    [$class_name] = explode('::', $provider);
                    $fq_class_name = Type::getFQCLNFromString($class_name, $statements_source->getAliases());
                    $codebase->queueClassLikeForScanning($fq_class_name);
                    $file_storage->referenced_classlikes[strtolower($fq_class_name)] = $fq_class_name;
                }
            }
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

            $stmt_method = $declaring_class_node->getMethod($declaring_method_name);

            if (!$stmt_method) {
                continue;
            }

            // Use the declaring class's aliases so trait-declared attributes resolve via the trait's imports.
            $method_aliases = $declaring_class_storage->aliases ?? $aliases;
            $specials = self::getSpecials($stmt_method, $method_aliases);
            // PHPUnit ignores docblock annotations on a method that has any PHPUnit attribute
            $docblock_providers_ignored = self::hasPhpUnitAttribute($stmt_method, $method_aliases)
                && !isset(self::getAttributeSpecials($stmt_method, $method_aliases)['dataProvider']);

            $is_test = 0 === strpos($method_name_lc, 'test') || isset($specials['test']);
            if (!$is_test) {
                continue; // skip non-test methods
            }

            $codebase->methodExists(
                (string) $declaring_method_id,
                'PHPUnit\Framework\TestSuite::run'
            );

            if (!isset($specials['dataProvider'])) {
                continue;
            }

            $dependency_values = self::countDependencyValues(
                $codebase,
                $stmt_method,
                $method_aliases,
                $class_storage,
            );
            foreach ($specials['dataProvider'] as [$line, $provider]) {
                $provider_docblock_location = $method_storage->location->setCommentLine($line);

                if (false !== strpos($provider, '::')) {
                    [$class_name, $method_id] = explode('::', $provider);
                    $fq_class_name = Type::getFQCLNFromString($class_name, $statements_source->getAliases());

                    if (!$codebase->classOrInterfaceExists($fq_class_name, $provider_docblock_location)) {
                        IssueBuffer::accepts(new Issue\UndefinedClass(
                            'Class ' . $fq_class_name . ' does not exist',
                            $provider_docblock_location,
                            $fq_class_name
                        ));
                        continue;
                    }
                    $apparent_provider_method_name = $fq_class_name . '::' . $method_id;
                } else {
                    $apparent_provider_method_name = $class_storage->name . '::' . $provider;
                }

                $apparent_provider_method_name = preg_replace('/\(\s*\)$/', '', $apparent_provider_method_name);
                assert($apparent_provider_method_name !== null);

                $provider_method_id = $codebase->getDeclaringMethodId($apparent_provider_method_name);

                if (null === $provider_method_id) {
                    IssueBuffer::accepts(new Issue\UndefinedMethod(
                        'Provider method ' . $apparent_provider_method_name . ' is not defined',
                        $provider_docblock_location,
                        $apparent_provider_method_name
                    ));
                    continue;
                }

                // methodExists also can mark methods as used (weird, but handy)
                $provider_method_exists = $codebase->methodExists(
                    $provider_method_id,
                    (string) $declaring_method_id,
                    $provider_docblock_location,
                );

                if (!$provider_method_exists) {
                    IssueBuffer::accepts(new Issue\UndefinedMethod(
                        'Provider method ' . $apparent_provider_method_name . ' is not defined',
                        $provider_docblock_location,
                        $apparent_provider_method_name
                    ));
                    continue;
                }

                $provider_method_storage = $codebase->methods->getStorage(MethodIdentifier::wrap($provider_method_id));

                // Abstract providers are checked on the concrete classes implementing them
                if (!$provider_method_storage->abstract && !$docblock_providers_ignored) {
                    $provider_visibility = $provider_method_storage->visibility;
                    $appearing_provider_id = $codebase->methods->getAppearingMethodId(
                        MethodIdentifier::wrap($apparent_provider_method_name)
                    );
                    if (null !== $appearing_provider_id) {
                        $provider_visibility = $codebase->classlike_storage_provider
                            ->get($appearing_provider_id->fq_class_name)
                            ->trait_visibility_map[$appearing_provider_id->method_name]
                            ?? $provider_visibility;
                    }
                    $suppressed_issues = $method_storage->suppressed_issues
                        + $declaring_class_storage->suppressed_issues
                        + $class_storage->suppressed_issues
                        + $statements_source->getSuppressedIssues();

                    if (ClassLikeAnalyzer::VISIBILITY_PUBLIC !== $provider_visibility) {
                        IssueBuffer::accepts(new InvalidDataProvider(
                            'Data provider method ' . $apparent_provider_method_name . ' must be public',
                            $provider_docblock_location
                        ), $suppressed_issues);
                    }

                    if (!$provider_method_storage->is_static) {
                        IssueBuffer::accepts(new InvalidDataProvider(
                            'Data provider method ' . $apparent_provider_method_name . ' must be static',
                            $provider_docblock_location
                        ), $suppressed_issues);
                    }
                }

                $provider_return_type = $codebase->getMethodReturnType($provider_method_id, $_);

                if (!$provider_return_type) {
                    continue;
                }

                $provider_return_type_string = $provider_return_type->getId();

                $provider_return_type_location = $codebase->getMethodReturnTypeLocation($provider_method_id);
                assert(null !== $provider_return_type_location);

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
                        ));
                        continue 2;
                    }
                    $non_null_provider_return_types[] = $type;
                }

                if ([] === $non_null_provider_return_types) {
                    IssueBuffer::accepts(new Issue\InvalidReturnType(
                        'Providers must return ' . $expected_provider_return_type->getId()
                        . ', ' . $provider_return_type_string . ' provided',
                        $provider_return_type_location
                    ));
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
                        ));
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ));
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
                        ));
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ));
                    }
                    continue;
                }

                $checkParam =
                static function (
                    Type\Union $potential_argument_type,
                    Type\Union $param_type,
                    bool $is_optional,
                    int $param_offset
                ) use (
                    $codebase,
                    $method_name,
                    $provider_method_id,
                    $provider_return_type_string,
                    $provider_docblock_location
                ): void {
                    if ($is_optional) {
                        /** @psalm-suppress RedundantCondition */
                        if (method_exists($param_type, 'setPossiblyUndefined')) {
                            /** @var Union */
                            $param_type = $param_type->setPossiblyUndefined(true);
                        } else {
                            // for older Psalm versions
                            /**
                             * @psalm-suppress InvalidClone
                             * @var Union
                             */
                            $param_type = clone $param_type;
                            /** @psalm-suppress InaccessibleProperty */
                            $param_type->possibly_undefined = true;
                        }
                    }
                    if ($codebase->isTypeContainedByType($potential_argument_type, $param_type)) {
                        // ok
                    } elseif ($codebase->canTypeBeContainedByType($potential_argument_type, $param_type)) {
                        IssueBuffer::accepts(new Issue\PossiblyInvalidArgument(
                            'Argument ' . ($param_offset + 1) . ' of ' . $method_name
                            . ' expects ' . $param_type->getId() . ', '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_method_id . '():(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ));
                    } elseif ($potential_argument_type->possibly_undefined && !$is_optional) {
                        IssueBuffer::accepts(new Issue\InvalidArgument(
                            'Argument ' . ($param_offset + 1) . ' of ' . $method_name
                            . ' is not optional, but possibly undefined '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_method_id . '():(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ));
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidArgument(
                            'Argument ' . ($param_offset + 1) . ' of ' . $method_name
                            . ' expects ' . $param_type->getId() . ', '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_method_id . '():(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ));
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
                                . ' provided by ' . $provider_method_id . '()'
                                .  ':(' . $provider_return_type_string . ')',
                                $provider_docblock_location,
                                $method_name
                            ));
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
     * @return non-empty-array<string,Type\Atomic>
     *
     * @psalm-pure
     */
    private static function getAtomics(Type\Union $union): array
    {
        return $union->getAtomicTypes();
    }

    private static function unionizeIterables(Codebase $codebase, Type\Union $iterables): Type\Atomic\TIterable
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

    /** @return array<string, list<array{int, string}>> Each entry is [file line, value] */
    private static function getSpecials(ClassMethod $method, Aliases $aliases): array
    {
        return array_merge(
            self::getDocblockSpecials($method),
            // Attributes take priority over docblocks
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

                $target_class = explode('::', $target)[0];
                $target_id    = $codebase->classOrInterfaceExists($target_class)
                    ? $codebase->getDeclaringMethodId($target)
                    : null;
                $return_type  = $target_id === null
                    ? null
                    : $codebase->methods->getStorage(MethodIdentifier::wrap($target_id))->signature_return_type;
                if ($return_type !== null && ($return_type->isVoid() || $return_type->isNever())) {
                    continue;
                }
            }
            $count++;
        }

        return $count;
    }

    /**
     * PHPUnit's ParserChain ignores docblock annotations on a method that has any PHPUnit attribute.
     */
    private static function hasPhpUnitAttribute(ClassMethod $method, Aliases $aliases): bool
    {
        foreach ($method->getAttrGroups() as $group) {
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
     * Mirrors PHPUnit's ParserChain: docblock annotations are only read when the method has no PHPUnit attribute.
     *
     * @return list<string|null> "Class::method" per method dependency, null when the target is not a literal
     */
    private static function getDependencyTargets(ClassMethod $method, Aliases $aliases, ClassLikeStorage $class): array
    {
        $has_phpunit_attribute = self::hasPhpUnitAttribute($method, $aliases);
        $targets               = [];
        foreach ($method->getAttrGroups() as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                if (!isset(self::DEPENDS_ATTRIBUTES[$attribute_class])) {
                    continue;
                }

                $args = [];
                foreach ($attribute->args as $position => $arg) {
                    $args[$arg->name?->toString() ?? $position] = $arg->value;
                }

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

        if ($has_phpunit_attribute) {
            return $targets;
        }

        foreach (self::getDocblockSpecials($method)['depends'] ?? [] as [, $value]) {
            $is_target = preg_match('/^(?:!?(?:clone|shallowClone)\s+)?(\S+)/', $value, $matches) === 1;
            if (!$is_target || str_ends_with(strtolower($matches[1]), '::class')) {
                continue;
            }

            $target    = $matches[1];
            $targets[] = str_contains($target, '::') ? ltrim($target, '\\') : $class->name . '::' . $target;
        }

        return $targets;
    }

    private static function classFromExpression(
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
            'dataProvider' => self::attributeValue($method, $aliases, DataProvider::class),
        ], static fn(array|null $special): bool => $special !== null);
    }

    /** @return array<string, list<array{int, string}>> */
    private static function getDocblockSpecials(ClassMethod $method): array
    {
        $docblock = $method->getDocComment();
        if (!$docblock) {
            return [];
        }

        try {
            $parsed_comment = self::getParsedComment($docblock);
        } catch (DocblockParseException $e) {
            return [];
        }

        if (!isset($parsed_comment['specials'])) {
            return [];
        }

        // Psalm keys tags by absolute file offset, which is useless for issue locations.
        $start_pos = $docblock->getStartFilePos();
        $to_line   = static fn(int $offset): int => $docblock->getStartLine()
            + substr_count($docblock->getText(), "\n", 0, $offset - $start_pos);

        return array_map(
            static function (array $tags) use ($to_line): array {
                $entries = [];
                foreach ($tags as $offset => $data) {
                    $entries[] = [$to_line($offset), trim($data)];
                }

                return $entries;
            },
            $parsed_comment['specials']
        );
    }

    /** @return array{description:string, specials:array<string,array<int,string>>} */
    private static function getParsedComment(Doc $comment): array
    {
        $parsed_docblock = DocComment::parsePreservingLength($comment);

        $description = $parsed_docblock->description;
        $specials = $parsed_docblock->tags;

        return [
            'description' => $description,
            'specials' => $specials,
        ];
    }
}
