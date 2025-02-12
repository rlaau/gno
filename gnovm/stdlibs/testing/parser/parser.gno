package parser

import (
	"fmt"
	"strings"
	"unicode"
	"unicode/utf8"
)

// ─────────────────────────────
//  1. Ent 인터페이스
//     setDepth(d int), getDepth() int
//
// ─────────────────────────────
type Ent interface {
	setDepth(d int)
	getDepth() int
	// 추가된 메서드
	// 타겟팅 후 변형
	// change()
	// // 변형 전략 기록
	// //처음엔 1로 초기화
	// getWeightedStrategy()*map[int]int
	// setWeightedStrategy(int)
}

// ─────────────────────────────
// 2) 구조체들 & 인터페이스 구현
// ─────────────────────────────

// letterEnt
type letterEnt struct {
	data  string
	depth int
}

func (a *letterEnt) setDepth(d int) { a.depth = d }
func (a *letterEnt) getDepth() int  { return a.depth }

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

// RootEnt: 최상위 (패턴 판단)
type RootEnt struct {
	data      []Ent
	depth     int
	isPattern bool
	pattern   string
}

// //이것들 추가하기
// // 인터페이스는 문법 오류니까. 여튼 추가.
// type RootEnt interface {
// 	//여기서부터 추가된 메서드
// 	// 한 단계 밑으 *Ent의 가중치 계싼
// 	fmtWeight() //처음엔 1로 초기회
// 	setWeight(*Ent, int) //Ent에 따른 가중치
// 	getWeight() map[*Ent][int]
// 	//모든 ent를 flatten후 포인터 저장
// 	getFlattened()[]*Ent
// 	// 변이 수 할당받아서 그 비율만큼 1개씩 변형된 ENT리턴

// }
func (r *RootEnt) setDepth(d int) { r.depth = d }
func (r *RootEnt) getDepth() int  { return r.depth }

// ─────────────────────────────
// 3) 전역 설정 (mark 목록, bracket)
var parserMark = []string{
	"\r\n", "\n", "\t",
	"/", "://", "//",
	".", "?", "@", "!", "#", "$", "%", "^",
	"&&", "&", "||", "|",
	"or", "OR", "and", "AND",
	",", ";",
	":=", "=", ":",
}

// var bracketPairs = map[rune]rune{
// 	'(': ')',
// 	'{': '}',
// 	'[': ']',
// for quoted pairs =

// 근데 인용부호는 그 크기가 정합적이지 못함
// "keyval"은 반드시 그룹에 소갛ㅁ
// 근데, 인용은 그룹을 포함할수도 될수도, 키에도 그럼.
// 너무 애매. 걍 파싱 후 후처리 ㄱㄱ

// 왜냐하면, 이런 "인용"들은 "그룹"안에 속하는 "element"이기 때문
// 아님 차라리 걍 포기해도 좋음. 차피 "파싱"에서 다 갈려나가고 나면 이후 점검해도 됨.
// isQouted, isAscii, isNumber, isTag, isKeyword등으로

// 즉, 파싱에서 인용으로 묶던가
// 아님 파싱 이후, 파싱된 대상을 처리하든가

