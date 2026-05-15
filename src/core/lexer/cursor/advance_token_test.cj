protected package jian.core.lexer.cursor

import std.collection.*
import std.unittest.*
import std.unittest.testmacro.*

@Test
class AdvanceTokenTest {
    @TestCase
    func itWorks() {
        // arrange
        let input = "cjpm init --name jian"
        let expected = [CursorToken(Value, 4), CursorToken(WS, 1), CursorToken(Value, 4), CursorToken(WS, 1),
            CursorToken(DoubleDashed, 6), CursorToken(WS, 1), CursorToken(Value, 4)]

        // act
        let actual = Cursor.tokenize(input) |> collectArray

        // assert
        @PowerAssert(expected == actual)
    }
}
