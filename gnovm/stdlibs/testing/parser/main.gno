package main

import (
	"fmt"
	"strings"
	"unicode"
)

// ── 엔티티(토큰) 정의 ─────────────────────────────────────────────

// Ent 인터페이스 (모든 토큰 타입의 공통 타입)
type Ent interface{}

// 알파벳/식별자 토큰
type alphaEnt struct {
	depth int
	data  string
}

// 숫자 토큰 (여기서는 hex 표기를 단순히 false로 처리)
type numEnt struct {
	depth int
	hex   bool
	data  string
}

// 공백 토큰
type wsEnt struct {
	depth int
	data  string
}

// 기호(mark) 토큰
type markEnt struct {
	depth int
	data  string
}

type keyValEnt struct {
	k         Ent
	v         Ent
	delimeter Ent
}

// 그룹 토큰: 괄호 등의 내부 구조를 담음 (패턴 검출은 하지 않음)
type groupEnt struct {
	isPattern bool // 개별 그룹에 대해 패턴을 적용할 수도 있으나, 여기서는 주로 rootEnt에서 판별합니다.
	depth     int
	data      []Ent
}

// 최상위 노드: 전체 토큰을 담으며 패턴 전담
type rootEnt struct {
	isPattern bool
	pattern   string
	depth     int
	data      []Ent
}

// ── 패턴 관련 설정 ─────────────────────────────────────────────

// 4가지 패턴 중 하나로 분류하도록 합니다.
var patternSet = map[string]bool{
	"HTTP":      true,
	"SOME_ML":   true,
	"GNO":       true,
	"JSON":      true,
	"SOMETHING": true,
}

// ── 구분자 및 괄호 설정 ───────────────────────────────────────────

var (
	// parserMark: 여러 글자 기호(길이가 긴 순으로 매칭)
	parserMark = []string{
		"\r\n", "\n", "\t", "//", "&&", "||",
		"&", "|", ".", "?", "@", "!", "#", "$", "%", "^",
		"or", "OR", "and", "AND", "/", "://", ":=", "=", ":",
	}
	// bracketMark: 여는 괄호와 대응하는 닫는 괄호 (모든 따옴표도 포함)
	bracketMark = map[rune]rune{
		'<':  '>',
		'[':  ']',
		'(':  ')',
		'{':  '}',
		'\'': '\'',
		'"':  '"',
		'`':  '`',
	}
)

// ─────────────────────────────
// 3. (단계 1) Lexer
//    → 문자열을 순회하면서 가장 기초적인 토큰(Ent) 목록을 만든다.
//    → 괄호도 단순히 markEnt("(")처럼 처리.
// ─────────────────────────────

type Lexer struct {
	input []rune
	pos   int
}

func NewLexer(s string) *Lexer {
	return &Lexer{input: []rune(s), pos: 0}
}

