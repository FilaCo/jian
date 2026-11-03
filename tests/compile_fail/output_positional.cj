// expect-error: expected ',' or ')', found '='
package fixture

import jian.*

@JianCommand
func invalid(output: JianOutput = JianCurrentOutput()) {}
