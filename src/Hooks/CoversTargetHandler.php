<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Hooks;

use PhpParser\Node\Scalar\String_;
use PhpParser\Node\Stmt\ClassLike;
use PhpParser\Node\Stmt\ClassMethod;
use PHPUnit\Framework\Attributes\CoversFunction;
use PHPUnit\Framework\Attributes\CoversMethod;
use PHPUnit\Framework\Attributes\UsesFunction;
use PHPUnit\Framework\Attributes\UsesMethod;
use Psalm\Aliases;
use Psalm\Codebase;
use Psalm\CodeLocation;
use Psalm\Issue;
use Psalm\IssueBuffer;
use Psalm\PhpUnitPlugin\DocblockSpecials;
use Psalm\PhpUnitPlugin\PhpUnitVersion;
use Psalm\PhpUnitPlugin\Suppressions;
use Psalm\Plugin\EventHandler\AfterClassLikeAnalysisInterface;
use Psalm\Plugin\EventHandler\AfterClassLikeVisitInterface;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeAnalysisEvent;
use Psalm\Plugin\EventHandler\Event\AfterClassLikeVisitEvent;
use Psalm\StatementsSource;
use Psalm\Storage\ClassLikeStorage;
use Psalm\Type;

use function array_intersect_key;
use function explode;
use function ltrim;
use function preg_replace;
use function str_contains;
use function str_starts_with;
use function strpos;
use function strtolower;
use function substr;

/**
 * Reports #[CoversMethod], #[CoversFunction], #[UsesMethod], #[UsesFunction] and docblock @covers, @uses,
 * @coversDefaultClass and @usesDefaultClass targets that do not exist. Psalm already reports missing classes in
 * attribute arguments.
 */
final class CoversTargetHandler implements AfterClassLikeVisitInterface, AfterClassLikeAnalysisInterface
{
    /** @var array<class-string, string> */
    private const METHOD_ATTRIBUTES = [
        CoversMethod::class => 'CoversMethod',
        UsesMethod::class => 'UsesMethod',
    ];

    /** @var array<class-string, string> */
    private const FUNCTION_ATTRIBUTES = [
        CoversFunction::class => 'CoversFunction',
        UsesFunction::class => 'UsesFunction',
    ];

    /** @var array<string, true> */
    private const TARGET_TAGS = ['covers' => true, 'uses' => true];

    /** @var array<string, string> default class tag => the target tag it applies to */
    private const DEFAULT_CLASS_TAGS = ['coversDefaultClass' => 'covers', 'usesDefaultClass' => 'uses'];

    /**
     * Docblock targets are not part of the file's dependencies, so Psalm would not scan them in a single file run
     * and report them as missing. The tags are kept in the storage, because a test case also uses the ones of its
     * traits and parent classes.
     */
    #[\Override]
    public static function afterClassLikeVisit(AfterClassLikeVisitEvent $event)
    {
        if (PhpUnitVersion::ignoresDocblockMetadata()) {
            return;
        }

        $source = $event->getStatementsSource();
        $codebase = $event->getCodebase();
        $metadata = self::collectMetadata($event->getStmt(), $source->getAliases());
        if ($metadata['class'] === [] && $metadata['methods'] === []) {
            return;
        }

        $event->getStorage()->custom_metadata[self::class] = $metadata;
        $file_storage = $codebase->file_storage_provider->get($source->getFilePath());
        foreach ([$metadata['class'], ...$metadata['methods']] as $tags) {
            foreach ($tags as $tag => $entries) {
                foreach ($entries as [, $value]) {
                    $class_name = self::splitTarget($tag, $value)[0];
                    if ($class_name === '') {
                        continue;
                    }

                    $codebase->queueClassLikeForScanning($class_name);
                    $file_storage->referenced_classlikes[strtolower($class_name)] = $class_name;
                }
            }
        }
    }

