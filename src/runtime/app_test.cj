package jian.runtime

import std.collection.ArrayList
import std.io.ByteBuffer

private class TestCommand <: JianCommand {
    private let commandName: String
    public prop name: String { get() { commandName } }
    private let commandSpec: JianCommandSpec
    public prop spec: JianCommandSpec { get() { commandSpec } }
    private let action: (JianArgCursor) -> Int64

    public init(name: String, action: (JianArgCursor) -> Int64, spec!: JianCommandSpec = JianCommandSpec()) {
        this.commandName = name
        this.action = action
        this.commandSpec = spec
    }

    public func run(args: JianArgCursor): Int64 { action(args) }
}

private class TestCallback <: JianCallback {
    private let commandSpec: JianCommandSpec
    public prop spec: JianCommandSpec { get() { commandSpec } }
    private let action: (JianArgCursor) -> JianCallbackResult

    public init(action: (JianArgCursor) -> JianCallbackResult, spec!: JianCommandSpec = JianCommandSpec()) {
        this.action = action
        this.commandSpec = spec
    }

    public func run(args: JianArgCursor): JianCallbackResult { action(args) }
}

@Test
class AppTest {
    @TestCase
    func dispatchUsesTheRegisteredNameAndPreservesCommandArguments() {
        // arrange
        let received = ArrayList<String>()
        let app = JianApp(name: "demo").add(TestCommand("sync", { args =>
            received.add(all: args.remaining())
            7
        }))

        // act
        let code = app.run(["sync", "--", "-file"])

        // assert
        @Expect(code, 7)
        @Expect(received.toArray(), ["--", "-file"])
    }

    @TestCase
    func aCommandMayHaveTheSameNameAsTheApp() {
        // arrange
        let app = JianApp(name: "demo").add(TestCommand("demo", { _ => 9 }))

        // act
        let code = app.run(["demo"])

        // assert
        @Expect(code, 9)
    }

    @TestCase
    func nestedAppsDispatchAndRunCallbacksInOrder() {
        // arrange
        let events = ArrayList<String>()
        let child = JianApp(name: "admin")
            .callback(TestCallback({ _ => events.add("child"); JianCallbackResult.Continue }))
            .add(TestCommand("sync", { _ => events.add("command"); 3 }))
        let app = JianApp(name: "demo")
            .callback(TestCallback({ args =>
                @Expect(args.next(), Some(JianArg.Long("verbose")))
                events.add("root")
                JianCallbackResult.Continue
            }))
            .add(child, name: "admin")

        // act
        let code = app.run(["--verbose", "admin", "sync"])

        // assert
        @Expect(code, 3)
        @Expect(events.toArray(), ["root", "child", "command"])
    }

    @TestCase
    func shortValueOptionsAreConfiguredForCallbacksAndCommands() {
        // arrange
        let values = ArrayList<String>()
        let spec = JianCommandSpec(inputs: [JianInputSpec("number", kind: JianInputKind.ValueOption, short: b'n')])
        let app = JianApp(name: "demo")
            .callback(TestCallback({ args =>
                @Expect(args.next(), Some(JianArg.Short(b'n', "42")))
                @Expect(args.peek(), Some(JianArg.Operand("sync")))
                values.add("callback")
                JianCallbackResult.Continue
            }, spec: spec))
            .add(TestCommand("sync", { args =>
                @Expect(args.next(), Some(JianArg.Short(b'n', "17")))
                values.add("command")
                0
            }, spec: spec))

        // act
        let code = app.run(["-n42", "sync", "-n17"])

        // assert
        @Expect(code, 0)
        @Expect(values.toArray(), ["callback", "command"])
    }

