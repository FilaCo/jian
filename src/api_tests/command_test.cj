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

@Command[help: "A greeting"]
func greet_user(name: String, times!: Int64 = 2): Int64 {
    observed = name
    times
}

@Command
func dependent(first: String, second!: String = privatePrefix + first): Unit {
    observed = second
}

@Command
func implicit(loud!: Bool = false, jobs!: ?Int64): Unit {
    observed = "${loud}:${jobs ?? -1}"
}

@Command
func collect(paths!: Array<String> = []): Int64 {
    observed = paths.toString()
    paths.size
}

@Command
func lazy(value!: String = dynamicDefault()) {
    observed = value
}

@Command
func `quoted_name`(): Int64 { 7 }

@Command
func inferred() { 9 }

@Command
func textDefault(value!: String = "hello"): Int64 { value.size }

@Command
func requiredNumber(value!: Int64): Int64 { value }

type Switch = Bool
type MaybeJobs = ?Int64

@Command
func aliases(enabled!: Switch = false, jobs!: MaybeJobs): Int64 {
    if (enabled) { jobs ?? 0 } else { -1 }
}

@Command
func camelCase(): Int64 { 8 }

@Command
func copyFiles(destination: String, files!: Array<Path> = Argument(default: []), verbose!: Bool = false): Int64 {
    observed = "${destination}:${files}:${verbose}"
    files.size
}

@Command
func sumValues(values!: Array<Int64> = Argument(default: [])): Int64 {
    var total: Int64 = 0
    for (value in values) { total += value }
    total
}

@Command
func overloaded(value: String): Int64 { value.size }

func overloaded(value: Int64): Int64 { value }

@Test
class CommandMacroTest {
    @TestCase
    func variadic_paths_collect_remaining_operands_around_named_options() {
        // arrange
        let command = CopyFilesCommand()

        // act
        let code = command.run(ArgCursor(["out", "first", "--verbose", "second", "--", "--third"]))

        // assert
        @Expect(code, 3)
        @Expect(observed, "out:[first, second, --third]:true")
        @Expect(command.spec.params[1].repeatable, true)
        @Expect(command.spec.params[1].required, false)
        @Expect(command.spec.params[1].metavar, "PATH...")
        @Expect(command.run(ArgCursor(["out"])), 0)
        @Expect(observed, "out:[]:false")
    }

    @TestCase
    func variadic_elements_keep_their_declared_type_and_report_invalid_values() {
        // arrange
        let command = SumValuesCommand()

        // act
        let total = command.run(ArgCursor(["1", "2", "3"]))
        let invalid = @AssertThrows[UsageException](command.run(ArgCursor(["1", "bad"])))

        // assert
        @Expect(total, 6)
        @Expect(command.run(ArgCursor([])), 0)
        @Expect(invalid.message, "invalid value 'bad' for 'VALUES': expected Int64")
        @Expect(OverloadedCommand().run(ArgCursor(["hello"])), 5)
    }

    @TestCase
    func generates_metadata_and_typed_positional_and_named_parsing() {
        // arrange
        let command = Greet_userCommand()

        // act
        let code = command.run(ArgCursor(["Alice", "--times=4"]))

        // assert
        @Expect(code, 4)
        @Expect(observed, "Alice")
        @Expect(command.name, "greet-user")
        @Expect(command.spec.help, "A greeting")
        @Expect(command.spec.params[0].kind, ParamKind.Positional)
        @Expect(command.spec.params[0].metavar, "TEXT")
        @Expect(command.spec.params[0].required, true)
        @Expect(command.spec.params[1].defaultShown, Some("2"))
        @Expect(command.spec.params[1].required, false)
        @Expect(command.run(ArgCursor(["Bob"])), 2)
    }

    @TestCase
    func defaults_retain_earlier_parameter_and_private_names() {
        // arrange
        let command = DependentCommand()

        // act
        let code = command.run(ArgCursor(["name"]))

        // assert
        @Expect(code, 0)
        @Expect(observed, "private:name")
        command.run(ArgCursor(["name", "--second=explicit"]))
        @Expect(observed, "explicit")
    }

