package jian.runtime

import std.collection.ArrayList

@Test
class ArgCursorTest {
    @TestCase[input in [
        (
            ["cjpm", "init", "--name", "jian", "--type=dynamic"],
            [Arg.Operand("cjpm"), Arg.Operand("init"), Arg.Long("name"), Arg.Operand("jian"), Arg.Long("type", "dynamic")]
        ),
        (
            ["--opt=v", "--opt=", "--opt=a=b", "--имя=да"],
            [Arg.Long("opt", "v"), Arg.Long("opt", ""), Arg.Long("opt", "a=b"), Arg.Long("имя", "да")]
        ),
        (
            ["-n", "3", "-n=3", "-n3", "-n=", "-n", ""],
            [Arg.Short(b'n', "3"), Arg.Short(b'n', "3"), Arg.Short(b'n', "3"), Arg.Short(b'n', ""), Arg.Short(b'n', "")]
        ),
        (
            ["-abn3", "-abn", "3", "-nabc"],
            [
                Arg.Short(b'a'), Arg.Short(b'b'), Arg.Short(b'n', "3"),
                Arg.Short(b'a'), Arg.Short(b'b'), Arg.Short(b'n', "3"), Arg.Short(b'n', "abc")
            ]
        ),
        (
            ["-abc", "-a=", "-a=value"],
            [Arg.Short(b'a'), Arg.Short(b'b'), Arg.Short(b'c'), Arg.Short(b'a', ""), Arg.Short(b'a', "value")]
        ),
        (
            ["-n", "--", "-n", "-x", "-n", "--opt=v"],
            [Arg.Short(b'n', "--"), Arg.Short(b'n', "-x"), Arg.Short(b'n', "--opt=v")]
        ),
        (
            ["-nПривет", "-n=Привет"],
            [Arg.Short(b'n', "Привет"), Arg.Short(b'n', "Привет")]
        ),
        (
            ["-", "", "file", "--", "-a", "--x=v", "--", "-"],
            [
                Arg.Operand("-"), Arg.Operand(""), Arg.Operand("file"), Arg.Operand("-a"),
                Arg.Operand("--x=v"), Arg.Operand("--"), Arg.Operand("-")
            ]
        ),
        (["--"], []),
        ([], [])
    ]]
    func optionFormsPreserveValuesAndSplitClusters(input: (Array<String>, Array<Arg>)) {
        // arrange
        let (argv, expected) = input
        let cursor = ArgCursor(argv, shortsTakingValue: [b'n'])

        // act
        let actual = ArrayList<Arg>()
        let firstPeek = ArrayList<Arg>()
        let secondPeek = ArrayList<Arg>()
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
        let cursor = ArgCursor(["--opt", value, "tail"], shortsTakingValue: [b'n'])
        let option = cursor.next()

        // act
        let _ = cursor.peek()
        let before = cursor.remaining()
        let actual = cursor.nextValue("--opt")
        let after = cursor.remaining()
        let tail = cursor.next()

        // assert
        @Expect(option, Some(Arg.Long("opt")))
        @Expect(before, [value, "tail"])
        @Expect(actual, value)
        @Expect(after, ["tail"])
        @Expect(tail, Some(Arg.Operand("tail")))
        @Expect(cursor.next(), None)
    }

