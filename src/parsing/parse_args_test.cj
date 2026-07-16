protected package jian.parsing

@Test
class ParseArgsTest {
    @TestCase
    func positionalOnly() {
        let specs: Array<ArgSpec> = [PosSpec(name: "target", help: None), PosSpec(name: "dest", help: None)]
        let result = parseArgs(["build", "out"], specs)
        @Expect("build", result.getRaw("target").getOrThrow())
        @Expect("out", result.getRaw("dest").getOrThrow())
    }

    @TestCase
    func longOptionOnly() {
        let specs: Array<ArgSpec> = [OptSpec(name: "verbose", long: "verbose")]
        let result = parseArgs(["--verbose"], specs)
        @Expect("true", result.getRaw("verbose").getOrThrow())
    }

    @TestCase
    func longOptionWithValue() {
        let specs: Array<ArgSpec> = [OptSpec(name: "output", long: "output")]
        let result = parseArgs(["--output=build"], specs)
        @Expect("build", result.getRaw("output").getOrThrow())
    }

    @TestCase
    func shortOption() {
        let specs: Array<ArgSpec> = [OptSpec(name: "verbose", short: b'v')]
        let result = parseArgs(["-v"], specs)
        @Expect("true", result.getRaw("verbose").getOrThrow())
    }

    @TestCase
    func shortOptionWithValue() {
        let specs: Array<ArgSpec> = [OptSpec(name: "output", short: b'o')]
        let result = parseArgs(["-o=file.txt"], specs)
        @Expect("file.txt", result.getRaw("output").getOrThrow())
    }

    @TestCase
    func positionalWithDefault() {
        let specs: Array<ArgSpec> = [PosSpec(name: "count", defaultValue: "42")]
        let result = parseArgs([], specs)
        @Expect("42", result.getRaw("count").getOrThrow())
    }

    @TestCase
    func optionWithDefault() {
        let specs: Array<ArgSpec> = [OptSpec(name: "jobs", long: "jobs", defaultValue: "4")]
        let result = parseArgs([], specs)
        @Expect("4", result.getRaw("jobs").getOrThrow())
    }

    @TestCase
    func mixedPositionalAndOptions() {
        let specs: Array<ArgSpec> = [PosSpec(name: "command", help: None),
                                     OptSpec(name: "release", long: "release"),
                                     OptSpec(name: "jobs", long: "jobs")]
        let result = parseArgs(["build", "--release", "--jobs=8"], specs)
        @Expect("build", result.getRaw("command").getOrThrow())
        @Expect("true", result.getRaw("release").getOrThrow())
        @Expect("8", result.getRaw("jobs").getOrThrow())
    }

    @TestCase
    func typedGet() {
        let specs: Array<ArgSpec> = [PosSpec(name: "count", defaultValue: "42")]
        let result = parseArgs([], specs)
        @Expect(42, result.get<Int64>("count"))
    }

    @TestCase
    func typedGetOr() {
        let result = parseArgs([], [])
        @Expect(10, result.getOr<Int64>("missing", 10))
    }
}