    #[\Override]
    public static function afterStatementAnalysis(AfterClassLikeAnalysisEvent $event)
    {
        $codebase = $event->getCodebase();
        $storage = $event->getClasslikeStorage();

        if (!$codebase->classExtends($storage->name, 'PHPUnit\Framework\TestCase')) {
            return null;
        }

        $source = $event->getStatementsSource();
        $stmt = $event->getStmt();

        self::validateAttributeTargets($codebase, $source, $stmt, $storage);
        if (!PhpUnitVersion::ignoresDocblockMetadata()) {
            self::validateDocblockTargets($codebase, $source, $stmt, $storage);
        }

        return null;
    }

    private static function validateAttributeTargets(
        Codebase $codebase,
        StatementsSource $source,
        ClassLike $stmt,
        ClassLikeStorage $storage,
    ): void {
        $aliases = $source->getAliases();
        $suppressed = $storage->suppressed_issues + $source->getSuppressedIssues();

        foreach ($stmt->attrGroups as $group) {
            foreach ($group->attrs as $attribute) {
                $attribute_class = Type::getFQCLNFromString($attribute->name->toCodeString(), $aliases);
                $args = TestCaseHandler::attributeArguments($attribute);

                if (isset(self::METHOD_ATTRIBUTES[$attribute_class])) {
                    $method_name = $args['methodName'] ?? $args[1] ?? null;
                    $class_name = TestCaseHandler::classFromExpression(
                        $args['className'] ?? $args[0] ?? null,
                        $aliases,
                        $storage,
                    );
                    // A missing class is reported by Psalm
                    if (
                        $class_name === null
                        || !$method_name instanceof String_
                        || !self::classLikeExists($codebase, $class_name)
                    ) {
                        continue;
                    }

                    $target = $class_name . '::' . $method_name->value;
                    if ($codebase->getDeclaringMethodId($target) === null) {
                        IssueBuffer::accepts(new Issue\UndefinedMethod(
                            self::attributeMessage(self::METHOD_ATTRIBUTES[$attribute_class], $target),
                            new CodeLocation($source, $method_name),
                            $target,
                        ), $suppressed);
                    }
                } elseif (isset(self::FUNCTION_ATTRIBUTES[$attribute_class])) {
                    $function_name = $args['functionName'] ?? $args[0] ?? null;
                    if (!$function_name instanceof String_) {
                        continue;
                    }

                    $function_id = ltrim($function_name->value, '\\');
                    if (!self::functionExists($codebase, $function_id)) {
                        IssueBuffer::accepts(new Issue\UndefinedFunction(
                            self::attributeMessage(self::FUNCTION_ATTRIBUTES[$attribute_class], $function_id),
                            new CodeLocation($source, $function_name),
                            $function_id,
                        ), $suppressed);
                    }
                }
            }
        }
    }

    /** @psalm-pure */
    private static function attributeMessage(string $attribute, string $target): string
    {
        return '#[' . $attribute . '] target ' . $target . ' is not defined';
    }

