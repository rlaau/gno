package main

import (
	"fmt"
	"strings"
	"unicode"
)

// ─────────────────────────────
//  1. Ent 인터페이스
//     setDepth(d int), getDepth() int
//
// ─────────────────────────────
type Ent interface {
	setDepth(d int)
	getDepth() int
}

// ─────────────────────────────
// 2) 구조체들 & 인터페이스 구현
// ─────────────────────────────

// alphaEnt
type alphaEnt struct {
	data  string
	depth int
}

func (a *alphaEnt) setDepth(d int) { a.depth = d }
func (a *alphaEnt) getDepth() int  { return a.depth }

// numEnt
type numEnt struct {
	data  string
	hex   bool
	depth int
}

func (n *numEnt) setDepth(d int) { n.depth = d }
func (n *numEnt) getDepth() int  { return n.depth }

// wsEnt
type wsEnt struct {
	data  string
	depth int
}

func (w *wsEnt) setDepth(d int) { w.depth = d }
func (w *wsEnt) getDepth() int  { return w.depth }

// markEnt
type markEnt struct {
	data  string
	depth int
}

func (m *markEnt) setDepth(d int) { m.depth = d }
func (m *markEnt) getDepth() int  { return m.depth }

// keyValEnt: key, 구분자, value를 하나로 묶은 엔티티
type keyValEnt struct {
	depth     int
	k         Ent
	plOrNil   Ent
	prOrNil   Ent
	delimiter Ent
	v         Ent
}

func (kv *keyValEnt) setDepth(d int) { kv.depth = d }
func (kv *keyValEnt) getDepth() int  { return kv.depth }

// groupEnt: 괄호를 그룹화
type groupEnt struct {
	data      []Ent
	depth     int
	isPattern bool
}

func (g *groupEnt) setDepth(d int) { g.depth = d }
func (g *groupEnt) getDepth() int  { return g.depth }

// rootEnt: 최상위 (패턴 판단)
type rootEnt struct {
	data      []Ent
	depth     int
	isPattern bool
	pattern   string
}

func (r *rootEnt) setDepth(d int) { r.depth = d }
func (r *rootEnt) getDepth() int  { return r.depth }

// ─────────────────────────────
// 3) 전역 설정 (mark 목록, bracket)
var parserMark = []string{
	"\r\n", "\n", "\t", "//", "&&", "||",
	"&", "|", ".", "?", "@", "!", "#", "$", "%", "^",
	"or", "OR", "and", "AND", "/", "://", ":=", "=", ":",
}

var bracketPairs = map[rune]rune{
	'(': ')',
	'{': '}',
	'[': ']',
}

// ─────────────────────────────
// 4) Lexer: 문자열 → 기본 토큰
// ─────────────────────────────
type Lexer struct {
	input []rune
	pos   int
}

func NewLexer(s string) *Lexer {
	return &Lexer{[]rune(s), 0}
}

func (lx *Lexer) eof() bool {
	return lx.pos >= len(lx.input)
}

func (lx *Lexer) peek() rune {
	if lx.eof() {
		return 0
	}
	return lx.input[lx.pos]
}

func (lx *Lexer) next() rune {
	if lx.eof() {
		return 0
	}
	ch := lx.input[lx.pos]
	lx.pos++
	return ch
}

func (lx *Lexer) matchString(s string) bool {
	if lx.pos+len(s) > len(lx.input) {
		return false
	}
	for i, r := range s {
		if lx.input[lx.pos+i] != r {
			return false
		}
	}
	return true
}

func sortMarksByLengthDesc(marks []string) []string {
	cp := make([]string, len(marks))
	copy(cp, marks)
	for i := 0; i < len(cp)-1; i++ {
		for j := 0; j < len(cp)-1-i; j++ {
			if len(cp[j]) < len(cp[j+1]) {
				cp[j], cp[j+1] = cp[j+1], cp[j]
			}
		}
	}
	return cp
}

// Lex(): 전체 문자열 → (depth=0) 토큰
func (lx *Lexer) Lex() []Ent {
	var tokens []Ent
	for !lx.eof() {
		t := lx.nextToken()
		if t != nil {
			t.setDepth(0) // lexer 단계: 일단 모두 depth=0
			tokens = append(tokens, t)
		}
	}
	return tokens
}

