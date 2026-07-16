macro package jian.macros

import std.ast.* // cjlint-ignore !G.PKG.01

/**
 * @Command macro — generates a Command registration function from a function declaration.
 *
 * Usage:
 * ```
 * @Command
 * func greet(name: String, greeting: String) {
 *     println("Hello, ${name}, ${greeting}!")
 * }
 *
 * // Generates:
 * //   func __greet_impl(name: String, greeting: String) { ... }
 * //   func greet_cmd(): Command { ... }
 * ```
 *
 * The generated greet_cmd() function returns a Command that can be added to an App.
 * All function parameters become positional command parameters.
 */
public macro Command(input: Tokens): Tokens {
    let funcDecl = FuncDecl(input)
    let funcName = funcDecl.identifier.value
    let bodyStr = funcDecl.block.toTokens().toString()

    // collect parameter names and types
    let paramNames = ArrayList<String>()
    let paramTypes = ArrayList<String>()
    for (param in funcDecl.funcParams) {
        paramNames.add(param.identifier.value)
        paramTypes.add(param.paramType.toTokens().toString())
    }

    // build impl params
    let implParams = ArrayList<String>()
    var i = 0
    while (i < paramNames.size) {
        implParams.add("${paramNames[i]}: ${paramTypes[i]}")
        i = i + 1
    }
    let implParamsStr = joinStrings(implParams, ", ")

    // build param builder calls
    let builderCalls = ArrayList<String>()
    i = 0
    while (i < paramNames.size) {
        builderCalls.add("builder.add(Param.builder(\"${paramNames[i]}\").build())")
        i = i + 1
    }
    let builderCallsStr = joinStrings(builderCalls, "\n        ")

    // build arg extraction and call args
    let argExtracts = ArrayList<String>()
    let callArgs = ArrayList<String>()
    i = 0
    while (i < paramNames.size) {
        let typeStr = paramTypes[i]
        if (typeStr == "String") {
            argExtracts.add("let ${paramNames[i]} = args.getRaw(\"${paramNames[i]}\").getOrThrow()")
        } else {
            argExtracts.add("let ${paramNames[i]} = args.get<${typeStr}>(\"${paramNames[i]}\")")
        }
        callArgs.add(paramNames[i])
        i = i + 1
    }
    let argExtractsStr = joinStrings(argExtracts, "\n        ")
    let callArgsStr = joinStrings(callArgs, ", ")

    // build the output code
    let output = "func __${funcName}_impl(${implParamsStr}) ${bodyStr}\n" +
                 "\n" +
                 "func ${funcName}_cmd(): Command {\n" +
                 "    let builder = Command.builder(\"${funcName}\")\n" +
                 "    ${builderCallsStr}\n" +
                 "    builder.invoke({ args =>\n" +
                 "        ${argExtractsStr}\n" +
                 "        __${funcName}_impl(${callArgsStr})\n" +
                 "    })\n" +
                 "    return (builder.build() as Command).getOrThrow()\n" +
                 "}"

    cangjieLex(output)
}