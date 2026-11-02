package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

@JianCommand[name: "sum", aliases: ["add", "plus"], help: "Add numbers."]
func computeTotal(left: Int64, right!: Int64 = 2): Int64 { left + right }

private func dynamicAliases(left: String, right: String): Array<String> { [left, right + "2"] }

@JianCommand[aliases: dynamicAliases("d", "d")]
func dynamicallyNamed(): Int64 { 8 }

@JianCommand[name: "record", aliases: ["r"]]
func recordNamed(value: Int64, trace!: ContextTrace = JianFromContext<PrimaryContext>()): Int64 {
    trace.events += "command;"
    value
}

private let name = "global-name"
private let spec = "global-spec"

@JianCommand[name: name, aliases: [spec]]
func attributeBindings(): Int64 { 9 }

@Test
class CommandNamesTest {
    @TestCase[name in ["sum", "add", "plus"]]
    func allSpellingsUseTheTypedAdapter(name: String) {
        // arrange
        let app = JianApp().add(computeTotal)

        // act
        let code = app.run([name, "3", "--right=4"])

        // assert
        @Expect(code, 7)
        @Expect(computeTotal(3), 5)
        @Expect(ComputeTotalCommand().name, "sum")
        @Expect(ComputeTotalCommand().spec.aliases, ["add", "plus"])
    }

    @TestCase
    func explicitNamesReplaceDerivedNamesAndAliasesKeepTheirUsagePath() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "demo", stderr: errors).add(computeTotal)

        // act
        let oldName = app.run(["compute-total"])
        let invalid = app.run(["plus", "no"])

        // assert
        @Expect(oldName, 2)
        @Expect(invalid, 2)
        let text = String.fromUtf8(errors.bytes())
        @Expect(text.contains("unknown command 'compute-total'"), true)
        @Expect(text.contains("invalid value 'no' for 'LEFT'"), true)
        @Expect(text.contains("Usage: demo plus [OPTIONS] LEFT"), true)
    }

    @TestCase
    func helpListsAliasesOnceAndLooksUpTheirTypedTarget() {
        // arrange
        let output = ByteBuffer()
        let app = JianApp(name: "demo", stdout: output).add(computeTotal)

        // act
        @Expect(app.run(["help"]), 0)
        @Expect(app.run(["help", "plus"]), 0)

        // assert
        let text = String.fromUtf8(output.bytes())
        @Expect(text.contains("sum (aliases: add, plus)  Add numbers."), true)
        @Expect(text.contains("Usage: demo plus [OPTIONS] LEFT"), true)
    }
    @TestCase
    func dynamicAliasesAreValidatedFromTheirResultAtRegistration() {
        // arrange
        let app = JianApp().add(dynamicallyNamed)

        // act / assert
        @Expect(app.run(["d"]), 8)
        @Expect(app.run(["d2"]), 8)
    }

    @TestCase
    func contextCommandsShareAliasesAndHelpValidationDoesNotProjectContext() {
        // arrange
        let output = ByteBuffer()
        let errors = ByteBuffer()
        let trace = ContextTrace()
        let child = JianContextApp<PrimaryContext>().add(recordNamed)
        let app = JianContextApp<PrimaryContext>(name: "demo", stdout: output, stderr: errors)
            .add(child, name: "child", context: { context: PrimaryContext =>
                trace.events += "project;"; context
            })
        let context = PrimaryContext(trace)

        // act / assert
        @Expect(app.run(["help", "child", "r", "extra"], context: context), 2)
        @Expect(trace.events, "")
        @Expect(app.run(["help", "child", "r"], context: context), 0)
        @Expect(trace.events, "project;")
        @Expect(app.run(["child", "r", "6"], context: context), 6)
        @Expect(trace.events, "project;project;command;")
    }

    @TestCase
    func attributeExpressionsKeepTheirPackageBindings() {
        // arrange
        let app = JianApp().add(attributeBindings)

        // act / assert
        @Expect(app.run(["global-name"]), 9)
        @Expect(app.run(["global-spec"]), 9)
    }

}