// Lex()는 전체 입력을 토큰 목록으로 변환한다.
func (lx *Lexer) Lex() []Ent {
	var tokens []Ent
	for !lx.eof() {
		tok := lx.nextToken()
		if tok != nil {
			tokens = append(tokens, tok)
		}
	}
	return tokens
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

// nextToken() : 한 토큰을 반환
func (lx *Lexer) nextToken() Ent {
	ch := lx.peek()

	// 1) 줄바꿈
	if ch == '\n' {
		lx.next()
		return markEnt{data: "\n"}
	}
	// 2) 공백
	if unicode.IsSpace(ch) {
		var ws strings.Builder
		for !lx.eof() && unicode.IsSpace(lx.peek()) && lx.peek() != '\n' {
			ws.WriteRune(lx.next())
		}
		return wsEnt{data: ws.String()}
	}
	// 3) 숫자 or -로 시작
	if unicode.IsDigit(ch) || ch == '-' {
		return lx.lexNumber()
	}
	// 4) 알파벳
	if unicode.IsLetter(ch) {
		var sb strings.Builder
		for !lx.eof() && (unicode.IsLetter(lx.peek()) || unicode.IsDigit(lx.peek()) || lx.peek() == '_') {
			sb.WriteRune(lx.next())
		}
		return alphaEnt{data: sb.String()}
	}
	// 5) 다중 문자 기호 매칭
	sorted := sortMarksByLengthDesc(parserMark)
	for _, mk := range sorted {
		if lx.matchString(mk) {
			lx.pos += len(mk)
			return markEnt{data: mk}
		}
	}
	// 6) 그 외 한 글자
	return markEnt{data: string(lx.next())}
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

// 정렬 함수: 길이가 긴 문자열 우선
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

// lexNumber: -12, 1e12, 0x16 등 간단 처리
func (lx *Lexer) lexNumber() Ent {
	sign := ""
	if !lx.eof() && lx.peek() == '-' {
		sign = "-"
		lx.next()
	}
	// 0x
	if !lx.eof() && lx.peek() == '0' {
		// 다음 문자가 x/X?
		if lx.pos+1 < len(lx.input) && (lx.input[lx.pos+1] == 'x' || lx.input[lx.pos+1] == 'X') {
			// 0x consume
			lx.next() // '0'
			lx.next() // 'x'/'X'
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
				// 0x만 있고 숫자 없음
				return numEnt{data: sign + "0x", hex: false}
			}
			return numEnt{data: sign + "0x" + hexDigits, hex: true}
		}
	}

	// 10진수
	decDigits := ""
	for !lx.eof() && unicode.IsDigit(lx.peek()) {
		decDigits += string(lx.next())
	}
	if decDigits == "" {
		// -만 있었던 경우
		return markEnt{data: sign}
	}

	// e/E
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
			// e만 있고 숫자 없음
			return numEnt{data: sign + decDigits, hex: false}
		}
		expo = string(echar) + expSign + expDigits
	}
	return numEnt{data: sign + decDigits + expo, hex: false}
}

// ─────────────────────────────
// 4. (단계 2) KeyVal 파싱
//    → lexer 결과(토큰 목록)를 받아서,
//      [alphaEnt/numEnt] + [markEnt(:,=,:=)] + [alphaEnt/numEnt]
//      을 keyValEnt로 묶는다.
// ─────────────────────────────

// ─────────────────────────────
// 4. (단계 2) KeyVal 파싱
//    → lexer 결과(토큰 목록)를 받아서,
//      [alphaEnt/numEnt] + [markEnt(:,=,:=)] + [alphaEnt/numEnt]
//      을 keyValEnt로 묶는다.
// ─────────────────────────────

func parseKeyVals(tokens []Ent) []Ent {
	result := []Ent{}
	i := 0
	for i < len(tokens) {
		// 패턴 체크: [Ent1, markEnt, Ent2]
		if i+2 < len(tokens) {
			e1 := tokens[i]
			delim := tokens[i+1]
			e2 := tokens[i+2]

			// e1,e2가 alphaEnt나 numEnt인지 확인
			isLeft := isAlphaOrNum(e1)
			isRight := isAlphaOrNum(e2)

			// delim이 markEnt(":","=",":=")인지
			md, ok := delim.(markEnt)
			if isLeft && isRight && ok && (md.data == ":" || md.data == "=" || md.data == ":=") {
				// keyValEnt로 합침
				result = append(result, keyValEnt{k: e1, delimeter: md, v: e2})
				i += 3
				continue
			}
		}
		// 패턴이 아니면 그냥 결과에 추가
		result = append(result, tokens[i])
		i++
	}
	return result
}

func isAlphaOrNum(e Ent) bool {
	switch e.(type) {
	case alphaEnt, numEnt:
		return true
	}
	return false
}

// ─────────────────────────────
// 5. (단계 3) Bracket 파싱
//    → KeyVal로 변환된 토큰들을 순회하면서,
//      여는 괄호 '(' '{' '[' 만나면 재귀적으로 닫는 괄호까지 groupEnt로 묶는다.
// ─────────────────────────────

