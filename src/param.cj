macro package jian

import std.ast.*

/**
 * Supplies `short`, `help` and `hidden` metadata for a command or callback parameter.
 * `short` is a single ASCII character literal on a named parameter; `h` is reserved.
 * Apply one marker per parameter. Hidden parameters remain accepted by the parser.
 */
public macro Param(attrs: Tokens, input: Tokens): Tokens {
    paramMetadata(attrs, input)
}

/** Attribute-free parameter marker. */
public macro Param(input: Tokens): Tokens {
    paramMetadata(Tokens(), input)
}

func paramMetadata(attrs: Tokens, input: Tokens): Tokens {
    if (!insideParentContext("Callback")) {
        assertParentContext("Command")
    }
    if (insideParentContext("Param")) {
        throw ASTException("apply @Param only once per parameter")
    }
    let parameter = FuncParam(input)
    setItem("param", parameter.identifier.value)
    if (attrs.size != 0) {
        let settings = CallExpr(quote(__jian_settings($(attrs))))
        var seen = ""
        for (setting in settings.arguments) {
            let tokens = setting.toTokens()
            if (tokens.size < 2 || tokens[1].kind != TokenKind.COLON) {
                throw ASTException("@Param settings must be named: short, help, hidden")
            }
            let key = setting.identifier.value
            if (key != "short" && key != "help" && key != "hidden") {
                throw ASTException("unknown Param setting '${key}'")
            }
            if (seen.contains("," + key + ",")) {
                throw ASTException("duplicate Param setting '${key}'")
            }
            seen += "," + key + ","
            setItem(key, setting.expr.toTokens())
        }
    }
    input
}
