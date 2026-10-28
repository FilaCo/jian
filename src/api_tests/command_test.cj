package jian.api_tests

import jian.*
import std.fs.Path
import std.unittest.*
import std.unittest.testmacro.*

private let privatePrefix = "private:"
private var observed = ""
private var defaultCalls = 0

private func dynamicDefault(): String {
    defaultCalls++
    "default"
}

@JianCommand[help: "A greeting"]
func greet_user(name: String, times!: Int64 = 2): Int64 {
    observed = name
    times
}

@JianCommand
func dependent(first: String, second!: String = privatePrefix + first): Unit {
    observed = second
}

@JianCommand
func implicit(loud!: Bool = false, jobs!: ?Int64): Unit {
    observed = "${loud}:${jobs ?? -1}"
}

@JianCommand
func collect(paths!: Array<String> = []): Int64 {
    observed = paths.toString()
    paths.size
}

@JianCommand
func lazy(value!: String = dynamicDefault()) {
    observed = value
}

@JianCommand
func `quoted_name`(): Int64 { 7 }

@JianCommand
func inferred() { 9 }

@JianCommand
func textDefault(value!: String = "hello"): Int64 { value.size }

@JianCommand
func requiredNumber(value!: Int64): Int64 { value }

type Switch = Bool
type MaybeJobs = ?Int64

@JianCommand
func aliases(enabled!: Switch = false, jobs!: MaybeJobs): Int64 {
    if (enabled) { jobs ?? 0 } else { -1 }
}

@JianCommand
func camelCase(): Int64 { 8 }

@JianCommand
func copyFiles(destination: String, files!: Array<Path> = JianArgument(default: []), verbose!: Bool = false): Int64 {
    observed = "${destination}:${files}:${verbose}"
    files.size
}

@JianCommand
func sumValues(values!: Array<Int64> = JianArgument(default: [])): Int64 {
    var total: Int64 = 0
    for (value in values) { total += value }
    total
}

@JianCommand
func overloaded(value: String): Int64 { value.size }

func overloaded(value: Int64): Int64 { value }

@Test
class CommandMacroTest {
    @TestCase
    func variadicPathsCollectRemainingOperandsAroundNamedOptions() {
        // arrange
        let command = CopyFilesCommand()

        // act
        let code = command.run(JianArgCursor(["out", "first", "--verbose", "second", "--", "--third"]))

        // assert
        @Expect(code, 3)
        @Expect(observed, "out:[first, second, --third]:true")
        @Expect(command.spec.inputs[1].repeatable, true)
        @Expect(command.spec.inputs[1].required, false)
        @Expect(command.spec.inputs[1].metavar, "PATH...")
        @Expect(command.run(JianArgCursor(["out"])), 0)
        @Expect(observed, "out:[]:false")
    }

    @TestCase
    func variadicElementsKeepTheirDeclaredTypeAndReportInvalidValues() {
        // arrange
        let command = SumValuesCommand()

        // act
        let total = command.run(JianArgCursor(["1", "2", "3"]))
        let invalid = @AssertThrows[JianUsageException](command.run(JianArgCursor(["1", "bad"])))

        // assert
        @Expect(total, 6)
        @Expect(command.run(JianArgCursor([])), 0)
        @Expect(invalid.message, "invalid value 'bad' for 'VALUES': expected Int64")
        @Expect(OverloadedCommand().run(JianArgCursor(["hello"])), 5)
    }

    @TestCase
    func generatesMetadataAndTypedPositionalAndNamedParsing() {
        // arrange
        let command = Greet_userCommand()

        // act
        let code = command.run(JianArgCursor(["Alice", "--times=4"]))

        // assert
        @Expect(code, 4)
        @Expect(observed, "Alice")
        @Expect(command.name, "greet-user")
        @Expect(command.spec.help, "A greeting")
        @Expect(command.spec.inputs[0].kind, JianInputKind.Positional)
        @Expect(command.spec.inputs[0].metavar, "TEXT")
        @Expect(command.spec.inputs[0].required, true)
        @Expect(command.spec.inputs[1].defaultShown, Some("2"))
        @Expect(command.spec.inputs[1].required, false)
        @Expect(command.run(JianArgCursor(["Bob"])), 2)
    }

