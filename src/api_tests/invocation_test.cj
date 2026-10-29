package jian.api_tests

import jian.*
import jian.api_tests.exported.exportedInvocation
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private var invocationEvents = ""

@JianCallback[defaultAction: "Run the server"]
func defaultInvocation(invocation!: JianInvocation = JianCurrentInvocation(), schema!: Bool = false) {
    invocationEvents += "${invocation.requestedSubcommand ?? "absent"};"
    if (schema) { return JianCallbackResult.Exit(0) }
    if (invocation.requestedSubcommand.isNone()) {
        invocationEvents += "server;"
        return JianCallbackResult.Exit(6)
    }
    JianCallbackResult.Continue
}

@JianCallback
func observeInvocation(invocation!: JianInvocation = JianCurrentInvocation()) {
    invocationEvents += "${invocation.requestedSubcommand ?? "absent"};"
    JianCallbackResult.Continue
}

@JianCallback
func parsedInvocation(workspace: String, invocation!: JianInvocation = JianCurrentInvocation(),
    verbose!: Bool = JianOption(default: false, short: 'v'),
    target!: String = JianOption(default: "default", short: 't'),
    snapshot!: String = invocation.requestedSubcommand ?? "absent") {
    invocationEvents += "${workspace}:${verbose}:${target}:${snapshot};"
    JianCallbackResult.Continue
}

@JianCallback
func requiredInvocation(invocation!: JianInvocation = JianCurrentInvocation(), required!: String) {
    let _ = (invocation, required)
    invocationEvents += "body;"
    JianCallbackResult.Exit(0)
}

@JianCallback
func contextInvocation(invocation!: JianInvocation = JianCurrentInvocation(),
    trace!: ContextTrace = JianFromContext<TestContext>()) {
    trace.events += "${invocation.requestedSubcommand ?? "absent"};"
    if (invocation.requestedSubcommand.isNone()) { JianCallbackResult.Exit(5) }
    else { JianCallbackResult.Continue }
}

@JianCallback
func failingInvocation(invocation!: JianInvocation = JianCurrentInvocation()) {
    throw IllegalStateException(invocation.requestedSubcommand ?? "absent")
}

@JianCommand
func invocationCommand(): Int64 {
    invocationEvents += "command;"
    7
}

@JianContext
class InvocationParent {
    public InvocationParent(public let child: TestContext) {}
}

@JianCallback
func parentInvocation(parent!: InvocationParent = JianFromContext<InvocationParent>(),
    invocation!: JianInvocation = JianCurrentInvocation()) {
    TestContext.jianFromContext<ContextTrace>(parent.child).events += "parent:${invocation.requestedSubcommand ?? "absent"};"
    JianCallbackResult.Continue
}

@Test
class InvocationTest {
    @TestCase
    func defaultActionRunsOnlyWhenNoCommandWasRequestedAcrossRepeatedRuns() {
        // arrange
        invocationEvents = ""
        let errors = ByteBuffer()
        let app = JianApp(stderr: errors).callback(defaultInvocation).add(invocationCommand)

        // act
        let absent = app.run([])
        let known = app.run(["invocation-command"])
        let unknown = app.run(["invocation-commnad"])
        let absentAgain = app.run([])

        // assert
        @Expect(absent, 6)
        @Expect(known, 7)
        @Expect(unknown, 2)
        @Expect(absentAgain, 6)
        @Expect(invocationEvents, "absent;server;invocation-command;command;invocation-commnad;absent;server;")
        @Expect(String.fromUtf8(errors.bytes()).contains("unknown command 'invocation-commnad'"), true)
    }

    @TestCase
    func continuePreservesMissingCommandAndCallbackOnlyBehavior() {
        // arrange
        invocationEvents = ""
        let errors = ByteBuffer()
        let withCommands = JianApp(stderr: errors).callback(observeInvocation).add(invocationCommand)
        let callbackOnly = JianApp().callback(observeInvocation)

        // act
        let missing = withCommands.run([])
        let only = callbackOnly.run([])

        // assert
        @Expect(missing, 2)
        @Expect(only, 0)
        @Expect(invocationEvents, "absent;absent;")
        @Expect(String.fromUtf8(errors.bytes()).contains("missing argument 'COMMAND'"), true)
    }

    @TestCase
    func metadataUsesTheBoundaryAfterPositionalsAndOptionValues() {
        // arrange
        invocationEvents = ""
        let app = JianApp().callback(parsedInvocation).add(invocationCommand)

        // act
        let longValue = app.run(["invocation-command", "--target", "invocation-command", "invocation-command"])
        let cluster = app.run(["workspace", "-vtinvocation-command", "invocation-command"])
        let clusterValue = app.run(["workspace", "-vt", "invocation-command", "invocation-command"])
        let absent = app.run(["workspace", "--target=invocation-command"])

        // assert
        @Expect(longValue, 7)
        @Expect(cluster, 7)
        @Expect(clusterValue, 7)
        @Expect(absent, 2)
        @Expect(invocationEvents,
            "invocation-command:false:invocation-command:invocation-command;command;" +
            "workspace:true:invocation-command:invocation-command;command;" +
            "workspace:true:invocation-command:invocation-command;command;" +
            "workspace:false:invocation-command:absent;")
    }

