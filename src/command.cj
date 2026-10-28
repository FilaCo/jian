macro package jian

import std.ast.*

/**
 * Generates a typed CLI adapter beside the unchanged command function.
 */
public macro Command(attrs: Tokens, input: Tokens): Tokens {
    commandAdapter(attrs, input)
}

/**
 * Attribute-free form of `@Command`.
 */
public macro Command(input: Tokens): Tokens {
    commandAdapter(Tokens(), input)
}

func cliName(name: String): String {
    var result = ""
    let bytes = name.toArray()
    for (index in 0..bytes.size) {
        let value = bytes[index]
        if (value == 95) {
            result += "-"
        } else if (value >= 65 && value <= 90) {
            if (index > 0 && bytes[index - 1] != 95 &&
                (bytes[index - 1] >= 97 && bytes[index - 1] <= 122 ||
                 index + 1 < bytes.size && bytes[index + 1] >= 97 && bytes[index + 1] <= 122)) {
                result += "-"
            }
            result += String.fromUtf8([value + 32])
        } else {
            result += String.fromUtf8([value])
        }
    }
    result
}

func commandAdapter(attrs: Tokens, input: Tokens, callback!: Bool = false): Tokens {
    let declaration = FuncDecl(input)
    if (declaration.isGenericDecl) {
        diagReport(DiagReportLevel.ERROR, declaration.genericParam.toTokens(),
            "@Command does not take generic functions", "use a concrete command function")
        return input
    }
    if (declaration.colon.kind == TokenKind.COLON) {
        let result = declaration.declType.toTokens()
        let spelling = result.toString().replace(" ", "")
        if (spelling != "Unit" && spelling != "Int64") {
            diagReport(DiagReportLevel.ERROR, result,
                "@Command return type must be Unit or Int64", "omit the return type to let the compiler infer it")
            return input
        }
    }
    let functionName = declaration.identifier
    let sourceName = functionName.value.replace("`", "")
    let suffix = if (callback) { "Callback" } else { "Command" }
    let interfaceName = Token(TokenKind.IDENTIFIER, suffix)
    let className = Token(TokenKind.IDENTIFIER, sourceName[0..1].toAsciiUpper() + sourceName[1..] + suffix)
    let name = Token(TokenKind.STRING_LITERAL, cliName(sourceName))
    var help = quote("")
    if (attrs.size != 0) {
        let settings = CallExpr(quote(__jian_settings($(attrs))))
        for (setting in settings.arguments) {
            if (setting.identifier.value != "help") {
                throw ASTException("unknown ${suffix} setting '${setting.identifier.value}'")
            }
            help = setting.expr.toTokens()
        }
    }
    var specs = Tokens()
    var storage = Tokens()
    var options = Tokens()
    var operands = Tokens()
    var shorts = Tokens()
    var bindings = Tokens()
    var arguments = Tokens()
    let metadata = getChildMessages("Param")
    var usedShorts = ""
    var positional = 0
    var names: Array<String> = []
    for (index in 0..declaration.funcParams.size) {
        let parameter = declaration.funcParams[index]
        let identifier = parameter.identifier
        let typeName = parameter.paramType.toTokens()
        let slot = Token(TokenKind.IDENTIFIER, "__jian_value_${index}")
        let cli = cliName(identifier.value.replace("`", ""))
        if (names.contains(cli)) {
            diagReport(DiagReportLevel.ERROR, quote($(identifier)),
                "duplicate CLI parameter name '--${cli}'", "use distinct names after kebab-case conversion")
            return input
        }
        if (cli == "help") {
            diagReport(DiagReportLevel.ERROR, quote($(identifier)),
                "parameter name '--help' is reserved", "choose another parameter name")
            return input
        }
        names = names.concat([cli])
        let cliLiteral = Token(TokenKind.STRING_LITERAL, cli)
        let optionLabel = Token(TokenKind.STRING_LITERAL, "--" + cli)
        let named = parameter.not.kind == TokenKind.NOT
        let label = if (named) { optionLabel } else { Token(TokenKind.STRING_LITERAL, cli.toAsciiUpper()) }
        let hasDefault = parameter.assign.kind == TokenKind.ASSIGN
        let repeated = match (parameter.paramType as RefType) {
            case Some(reference) => reference.identifier.value == "Array" && reference.typeArguments.size == 1
            case None => false
        }
        if (repeated && !named) {
            for (later in index + 1..declaration.funcParams.size) {
                if (declaration.funcParams[later].not.kind != TokenKind.NOT) {
                    diagReport(DiagReportLevel.ERROR, typeName,
                        "variadic Array parameter must be the last positional parameter",
                        "move this parameter after all other positional parameters")
                    return input
                }
            }
        }
        let repeatable = if (repeated) { quote(true) } else { quote(false) }
        var short = quote(None)
        var paramHelp = quote("")
        var hidden = quote(false)
        var markers = 0
        for (message in metadata) {
            if (!message.hasItem("param") || message.getString("param") != identifier.value) { continue }
            markers++
            if (markers > 1) { throw ASTException("apply @Param only once per parameter") }
            if (message.hasItem("help")) { paramHelp = message.getTokens("help") }
            if (message.hasItem("hidden")) { hidden = message.getTokens("hidden") }
            if (message.hasItem("short")) {
                if (!named) { throw ASTException("short name requires a named parameter") }
                let spelling = message.getTokens("short").toString().trimAscii()
                if (spelling.size != 3 || !spelling.startsWith("'") || !spelling.endsWith("'") ||
                    spelling.toArray()[1] > 127) {
                    throw ASTException("short name must be a single ASCII character literal")
                }
                let alias = spelling[1..2]
                if (alias == "h") { throw ASTException("short name '-h' is reserved for help") }
                if (usedShorts.contains(alias)) { throw ASTException("duplicate short name '-${alias}'") }
                usedShorts += alias
                let byte = Token(TokenKind.INTEGER_LITERAL, spelling.toArray()[1].toString())
                short = quote(Some(UInt8($(byte))))
                shorts += quote(
                    if (__jian_short == UInt8($(byte))) { __jian_name = $(cliLiteral); }
                )
            }
        }
        let kind = if (named) {
            quote(if (takesValueAs<$(typeName)>()) { ParamKind.ValueOption } else { ParamKind.Flag })
        } else { quote(ParamKind.Positional) }
        let shown = if (hasDefault) {
            let text = Token(TokenKind.STRING_LITERAL, parameter.expr.toTokens().toString())
            quote(Some($(text)))
        } else { quote(None) }
        let required = if (hasDefault) { quote(false) } else { quote(whenAbsentAs<$(typeName)>().isNone()) }
        specs += quote(ParamSpec($(cliLiteral), kind: $(kind), metavar: metavarAs<$(typeName)>(),
            short: $(short), help: $(paramHelp), hidden: $(hidden), defaultShown: $(shown), required: $(required), repeatable: $(repeatable)),)
        storage += quote(var $(slot): Option<$(typeName)> = None;)
        if (named) {
            options += quote(
                if (__jian_name == $(cliLiteral)) {
                    let __jian_raw: ?String = if (__jian_attached.isSome()) { __jian_attached }
                        else if (takesValueAs<$(typeName)>()) { Some(__jian_args.nextValue($(optionLabel))) }
                        else { None }
                    try {
                        $(slot) = Some(acceptAs<$(typeName)>($(slot), __jian_raw))
                    } catch (__jian_error: InvalidValueException) {
                        throw UsageException.invalidValue($(label), __jian_error.raw, __jian_error.expected)
                    }
                    continue
                }
            )
        } else {
            let ordinal = Token(TokenKind.INTEGER_LITERAL, positional.toString())
            // Keep the cursor on the final array so later operands accumulate in it.
            let advance = if (repeated) { Tokens() } else { quote(__jian_position++) }
            operands += quote(
                if (__jian_position == $(ordinal)) {
                    try {
                        $(slot) = Some(acceptAs<$(typeName)>($(slot), Some(__jian_operand)))
                    } catch (__jian_error: InvalidValueException) {
                        throw UsageException.invalidValue($(label), __jian_error.raw, __jian_error.expected)
                    }
                    $(advance)
                    continue
                }
            )
            positional++
        }
        let absent = if (hasDefault) { parameter.expr.toTokens() }
            else { quote(whenAbsentAs<$(typeName)>() ?? throw UsageException.missingArgument($(label))) }
        // Bind original names in order so defaults retain their lexical dependencies.
        bindings += quote(let $(identifier): $(typeName) = $(slot) ?? ($(absent));)
        if (index > 0) { arguments += quote(,) }
        arguments += if (named) { quote($(identifier): $(identifier)) } else { quote($(identifier)) }
    }
    let commandName = if (callback) { Tokens() } else { quote(public prop name: String { get() { $(name) } }) }
    let positionalCount = Token(TokenKind.INTEGER_LITERAL, positional.toString())
    // Look ahead so the callback leaves the command name and its options for App.
    let boundary = if (callback) { quote(
        if (__jian_position >= $(positionalCount)) {
            if (let Arg.Operand(_) <- __jian_arg) { break }
        }
    ) } else { Tokens() }
    input + quote(
        public class $(className) <: $(interfaceName) {
            $(commandName)
            public prop spec: CommandSpec { get() { CommandSpec(help: $(help), params: [$(specs)]) } }
            public func run(__jian_args: ArgCursor): Int64 {
                $(storage)
                var __jian_position = 0
                while (let Some(__jian_arg) <- __jian_args.peek()) {
                    $(boundary)
                    __jian_args.next()
                    var __jian_name = ""
                    var __jian_attached: ?String = None
                    match (__jian_arg) {
                        case Arg.Operand(__jian_operand) =>
                            $(operands)
                            throw UsageException("unexpected argument '${__jian_operand}'")
                        case Arg.Long(__jian_long) => __jian_name = __jian_long
                        case Arg.Long(__jian_long, __jian_raw) =>
                            __jian_name = __jian_long
                            __jian_attached = Some(__jian_raw)
                        case Arg.Short(__jian_short) =>
                            $(shorts)
                            if (__jian_name.isEmpty()) {
                                throw UsageException.unknownOption("-" + String.fromUtf8([__jian_short]))
                            }
                        case Arg.Short(__jian_short, __jian_raw) =>
                            $(shorts)
                            if (__jian_name.isEmpty()) {
                                throw UsageException.unknownOption("-" + String.fromUtf8([__jian_short]))
                            }
                            __jian_attached = Some(__jian_raw)
                    }
                    $(options)
                    throw UsageException.unknownOption("--" + __jian_name)
                }
                $(bindings)
                exitCode($(functionName)($(arguments)))
            }
        }
    )
}
