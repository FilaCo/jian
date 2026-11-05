// expect-error: JianCurrentOutput takes no type arguments or arguments
package fixture

import jian.*

@JianCommand
func invalid(output!: JianOutput = JianCurrentOutput<JianOutput>()) {}
