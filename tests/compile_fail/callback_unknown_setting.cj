// expect-error: unknown JianCallback setting 'unknown'
package fixture
import jian.*
@JianCallback[unknown: true]
func bad(): Unit {}
