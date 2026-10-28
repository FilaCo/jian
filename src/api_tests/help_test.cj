package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

@JianCommand[help: "Greet someone."]
func helpGreeting(name: String, times!: Int64 = 2): Unit {
    throw IllegalStateException("help executed '${name}' ${times} times")
}

@JianCommand[help: "Collect files."]
func helpMarkers(files!: Array<String> = JianArgument(help: "Input files."),
    times!: ?Int64 = JianOption(short: 't', help: "Repetitions."),
    secret!: String = JianOption(hidden: true)): Unit {
    throw IllegalStateException("help executed '${files}' ${times} ${secret}")
}

@JianCallback[help: "Global settings."]
func helpSettings(workspace!: String = JianArgument(help: "Workspace."),
    verbose!: Bool = JianOption(short: 'v', default: false)): Unit {
    throw IllegalStateException("help executed '${workspace}' ${verbose}")
}

private class HandwrittenHelpCommand <: JianCommand {
    public prop name: String { get() { "manual" } }
    public prop spec: JianCommandSpec { get() { JianCommandSpec(help: "Manual command.") } }
    public func run(args: JianArgCursor): Int64 { args.remaining().size }
}

@Test
class HelpMacroTest {
    @TestCase[input in [["--help"], ["-h"], ["-t", "3", "-h"]]]
    func helpRendersMarkerMetadataAndImplicitOptionalDefaults(input: Array<String>) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp<JianNoContext>(name: "demo", stdout: output, stderr: errors).add(HelpMarkersCommand())

        // act
        let code = app.run(["help-markers"].concat(input))

        // assert
        @Expect(code, 0)
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo help-markers [OPTIONS] FILES...\n\nCollect files.\n\nArguments:\n" +
            "  FILES...  Input files. [required]\n\nOptions:\n" +
            "  -t, --times INT  Repetitions. [default: None]\n" +
            "  -h, --help  Show this message and exit.\n")
    }

    @TestCase
    func appHelpRendersCallbackMarkersWithoutInvokingTheCallback() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp<JianNoContext>(name: "demo", stdout: output, stderr: errors).callback(HelpSettingsCallback())

        // act
        let code = app.run(["--help"])

        // assert
        @Expect(code, 0)
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo [OPTIONS] WORKSPACE\n\nGlobal settings.\n\nArguments:\n" +
            "  WORKSPACE  Workspace. [required]\n\nOptions:\n" +
            "  -v, --verbose  [default: false]\n  -h, --help  Show this message and exit.\n")
    }

    @TestCase
    func handwrittenConsumerCommandsUseTheSameHelpContract() {
        // arrange
        let output = ByteBuffer()
        let app = JianApp<JianNoContext>(name: "demo", stdout: output).add(HandwrittenHelpCommand())

        // act
        let code = app.run(["manual", "--help"])

        // assert
        @Expect(code, 0)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo manual [OPTIONS]\n\nManual command.\n\nOptions:\n" +
            "  -h, --help  Show this message and exit.\n")
        @Expect(app.run(["manual", "one", "two"]), 2)
    }

    @TestCase
    func helpRendersGeneratedMetadataBeforeParsingRequiredArguments() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp<JianNoContext>(name: "demo", stdout: output, stderr: errors).add(HelpGreetingCommand())

        // act
        let code = app.run(["help-greeting", "--help"])

        // assert
        @Expect(code, 0)
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo help-greeting [OPTIONS] NAME\n\nGreet someone.\n\nArguments:\n" +
            "  NAME  [required]\n\nOptions:\n  --times INT  [default: 2]\n" +
            "  -h, --help  Show this message and exit.\n")
    }

    @TestCase[index in 0..3]
    func generatedParserErrorsUseTheSameMetadataAsHelp(index: Int64) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let inputs: Array<Array<String>> = [[], ["Ann", "--x"], ["Ann", "--times=abc"]]
        let messages = ["missing argument 'NAME'", "unknown option '--x'",
            "invalid value 'abc' for '--times': expected Int64"]
        let app = JianApp<JianNoContext>(name: "demo", stdout: output, stderr: errors).add(HelpGreetingCommand())

        // act
        let code = app.run(["help-greeting"].concat(inputs[index]))

        // assert
        @Expect(code, 2)
        @Expect(output.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(errors.bytes()),
            "Error: ${messages[index]}\nUsage: demo help-greeting [OPTIONS] NAME\n")
    }
}
