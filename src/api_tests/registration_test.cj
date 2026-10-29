package jian.api_tests

import jian.*
import std.unittest.*
import std.unittest.testmacro.*

private var registeredDefaultCalls = 0
private func registeredDefault(): Int64 {
    registeredDefaultCalls++
    6
}

@JianCommand[app: registeredUsers]
func registeredLazy(value!: Int64 = registeredDefault()): Int64 { value }

@JianCallback[app: registeredUsers]
func registeredSettings(stop!: Int64 = 0): Int64 { stop }

@JianCommand[app: registeredUsers, help: "Add two numbers"]
func registeredAdd(value: Int64, amount!: Int64 = 4): Int64 { value + amount }

@JianCommand[app: registeredUsers]
func registeredIdentity(value: Int64): Int64 { value }

@Test
class RegistrationTest {
    @TestCase
    func commandsInAnotherFileRegisterIntoAnAlreadyMountedApp() {
        // arrange
        let args = ["users", "registered-add", "3", "--amount=5"]

        // act
        let code = registeredApp.run(args)

        // assert
        @Expect(code, 8)
    }

    @TestCase
    func registeredCallbacksCanStopCommands() {
        // arrange
        let args = ["users", "--stop=7", "registered-add", "3"]

        // act
        let code = registeredApp.run(args)

        // assert
        @Expect(code, 7)
    }

    @TestCase
    func registeredFunctionsPreserveDefaultsAndFunctionValues() {
        // arrange
        let identity: (Int64) -> Int64 = registeredIdentity

        // act
        let defaulted = registeredAdd(3)
        let explicit = registeredAdd(3, amount: 5)
        let fromFunctionValue = identity(9)

        // assert
        @Expect(defaulted, 7)
        @Expect(explicit, 8)
        @Expect(fromFunctionValue, 9)
    }

    @TestCase
    func registrationDoesNotEvaluateFunctionDefaults() {
        // arrange
        let callsAfterRegistration = registeredDefaultCalls

        // act
        let explicit = registeredApp.run(["users", "registered-lazy", "--value=5"])
        let callsAfterExplicit = registeredDefaultCalls
        let defaulted = registeredApp.run(["users", "registered-lazy"])

        // assert
        @Expect(callsAfterRegistration, 0)
        @Expect(explicit, 5)
        @Expect(callsAfterExplicit, 0)
        @Expect(defaulted, 6)
        @Expect(registeredDefaultCalls, 1)
    }

}
