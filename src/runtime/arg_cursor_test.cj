package jian.runtime

import std.collection.ArrayList

@Test
class ArgCursorTest {
    @TestCase[input in [
        (
            ["cjpm", "init", "--name", "jian", "--type=dynamic"],
            [JianArg.Operand("cjpm"), JianArg.Operand("init"), JianArg.Long("name"), JianArg.Operand("jian"), JianArg.Long("type", "dynamic")]
        ),
        (
            ["--opt=v", "--opt=", "--opt=a=b", "--имя=да"],
            [JianArg.Long("opt", "v"), JianArg.Long("opt", ""), JianArg.Long("opt", "a=b"), JianArg.Long("имя", "да")]
        ),
        (
            ["-n", "3", "-n=3", "-n3", "-n=", "-n", ""],
            [JianArg.Short(b'n', "3"), JianArg.Short(b'n', "3"), JianArg.Short(b'n', "3"), JianArg.Short(b'n', ""), JianArg.Short(b'n', "")]
        ),
        (
            ["-abn3", "-abn", "3", "-nabc"],
            [
                JianArg.Short(b'a'), JianArg.Short(b'b'), JianArg.Short(b'n', "3"),
                JianArg.Short(b'a'), JianArg.Short(b'b'), JianArg.Short(b'n', "3"), JianArg.Short(b'n', "abc")
            ]
        ),
        (
            ["-abc", "-a=", "-a=value"],
            [JianArg.Short(b'a'), JianArg.Short(b'b'), JianArg.Short(b'c'), JianArg.Short(b'a', ""), JianArg.Short(b'a', "value")]
        ),
        (
            ["-n", "--", "-n", "-x", "-n", "--opt=v"],
            [JianArg.Short(b'n', "--"), JianArg.Short(b'n', "-x"), JianArg.Short(b'n', "--opt=v")]
        ),
        (
            ["-nПривет", "-n=Привет"],
            [JianArg.Short(b'n', "Привет"), JianArg.Short(b'n', "Привет")]
        ),
        (
            ["-", "", "file", "--", "-a", "--x=v", "--", "-"],
            [
                JianArg.Operand("-"), JianArg.Operand(""), JianArg.Operand("file"), JianArg.Operand("-a"),
                JianArg.Operand("--x=v"), JianArg.Operand("--"), JianArg.Operand("-")
            ]
        ),
        (["--"], []),
        ([], [])
    ]]
    func optionFormsPreserveValuesAndSplitClusters(input: (Array<String>, Array<JianArg>)) {
        // arrange
        let (argv, expected) = input
        let cursor = JianArgCursor(argv, shortsTakingValue: [b'n'])

        // act
        let actual = ArrayList<JianArg>()
        let firstPeek = ArrayList<JianArg>()
        let secondPeek = ArrayList<JianArg>()
        let before = ArrayList<Array<String>>()
        let after = ArrayList<Array<String>>()
        while (let Some(arg) <- cursor.peek()) {
            before.add(cursor.remaining())
            firstPeek.add(arg)
            secondPeek.add(cursor.peek().getOrThrow())
            after.add(cursor.remaining())
            actual.add(cursor.next().getOrThrow())
        }

        // assert
        @Expect(actual.toArray(), expected)
        @Expect(firstPeek.toArray(), expected)
        @Expect(secondPeek.toArray(), expected)
        @Expect(after.toArray(), before.toArray())
        @Expect(cursor.peek(), None)
        @Expect(cursor.next(), None)
        @Expect(cursor.next(), None)
        @Expect(cursor.remaining(), [])
    }

    @TestCase[value in ["plain", "", "--", "-x", "--name=value", "-n", "-n=", "-abc"]]
    func longRequiredValueRemainsRawDespiteLookahead(value: String) {
        // arrange
        let cursor = JianArgCursor(["--opt", value, "tail"], shortsTakingValue: [b'n'])
        let option = cursor.next()

        // act
        let _ = cursor.peek()
        let before = cursor.remaining()
        let actual = cursor.nextValue("--opt")
        let after = cursor.remaining()
        let tail = cursor.next()

        // assert
        @Expect(option, Some(JianArg.Long("opt")))
        @Expect(before, [value, "tail"])
        @Expect(actual, value)
        @Expect(after, ["tail"])
        @Expect(tail, Some(JianArg.Operand("tail")))
        @Expect(cursor.next(), None)
    }

