macro package jian.runtime.macros

import std.ast.*
import std.collection.ArrayList

/**
 * Generates extensions from rows of (type, metavar, takesValue, whenAbsent, accept).
 * The accept expression can use `raw`.
 */
public macro ArgValues(input: Tokens): Tokens {
    argValues(input, quote(extend), Tokens(), quote(_))
}

/**
 * Generates container extensions with a type parameter constrained to ArgValue.
 * The accept expression can also use `prev` to accumulate occurrences.
 */
public macro ArgValues(attrs: Tokens, input: Tokens): Tokens {
    argValues(input, quote(extend<$(attrs)>), quote(where $(attrs) <: ArgValue<$(attrs)>), quote(prev))
}

func argValues(input: Tokens, header: Tokens, constraint: Tokens, previous: Tokens): Tokens {
    var output = Tokens()
    var position = 0
    while (position < input.size) {
        if (input[position].kind == TokenKind.NL || input[position].kind == TokenKind.COMMA) {
            position++
            continue
        }
        if (input[position].kind != TokenKind.LPAREN) {
            throw ASTException("ArgValues expects rows of (type, metavar, takesValue, whenAbsent, accept)")
        }
        let (typeNode, typeEnd) = parseTypeFragment(input, startFrom: position + 1)
        let valueType = typeNode.toTokens()
        position = typeEnd
        let values = ArrayList<Expr>()
        // Parse the type separately: primitive type names are not tuple value expressions.
        for (_ in 0..4) {
            if (input[position].kind != TokenKind.COMMA) {
                throw ASTException("ArgValues expects five columns per row")
            }
            let (expression, end) = parseExprFragment(input, startFrom: position + 1)
            values.add(expression)
            position = end
        }
        if (input[position].kind != TokenKind.RPAREN) {
            throw ASTException("ArgValues expects five columns per row")
        }
        position++
        output = output + quote(
            $(header) $(valueType) <: ArgValue<$(valueType)> $(constraint) {
                public static func metavar(): String { $(values[0]) }
                public static func takesValue(): Bool { $(values[1]) }
                public static func whenAbsent(): ?$(valueType) { $(values[2]) }
                public static func accept($(previous): ?$(valueType), raw: ?String): $(valueType) {
                    $(values[3])
                }
            }
        )
    }
    output
}