// parseBrackets는 전체 토큰 목록을 하나씩 순회하며,
// groupEnt 구조를 만든 최종 AST를 반환한다.
func parseBrackets(tokens []Ent) []Ent {
	var result []Ent
	i := 0
	for i < len(tokens) {
		tok := tokens[i]

		// 여는 괄호면 parseBracketGroup 처리
		if m, ok := tok.(markEnt); ok {
			if _, exist := bracketMark[rune(m.data[0])]; exist && len(m.data) == 1 {
				// 실제로 '(' 또는 '{' 또는 '['인지?
				// 재귀적으로 내부 parse
				group, consumed := parseBracketGroup(tokens, i)
				result = append(result, group)
				i = consumed
				continue
			}
		}
		// 그냥 추가
		result = append(result, tok)
		i++
	}
	return result
}

// parseBracketGroup: tokens[from]이 여는 괄호라고 가정하고,
// 대응하는 닫는 괄호를 찾을 때까지 내부를 groupEnt로 묶는다.
func parseBracketGroup(tokens []Ent, from int) (groupEnt, int) {
	openMark, _ := tokens[from].(markEnt)
	openRune := rune(openMark.data[0])
	closeRune := bracketMark[openRune]

	// groupEnt 데이터에 openMark 포함
	g := groupEnt{data: []Ent{openMark}}

	i := from + 1
	for i < len(tokens) {
		// 닫는 괄호 만났으면
		if mm, ok := tokens[i].(markEnt); ok && len(mm.data) == 1 && rune(mm.data[0]) == closeRune {
			// groupEnt 닫기
			g.data = append(g.data, mm)
			return g, i + 1
		}
		// 중첩 괄호면 재귀 처리
		if mm, ok := tokens[i].(markEnt); ok && len(mm.data) == 1 {
			if _, exist := bracketMark[rune(mm.data[0])]; exist {
				subGroup, consumed := parseBracketGroup(tokens, i)
				g.data = append(g.data, subGroup)
				i = consumed
				continue
			}
		}
		// 일반 토큰
		g.data = append(g.data, tokens[i])
		i++
	}
	// 만약 끝까지 닫는 괄호 못 찾았으면(에러 상황),
	// 일단 그대로 반환
	return g, i
}

func printAll(tokens []Ent, indent int) {
	for _, e := range tokens {
		printEnt(e, indent)
	}
}

func printEnt(e Ent, indent int) {
	ind := strings.Repeat("  ", indent)
	switch t := e.(type) {
	case alphaEnt:
		fmt.Printf("%salphaEnt(%q)\n", ind, t.data)
	case numEnt:
		fmt.Printf("%snumEnt(%q, hex:%v)\n", ind, t.data, t.hex)
	case wsEnt:
		fmt.Printf("%swsEnt(%q)\n", ind, t.data)
	case markEnt:
		fmt.Printf("%smarkEnt(%q)\n", ind, t.data)
	case keyValEnt:
		fmt.Printf("%skeyValEnt(\n", ind)
		fmt.Printf("%s  k:\n", ind)
		printEnt(t.k, indent+2)
		fmt.Printf("%s  delimiter:\n", ind)
		printEnt(t.delimeter, indent+2)
		fmt.Printf("%s  v:\n", ind)
		printEnt(t.v, indent+2)
		fmt.Printf("%s)\n", ind)
	case groupEnt:
		fmt.Printf("%sgroupEnt [\n", ind)
		for _, c := range t.data {
			printEnt(c, indent+1)
		}
		fmt.Printf("%s]\n", ind)
	default:
		fmt.Printf("%sUnknown token\n", ind)
	}
}

// ── Parser 구조체 및 기본 함수 ───────────────────────────────────

type Parser struct {
	input []rune
	pos   int
	depth int
}

func NewParser(s string) *Parser {
	return &Parser{
		// TODO: NOTICE. 얘는 자체적으론 non-unicode 못다룸 (\xeb등 삽입 필요)
		input: []rune(s),
		pos:   0,
		depth: 0,
	}
}

func (p *Parser) eof() bool {
	return p.pos >= len(p.input)
}

func (p *Parser) peek() rune {
	if p.eof() {
		return 0
	}
	return p.input[p.pos]
}

