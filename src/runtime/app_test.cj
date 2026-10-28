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
    private let action: (JianArgCursor) -> Int64

    public init(action: (JianArgCursor) -> Int64, spec!: JianCommandSpec = JianCommandSpec()) {
        this.action = action
        this.commandSpec = spec
    }

    public func run(args: JianArgCursor): Int64 { action(args) }
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
            .callback(TestCallback({ _ => events.add("child"); 0 }))
            .add(TestCommand("sync", { _ => events.add("command"); 3 }))
        let app = JianApp(name: "demo")
            .callback(TestCallback({ args =>
                @Expect(args.next(), Some(JianArg.Long("verbose")))
                events.add("root")
                0
            }))
            .add(child)

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
                0
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
        let app = JianApp(name: "demo", stderr: errors).add(child)

        // act
        let code = app.run(["admin", "sync"])

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()), "Error: missing argument 'PATH'\nUsage: demo admin sync [ARGS]...\n")
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
    func nonzeroCallbackStopsCommandDispatch() {
        // arrange
        let calls = ArrayList<Bool>()
        let app = JianApp(name: "demo")
            .callback(TestCallback({ _ => 5 }))
            .add(TestCommand("sync", { _ => calls.add(true); 0 }))

        // act
        let code = app.run(["sync"])

        // assert
        @Expect(code, 5)
        @Expect(calls.isEmpty(), true)
    }

    @TestCase
    func callbackOnlyAppMayRunWithoutACommand() {
        // arrange
        let calls = ArrayList<Bool>()
        let app = JianApp(name: "demo").callback(TestCallback({ _ => calls.add(true); 0 }))

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
        @Expect(String.fromUtf8(errors.bytes()), "Error: missing argument '--config'\nUsage: demo [OPTIONS] COMMAND [ARGS]...\n")
    }

    @TestCase
    func duplicateNamesAreRejectedAcrossCommandsAndSubApps() {
        // arrange
        let app = JianApp(name: "demo").add(TestCommand("sync", { _ => 0 }))

        // act
        let error = @AssertThrows[IllegalArgumentException](app.add(JianApp(name: "sync")))

        // assert
        @Expect(error.message, "duplicate command 'sync'")
    }
}
