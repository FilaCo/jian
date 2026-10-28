macro package jian

import std.ast.*

class ParameterSettings {
    var marker = ""
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
    if (marker != "Option" && marker != "Argument") { return settings }
    if (!reference.typeArguments.isEmpty()) {
        throw ASTException("${marker} takes its type from the parameter declaration")
    }
    settings.marker = marker
    var seen = ""
    for (argument in call.arguments) {
        let tokens = argument.toTokens()
        if (tokens.size < 2 || tokens[1].kind != TokenKind.COLON) {
            throw ASTException("${marker} settings must be named")
        }
        let key = argument.identifier.value
        if (!["default", "help", "hidden"].contains(key) && !(marker == "Option" && key == "short")) {
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
    parameter.not.kind == TokenKind.NOT && parameterSettings(parameter).marker != "Argument"
}
