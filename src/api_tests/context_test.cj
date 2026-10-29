package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

class ContextTrace {
    public var events = ""
}

@JianContext
class TestContext {
    private let trace: ContextTrace
    public var enabled: Bool = false
    public let optional: ?Int64 = None

    public init(trace: ContextTrace) { this.trace = trace }
}

@JianContext
class PrimaryContext {
    public PrimaryContext(public let trace: ContextTrace) {}
}

type ContextAlias = TestContext

@JianCallback
func configureContext(ctx!: ContextAlias = JianFromContext<ContextAlias>(),
    trace!: ContextTrace = JianFromContext<ContextAlias>(), enabled!: Bool = false, stop!: Int64 = 0): JianCallbackResult {
    ctx.enabled = enabled
    trace.events += "root;"
    if (stop == 0) { JianCallbackResult.Continue } else { JianCallbackResult.Exit(stop) }
}

@JianCallback
func childContext(trace!: ContextTrace = JianFromContext<TestContext>()): JianCallbackResult {
    trace.events += "child;"
    JianCallbackResult.Continue
}

@JianCallback
func stopContext(trace!: ContextTrace = JianFromContext<TestContext>(), code!: Int64 = 0) {
    trace.events += "exit;"
    JianCallbackResult.Exit(code)
}

@JianCommand
func recordContext(value: String, trace!: ContextTrace = JianFromContext<TestContext>(),
    enabled!: Bool = JianFromContext<TestContext>(), optional!: ?Int64 = JianFromContext<TestContext>()): Int64 {
    trace.events += "${value}:${enabled}:${optional ?? -1};"
    7
}

@JianCommand
func contextFiles(files!: Array<String> = JianArgument(default: []),
    help!: ContextTrace = JianFromContext<PrimaryContext>()): Unit {
    help.events += files.size.toString()
}

@JianCommand
func contextDefault(trace!: ContextTrace = JianFromContext<TestContext>(), text!: String = trace.events): Unit {
    trace.events = text
}

@JianCommand
func contextFailure(ctx!: TestContext = JianFromContext<TestContext>()): Unit {
    ctx.enabled = true
    throw IllegalStateException("context failure")
}

class ContextlessTestCommand <: JianCommand {
    public prop name: String { get() { "plain" } }
    public prop spec: JianCommandSpec { get() { JianCommandSpec() } }
    public func run(_: JianArgCursor): Int64 { 8 }
}

class ContextlessTestCallback <: JianCallback {
    public prop spec: JianCommandSpec { get() { JianCommandSpec() } }
    public func run(_: JianArgCursor): JianCallbackResult { JianCallbackResult.Continue }
}

@Test
class ContextTest {
    @TestCase
    func callbacksAndNestedCommandShareTheExactContext() {
        // arrange
        let trace = ContextTrace()
        let context = TestContext(trace)
        let app = JianContextApp<TestContext>(name: "demo").callback(configureContext)
            .add(JianContextApp<TestContext>(name: "child").callback(childContext).add(recordContext), name: "child")

        // act
        let code = app.run(["--enabled", "child", "record-context", "hello"], context: context)

        // assert
        @Expect(code, 7)
        @Expect(trace.events, "root;child;hello:true:-1;")
        @Expect(context.enabled, true)
        @Expect(refEq(TestContext.jianFromContext<TestContext>(context), context), true)
    }

    @TestCase
    func contextDoesNotCreateCliInputsOrHelpRows() {
        // arrange
        let output = ByteBuffer()
        let trace = ContextTrace()
        let app = JianContextApp<TestContext>(name: "demo", stdout: output).add(recordContext)

        // act
        let code = app.run(["record-context", "--help"], context: TestContext(trace))
        let text = String.fromUtf8(output.bytes())

        // assert
        @Expect(code, 0)
        @Expect(RecordContextCommand().spec.inputs.size, 1)
        @Expect(ConfigureContextCallback().spec.inputs.size, 2)
        @Expect(text.contains("VALUE"), true)
        @Expect(text.contains("--trace"), false)
        @Expect(text.contains("--enabled"), false)
        @Expect(text.contains("--optional"), false)
        @Expect(trace.events, "")
    }

    @TestCase
    func helpSkipsItsTargetButPreservesAncestorCallbacks() {
        // arrange
        let trace = ContextTrace()
        let context = TestContext(trace)
        let app = JianContextApp<TestContext>(name: "demo", stdout: ByteBuffer()).callback(configureContext)
            .add(JianContextApp<TestContext>(name: "child").callback(childContext).add(recordContext), name: "child")

        // act
        let root = app.run(["--help"], context: context)
        let child = app.run(["child", "--help"], context: context)
        let command = app.run(["child", "record-context", "--help"], context: context)

        // assert
        @Expect(root, 0)
        @Expect(child, 0)
        @Expect(command, 0)
        @Expect(trace.events, "root;root;child;")
    }

    @TestCase
    func callbackExitStopsNestedDispatch() {
        // arrange
        let trace = ContextTrace()
        let app = JianContextApp<TestContext>(name: "demo").callback(configureContext)
            .add(JianContextApp<TestContext>(name: "child").callback(childContext).add(recordContext), name: "child")

        // act
        let code = app.run(["--stop=9", "child", "record-context", "hello"], context: TestContext(trace))

        // assert
        @Expect(code, 9)
        @Expect(trace.events, "root;")
    }

