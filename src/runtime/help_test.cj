package jian.runtime

import std.collection.ArrayList
import std.io.ByteBuffer

private class HelpCommand <: JianCommand {
    public prop name: String { get() { commandName } }
    public prop spec: JianCommandSpec { get() { commandSpec } }

    public HelpCommand(private let commandName: String, private let commandSpec: JianCommandSpec,
        private let action!: (JianArgCursor) -> Int64 = { _ => throw IllegalStateException("help invoked the command") }) {}

    public func run(args: JianArgCursor): Int64 { action(args) }
}

private class HelpCallback <: JianCallback {
    public prop spec: JianCommandSpec { get() { commandSpec } }

    public HelpCallback(private let commandSpec: JianCommandSpec,
        private let action!: (JianArgCursor) -> JianCallbackResult = { _ => throw IllegalStateException("help invoked the callback") }) {}

    public func run(args: JianArgCursor): JianCallbackResult { action(args) }
}

private func greetingSpec(): JianCommandSpec {
    JianCommandSpec(help: "Greet someone.", inputs: [
        JianInputSpec("name", kind: JianInputKind.Positional, metavar: "TEXT", help: "Who to greet.", required: true),
        JianInputSpec("files", kind: JianInputKind.Positional, metavar: "PATH...", repeatable: true),
        JianInputSpec("times", kind: JianInputKind.ValueOption, metavar: "INT", short: b't', help: "Repetitions.", defaultShown: Some("2")),
        JianInputSpec("loud", kind: JianInputKind.Flag, short: b'l', help: "Use capitals."),
        JianInputSpec("secret", kind: JianInputKind.ValueOption, metavar: "TEXT", help: "Hidden.", hidden: true)
    ])
}

@Test
class HelpTest {
    @TestCase[input in [["--help"], ["-h"]]]
    func appHelpListsCommandsAndSubAppsTogetherInNameOrder(input: Array<String>) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", help: "Demo CLI.", stdout: output, stderr: errors)
            .add(HelpCommand("zebra", JianCommandSpec(help: "Last command.")))
            .add(JianApp(help: "Administration."), name: "admin")
            .add(HelpCommand("greet", greetingSpec()))

        // act
        let code = app.run(input)

