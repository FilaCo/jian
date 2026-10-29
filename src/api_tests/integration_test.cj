package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private var integrationEvents = ""

@JianCallback[help: "Workspace options"]
func integrationGlobal(verbose!: Bool = JianOption(short: 'v', help: "Verbose workspace", default: false),
    jobs!: Int64 = JianOption(short: 'j', default: 1),
    paths!: Array<String> = JianOption(short: 'p', hidden: true, default: [])): JianCallbackResult {
    integrationEvents += "global:${verbose}:${jobs}:${paths};"
    JianCallbackResult.Continue
}

@JianCommand[help: "Process input paths"]
func integrationFiles(paths!: Array<String> = JianArgument(help: "Input paths", default: []),
    verbose!: Bool = JianOption(short: 'v', default: false), times!: Int64 = JianOption(short: 't', default: 1)): Int64 {
    integrationEvents += "files:${paths}:${verbose}:${times};"
    paths.size * times
}

@JianCallback
func integrationArguments(values!: Array<String> = JianArgument(help: "Arguments", default: [])): JianCallbackResult {
    integrationEvents = values.toString()
    JianCallbackResult.Continue
}

@Test
class MacroIntegrationTest {
    @TestCase
    func shortTablesSwitchAtCommandBoundaryAndVariadicOperandsAccumulate() {
        // arrange
        integrationEvents = ""
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stderr: errors)
            .callback(integrationGlobal).add(integrationFiles)

        // act
        let code = app.run(["-vj3", "-pa", "-p", "b", "integration-files", "first", "-vt2", "second"])

        // assert
        @Expect(code, 4)
        @Expect(integrationEvents, "global:true:3:[a, b];files:[first, second]:true:2;")
        @Expect(errors.bytes().size, 0)
        @Expect(IntegrationGlobalCallback().spec.inputs[0].short, Some(b'v'))
        @Expect(IntegrationGlobalCallback().spec.inputs[0].help, "Verbose workspace")
        @Expect(IntegrationGlobalCallback().spec.inputs[2].hidden, true)
        @Expect(IntegrationFilesCommand().spec.inputs[0].repeatable, true)
        @Expect(IntegrationFilesCommand().spec.inputs[0].help, "Input paths")
    }

    @TestCase
    func callbackVariadicCollectsAllOperandsWhenUsedWithoutSubcommands() {
        // arrange
        let app = JianApp(name: "test").callback(integrationArguments)

        // act
        let code = app.run(["first", "second", "--", "-third"])

        // assert
        @Expect(code, 0)
        @Expect(integrationEvents, "[first, second, -third]")
    }

    @TestCase
    func callbackShortValueCanEqualASubcommandName() {
        // arrange
        integrationEvents = ""
        let app = JianApp(name: "test").callback(integrationGlobal).add(integrationFiles)

        // act
        let code = app.run(["-p", "integration-files", "integration-files", "input"])

        // assert
        @Expect(code, 1)
        @Expect(integrationEvents, "global:false:1:[integration-files];files:[input]:false:1;")
    }

    @TestCase
    func appHelpUsesCallbackParamMetadataAfterShortClustersWithoutInvocation() {
        // arrange
        integrationEvents = ""
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stdout: output, stderr: errors)
            .callback(integrationGlobal).add(integrationFiles)

        // act
        let code = app.run(["-vj3", "-h"])
        let help = String.fromUtf8(output.bytes())

        // assert
        @Expect(code, 0)
        @Expect(integrationEvents, "")
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(help.contains("Workspace options"), true)
        @Expect(help.contains("-v, --verbose  Verbose workspace"), true)
        @Expect(help.contains("-j, --jobs INT"), true)
        @Expect(help.contains("--paths"), false)
        @Expect(help.contains("integration-files  Process input paths"), true)
    }

    @TestCase
    func commandHelpDescribesVariadicOperandsAfterShortOptions() {
        // arrange
        integrationEvents = ""
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stdout: output, stderr: errors)
            .callback(integrationGlobal).add(integrationFiles)

        // act
        let code = app.run(["integration-files", "-vt2", "-h"])
        let help = String.fromUtf8(output.bytes())

        // assert
        @Expect(code, 0)
        @Expect(integrationEvents, "global:false:1:[];")
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(help.contains("Usage: test integration-files [OPTIONS] [PATHS...]"), true)
        @Expect(help.contains("PATHS...  Input paths"), true)
        @Expect(help.contains("-t, --times INT"), true)
    }

    @TestCase
    func helpLikeValuesAndVariadicOperandsAfterMarkerReachTheFunctions() {
        // arrange
        integrationEvents = ""
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stdout: output, stderr: errors)
            .callback(integrationGlobal).add(integrationFiles)

        // act
        let code = app.run(["-p", "-h", "integration-files", "--", "-h"])

        // assert
        @Expect(code, 1)
        @Expect(integrationEvents, "global:false:1:[-h];files:[-h]:false:1;")
        @Expect(output.bytes().isEmpty(), true)
        @Expect(errors.bytes().isEmpty(), true)
    }
}
