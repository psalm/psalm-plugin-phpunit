<?php declare(strict_types=1);
namespace Psalm\PhpUnitPlugin\Hooks;

use PHPUnit\Framework\TestCase;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use Psalm\Codebase;
use Psalm\DocComment;
use Psalm\FileSource;
use Psalm\IssueBuffer;
use Psalm\Issue;
use Psalm\PhpUnitPlugin\Exception\UnsupportedPsalmVersion;
use Psalm\Plugin\Hook\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\Hook\AfterClassLikeVisitInterface;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Storage\FunctionLikeParameter;
use Psalm\Storage\MethodStorage;
use Psalm\Type;
use Psalm\Type\Atomic\TIterable;

class TestCaseHandler implements AfterClassLikeVisitInterface, AfterClassLikeAnalysisInterface
{
    /**
     * {@inheritDoc}
     */
    public static function afterClassLikeVisit(
        ClassLike $classNode,
        ClassLikeStorage $classStorage,
        FileSource $statements_source,
        Codebase $codebase,
        array &$file_replacements = []
    ) {
        if (!$codebase->classExtends($classStorage->name, TestCase::class)) {
            return;
        }

        if (self::hasInitializers($classStorage, $classNode)) {
            $classStorage->suppressed_issues[] = 'MissingConstructor';
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

        // add a fake reference to test class to prevent it from being marked as unused
        // it would have been easier to add a suppression, but that's only possible
        // since 3.0.17 (vimeo/psalm#1353)
        //
        // This should always pass, we're calling it for the side-effect
        // of adding self-reference

        if (!$codebase->classOrInterfaceExists($class_storage->name, $class_storage->location)) {
            return null;
        }

        foreach ($class_storage->methods as $method_name => $method_storage) {
            if (!$method_storage->location) {
                continue;
            }

            $stmt_method = $class_node->getMethod($method_name);

            if (!$stmt_method) {
                throw new \RuntimeException('Failed to find ' . $method_name);
            }

            $specials = self::getSpecials($stmt_method);

            $method_id = $class_storage->name . '::' . $method_storage->cased_name;

            if (0 !== strpos($method_storage->cased_name, 'test')
                && !isset($specials['test'])) {
                continue; // skip non-test methods
            }

            $method_storage->suppressed_issues[] = 'PossiblyUnusedMethod';

            if (!isset($specials['dataProvider'])) {
                continue;
            }

            foreach ($specials['dataProvider'] as $line => $provider) {
                $provider_method_id = $class_storage->name . '::' . (string) $provider;

                $provider_docblock_location = clone $method_storage->location;
                $provider_docblock_location->setCommentLine($line);

                // methodExists also can mark methods as used (weird, but handy)
                if (!$codebase->methodExists($provider_method_id, $provider_docblock_location, $method_id)) {
                    IssueBuffer::accepts(new Issue\UndefinedMethod(
                        'Provider method ' . $provider_method_id . ' is not defined',
                        $provider_docblock_location,
                        $provider_method_id
                    ));

                    continue;
                }

                $provider_return_type = $codebase->getMethodReturnType($provider_method_id, $classStorage->name);
                assert(null !== $provider_return_type);

                $provider_return_type_string = $provider_return_type->getId();

                $provider_return_type_location = $codebase->getMethodReturnTypeLocation($provider_method_id);
                assert(null !== $provider_return_type_location);

                $expected_provider_return_type = new Type\Atomic\TIterable([
                    Type::combineUnionTypes(Type::getInt(), Type::getString()),
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

                $provider_return_type = self::unionizeIterables($codebase, $provider_return_type);

                if (!self::isTypeContainedByType(
                    $codebase,
                    $provider_return_type->type_params[0],
                    $expected_provider_return_type->type_params[0]
                ) || !self::isTypeContainedByType(
                    $codebase,
                    $provider_return_type->type_params[1],
                    $expected_provider_return_type->type_params[1]
                )) {
                    if ($provider_return_type->type_params[0]->hasMixed()
                        || $provider_return_type->type_params[1]->hasMixed()) {
                        IssueBuffer::accepts(new Issue\InvalidReturnType(
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
                /** @return void */
                function (
                    Type\Union $potential_argument_type,
                    FunctionLikeParameter $param,
                    int $param_offset
                ) use (
                    $codebase,
                    $method_id,
                    $provider_method_id,
                    $provider_return_type_string,
                    $provider_docblock_location
                ) {
                    assert(null !== $param->type);
                    $param_type = clone $param->type;
                    if ($param->default_type) {
                        $param_type->possibly_undefined = true;
                    }
                    if (self::isTypeContainedByType($codebase, $potential_argument_type, $param_type)) {
                        // ok
                    } elseif (self::canTypeBeContainedByType($codebase, $potential_argument_type, $param_type)) {
                        IssueBuffer::accepts(new Issue\PossiblyInvalidArgument(
                            'Argument ' . ($param_offset + 1) . ' of ' . $method_id
                            . ' expects ' . $param_type->getId() . ', '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_method_id . '():(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ));
                    } elseif ($potential_argument_type->possibly_undefined && !$param->default_type) {
                        IssueBuffer::accepts(new Issue\InvalidArgument(
                            'Argument ' . ($param_offset + 1) . ' of ' . $method_id
                            . ' has no default value, but possibly undefined '
                            . $potential_argument_type->getId() . ' provided'
                            . ' by ' . $provider_method_id . '():(' . $provider_return_type_string . ')',
                            $provider_docblock_location
                        ));
                    } else {
                        IssueBuffer::accepts(new Issue\InvalidArgument(
                            'Argument ' . ($param_offset + 1) . ' of ' . $method_id
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
                        $checkParam($potential_argument_type, $param, $param_offset);
                    }
                } else {
                    // iterate over all params checking if corresponding value type is acceptable
                    // let's hope properties are sorted in array order
                    $potential_argument_types = array_values($dataset_type->properties);

                    if (count($potential_argument_types) < $method_storage->required_param_count) {
                        IssueBuffer::accepts(new Issue\TooFewArguments(
                            'Too few arguments for ' . $method_id
                            . ' - expecting ' . $method_storage->required_param_count
                            . ' but saw ' . count($potential_argument_types)
                            . ' provided by ' . $provider_method_id . '()'
                            .  ':(' . $provider_return_type_string . ')',
                            $provider_docblock_location,
                            $method_id
                        ));
                    }


                    foreach ($method_storage->params as $param_offset => $param) {
                        if (!isset($potential_argument_types[$param_offset])) {
                            break;
                        }
                        $potential_argument_type = $potential_argument_types[$param_offset];

                        $checkParam($potential_argument_type, $param, $param_offset);
                    }
                }
            }
        }
    }

    private static function isTypeContainedByType(
        Codebase $codebase,
        Type\Union $input_type,
        Type\Union $container_type
    ): bool {
        if (method_exists($codebase, 'isTypeContainedByType')) {
            return (bool) $codebase->isTypeContainedByType($input_type, $container_type);
        } elseif (class_exists(\Psalm\Internal\Analyzer\TypeAnalyzer::class, true)
            && method_exists(\Psalm\Internal\Analyzer\TypeAnalyzer::class, 'isContainedBy')) {
            return \Psalm\Internal\Analyzer\TypeAnalyzer::isContainedBy($codebase, $input_type, $container_type);
        } else {
            throw new UnsupportedPsalmVersion();
        }
    }

    private static function canTypeBeContainedByType(
        Codebase $codebase,
        Type\Union $input_type,
        Type\Union $container_type
    ): bool {
        if (method_exists($codebase, 'canTypeBeContainedByType')) {
            return (bool) $codebase->canTypeBeContainedByType($input_type, $container_type);
        } elseif (class_exists(\Psalm\Internal\Analyzer\TypeAnalyzer::class, true)
            && method_exists(\Psalm\Internal\Analyzer\TypeAnalyzer::class, 'canBeContainedBy')) {
            return \Psalm\Internal\Analyzer\TypeAnalyzer::canBeContainedBy($codebase, $input_type, $container_type);
        } else {
            throw new UnsupportedPsalmVersion();
        }
    }

    /**
     * @param Type\Atomic\TNamedObject|Type\Atomic\TIterable $type
     * @return array{0:Type\Union,1:Type\Union}
     */
    private static function getKeyValueParamsForTraversableObject(Codebase $codebase, $type): array
    {
        if (method_exists($codebase, 'getKeyValueParamsForTraversableObject')) {
            $ret = (array) $codebase->getKeyValueParamsForTraversableObject($type);
            assert($ret[0] instanceof Type\Union);
            assert($ret[1] instanceof Type\Union);
            return [$ret[0], $ret[1]];
        } elseif (class_exists(\Psalm\Internal\Analyzer\Statements\Block\ForeachAnalyzer::class, true)
            && method_exists(
                \Psalm\Internal\Analyzer\Statements\Block\ForeachAnalyzer::class,
                'getKeyValueParamsForTraversableObject'
            )
        ) {
            $iterable_key_type = null;
            $iterable_value_type = null;

            \Psalm\Internal\Analyzer\Statements\Block\ForeachAnalyzer::getKeyValueParamsForTraversableObject(
                $type,
                $codebase,
                $iterable_key_type,
                $iterable_value_type
            );

            return [
                $iterable_key_type ?? Type::getMixed(),
                $iterable_value_type ?? Type::getMixed(),
            ];
        } else {
            throw new UnsupportedPsalmVersion();
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
                list($key_types[], $value_types[]) = self::getKeyValueParamsForTraversableObject($codebase, $type);
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

        $combine = function (?Type\Union $a, Type\Union $b) use ($codebase): Type\Union {
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
                throw new \RuntimeException('Failed to find ' . $method);
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
            $parsed_comment = DocComment::parse((string)$docblock->getReformattedText(), $docblock->getLine());
            if (isset($parsed_comment['specials'])) {
                return $parsed_comment['specials'];
            }
        }
        return [];
    }
}
