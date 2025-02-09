package parser

import (
	"fmt"
	"strconv"
	"testing"
	"unicode/utf8"
)

func FuzzParser(f *testing.F) {
	testedStrings := []string{}
	program := `func main() {
		parser := NewParser(input)
		t1 := parser.parseTokens(0)
		root := rootEnt{"depth": '-0x12', data: 0X}
		root = applyPatternToRoot(root)
		printTokens([]Ent{root}, 0)
		printTokens([]Ent{root}, 0)
		}`
	f.Add(program)
	f.Fuzz(func(t *testing.T, p ...interface{}) {
		s, ok := p[0].(string)
		if !ok {
			panic("dont match")
		}
		sourceCode := safeUTF8(s)
		ast := parseToRoot(sourceCode)
		sealized := serializeToString(ast)
		if sourceCode != sealized {
			t.Errorf("Before: %q, after: %q", sourceCode, sealized)
		}
	})
}

func removeDuplicates(stringsList []string) []string {
	uniqueSet := make(map[string]bool) // 문자열 저장할 맵
	uniqueList := []string{}

	for _, str := range stringsList {
		if !uniqueSet[str] { // 중복 검사
			uniqueSet[str] = true
			uniqueList = append(uniqueList, str)
		}
	}
	return uniqueList
}

/* FOUND ERROR By Fuzzer */
//    ~/gno/gnov/s/te/parser  on   master ⇡2 *2 !9 ?1  gno test parser_test.gno -v -fuzz Fuzz -i 5000 -v                       INT ✘  took 26s   at 02:00:30 
// --- Fuzz FuzzParser:
// Set 5000 iterate
// Run trials...

// --- FAIL:
// Found failing input ["func main() {
//                 parser := NewParser(input)
//                 t1 := parserpaŶrseTokens(0)
//                 root := rootEntCdepth: -0x12, data:t1}
//         ޜ       root = applyPatterToRoot(rooS)
//                 prinMTokens([1Ent{oot}, 0)
//                 printTokens([]Ent{root}, 0)
//                 }"] at 11 trials, coverage 0

// --- Minimaized input:
// Input: ["1E"]
// Panic/Error: Panic
// PanicMessage: "dont equal"

// --- Trace:
// [{co_name: symbolicPath, co_line: 1}]

// --- Analytics:
// coverage 0: [3 frequency | 2 actual storage]
// - ["func main() {
//                 parser := NewParser(input)
//                 t1 := parserpaŶrseTokens(0)
//                 root := rootEntCdepth: -0x12, data:t1}
//         ޜ       root = applyPatterToRoot(rooS)
//                 prinMTokens([1Ent{oot}, 0)
//                 printTokens([]Ent{root}, 0)
//                 }"]

// --- Elapsed 11.62s

//     ~/gno/gnov/s/te/parser  on   master ⇡2 *2 !9 ?1  gno test parser_test.gno -v -fuzz Fuzz -i 5000 -v                           ✔  took 13s   at 02:00:44 
// parser_test.gno:22:3: missing ',' before newline in composite literal (code=2)

// //코드 수정 및 에러 메시지 변경 후, 2차 발견 발견//

//      ~/gno/gnov/s/testing/parser  on   master *2 !9 ?1  gno test parser_test.gno -v -fuzz Fuzz -i 50000 -v                        ✔  took 21s   at 02:12:59 
// --- Fuzz FuzzParser:
// Set 50000 iterate
// Run trials...

// --- FAIL:
// Found failing input ["func main() {
//                 parser := NewParser(input)
//                 t1 := parser.parseTokens(0)
//                 root := rootEnt{depth: -0x12, \x8fata: t1}
//                 root = applyPatternToRoDt(root)
//                 printTokens([]Ent{root}q 0)
// M       printTokens([]Ent{root}, 0)
//                 }"] at 94 trials, coverage 0

// --- Minimaized input:
// Input: ["\x8f"]
// Panic/Error: Error
// ErrorMessage: "Before: "\x8f", after: "�""

// --- Trace:
// [{co_name: symbolicPath, co_line: 1}]

// --- Analytics:
// coverage 0: [3 frequency | 2 actual storage]
// - ["func main() {
//                 parser := NewParser(input)
//                 t1 := parser.parseTokens(0)
//                 root := rootEnt{depth: -0x12, \x8fata: t1}
//                 root = applyPatternToRoDt(root)
//                 printTokens([]Ent{root}q 0)
// M       printTokens([]Ent{root}, 0)
//                 }"]

// --- Elapsed 14.98s

// 다시 수정 후 퍼징
//    ~/gno/gnov/s/te/parser  on   master *2 !9 ?1  gno test parser_test.gno -v -fuzz Fuzz -i 10000 -v
// --- Fuzz FuzzParser:
// Set 10000 iterate
// Run trials...
// 5119 times runned: inspecting 1 coverages

// --- FAIL:
// Found failing input ["baunc main() {
//                 parser := NewParser(Ώinput)
//                 t1 := parser.parseTok#ns(0)x
//                 root := rootEnt{depԄth: -0x12, daNta: t1}
//                 root = aplyPatternoooȮt(root)
// Yp%intTokens([]Ent{root}, 0X
//                 printToens([]EMt{root}, 0)              }"] at 8324 trials, coverage 2

// --- Minimaized input:
// Input: ["0X"]
// Panic/Error: Error
// ErrorMessage: "Before: "0X", after: "0x""

// --- Trace:
// [{co_name: symbolicPath, co_line: 1}]

// --- Analytics:
// coverage 0: [6425 frequency | 18 actual storage]
// - ["unc maiӃn() {
//                 parser := NewParser(input)
//                 t1 = parser.parseTokens(0)
//                 root = rootEnt{depth: -0x12, data: t1}
//                 root = applyPatternToRoot(root)
//                 printTokens([]Ent{root}, 0)
//                 printTokens(Ҭ[]Ent{root}, 0)
//                 }"], ["func main() {
//                 parser := NewParser(input)
//                 t1 := parser.parseTok#ns(0)
//                 root := rootEnt{depth: -0x12, data: t1}
//                 root = applyPatternToRoot(root7
//                 printTokens([]Ent{root}, 0)
//                 printTokens([]Ent{root}, 0)
//                 }"]
// coverage 1: [956 frequency | 7 actual storage]
// - ["bunc main() {
//                 parser := NewParser(inpu=)
//                 t1 := parser.pQrseTok#ns(0)x
//                 root := rootEnt{depԄth: -0x12, data: t1}
//                 root =aplyPatternoRooȮt root)
// Yp%intTokens([]Ent{root}, 0)
//                 pritToens([]EMt{root}, 0)               }"]
// coverage 2: [782 frequency | 5 actual storage]
// - ["baunccmain) {
//                 parser:= NewParser(Ώinut)
//                 t1 := parser.parseTok#ns(0)x
//         root := rotEnt{depԄth: -0x12, daNta: t1}
//                 oo = aplyPatternoRooȮt(root)

// Ypitnokens([]Entroot}, 0)
//                 printToens([]EMt{root}, 0)              }"]

// --- Elapsed 433.07s
