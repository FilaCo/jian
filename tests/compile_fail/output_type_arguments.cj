// expect-error: JianCurrentOutput takes no type arguments or arguments
package fixture
import jian.*
@JianCommand
func bad(output!: JianOutput = JianCurrentOutput<Int64>()) {}
