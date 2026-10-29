package jian.runtime

func usageLine(path: String, spec: JianCommandSpec, commands!: Bool = false): String {
    var text = "Usage: ${path} [OPTIONS]"
    for (param in spec.inputs) {
        if (param.kind == JianInputKind.Positional && !param.hidden) {
            let label = positionalLabel(param)
            text += if (param.required) { " ${label}" } else { " [${label}]" }
        }
    }
    if (commands) {
        text += if (spec.defaultAction.isSome()) { " [COMMAND [ARGS]...]" } else { " COMMAND [ARGS]..." }
    }
    "${text}\n"
}

func positionalLabel(param: JianInputSpec): String {
    let suffix = if (param.repeatable) { "..." } else { "" }
    "${param.name.toAsciiUpper()}${suffix}"
}

func parameterHelp(spec: JianCommandSpec): String {
    var arguments = ""
    var options = ""
    for (param in spec.inputs) {
        if (param.hidden) { continue }
        var description = param.help
        if (let Some(value) <- param.defaultShown) {
            description += if (description.isEmpty()) { "" } else { " " }
            description += "[default: ${value}]"
        }
        if (param.required) {
            description += if (description.isEmpty()) { "" } else { " " }
            description += "[required]"
        }
        if (param.kind == JianInputKind.Positional) {
            arguments += helpRow(positionalLabel(param), description)
        } else {
            var label = "--${param.name}"
            if (let Some(short) <- param.short) {
                label = "-${String.fromUtf8([short])}, ${label}"
            }
            if (param.kind == JianInputKind.ValueOption && !param.metavar.isEmpty()) {
                label += " ${param.metavar}"
            }
            options += helpRow(label, description)
        }
    }
    var text = if (arguments.isEmpty()) { "" } else { "\nArguments:\n${arguments}" }
    let helpOption = helpRow("-h, --help", "Show this message and exit.")
    text += "\nOptions:\n${options}${helpOption}"
    text
}

func helpRow(label: String, description: String): String {
    if (description.isEmpty()) { "  ${label}\n" } else { "  ${label}  ${description}\n" }
}

func commandHelp(path: String, spec: JianCommandSpec): String {
    let usage = usageLine(path, spec)
    let description = if (spec.help.isEmpty()) { "" } else { "\n${spec.help}\n" }
    let parameters = parameterHelp(spec)
    "${usage}${description}${parameters}"
}

/**
 * Detects help requests using the parser's cursor rules, excluding option values
 * and operands after `--`. App scanning stops at its subcommand.
 */
func requestsHelp(argv: Array<String>, spec: JianCommandSpec, app!: Bool = false): Bool {
    let args = JianArgCursor(argv, shortsTakingValue: valueShorts(spec))
    let positionals = spec.inputs.filter({ param => param.kind == JianInputKind.Positional })
    var position = 0
    while (let Some(arg) <- args.next()) {
        match (arg) {
            case JianArg.Long(name) =>
                if (name == "help") { return true }
                var known = false
                for (param in spec.inputs) {
                    if (param.kind != JianInputKind.Positional && param.name == name) {
                        known = true
                        if (param.kind == JianInputKind.ValueOption) { args.nextValue("--${name}") }
                        break
                    }
                }
                if (!known) { return false }
            case JianArg.Long(name, _) =>
                if (!spec.inputs.any({ param => param.kind != JianInputKind.Positional && param.name == name })) {
                    return false
                }
            case JianArg.Short(name) =>
                if (name == b'h') { return true }
                if (!spec.inputs.any({ param => param.kind != JianInputKind.Positional && param.short == Some(name) })) {
                    return false
                }
            case JianArg.Short(name, _) =>
                if (!spec.inputs.any({ param => param.kind != JianInputKind.Positional && param.short == Some(name) })) {
                    return false
                }
            case JianArg.Operand(_) =>
                if (app && position >= positionals.size) { return false }
                if (position < positionals.size && !positionals[position].repeatable) { position++ }
        }
    }
    false
}
