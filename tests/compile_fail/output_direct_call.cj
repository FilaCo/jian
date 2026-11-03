// expect-error: missing argument
package fixture
import jian.*
@JianCommand
func good(output!: JianOutput = JianCurrentOutput()) {}
func bad() { good() }