    @TestCase
    func endOfOptionsPreservesOperandClassificationAndDoesNotConsumeTheName() {
        // arrange
        invocationEvents = ""
        let args = JianArgCursor(["workspace", "--", "-h", "--remaining"])

        // act
        let result = ParsedInvocationCallback().run(args)
        let operand = args.next()
        let remaining = args.next()
        let ended = ObserveInvocationCallback().run(JianArgCursor(["--"]))

        // assert
        @Expect(result, JianCallbackResult.Continue)
        @Expect(operand, Some(JianArg.Operand("-h")))
        @Expect(remaining, Some(JianArg.Operand("--remaining")))
        @Expect(ended, JianCallbackResult.Continue)
        @Expect(invocationEvents, "workspace:false:default:-h;absent;")
    }

    @TestCase
    func namedCommandsAndMountedGroupsTakePrecedenceOverDefaultActions() {
        // arrange
        invocationEvents = ""
        let child = JianApp(name: "intrinsic").callback(defaultInvocation).add(invocationCommand)
        let app = JianApp().callback(defaultInvocation).add(invocationCommand).add(child, name: "mounted")

        // act
        let command = app.run(["invocation-command"])
        let groupDefault = app.run(["mounted"])
        let nestedCommand = app.run(["mounted", "invocation-command"])

        // assert
        @Expect(command, 7)
        @Expect(groupDefault, 6)
        @Expect(nestedCommand, 7)
        @Expect(invocationEvents,
            "invocation-command;command;mounted;absent;server;mounted;invocation-command;command;")
    }

    @TestCase
    func rootAndNestedHelpUseRootStreamsAndSkipTheirTargetCallback() {
        // arrange
        invocationEvents = ""
        let output = ByteBuffer()
        let childOutput = ByteBuffer()
        let app = JianApp(name: "demo", stdout: output).callback(defaultInvocation)
            .add(JianApp(stdout: childOutput).callback(defaultInvocation).add(invocationCommand), name: "mounted")

        // act
        let root = app.run(["--help"])
        let nested = app.run(["mounted", "--help"])
        let command = app.run(["mounted", "invocation-command", "--help"])
        let text = String.fromUtf8(output.bytes())

        // assert
        @Expect(root, 0)
        @Expect(nested, 0)
        @Expect(command, 0)
        @Expect(invocationEvents, "mounted;mounted;invocation-command;")
        @Expect(text.contains("Usage: demo [OPTIONS] [COMMAND [ARGS]...]"), true)
        @Expect(text.contains("Default action: Run the server"), true)
        @Expect(text.contains("Usage: demo mounted [OPTIONS] [COMMAND [ARGS]...]"), true)
        @Expect(childOutput.bytes().isEmpty(), true)
        @Expect(text.contains("--invocation"), false)
    }

    @TestCase
    func inspectingMetadataAloneDoesNotMakeCommandSelectionOptionalInHelp() {
        // arrange
        let output = ByteBuffer()
        let app = JianApp(name: "demo", stdout: output).callback(observeInvocation).add(invocationCommand)

        // act
        let code = app.run(["--help"])

        // assert
        @Expect(code, 0)
        @Expect(String.fromUtf8(output.bytes()).startsWith("Usage: demo [OPTIONS] COMMAND [ARGS]...\n"), true)
        @Expect(ObserveInvocationCallback().spec.inputs.size, 0)
        @Expect(ParsedInvocationCallback().spec.inputs.size, 4)
    }

    @TestCase
    func defaultActionHelpMetadataDoesNotChangeDispatch() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(stderr: errors).callback(DefaultHelpOnlyCallback()).add(invocationCommand)

