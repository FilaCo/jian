// expect-error: JianCurrentOutput requires parameter type JianOutput
package fixture
import jian.*
@JianCommand
func bad(output!: String = JianCurrentOutput()) {}
