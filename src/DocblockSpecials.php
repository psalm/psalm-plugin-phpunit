<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin;

use PhpParser\Node;
use Psalm\DocComment;
use Psalm\Exception\DocblockParseException;

use function array_map;
use function substr_count;
use function trim;

final class DocblockSpecials
{
    /** @return array<string, list<array{int, string}>> tag => [[file line, value]] */
    public static function of(Node $node): array
    {
        $docblock = $node->getDocComment();
        if (!$docblock) {
            return [];
        }

        try {
            $tags = DocComment::parsePreservingLength($docblock)->tags;
        } catch (DocblockParseException) {
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
            $tags,
        );
    }
}