        // act
        let code = app.run([])

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()).contains("missing argument 'COMMAND'"), true)
    }

    @TestCase
    func successfulCompletionSkipsUnknownNamesAndCommandInputValidation() {
        // arrange
        invocationEvents = ""
        let app = JianApp().callback(defaultInvocation).add(invocationCommand)

        // act
        let unknown = app.run(["--schema", "typo", "--invalid"])
        let invalid = app.run(["--schema", "invocation-command", "--invalid"])
        let absent = app.run(["--schema"])

        // assert
        @Expect(unknown, 0)
        @Expect(invalid, 0)
        @Expect(absent, 0)
        @Expect(invocationEvents, "typo;invocation-command;absent;")
    }

    @TestCase
    func injectionDoesNotBypassRequiredCallbackInputsOrAcceptAnInvocationOption() {
        // arrange
        invocationEvents = ""
        let app = JianApp(stderr: ByteBuffer()).callback(requiredInvocation)
        let observing = JianApp(stderr: ByteBuffer()).callback(observeInvocation)

        // act
        let missing = app.run([])
        let unknown = observing.run(["--invocation=command"])

        // assert
        @Expect(missing, 2)
        @Expect(unknown, 2)
        @Expect(invocationEvents, "")
    }

    @TestCase
    func dependencyAndInvocationInjectionComposeAcrossContextAppLevels() {
        // arrange
        invocationEvents = ""
        let first = ContextTrace()
        let second = ContextTrace()
        let app = JianContextApp<TestContext>().callback(contextInvocation)
            .add(JianContextApp<TestContext>().callback(contextInvocation).add(invocationCommand), name: "mounted")
            .add(JianApp().callback(defaultInvocation), name: "plain")

        // act
        let command = app.run(["mounted", "invocation-command"], context: TestContext(first))
        let childDefault = app.run(["mounted"], context: TestContext(first))
        let rootDefault = app.run([], context: TestContext(second))
        let plainDefault = app.run(["plain"], context: TestContext(second))

        // assert
        @Expect(command, 7)
        @Expect(childDefault, 5)
        @Expect(rootDefault, 5)
        @Expect(plainDefault, 6)
        @Expect(first.events, "mounted;invocation-command;mounted;absent;")
        @Expect(second.events, "absent;plain;")
        @Expect(invocationEvents, "command;absent;server;")
    }

    @TestCase
    func childContextExtractionAndNestedHelpPreserveInvocationOrder() {
        // arrange
        let trace = ContextTrace()
        let output = ByteBuffer()
        let childOutput = ByteBuffer()
        let parent = InvocationParent(TestContext(trace))
        let app = JianContextApp<InvocationParent>(name: "demo", stdout: output).callback(parentInvocation)
            .add(JianContextApp<TestContext>(stdout: childOutput).callback(contextInvocation)
                .add(invocationCommand), name: "mounted")

        // act
        let rootHelp = app.run(["--help"], context: parent)
        let childHelp = app.run(["mounted", "--help"], context: parent)
        let commandHelp = app.run(["mounted", "invocation-command", "--help"], context: parent)
        let childDefault = app.run(["mounted"], context: parent)

        // assert
        @Expect(rootHelp, 0)
        @Expect(childHelp, 0)
        @Expect(commandHelp, 0)
        @Expect(childDefault, 5)
        @Expect(trace.events, "parent:mounted;parent:mounted;invocation-command;parent:mounted;absent;")
        @Expect(String.fromUtf8(output.bytes()).contains("Usage: demo mounted invocation-command"), true)
        @Expect(childOutput.bytes().isEmpty(), true)
    }

    @TestCase
    func contextAppSupportsInvocationWithoutDependencyInjection() {
        // arrange
        invocationEvents = ""
        let app = JianContextApp<TestContext>().callback(defaultInvocation).add(invocationCommand)

        // act
        let defaultCode = app.run([], context: TestContext(ContextTrace()))
        let commandCode = app.run(["invocation-command"], context: TestContext(ContextTrace()))

        // assert
        @Expect(defaultCode, 6)
        @Expect(commandCode, 7)
        @Expect(invocationEvents, "absent;server;invocation-command;command;")
    }

    @TestCase
    func directAndImportedCallsUseExplicitTypedMetadataAndInferredResults() {
        // arrange
        invocationEvents = ""
        let action: (JianInvocation, Bool) -> JianCallbackResult = defaultInvocation
        let app = JianApp().callback(exportedInvocation).add(invocationCommand)

        // act
        let direct = action(JianInvocation(), false)
        let imported = exportedInvocation(invocation: JianInvocation(requestedSubcommand: Some("explicit")))
        let adapted = app.run([])
        let command = app.run(["invocation-command"])

        // assert
        @Expect(direct, JianCallbackResult.Exit(6))
        @Expect(imported, JianCallbackResult.Continue)
        @Expect(adapted, 4)
        @Expect(command, 7)
        @Expect(invocationEvents, "absent;server;command;")
    }

    @TestCase
    func exceptionsPropagateFromCallbacksWithInvocationMetadata() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(stderr: errors).callback(failingInvocation)

        // act
        let error = @AssertThrows[IllegalStateException](app.run(["requested"]))

        // assert
        @Expect(error.message, "requested")
        @Expect(errors.bytes().isEmpty(), true)
    }
}

@JianCallback[defaultAction: "Documentation only"]
func defaultHelpOnly() { JianCallbackResult.Continue }
