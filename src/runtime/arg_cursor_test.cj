package jian.runtime

private func describe(arg: ?Arg): String {
    match (arg) {
        case None => "EOF"
        case Some(Arg.Long(name)) => "long:${name}"
        case Some(Arg.Long(name, value)) => "long:${name}=${value}"
        case Some(Arg.Short(name)) => "short:" + String.fromUtf8([name])
        case Some(Arg.Short(name, value)) => "short:" + String.fromUtf8([name]) + "=${value}"
        case Some(Arg.Operand(value)) => "operand:${value}"
    }
}

@Test
class ArgCursorTest {
    @TestCase[input in [
        (["cjpm", "init", "--name", "jian", "--type=dynamic"],
            ["operand:cjpm", "operand:init", "long:name", "operand:jian", "long:type=dynamic"]),
        (["--opt=v", "--opt=", "--opt=a=b", "--имя=да"], ["long:opt=v", "long:opt=", "long:opt=a=b", "long:имя=да"]),
        (["-n", "3", "-n=3", "-n3", "-n=", "-n", ""],
            ["short:n=3", "short:n=3", "short:n=3", "short:n=", "short:n="]),
        (["-abn3", "-abn", "3", "-nabc"],
            ["short:a", "short:b", "short:n=3", "short:a", "short:b", "short:n=3", "short:n=abc"]),
        (["-abc", "-a=", "-a=value"], ["short:a", "short:b", "short:c", "short:a=", "short:a=value"]),
        (["-n", "--", "-n", "-x", "-n", "--opt=v"], ["short:n=--", "short:n=-x", "short:n=--opt=v"]),
        (["-nПривет", "-n=Привет"], ["short:n=Привет", "short:n=Привет"]),
        (["-", "", "file", "--", "-a", "--x=v", "--", "-"],
            ["operand:-", "operand:", "operand:file", "operand:-a", "operand:--x=v", "operand:--", "operand:-"]),
        (["--"], []),
        ([], [])
    ]]
    func optionFormsPreserveValuesAndSplitClusters(input: (Array<String>, Array<String>)) {
        // arrange
        let (argv, expected) = input
        let cursor = ArgCursor(argv, shortsTakingValue: [b'n'])

        // act
        for (arg in expected) {
            let before = cursor.remaining()
            @Expect(arg, describe(cursor.peek()))
            @Expect(arg, describe(cursor.peek()))
            @Expect(before, cursor.remaining())
            @Expect(arg, describe(cursor.next()))
        }

        // assert
        @Expect("EOF", describe(cursor.peek()))
        @Expect("EOF", describe(cursor.next()))
        @Expect("EOF", describe(cursor.next()))
        @Expect([], cursor.remaining())
    }

    @TestCase[value in ["plain", "", "--", "-x", "--name=value", "-n", "-n=", "-abc"]]
    func longRequiredValueRemainsRawDespiteLookahead(value: String) {
        // arrange
        let cursor = ArgCursor(["--opt", value, "tail"], shortsTakingValue: [b'n'])
        @Expect("long:opt", describe(cursor.next()))

        // act
        // A declared short may fail lookahead, but it must still be usable as raw text.
        try {
            let _ = cursor.peek()
        } catch (error: UsageException) {
            @Expect("-n", value)
            @Expect("missing argument '-n'", error.message)
        }
        @Expect([value, "tail"], cursor.remaining())
        let actual = cursor.nextValue("--opt")

        // assert
        @Expect(value, actual)
        @Expect(["tail"], cursor.remaining())
        @Expect("operand:tail", describe(cursor.next()))
        @Expect("EOF", describe(cursor.next()))
    }

    @TestCase[input in [[], ["--"], ["last"]]]
    func lastArgumentAndEofHaveStableState(input: Array<String>) {
        // arrange
        let cursor = ArgCursor(input)
        let expected = if (input == ["last"]) { "operand:last" } else { "EOF" }

        // act
        @Expect(expected, describe(cursor.peek()))
        @Expect(expected, describe(cursor.peek()))
        @Expect(input, cursor.remaining())
        @Expect(expected, describe(cursor.next()))

        // assert
        @Expect([], cursor.remaining())
        @Expect("EOF", describe(cursor.peek()))
        @Expect("EOF", describe(cursor.next()))
        @Expect("EOF", describe(cursor.peek()))
    }

