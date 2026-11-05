macro package jian

import std.ast.*

/**
 * `@JianDerive[JianArgValue]` implements JianArgValue for a nongeneric, exhaustive enum
 * with fieldless variants. Other interfaces are rejected.
 * Values use case-sensitive kebab-case names; no occurrence means required.
 */
public macro JianDerive(attrs: Tokens, input: Tokens): Tokens {
    if (attrs.size != 1 || attrs[0].kind != TokenKind.IDENTIFIER || attrs[0].value != "JianArgValue") {
        throw ASTException("@JianDerive requires exactly one supported interface: JianArgValue")
    }
    enumArgValue(input)
}

/**
 * Requires an explicit interface, as in `@JianDerive[JianArgValue]`.
 */
public macro JianDerive(input: Tokens): Tokens {
    throw ASTException("@JianDerive requires exactly one supported interface: JianArgValue")
}

func enumArgValue(input: Tokens): Tokens {
    let declaration = match (parseDecl(input) as EnumDecl) {
        case Some(value) => value
        case None => throw ASTException("@JianDerive[JianArgValue] requires an enum")
    }
    if (declaration.isGenericDecl) {
        throw ASTException("@JianDerive[JianArgValue] requires a nongeneric enum")
    }
    if (declaration.ellipsis.kind == TokenKind.ELLIPSIS) {
        throw ASTException("@JianDerive[JianArgValue] does not support non-exhaustive enums")
    }
    for (superType in declaration.superTypes) {
        if (let Some(reference) <- (superType as RefType)) {
            if (reference.identifier.value == "JianArgValue") {
                throw ASTException("@JianDerive[JianArgValue] conflicts with an explicit JianArgValue implementation")
            }
        }
    }
    let name = declaration.identifier
    var spellings: Array<String> = []
    var cases = Tokens()
    for (variant in declaration.constructors) {
        if (!variant.typeArguments.isEmpty()) {
            throw ASTException("@JianDerive[JianArgValue] requires variants without associated values")
        }
        let constructor = variant.identifier
        let spelling = cliName(constructor.value.replace("`", ""))
        if (spellings.contains(spelling)) {
            throw ASTException("duplicate enum CLI spelling '${spelling}'")
        }
        spellings = spellings.concat([spelling])
        let literal = Token(TokenKind.STRING_LITERAL, spelling)
        cases += quote(case $(literal) => $(name).$(constructor))
    }
    let metavar = Token(TokenKind.STRING_LITERAL, cliName(name.value.replace("`", "")).toAsciiUpper())
    let expected = Token(TokenKind.STRING_LITERAL, String.join(spellings, delimiter: " or "))
    // An extension keeps the original declaration and any unrelated interfaces intact.
    input + quote(
        extend $(name) <: JianArgValue<$(name)> {
            public static func takesValue(): Bool { true }
            public static func metavar(): String { $(metavar) }
            public static func whenAbsent(): ?$(name) { None }
            public static func accept(_: ?$(name), raw: ?String): $(name) {
                let text = raw ?? throw JianUsageException("missing argument value")
                match (text) {
                    $(cases)
                    case _ => throw JianInvalidValueException(text, $(expected))
                }
            }
        }
    )
}