    /**
     * Mirrors what PHPUnit does with @covers, @uses and the default class tags, so only targets PHPUnit would reject
     * are reported: names are not resolved against `use` imports, and `Class::name` also passes for a global
     * function called `name`. PHPUnit reads the default class tags only on the class (merged with the docblocks of
     * the traits it uses, a tag of the class replacing the same tag of a trait), and applies them to the methods
     * of the test case it runs, including inherited ones.
     */
    private static function validateDocblockTargets(
        Codebase $codebase,
        StatementsSource $source,
        ClassLike $stmt,
        ClassLikeStorage $storage,
    ): void {
        // tag => [storage that declares the docblock, [[line, value]]]
        $class_tags = [];
        if (!TestCaseHandler::hasPhpUnitAttribute($stmt, $source->getAliases())) {
            $declaring_storages = [];
            foreach ($stmt->getTraitUses() as $trait_use) {
                foreach ($trait_use->traits as $trait_name) {
                    $trait_name = Type::getFQCLNFromString($trait_name->toCodeString(), $source->getAliases());
                    if ($codebase->classlike_storage_provider->has($trait_name)) {
                        $declaring_storages[] = $codebase->classlike_storage_provider->get($trait_name);
                    }
                }
            }

            foreach ([...$declaring_storages, $storage] as $declaring_storage) {
                foreach (self::metadata($declaring_storage)['class'] as $tag => $entries) {
                    $class_tags[$tag] = [$declaring_storage, $entries];
                }
            }
        }

        // false marks a default class that does not exist, which was reported already
        $default_classes = [];
        foreach (self::DEFAULT_CLASS_TAGS as $tag => $target_tag) {
            [$declaring_storage, $entries] = $class_tags[$tag] ?? [$storage, []];
            $location = $declaring_storage->stmt_location ?? $declaring_storage->location;
            if ($entries === [] || $location === null) {
                continue;
            }

            [$line, $value] = $entries[0];
            $class_name = self::splitTarget($tag, $value)[0];
            $default_classes[$target_tag] = self::classLikeExists($codebase, $class_name) ? $class_name : false;
            if ($default_classes[$target_tag] === false) {
                IssueBuffer::accepts(new Issue\UndefinedClass(
                    '@' . $tag . ' target ' . $class_name . ' does not exist',
                    $location->setCommentLine($line),
                    $class_name,
                ), Suppressions::of(
                    $location,
                    $declaring_storage->suppressed_issues,
                    $storage,
                    $source,
                ));
            }
        }

        foreach (self::TARGET_TAGS as $tag => $_) {
            [$declaring_storage, $entries] = $class_tags[$tag] ?? [$storage, []];
            $location = $declaring_storage->stmt_location ?? $declaring_storage->location;
            if ($entries === [] || $location === null) {
                continue;
            }

            $suppressed = Suppressions::of(
                $location,
                $declaring_storage->suppressed_issues,
                $storage,
                $source,
            );
            foreach ($entries as [$line, $value]) {
                self::validateDocblockTarget(
                    $codebase,
                    '@' . $tag,
                    $value,
                    $default_classes[$tag] ?? null,
                    $location->setCommentLine($line),
                    $suppressed,
                );
            }
        }

        // An abstract test case is only run through its subclasses, which may bring their own default class
        if ($storage->abstract) {
            return;
        }

        foreach ($storage->declaring_method_ids as $declaring_method_id) {
            $declaring_storage = $codebase->classlike_storage_provider->get($declaring_method_id->fq_class_name);
            $tags = self::metadata($declaring_storage)['methods'][$declaring_method_id->method_name] ?? [];
            if ($tags === []) {
                continue;
            }

            $method_storage = $codebase->methods->getStorage($declaring_method_id);
            $location = $method_storage->stmt_location ?? $method_storage->location;
            if ($location === null) {
                continue;
            }

            $suppressed = Suppressions::of(
                $location,
                $method_storage->suppressed_issues + $declaring_storage->suppressed_issues,
                $storage,
                $source,
            );
            foreach ($tags as $tag => $entries) {
                foreach ($entries as [$line, $value]) {
                    self::validateDocblockTarget(
                        $codebase,
                        '@' . $tag,
                        $value,
                        $default_classes[$tag] ?? null,
                        $location->setCommentLine($line),
                        $suppressed,
                    );
                }
            }
        }
    }

    /** @param array<array-key, string> $suppressed */
    private static function validateDocblockTarget(
        Codebase $codebase,
        string $tag,
        string $value,
        string|false|null $default_class,
        CodeLocation $location,
        array $suppressed,
    ): void {
        $target = self::cleanUpTarget($value);
        if (str_starts_with($target, '::') && $default_class !== null) {
            // The default class does not exist, which was reported already
            if ($default_class === false) {
                return;
            }

            $target = $default_class . $target;
        }

        if ($target === '') {
            return;
        }

        [$class_name, $member] = self::splitMember($target);

        // PHPUnit also takes `Class::name` and `::name` for a global function called `name`
        if (self::functionExists($codebase, $member ?? $class_name)) {
            return;
        }

        if ($class_name === '') {
            if ($member !== '') {
                IssueBuffer::accepts(new Issue\UndefinedFunction(
                    $tag . ' target ' . $target . ' is not defined',
                    $location,
                    (string) $member,
                ), $suppressed);
            }

            return;
        }

        if (!self::classLikeExists($codebase, $class_name)) {
            IssueBuffer::accepts(new Issue\UndefinedClass(
                $tag . ' target ' . $class_name . ' does not exist',
                $location,
                $class_name,
            ), $suppressed);
        } elseif ($member !== null && $codebase->getDeclaringMethodId($class_name . '::' . $member) === null) {
            IssueBuffer::accepts(new Issue\UndefinedMethod(
                $tag . ' target ' . $target . ' is not defined',
                $location,
                $target,
            ), $suppressed);
        }
    }

