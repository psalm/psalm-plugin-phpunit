<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use PhpParser\Comment\Doc;
use PhpParser\Node;
use Psalm\DocComment;

final class DocblockSpecials
{
    /**
     * PHPUnit takes the value of these tags from the rest of the line.
     *
     * @var array<string, true>
     */
    private const VALUE_TAGS = [
        'backupGlobals' => true,
        'backupStaticAttributes' => true,
        'covers' => true,
        'coversDefaultClass' => true,
        'dataProvider' => true,
        'depends' => true,
        'group' => true,
        'preserveGlobalState' => true,
        'requires' => true,
        'testDox' => true,
        'testWith' => true,
        'ticket' => true,
        'uses' => true,
        'usesDefaultClass' => true,
    ];

    /**
     * Matches every tag PHPUnit 11 reads from a docblock (the keys of DocblockMetadataHandler::ATTRIBUTES) by its
     * first letters, in any case.
     */
    private const TAGS = '/@(?:after|backup|before|covers|dataProvider|depends|doesNotPerformAssertions|exclude|group'
        . '|large|medium|postCondition|preCondition|preserveGlobalState|requires|run|small|test|ticket|uses)/i';

    /**
     * The tags PHPUnit 11 accepts. A malformed tag is ignored by PHPUnit, so it is not here.
     *
     * @return array<string, list<array{int, string}>> tag => [[file line, value]]
     */
    public static function of(Node $node): array
    {
        $specials = [];
        foreach (self::parse($node) as [$tag, $line, $value, $problem]) {
            if ($problem === null) {
                $specials[$tag][] = [$line, $value];
            }
        }

        return $specials;
    }

    /**
     * Every tag, malformed or not, of a docblock that may hold a tag PHPUnit 11 reads.
     *
     * @return array<string, list<array{int, string}>> tag => [[file line, value]]
     */
    public static function all(Node $node): array
    {
        $specials = [];
        foreach (self::parse($node) as [$tag, $line, $value]) {
            $specials[$tag][] = [$line, $value];
        }

        return $specials;
    }

    /** @return list<array{tag: string, line: int, problem: string}> what is wrong with each tag PHPUnit ignores */
    public static function malformed(Node $node): array
    {
        $malformed = [];
        foreach (self::parse($node) as [$tag, $line, , $problem]) {
            if ($problem !== null) {
                $malformed[] = ['tag' => $tag, 'line' => $line, 'problem' => $problem];
            }
        }

        return $malformed;
    }

    /**
     * Whether the docblock of the node may hold a tag PHPUnit 11 reads. Without one, of(), all() and malformed() find
     * nothing.
     */
    public static function mayHoldTags(Node $node): bool
    {
        $docblock = $node->getDocComment();

        return $docblock !== null && self::docblockMayHoldTags($docblock);
    }

    private static function docblockMayHoldTags(Doc $docblock): bool
    {
        // Psalm's DocblockParser removes every \r before it reads a tag
        return \preg_match(self::TAGS, \str_replace("\r", '', $docblock->getText())) === 1;
    }

    /**
     * @return list<array{string, int, string, string|null}> [tag, file line, value, what is wrong with the tag]
     */
    private static function parse(Node $node): array
    {
        $docblock = $node->getDocComment();
        if ($docblock === null || !self::docblockMayHoldTags($docblock)) {
            return [];
        }

        $tags = DocComment::parsePreservingLength($docblock, true)->tags;

        $entries = [];
        foreach ($tags as $tag => $values) {
            foreach ($values as $offset => $data) {
                $entries[] = [
                    $tag,
                    // Psalm keys tags by absolute file offset, which is useless for issue locations.
                    $docblock->getStartLine()
                        + \substr_count($docblock->getText(), "\n", 0, $offset - $docblock->getStartFilePos()),
                    // PHPUnit reads a tag's value from its own line only, Psalm also folds the following lines into it.
                    self::firstLine($data),
                    self::problem($docblock, $tag, $offset, $data),
                ];
            }
        }

        return $entries;
    }

    /** @psalm-pure */
    private static function firstLine(string $data): string
    {
        return \trim(\explode("\n", $data, 2)[0]);
    }

    /** @return string|null What is wrong with the tag, null when PHPUnit accepts it */
    private static function problem(Doc $docblock, string $tag, int $offset, string $data): ?string
    {
        if (!isset(self::VALUE_TAGS[$tag])) {
            return null;
        }

        // PHPUnit's `@testWith\s+` spans line breaks, so the datasets may start on the line below the tag.
        // Psalm then starts the value at that line break.
        if ($tag === 'testWith') {
            if (\trim($data) === '') {
                return 'has no value';
            }

            if (\ltrim($data) !== $data) {
                return null;
            }
        } elseif (self::firstLine($data) === '') {
            return 'has no value';
        }

        $char_before_value = $docblock->getText()[$offset - $docblock->getStartFilePos() - 1];

        return $char_before_value === ' ' || $char_before_value === "\t"
            ? null
            : 'must be followed by a space and a value';
    }
}