    @TestCase
    func failedLookaheadLeavesARequiredValueAvailableAsRawText() {
        // arrange
        let cursor = JianArgCursor(["--opt", "-n"], shortsTakingValue: [b'n'])
        let _ = cursor.next()

        // act
        let error = @AssertThrows[JianUsageException](cursor.peek())
        let before = cursor.remaining()
        let value = cursor.nextValue("--opt")

        // assert
        @Expect(error.message, "missing argument '-n'")
        @Expect(before, ["-n"])
        @Expect(value, "-n")
        @Expect(cursor.next(), None)
    }

    @TestCase[input in [[], ["--"], ["last"], ["--", "last"], ["-a"]]]
    func lastArgumentAndEofHaveStableState(input: Array<String>) {
        // arrange
        let cursor = JianArgCursor(input)
        let expected = if (input.contains("last")) {
            Some(JianArg.Operand("last"))
        } else if (input == ["-a"]) {
            Some(JianArg.Short(b'a'))
        } else {
            None<JianArg>
        }

        // act
        let firstPeek = cursor.peek()
        let secondPeek = cursor.peek()
        let before = cursor.remaining()
        let actual = cursor.next()
        let after = cursor.remaining()
        let eofPeek = cursor.peek()
        let firstEof = cursor.next()
        let secondEof = cursor.next()

        // assert
        @Expect(firstPeek, expected)
        @Expect(secondPeek, expected)
        @Expect(before, input)
        @Expect(actual, expected)
        @Expect(after, [])
        @Expect(eofPeek, None)
        @Expect(firstEof, None)
        @Expect(secondEof, None)
        @Expect(cursor.remaining(), [])
    }

    @TestCase[input in [
        (["-abc", "tail"], [b'a', b'b', b'c']),
        (["-abn=3", "tail"], [b'a', b'b', b'n'])
    ]]
    func clusterLookaheadPreservesTheUnconsumedSuffix(input: (Array<String>, Array<Byte>)) {
        // arrange
        let (argv, names) = input
        let cursor = JianArgCursor(argv, shortsTakingValue: [b'n'])
        let initial = cursor.remaining()
        let expectedLast = if (names[2] == b'n') { JianArg.Short(b'n', "3") } else { JianArg.Short(b'c') }

        // act
        let first = cursor.next()
        let before = cursor.remaining()
        let firstPeek = cursor.peek()
        let secondPeek = cursor.peek()
        let after = cursor.remaining()
        let second = cursor.next()
        let suffix = cursor.remaining()
        let last = cursor.next()

        // assert
        @Expect(initial, argv)
        @Expect(first, Some(JianArg.Short(names[0])))
        @Expect(before, ["-" + argv[0][2..], "tail"])
        @Expect(firstPeek, Some(JianArg.Short(names[1])))
        @Expect(secondPeek, firstPeek)
        @Expect(after, before)
        @Expect(second, firstPeek)
        @Expect(suffix, ["-" + argv[0][3..], "tail"])
        @Expect(last, Some(expectedLast))
        @Expect(cursor.remaining(), ["tail"])
    }

    @TestCase
    func rawValueWithinClusterConsumesReconstructedSuffix() {
        // arrange
        let cursor = JianArgCursor(["-abc", "tail"])
        let _ = cursor.next()
        let _ = cursor.peek()

        // act
        let value = cursor.nextValue("--opt")
        let remaining = cursor.remaining()
        let tail = cursor.next()

        // assert
        @Expect(value, "-bc")
        @Expect(remaining, ["tail"])
        @Expect(tail, Some(JianArg.Operand("tail")))
    }

    @TestCase[input in [
        ["child", "--name=", "-ab", "--", "-x"],
        ["child", "--", "--", "-"],
        ["child"]
    ]]
    func subcommandHandoffPreservesOriginalArguments(input: Array<String>) {
        // arrange
        let parent = JianArgCursor(input)
        let command = parent.next()

        // act
        let _ = parent.peek()
        let forwarded = parent.remaining()
        let child = JianArgCursor(forwarded)
        let initial = child.remaining()
        let parentArgs = ArrayList<JianArg>()
        let childArgs = ArrayList<JianArg>()
        while (let Some(arg) <- parent.next()) { parentArgs.add(arg) }
        while (let Some(arg) <- child.next()) { childArgs.add(arg) }

        // assert
        @Expect(command, Some(JianArg.Operand("child")))
        @Expect(forwarded, input[1..])
        @Expect(initial, forwarded)
        @Expect(childArgs.toArray(), parentArgs.toArray())
        @Expect(child.remaining(), [])
        @Expect(parent.remaining(), [])
    }

