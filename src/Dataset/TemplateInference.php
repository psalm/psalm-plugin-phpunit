<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Dataset;

use Psalm\Codebase;
use Psalm\Internal\Type\TemplateBound;
use Psalm\Internal\Type\TemplateInferredTypeReplacer;
use Psalm\Internal\Type\TemplateResult;
use Psalm\Internal\Type\TemplateStandinTypeReplacer;
use Psalm\Storage\MethodStorage;
use Psalm\Type\Union;

/**
 * @internal
 */
final class TemplateInference
{
    /**
     * What all the dataset values passed together infer about the templates of the test method, as Psalm infers
     * them from all the arguments of a call.
     *
     * @param list<array{Union, Union}> $pairs parameter type and dataset value
     */
    public static function infer(Codebase $codebase, MethodStorage $method, array $pairs): ?TemplateResult
    {
        if ($method->template_types === null) {
            return null;
        }

        $result = new TemplateResult($method->template_types, []);
        foreach ($pairs as $offset => [$param_type, $argument]) {
            TemplateStandinTypeReplacer::fillTemplateResult($param_type, $result, $codebase, null, $argument, $offset);
        }
        // Without replacing, the closure parameters record what they accept as upper bounds
        foreach ($pairs as $offset => [$param_type, $argument]) {
            TemplateStandinTypeReplacer::fillTemplateResult(
                $param_type,
                $result,
                $codebase,
                null,
                $argument,
                $offset,
                replace: false,
            );
        }

        // A template that no value infers takes what the closure accepts, as Psalm decides after checking a call
        foreach ($result->upper_bounds as $name => $by_class) {
            foreach ($by_class as $class => $upper_bound) {
                $result->lower_bounds[$name][$class] ??= [new TemplateBound($upper_bound->type)];
            }
        }

        return $result;
    }

    /**
     * Replaces the templates of the test method in a parameter type, as Psalm does for a call: by what the dataset
     * values infer, or by the template's bound when they infer nothing.
     */
    public static function resolve(
        Codebase $codebase,
        MethodStorage $method,
        Union $param_type,
        Union $argument,
        ?TemplateResult $inferred = null,
    ): Union {
        if ($method->template_types === null || $param_type->getTemplateTypes() === []) {
            return $param_type;
        }

        $inferred ??= self::infer($codebase, $method, [[$param_type, $argument]]);
        $replaced = $inferred === null
            ? $param_type
            : TemplateInferredTypeReplacer::replace($param_type, $inferred, $codebase);

        // The bounds on the parameter type are already expanded, those in the method storage are not
        $bounds = [];
        foreach ($param_type->getTemplateTypes() as $template) {
            $bounds[$template->param_name][$template->defining_class] = $template->as;
        }

        return TemplateInferredTypeReplacer::replace($replaced, new TemplateResult($bounds, $bounds), $codebase);
    }
}