// 	'<': '>',
// 	'\': '\',
// 	'"': '"',
// 	''': ''',
// }

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
	// 4) 유니코드 문자
	if unicode.IsLetter(ch) {
		var sb strings.Builder
		for !lx.eof() && (unicode.IsLetter(lx.peek()) ||
			unicode.IsDigit(lx.peek()) || lx.peek() == '_') {
			sb.WriteRune(lx.next())
		}
		return &letterEnt{data: sb.String()}
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
// 숫자 처리: -12, 1e12, 0x16, 1e 등도 올바르게 처리
func (lx *Lexer) lexNumber() Ent {
	sign := ""
	if !lx.eof() && lx.peek() == '-' {
		sign = "-"
		lx.next()
	}

	// 퍼져에 의해 "0X"에러 발견 후 수정됨
	// // 16진수 (0x, 0X)
	// if !lx.eof() && lx.peek() == '0' {
	// 	if lx.pos+1 < len(lx.input) &&
	// 		(lx.input[lx.pos+1] == 'x' || lx.input[lx.pos+1] == 'X') {
	// 		lx.next() // '0'
	// 		lx.next() // 'x'
	// 		hexDigits := ""
	// 		for !lx.eof() {
	// 			ch := lx.peek()
	// 			if (ch >= '0' && ch <= '9') ||
	// 				(ch >= 'a' && ch <= 'f') ||
	// 				(ch >= 'A' && ch <= 'F') {
	// 				hexDigits += string(ch)
	// 				lx.next()
	// 			} else {
	// 				break
	// 			}
	// 		}
	// 		if hexDigits == "" {
	// 			return &numEnt{data: sign + "0x", hex: false}
	// 		}
	// 		return &numEnt{data: sign + "0x" + hexDigits, hex: true}
	// 	}
	// }
	// 16진수 (0x, 0X)
	if !lx.eof() && lx.peek() == '0' {
		// 만약 다음 문자가 x/X라면
		if lx.pos+1 < len(lx.input) &&
			(lx.input[lx.pos+1] == 'x' || lx.input[lx.pos+1] == 'X') {

			lx.next()          // '0'
			xChar := lx.next() // 'x' or 'X' (rune)
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

			// 만약 x 뒤에 헥사 숫자가 하나도 없으면
			if hexDigits == "" {
				// ex) "0x" or "0X"만 입력되었을 경우
				// → hex=false로 반환
				return &numEnt{
					data: sign + "0" + string(xChar),
					hex:  false,
				}
			}

			// 정상적인 16진수
			return &numEnt{
				data: sign + "0" + string(xChar) + hexDigits, // 대소문자 보존
				hex:  true,
			}
		}
	}

	// 10진수
	digits := ""
	for !lx.eof() && unicode.IsDigit(lx.peek()) {
		digits += string(lx.next())
	}

	if digits == "" {
		// '-' 단독이면 숫자가 아님
		return &markEnt{data: sign}
	}

	// e/E (지수 표현)
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
			// `1e` 같은 경우를 처리 → `1e` 자체를 숫자로 인식
			return &numEnt{data: sign + digits + string(echar) + expSign, hex: false}
		}

		expo = string(echar) + expSign + expDigits
	}

	return &numEnt{data: sign + digits + expo, hex: false}
}

func parseKeyVals(tokens []Ent) []Ent {
	var result []Ent
	i := 0
	for i < len(tokens) {
		// 1) 왼쪽(키) 검사: alphaEnt/numEnt ?
		left := tokens[i]
		if !isAlphaOrNum(left) {
			// (키 후보 아님) => 그대로 결과에 넣고 다음
			result = append(result, left)
			i++
			continue
		}
		// 지금 left는 alphaEnt or numEnt

		pos := i + 1
		// 2) 왼쪽 공백(옵션)
		var leftPadding Ent
		if pos < len(tokens) {
			if w, ok := tokens[pos].(*wsEnt); ok {
				leftPadding = w
				pos++
			}
		}

		// delimiter(구분자) 확인
		if pos >= len(tokens) {
			// 구분자 위치가 없음 => 실패.
			result = append(result, left)
			if leftPadding != nil {
				result = append(result, leftPadding)
				// left+padding 소비
				i += 2
			} else {
				i += 1
			}
			continue
		}

		delimiter := tokens[pos]
		md, ok2 := delimiter.(*markEnt)
		if !ok2 || (md.data != ":" && md.data != "=" && md.data != ":=") {
			// 구분자가 아닌 경우 => 실패
			result = append(result, left)
			if leftPadding != nil {
				result = append(result, leftPadding)
				i += 2
			} else {
				i += 1
			}
			continue
		}
		pos++ // delimiter 소비

		// 4) 오른쪽 공백(옵션)
		var rightPadding Ent
		if pos < len(tokens) {
			if w2, ok3 := tokens[pos].(*wsEnt); ok3 {
				rightPadding = w2
				pos++
			}
		}

		if pos >= len(tokens) {
			// 값이 있을 자리가 없음 => 실패
			// => left + leftPadding + delimiter + rightPadding
			result = append(result, left)
			if leftPadding != nil {
				result = append(result, leftPadding)
			}
			result = append(result, delimiter)
			if rightPadding != nil {
				result = append(result, rightPadding)
			}
			// 지금까지 pos개 소비
			i = pos
			continue
		}

		// 5) 오른쪽(값) 검사
		right := tokens[pos]
		if !isAlphaOrNum(right) {
			// 값 후보가 아니면 => 실패
			result = append(result, left)
			if leftPadding != nil {
				result = append(result, leftPadding)
			}
			result = append(result, delimiter)
			if rightPadding != nil {
				result = append(result, rightPadding)
			}
			// i=pos => delimiter/패딩까지 소비
			i = pos
			continue
		}
		// 성공 => keyValEnt 생성
		kv := &keyValEnt{
			depth:     0,
			k:         left,
			plOrNil:   leftPadding,
			delimiter: delimiter,
			prOrNil:   rightPadding,
			v:         right,
		}
		result = append(result, kv)

		// 키,왼쪽패딩,구분자,오른쪽패딩,값 소비
		i = pos + 1
	} // end for
	return result
}

