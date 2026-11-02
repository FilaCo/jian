// expect-error: JianArgument settings must be named
package fixture
import jian.*
@JianCommand
func example(value!: Int64 = JianArgument({ value: Int64 => value })): Int64 { value }
