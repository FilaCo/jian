// expect-error: no matching function declaration
package fixture
import jian.*
func wrong(value: Bool): Bool { value }
@JianCommand
func example(value!: Int64 = JianOption(validate: wrong)): Int64 { value }
