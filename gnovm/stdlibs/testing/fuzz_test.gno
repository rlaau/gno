package testing_test

import (
	"testing"
	"unicode/utf8"
)

// afl 퍼져의 주요 벤치마크는 크게 2개임
// symbolic guided: symbolic한 가이드를 받으며 깊은 depth나 분기를 뚫을 수 있는가
// find edge input: 기계적으로 edge input을 생성할 수 있는가.

// 퍼져의 주요 벤치마크크 중 "symbolic"한 특성 대한 test: 심볼릭한 경로를 제대로 탐색하는가를 측정.
// 깊은 path depth를 뚫어낼 수 있는지 test하는 함수
func FuzzSymbolicPath(f *testing.F) {
	f.Add("")
	f.Fuzz(func(t *testing.T, orig ...interface{}) {
		s, ok := orig[0].(string)
		if !ok {
			panic("dont match")
		}
		if len(s) > 0 && s[0] == 'b' {
			if len(s) > 1 && s[1] == 'a' {
				if len(s) > 2 && s[2] == 'd' {
					if len(s) > 3 && s[3] == '!' {
						panic("crash triggered")
					}
				}
			}
		}
	})
}

// 퍼져의 주요 기준 중 "edge"한 특성 대한 tets: edge case를 제대로 생성하는가를 측정.
// find edge input: 기계적으로 edge input을 생성할 수 있는가에 대한 함수.
// 그걸 위한 적절한 최소 genetic gen값과, 뮤테이션, 엣지케이스 정도가 만족해야 함.
// 물론, 유전 알고리즘의 최소 생성 개수를 240에서 2로, 최대 생성을 1920에서 190으로 낮추면, 위의 symbolicPath는 엄청 빨리 찾아짐
// 근데 그렇게 되면, 아래의 edgeCase를 찾지 못함.
// 유전알고리즘의 최소 생성 개수를 좁히면 조건분기에는 능숙한데, 반복문에서의 path폭증 시 그걸 대응하지 못함
// 또한 유전알고리즘의 최대 생성 개수를 줄이면 빠르게 변이를 늘릴 수 있지만, 고착화 문제가 생김
// 즉, 최대와 최소 생성개수에는 최솟값 제약이 걸림. 이것은 failing인풋을 찾는데 걸리는 시간이 길어지게 함.
// 그러나 그럼으로써 안정적인 시간 내에 웬만한 경우에 failing input을 찾도록 함.
// 범용적인 퍼져를 만들수록 퍼징 시간은 길어짐. 일종의 trade off임. (특히나 go의 경우 string값의 아주 넓기에...)
func FuzzEdgeCase(f *testing.F) {
	f.Add("apple hello", int(42131231230))
	f.Add("rainy day", int(98401132231331))
	f.Add("winter comes", int(12349123123))
	f.Fuzz(func(t *testing.T, orig ...interface{}) {
		v, ok := orig[0].(string)
		if !ok {
			panic("dont match")
		}
		i, ok2 := orig[1].(int)
		if !ok2 {
			panic("dont match")
		}
		rev := testing.Reverse(v)
		doubleRev := testing.Reverse(rev)
		if v != doubleRev && i > 300 && i < 500 {
			t.Errorf("Before: %q, after: %q", orig, doubleRev)
		}
		if utf8.ValidString(v) && !utf8.ValidString(rev) && i > 300 && i < 1000 {
			t.Errorf("Reverse produced invalid UTF-8 string %q", rev)
		}
	})
}