func (p *Parser) next() rune {
	if p.eof() {
		return 0
	}
	ch := p.input[p.pos]
	p.pos++
	return ch
}

func (p *Parser) matchString(s string) bool {
	if p.pos+len(s) > len(p.input) {
		return false
	}
	for i, ch := range s {
		if p.input[p.pos+i] != ch {
			return false
		}
	}
	return true
}

func (p *Parser) consumeString(s string) bool {
	if p.matchString(s) {
		p.pos += len(s)
		return true
	}
	return false
}

// isOpeningBracket(): 주어진 rune이 여는 괄호(또는 따옴표)인지 확인
func isOpeningBracket(r rune) bool {
	_, ok := bracketMark[r]
	return ok
}

// ── flattenTokens: 중첩된 groupEnt 내부의 토큰들을 평탄화 ─────────────────────────────

func flattenTokens(tokens []Ent) []Ent {
	var flat []Ent
	for _, token := range tokens {
		switch t := token.(type) {
		case groupEnt:
			// groupEnt 내부 토큰들을 재귀적으로 평탄화하여 추가
			flat = append(flat, flattenTokens(t.data)...)
		default:
			flat = append(flat, t)
		}
	}
	return flat
}

// ── 패턴 검출 및 적용 (rootEnt 전담) ─────────────────────────────

// detectPattern는 토큰 슬라이스를 평탄화한 후, 각 패턴 후보 토큰의 등장 횟수를 세고,
// 전체(공백 제외) 토큰 수와의 비율 또는 단순 등장 여부를 기준으로 패턴을 결정합니다.
func detectPattern(tokens []Ent) (string, bool) {
	flat := flattenTokens(tokens)

	total := 0          // 전체(공백 제외) 토큰 수
	gnoCount := 0       // GNO 후보 토큰 수
	httpCount := 0      // HTTP 후보 토큰 수
	mlCount := 0        // SOME_ML 후보 (예: "<" 또는 ">" 토큰)
	jsonBraceCount := 0 // JSON: "{" 또는 "}" 토큰 수
	jsonColonCount := 0 // JSON: ":" 토큰 수

	for _, token := range flat {
		switch t := token.(type) {
		case wsEnt:
			// 공백은 전체 토큰에 포함하지 않음.
			continue
		case alphaEnt:
			total++
			lower := strings.ToLower(t.data)
			// GNO 후보: "return", "func", "for", "if", "case", "switch", "int"
			if lower == "return" || lower == "func" || lower == "for" ||
				lower == "if" || lower == "case" || lower == "switch" || lower == "int" {
				gnoCount++
			}
			// HTTP 후보: "http", "https"
			if lower == "http" || lower == "https" {
				httpCount++
			}
		case markEnt:
			total++
			data := t.data
			// GNO 후보: ":=" , "~.~", "~(~)" (예시)
			if data == ":=" || data == "=" {
				gnoCount++
			}
			// HTTP 후보: "/" 또는 "http://" 또는 "https://"
			if data == "/" || strings.ToLower(data) == "http://" || strings.ToLower(data) == "https://" {
				httpCount++
			}
			// SOME_ML 후보: 태그 관련 토큰 "<" 또는 ">"
			if data == "<" || data == ">" {
				mlCount++
			}
			// JSON 후보: 중괄호와 콜론
			if data == "{" || data == "}" {
				jsonBraceCount++
			}
			if data == ":" {
				jsonColonCount++
			}
		}
	}

	if total == 0 {
		return "SOMETHING", true
	}

	// 우선순위: HTTP > JSON > SOME_ML > GNO > SOMETHING
	if httpCount > 0 {
		return "HTTP", true
	}
	if float64(gnoCount)/float64(total) >= 0.1 || gnoCount > 2 {
		return "GNO", true
	}
	if float64(mlCount)/float64(total) >= 0.1 || mlCount > 7 {
		return "SOME_ML", true
	}
	if (jsonBraceCount + jsonColonCount) > 2 {
		return "JSON", true
	}
	return "SOMETHING", true
}

