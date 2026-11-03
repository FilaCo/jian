// expect-error: mismatched types
package fixture
import jian.*
@JianCommand
func good(output!: JianOutput = JianCurrentOutput()) {}
func bad() { good(output: "wrong") }
