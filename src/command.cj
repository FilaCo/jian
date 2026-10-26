macro package jian

import std.ast.*

/**
 * Generates a typed CLI adapter beside the command function, replacing CLI markers with real defaults.
 */
public macro JianCommand(attrs: Tokens, input: Tokens): Tokens {
    commandAdapter(attrs, input)
}

/**
 * Attribute-free form of `@JianCommand`.
 */
public macro JianCommand(input: Tokens): Tokens {
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
    let suffix = if (callback) { "Callback" } else { "Command" }
    if (declaration.isGenericDecl) {
        diagReport(DiagReportLevel.ERROR, declaration.genericParam.toTokens(),
            "@Jian${suffix} does not take generic functions", "use a concrete command function")
        return input
    }
    if (declaration.colon.kind == TokenKind.COLON) {
        let result = declaration.declType.toTokens()
        let spelling = result.toString().replace(" ", "")
        if (spelling != "Unit" && spelling != "Int64") {
            diagReport(DiagReportLevel.ERROR, result,
                "@Jian${suffix} return type must be Unit or Int64", "omit the return type to let the compiler infer it")
            return input
        }
    }
    let functionName = declaration.identifier
    let sourceName = functionName.value.replace("`", "")
    let interfaceName = Token(TokenKind.IDENTIFIER, "Jian" + suffix)
    let className = Token(TokenKind.IDENTIFIER, sourceName[0..1].toAsciiUpper() + sourceName[1..] + suffix)
    let name = Token(TokenKind.STRING_LITERAL, cliName(sourceName))
    var help = quote("")
    if (attrs.size != 0) {
        let settings = CallExpr(quote(__jian_settings($(attrs))))
        for (setting in settings.arguments) {
            if (setting.identifier.value != "help") {
                throw ASTException("unknown Jian${suffix} setting '${setting.identifier.value}'")
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
                "duplicate CLI input name '--${cli}'", "use distinct names after kebab-case conversion")
            return input
        }
        if (cli == "help") {
            diagReport(DiagReportLevel.ERROR, quote($(identifier)),
                "option name '--help' is reserved", "choose another parameter name")
            return input
        }
        names = names.concat([cli])
        let cliLiteral = Token(TokenKind.STRING_LITERAL, cli)
        let optionLabel = Token(TokenKind.STRING_LITERAL, "--" + cli)
        let functionNamed = parameter.not.kind == TokenKind.NOT
        let settings = parameterSettings(parameter)
        let named = functionNamed && settings.marker != "JianArgument"
        if (settings.marker == "JianOption" && !functionNamed) {
            throw ASTException("JianOption requires a named function parameter")
        }
        let implicitNone = functionNamed && isOptionalSpelling(parameter.paramType)
        if (settings.marker != "") {
            // Marker expressions are declaration syntax, never runtime defaults.
            if (let Some(value) <- settings.defaultValue) {
                parameter.expr = parseExpr(value)
            } else if (implicitNone) {
                parameter.expr = parseExpr(quote(None))
            } else {
                let original = parameter.toTokens()
                var plain = Tokens()
                for (token in original) {
                    if (token.kind == TokenKind.ASSIGN) { break }
                    plain.append(token)
                }
                if (original[original.size - 1].kind == TokenKind.COMMA) {
                    plain.append(original[original.size - 1])
                }
                declaration.funcParams[index] = FuncParam(plain)
            }
        }
        if (implicitNone && parameter.assign.kind != TokenKind.ASSIGN) {
            parameter.assign = Token(TokenKind.ASSIGN)
            parameter.expr = parseExpr(quote(None))
        }
        let label = if (named) { optionLabel } else { Token(TokenKind.STRING_LITERAL, cli.toAsciiUpper()) }
        let hasDefault = declaration.funcParams[index].assign.kind == TokenKind.ASSIGN
        let repeated = match (parameter.paramType as RefType) {
            case Some(reference) => reference.identifier.value == "Array" && reference.typeArguments.size == 1
            case None => false
        }
        if (repeated && !named) {
            for (later in index + 1..declaration.funcParams.size) {
                if (!isNamedCLI(declaration.funcParams[later])) {
                    diagReport(DiagReportLevel.ERROR, typeName,
                        "variadic Array argument must be the last positional argument",
                        "move this argument after all other positional arguments")
                    return input
                }
            }
        }
        let repeatable = if (repeated) { quote(true) } else { quote(false) }
        var short = quote(None)
        if (let Some(shortName) <- settings.short) {
            let spelling = shortName.toString().trimAscii()
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
        let inputHelp = settings.help
        let hidden = settings.hidden
        let kind = if (named) {
            quote(if (jianTakesValueAs<$(typeName)>()) { JianInputKind.ValueOption } else { JianInputKind.Flag })
        } else { quote(JianInputKind.Positional) }
        let shown = if (hasDefault) {
            let text = Token(TokenKind.STRING_LITERAL, declaration.funcParams[index].expr.toTokens().toString())
            quote(Some($(text)))
        } else { quote(None) }
        let required = if (hasDefault) { quote(false) } else { quote(jianWhenAbsentAs<$(typeName)>().isNone()) }
        specs += quote(JianInputSpec($(cliLiteral), kind: $(kind), metavar: jianMetavarAs<$(typeName)>(),
            short: $(short), help: $(inputHelp), hidden: $(hidden), defaultShown: $(shown), required: $(required), repeatable: $(repeatable)),)
        storage += quote(var $(slot): Option<$(typeName)> = None;)
        if (named) {
            options += quote(
                if (__jian_name == $(cliLiteral)) {
                    let __jian_raw: ?String = if (__jian_attached.isSome()) { __jian_attached }
                        else if (jianTakesValueAs<$(typeName)>()) { Some(__jian_args.nextValue($(optionLabel))) }
                        else { None }
                    try {
                        $(slot) = Some(jianAcceptAs<$(typeName)>($(slot), __jian_raw))
                    } catch (__jian_error: JianInvalidValueException) {
                        throw JianUsageException.invalidValue($(label), __jian_error.raw, __jian_error.expected)
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
                        $(slot) = Some(jianAcceptAs<$(typeName)>($(slot), Some(__jian_operand)))
                    } catch (__jian_error: JianInvalidValueException) {
                        throw JianUsageException.invalidValue($(label), __jian_error.raw, __jian_error.expected)
                    }
                    $(advance)
                    continue
                }
            )
            positional++
        }
        let absent = if (hasDefault) { declaration.funcParams[index].expr.toTokens() }
            else { quote(jianWhenAbsentAs<$(typeName)>() ?? throw JianUsageException.missingArgument($(label))) }
        // Bind original names in order so defaults retain their lexical dependencies.
        bindings += quote(let $(identifier): $(typeName) = $(slot) ?? ($(absent));)
        if (index > 0) { arguments += quote(,) }
        arguments += if (functionNamed) { quote($(identifier): $(identifier)) } else { quote($(identifier)) }
    }
    let commandName = if (callback) { Tokens() } else { quote(public prop name: String { get() { $(name) } }) }
    let positionalCount = Token(TokenKind.INTEGER_LITERAL, positional.toString())
    // Look ahead so the callback leaves the command name and its options for JianApp.
    let boundary = if (callback) { quote(
        if (__jian_position >= $(positionalCount)) {
            if (let JianArg.Operand(_) <- __jian_arg) { break }
        }
    ) } else { Tokens() }
    declaration.toTokens() + quote(
        public class $(className) <: $(interfaceName) {
            $(commandName)
            public prop spec: JianCommandSpec { get() { JianCommandSpec(help: $(help), inputs: [$(specs)]) } }
            public func run(__jian_args: JianArgCursor): Int64 {
                $(storage)
                var __jian_position = 0
                while (let Some(__jian_arg) <- __jian_args.peek()) {
                    $(boundary)
                    __jian_args.next()
                    var __jian_name = ""
                    var __jian_attached: ?String = None
                    match (__jian_arg) {
                        case JianArg.Operand(__jian_operand) =>
                            $(operands)
                            throw JianUsageException("unexpected argument '${__jian_operand}'")
                        case JianArg.Long(__jian_long) => __jian_name = __jian_long
                        case JianArg.Long(__jian_long, __jian_raw) =>
                            __jian_name = __jian_long
                            __jian_attached = Some(__jian_raw)
                        case JianArg.Short(__jian_short) =>
                            $(shorts)
                            if (__jian_name.isEmpty()) {
                                throw JianUsageException.unknownOption("-" + String.fromUtf8([__jian_short]))
                            }
                        case JianArg.Short(__jian_short, __jian_raw) =>
                            $(shorts)
                            if (__jian_name.isEmpty()) {
                                throw JianUsageException.unknownOption("-" + String.fromUtf8([__jian_short]))
                            }
                            __jian_attached = Some(__jian_raw)
                    }
                    $(options)
                    throw JianUsageException.unknownOption("--" + __jian_name)
                }
                $(bindings)
                jianExitCode($(functionName)($(arguments)))
            }
        }
    )
}
