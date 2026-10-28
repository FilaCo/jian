macro package jian

import std.ast.*

/**
 * Makes each explicitly typed instance field, and the context itself, injectable by type.
 * Applies to nongeneric classes. Duplicate field types require distinct wrapper types.
 */
public macro JianContext(input: Tokens): Tokens {
    let node = parseDecl(input)
    let declaration = match (node as ClassDecl) {
        case Some(value) => value
        case None => throw ASTException("@JianContext requires a class")
    }
    if (declaration.isGenericDecl) {
        throw ASTException("@JianContext requires a nongeneric class")
    }
    let context = declaration.identifier
    let contract = Token(TokenKind.IDENTIFIER, "From" + context.value.replace("`", ""))
    let visibility = contextVisibility(declaration)
    var extensions = quote(
        extend $(context) <: $(contract)<$(context)> {
            public static func fromContext(context: $(context)): $(context) { context }
        }
    )
    var types: Array<String> = [context.value.replace("`", "")]
    // Snapshot the members because generated accessors are appended to the class body.
    let members = declaration.body.decls.toArray()
    for (member in members) {
        if (member.modifiers.toArray().any({ modifier => modifier.keyword.kind == TokenKind.STATIC })) {
            continue
        }
        if (let Some(field) <- (member as VarDecl)) {
            if (field.colon.kind != TokenKind.COLON) {
                throw ASTException("@JianContext fields require explicit types")
            }
            extensions += contextField(declaration, contract, field.identifier, field.declType.toTokens(), types)
            types = types.concat([field.declType.toTokens().toString().replace(" ", "")])
        } else if (let Some(constructor) <- (member as PrimaryCtorDecl)) {
            for (parameter in constructor.funcParams) {
                if (parameter.isMemberParam()) {
                    extensions += contextField(declaration, contract, parameter.identifier, parameter.paramType.toTokens(), types)
                    types = types.concat([parameter.paramType.toTokens().toString().replace(" ", "")])
                }
            }
        }
    }
    declaration.body.decls.add(parseDecl(quote(
        public static func jianFromContext<T>(context: $(context)): T where T <: $(contract)<T> {
            T.fromContext(context)
        }
    )))
    quote(
        $(visibility) interface $(contract)<T> {
            static func fromContext(context: $(context)): T
        }
    ) + declaration.toTokens() + extensions
}

func contextVisibility(declaration: Decl): Tokens {
    for (modifier in declaration.modifiers) {
        match (modifier.keyword.kind) {
            case TokenKind.PUBLIC | TokenKind.PRIVATE | TokenKind.PROTECTED | TokenKind.INTERNAL =>
                return quote($(modifier.keyword))
            case _ => ()
        }
    }
    Tokens()
}

func contextField(declaration: ClassDecl, contract: Token, field: Token, fieldType: Tokens,
    types: Array<String>): Tokens {
    let spelling = fieldType.toString().replace(" ", "")
    if (types.contains(spelling)) {
        throw ASTException("duplicate context field type '${spelling}'; use distinct wrapper types")
    }
    let context = declaration.identifier
    let accessor = Token(TokenKind.IDENTIFIER, "__jian_context_${types.size}")
    // Access stays inside the class so private fields work without changing their visibility.
    declaration.body.decls.add(parseDecl(quote(
        static func $(accessor)(context: $(context)): $(fieldType) { context.$(field) }
    )))
    quote(
        extend $(fieldType) <: $(contract)<$(fieldType)> {
            public static func fromContext(context: $(context)): $(fieldType) {
                $(context).$(accessor)(context)
            }
        }
    )
}
