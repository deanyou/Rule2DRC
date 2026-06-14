# spec2drc: Foundry DRC Spec → KLayout DRC Script Generator
# Usage: python spec2drc.py <spec.yaml> [--output <output.drc>]

import yaml
import sys
import argparse
from pathlib import Path

# KLayout DRC DSL templates for each rule type
RULE_TEMPLATES = {
    "width_min": """
{name}.width({threshold}.um).output("{category}", "{desc}")""",

    "width_max": """
{sized_name} = {name}.sized(-{threshold}.um / 2).sized({threshold}.um / 2)
{sized_name}.output("{category}", "{desc}")""",

    "spacing": """
{name}.separation({other}.separation, {threshold}.um).output("{category}", "{desc}")""",

    "spacing_self": """
{name}.space({threshold}.um).output("{category}", "{desc}")""",

    "enclosed": """
{name}.enclosed({other}.separation, {threshold}.um).output("{category}", "{desc}")
({name} - {other}.separation).output("{category}", "{desc} not inside {other}")""",

    "inside": """
({name} - {other}.separation).output("{category}", "{desc}")""",

    "overlap": """
({name} & {other}).output("{category}", "{desc}")""",

    "no_overlap": """
({name} & {other}).output("{category}", "{desc}")""",

    "separation": """
{name}.separation({other}, {threshold}.um).output("{category}", "{desc}")""",

    "extension": """
({name} - {other}.sized({threshold}.um)).output("{category}", "{desc}")""",

    "area_min": """
{name}.area({threshold}.um²).output("{category}", "{desc}")""",

    "area_max": """
{name}.area < {threshold}.um²).output("{category}", "{desc}")""",

    "multi_layer_check": """
{expression}.output("{category}", "{desc}")""",
}


def load_spec(spec_path: Path) -> dict:
    with open(spec_path) as f:
        return yaml.safe_load(f)


def generate_drc(spec: dict) -> str:
    title = spec.get("title", spec.get("id", "DRC Check"))
    layers = spec.get("layers", {})
    rules = spec.get("rules", [])
    categories = spec.get("categories", [])

    lines = []
    lines.append(f'source($input)')
    lines.append(f'report("{title}", $output)')
    lines.append("")

    # Layer definitions
    lines.append("# Layer definitions")
    layer_vars = {}
    for name, (layer_num, datatype) in layers.items():
        var_name = name.replace(" ", "_").replace("-", "_").lower()
        layer_vars[name] = var_name
        lines.append(f"{var_name} = input({layer_num}, {datatype})")
    lines.append("")

    # Rules
    lines.append("# DRC Rules")
    for rule in rules:
        rule_type = rule.get("type", "")
        category = rule.get("category", "")
        desc = rule.get("text", rule.get("desc", ""))
        threshold = rule.get("threshold", rule.get("value", ""))
        layer_name = rule.get("layer", "")
        other_layer = rule.get("other_layer", "")

        # Get variable names
        var = layer_vars.get(layer_name, layer_name)
        other_var = layer_vars.get(other_layer, other_layer) if other_layer else ""

        if rule_type == "width_min":
            lines.append(f'{var}.width({threshold}.um).output("{category}", "{desc}")')

        elif rule_type == "width_max":
            sn = f"{var}_sized"
            lines.append(f'{sn} = {var}.sized(-{threshold}.um / 2).sized({threshold}.um / 2)')
            lines.append(f'{sn}.output("{category}", "{desc}")')

        elif rule_type == "spacing":
            lines.append(f'{var}.separation({other_var}, {threshold}.um).output("{category}", "{desc}")')

        elif rule_type == "spacing_self":
            lines.append(f'{var}.space({threshold}.um).output("{category}", "{desc}")')

        elif rule_type == "enclosed":
            lines.append(f'{var}.enclosed({other_var}, {threshold}.um).output("{category}", "{desc}")')
            lines.append(f'({var} - {other_var}).output("{category}", "{desc} not inside")')

        elif rule_type == "inside":
            lines.append(f'({var} - {other_var}).output("{category}", "{desc}")')

        elif rule_type == "overlap":
            lines.append(f'({var} & {other_var}).output("{category}", "{desc}")')

        elif rule_type == "no_overlap":
            lines.append(f'({var} & {other_var}).output("{category}", "{desc}")')

        elif rule_type == "separation":
            lines.append(f'{var}.separation({other_var}, {threshold}.um).output("{category}", "{desc}")')

        elif rule_type == "extension":
            lines.append(f'({var} - {other_var}.sized({threshold}.um)).output("{category}", "{desc}")')

        elif rule_type == "expression":
            # Custom expression
            expr = rule.get("expression", "")
            # Replace layer names with variables
            for name, var in layer_vars.items():
                expr = expr.replace(f"${name}", var)
            lines.append(f'({expr}).output("{category}", "{desc}")')

        lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Generate KLayout DRC script from structured spec")
    parser.add_argument("spec", help="Path to YAML spec file")
    parser.add_argument("-o", "--output", help="Output DRC file path (default: stdout)")
    parser.add_argument("--list-rules", action="store_true", help="List supported rule types")
    args = parser.parse_args()

    if args.list_rules:
        print("Supported rule types:")
        for rt in sorted(RULE_TEMPLATES.keys()):
            print(f"  {rt}")
        return

    spec = load_spec(Path(args.spec))
    drc = generate_drc(spec)

    if args.output:
        Path(args.output).write_text(drc)
        print(f"Generated: {args.output}")
    else:
        print(drc)


if __name__ == "__main__":
    main()