    @TestCase
    func clusterRemainderContainsOnlyUnconsumedSuffix() {
        // arrange
        let cursor = ArgCursor(["-abn=3", "tail"], shortsTakingValue: [b'n'])
        @Expect(["-abn=3", "tail"], cursor.remaining())

        // act
        @Expect("short:a", describe(cursor.next()))
        @Expect(["-bn=3", "tail"], cursor.remaining())
        @Expect("short:b", describe(cursor.peek()))
        @Expect(["-bn=3", "tail"], cursor.remaining())
        let child = ArgCursor(cursor.remaining(), shortsTakingValue: [b'n'])
        @Expect("short:b", describe(child.next()))
        @Expect("short:n=3", describe(child.next()))
        @Expect("operand:tail", describe(child.next()))
        @Expect("EOF", describe(child.next()))
        @Expect("short:b", describe(cursor.next()))
        @Expect(["-n=3", "tail"], cursor.remaining())
        @Expect("short:n=3", describe(cursor.peek()))
        @Expect(["-n=3", "tail"], cursor.remaining())
        @Expect("short:n=3", describe(cursor.next()))

        // assert
        @Expect(["tail"], cursor.remaining())
    }

    @TestCase
    func rawValueWithinClusterConsumesReconstructedSuffix() {
        // arrange
        let cursor = ArgCursor(["-abc", "tail"])
        let _ = cursor.next()
        let _ = cursor.peek()

        // act
        let value = cursor.nextValue("--opt")

        // assert
        @Expect("-bc", value)
        @Expect(["tail"], cursor.remaining())
        @Expect("operand:tail", describe(cursor.next()))
    }

    @TestCase[input in [
        ["child", "--name=", "-ab", "--", "-x"],
        ["child", "--", "--", "-"],
        ["child"]
    ]]
    func subcommandHandoffPreservesOriginalArguments(input: Array<String>) {
        // arrange
        let parent = ArgCursor(input)
        @Expect("operand:child", describe(parent.next()))

        // act
        let _ = parent.peek()
        let forwarded = parent.remaining()
        let child = ArgCursor(forwarded)

        // assert
        @Expect(input[1..], forwarded)
        @Expect(forwarded, child.remaining())
        @Expect(describe(parent.next()), describe(child.next()))
        @Expect(parent.remaining(), child.remaining())
    }

    @TestCase
    func endOfOptionsPersistsWhileAllFollowingArgumentsAreConsumed() {
        // arrange
        let cursor = ArgCursor(["--", "-a", "--", "-n"])

        // act
        @Expect("operand:-a", describe(cursor.peek()))
        @Expect(["--", "-a", "--", "-n"], cursor.remaining())
        @Expect("operand:-a", describe(cursor.next()))
        @Expect(["--", "-n"], cursor.remaining())
        @Expect("operand:--", describe(cursor.next()))
        @Expect("-n", cursor.nextValue("VALUE"))

        // assert
        @Expect("EOF", describe(cursor.next()))
    }

    @TestCase[input in [["-n"], ["-abn"]]]
    func missingShortValueThrowsWithoutConsumingInput(input: Array<String>) {
        // arrange
        let cursor = ArgCursor(input, shortsTakingValue: [b'n'])
        if (input[0] == "-abn") {
            let _ = cursor.next()
            let _ = cursor.next()
        }
        let before = cursor.remaining()

        // act
        var failures = 0
        for (_ in 0..2) {
            try { let _ = cursor.peek() } catch (error: UsageException) {
                @Expect("missing argument '-n'", error.message)
                failures++
            }
            try { let _ = cursor.next() } catch (_: UsageException) { failures++ }
        }

        // assert
        @Expect(4, failures)
        @Expect(before, cursor.remaining())
    }

    @TestCase[input in ["-é", "-aé"]]
    func nonAsciiShortNamesThrowUsageExceptionWithoutSplittingUtf8(input: String) {
        // arrange
        let cursor = ArgCursor([input])
        if (input == "-aé") {
            @Expect("short:a", describe(cursor.next()))
        }
        let before = cursor.remaining()
        var failures = 0

        // act
        try { let _ = cursor.peek() } catch (error: UsageException) {
            @Expect("unknown option '-é'", error.message)
            failures++
        }
        try { let _ = cursor.next() } catch (_: UsageException) { failures++ }

        // assert
        @Expect(2, failures)
        @Expect(before, cursor.remaining())
    }

    @TestCase
    func missingLongValueThrowsUsageExceptionAtStableEof() {
        // arrange
        let cursor = ArgCursor(["--opt"])
        let _ = cursor.next()
        var failures = 0

        // act
        for (_ in 0..2) {
            try { let _ = cursor.nextValue("--opt") } catch (error: UsageException) {
                @Expect("missing argument '--opt'", error.message)
                failures++
            }
        }

        // assert
        @Expect(2, failures)
        @Expect("EOF", describe(cursor.peek()))
        @Expect([], cursor.remaining())
    }
}
