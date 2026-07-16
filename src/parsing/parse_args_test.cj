protected package jian.parsing

@Test
class ParseArgsTest {
    @TestCase
    func positionalOnly() {
        // arrange
        let specs: Array<ArgSpec> = [PosSpec(name: "target", help: None), PosSpec(name: "dest", help: None)]

        // act
        let result = parseArgs(["build", "out"], specs)

        // assert
        @Expect("build", result.getRaw("target").getOrThrow())
        @Expect("out", result.getRaw("dest").getOrThrow())
    }

    @TestCase
    func longOptionOnly() {
        // arrange
        let specs: Array<ArgSpec> = [OptSpec(name: "verbose", long: "verbose")]

        // act
        let result = parseArgs(["--verbose"], specs)

        // assert
        @Expect("true", result.getRaw("verbose").getOrThrow())
    }

    @TestCase
    func longOptionWithValue() {
        // arrange
        let specs: Array<ArgSpec> = [OptSpec(name: "output", long: "output")]

        // act
        let result = parseArgs(["--output=build"], specs)

        // assert
        @Expect("build", result.getRaw("output").getOrThrow())
    }

    @TestCase
    func shortOption() {
        // arrange
        let specs: Array<ArgSpec> = [OptSpec(name: "verbose", short: b'v')]

        // act
        let result = parseArgs(["-v"], specs)

        // assert
        @Expect("true", result.getRaw("verbose").getOrThrow())
    }

    @TestCase
    func shortOptionWithValue() {
        // arrange
        let specs: Array<ArgSpec> = [OptSpec(name: "output", short: b'o')]

        // act
        let result = parseArgs(["-o=file.txt"], specs)

        // assert
        @Expect("file.txt", result.getRaw("output").getOrThrow())
    }

    @TestCase
    func positionalWithDefault() {
        // arrange
        let specs: Array<ArgSpec> = [PosSpec(name: "count", defaultValue: "42")]

        // act
        let result = parseArgs([], specs)

        // assert
        @Expect("42", result.getRaw("count").getOrThrow())
    }

    @TestCase
    func optionWithDefault() {
        // arrange
        let specs: Array<ArgSpec> = [OptSpec(name: "jobs", long: "jobs", defaultValue: "4")]

        // act
        let result = parseArgs([], specs)

        // assert
        @Expect("4", result.getRaw("jobs").getOrThrow())
    }

    @TestCase
    func mixedPositionalAndOptions() {
        // arrange
        let specs: Array<ArgSpec> = [PosSpec(name: "command", help: None),
                                     OptSpec(name: "release", long: "release"),
                                     OptSpec(name: "jobs", long: "jobs")]

        // act
        let result = parseArgs(["build", "--release", "--jobs=8"], specs)

        // assert
        @Expect("build", result.getRaw("command").getOrThrow())
        @Expect("true", result.getRaw("release").getOrThrow())
        @Expect("8", result.getRaw("jobs").getOrThrow())
    }

    @TestCase
    func typedGet() {
        // arrange
        let specs: Array<ArgSpec> = [PosSpec(name: "count", defaultValue: "42")]

        // act
        let result = parseArgs([], specs)

        // assert
        @Expect(42, result.get<Int64>("count"))
    }

    @TestCase
    func typedGetOr() {
        // arrange & act
        let result = parseArgs([], [])

        // assert
        @Expect(10, result.getOr<Int64>("missing", 10))
    }
}