    @TestCase[exitCode in [0, 9]]
    func contextualCallbackExitStopsAtTheSelectedChild(exitCode: Int64) {
        // arrange
        let trace = ContextTrace()
        let errors = ByteBuffer()
        let app = JianContextApp<TestContext>(name: "demo", stderr: errors).callback(configureContext)
            .add(JianContextApp<TestContext>().callback(stopContext).add(recordContext), name: "child")

        // act
        let code = app.run(["child", "--code=${exitCode}"], context: TestContext(trace))

        // assert
        @Expect(code, exitCode)
        @Expect(trace.events, "root;exit;")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func contextFreeCallbackCanExitAContextAppSuccessfully() {
        // arrange
        let trace = ContextTrace()
        let errors = ByteBuffer()
        let app = JianContextApp<TestContext>(stderr: errors).callback(callbackExit).add(recordContext)

        // act
        let code = app.run(["--code=0", "record-context", "hello"], context: TestContext(trace))

        // assert
        @Expect(code, 0)
        @Expect(trace.events, "")
        @Expect(errors.bytes().isEmpty(), true)
    }

    @TestCase
    func repeatedRunsUseTheSuppliedContextAndPreserveItsState() {
        // arrange
        let first = ContextTrace()
        let second = ContextTrace()
        let firstContext = TestContext(first)
        let secondContext = TestContext(second)
        firstContext.enabled = true
        let app = JianContextApp<TestContext>(name: "demo").add(recordContext)
        let otherApp = JianContextApp<TestContext>(name: "demo").add(recordContext)

        // act
        app.run(["record-context", "one"], context: firstContext)
        app.run(["record-context", "two"], context: secondContext)
        otherApp.run(["record-context", "three"], context: firstContext)

        // assert
        @Expect(first.events, "one:true:-1;three:true:-1;")
        @Expect(second.events, "two:false:-1;")
    }

    @TestCase
    func directCallsRequireAndUseExplicitDependencies() {
        // arrange
        let trace = ContextTrace()
        let context = TestContext(trace)

        // act
        configureContext(ctx: context, trace: trace, enabled: true)
        let code = recordContext("direct", trace: trace, enabled: context.enabled, optional: None)

        // assert
        @Expect(code, 7)
        @Expect(trace.events, "root;direct:true:-1;")
    }

    @TestCase
    func injectionAfterVariadicArgumentUsesPrimaryConstructorFields() {
        // arrange
        let trace = ContextTrace()
        let command = ContextFilesCommand()

        // act
        let code = command.run(JianArgCursor(["a", "b"]), PrimaryContext(trace))

        // assert
        @Expect(code, 0)
        @Expect(trace.events, "2")
        @Expect(command.spec.inputs.size, 1)
    }

    @TestCase
    func contextAppAcceptsOrdinaryCommandsAndCallbacks() {
        // arrange
        let app = JianContextApp<TestContext>(name: "demo").callback(ContextlessTestCallback()).add(ContextlessTestCommand())

        // act
        let code = app.run(["plain"], context: TestContext(ContextTrace()))

        // assert
        @Expect(code, 8)
    }

    @TestCase
    func injectedNamesAreNotRecognizedAsOptionsAndErrorsUseTheFullPath() {
        // arrange
        let errors = ByteBuffer()
        let trace = ContextTrace()
        let app = JianContextApp<TestContext>(name: "demo", stderr: errors)
            .add(JianContextApp<TestContext>(name: "child").add(recordContext), name: "child")

        // act
        let code = app.run(["child", "record-context", "hello", "--enabled"], context: TestContext(trace))

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown option '--enabled'"), true)
        @Expect(String.fromUtf8(errors.bytes()).contains("Usage: demo child record-context"), true)
        @Expect(trace.events, "")
    }

    @TestCase
    func callbackOnlyAppConfiguresTheSuppliedContext() {
        // arrange
        let trace = ContextTrace()
        let context = TestContext(trace)
        let app = JianContextApp<TestContext>(name: "demo").callback(configureContext)

        // act
        let code = app.run(["--enabled"], context: context)

        // assert
        @Expect(code, 0)
        @Expect(context.enabled, true)
        @Expect(trace.events, "root;")
    }

    @TestCase
    func defaultsCanReferToEarlierInjectedDependencies() {
        // arrange
        let trace = ContextTrace()
        trace.events = "existing"
        let context = TestContext(trace)
        let command = ContextDefaultCommand()

        // act
        command.run(JianArgCursor([]), context)
        let defaulted = trace.events
        command.run(JianArgCursor(["--text=explicit"]), context)

        // assert
        @Expect(defaulted, "existing")
        @Expect(trace.events, "explicit")
    }

    @TestCase
    func contextFailuresPropagateWithoutBeingReportedAsCliErrors() {
        // arrange
        let context = TestContext(ContextTrace())
        let errors = ByteBuffer()
        let app = JianContextApp<TestContext>(name: "demo", stderr: errors).add(contextFailure)

        // act
        let error = @AssertThrows[IllegalStateException](app.run(["context-failure"], context: context))

        // assert
        @Expect(error.message, "context failure")
        @Expect(context.enabled, true)
        @Expect(errors.bytes().size, 0)
    }
}
