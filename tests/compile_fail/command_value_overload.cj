// expect-error: redefinition
package fixture
import jian.*
@JianCommand
func example(value: String): Unit {}
func example(value: Int64): Unit {}