        // assert
        @Expect(code, 0)
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo [OPTIONS] COMMAND [ARGS]...\n\nDemo CLI.\n\nOptions:\n" +
            "  -h, --help  Show this message and exit.\n\nCommands:\n" +
            "  admin  Administration.\n  greet  Greet someone.\n  zebra  Last command.\n")
    }

    @TestCase[input in [["greet", "--help"], ["greet", "-lh"], ["greet", "Alice", "-h"]]]
    func commandHelpUsesOnlyItsSpecAndNeverInvokesTheCommand(input: Array<String>) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stdout: output, stderr: errors).add(HelpCommand("greet", greetingSpec()))

        // act
        let code = app.run(input)

        // assert
        @Expect(code, 0)
        @Expect(errors.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo greet [OPTIONS] NAME [FILES...]\n\nGreet someone.\n\nArguments:\n" +
            "  NAME  Who to greet. [required]\n  FILES...\n\nOptions:\n" +
            "  -t, --times INT  Repetitions. [default: 2]\n  -l, --loud  Use capitals.\n" +
            "  -h, --help  Show this message and exit.\n")
    }

    @TestCase
    func appHelpIncludesCallbackMetadataWithoutRunningIt() {
        // arrange
        let output = ByteBuffer()
        let spec = JianCommandSpec(help: "Global settings.", inputs: [
            JianInputSpec("config", kind: JianInputKind.ValueOption, metavar: "PATH", short: b'c', required: true)
        ])
        let app = JianApp(name: "demo", stdout: output).callback(HelpCallback(spec))

        // act
        let code = app.run(["--help"])

        // assert
        @Expect(code, 0)
        @Expect(String.fromUtf8(output.bytes()),
            "Usage: demo [OPTIONS]\n\nGlobal settings.\n\nOptions:\n" +
            "  -c, --config PATH  [required]\n  -h, --help  Show this message and exit.\n")
    }

    @TestCase[input in [["admin", "--help"], ["admin", "sync", "-h"]]]
    func nestedHelpUsesTheRootOutputAndFullInvocation(input: Array<String>) {
        // arrange
        let output = ByteBuffer()
        let childOutput = ByteBuffer()
        let errors = ByteBuffer()
        let child = JianApp(name: "admin", stdout: childOutput)
            .add(HelpCommand("sync", JianCommandSpec()))
        let app = JianApp(name: "demo", stdout: output, stderr: errors).add(child, name: "admin")

        // act
        let code = app.run(input)

        // assert
        @Expect(code, 0)
        @Expect(childOutput.bytes().isEmpty(), true)
        @Expect(errors.bytes().isEmpty(), true)
        let usage = if (input.size == 2) { "Usage: demo admin [OPTIONS] COMMAND [ARGS]...\n" }
            else { "Usage: demo admin sync [OPTIONS]\n" }
        let commands = if (input.size == 2) { "\nCommands:\n  sync\n" } else { "" }
        @Expect(String.fromUtf8(output.bytes()), usage + "\nOptions:\n  -h, --help  Show this message and exit.\n" + commands)
    }

    @TestCase[input in [["--times", "--help"], ["--times=--help"], ["-t", "-h"], ["-t-h"], ["--", "--help"]]]
    func helpLookingValuesAndOperandsStayWithTheCommand(input: Array<String>) {
        // arrange
        let output = ByteBuffer()
        let seen = ArrayList<String>()
        let app = JianApp(name: "demo", stdout: output)
            .add(HelpCommand("greet", greetingSpec(), action: { args => seen.add(all: args.remaining()); 7 }))

        // act
        let code = app.run(["greet"].concat(input))

        // assert
        @Expect(code, 7)
        @Expect(seen.toArray(), input)
        @Expect(output.bytes().isEmpty(), true)
    }

    @TestCase
    func appHelpLookingOptionValuesDoNotBypassCallbackOrCommand() {
        // arrange
        let output = ByteBuffer()
        let events = ArrayList<String>()
        let spec = JianCommandSpec(inputs: [JianInputSpec("config", kind: JianInputKind.ValueOption, metavar: "PATH", short: b'c')])
        let app = JianApp(name: "demo", stdout: output).callback(HelpCallback(spec, action: { args =>
            @Expect(args.next(), Some(JianArg.Long("config")))
            events.add(args.nextValue("--config"))
            JianCallbackResult.Continue
        })).add(HelpCommand("sync", JianCommandSpec(), action: { _ => events.add("sync"); 3 }))

        // act
        let code = app.run(["--config", "--help", "sync"])

        // assert
        @Expect(code, 3)
        @Expect(events.toArray(), ["--help", "sync"])
        @Expect(output.bytes().isEmpty(), true)
    }

    @TestCase[input in [["acme", "--help"], ["acme", "sync", "--help"], ["--", "acme", "--help"]]]
    func callbackPositionalsKeepAppAndCommandHelpInTheirOwnScope(input: Array<String>) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let events = ArrayList<String>()
        let spec = JianCommandSpec(inputs: [JianInputSpec("tenant", kind: JianInputKind.Positional, required: true)])
        let app = JianApp(name: "demo", stdout: output, stderr: errors)
            .callback(HelpCallback(spec, action: { args =>
                @Expect(args.next(), Some(JianArg.Operand("acme")))
                events.add("callback")
                JianCallbackResult.Continue
            })).add(HelpCommand("sync", JianCommandSpec()))

        // act
        let code = app.run(input)

        // assert
        if (input[0] == "--") {
            @Expect(code, 2)
            @Expect(events.toArray(), ["callback"])
            @Expect(output.bytes().isEmpty(), true)
            @Expect(String.fromUtf8(errors.bytes()),
                "Error: unknown command '--help'\nUsage: demo [OPTIONS] TENANT COMMAND [ARGS]...\n")
        } else if (input.size == 2) {
            @Expect(code, 0)
            @Expect(events.isEmpty(), true)
            @Expect(String.fromUtf8(output.bytes()),
                "Usage: demo [OPTIONS] TENANT COMMAND [ARGS]...\n\nArguments:\n  TENANT  [required]\n" +
                "\nOptions:\n  -h, --help  Show this message and exit.\n\nCommands:\n  sync\n")
        } else {
            @Expect(code, 0)
            @Expect(events.toArray(), ["callback"])
            @Expect(String.fromUtf8(output.bytes()),
                "Usage: demo sync [OPTIONS]\n\nOptions:\n  -h, --help  Show this message and exit.\n")
        }
    }

    @TestCase[index in 0..3]
    func usageErrorsShowTheSelectedCommandSpecAndExactMessage(index: Int64) {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let messages = [JianUsageException.unknownOption("--x"), JianUsageException.missingArgument("NAME"),
            JianUsageException.invalidValue("--times", "abc", "Int64")]
        let expected = ["unknown option '--x'", "missing argument 'NAME'", "invalid value 'abc' for '--times': expected Int64"]
        let app = JianApp(name: "demo", stdout: output, stderr: errors)
            .add(HelpCommand("greet", greetingSpec(), action: { _ => throw messages[index] }))

        // act
        let code = app.run(["greet"])

        // assert
        @Expect(code, 2)
        @Expect(output.bytes().isEmpty(), true)
        @Expect(String.fromUtf8(errors.bytes()), "Error: ${expected[index]}\nUsage: demo greet [OPTIONS] NAME [FILES...]\n")
    }
}