func (lx *Lexer) nextToken() Ent {
	ch := lx.peek()
	// 1) 줄바꿈
	if ch == '\n' {
		lx.next()
		return &markEnt{data: "\n"}
	}
	// 2) 공백
	if unicode.IsSpace(ch) {
		var sb strings.Builder
		for !lx.eof() && unicode.IsSpace(lx.peek()) && lx.peek() != '\n' {
			sb.WriteRune(lx.next())
		}
		return &wsEnt{data: sb.String()}
	}
	// 3) 숫자 / - 부호
	if unicode.IsDigit(ch) || ch == '-' {
		return lx.lexNumber()
	}
	// 4) 알파벳
	if unicode.IsLetter(ch) {
		var sb strings.Builder
		for !lx.eof() && (unicode.IsLetter(lx.peek()) ||
			unicode.IsDigit(lx.peek()) || lx.peek() == '_') {
			sb.WriteRune(lx.next())
		}
		return &alphaEnt{data: sb.String()}
	}
	// 5) 다중문자 마커
	sorted := sortMarksByLengthDesc(parserMark)
	for _, mk := range sorted {
		if lx.matchString(mk) {
			lx.pos += len(mk)
			return &markEnt{data: mk}
		}
	}
	// 6) 그 외 1글자
	return &markEnt{data: string(lx.next())}
}

// 숫자 처리: -12, 1e12, 0x16 ...
func (lx *Lexer) lexNumber() Ent {
	sign := ""
	if !lx.eof() && lx.peek() == '-' {
		sign = "-"
		lx.next()
	}
	// 0x?
	if !lx.eof() && lx.peek() == '0' {
		if lx.pos+1 < len(lx.input) &&
			(lx.input[lx.pos+1] == 'x' || lx.input[lx.pos+1] == 'X') {
			lx.next() // '0'
			lx.next() // 'x'
			hexDigits := ""
			for !lx.eof() {
				ch := lx.peek()
				if (ch >= '0' && ch <= '9') ||
					(ch >= 'a' && ch <= 'f') ||
					(ch >= 'A' && ch <= 'F') {
					hexDigits += string(ch)
					lx.next()
				} else {
					break
				}
			}
			if hexDigits == "" {
				return &numEnt{data: sign + "0x", hex: false}
			}
			return &numEnt{data: sign + "0x" + hexDigits, hex: true}
		}
	}
	// 10진수
	digits := ""
	for !lx.eof() && unicode.IsDigit(lx.peek()) {
		digits += string(lx.next())
	}
	if digits == "" {
		// -만 있었음
		return &markEnt{data: sign}
	}
	// e/E?
	expo := ""
	if !lx.eof() && (lx.peek() == 'e' || lx.peek() == 'E') {
		echar := lx.next() // consume e/E
		expSign := ""
		if !lx.eof() && (lx.peek() == '+' || lx.peek() == '-') {
			expSign = string(lx.next())
		}
		expDigits := ""
		for !lx.eof() && unicode.IsDigit(lx.peek()) {
			expDigits += string(lx.next())
		}
		if expDigits == "" {
			return &numEnt{data: sign + digits, hex: false}
		}
		expo = string(echar) + expSign + expDigits
	}
	return &numEnt{data: sign + digits + expo, hex: false}
}

