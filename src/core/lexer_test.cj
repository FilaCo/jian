protected package jian.core

import std.collection.collectArray
import std.unittest.*
import std.unittest.testmacro.*

@Test
class LexerTest {
    @TestCase[input in [ 
(
 [ "cjpm", "init", "--name", "jian", "--type=dynamic" ], 
 [ Value("cjpm"), Value("init"), DoubleDashed("--name"), Value("jian"), DoubleDashed("--type", "dynamic") ] 
), 
 
(
 [ "cjc", "-", "--output-type=exe", "--output-dir", "whatever" ], 
 [ Value("cjc"), StdinPlaceholder, DoubleDashed("--output-type", "exe"), DoubleDashed("--output-dir"), Value("whatever") ] 
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
}
