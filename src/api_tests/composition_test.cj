package jian.api_tests

import jian.*
import std.io.ByteBuffer
import std.unittest.*
import std.unittest.testmacro.*

@JianContext
class ParentContext {
    public var child: TestContext
    public var replacement: ?TestContext = None
    public init(child: TestContext) { this.child = child }
}

let composedChild = JianContextApp<TestContext>()
    .callback(childContext).add(recordContext)
let composedApp = JianContextApp<ParentContext>(name: "demo")
    .add(composedChild, name: "users")

@JianCallback[composedApp]
func replaceChild(parent!: ParentContext = JianFromContext<ParentContext>()): JianCallbackResult {
    if (let Some(replacement) <- parent.replacement) { parent.child = replacement }
    JianCallbackResult.Continue
}

@Test
class CompositionTest {
    @TestCase
    func childExtractionUsesTheContextAfterTheParentCallback() {
        // arrange
        let original = ContextTrace()
        let replacement = ContextTrace()
        let parent = ParentContext(TestContext(original))
        parent.replacement = Some(TestContext(replacement))

        // act
        let code = composedApp.run(["users", "record-context", "hello"], context: parent)

        // assert
        @Expect(code, 7)
        @Expect(original.events, "")
        @Expect(replacement.events, "child;hello:false:-1;")
    }

    @TestCase
    func repeatedRunsExtractFromTheirOwnParentContext() {
        // arrange
        let first = ContextTrace()
        let second = ContextTrace()

        // act
        composedApp.run(["users", "record-context", "one"], context: ParentContext(TestContext(first)))
        composedApp.run(["users", "record-context", "two"], context: ParentContext(TestContext(second)))

        // assert
        @Expect(first.events, "child;one:false:-1;")
        @Expect(second.events, "child;two:false:-1;")
    }

    @TestCase
    func contextAppCanMountAnAppWithoutContext() {
        // arrange
        let child = JianApp().add(ContextlessTestCommand())
        let app = JianContextApp<ParentContext>().add(child, name: "plain")

        // act
        let code = app.run(["plain", "plain"], context: ParentContext(TestContext(ContextTrace())))

        // assert
        @Expect(code, 8)
    }

    @TestCase
    func projectedChildErrorsUseTheMountPathAndRootStream() {
        // arrange
        let errors = ByteBuffer()
        let app = JianContextApp<ParentContext>(name: "demo", stderr: errors)
            .add(composedChild, name: "people")

        // act
        let code = app.run(["people", "record-context"], context: ParentContext(TestContext(ContextTrace())))

        // assert
        @Expect(code, 2)
        @Expect(String.fromUtf8(errors.bytes()).contains("Usage: demo people record-context [OPTIONS] VALUE"), true)
    }

    @TestCase
    func cyclesAreRejectedAcrossDifferentContextTypes() {
        // arrange
        let child = JianContextApp<TestContext>()
        let parent = JianContextApp<ParentContext>().add(child, name: "users")

        // act
        let error = @AssertThrows[IllegalArgumentException](child.add(parent, name: "parent",
            context: { value: TestContext => ParentContext(value) }))

        // assert
        @Expect(error.message, "cyclic app mount 'parent'")
    }
}