    @TestCase
    func defaultsRetainEarlierParameterAndPrivateNames() {
        // arrange
        let command = DependentCommand()

        // act
        let code = command.run(JianArgCursor(["name"]))

        // assert
        @Expect(code, 0)
        @Expect(observed, "private:name")
        command.run(JianArgCursor(["name", "--second=explicit"]))
        @Expect(observed, "explicit")
    }

    @TestCase
    func explicitFlagDefaultAndOptionalValuesAllowAbsence() {
        // arrange
        let command = ImplicitCommand()

        // act
        command.run(JianArgCursor([]))

        // assert
        @Expect(observed, "false:-1")
        @Expect(command.spec.inputs[0].kind, JianInputKind.Flag)
        @Expect(command.spec.inputs[0].required, false)
        @Expect(command.spec.inputs[1].metavar, "INT")
        @Expect(command.spec.inputs[1].required, false)
        command.run(JianArgCursor(["--loud", "--jobs", "3"]))
        @Expect(observed, "true:3")
    }

    @TestCase
    func repeatedOptionsAccumulateInTheDeclaredArray() {
        // arrange
        let command = CollectCommand()

        // act
        let code = command.run(JianArgCursor(["--paths", "a", "--paths=b"]))

        // assert
        @Expect(code, 2)
        @Expect(observed, "[a, b]")
        @Expect(command.spec.inputs[0].repeatable, true)
        @Expect(command.spec.inputs[0].metavar, "TEXT...")
        @Expect(command.run(JianArgCursor([])), 0)
    }

    @TestCase
    func defaultsAreEvaluatedOnlyWhenAbsentAndHelpDoesNotRunThem() {
        // arrange
        defaultCalls = 0
        let command = LazyCommand()

        // act
        let metadata = command.spec
        let explicitCode = command.run(JianArgCursor(["--value=given"]))

        // assert
        @Expect((metadata.inputs[0].defaultShown ?? "").replace(" ", ""), "dynamicDefault()")
        @Expect(defaultCalls, 0)
        @Expect(explicitCode, 0)
        command.run(JianArgCursor([]))
        @Expect(defaultCalls, 1)
        @Expect(observed, "default")
    }

    @TestCase
    func namesPreserveFunctionSpellingForClassesAndUseKebabForCli() {
        // arrange
        let quoted = Quoted_nameCommand()
        let camel = CamelCaseCommand()

        // act
        let code = quoted.run(JianArgCursor([]))

        // assert
        @Expect(code, 7)
        @Expect(quoted.name, "quoted-name")
        @Expect(camel.name, "camel-case")
        @Expect(camel.run(JianArgCursor([])), 8)
    }

    @TestCase
    func aliasesPreserveFlagAndOptionalValueBehavior() {
        // arrange
        let command = AliasesCommand()

        // act
        let code = command.run(JianArgCursor(["--enabled", "--jobs=6"]))

        // assert
        @Expect(code, 6)
        @Expect(command.run(JianArgCursor([])), -1)
        @Expect(command.spec.inputs[0].kind, JianInputKind.Flag)
        @Expect(InferredCommand().run(JianArgCursor([])), 9)
        @Expect(TextDefaultCommand().run(JianArgCursor([])), 5)
        @Expect(TextDefaultCommand().spec.inputs[0].defaultShown, Some("\"hello\""))
    }

    @TestCase
    func malformedArgumentsReportUsageErrorsWithInputContext() {
        // arrange
        let command = Greet_userCommand()

        // act
        let missing = @AssertThrows[JianUsageException](command.run(JianArgCursor([])))
        let invalid = @AssertThrows[JianUsageException](command.run(JianArgCursor(["Alice", "--times=bad"])))
        let unknown = @AssertThrows[JianUsageException](command.run(JianArgCursor(["Alice", "--other"])))
        let missingValue = @AssertThrows[JianUsageException](command.run(JianArgCursor(["Alice", "--times"])))
        let namedMissing = @AssertThrows[JianUsageException](RequiredNumberCommand().run(JianArgCursor([])))
        let surplus = @AssertThrows[JianUsageException](command.run(JianArgCursor(["Alice", "Bob"])))

        // assert
        @Expect(missing.message, "missing argument 'NAME'")
        @Expect(namedMissing.message, "missing argument '--value'")
        @Expect(invalid.message, "invalid value 'bad' for '--times': expected Int64")
        @Expect(unknown.message, "unknown option '--other'")
        @Expect(missingValue.message, "missing argument '--times'")
        @Expect(surplus.message, "unexpected argument 'Bob'")
    }

}
