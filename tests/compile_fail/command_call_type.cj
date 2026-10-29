// expect-error: mismatched types
package fixture
import jian.*
@JianCommand
func example(value: Int64): Int64 { value }
func direct(): Unit { example.call("wrong") }