    @TestCase
    func explicit_flag_default_and_optional_values_allow_absence() {
        // arrange
        let command = ImplicitCommand()

        // act
        command.run(ArgCursor([]))

        // assert
        @Expect(observed, "false:-1")
        @Expect(command.spec.params[0].kind, ParamKind.Flag)
        @Expect(command.spec.params[0].required, false)
        @Expect(command.spec.params[1].metavar, "INT")
        @Expect(command.spec.params[1].required, false)
        command.run(ArgCursor(["--loud", "--jobs", "3"]))
        @Expect(observed, "true:3")
    }

    @TestCase
    func repeated_options_accumulate_in_the_declared_array() {
        // arrange
        let command = CollectCommand()

        // act
        let code = command.run(ArgCursor(["--paths", "a", "--paths=b"]))

        // assert
        @Expect(code, 2)
        @Expect(observed, "[a, b]")
        @Expect(command.spec.params[0].repeatable, true)
        @Expect(command.spec.params[0].metavar, "TEXT...")
        @Expect(command.run(ArgCursor([])), 0)
    }

    @TestCase
    func defaults_are_evaluated_only_when_absent_and_help_does_not_run_them() {
        // arrange
        defaultCalls = 0
        let command = LazyCommand()

        // act
        let metadata = command.spec
        let explicitCode = command.run(ArgCursor(["--value=given"]))

        // assert
        @Expect((metadata.params[0].defaultShown ?? "").replace(" ", ""), "dynamicDefault()")
        @Expect(defaultCalls, 0)
        @Expect(explicitCode, 0)
        command.run(ArgCursor([]))
        @Expect(defaultCalls, 1)
        @Expect(observed, "default")
    }

    @TestCase
    func names_preserve_function_spelling_for_classes_and_use_kebab_for_cli() {
        // arrange
        let quoted = Quoted_nameCommand()
        let camel = CamelCaseCommand()

        // act
        let code = quoted.run(ArgCursor([]))

        // assert
        @Expect(code, 7)
        @Expect(quoted.name, "quoted-name")
        @Expect(camel.name, "camel-case")
        @Expect(camel.run(ArgCursor([])), 8)
    }

    @TestCase
    func aliases_preserve_flag_and_optional_value_behavior() {
        // arrange
        let command = AliasesCommand()

        // act
        let code = command.run(ArgCursor(["--enabled", "--jobs=6"]))

        // assert
        @Expect(code, 6)
        @Expect(command.run(ArgCursor([])), -1)
        @Expect(command.spec.params[0].kind, ParamKind.Flag)
        @Expect(InferredCommand().run(ArgCursor([])), 9)
        @Expect(TextDefaultCommand().run(ArgCursor([])), 5)
        @Expect(TextDefaultCommand().spec.params[0].defaultShown, Some("\"hello\""))
    }

    @TestCase
    func malformed_arguments_report_usage_errors_with_parameter_context() {
        // arrange
        let command = Greet_userCommand()

        // act
        let missing = @AssertThrows[UsageException](command.run(ArgCursor([])))
        let invalid = @AssertThrows[UsageException](command.run(ArgCursor(["Alice", "--times=bad"])))
        let unknown = @AssertThrows[UsageException](command.run(ArgCursor(["Alice", "--other"])))
        let missingValue = @AssertThrows[UsageException](command.run(ArgCursor(["Alice", "--times"])))
        let namedMissing = @AssertThrows[UsageException](RequiredNumberCommand().run(ArgCursor([])))
        let surplus = @AssertThrows[UsageException](command.run(ArgCursor(["Alice", "Bob"])))

        // assert
        @Expect(missing.message, "missing argument 'NAME'")
        @Expect(namedMissing.message, "missing argument '--value'")
        @Expect(invalid.message, "invalid value 'bad' for '--times': expected Int64")
        @Expect(unknown.message, "unknown option '--other'")
        @Expect(missingValue.message, "missing argument '--times'")
        @Expect(surplus.message, "unexpected argument 'Bob'")
    }

}
