package main

import "testing/cov"

func main() {
	exampleSource := `package main

 		func anomFunc() int {
 			// 익명함수를 정의하고 바로 호출합니다.
 			result := (func(a int) int {
 				if a == 6 {
 					println("catch!")
 				}
 				println("Hello from Gno!!!!!!!!", a)
 				// 더 복잡한 코드 추가 가능
 				return 1
 			})(6)

 			println("std로 리턴:", result)
 			return 14
 		}`

	cov.GetCovOfSource(exampleSource)
}
