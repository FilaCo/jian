macro package jian

import std.ast.*

class ParameterSettings {
    var marker = ""
    var contextType = Tokens()
    var defaultValue: ?Tokens = None
    var short: ?Tokens = None
    var help = quote("")
    var hidden = quote(false)
}

func parameterSettings(parameter: FuncParam): ParameterSettings {
    let settings = ParameterSettings()
    if (parameter.assign.kind != TokenKind.ASSIGN) { return settings }
    let call = match (parameter.expr as CallExpr) {
        case Some(value) => value
        case None => return settings
    }
    let reference = match (call.callFunc as RefExpr) {
        case Some(value) => value
        case None => return settings
    }
    let marker = reference.identifier.value
    if (marker == "JianCurrentInvocation") {
        if (!reference.typeArguments.isEmpty() || !call.arguments.isEmpty()) {
            throw ASTException("JianCurrentInvocation takes no type arguments or arguments")
        }
        if (parameter.not.kind != TokenKind.NOT) {
            throw ASTException("JianCurrentInvocation requires a named function parameter")
        }
        settings.marker = marker
        return settings
    }
    if (marker == "JianFromContext") {
        if (reference.typeArguments.size != 1 || !call.arguments.isEmpty()) {
            throw ASTException("JianFromContext requires one context type and no arguments")
        }
        if (parameter.not.kind != TokenKind.NOT) {
            throw ASTException("JianFromContext requires a named function parameter")
        }
        settings.marker = marker
        settings.contextType = reference.typeArguments[0].toTokens()
        return settings
    }
    if (marker != "JianOption" && marker != "JianArgument") { return settings }
    if (!reference.typeArguments.isEmpty()) {
        throw ASTException("${marker} takes its type from the function parameter declaration")
    }
    settings.marker = marker
    var seen = ""
    for (argument in call.arguments) {
        let tokens = argument.toTokens()
        if (tokens.size < 2 || tokens[1].kind != TokenKind.COLON) {
            throw ASTException("${marker} settings must be named")
        }
        let key = argument.identifier.value
        if (!["default", "help", "hidden"].contains(key) && !(marker == "JianOption" && key == "short")) {
            throw ASTException("unknown ${marker} setting '${key}'")
        }
        if (seen.contains("," + key + ",")) {
            throw ASTException("duplicate ${marker} setting '${key}'")
        }
        seen += "," + key + ","
        let value = argument.expr.toTokens()
        match (key) {
            case "default" => settings.defaultValue = Some(value)
            case "short" => settings.short = Some(value)
            case "help" => settings.help = value
            case "hidden" => settings.hidden = value
            case _ => ()
        }
    }
    settings
}

func isNamedCLI(parameter: FuncParam): Bool {
    let marker = parameterSettings(parameter).marker
    marker == "JianFromContext" || marker == "JianCurrentInvocation" || parameter.not.kind == TokenKind.NOT && marker != "JianArgument"
}

func withoutDefault(parameter: FuncParam): FuncParam {
    let original = parameter.toTokens()
    var plain = Tokens()
    for (token in original) {
        if (token.kind == TokenKind.ASSIGN) { break }
        plain.append(token)
    }
    if (original[original.size - 1].kind == TokenKind.COMMA) {
        plain.append(original[original.size - 1])
    }
    FuncParam(plain)
}

// Macros run before type resolution, so aliases cannot be classified here.
func isOptionalSpelling(typeNode: TypeNode): Bool {
    if (typeNode is PrefixType) { return true }
    if (let Some(reference) <- (typeNode as RefType)) {
        return reference.identifier.value == "Option" && reference.typeArguments.size == 1
    }
    if (let Some(parenthesized) <- (typeNode as ParenType)) {
        return isOptionalSpelling(parenthesized.parenthesizedType)
    }
    false
}
