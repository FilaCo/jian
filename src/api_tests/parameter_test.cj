package jian.api_tests

import jian.*
import jian.runtime.Option as OptionMarker
import std.deriving.*
import std.unittest.*
import std.unittest.testmacro.*

@Derive[Equatable]
private struct ParamResult {
    ParamResult(let verbose: Bool, let quiet: Bool, let times: Int64) {}
}

private var paramResult = ParamResult(false, false, 0)

@Command
func paramOptions(verbose!: Bool = Option(short: 'v', help: "Verbose output", default: false),
    quiet!: Bool = Option(short: 'q', hidden: true, default: false),
    times!: Int64 = Option(short: 't', help: "Repetitions", default: 1)): Int64 {
    paramResult = ParamResult(verbose, quiet, times)
    times
}

@Command
func paramOperand(path!: String = Argument(help: "Input path", hidden: true)): Int64 { path.size }

@Command
func paramDefault(count!: Int64 = Option(default: 2)): Int64 { count }

@Test
class ParameterMarkerTest {
    @TestCase
    func carries_parameter_metadata_in_declaration_order() {
        // arrange
        let command = ParamOptionsCommand()

        // act
        let params = command.spec.params

        // assert
        @Expect(params[0].short, Some(b'v'))
        @Expect(params[0].help, "Verbose output")
        @Expect(params[0].hidden, false)
        @Expect(params[1].short, Some(b'q'))
        @Expect(params[1].hidden, true)
        @Expect(params[2].short, Some(b't'))
        @Expect(params[2].help, "Repetitions")
        @Expect(ParamOperandCommand().spec.params[0].help, "Input path")
        @Expect(ParamOperandCommand().spec.params[0].hidden, true)
        @Expect(ParamDefaultCommand().run(ArgCursor([])), 2)
        @Expect(ParamDefaultCommand().spec.params[0].short, None)
    }

    @TestCase
    func parses_flags_and_attached_values_from_short_clusters() {
        // arrange
        let app = App(name: "test").add(ParamOptionsCommand())

        // act
        let code = app.run(["param-options", "-vqt3"])

        // assert
        @Expect(code, 3)
        @Expect(paramResult, ParamResult(true, true, 3))
        @Expect(app.run(["param-options", "-t=4", "-v"]), 4)
        @Expect(paramResult, ParamResult(true, false, 4))
        @Expect(app.run(["param-options", "-t", "5", "--quiet"]), 5)
        @Expect(paramResult, ParamResult(false, true, 5))
    }
}

private var markerObserved = ""
private var markerDefaultCalls = 0
private let markerPrefix = "private:"

type MarkerMaybeInt = ?Int64

private func markerDefault(): String {
    markerDefaultCalls++
    "fallback"
}

@Command
func mixedMarkers(prefix: String,
    name!: String = Argument(help: "Name"),
    files!: Array<String> = Argument(default: [], help: "Files"),
    count!: Int64 = Option(short: 'c', default: 2),
    plain!: ?String): Int64 {
    markerObserved = "${prefix}:${name}:${files}:${plain ?? "none"}"
    count
}

@Command
func markerDefaults(first!: String = Argument(default: markerDefault()),
    second!: String = Option(default: markerPrefix + first)): Int64 {
    markerObserved = second
    second.size
}

@Command
func markerOptional(value!: MarkerMaybeInt = Option(),
    operand!: ?String = Argument(),
    fallback!: ?Int64 = Option(default: Some(3)),
    absent!: ?String = Option(default: None)): Int64 {
    markerObserved = "${operand ?? "none"}:${absent ?? "none"}"
    (value ?? 0) + (fallback ?? 0)
}

@Command
func requiredMarkers(flag!: Bool = Option(short: 'f'),
    paths!: Array<String> = Option(short: 'p')): Int64 {
    if (flag) { paths.size } else { 0 }
}

@Command
func requiredOperand(value!: String = Argument()): Int64 { value.size }

@Command
func requiredArray(values!: Array<Int64> = Argument()): Int64 { values.size }

@Callback
func markerConfigure(workspace!: String = Argument(help: "Workspace"),
    verbose!: Bool = Option(short: 'v', default: false),
    count!: Int64 = Option(short: 'c', default: 1)): Unit {
    markerObserved = "${workspace}:${verbose}:${count}"
}

private func unprocessedOption(value!: Int64 = OptionMarker(help: "Value")): Int64 { value }
private func unprocessedArgument(value!: String = Argument(default: "ignored")): String { value }

@Test
class ParameterBehaviorTest {
    @TestCase
    func combines_explicit_positionals_with_inferred_parameters_and_short_options() {
        // arrange
        let command = MixedMarkersCommand()
        let app = App(name: "test").add(command)

        // act
        let code = app.run(["mixed-markers", "prefix", "name", "a", "-c4", "b", "--plain=yes"])

        // assert
        @Expect(code, 4)
        @Expect(markerObserved, "prefix:name:[a, b]:yes")
        @Expect(command.spec.params[1].kind, ParamKind.Positional)
        @Expect(command.spec.params[1].required, true)
        @Expect(command.spec.params[2].repeatable, true)
        @Expect(command.spec.params[2].required, false)
        @Expect(mixedMarkers("direct", name: "name", plain: None), 2)
        @Expect(markerObserved, "direct:name:[]:none")
    }

