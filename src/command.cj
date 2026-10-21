macro package jian

import std.ast.*

/** Generates a typed CLI adapter beside the unchanged command function. */
public macro Command(attrs: Tokens, input: Tokens): Tokens {
    commandAdapter(attrs, input)
}

/** Attribute-free form of `@Command`. */
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

func commandAdapter(attrs: Tokens, input: Tokens): Tokens {
    let declaration = FuncDecl(input)
    let functionName = declaration.identifier
    let sourceName = functionName.value.replace("`", "")
    let className = Token(TokenKind.IDENTIFIER, sourceName[0..1].toAsciiUpper() + sourceName[1..] + "Command")
    let name = Token(TokenKind.STRING_LITERAL, cliName(sourceName))
    var help = quote("")
    if (attrs.size != 0) {
        let settings = CallExpr(quote(__jian_settings($(attrs))))
        for (setting in settings.arguments) {
            if (setting.identifier.value != "help") {
                throw ASTException("unknown Command setting '${setting.identifier.value}'")
            }
            help = setting.expr.toTokens()
        }
    }
    var specs = Tokens()
    var storage = Tokens()
    var options = Tokens()
    var operands = Tokens()
    var bindings = Tokens()
    var arguments = Tokens()
    var positional = 0
    for (index in 0..declaration.funcParams.size) {
        let parameter = declaration.funcParams[index]
        let identifier = parameter.identifier
        let typeName = parameter.paramType.toTokens()
        let slot = Token(TokenKind.IDENTIFIER, "__jian_value_${index}")
        let cli = cliName(identifier.value.replace("`", ""))
        let cliLiteral = Token(TokenKind.STRING_LITERAL, cli)
        let optionLabel = Token(TokenKind.STRING_LITERAL, "--" + cli)
        let named = parameter.not.kind == TokenKind.NOT
        let label = if (named) { optionLabel } else { Token(TokenKind.STRING_LITERAL, cli.toAsciiUpper()) }
        let hasDefault = parameter.assign.kind == TokenKind.ASSIGN
        let repeated = typeName.toString().replace(" ", "").startsWith("Array<")
        let repeatable = if (repeated) { quote(true) } else { quote(false) }
        let kind = if (named) {
            quote(if (takesValueAs<$(typeName)>()) { ParamKind.ValueOption } else { ParamKind.Flag })
        } else { quote(ParamKind.Positional) }
        let shown = if (hasDefault) {
            let text = Token(TokenKind.STRING_LITERAL, parameter.expr.toTokens().toString())
            quote(Some($(text)))
        } else { quote(None) }
        let required = if (hasDefault) { quote(false) } else { quote(whenAbsentAs<$(typeName)>().isNone()) }
        specs += quote(ParamSpec($(cliLiteral), kind: $(kind), metavar: metavarAs<$(typeName)>(),
            defaultShown: $(shown), required: $(required), repeatable: $(repeatable)),)
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
            operands += quote(
                if (__jian_position == $(ordinal)) {
                    try {
                        $(slot) = Some(acceptAs<$(typeName)>($(slot), Some(__jian_operand)))
                    } catch (__jian_error: InvalidValueException) {
                        throw UsageException.invalidValue($(label), __jian_error.raw, __jian_error.expected)
                    }
                    __jian_position++
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
    input + quote(
        public class $(className) <: Command {
            public prop name: String { get() { $(name) } }
            public prop spec: CommandSpec { get() { CommandSpec(help: $(help), params: [$(specs)]) } }
            public func run(__jian_args: ArgCursor): Int64 {
                $(storage)
                var __jian_position = 0
                while (let Some(__jian_arg) <- __jian_args.next()) {
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
                            throw UsageException.unknownOption("-" + String.fromUtf8([__jian_short]))
                        case Arg.Short(__jian_short, _) =>
                            throw UsageException.unknownOption("-" + String.fromUtf8([__jian_short]))
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