// ─────────────────────────────
//  5. keyVal 파싱
//     keyValEnt.depth = (부모 depth)
//     내부 토큰 depth = keyValEnt.depth+1
//
// ─────────────────────────────
// parseKeyVals:
//
//	... alphaEnt/numEnt, (공백), markEnt(:|=|:=), (공백), alphaEnt/numEnt ...
//
// 을 하나의 keyValEnt로 묶는다. (중간에 wsEnt 한 번씩만 건너뛰어 검사)
func parseKeyVals(tokens []Ent) []Ent {
	var result []Ent
	i := 0
	for i < len(tokens) {
		cur := tokens[i]

		// 1) markEnt인지 검사
		m, ok := cur.(*markEnt)
		if !ok {
			// markEnt가 아니면 그냥 결과에 넣고 계속
			result = append(result, cur)
			i++
			continue
		}
		// 2) 구분자(":","=",":=")인지?
		if m.data != ":" && m.data != "=" && m.data != ":=" {
			// 아니면 그대로 넣고 계속
			result = append(result, cur)
			i++
			continue
		}

		// 여기서부터는 m.data가 구분자인 경우
		// 3) 왼쪽 / 오른쪽에서 alphaEnt/numEnt 찾기
		leftIndex := i - 1
		rightIndex := i + 1
		if leftIndex < 0 || rightIndex >= len(tokens) {
			// 범위를 벗어나면 keyVal 불가능
			result = append(result, cur)
			i++
			continue
		}

		// ------------------------------------------------
		// 왼쪽 공백(있으면) 먼저 확인
		var leftPadding Ent
		if _, isWs := tokens[leftIndex].(*wsEnt); isWs {
			// 이 wsEnt를 leftPadding으로 저장
			leftPadding = tokens[leftIndex]
			leftIndex--
		} else {
			leftPadding = nil
		}
		if leftIndex < 0 {
			result = append(result, cur)
			i++
			continue
		}
		left := tokens[leftIndex]
		if !isAlphaOrNum(left) {
			// 왼쪽이 alphaEnt/numEnt가 아니라면 keyVal 불가
			result = append(result, cur)
			i++
			continue
		}

		// 오른쪽에 wsEnt가 있으면 한 칸 건너뛴다
		// 오른쪽 공백(있으면) 확인
		var rightPadding Ent
		if rightIndex < len(tokens) {
			if _, isWs := tokens[rightIndex].(*wsEnt); isWs {
				rightPadding = tokens[rightIndex]
				rightIndex++
			}
		} else {
			rightPadding = nil
		}
		if rightIndex >= len(tokens) {
			// 범위 벗어나면 keyVal 불가
			result = append(result, cur)
			i++
			continue
		}
		right := tokens[rightIndex]
		if !isAlphaOrNum(right) {
			result = append(result, cur)
			i++
			continue
		}

		// 4) 여기까지 오면 keyVal 패턴 성립!
		//    left, cur(구분자), right → 묶어서 keyValEnt
		parentDepth := left.getDepth()
		// 내부 토큰들 depth = keyValEnt.depth + 1
		left.setDepth(parentDepth + 1)
		cur.setDepth(parentDepth + 1)
		right.setDepth(parentDepth + 1)
		if leftPadding != nil {
			leftPadding.setDepth(parentDepth + 1)
		}
		if rightPadding != nil {
			rightPadding.setDepth(parentDepth + 1)
		}
		kv := &keyValEnt{
			depth:     parentDepth,
			k:         left,
			plOrNil:   leftPadding,
			delimiter: cur,
			prOrNil:   rightPadding,
			v:         right,
		}
		// 5) result에 keyValEnt 추가
		result = append(result, kv)

		// 6) 이미 처리된 left / 구분자 / right를 건너뛰어야 함
		//    (leftIndex < i < rightIndex)
		//    주의: leftIndex가 i-1이고, rightIndex가 i+1 (혹은 i+2)
		//    → i는 rightIndex+1로 점프
		i = rightIndex + 1
	} // end for
	return result
}

func isAlphaOrNum(e Ent) bool {
	switch e.(type) {
	case *alphaEnt, *numEnt:
		return true
	}
	return false
}

// ─────────────────────────────
//  6. Bracket 파싱 (재귀)
//     groupEnt.depth = (여는 괄호 depth)
//     여/닫 bracket depth= same
//     내부 = groupEnt.depth+1
//
// ─────────────────────────────
func parseBrackets(tokens []Ent) []Ent {
	var result []Ent
	i := 0
	for i < len(tokens) {
		tok := tokens[i]
		if mk, ok := tok.(*markEnt); ok && len(mk.data) == 1 {
			openRune := rune(mk.data[0])
			if _, exist := bracketPairs[openRune]; exist {
				g, consumed := parseBracketGroup(tokens, i)
				result = append(result, g)
				i = consumed
				continue
			}
		}
		result = append(result, tok)
		i++
	}
	return result
}

