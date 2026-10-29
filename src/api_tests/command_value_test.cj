package jian.api_tests

import jian.*
import std.unittest.*
import std.unittest.testmacro.*

private let name = "global-name"
private let spec = "global-spec"
private let run = "global-run"

@JianCommand
func detached(value: Int64, amount!: Int64 = 4): Int64 { value + amount }

@JianCallback
func detachedSettings(stop!: Int64 = 0): Int64 { stop }

@JianCommand
func lexicalDefault(first: String,
    text!: String = "${name}:${spec}:${run}:${first}"): Int64 {
    if (text == "${name}:${spec}:${run}:${first}") { 9 } else { 1 }
}

@JianCommand
func recursiveValue(value: Int64): Int64 {
    if (value == 0) { 0 } else { 1 + recursiveValue.call(value - 1) }
}

@Test
class CommandValueTest {
    @TestCase
    func detachedCommandsAndCallbacksCanBeAttachedToIndependentApps() {
        // arrange
        let first = JianApp().callback(detachedSettings).add(detached)
        let second = JianApp().add(detached)
        let action: (Int64, Int64) -> Int64 = detached.call

        // act
        let stopped = first.run(["--stop=7", "detached", "2"])
        let defaulted = first.run(["detached", "2"])
        let explicit = second.run(["detached", "2", "--amount=3"])

        // assert
        @Expect(stopped, 7)
        @Expect(defaulted, 6)
        @Expect(explicit, 5)
        @Expect(detached.call(2), 6)
        @Expect(action(2, 3), 5)
        @Expect(detachedSettings.call(), 0)
    }

    @TestCase
    func defaultsAndBodiesKeepTheirOriginalGlobalBindings() {
        // arrange
        let app = JianApp().add(lexicalDefault)

        // act
        let direct = lexicalDefault.call("Alice")
        let cli = app.run(["lexical-default", "Alice"])
        let overridden = lexicalDefault.call("Alice", text: "other")

        // assert
        @Expect(direct, 9)
        @Expect(cli, 9)
        @Expect(overridden, 1)
        @Expect((lexicalDefault.spec.inputs[1].defaultShown ?? "").contains("first"), true)
    }

    @TestCase
    func commandValuesAreAvailableInsideTheirOwnBodies() {
        // arrange
        let app = JianApp().add(recursiveValue)

        // act
        let direct = recursiveValue.call(3)
        let cli = app.run(["recursive-value", "4"])

        // assert
        @Expect(direct, 3)
        @Expect(cli, 4)
    }
}
