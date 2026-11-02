// expect-error: duplicate JianOption setting 'validate'
package fixture
import jian.*
func check(_: Int64): Unit {}
@JianCommand
func example(value!: Int64 = JianOption(validate: check, validate: check)): Int64 { value }