func parseBracketGroup(tokens []Ent, from int) (*groupEnt, int) {
	open, _ := tokens[from].(*markEnt)
	openDepth := open.getDepth()
	closeRune := bracketPairs[rune(open.data[0])]
	g := &groupEnt{
		depth: openDepth,
		data:  []Ent{open},
	}
	// open bracket depth는 그대로
	i := from + 1
	for i < len(tokens) {
		tok := tokens[i]
		if mk, ok := tok.(*markEnt); ok && len(mk.data) == 1 {
			if rune(mk.data[0]) == closeRune {
				// 닫는 bracket depth도 groupEnt.depth
				mk.setDepth(openDepth)
				g.data = append(g.data, mk)
				return g, i + 1
			}
			// 중첩 괄호?
			if _, has := bracketPairs[rune(mk.data[0])]; has {
				sub, consumed := parseBracketGroup(tokens, i)
				g.data = append(g.data, sub)
				i = consumed
				continue
			}
		}
		// 일반 토큰 => groupEnt.depth+1
		tok.setDepth(openDepth + 1)
		g.data = append(g.data, tok)
		i++
	}
	return g, i
}

// ─────────────────────────────
// 7) rootEnt + pattern
// ─────────────────────────────
func parseToRoot(s string) *rootEnt {
	// 1) Lex
	lx := NewLexer(s)
	toks := lx.Lex()
	// 2) keyVal
	toks2 := parseKeyVals(toks)
	// 3) bracket
	toks3 := parseBrackets(toks2)
	// 4) rootEnt
	r := &rootEnt{data: toks3, depth: 0}
	r = applyPatternToRoot(r)
	return r
}

// 패턴 감지
func detectPattern(tokens []Ent) (string, bool) {
	flat := flattenTokens(tokens)
	total := 0
	httpCount := 0
	gnoCount := 0
	mlCount := 0
	jsonBrace := 0
	jsonColon := 0

	for _, e := range flat {
		switch t := e.(type) {
		case *wsEnt:
			continue
		case *alphaEnt:
			total++
			low := strings.ToLower(t.data)
			if low == "return" || low == "func" || low == "for" ||
				low == "if" || low == "case" || low == "switch" || low == "int" {
				gnoCount++
			}
			if low == "http" || low == "https" {
				httpCount++
			}
		case *markEnt:
			total++
			d := strings.ToLower(t.data)
			if d == ":=" || d == "=" {
				gnoCount++
			}
			if d == "http://" || d == "https://" {
				httpCount++
			}
			if d == "<" || d == ">" {
				mlCount++
			}
			if d == "{" || d == "}" {
				jsonBrace++
			}
			if d == ":" {
				jsonColon++
			}
		}
	}
	if total == 0 {
		return "SOMETHING", true
	}
	if gnoCount > 3 || float64(gnoCount)/float64(total) >= 0.1 {
		return "GNO", true
	}
	if httpCount > 0 {
		return "HTTP", true
	}
	if (jsonBrace + jsonColon) > 2 {
		return "JSON", true
	}
	if mlCount > 7 || float64(mlCount)/float64(total) >= 0.1 {
		return "SOME_ML", true
	}
	return "SOMETHING", true
}

func applyPatternToRoot(r *rootEnt) *rootEnt {
	p, ok := detectPattern(r.data)
	if ok {
		r.isPattern = true
		r.pattern = p
	}
	return r
}

// flattenTokens: groupEnt 안의 내용을 재귀적으로 펼침
func flattenTokens(tokens []Ent) []Ent {
	var out []Ent
	for _, e := range tokens {
		switch gg := e.(type) {
		case *groupEnt:
			if len(gg.data) > 0 {
				out = append(out, gg.data[0]) // open bracket
				if len(gg.data) > 2 {
					body := gg.data[1 : len(gg.data)-1]
					out = append(out, flattenTokens(body)...)
				}
				out = append(out, gg.data[len(gg.data)-1]) // close bracket
			}
		default:
			out = append(out, e)
		}
	}
	return out
}