    @TestCase
    func unknownCommandReportsAnErrorAndUsage() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors)

        // act
        let code = app.run(["absent"])

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()), "Error: unknown command 'absent'\nUsage: demo [OPTIONS] COMMAND [ARGS]...\n")
    }

    @TestCase
    func nestedUsageErrorsUseTheRootStreamAndFullCommandPath() {
        // arrange
        let errors = ByteBuffer()
        let childErrors = ByteBuffer()
        let child = JianApp(name: "admin", stderr: childErrors)
            .add(TestCommand("sync", { _ => throw JianUsageException.missingArgument("PATH") }))
        let app = JianApp(name: "demo", stderr: errors).add(child, name: "admin")

        // act
        let code = app.run(["admin", "sync"])

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()), "Error: missing argument 'PATH'\nUsage: demo admin sync [OPTIONS]\n")
        @Expect(childErrors.bytes().isEmpty(), true)
    }

    @TestCase
    func commandExceptionsPropagateWithoutWritingAUsageError() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors)
            .add(TestCommand("sync", { _ => throw IllegalStateException("command failed") }))

        // act
        let error = @AssertThrows[IllegalStateException](app.run(["sync"]))

        // assert
        @Expect(error.message, "command failed")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func callbackExitStopsCommandDispatch() {
        // arrange
        let calls = ArrayList<Bool>()
        let app = JianApp(name: "demo")
            .callback(TestCallback({ _ => JianCallbackResult.Exit(5) }))
            .add(TestCommand("sync", { _ => calls.add(true); 0 }))

        // act
        let code = app.run(["sync"])

        // assert
        @Expect(code, 5)
        @Expect(calls.isEmpty(), true)
    }

    @TestCase[code in [0, 7, -1], input in [[], ["sync"], ["admin", "sync"], ["unknown"]]]
    func callbackExitReturnsBeforeCommandSelection(code: Int64, input: Array<String>) {
        // arrange
        let errors = ByteBuffer()
        let calls = ArrayList<String>()
        let child = JianApp().callback(TestCallback({ _ => calls.add("child"); JianCallbackResult.Continue }))
            .add(TestCommand("sync", { _ => calls.add("command"); 9 }))
        let app = JianApp(name: "demo", stderr: errors)
            .callback(TestCallback({ _ => JianCallbackResult.Exit(code) }))
            .add(TestCommand("sync", { _ => calls.add("command"); 9 }))
            .add(child, name: "admin")

        // act
        let result = app.run(input)

        // assert
        @Expect(result, code)
        @Expect(calls.isEmpty(), true)
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase[code in [0, 9]]
    func nestedCallbackExitReturnsThroughTheRoot(code: Int64) {
        // arrange
        let errors = ByteBuffer()
        let childErrors = ByteBuffer()
        let calls = ArrayList<String>()
        let child = JianApp(stderr: childErrors)
            .callback(TestCallback({ _ => calls.add("child"); JianCallbackResult.Exit(code) }))
            .add(TestCommand("sync", { _ => calls.add("command"); 7 }))
        let app = JianApp(name: "demo", stderr: errors)
            .callback(TestCallback({ _ => calls.add("root"); JianCallbackResult.Continue }))
            .add(child, name: "admin")

        // act
        let result = app.run(["admin", "sync"])

        // assert
        @Expect(result, code)
        @Expect(calls.toArray(), ["root", "child"])
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(childErrors.bytes().isEmpty(), true)
    }

    @TestCase
    func continueStillRequiresACommandWhenCommandsAreRegistered() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors)
            .callback(TestCallback({ _ => JianCallbackResult.Continue }))
            .add(TestCommand("sync", { _ => 0 }))

        // act
        let code = app.run([])

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()),
            "Error: missing argument 'COMMAND'\nUsage: demo [OPTIONS] COMMAND [ARGS]...\n")
    }

    @TestCase
    func callbackOnlyAppMayRunWithoutACommand() {
        // arrange
        let calls = ArrayList<Bool>()
        let app = JianApp(name: "demo").callback(TestCallback({ _ => calls.add(true); JianCallbackResult.Continue }))

        // act
        let code = app.run([])

        // assert
        @Expect(code, 0)
        @Expect(calls.toArray(), [true])
    }

    @TestCase[input in [[], ["--bad"], ["-x"], ["--bad=value"], ["-x=value"]]]
    func missingCommandsAndUnknownAppOptionsAreUsageErrors(input: Array<String>) {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors)

        // act
        let code = app.run(input)

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()).contains("Usage: demo "), true)
    }

    @TestCase
    func callbackUsageErrorsAreReportedBeforeDispatch() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors)
            .callback(TestCallback({ _ => throw JianUsageException.missingArgument("--config") }))

        // act
        let code = app.run(["sync"])

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()), "Error: missing argument '--config'\nUsage: demo [OPTIONS]\n")
    }

    @TestCase
    func duplicateNamesAreRejectedAcrossCommandsAndSubApps() {
        // arrange
        let app = JianApp(name: "demo").add(TestCommand("sync", { _ => 0 }))

        // act
        let error = @AssertThrows[IllegalArgumentException](app.add(JianApp(name: "sync"), name: "sync"))

        // assert
        @Expect(error.message, "duplicate command 'sync'")
    }

    @TestCase
    func mountNamesAndHelpDoNotChangeTheChild() {
        // arrange
        let output = ByteBuffer()
        let childOutput = ByteBuffer()
        let child = JianApp(name: "standalone", help: "Original help", stdout: childOutput)
            .add(TestCommand("show", { _ => 4 }))
        let app = JianApp(name: "demo", stdout: output)
            .add(child, name: "users", help: "Users help")
            .add(child, name: "admins", help: "Admins help")

        // act
        let users = app.run(["users", "show"])
        let admins = app.run(["admins", "show"])
        app.run(["users", "--help"])
        app.run(["admins", "--help"])
        child.run(["--help"])

        // assert
        @Expect(users, 4)
        @Expect(admins, 4)
        let mounted = String.fromUtf8(output.bytes())
        @Expect(mounted.contains("Usage: demo users "), true)
        @Expect(mounted.contains("Usage: demo admins "), true)
        @Expect(mounted.contains("Users help"), true)
        @Expect(mounted.contains("Admins help"), true)
        @Expect(mounted.contains("Original help"), false)
        let standalone = String.fromUtf8(childOutput.bytes())
        @Expect(standalone.contains("Usage: standalone "), true)
        @Expect(standalone.contains("Original help"), true)
    }

    @TestCase
    func laterRegistrationsAreVisibleThroughEveryMount() {
        // arrange
        let child = JianApp()
        let app = JianApp().add(child, name: "first").add(child, name: "second")
        child.add(TestCommand("late", { _ => 6 }))

        // act
        let first = app.run(["first", "late"])
        let second = app.run(["second", "late"])

        // assert
        @Expect(first, 6)
        @Expect(second, 6)
    }

    @TestCase
    func duplicateCallbacksAreRejected() {
        // arrange
        let callback = TestCallback({ _ => JianCallbackResult.Continue })
        let app = JianApp().callback(callback)

        // act
        let error = @AssertThrows[IllegalArgumentException](app.callback(callback))

        // assert
        @Expect(error.message, "duplicate callback")
    }

    @TestCase
    func directAndIndirectMountCyclesAreRejected() {
        // arrange
        let parent = JianApp()
        let child = JianApp()
        parent.add(child, name: "child")

        // act
        let direct = @AssertThrows[IllegalArgumentException](parent.add(parent, name: "self"))
        let indirect = @AssertThrows[IllegalArgumentException](child.add(parent, name: "parent"))

        // assert
        @Expect(direct.message, "cyclic app mount 'self'")
        @Expect(indirect.message, "cyclic app mount 'parent'")
    }

    @TestCase
    func unnamedAppsHaveAStableStandaloneUsageName() {
        // arrange
        let output = ByteBuffer()
        let app = JianApp(stdout: output)

        // act
        let code = app.run(["--help"])

        // assert
        @Expect(code, 0)
        @Expect(String.fromUtf8(output.bytes()).startsWith("Usage: app "), true)
    }

}