    @TestCase
    func subcommandHandoffWithinAClusterPreservesOnlyUnconsumedFlags() {
        // arrange
        let parent = JianArgCursor(["-abn=3", "tail"], shortsTakingValue: [b'n'])
        let _ = parent.next()
        let _ = parent.peek()

        // act
        let child = JianArgCursor(parent.remaining(), shortsTakingValue: [b'n'])
        let args = ArrayList<JianArg>()
        while (let Some(arg) <- child.next()) { args.add(arg) }

        // assert
        @Expect(args.toArray(), [JianArg.Short(b'b'), JianArg.Short(b'n', "3"), JianArg.Operand("tail")])
        @Expect(parent.remaining(), ["-bn=3", "tail"])
        @Expect(child.remaining(), [])
    }

    @TestCase
    func endOfOptionsPersistsWhileAllFollowingArgumentsAreConsumed() {
        // arrange
        let cursor = JianArgCursor(["--", "-a", "--", "-n"])

        // act
        let lookahead = cursor.peek()
        let before = cursor.remaining()
        let first = cursor.next()
        let after = cursor.remaining()
        let second = cursor.next()
        let value = cursor.nextValue("VALUE")

        // assert
        @Expect(lookahead, Some(JianArg.Operand("-a")))
        @Expect(before, ["--", "-a", "--", "-n"])
        @Expect(first, lookahead)
        @Expect(after, ["--", "-n"])
        @Expect(second, Some(JianArg.Operand("--")))
        @Expect(value, "-n")
        @Expect(cursor.next(), None)
    }

    @TestCase[input in [["-n"], ["-abn"]]]
    func missingShortValueThrowsWithoutConsumingInput(input: Array<String>) {
        // arrange
        let cursor = JianArgCursor(input, shortsTakingValue: [b'n'])
        if (input[0] == "-abn") {
            let _ = cursor.next()
            let _ = cursor.next()
        }
        let before = cursor.remaining()

        // act
        let firstPeek = @AssertThrows[JianUsageException](cursor.peek())
        let secondPeek = @AssertThrows[JianUsageException](cursor.peek())
        let firstNext = @AssertThrows[JianUsageException](cursor.next())
        let secondNext = @AssertThrows[JianUsageException](cursor.next())

        // assert
        @Expect(firstPeek.message, "missing argument '-n'")
        @Expect(secondPeek.message, firstPeek.message)
        @Expect(firstNext.message, firstPeek.message)
        @Expect(secondNext.message, firstPeek.message)
        @Expect(cursor.remaining(), before)
    }

    @TestCase[input in ["-é", "-aé"]]
    func nonAsciiShortNamesThrowUsageExceptionWithoutSplittingUtf8(input: String) {
        // arrange
        let cursor = JianArgCursor([input])
        if (input == "-aé") {
            let _ = cursor.next()
        }
        let before = cursor.remaining()

        // act
        let peekError = @AssertThrows[JianUsageException](cursor.peek())
        let nextError = @AssertThrows[JianUsageException](cursor.next())

        // assert
        @Expect(peekError.message, "unknown option '-é'")
        @Expect(nextError.message, peekError.message)
        @Expect(cursor.remaining(), before)
    }

    @TestCase
    func missingLongValueThrowsUsageExceptionAtStableEof() {
        // arrange
        let cursor = JianArgCursor(["--opt"])
        let _ = cursor.next()

        // act
        let first = @AssertThrows[JianUsageException](cursor.nextValue("--opt"))
        let second = @AssertThrows[JianUsageException](cursor.nextValue("--opt"))

        // assert
        @Expect(first.message, "missing argument '--opt'")
        @Expect(second.message, first.message)
        @Expect(cursor.peek(), None)
        @Expect(cursor.remaining(), [])
    }
}