// ─────────────────────────────
// 8) 출력
// ─────────────────────────────
func printTree(e Ent, indent int) {
	ind := strings.Repeat("  ", indent)
	switch t := e.(type) {
	case *alphaEnt:
		fmt.Printf("%salphaEnt(%q, depth:%d)\n", ind, t.data, t.depth)
	case *numEnt:
		fmt.Printf("%snumEnt(%q, hex:%v, depth:%d)\n", ind, t.data, t.hex, t.depth)
	case *wsEnt:
		fmt.Printf("%swsEnt(%q, depth:%d)\n", ind, t.data, t.depth)
	case *markEnt:
		fmt.Printf("%smarkEnt(%q, depth:%d)\n", ind, t.data, t.depth)
	case *keyValEnt:
		fmt.Printf("%skeyValEnt(depth:%d)[\n", ind, t.depth)
		fmt.Printf("%s  k:\n", ind)
		printTree(t.k, indent+2)
		fmt.Printf("%s  pl:\n", ind)
		printTree(t.plOrNil, indent+2)
		fmt.Printf("%s  delimiter:\n", ind)
		printTree(t.delimiter, indent+2)
		fmt.Printf("%s  pr:\n", ind)
		printTree(t.prOrNil, indent+2)
		fmt.Printf("%s  v:\n", ind)
		printTree(t.v, indent+2)
		fmt.Printf("%s]\n", ind)
	case *groupEnt:
		fmt.Printf("%sgroupEnt(depth:%d)[\n", ind, t.depth)
		for _, c := range t.data {
			printTree(c, indent+1)
		}
		fmt.Printf("%s]\n", ind)
	case *rootEnt:
		if t.isPattern {
			fmt.Printf("%srootEnt(depth:%d, pattern:%q)[\n", ind, t.depth, t.pattern)
		} else {
			fmt.Printf("%srootEnt(depth:%d)[\n", ind, t.depth)
		}
		for _, c := range t.data {
			printTree(c, indent+1)
		}
		fmt.Printf("%s]\n", ind)
	case nil:
		fmt.Printf("%snil\n", ind)
	default:
		fmt.Printf("%sUnknown token\n", ind)
	}
}

// ─────────────────────────────
// main
// ─────────────────────────────
func main() {
	input := "{a:apple}     hello := world (x=4)"
	root := parseToRoot(input) // 파싱
	fmt.Println("=== Final AST ===")
	printTree(root, 0)
	program := `func main() {
		parser :=NewParser(input)
		t1 := parser.parseTokens(0)
		root := rootEnt{depth: -0x12, data: t1}
		root = applyPatternToRoot(root)
		printTokens([]Ent{root}, 0)
	   printTokens([]Ent{root}, 0)
	}`
	myAst := parseToRoot(program)
	fmt.Println("TEST")
	printTree(myAst, 0)
}

// func main() {
// 	// 예제 1: JSON 형식 문자열 (괄호 내 return 블록은 groupEnt로 처리)
// 	input := "{a:appple,b:apple}"
// 	parser := NewParser(input)
// 	tokens := parser.parseTokens(0)
// 	// 최상위 노드는 rootEnt로 생성 (groupEnt은 내부에서만 사용)
// 	root := rootEnt{depth: 0, data: tokens}
// 	root = applyPatternToRoot(root)
// 	fmt.Println("Parsed tokens (예제 1):")
// 	printTokens([]Ent{root}, 0)

// 	// 예제 2: URL 문자열
// 	input = "https://www.naver.com?search=0x16+1e14"
// 	parser = NewParser(input)
// 	tokens = parser.parseTokens(0)
// 	root = rootEnt{depth: 0, data: tokens}
// 	root = applyPatternToRoot(root)
// 	fmt.Println("\nParsed tokens (예제 2):")
// 	printTokens([]Ent{root}, 0)

// 	// 예제 3: 일반 문자열 (패턴은 rootEnt에서만 전담)
// 	input = `func main() {
// 		parser := NewParser(input)
// 		tokens := parser.parseTokens(0)
// 		root := rootEnt{depth: 0, data: tokens}
// 		root = applyPatternToRoot(root)
// 		printTokens([]Ent{root}, 0)
// 		printTokens([]Ent{root}, 0)
// 	}`
// 	parser = NewParser(input)
// 	tokens = parser.parseTokens(0)
// 	root = rootEnt{depth: 0, data: tokens}
// 	root = applyPatternToRoot(root)
// 	fmt.Println("\nParsed string (예제 3):")
// 	fmt.Println("Detected pattern:", root.pattern)
// 	printTokens([]Ent{root}, 0)
// 	input = "{a:apple} hello := world (x=4)"
// 	root = rootEnt{depth: 0, data: parseString(input)}
// 	final := applyPatternToRoot(root)
// 	fmt.Println("Detected pattern:", final.pattern)
// 	printTokens([]Ent{final}, 0)
// }
