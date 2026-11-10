<?php

declare(strict_types=1);

namespace Psalm\PhpUnitPlugin\Dataset;

use Psalm\Codebase;
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
     * Replaces the templates of the test method in a parameter type, as Psalm does for a call: by what the dataset
     * value infers, or by the template's bound when it infers nothing.
     */
    public static function resolve(Codebase $codebase, MethodStorage $method, Union $param_type, Union $argument): Union
    {
        if ($method->template_types === null || $param_type->getTemplateTypes() === []) {
            return $param_type;
        }

        $result = new TemplateResult($method->template_types, []);
        TemplateStandinTypeReplacer::fillTemplateResult($param_type, $result, $codebase, null, $argument);
        $inferred = TemplateInferredTypeReplacer::replace($param_type, $result, $codebase);

        // The bounds on the parameter type are already expanded, those in the method storage are not
        $bounds = [];
        foreach ($param_type->getTemplateTypes() as $template) {
            $bounds[$template->param_name][$template->defining_class] = $template->as;
        }

        return TemplateInferredTypeReplacer::replace($inferred, new TemplateResult($bounds, $bounds), $codebase);
    }
}
