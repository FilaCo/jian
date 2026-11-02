package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

private let declarativeRootOutput = ByteBuffer()
private let declarativeRootApp = JianApp(name: "files", stdout: declarativeRootOutput)
private let declarativeTypedRootApp = JianContextApp<TestContext>()
private let declarativePlainContextRootApp = JianContextApp<TestContext>()
private let declarativeNamedApp = JianApp()

@JianCommand[declarativeRootApp, root: true, help: "Count input files."]
func declarativeFiles(paths!: Array<String> = JianArgument(default: []), count!: Int64 = 2): Int64 {
    paths.size + count
}

@JianCommand[declarativeTypedRootApp, root: true]
func declarativeTyped(value: String, trace!: ContextTrace = JianFromContext<TestContext>()): Int64 {
    trace.events += value
    9
}

@JianCommand[declarativePlainContextRootApp, root: true]
func declarativePlain(value!: Int64 = 4): Int64 { value }

@JianCommand[declarativeNamedApp, root: false, name: "named", aliases: ["alias"]]
func declarativeNamed(): Int64 { 6 }

@Test
class RootRegistrationTest {
    @TestCase
    func registeredRootParsesOperandsWithoutACommandNameAndPreservesDirectCalls() {
        // arrange
        let args = ["help", "file", "--count=5"]

        // act
        let code = declarativeRootApp.run(args)
        let defaulted = declarativeRootApp.run([])
        let direct = declarativeFiles(paths: ["file"])

        // assert
        @Expect(code, 7)
        @Expect(defaulted, 2)
        @Expect(direct, 3)
    }

    @TestCase
    func registeredRootHelpUsesItsDescriptionAndHasNoCommandSelector() {
        // arrange
        let args = ["--help"]

        // act
        let code = declarativeRootApp.run(args)
        let message = String.fromUtf8(declarativeRootOutput.bytes())

        // assert
        @Expect(code, 0)
        @Expect(message.startsWith("Usage: files [OPTIONS] [PATHS...]"), true)
        @Expect(message.contains("Count input files."), true)
        @Expect(message.contains("COMMAND"), false)
    }

    @TestCase
    func registeredRootsReceiveTypedContextOrIgnoreItForPlainFunctions() {
        // arrange
        let trace = ContextTrace()
        let context = TestContext(trace)

        // act
        let typed = declarativeTypedRootApp.run(["hello"], context: context)
        let plain = declarativePlainContextRootApp.run([], context: context)

        // assert
        @Expect(typed, 9)
        @Expect(plain, 4)
        @Expect(trace.events, "hello")
    }

    @TestCase
    func rootFalsePreservesNamedCommandsAndAliases() {
        // arrange
        let args = ["alias"]

        // act
        let code = declarativeNamedApp.run(args)

        // assert
        @Expect(code, 6)
        @Expect(declarativeNamedApp.run(["named"]), 6)
    }
}
