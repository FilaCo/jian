package jian.api_tests

import jian.*
import std.deriving.*
import std.unittest.*
import std.unittest.testmacro.*

@Derive[Equatable]
private struct OptionResult {
    OptionResult(let verbose: Bool, let quiet: Bool, let times: Int64) {}
}

private var optionResult = OptionResult(false, false, 0)

@JianCommand
func optionMetadata(verbose!: Bool = JianOption(short: 'v', help: "Verbose output", default: false),
    quiet!: Bool = JianOption(short: 'q', hidden: true, default: false),
    times!: Int64 = JianOption(short: 't', help: "Repetitions", default: 1)): Int64 {
    optionResult = OptionResult(verbose, quiet, times)
    times
}

@JianCommand
func argumentMetadata(path!: String = JianArgument(help: "Input path", hidden: true)): Int64 { path.size }

@JianCommand
func optionDefault(count!: Int64 = JianOption(default: 2)): Int64 { count }

@Test
class ArgumentAndOptionMarkerTest {
    @TestCase
    func carriesArgumentAndOptionMetadataInDeclarationOrder() {
        // arrange
        let command = OptionMetadataCommand()

        // act
        let inputs = command.spec.inputs

        // assert
        @Expect(inputs[0].short, Some(b'v'))
        @Expect(inputs[0].help, "Verbose output")
        @Expect(inputs[0].hidden, false)
        @Expect(inputs[1].short, Some(b'q'))
        @Expect(inputs[1].hidden, true)
        @Expect(inputs[2].short, Some(b't'))
        @Expect(inputs[2].help, "Repetitions")
        @Expect(ArgumentMetadataCommand().spec.inputs[0].help, "Input path")
        @Expect(ArgumentMetadataCommand().spec.inputs[0].hidden, true)
        @Expect(OptionDefaultCommand().run(JianArgCursor([])), 2)
        @Expect(OptionDefaultCommand().spec.inputs[0].short, None)
    }

