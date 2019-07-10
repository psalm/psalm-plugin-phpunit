<?php declare(strict_types=1);
namespace Psalm\PhpUnitPlugin\Hooks;

use PHPUnit\Framework\TestCase;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use Psalm\CodeLocation;
use Psalm\Codebase;
use Psalm\DocComment;
use Psalm\Exception\DocblockParseException;
use Psalm\FileSource;
use Psalm\IssueBuffer;
use Psalm\Issue;
use Psalm\Plugin\Hook\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\Hook\AfterClassLikeVisitInterface;
use Psalm\Plugin\Hook\AfterCodebasePopulatedInterface;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Type;

class TestCaseHandler implements
    AfterClassLikeVisitInterface,
    AfterClassLikeAnalysisInterface,
    AfterCodebasePopulatedInterface
{
    /**
     * {@inheritDoc}
     */
    public static function afterCodebasePopulated(Codebase $codebase)
    {
        foreach ($codebase->classlike_storage_provider->getAll() as $name => $storage) {
            $meta = (array) ($storage->custom_metadata[__NAMESPACE__] ?? []);
            if ($codebase->classExtends($name, TestCase::class) && ($meta['hasInitializers'] ?? false)) {
                $storage->suppressed_issues[] = 'MissingConstructor';

                foreach (self::getDescendants($codebase, $name) as $dependent_name) {
                    $dependent_storage = $codebase->classlike_storage_provider->get($dependent_name);
                    $dependent_storage->suppressed_issues[] = 'MissingConstructor';
                }
            }
        }
    }

    /** @return string[] */
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

    /**
     * {@inheritDoc}
     */
    public static function afterClassLikeVisit(
        ClassLike $class_node,
        ClassLikeStorage $class_storage,
        FileSource $statements_source,
        Codebase $codebase,
        array &$file_replacements = []
    ) {
        if (self::hasInitializers($class_storage, $class_node)) {
            $class_storage->custom_metadata[__NAMESPACE__] = ['hasInitializers' => true];
        }
    }

    /**
     * {@inheritDoc}
     */
    public static function afterStatementAnalysis(
        ClassLike $class_node,
        ClassLikeStorage $class_storage,
        StatementsSource $statements_source,
        Codebase $codebase,
        array &$file_replacements = []
    ) {
        if (!$codebase->classExtends($class_storage->name, TestCase::class)) {
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
            $method_name = $codebase->getCasedMethodId($class_storage->name . '::' . $method_name_lc);
            $method_storage = $codebase->methods->getStorage($declaring_method_id);
            list($declaring_method_class, $declaring_method_name) = explode('::', $declaring_method_id);
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

            $specials = self::getSpecials($stmt_method);

            if (0 !== strpos($method_name_lc, 'test')
                && !isset($specials['test'])) {
                continue; // skip non-test methods
            }

            $codebase->methodExists(
                $declaring_method_id,
                null,
                'PHPUnit\Framework\TestSuite::run'
            );

            if (!isset($specials['dataProvider'])) {
                continue;
            }

            foreach ($specials['dataProvider'] as $line => $provider) {
                $provider_docblock_location = clone $method_storage->location;
                $provider_docblock_location->setCommentLine($line);

                $apparent_provider_method_name = $class_storage->name . '::' . (string) $provider;
                $provider_method_id = $codebase->getDeclaringMethodId($apparent_provider_method_name);

                // methodExists also can mark methods as used (weird, but handy)
                if (null === $provider_method_id
                    || !$codebase->methodExists($provider_method_id, $provider_docblock_location, $declaring_method_id)
                ) {
                    IssueBuffer::accepts(new Issue\UndefinedMethod(
                        'Provider method ' . $apparent_provider_method_name . ' is not defined',
                        $provider_docblock_location,
                        $apparent_provider_method_name
                    ));
                    continue;
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

                foreach ($provider_return_type->getTypes() as $type) {
                    if (!$type->isIterable($codebase)) {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
                            'Providers must return ' . $expected_provider_return_type->getId()
                            . ', ' . $provider_return_type_string . ' provided',
                            $provider_return_type_location
                        ));
                        continue;
                    }
                }

                // unionize iterable so that instead of array<int,string>|Traversable<object|int>
                // we get iterable<int|object,string|int>
                //
                // TODO: this may get implemented in a future Psalm version, remove it then
                $provider_return_type = self::unionizeIterables($codebase, $provider_return_type);

                if (!$codebase->isTypeContainedByType(
                    $provider_return_type->type_params[0],
                    $expected_provider_return_type->type_params[0]
                )) {
                    if ($provider_return_type->type_params[0]->hasMixed()
                        || $provider_return_type->type_params[0]->hasArrayKey()
                    ) {
                        IssueBuffer::accepts(new Issue\MixedInferredReturnType(
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

                if (!$codebase->isTypeContainedByType(
                    $provider_return_type->type_params[1],
                    $expected_provider_return_type->type_params[1]
                )) {
                    if ($provider_return_type->type_params[1]->hasMixed()) {
                        IssueBuffer::accepts(new Issue\MixedInferredReturnType(
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
                function (
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
                ) : void {
                    $param_type = clone $param_type;
                    if ($is_optional) {
                        $param_type->possibly_undefined = true;
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
                            . ' has no default value, but possibly undefined '
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

                /** @var Type\Atomic\TArray|Type\Atomic\ObjectLike $dataset_type */
                $dataset_type = $provider_return_type->type_params[1]->getTypes()['array'];

                if ($dataset_type instanceof Type\Atomic\TArray) {
                    // check that all of the required (?) params accept value type
                    $potential_argument_type = $dataset_type->type_params[1];
                    foreach ($method_storage->params as $param_offset => $param) {
                        if (!$param->type) {
                            continue;
                        }
                        $checkParam($potential_argument_type, $param->type, $param->is_optional, $param_offset);
                    }
                } else {
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

                            IssueBuffer::accepts(new Issue\TooFewArguments(
                                'Too few arguments for ' . $method_name
                                . ' - expecting at least ' . ($param_offset + 1)
                                . ', but saw ' . count($potential_argument_types)
                                . ' provided by ' . $provider_method_id . '()'
                                .  ':(' . $provider_return_type_string . ')',
                                $provider_docblock_location,
                                $method_name
                            ));
                            break;
                        }
                        $potential_argument_type = $potential_argument_types[$param_offset];

                        assert(null !== $param->type);
                        if ($param->is_variadic) {
                            $param_types = $param->type->getTypes();
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

                        $checkParam($potential_argument_type, $param->type, $param->is_optional, $param_offset);
                    }
                }
            }
        }
    }

    private static function unionizeIterables(Codebase $codebase, Type\Union $iterables): Type\Atomic\TIterable
    {
        /** @var Type\Union[] $key_types */
        $key_types = [];

        /** @var Type\Union[] $value_types */
        $value_types = [];

        foreach ($iterables->getTypes() as $type) {
            if (!$type->isIterable($codebase)) {
                throw new \RuntimeException('should be iterable');
            }

            if ($type instanceof Type\Atomic\TArray) {
                $key_types[] = $type->type_params[0] ?? Type::getMixed();
                $value_types[] = $type->type_params[1] ?? Type::getMixed();
            } elseif ($type instanceof Type\Atomic\ObjectLike) {
                $key_types[] = $type->getGenericKeyType();
                $value_types[] = $type->getGenericValueType();
            } elseif ($type instanceof Type\Atomic\TNamedObject || $type instanceof Type\Atomic\TIterable) {
                list($key_types[], $value_types[]) = $codebase->getKeyValueParamsForTraversableObject($type);
            } else {
                throw new \RuntimeException('unexpected type');
            }
        }

        if (empty($key_types) || empty($value_types)) {
            return new Type\Atomic\TIterable([
                Type::getMixed(),
                Type::getMixed(),
            ]);
        }

        $combine =
            /** @param null|Type\Union $a */
            function ($a, Type\Union $b) use ($codebase): Type\Union {
                return $a ? Type::combineUnionTypes($a, $b, $codebase) : $b;
            };

        return new Type\Atomic\TIterable([
            array_reduce($key_types, $combine),
            array_reduce($value_types, $combine),
        ]);
    }


    private static function hasInitializers(ClassLikeStorage $storage, ClassLike $stmt): bool
    {
        if (isset($storage->methods['setup'])) {
            return true;
        }

        foreach ($storage->methods as $method => $_) {
            $stmt_method = $stmt->getMethod($method);
            if (!$stmt_method) {
                continue;
            }
            if (self::isBeforeInitializer($stmt_method)) {
                return true;
            }
        }
        return false;
    }

    private static function isBeforeInitializer(ClassMethod $method): bool
    {
        $specials = self::getSpecials($method);
        return isset($specials['before']);
    }

    /** @return array<string, array<int,string>> */
    private static function getSpecials(ClassMethod $method): array
    {
        $docblock = $method->getDocComment();

        if ($docblock) {
            try {
                $parsed_comment = DocComment::parse((string)$docblock->getReformattedText(), $docblock->getLine());
            } catch (DocblockParseException $e) {
                return [];
            }
            if (isset($parsed_comment['specials'])) {
                return $parsed_comment['specials'];
            }
        }
        return [];
    }
}
