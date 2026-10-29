macro package jian

import std.ast.*

/**
 * Preserves the function and generates a typed CLI adapter and registration overload.
 * An optional app registers the command; direct calls retain parameter defaults.
 * JianFromContext<C>() parameters are injected by type and remain required in direct calls.
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
    var contextType = Tokens()
    for (parameter in declaration.funcParams) {
        let injected = parameterSettings(parameter).contextType
        if (injected.size != 0) {
            if (contextType.size != 0 && contextType.toString().replace(" ", "") != injected.toString().replace(" ", "")) {
                throw ASTException("all JianFromContext parameters must use the same context type")
            }
            contextType = injected
        }
    }
    let interfaceToken = Token(TokenKind.IDENTIFIER, if (contextType.size == 0) { "Jian" + suffix }
        else { "JianContext" + suffix })
    let interfaceName = if (contextType.size == 0) { quote($(interfaceToken)) }
        else { quote($(interfaceToken)<$(contextType)>) }
    let contextArgument = if (contextType.size == 0) { Tokens() }
        else { quote(, __jian_context: $(contextType)) }
    let visibility = contextVisibility(declaration)
    let className = Token(TokenKind.IDENTIFIER, sourceName[0..1].toAsciiUpper() + sourceName[1..] + suffix)
    let implementation = Token(TokenKind.IDENTIFIER, "__jian_${suffix.toAsciiLower()}_${sourceName}")
    let name = Token(TokenKind.STRING_LITERAL, cliName(sourceName))
    var help = quote("")
    var app = Tokens()
    var usedSettings: Array<String> = []
    if (attrs.size != 0) {
        let settings = CallExpr(quote(__jian_settings($(attrs))))
        for (setting in settings.arguments) {
            let tokens = setting.toTokens()
            let named = tokens.size >= 2 && tokens[1].kind == TokenKind.COLON
            if (!named && !usedSettings.isEmpty() && !usedSettings.contains("app")) {
                throw ASTException("Jian${suffix} positional app must be the first setting")
            }
            let key = if (named) { setting.identifier.value } else { "app" }
            if (named && key == "app") {
                throw ASTException("Jian${suffix} app must be positional; use @Jian${suffix}[app]")
            }
            if (usedSettings.contains(key)) { throw ASTException("duplicate Jian${suffix} setting '${key}'") }
            usedSettings = usedSettings.concat([key])
            match (key) {
                case "help" => help = setting.expr.toTokens()
                case "app" => app = setting.expr.toTokens()
                case _ => throw ASTException("unknown Jian${suffix} setting '${key}'")
            }
        }
    }
    var specs = Tokens()
    var storage = Tokens()
    var options = Tokens()
    var operands = Tokens()
    var shorts = Tokens()
    var bindings = Tokens()
    var arguments = Tokens()
    var defaultHelpers = Tokens()
    var usedShorts = ""
    var positional = 0
    var names: Array<String> = []
    for (index in 0..declaration.funcParams.size) {
        let parameter = declaration.funcParams[index]
        let identifier = parameter.identifier
        let typeName = parameter.paramType.toTokens()
        let slot = Token(TokenKind.IDENTIFIER, "__jian_value_${index}")
        let settings = parameterSettings(parameter)
        if (settings.marker == "JianFromContext") {
            declaration.funcParams[index] = withoutDefault(parameter)
            bindings += quote(let $(identifier): $(typeName) = $(contextType).jianFromContext<$(typeName)>(__jian_context);)
            if (index > 0) { arguments += quote(,) }
            arguments += quote($(identifier): $(identifier))
            continue
        }
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
                declaration.funcParams[index] = withoutDefault(parameter)
            }
        }
        if (implicitNone && parameter.assign.kind != TokenKind.ASSIGN) {
            parameter.assign = Token(TokenKind.ASSIGN)
            parameter.expr = parseExpr(quote(None))
        }
        let label = if (named) { optionLabel } else { Token(TokenKind.STRING_LITERAL, cli.toAsciiUpper()) }
        let hasDefault = declaration.funcParams[index].assign.kind == TokenKind.ASSIGN
        let defaultName = Token(TokenKind.IDENTIFIER, "__jian_default_${sourceName}_${index}")
        let defaultArguments = earlierArguments(declaration, index)
        if (hasDefault) {
            let parameters = earlierParameters(declaration, index)
            let expression = declaration.funcParams[index].expr.toTokens()
            // Forward every earlier binding; mark even unused ones to avoid generated-code warnings.
            var keepBindings = Tokens()
            for (previous in 0..index) {
                keepBindings += quote(let _ = $(declaration.funcParams[previous].identifier);)
            }
            // Keep defaults outside the adapter's member scope, preserving globals such as name/spec.
            defaultHelpers += quote(private func $(defaultName)($(parameters)): $(typeName) {
                $(keepBindings)
                $(expression)
            };)
        }
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
            let text = sourceText(declaration.funcParams[index].expr.toTokens().toString())
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
        let absent = if (hasDefault) { quote($(defaultName)($(defaultArguments))) }
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
    let directDeclaration = FuncDecl(declaration.toTokens())
    // Resolve the function outside adapter members such as run/name/spec.
    declaration.block = FuncDecl(quote(func __jian_forward() { $(functionName)($(arguments)) })).block
    for (index in 0..declaration.funcParams.size) {
        if (declaration.funcParams[index].assign.kind == TokenKind.ASSIGN) {
            declaration.funcParams[index] = withoutDefault(declaration.funcParams[index])
        }
    }
    let tagToken = Token(TokenKind.IDENTIFIER, interfaceToken.value + "Tag")
    let tagType = if (contextType.size == 0) { quote($(tagToken)) }
        else { quote($(tagToken)<$(contextType)>) }
    declaration.identifier = implementation
    declaration.modifiers.clear()
    declaration.modifiers.add(Modifier(Token(TokenKind.PRIVATE)))
    let registration = if (app.size == 0) { Tokens() } else if (callback) {
        quote(let _ = ($(app)).callback($(functionName));)
    } else {
        quote(let _ = ($(app)).add($(functionName));)
    }
    // The required tag lets registration select an adapter without changing ordinary calls.
    directDeclaration.toTokens() + defaultHelpers + declaration.toTokens() + quote(
        $(visibility) func $(functionName)(_: $(tagType)): $(interfaceName) { $(className)() }

        $(visibility) class $(className) <: $(interfaceName) {
            $(commandName)
            public prop spec: JianCommandSpec { get() { JianCommandSpec(help: $(help), inputs: [$(specs)]) } }
            public func run(__jian_args: JianArgCursor $(contextArgument)): Int64 {
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
                jianExitCode($(implementation)($(arguments)))
            }
        }
    ) + registration
}

func earlierArguments(declaration: FuncDecl, end: Int64): Tokens {
    var result = Tokens()
    for (index in 0..end) {
        if (index > 0) { result += quote(,) }
        result += quote($(declaration.funcParams[index].identifier))
    }
    result
}

func earlierParameters(declaration: FuncDecl, end: Int64): Tokens {
    var result = Tokens()
    for (index in 0..end) {
        if (index > 0) { result += quote(,) }
        let parameter = declaration.funcParams[index]
        let typeName = parameter.paramType.toTokens()
        result += quote($(parameter.identifier): $(typeName))
    }
    result
}

func sourceText(value: String): Tokens {
    // Literal source text must not execute string interpolation when rendered in help metadata.
    var bytes = Tokens()
    for (byte in value.toArray()) {
        bytes += quote($(Token(TokenKind.INTEGER_LITERAL, byte.toString())),)
    }
    quote(String.fromUtf8([$(bytes)]))
}
