package jian.runtime

func usageLine(path: String, spec: JianCommandSpec, commands!: Bool = false): String {
    var text = "Usage: ${path} [OPTIONS]"
    for (param in spec.inputs) {
        if (param.kind == JianInputKind.Positional && !param.hidden) {
            let label = positionalLabel(param)
            text += " " + if (param.required) { label } else { "[${label}]" }
        }
    }
    if (commands) { text += " COMMAND [ARGS]..." }
    text + "\n"
}

func positionalLabel(param: JianInputSpec): String {
    param.name.toAsciiUpper() + if (param.repeatable) { "..." } else { "" }
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
            var label = "--" + param.name
            if (let Some(short) <- param.short) {
                label = "-" + String.fromUtf8([short]) + ", " + label
            }
            if (param.kind == JianInputKind.ValueOption && !param.metavar.isEmpty()) {
                label += " " + param.metavar
            }
            options += helpRow(label, description)
        }
    }
    var text = if (arguments.isEmpty()) { "" } else { "\nArguments:\n" + arguments }
    text += "\nOptions:\n" + options + helpRow("-h, --help", "Show this message and exit.")
    text
}

func helpRow(label: String, description: String): String {
    "  " + label + if (description.isEmpty()) { "\n" } else { "  " + description + "\n" }
}

func commandHelp(path: String, spec: JianCommandSpec): String {
    usageLine(path, spec) + if (spec.help.isEmpty()) { "" } else { "\n" + spec.help + "\n" } +
        parameterHelp(spec)
}

// Scan with the same cursor rules as parsing: option values and operands after
// `--` must never turn into help requests. JianApp scanning stops at its subcommand.
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
                        if (param.kind == JianInputKind.ValueOption) { args.nextValue("--" + name) }
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
