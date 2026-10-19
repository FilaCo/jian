package jian.runtime

@Test
class UsageExceptionTest {
    @TestCase
    func eachFactoryNamesWhatIsWrong() {
        // arrange, act
        let unknown = UsageException.unknownOption("--x")
        let missing = UsageException.missingArgument("NAME")
        let invalid = UsageException.invalidValue("--times", "abc", "Int64")

        // assert
        @Expect(unknown.message, "unknown option '--x'")
        @Expect(missing.message, "missing argument 'NAME'")
        @Expect(invalid.message, "invalid value 'abc' for '--times': expected Int64")
    }
}
