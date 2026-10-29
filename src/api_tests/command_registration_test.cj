package jian.api_tests

import jian.*
import jian.api_tests.exported.{exportedCreate, exportedConfigure}
import std.unittest.*
import std.unittest.testmacro.*

private let name = "global-name"
private let spec = "global-spec"
private let run = "global-run"

private let forwardApp = JianApp().add(forwardCommand)
private let forwardResult = forwardCommand()

@JianCommand
func forwardCommand(value!: Int64 = 3): Int64 { value }

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
    if (value == 0) { 0 } else { 1 + recursiveValue(value - 1) }
}

@Test
class CommandRegistrationTest {
    @TestCase
    func importedFunctionsKeepEveryCombinationOfDefaultsAndRegisterByExpectedType() {
        // arrange
        let app = JianApp().callback(exportedConfigure).add(exportedCreate)
        let action: (Int64, Int64, Int64) -> Int64 = exportedCreate

        // act
        let defaulted = app.run(["exported-create"])
        let overridden = app.run(["exported-create", "--second=10"])
        let stopped = app.run(["--stop=7", "exported-create"])

        // assert
        @Expect(exportedCreate(), 11)
        @Expect(exportedCreate(first: 2), 14)
        @Expect(exportedCreate(second: 10), 25)
        @Expect(exportedCreate(third: 20), 24)
        @Expect(exportedCreate(first: 2, second: 10), 26)
        @Expect(exportedCreate(first: 2, third: 20), 26)
        @Expect(exportedCreate(second: 10, third: 20), 31)
        @Expect(exportedCreate(first: 2, second: 10, third: 20), 32)
        @Expect(action(2, 10, 20), 32)
        @Expect(defaulted, 11)
        @Expect(overridden, 25)
        @Expect(stopped, 7)
    }

    @TestCase
    func contextAppsSelectImportedFunctionsThatIgnoreTheirContext() {
        // arrange
        let app = JianContextApp<Int64>().callback(exportedConfigure).add(exportedCreate)

        // act
        let code = app.run(["exported-create", "--third=20"], context: 42)
        let stopped = app.run(["--stop=7", "exported-create"], context: 42)

        // assert
        @Expect(code, 24)
        @Expect(stopped, 7)
    }

    @TestCase
    func detachedCommandsAndCallbacksCanBeAttachedToIndependentApps() {
        // arrange
        let first = JianApp().callback(detachedSettings).add(detached)
        let second = JianApp().add(detached)
        let action: (Int64, Int64) -> Int64 = detached

        // act
        let stopped = first.run(["--stop=7", "detached", "2"])
        let defaulted = first.run(["detached", "2"])
        let explicit = second.run(["detached", "2", "--amount=3"])

        // assert
        @Expect(stopped, 7)
        @Expect(defaulted, 6)
        @Expect(explicit, 5)
        @Expect(detached(2), 6)
        @Expect(action(2, 3), 5)
        @Expect(detachedSettings(), 0)
        @Expect(forwardApp.run(["forward-command"]), 3)
        @Expect(forwardResult, 3)
    }

    @TestCase
    func defaultsAndBodiesKeepTheirOriginalGlobalBindings() {
        // arrange
        let app = JianApp().add(lexicalDefault)

        // act
        let direct = lexicalDefault("Alice")
        let cli = app.run(["lexical-default", "Alice"])
        let overridden = lexicalDefault("Alice", text: "other")

        // assert
        @Expect(direct, 9)
        @Expect(cli, 9)
        @Expect(overridden, 1)
        @Expect((LexicalDefaultCommand().spec.inputs[1].defaultShown ?? "").contains("first"), true)
    }

    @TestCase
    func functionsCanRecurseBeforeTheirRegistrationOverload() {
        // arrange
        let app = JianApp().add(recursiveValue)

        // act
        let direct = recursiveValue(3)
        let cli = app.run(["recursive-value", "4"])

        // assert
        @Expect(direct, 3)
        @Expect(cli, 4)
    }
}
