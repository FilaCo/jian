macro package jian.internal_macros

import std.ast.*

/**
 * Generates ArgValue with required scalar defaults and a help placeholder attribute.
 * Methods declared in the extension replace the defaults; the default accept uses Parsable.
 */
public macro ArgValueImpl(attrs: Tokens, input: Tokens): Tokens {
    let extension = ExtendDecl(input)
    if (!extension.superTypes.isEmpty()) {
        throw ASTException("ArgValueImpl expects an extension without supertypes")
    }
    let valueType = extension.extendType.toTokens()
    let expected = Token(TokenKind.STRING_LITERAL, valueType.toString())
    let defaults = ExtendDecl(quote(
        extend $(valueType) <: ArgValue<$(valueType)> {
            public static func takesValue(): Bool { true }
            public static func metavar(): String { $(attrs) }
            public static func accept(_: ?$(valueType), raw: ?String): $(valueType) {
                parseValue<$(valueType)>(raw, $(expected))
            }
            public static func whenAbsent(): ?$(valueType) { None }
        }
    ))
    extension.upperBound = defaults.upperBound
    extension.superTypes.add(defaults.superTypes[0])
    for (method in defaults.body.decls) {
        if (!extension.body.decls.any({decl => decl.identifier.value == method.identifier.value})) {
            extension.body.decls.add(method)
        }
    }
    extension.toTokens()
}