func isAlphaOrNum(e Ent) bool {
	switch e.(type) {
	case *letterEnt, *numEnt:
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
	closeRune := bracketPairs[rune(open.data[0])]
	g := &groupEnt{
		depth: 0,
		data:  []Ent{open},
	}
	// open bracket depth는 그대로
	i := from + 1
	for i < len(tokens) {
		tok := tokens[i]
		if mk, ok := tok.(*markEnt); ok && len(mk.data) == 1 {
			if rune(mk.data[0]) == closeRune {
				// 닫는 bracket depth도 groupEnt.depth

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
		g.data = append(g.data, tok)
		i++
	}
	return g, i
}

// ─────────────────────────────
// 7) rootEnt + pattern
// ─────────────────────────────
func parseToRoot(s string) *RootEnt {
	// 1) Lex
	lx := NewLexer(s)
	toks := lx.Lex()
	// k := &rootEnt{data: toks, depth: 0}
	// println("lexer")
	// printTree(k, 0)
	// 2) keyVal
	toks2 := parseKeyVals(toks)
	// 3) bracket
	toks3 := parseBrackets(toks2)
	// 4) rootEnt
	r := &RootEnt{data: toks3, depth: 0}
	r = applyPatternToRoot(r)
	finalizeDepth(r, 0)
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
		case *letterEnt:
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
			if d == "://" {
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
		case *keyValEnt:
			total++
			d := t.delimiter
			var dStr string
			if delim, ok := d.(*markEnt); ok {
				dStr = delim.data
			} else {
				continue
			}

			if dStr == ":=" || dStr == "=" {
				gnoCount++
			} else {
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
	if httpCount > 1 {
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

func applyPatternToRoot(r *RootEnt) *RootEnt {
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

func finalizeDepth(e Ent, currentDepth int) {
	// e의 depth를 currentDepth로 설정
	e.setDepth(currentDepth)
	// 자식 요소가 있으면, 자식에게는 currentDepth+1 적용
	switch kv := e.(type) {
	case *keyValEnt:
		finalizeDepth(kv.k, currentDepth+1)
		if kv.plOrNil != nil {
			finalizeDepth(kv.plOrNil, currentDepth+1)
		}
		finalizeDepth(kv.delimiter, currentDepth+1)
		if kv.prOrNil != nil {
			finalizeDepth(kv.prOrNil, currentDepth+1)
		}
		finalizeDepth(kv.v, currentDepth+1)
	case *groupEnt:
		// groupEnt 내부 토큰들은 currentDepth+1
		for _, c := range kv.data {
			finalizeDepth(c, currentDepth+1)
		}
	case *RootEnt:
		// rootEnt 내부도 children은 currentDepth+1
		for _, c := range kv.data {
			finalizeDepth(c, currentDepth+1)
		}
	}
	// alphaEnt, numEnt, wsEnt, markEnt 등은 자식 없음
}

// ─────────────────────────────
// 8) 출력
// ─────────────────────────────
func printTree(e Ent, indent int) {
	ind := strings.Repeat("  ", indent)
	switch t := e.(type) {
	case *letterEnt:
		fmt.Printf("%sletterEnt(%q, depth:%d)\n", ind, t.data, t.depth)
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
	case *RootEnt:
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

// serializeToTokens는 AST 노드를 DFS 식으로 순회하여,
// 최종적으로 단순 토큰(기본 Ent: alphaEnt, numEnt, wsEnt, markEnt 등) 목록을 반환합니다.
func serializeToTokens(e Ent) []Ent {
	switch t := e.(type) {

	// 1) 기본 토큰 (알파벳, 숫자, 공백, 기호 등)
	case *letterEnt, *numEnt, *wsEnt, *markEnt:
		// 직접적으로 한 개의 요소로 변환
		return []Ent{e}

	// 2) keyValEnt (k, plOrNil, delimiter, prOrNil, v 순서)
	case *keyValEnt:
		var out []Ent
		// k
		out = append(out, serializeToTokens(t.k)...)
		// plOrNil (왼쪽 공백)
		if t.plOrNil != nil {
			out = append(out, serializeToTokens(t.plOrNil)...)
		}
		// delimiter
		out = append(out, serializeToTokens(t.delimiter)...)
		// prOrNil (오른쪽 공백)
		if t.prOrNil != nil {
			out = append(out, serializeToTokens(t.prOrNil)...)
		}
		// v
		out = append(out, serializeToTokens(t.v)...)
		return out

	// 3) groupEnt (첫 자식: 여는 괄호, 마지막 자식: 닫는 괄호, 중간: 내부)
	case *groupEnt:
		// 보통 data[0]은 여는 bracket, data[len-1]은 닫는 bracket,
		// 나머지 중간이 본문
		// 그대로 재귀 펼침
		var out []Ent
		if len(t.data) > 0 {
			// 여는 bracket
			out = append(out, serializeToTokens(t.data[0])...)
			// 내부
			for i := 1; i < len(t.data)-1; i++ {
				out = append(out, serializeToTokens(t.data[i])...)
			}
			// 닫는 bracket
			if len(t.data) > 1 {
				out = append(out, serializeToTokens(t.data[len(t.data)-1])...)
			}
		}
		return out

	// 4) rootEnt
	case *RootEnt:
		// rootEnt 내부 data를 순회
		var out []Ent
		for _, c := range t.data {
			out = append(out, serializeToTokens(c)...)
		}
		return out
	case nil:
		return nil
	default:
		// 알 수 없는/ 미구현된 노드 타입이면 빈 목록 반환
		return nil
	}
}

// entToString: 토큰 하나를 문자열로 변환 (공백은 그대로, 알파벳/기호도 그대로)
func entToString(e Ent) string {
	switch t := e.(type) {
	case *letterEnt:
		return t.data
	case *numEnt:
		return t.data
	case *wsEnt:
		return t.data
	case *markEnt:
		return t.data
	case nil:
		return ""
	default:
		// 이론상 여기는 오지 않음(serializeToTokens가 풀어줌)
		return ""
	}
}

// serializeToString는 AST 노드를 토큰으로 펼친 뒤,
// 각 토큰을 문자열로 변환하여 이어 붙여, 최종 문자열을 반환합니다.
func serializeToString(e Ent) string {
	tokens := serializeToTokens(e)
	var sb strings.Builder
	for _, tok := range tokens {
		sb.WriteString(entToString(tok))
	}
	return sb.String()
}

func safeUTF8(s string) string {
	if utf8.ValidString(s) {
		return s // 이미 안전한 UTF-8이면 그대로 반환
	}
	return string([]rune(s)) // 유효한 UTF-8 문자만 남김
}

// ─────────────────────────────
// main
// ─────────────────────────────
func main() {
	// input := "{a:apple}     hello := world (x=4)"
	// root := parseToRoot(input) // 파싱
	fmt.Println("=== Final AST ===")
	// program := `func main() {
	// 	parser := NewParser(input)
	// 	t1 := parser.parseTokens(0)
	// 	root := rootEnt{depth: -0x12, data: t1}
	// 	root = applyPatternToRoot(root)
	// 	printTokens([]Ent{root}, 0)
	// 	printTokens([]Ent{root}, 0)
	// 	}`
	program := `func main() {
		parser := NewParser(input)
		t1 := parser.parseTokens(0)
		root := rootEnt{"depth": '-0x12', data: 0X}
		root = applyPatternToRoot(root)
		printTokens([]Ent{root}, 0)
		printTokens([]Ent{root}, 0)
		}`

	root := parseToRoot(safeUTF8(program))
	printTree(root, 0)
	myAst := parseToRoot(program)
	sealized := serializeToString(myAst)
	println(sealized)

	if program != sealized {
		println("orig:", program)
		println("parsed", sealized)
		println("logic error")
	} else {
		println("ok!")
	}
	pp := "https://www.naver.com/search.naver?query=김명헌"
	rootp := parseToRoot(pp)
	printTree(rootp, 0)
	ml := `<html><a>yeah!<a/><html/>`
	rootm := parseToRoot(ml)
	printTree(rootm, 0)
}

// 퍼져가 찾은 에러 코드임. "1E"에 대해선 에러 나옴을 찾음
// // 숫자 처리: -12, 1e12, 0x16 ...
//
//	func (lx *Lexer) lexNumber() Ent {
//		sign := ""
//		if !lx.eof() && lx.peek() == '-' {
//			sign = "-"
//			lx.next()
//		}
//		// 0x?
//		if !lx.eof() && lx.peek() == '0' {
//			if lx.pos+1 < len(lx.input) &&
//				(lx.input[lx.pos+1] == 'x' || lx.input[lx.pos+1] == 'X') {
//				lx.next() // '0'
//				lx.next() // 'x'
//				hexDigits := ""
//				for !lx.eof() {
//					ch := lx.peek()
//					if (ch >= '0' && ch <= '9') ||
//						(ch >= 'a' && ch <= 'f') ||
//						(ch >= 'A' && ch <= 'F') {
//						hexDigits += string(ch)
//						lx.next()
//					} else {
//						break
//					}
//				}
//				if hexDigits == "" {
//					return &numEnt{data: sign + "0x", hex: false}
//				}
//				return &numEnt{data: sign + "0x" + hexDigits, hex: true}
//			}
//		}
//		// 10진수
//		digits := ""
//		for !lx.eof() && unicode.IsDigit(lx.peek()) {
//			digits += string(lx.next())
//		}
//		if digits == "" {
//			// -만 있었음
//			return &markEnt{data: sign}
//		}
//		// e/E?
//		expo := ""
//		if !lx.eof() && (lx.peek() == 'e' || lx.peek() == 'E') {
//			echar := lx.next() // consume e/E
//			expSign := ""
//			if !lx.eof() && (lx.peek() == '+' || lx.peek() == '-') {
//				expSign = string(lx.next())
//			}
//			expDigits := ""
//			for !lx.eof() && unicode.IsDigit(lx.peek()) {
//				expDigits += string(lx.next())
//			}
//			if expDigits == "" {
//				return &numEnt{data: sign + digits, hex: false}
//			}
//			expo = string(echar) + expSign + expDigits
//		}
//		return &numEnt{data: sign + digits + expo, hex: false}
//	}
//
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