// applyPatternToRoot는 rootEnt의 data를 검사하여,
// 패턴이 감지되면 rootEnt에 isPattern 및 pattern 필드를 설정합니다.
func applyPatternToRoot(r rootEnt) rootEnt {
	pattern, found := detectPattern(r.data)
	if found {
		r.isPattern = true
		// patternSet에 없는 경우에도 detected 패턴 문자열을 그대로 사용합니다.
		r.pattern = pattern
	}
	return r
}

// ── 파서의 토큰 파싱 로직 ───────────────────────────────────────────

// parseBracket: 여는 괄호를 만나면, open mark, 내부 토큰들, 닫는 mark를 하나의 groupEnt로 묶습니다.
func (p *Parser) parseBracket() groupEnt {
	// 여는 괄호 소비 및 토큰화
	openCh := p.next()
	openToken := markEnt{depth: p.depth, data: string(openCh)}

	// 대응하는 닫는 괄호 구하기
	closeCh, exists := bracketMark[openCh]
	if !exists {
		return groupEnt{depth: p.depth, data: []Ent{openToken}}
	}

	// 내부 토큰 파싱 (닫는 괄호 전까지)
	p.depth++
	innerTokens := p.parseTokens(closeCh)
	p.depth--

	// 닫는 괄호 소비 및 토큰화
	var closeToken markEnt
	if !p.eof() && p.peek() == closeCh {
		p.next()
		closeToken = markEnt{depth: p.depth, data: string(closeCh)}
	} else {
		closeToken = markEnt{depth: p.depth, data: ""}
	}

	tokens := []Ent{openToken}
	tokens = append(tokens, innerTokens...)
	tokens = append(tokens, closeToken)

	// groupEnt 생성 (괄호 내부의 깊이는 p.depth+1로 기록)
	group := groupEnt{
		depth: p.depth + 1,
		data:  tokens,
	}
	return group
}

// parseTokens: stop 문자가 나오기 전까지 토큰들을 파싱합니다.
func (p *Parser) parseTokens(stop rune) []Ent {
	var tokens []Ent
	for !p.eof() {
		if stop != 0 && p.peek() == stop {
			break
		}
		if isOpeningBracket(p.peek()) {
			group := p.parseBracket()
			tokens = append(tokens, group)
			continue
		}
		tok := p.parseNextToken()
		if tok != nil {
			tokens = append(tokens, tok)
		}
	}
	return tokens
}

// parseNextToken: 단일 토큰(알파벳, 숫자, 공백, 그 외 기호)을 파싱합니다.
func (p *Parser) parseNextToken() Ent {
	ch := p.peek()

	if ch == '\n' {
		p.next()
		return markEnt{depth: p.depth, data: "\n"}
	}

	if unicode.IsSpace(ch) {
		ws := ""
		for !p.eof() && unicode.IsSpace(p.peek()) && p.peek() != '\n' {
			ws += string(p.next())
		}
		return wsEnt{depth: p.depth, data: ws}
	}

	// 숫자 또는 -로 시작하는 경우 parseNumber로 처리
	if unicode.IsDigit(ch) || ch == '-' {
		numStr, isHex := p.parseNumber()
		// parseNumber()가 반환한 문자열이 실제 유효 숫자인지 더 검증하려면 추가 코드 필요
		return numEnt{depth: p.depth, hex: isHex, data: numStr}
	}

	if unicode.IsLetter(ch) {
		word := ""
		for !p.eof() && (unicode.IsLetter(p.peek()) || unicode.IsDigit(p.peek()) || p.peek() == '_') {
			word += string(p.next())
		}
		return alphaEnt{depth: p.depth, data: word}
	}

	sortedMarks := make([]string, len(parserMark))
	copy(sortedMarks, parserMark)
	n := len(sortedMarks)
	// 길이 긴게 먼저 인식되기 위함
	// TODO: 이것도 걍 미리 정렬해 두기
	for i := 0; i < n-1; i++ {
		for j := 0; j < n-1-i; j++ {
			if len(sortedMarks[j]) < len(sortedMarks[j+1]) {
				sortedMarks[j], sortedMarks[j+1] = sortedMarks[j+1], sortedMarks[j]
			}
		}
	}
	for _, mark := range sortedMarks {
		if p.matchString(mark) {
			p.pos += len(mark)
			return markEnt{depth: p.depth, data: mark}
		}
	}
	return markEnt{depth: p.depth, data: string(p.next())}
}

