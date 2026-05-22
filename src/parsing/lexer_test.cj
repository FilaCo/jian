protected package jian.parsing

import std.collection.collectArray

@Test
class LexerTest {
    @TestCase[input in [ 
(
 [ "cjpm", "init", "--name", "jian", "--type=dynamic" ], 
 [ Value("cjpm"), Value("init"), DoubleDashed("name"), Value("jian"), DoubleDashed("type", "dynamic") ] 
), 
 
(
 [ "cjc", "-", "--output-type=exe", "--output-dir", "whatever" ], 
 [ Value("cjc"), StdinPlaceholder, DoubleDashed("output-type", "exe"), DoubleDashed("output-dir"), Value("whatever") ] 
), 
 
(
 [ "cjdev", "exec", "--", "ls", "-la" ], 
 [ Value("cjdev"), Value("exec") ] 
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
        let actual = sut |> collectArray
        let actualRemainder = sut.remainder()

        // assert
        @PowerAssert(expectedRemainder, actualRemainder)
    }

    @TestCase
    func bumpWorks() {
        // arrange
        let input = ["cjdev", "build", "-t", "debug", "cjc", "--", "whatever", "else"]
        let expected = [Value("cjdev"), Value("build"), Dashed("t"), Value("debug"), Value("cjc")]
        let sut = Lexer.make(input)

        // act
        var pos = 0
        while (!sut.isAtEoi()) {
            if (sut.peek() == Eoi) {
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
