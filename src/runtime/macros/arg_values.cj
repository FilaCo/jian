macro package jian.runtime.macros

import std.ast.*
import std.collection.HashMap

/**
 * Generates JianArgValue extensions from `value<Types...>(metavar: ..., accept: ...)` entries.
 * Defaults: takesValue is true, whenAbsent is None, accept uses Parsable, metavar is empty.
 * The accept expression can use `raw`; a group shares its settings across all listed types.
 */
public macro JianArgValues(input: Tokens): Tokens {
    argValues(input, quote(extend), Tokens(), quote(_))
}

/**
 * Generates container extensions with a type parameter constrained to JianArgValue.
 * The accept expression can also use `prev` to accumulate occurrences.
 */
public macro JianArgValues(attrs: Tokens, input: Tokens): Tokens {
    argValues(input, quote(extend<$(attrs)>), quote(where $(attrs) <: JianArgValue<$(attrs)>), quote(prev))
}

func argValues(input: Tokens, header: Tokens, constraint: Tokens, previous: Tokens): Tokens {
    var output = Tokens()
    var position = 0
    while (position < input.size) {
        if (input[position].kind == TokenKind.NL || input[position].kind == TokenKind.COMMA) {
            position++
            continue
        }
        let (expression, end) = parseExprFragment(input, startFrom: position)
        position = end
        let entry = CallExpr(expression.toTokens())
        let types = RefExpr(entry.callFunc.toTokens())
        if (types.identifier.value != "value" || types.typeArguments.isEmpty()) {
            throw ASTException("JianArgValues expects value<Types...>(named settings)")
        }
        let settings = HashMap<String, Tokens>()
        for (argument in entry.arguments) {
            let name = argument.identifier.value
            if (!["metavar", "takesValue", "whenAbsent", "accept"].contains(name)) {
                throw ASTException("unknown JianArgValues setting '${name}'")
            }
            if (settings.contains(name)) {
                throw ASTException("duplicate JianArgValues setting '${name}'")
            }
            settings.add(name, argument.expr.toTokens())
        }
        let metavar = settings.get("metavar") ?? quote("")
        let takesValue = settings.get("takesValue") ?? quote(true)
        let whenAbsent = settings.get("whenAbsent") ?? quote(None)
        for (typeNode in types.typeArguments) {
            let valueType = typeNode.toTokens()
            let expected = Token(TokenKind.STRING_LITERAL, valueType.toString())
            let accept = settings.get("accept") ?? quote(parseValue<$(valueType)>(raw, $(expected)))
            output = output + quote(
                $(header) $(valueType) <: JianArgValue<$(valueType)> $(constraint) {
                    public static func metavar(): String { $(metavar) }
                    public static func takesValue(): Bool { $(takesValue) }
                    public static func whenAbsent(): ?$(valueType) { $(whenAbsent) }
                    public static func accept($(previous): ?$(valueType), raw: ?String): $(valueType) {
                        $(accept)
                    }
                }
            )
        }
    }
    output
}
