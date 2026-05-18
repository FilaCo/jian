macro package jian.macros

import std.ast.* // cjlint-ignore !G.PKG.01
public import jian.macros.type_anno.* // cjlint-ignore !G.PKG.01

public macro Callback(attrs: Tokens, input: Tokens): Tokens {
    input
}