// parseNumber 파싱 로직: -12, 1e12, 0x16 등 처리
//   - 부호가 있으면 먼저 확인 (ex: -12, -0x16)
//   - 0x(또는 0X)인 경우, 뒤에 최소 한 글자 이상 헥사 숫자가 있어야 hex=true
//   - 10진수 처리 후, e/E 등장 시 뒤에 숫자가 있는지 검사 (ex: 1e12)
//   - 만약 숫자가 전혀 없으면, 부호만 반환(혹은 오류 처리).
//
// 문자열, isHex
func (p *Parser) parseNumber() (string, bool) {
	// 1) 부호 확인
	sign := ""
	if !p.eof() && p.peek() == '-' {
		sign = "-"
		p.next() // '-' 소비
	}

	// 2) 0x(또는 0X) 형태인지 확인 (부호 뒤에 '0x')
	//    예: -0x16
	if !p.eof() && p.peek() == '0' {
		// 다음 문자가 'x'나 'X'인지 확인
		nextPos := p.pos + 1
		if nextPos < len(p.input) && (p.input[nextPos] == 'x' || p.input[nextPos] == 'X') {
			// '0x'를 소비하기 전에 미리 헥사 숫자가 있는지 확인
			// 0x 또는 0X 자체만 있으면 숫자가 없는 것이므로, 그건 에러처리(또는 fallback)해야 함
			// 여기서는 간단히: 헥사 파트에 최소 한 글자라도 없으면 숫자 아님 처리

			// '0' 소비
			p.next()
			// 'x'/'X' 소비
			p.next()

			// 헥사 숫자를 읽어본다
			hexDigits := ""
			for !p.eof() {
				ch := p.peek()
				if (ch >= '0' && ch <= '9') ||
					(ch >= 'a' && ch <= 'f') ||
					(ch >= 'A' && ch <= 'F') {
					hexDigits += string(ch)
					p.next()
				} else {
					break
				}
			}

			if len(hexDigits) == 0 {
				// "0x" 뒤에 헥사 숫자가 없으면 -> 숫자로는 못 인식
				// 이 상황에서 어떻게 처리할지 결정해야 함.
				// 여기서는 임시로 sign + "0x"를 반환 (hex=false) 처리
				return sign + "0x", false
			}
			// 헥사 숫자가 한 글자 이상이면 정상 처리
			return sign + "0x" + hexDigits, true
		}
	}

	// 3) 10진수 처리 (부호/0x 제외 부분)
	decDigits := ""
	for !p.eof() {
		ch := p.peek()
		if ch >= '0' && ch <= '9' {
			decDigits += string(ch)
			p.next()
		} else {
			break
		}
	}

	if len(decDigits) == 0 {
		// 숫자가 전혀 없는 경우 (ex: "-"만 입력됨)
		// 여기서는 "숫자로 인식 실패 -> 부호만 반환" 처리
		return sign, false
	}

	// 3-1) 지수(e/E) 처리
	expo := ""
	if !p.eof() {
		ch3 := p.peek()
		if ch3 == 'e' || ch3 == 'E' {
			// e/E 소비
			echar := string(ch3)
			p.next()

			// e/E 뒤에 부호(+/-)가 있을 수 있음
			expSign := ""
			if !p.eof() && (p.peek() == '+' || p.peek() == '-') {
				expSign = string(p.peek())
				p.next()
			}

			// e/E 뒤의 숫자
			expDigits := ""
			for !p.eof() {
				ch4 := p.peek()
				if ch4 >= '0' && ch4 <= '9' {
					expDigits += string(ch4)
					p.next()
				} else {
					break
				}
			}
			// 만약 e/E 뒤에 숫자가 없다면 -> e부분 무효화 (1e 형태로 끝난 경우)
			if len(expDigits) == 0 {
				// e/E 뒤에 숫자 없어 -> 지수 인식 실패, 뒤로 되돌리거나?
				// 여기서는 간단히 "부호+10진수만" 반환
				return sign + decDigits, false
			}
			// e/E + (부호) + 숫자가 정상 인식되었다면 expo를 완성
			expo = echar + expSign + expDigits
		}
	}

	// 정상적인 10진수(부호, 10진수, 선택적 지수)
	return sign + decDigits + expo, false
}