    @TestCase
    func extracts_lazy_defaults_and_preserves_private_and_earlier_parameter_references() {
        // arrange
        markerDefaultCalls = 0
        let command = MarkerDefaultsCommand()

        // act
        let metadata = command.spec
        let explicitCode = command.run(ArgCursor(["given", "--second=explicit"]))

        // assert
        @Expect(metadata.params[0].defaultShown.getOrThrow().replace(" ", ""), "markerDefault()")
        @Expect(metadata.params[1].defaultShown.getOrThrow().replace(" ", ""), "markerPrefix+first")
        @Expect(markerDefaultCalls, 0)
        @Expect(explicitCode, 8)
        @Expect(command.run(ArgCursor(["given"])), 13)
        @Expect(markerObserved, "private:given")
        @Expect(markerDefaultCalls, 0)
        command.run(ArgCursor([]))
        @Expect(markerObserved, "private:fallback")
        @Expect(markerDefaultCalls, 1)
        markerDefaults()
        @Expect(markerObserved, "private:fallback")
        @Expect(markerDefaultCalls, 2)
    }

    @TestCase
    func optional_types_and_explicit_defaults_control_absence_including_aliases() {
        // arrange
        let command = MarkerOptionalCommand()

        // act
        let code = command.run(ArgCursor([]))

        // assert
        @Expect(code, 3)
        @Expect(markerObserved, "none:none")
        for (parameter in command.spec.params) {
            @Expect(parameter.required, false)
        }
        @Expect(command.spec.params[0].defaultShown, None)
        @Expect(command.spec.params[1].defaultShown, None)
        @Expect(command.spec.params[3].defaultShown, Some("None"))
        @Expect(command.run(ArgCursor(["text", "--value=4", "--fallback=5", "--absent=set"])), 9)
        @Expect(markerObserved, "text:set")
        @Expect(markerOptional(value: None, operand: None), 3)
    }

    @TestCase
    func nonoptional_flags_and_arrays_require_occurrences_without_explicit_defaults() {
        // arrange
        let command = RequiredMarkersCommand()

        // act
        let noFlag = @AssertThrows[UsageException](command.run(ArgCursor([])))
        let noPaths = @AssertThrows[UsageException](command.run(ArgCursor(["--flag"])))
        let noOperand = @AssertThrows[UsageException](RequiredOperandCommand().run(ArgCursor([])))
        let noArray = @AssertThrows[UsageException](RequiredArrayCommand().run(ArgCursor([])))

        // assert
        @Expect(noFlag.message, "missing argument '--flag'")
        @Expect(noPaths.message, "missing argument '--paths'")
        @Expect(noOperand.message, "missing argument 'VALUE'")
        @Expect(noArray.message, "missing argument 'VALUES'")
        @Expect(command.spec.params[0].required, true)
        @Expect(command.spec.params[1].required, true)
        @Expect(command.run(ArgCursor(["--flag", "--paths=a", "--paths=b"])), 2)
        @Expect(RequiredOperandCommand().run(ArgCursor(["name"])), 4)
        @Expect(RequiredArrayCommand().run(ArgCursor(["1", "2"])), 2)
        @Expect(requiredOperand(value: "direct"), 6)
    }

    @TestCase
    func callbacks_parse_marker_positionals_and_short_clusters_before_dispatch() {
        // arrange
        let callback = MarkerConfigureCallback()
        let app = App(name: "test").callback(callback).add(ParamDefaultCommand())

        // act
        let code = app.run(["project", "-vc3", "param-default"])

        // assert
        @Expect(code, 2)
        @Expect(markerObserved, "project:true:3")
        @Expect(callback.spec.params[0].kind, ParamKind.Positional)
        @Expect(callback.spec.params[0].help, "Workspace")
        @Expect(callback.spec.params[1].short, Some(b'v'))
        markerConfigure(workspace: "direct")
        @Expect(markerObserved, "direct:false:1")
    }

    @TestCase
    func markers_throw_when_evaluated_outside_command_or_callback_defaults() {
        // arrange
        let expectedOption = "Option must be a parameter default in @Command or @Callback"
        let expectedArgument = "Argument must be a parameter default in @Command or @Callback"

        // act
        let option = @AssertThrows[IllegalArgumentException](unprocessedOption())
        let argument = @AssertThrows[IllegalArgumentException](unprocessedArgument())
        let directOption = @AssertThrows[IllegalArgumentException](OptionMarker<Int64>(default: 1))
        let directArgument = @AssertThrows[IllegalArgumentException](Argument<String>())

        // assert
        @Expect(option.message, expectedOption)
        @Expect(argument.message, expectedArgument)
        @Expect(directOption.message, expectedOption)
        @Expect(directArgument.message, expectedArgument)
        @Expect(unprocessedOption(value: 7), 7)
        @Expect(unprocessedArgument(value: "explicit"), "explicit")
    }
}
