// expect-error: expected 'Struct-JianOutput', found 'Struct-String'
package fixture

import jian.*

@JianCommand
func action(output!: JianOutput = JianCurrentOutput()) {}
func invalid() { action(output: "stdout") }