    /**
     * The tags PHPUnit reads. The default class tags only count on the class. Methods that have a PHPUnit attribute
     * are left out, because PHPUnit ignores their docblock.
     *
     * @return array{
     *     class: array<string, list<array{int, string}>>,
     *     methods: array<lowercase-string, array<string, list<array{int, string}>>>,
     * }
     */
    private static function collectMetadata(ClassLike $stmt, Aliases $aliases): array
    {
        $metadata = [
            'class' => self::docblockTags($stmt, self::TARGET_TAGS + self::DEFAULT_CLASS_TAGS),
            'methods' => [],
        ];

        foreach ($stmt->getMethods() as $method) {
            $tags = self::docblockTags($method, self::TARGET_TAGS);
            if ($tags !== [] && !TestCaseHandler::hasPhpUnitAttribute($method, $aliases)) {
                $metadata['methods'][$method->name->toLowerString()] = $tags;
            }
        }

        return $metadata;
    }

    /**
     * @return array{
     *     class: array<string, list<array{int, string}>>,
     *     methods: array<lowercase-string, array<string, list<array{int, string}>>>,
     * }
     * @psalm-mutation-free
     */
    private static function metadata(ClassLikeStorage $storage): array
    {
        /**
         * @var array{
         *     class: array<string, list<array{int, string}>>,
         *     methods: array<lowercase-string, array<string, list<array{int, string}>>>,
         * }
         */
        return $storage->custom_metadata[self::class] ?? ['class' => [], 'methods' => []];
    }

    /**
     * @param array<string, mixed> $tags the tags to keep
     * @return array<string, list<array{int, string}>> tag => [[line, value]]
     */
    private static function docblockTags(ClassLike|ClassMethod $node, array $tags): array
    {
        $docblock = $node->getDocComment()?->getText() ?? '';
        if (!str_contains($docblock, '@covers') && !str_contains($docblock, '@uses')) {
            return [];
        }

        return array_intersect_key(DocblockSpecials::of($node), $tags);
    }

    /**
     * PHPUnit strips trailing whitespace and parentheses from the value and keeps its first word, so
     * `\NS\Foo::bar()` is the target `\NS\Foo::bar`, while `\NS\Foo::bar() description` stays `\NS\Foo::bar()`.
     *
     * @psalm-pure
     */
    private static function cleanUpTarget(string $value): string
    {
        $value = (string) preg_replace('/[\s()]+$/', '', $value);

        return ltrim(explode(' ', $value, 2)[0], '\\');
    }

    /**
     * @return array{string, string|null} the class (or function) name and the member of `Class::member`
     * @psalm-pure
     */
    private static function splitTarget(string $tag, string $value): array
    {
        if (isset(self::DEFAULT_CLASS_TAGS[$tag])) {
            return [ltrim($value, '\\'), null];
        }

        return self::splitMember(self::cleanUpTarget($value));
    }

    /**
     * @return array{string, string|null}
     * @psalm-pure
     */
    private static function splitMember(string $target): array
    {
        $position = strpos($target, '::');

        return $position === false ? [$target, null] : [substr($target, 0, $position), substr($target, $position + 2)];
    }

    /** Unlike methodExists() and the class checks with a location, this does not mark the target as used. */
    private static function classLikeExists(Codebase $codebase, string $name): bool
    {
        return $codebase->classlikes->classOrInterfaceOrEnumExists($name) || $codebase->classlikes->traitExists($name);
    }

    private static function functionExists(Codebase $codebase, string $name): bool
    {
        return $codebase->functions->isDeclaredInCode(ltrim($name, '\\'));
    }
}
