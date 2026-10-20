package jian.runtime

import std.collection.collectArray

@Test
class LexerTest {
    @TestCase[input in [
(
 [ "cjpm", "init", "--name", "jian", "--type=dynamic" ],
 [ Token.Operand("cjpm"), Token.Operand("init"), Token.Long("name"), Token.Operand("jian"), Token.Long("type", "dynamic") ]
),

(
 [ "cjc", "-", "--output-type=exe", "--output-dir", "whatever" ],
 [ Token.Operand("cjc"), Token.Operand("-"), Token.Long("output-type", "exe"), Token.Long("output-dir"), Token.Operand("whatever") ]
),

(
 [ "cjdev", "exec", "--", "ls", "-la" ],
 [ Token.Operand("cjdev"), Token.Operand("exec") ]
),

(
 [ "-abc", "-n=3", "--name=", "-", "file" ],
 [ Token.Short("abc"), Token.Short("n", "3"), Token.Long("name", ""), Token.Operand("-"), Token.Operand("file") ]
),
 ]]
    func itWorks(input: (Array<String>, Array<Token>)) {
        // arrange
        let (argv, expected) = input

        // act
        let actual = Lexer.make(argv) |> collectArray

        // assert
        @PowerAssert(expected == actual)
    }

    @TestCase[input in [
(
 [ ],
 [ ]
),
(
 [ "no", "escape", "arg" ],
 [ ]
),
(
 [ "escape", "arg", "in", "the", "end", "--" ],
 [ ]
),
(
 [ "cargo", "run", "--", "-h" ],
 [ "-h" ]
),
(
 [ "--" ],
 [  ]
),
(
 [ "--", "--", "--" ],
 [ "--", "--" ]
),
 ]]
    func remainderWorks(input: (Array<String>, Array<String>)) {
        // arrange
        let (argv, expectedRemainder) = input
        let sut = Lexer.make(argv)

        // act
        let _ = sut |> collectArray
        let actualRemainder = sut.remainder()

        // assert
        @PowerAssert(expectedRemainder, actualRemainder)
    }

    @TestCase
    func bumpWorks() {
        // arrange
        let input = ["cjdev", "build", "-t", "debug", "cjc", "--", "whatever", "else"]
        let expected = [Token.Operand("cjdev"), Token.Operand("build"), Token.Short("t"), Token.Operand("debug"), Token.Operand("cjc")]
        let sut = Lexer.make(input)

        // act
        var pos = 0
        while (!sut.isAtEoi()) {
            if (sut.peek() == Token.Eoi) {
                break
            }
            @Expect(input[pos..], sut.remainder())
            let actual = sut.bump()
            @Expect(expected[pos], actual)
            pos++
        }

        // assert
        @Expect(["whatever", "else"], sut.remainder())
    }
}
