package jian.builders

import jian.parsing.parseArgs

@Test
class AppTest {
    @TestCase
    func buildProducesAppWithCommands() {
        // arrange
        let cmd = Command.builder("greet")
            .invoke({ _ => () })
            .build()

        // act
        let app = App.builder()
            .add((cmd as Command).getOrThrow())
            .build()

        // assert
        @Expect(app.commands.contains("greet"))
    }

    @TestCase
    func buildProducesEmptyApp() {
        // arrange
        let app = App.builder().build()

        // assert
        @Expect(!app.commands.contains("nonexistent"))
    }

    @TestCase
    func commandLineReturnsBuilder() {
        // act
        let builder = commandLine()

        // assert
        @Expect(builder is AppBuilder)
    }

    @TestCase
    func runDispatchesCommand() {
        // arrange
        let called = Box<Bool>(false)
        let cmd = Command.builder("test")
            .invoke({ _ => called.value = true })
            .build()

        // act
        let app = App.builder()
            .add((cmd as Command).getOrThrow())
            .build()
        let dispatched = app.commands["test"]
        dispatched.invoke(parseArgs([], []))

        // assert
        @Expect(called.value)
    }
}