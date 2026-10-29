// expect-error: @JianCallback return type must be JianCallbackResult
package fixture

import jian.*

@JianCallback
func example(): Int64 { 0 }
