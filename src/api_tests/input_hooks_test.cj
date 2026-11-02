package jian.api_tests

import jian.*
import std.fs.Path
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private var hookEvents = ""
private var hookDefaults = 0
private func hookDefault(): Int64 { hookDefaults++; 2 }
private func hookTrim(raw: String): String {
    hookEvents += "raw;"
    let text = raw.trimAscii()
    if (text.isEmpty()) { throw JianInputException("must not be blank") }
    text
}
private func hookDouble(value: Int64): Int64 { hookEvents += "normalize;"; value * 2 }
private func hookPositive(value: Int64): Unit {
    hookEvents += "validate;"
    if (value <= 0) { throw JianInputException("must be positive") }
}
private func hookArray(values: Array<Int64>): Unit {
    hookEvents += "array:${values};"
}
private func hookOptional(value: ?Int64): Unit { hookEvents += "optional:${value};" }
private func hookFlag(value: Bool): Unit { hookEvents += "flag:${value};" }

@JianCommand
func hookCommand(path!: Path = JianArgument(preprocess: hookTrim),
    count!: Int64 = JianOption(default: hookDefault(), preprocess: hookTrim, normalize: hookDouble, validate: hookPositive),
    next!: Int64 = JianOption(default: count + 1),
    values!: Array<Int64> = JianOption(default: [], preprocess: hookTrim, validate: hookArray),
    optional!: ?Int64 = JianOption(validate: hookOptional),
    flag!: Bool = JianOption(default: false, preprocess: hookTrim, validate: hookFlag)): Int64 {
    hookEvents += "body:${path};"
    next
}

@JianCallback
func hookCallback(count!: Int64 = JianOption(default: 1, validate: hookPositive)): JianCallbackResult {
    hookEvents += "callback;"
    JianCallbackResult.Continue
}

private func hookUnexpected(_: Int64): Unit { throw IllegalStateException("hook bug") }
@JianCommand
func hookBroken(value!: Int64 = JianOption(default: 1, validate: hookUnexpected)): Int64 { value }

enum HookColor <: JianArgValue<HookColor> {
    | Red
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "COLOR" }
    public static func whenAbsent(): ?HookColor { None }
    public static func accept(_: ?HookColor, raw: ?String): HookColor {
        if (raw != Some("red")) { throw JianInvalidValueException(raw ?? "", "red") }
        HookColor.Red
    }
}
private func hookColor(_: HookColor): Unit { hookEvents += "color;" }
@JianCommand
func hookCustom(color!: HookColor = JianOption(preprocess: hookTrim, validate: hookColor)): Unit {
    let _ = color
    hookEvents += "body;"
}

private func raw(text: String): String { text.trimAscii() }
private func value(number: Int64): Int64 { number + 1 }
private func normalized(_: Int64): Unit {}
@JianCommand
func hookLexical(number!: Int64 = JianArgument(preprocess: raw, normalize: value, validate: normalized)): Int64 {
    number
}

@Test
class InputHooksTest {
    @TestCase
    func hookNamesResolveInTheirLexicalPackage() {
        // arrange
        let command = HookLexicalCommand()
        // act
        let code = command.run(JianArgCursor([" 3 "]))
        // assert
        @Expect(code, 4)
    }

    @TestCase
    func finalHooksObserveAccumulatedValuesAndLastOccurrenceBeforeLazyDefaults() {
        // arrange
        hookEvents = ""
        hookDefaults = 0
        // act
        let code = HookCommandCommand().run(JianArgCursor([" model ", "--count", " 0 ", "--count", "3",
            "--values", " 4 ", "--values", "5", "--flag"]))
        // assert
        @Expect(code, 7)
        @Expect(hookDefaults, 0)
        @Expect(hookEvents, "raw;raw;raw;raw;raw;normalize;validate;array:[4, 5];optional:None;flag:true;body:model;")
    }

    @TestCase
    func defaultsAreLazyAndValidatedAndDirectCallsBypassHooks() {
        // arrange
        hookEvents = ""
        hookDefaults = 0
        // act
        let code = HookCommandCommand().run(JianArgCursor(["model"]))
        // assert
        @Expect(code, 5)
        @Expect(hookDefaults, 1)
        @Expect(hookEvents, "raw;normalize;validate;array:[];optional:None;flag:false;body:model;")
        hookEvents = ""
        @Expect(hookCommand(path: Path(" direct "), count: -1), 0)
        @Expect(hookEvents, "body: direct ;")
        @Expect(hookDefaults, 1)
    }

    @TestCase
    func rejectionNamesInputAndStopsBodyWithUsageOnStderr() {
        // arrange
        hookEvents = ""
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stderr: errors).add(hookCommand)
        // act
        let code = app.run(["hook-command", "  "])
        // assert
        @Expect(code, 2)
        let text = String.fromUtf8(errors.bytes())
        @Expect(text.contains("'PATH': must not be blank"), true)
        @Expect(text.contains("Usage: test hook-command"), true)
        @Expect(hookEvents, "raw;")
        @Expect(app.run(["hook-command", "model", "--count", "0"]), 2)
        @Expect(hookEvents.contains("body:"), false)
    }

    @TestCase
    func callbackValidationRunsBeforeCallbackAndCommand() {
        // arrange
        hookEvents = ""
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stderr: errors).callback(hookCallback).add(hookCustom)
        // act
        let code = app.run(["--count", "0", "hook-custom", "--color", "red"])
        // assert
        @Expect(code, 2)
        @Expect(hookEvents, "validate;")
        @Expect(String.fromUtf8(errors.bytes()).contains("'--count': must be positive"), true)
        hookEvents = ""
        @Expect(app.run(["hook-custom", "--color", " red "]), 0)
        @Expect(hookEvents, "validate;callback;raw;color;body;")
    }

    @TestCase
    func helpAndMetadataExecuteNeitherHooksNorDefaults() {
        // arrange
        hookEvents = ""
        hookDefaults = 0
        let output = ByteBuffer()
        let app = JianApp(name: "test", stdout: output).add(hookCommand)
        // act
        let _ = HookCommandCommand().spec
        let code = app.run(["hook-command", "--help"])
        // assert
        @Expect(code, 0)
        @Expect(hookEvents, "")
        @Expect(hookDefaults, 0)
    }

    @TestCase
    func unrelatedExceptionsPropagate() {
        // arrange
        let app = JianApp(name: "test").add(hookBroken)
        var message = ""
        // act
        try { let _ = app.run(["hook-broken"]) }
        catch (error: IllegalStateException) { message = error.message }
        // assert
        @Expect(message, "hook bug")
    }
}

private func hookDerivedColor(color: PaintColor): Unit {
    match (color) {
        case PaintColor.DeepBlue => ()
        case _ => throw JianInputException("must be deep blue")
    }
}

@JianCommand
func hookDerived(color!: PaintColor = JianArgument(preprocess: raw, validate: hookDerivedColor)): Int64 {
    let _ = color
    9
}

@Test
class DerivedEnumHooksTest {
    @TestCase
    func derivedConversionComposesWithRawPreprocessingAndTypedValidation() {
        // arrange
        let errors = ByteBuffer()
        let app = JianApp(name: "test", stderr: errors).add(hookDerived)
        // act
        let accepted = app.run(["hook-derived", " deep-blue "])
        let rejected = app.run(["hook-derived", "red"])
        // assert
        @Expect(accepted, 9)
        @Expect(rejected, 2)
        @Expect(String.fromUtf8(errors.bytes()).contains("'COLOR': must be deep blue"), true)
    }
}
