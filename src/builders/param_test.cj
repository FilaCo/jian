package jian.builders

@Test
class ParamTest {
    @TestCase
    func itWorks() {
        // arrange
        let expected = Opt(name: "test", help: "test param", short: b't', long: "test")

        // act
        let actual = Param.builder("test").long("test").short(b't').help("test param").build()
    
        // assert
        @Expect(actual is Opt)
        @Expect(expected, actual)
        @Expect(expected.name, actual.name)
        @Expect(expected.help, actual.help)
        let actualOpt = (actual as Opt).getOrThrow()
        @Expect(expected.short, actualOpt.short)
        @Expect(expected.long, actualOpt.long)
    }

    @TestCase
    func testIfNamesAreEqualThenParamsAreEqual() {
        // arrange
        // act
        let lhs = Param.builder("test").long("first").short(b'f').help("first param").build()
        let rhs = Param.builder("test").long("second").short(b's').help("second param").build()
        
        // arrange
        @Expect(lhs, rhs)
    }
}