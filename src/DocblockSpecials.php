<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use PhpParser\Comment\Doc;
use PhpParser\Node;
use Psalm\DocComment;

use function explode;
use function ltrim;
use function substr_count;
use function trim;

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
    ];

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
     * Every tag, malformed or not.
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
     * @return list<array{string, int, string, string|null}> [tag, file line, value, what is wrong with the tag]
     */
    private static function parse(Node $node): array
    {
        $docblock = $node->getDocComment();
        if (!$docblock) {
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
                        + substr_count($docblock->getText(), "\n", 0, $offset - $docblock->getStartFilePos()),
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
        return trim(explode("\n", $data, 2)[0]);
    }

    /** @return string|null What is wrong with the tag, null when PHPUnit accepts it */
    private static function problem(Doc $docblock, string $tag, int $offset, string $data): string|null
    {
        if (!isset(self::VALUE_TAGS[$tag])) {
            return null;
        }

        // PHPUnit's `@testWith\s+` spans line breaks, so the datasets may start on the line below the tag.
        // Psalm then starts the value at that line break.
        if ($tag === 'testWith') {
            if (trim($data) === '') {
                return 'has no value';
            }

            if (ltrim($data) !== $data) {
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