    @TestCase
    func parsesFlagsAndAttachedValuesFromShortClusters() {
        // arrange
        let app = JianApp(name: "test").add(OptionMetadataCommand())

        // act
        let code = app.run(["option-metadata", "-vqt3"])

        // assert
        @Expect(code, 3)
        @Expect(optionResult, OptionResult(true, true, 3))
        @Expect(app.run(["option-metadata", "-t=4", "-v"]), 4)
        @Expect(optionResult, OptionResult(true, false, 4))
        @Expect(app.run(["option-metadata", "-t", "5", "--quiet"]), 5)
        @Expect(optionResult, OptionResult(false, true, 5))
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

@JianCommand
func mixedMarkers(prefix: String,
    name!: String = JianArgument(help: "Name"),
    files!: Array<String> = JianArgument(default: [], help: "Files"),
    count!: Int64 = JianOption(short: 'c', default: 2),
    plain!: ?String): Int64 {
    markerObserved = "${prefix}:${name}:${files}:${plain ?? "none"}"
    count
}

@JianCommand
func markerDefaults(first!: String = JianArgument(default: markerDefault()),
    second!: String = JianOption(default: markerPrefix + first)): Int64 {
    markerObserved = second
    second.size
}

@JianCommand
func markerOptional(value!: MarkerMaybeInt = JianOption(),
    operand!: ?String = JianArgument(),
    fallback!: ?Int64 = JianOption(default: Some(3)),
    absent!: ?String = JianOption(default: None)): Int64 {
    markerObserved = "${operand ?? "none"}:${absent ?? "none"}"
    (value ?? 0) + (fallback ?? 0)
}

@JianCommand
func requiredMarkers(flag!: Bool = JianOption(short: 'f'),
    paths!: Array<String> = JianOption(short: 'p')): Int64 {
    if (flag) { paths.size } else { 0 }
}

@JianCommand
func requiredOperand(value!: String = JianArgument()): Int64 { value.size }

@JianCommand
func requiredArray(values!: Array<Int64> = JianArgument()): Int64 { values.size }

@JianCallback
func markerConfigure(workspace!: String = JianArgument(help: "Workspace"),
    verbose!: Bool = JianOption(short: 'v', default: false),
    count!: Int64 = JianOption(short: 'c', default: 1)): Unit {
    markerObserved = "${workspace}:${verbose}:${count}"
}

private func unprocessedOption(value!: Int64 = JianOption(help: "Value")): Int64 { value }
private func unprocessedArgument(value!: String = JianArgument(default: "ignored")): String { value }

@JianCommand
func optionalDefaults(value!: ?Int64 = JianOption(),
    operand!: Option<String> = JianArgument(),
    bare!: ?Bool,
    next!: Option<Int64>,
    explicit!: ?Int64 = JianOption(default: None)): Int64 {
    markerObserved = "${operand ?? "none"}:${bare ?? false}"
    (value ?? 0) + (next ?? 0) + (explicit ?? 0)
}

@JianCommand
func optionalAliasDefault(value!: MarkerMaybeInt = JianOption(default: None)): Int64 {
    value ?? 0
}

@JianCallback
func optionalCallback(value!: ?Int64 = JianOption(),
    operand!: Option<String> = JianArgument()): Unit {
    markerObserved = "${value ?? 0}:${operand ?? "none"}"
}

@Test
class ArgumentAndOptionBehaviorTest {
    @TestCase
    func optionalInputsHaveNoneDefaultsForDirectCallsAndCli() {
        // arrange
        let command = OptionalDefaultsCommand()

        // act
        let direct = optionalDefaults()

        // assert
        @Expect(direct, 0)
        @Expect(markerObserved, "none:false")
        @Expect(optionalDefaults(value: 2, operand: "name", bare: true, next: 3, explicit: 4), 9)
        @Expect(markerObserved, "name:true")
        @Expect(command.run(JianArgCursor([])), 0)
        @Expect(markerObserved, "none:false")
        @Expect(command.run(JianArgCursor(["text", "--value=2", "--next=3", "--explicit=4", "--bare"])), 9)
        @Expect(markerObserved, "text:true")
        for (input in command.spec.inputs) {
            @Expect(input.required, false)
            @Expect(input.defaultShown, Some("None"))
        }
        @Expect(optionalAliasDefault(), 0)
        @Expect(optionalAliasDefault(value: 7), 7)
    }

    @TestCase
    func callbacksShareImplicitNoneDefaultsWithCommands() {
        // arrange
        let callback = OptionalCallbackCallback()

        // act
        optionalCallback()

        // assert
        @Expect(markerObserved, "0:none")
        optionalCallback(value: 5, operand: "direct")
        @Expect(markerObserved, "5:direct")
        @Expect(callback.run(JianArgCursor([])), 0)
        @Expect(markerObserved, "0:none")
        @Expect(callback.run(JianArgCursor(["cli", "--value=3"])), 0)
        @Expect(markerObserved, "3:cli")
    }

    @TestCase
    func standardOptionTypeAndStaticMembersWorkWithoutImportAliases() {
        // arrange
        let value: Option<Int64> = Some(7)

        // act
        let absent = Option<Int64>.whenAbsent()
        let takesValue = Option<Int64>.takesValue()

        // assert
        @Expect(value, Some(7))
        @Expect(absent, Some(None))
        @Expect(takesValue, true)
    }

    @TestCase
    func combinesExplicitPositionalsWithInferredInputsAndShortOptions() {
        // arrange
        let command = MixedMarkersCommand()
        let app = JianApp(name: "test").add(command)

        // act
        let code = app.run(["mixed-markers", "prefix", "name", "a", "-c4", "b", "--plain=yes"])

        // assert
        @Expect(code, 4)
        @Expect(markerObserved, "prefix:name:[a, b]:yes")
        @Expect(command.spec.inputs[1].kind, JianInputKind.Positional)
        @Expect(command.spec.inputs[1].required, true)
        @Expect(command.spec.inputs[2].repeatable, true)
        @Expect(command.spec.inputs[2].required, false)
        @Expect(mixedMarkers("direct", name: "name", plain: None), 2)
        @Expect(markerObserved, "direct:name:[]:none")
    }

    @TestCase
    func extractsLazyDefaultsAndPreservesPrivateAndEarlierParameterReferences() {
        // arrange
        markerDefaultCalls = 0
        let command = MarkerDefaultsCommand()

        // act
        let metadata = command.spec
        let explicitCode = command.run(JianArgCursor(["given", "--second=explicit"]))

        // assert
        @Expect(metadata.inputs[0].defaultShown.getOrThrow().replace(" ", ""), "markerDefault()")
        @Expect(metadata.inputs[1].defaultShown.getOrThrow().replace(" ", ""), "markerPrefix+first")
        @Expect(markerDefaultCalls, 0)
        @Expect(explicitCode, 8)
        @Expect(command.run(JianArgCursor(["given"])), 13)
        @Expect(markerObserved, "private:given")
        @Expect(markerDefaultCalls, 0)
        command.run(JianArgCursor([]))
        @Expect(markerObserved, "private:fallback")
        @Expect(markerDefaultCalls, 1)
        markerDefaults()
        @Expect(markerObserved, "private:fallback")
        @Expect(markerDefaultCalls, 2)
    }

    @TestCase
    func optionalTypesAndExplicitDefaultsControlAbsenceIncludingAliases() {
        // arrange
        let command = MarkerOptionalCommand()

        // act
        let code = command.run(JianArgCursor([]))

        // assert
        @Expect(code, 3)
        @Expect(markerObserved, "none:none")
        for (input in command.spec.inputs) {
            @Expect(input.required, false)
        }
        @Expect(command.spec.inputs[0].defaultShown, None)
        @Expect(command.spec.inputs[1].defaultShown, Some("None"))
        @Expect(command.spec.inputs[3].defaultShown, Some("None"))
        @Expect(command.run(JianArgCursor(["text", "--value=4", "--fallback=5", "--absent=set"])), 9)
        @Expect(markerObserved, "text:set")
        @Expect(markerOptional(value: None), 3)
    }

    @TestCase
    func nonoptionalFlagsAndArraysRequireOccurrencesWithoutExplicitDefaults() {
        // arrange
        let command = RequiredMarkersCommand()

        // act
        let noFlag = @AssertThrows[JianUsageException](command.run(JianArgCursor([])))
        let noPaths = @AssertThrows[JianUsageException](command.run(JianArgCursor(["--flag"])))
        let noOperand = @AssertThrows[JianUsageException](RequiredOperandCommand().run(JianArgCursor([])))
        let noArray = @AssertThrows[JianUsageException](RequiredArrayCommand().run(JianArgCursor([])))

        // assert
        @Expect(noFlag.message, "missing argument '--flag'")
        @Expect(noPaths.message, "missing argument '--paths'")
        @Expect(noOperand.message, "missing argument 'VALUE'")
        @Expect(noArray.message, "missing argument 'VALUES'")
        @Expect(command.spec.inputs[0].required, true)
        @Expect(command.spec.inputs[1].required, true)
        @Expect(command.run(JianArgCursor(["--flag", "--paths=a", "--paths=b"])), 2)
        @Expect(RequiredOperandCommand().run(JianArgCursor(["name"])), 4)
        @Expect(RequiredArrayCommand().run(JianArgCursor(["1", "2"])), 2)
        @Expect(requiredOperand(value: "direct"), 6)
    }

    @TestCase
    func callbacksParseMarkerPositionalsAndShortClustersBeforeDispatch() {
        // arrange
        let callback = MarkerConfigureCallback()
        let app = JianApp(name: "test").callback(callback).add(OptionDefaultCommand())

        // act
        let code = app.run(["project", "-vc3", "option-default"])

        // assert
        @Expect(code, 2)
        @Expect(markerObserved, "project:true:3")
        @Expect(callback.spec.inputs[0].kind, JianInputKind.Positional)
        @Expect(callback.spec.inputs[0].help, "Workspace")
        @Expect(callback.spec.inputs[1].short, Some(b'v'))
        markerConfigure(workspace: "direct")
        @Expect(markerObserved, "direct:false:1")
    }

    @TestCase
    func markersThrowWhenEvaluatedOutsideCommandOrCallbackDefaults() {
        // arrange
        let expectedOption = "JianOption must be a function parameter default in @JianCommand or @JianCallback"
        let expectedArgument = "JianArgument must be a function parameter default in @JianCommand or @JianCallback"

        // act
        let option = @AssertThrows[IllegalArgumentException](unprocessedOption())
        let argument = @AssertThrows[IllegalArgumentException](unprocessedArgument())
        let directOption = @AssertThrows[IllegalArgumentException](JianOption<Int64>(default: 1))
        let directArgument = @AssertThrows[IllegalArgumentException](JianArgument<String>())

        // assert
        @Expect(option.message, expectedOption)
        @Expect(argument.message, expectedArgument)
        @Expect(directOption.message, expectedOption)
        @Expect(directArgument.message, expectedArgument)
        @Expect(unprocessedOption(value: 7), 7)
        @Expect(unprocessedArgument(value: "explicit"), "explicit")
    }
}
