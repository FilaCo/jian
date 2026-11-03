// expect-error: expected 1 argument, found 0
package fixture

import jian.*

@JianCommand
func action(output!: JianOutput = JianCurrentOutput()) {}
func invalid() { action() }