    @TestCase
    func failedLookaheadLeavesARequiredValueAvailableAsRawText() {
        // arrange
        let cursor = ArgCursor(["--opt", "-n"], shortsTakingValue: [b'n'])
        let _ = cursor.next()

        // act
        let error = @AssertThrows[UsageException](cursor.peek())
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
        let cursor = ArgCursor(input)
        let expected = if (input.contains("last")) {
            Some(Arg.Operand("last"))
        } else if (input == ["-a"]) {
            Some(Arg.Short(b'a'))
        } else {
            None<Arg>
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
        let cursor = ArgCursor(argv, shortsTakingValue: [b'n'])
        let initial = cursor.remaining()
        let expectedLast = if (names[2] == b'n') { Arg.Short(b'n', "3") } else { Arg.Short(b'c') }

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
        @Expect(first, Some(Arg.Short(names[0])))
        @Expect(before, ["-" + argv[0][2..], "tail"])
        @Expect(firstPeek, Some(Arg.Short(names[1])))
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
        let cursor = ArgCursor(["-abc", "tail"])
        let _ = cursor.next()
        let _ = cursor.peek()

        // act
        let value = cursor.nextValue("--opt")
        let remaining = cursor.remaining()
        let tail = cursor.next()

        // assert
        @Expect(value, "-bc")
        @Expect(remaining, ["tail"])
        @Expect(tail, Some(Arg.Operand("tail")))
    }

    @TestCase[input in [
        ["child", "--name=", "-ab", "--", "-x"],
        ["child", "--", "--", "-"],
        ["child"]
    ]]
    func subcommandHandoffPreservesOriginalArguments(input: Array<String>) {
        // arrange
        let parent = ArgCursor(input)
        let command = parent.next()

        // act
        let _ = parent.peek()
        let forwarded = parent.remaining()
        let child = ArgCursor(forwarded)
        let initial = child.remaining()
        let parentArgs = ArrayList<Arg>()
        let childArgs = ArrayList<Arg>()
        while (let Some(arg) <- parent.next()) { parentArgs.add(arg) }
        while (let Some(arg) <- child.next()) { childArgs.add(arg) }

        // assert
        @Expect(command, Some(Arg.Operand("child")))
        @Expect(forwarded, input[1..])
        @Expect(initial, forwarded)
        @Expect(childArgs.toArray(), parentArgs.toArray())
        @Expect(child.remaining(), [])
        @Expect(parent.remaining(), [])
    }

    @TestCase
    func subcommandHandoffWithinAClusterPreservesOnlyUnconsumedFlags() {
        // arrange
        let parent = ArgCursor(["-abn=3", "tail"], shortsTakingValue: [b'n'])
        let _ = parent.next()
        let _ = parent.peek()

        // act
        let child = ArgCursor(parent.remaining(), shortsTakingValue: [b'n'])
        let args = ArrayList<Arg>()
        while (let Some(arg) <- child.next()) { args.add(arg) }

        // assert
        @Expect(args.toArray(), [Arg.Short(b'b'), Arg.Short(b'n', "3"), Arg.Operand("tail")])
        @Expect(parent.remaining(), ["-bn=3", "tail"])
        @Expect(child.remaining(), [])
    }

    @TestCase
    func endOfOptionsPersistsWhileAllFollowingArgumentsAreConsumed() {
        // arrange
        let cursor = ArgCursor(["--", "-a", "--", "-n"])

        // act
        let lookahead = cursor.peek()
        let before = cursor.remaining()
        let first = cursor.next()
        let after = cursor.remaining()
        let second = cursor.next()
        let value = cursor.nextValue("VALUE")

        // assert
        @Expect(lookahead, Some(Arg.Operand("-a")))
        @Expect(before, ["--", "-a", "--", "-n"])
        @Expect(first, lookahead)
        @Expect(after, ["--", "-n"])
        @Expect(second, Some(Arg.Operand("--")))
        @Expect(value, "-n")
        @Expect(cursor.next(), None)
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
        let firstPeek = @AssertThrows[UsageException](cursor.peek())
        let secondPeek = @AssertThrows[UsageException](cursor.peek())
        let firstNext = @AssertThrows[UsageException](cursor.next())
        let secondNext = @AssertThrows[UsageException](cursor.next())

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
        let cursor = ArgCursor([input])
        if (input == "-aé") {
            let _ = cursor.next()
        }
        let before = cursor.remaining()

        // act
        let peekError = @AssertThrows[UsageException](cursor.peek())
        let nextError = @AssertThrows[UsageException](cursor.next())

        // assert
        @Expect(peekError.message, "unknown option '-é'")
        @Expect(nextError.message, peekError.message)
        @Expect(cursor.remaining(), before)
    }

    @TestCase
    func missingLongValueThrowsUsageExceptionAtStableEof() {
        // arrange
        let cursor = ArgCursor(["--opt"])
        let _ = cursor.next()

        // act
        let first = @AssertThrows[UsageException](cursor.nextValue("--opt"))
        let second = @AssertThrows[UsageException](cursor.nextValue("--opt"))

        // assert
        @Expect(first.message, "missing argument '--opt'")
        @Expect(second.message, first.message)
        @Expect(cursor.peek(), None)
        @Expect(cursor.remaining(), [])
    }
}