// ── 결과 출력 함수 ─────────────────────────────────────────────

func printTokens(tokens []Ent, indent int) {
	indentStr := strings.Repeat("  ", indent)
	for _, tok := range tokens {
		switch t := tok.(type) {
		case alphaEnt:
			fmt.Printf("%salphaEnt(%q, depth:%d)\n", indentStr, t.data, t.depth)
		case numEnt:
			fmt.Printf("%snumEnt(%q, hex:%v, depth:%d)\n", indentStr, t.data, t.hex, t.depth)
		case wsEnt:
			fmt.Printf("%swsEnt(%q, depth:%d)\n", indentStr, t.data, t.depth)
		case markEnt:
			fmt.Printf("%smarkEnt(%q, depth:%d)\n", indentStr, t.data, t.depth)
		case groupEnt:
			fmt.Printf("%sgroupEnt(depth:%d) [\n", indentStr, t.depth)
			printTokens(t.data, indent+1)
			fmt.Printf("%s]\n", indentStr)
		case rootEnt:
			if t.isPattern {
				fmt.Printf("%srootEnt(depth:%d, pattern:%q) [\n", indentStr, t.depth, t.pattern)
			} else {
				fmt.Printf("%srootEnt(depth:%d) [\n", indentStr, t.depth)
			}
			printTokens(t.data, indent+1)
			fmt.Printf("%s]\n", indentStr)
		default:
			fmt.Printf("%sUnknown token\n", indentStr)
		}
	}
}

func parseString(s string) []Ent {
	lx := NewLexer(s)
	tokens := lx.Lex()
	keyValParsed := parseKeyVals(tokens)
	bracketParsed := parseBrackets(keyValParsed)
	return bracketParsed
}

// ── main ─────────────────────────────────────────────

func main() {
	// 예제 1: JSON 형식 문자열 (괄호 내 return 블록은 groupEnt로 처리)
	input := "{a:appple,b:apple}"
	parser := NewParser(input)
	tokens := parser.parseTokens(0)
	// 최상위 노드는 rootEnt로 생성 (groupEnt은 내부에서만 사용)
	root := rootEnt{depth: 0, data: tokens}
	root = applyPatternToRoot(root)
	fmt.Println("Parsed tokens (예제 1):")
	printTokens([]Ent{root}, 0)

	// 예제 2: URL 문자열
	input = "https://www.naver.com?search=0x16+1e14"
	parser = NewParser(input)
	tokens = parser.parseTokens(0)
	root = rootEnt{depth: 0, data: tokens}
	root = applyPatternToRoot(root)
	fmt.Println("\nParsed tokens (예제 2):")
	printTokens([]Ent{root}, 0)

	// 예제 3: 일반 문자열 (패턴은 rootEnt에서만 전담)
	input = `func main() {
		parser := NewParser(input)
		tokens := parser.parseTokens(0)
		root := rootEnt{depth: 0, data: tokens}
		root = applyPatternToRoot(root)
		printTokens([]Ent{root}, 0)
		printTokens([]Ent{root}, 0)
	}`
	parser = NewParser(input)
	tokens = parser.parseTokens(0)
	root = rootEnt{depth: 0, data: tokens}
	root = applyPatternToRoot(root)
	fmt.Println("\nParsed string (예제 3):")
	fmt.Println("Detected pattern:", root.pattern)
	printTokens([]Ent{root}, 0)
	input = "{a:apple} hello := world (x=4)"
	root = rootEnt{depth: 0, data: parseString(input)}
	final := applyPatternToRoot(root)
	fmt.Println("Detected pattern:", final.pattern)
	printTokens([]Ent{final}, 0)
}
