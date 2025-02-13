package mutating

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

	// 1) ID 관련 메서드
	setID(id int)
	getID() int
	String() string

	SetScore(s int)
	GetScore() int
	PlusScore(delta int)

	// 변형하기
	Mutate2String(strength int, pattern string) (string, map[string]int)
	// // 2) 변형 전략 카운터
	// setStrategyCount(strategy string, val int)
	// getStrategyCount(strategy string) int
	// plusStrategyCount(strategy string, delta int)
}

// LetterEnt
type LetterEnt struct {
	Data  string
	Depth int

	Id    int // 추가
	Score int

	// 전략 사용 로그
	Strategy2count map[string]int
}

func (a *LetterEnt) setDepth(d int) { a.Depth = d }
func (a *LetterEnt) getDepth() int  { return a.Depth }

// 새로 추가된 메서드
func (a *LetterEnt) setID(id int) { a.Id = id }
func (a *LetterEnt) getID() int   { return a.Id }

// 🔥 String() 구현
func (a *LetterEnt) String() string {
	return fmt.Sprintf("LetterEnt{Data:%q, Depth:%d, Id:%d, Score: %d}", a.Data, a.Depth, a.Id, a.Score)
}
func (a *LetterEnt) SetScore(s int)      { a.Score = s }
func (a *LetterEnt) GetScore() int       { return a.Score }
func (a *LetterEnt) PlusScore(delta int) { a.Score += delta }

func (a *LetterEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
}

// 전략 카운트 관련 메서드
// 기본값은 1로 간주(초기화 안 된 경우)
// func (a *LetterEnt) setStrategyCount(strategy string, val int) {
// 	if a.Strategy2count == nil {
// 		a.Strategy2count = make(map[string]int)
// 	}
// 	a.Strategy2count[strategy] = val
// }

//	func (a *LetterEnt) getStrategyCount(strategy string) int {
//		if a.Strategy2count == nil {
//			return 1
//		}
//		if count, ok := a.Strategy2count[strategy]; ok {
//			return count
//		}
//		return 1
//	}
//
//	plusStrategyCount(strategy string, delta int)
//
// NumEnt
type NumEnt struct {
	Data  string
	Hex   bool
	Depth int

	Id    int // 추가
	Score int
}

func (n *NumEnt) setDepth(d int) { n.Depth = d }
func (n *NumEnt) getDepth() int  { return n.Depth }

func (n *NumEnt) setID(id int) { n.Id = id }
func (n *NumEnt) getID() int   { return n.Id }
func (n *NumEnt) String() string {
	return fmt.Sprintf("NumEnt{Data:%q, Hex:%v, Depth:%d, Id:%d, Score: %d}", n.Data, n.Hex, n.Depth, n.Id, n.Score)
}
func (n *NumEnt) SetScore(s int)      { n.Score = s }
func (n *NumEnt) GetScore() int       { return n.Score }
func (n *NumEnt) PlusScore(delta int) { n.Score += delta }
func (n *NumEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
}

// WsEnt
type WsEnt struct {
	Data  string
	Depth int

	Id    int
	Score int
}

func (w *WsEnt) setDepth(d int) { w.Depth = d }
func (w *WsEnt) getDepth() int  { return w.Depth }

func (w *WsEnt) setID(id int) { w.Id = id }
func (w *WsEnt) getID() int   { return w.Id }

// 🔥 String() 구현
func (w *WsEnt) String() string {
	// 공백을 그대로 보이도록 %q 형식
	return fmt.Sprintf("WsEnt{Data:%q, Depth:%d, Id:%d, Score: %d}", w.Data, w.Depth, w.Id, w.Score)
}
func (w *WsEnt) SetScore(s int)      { w.Score = s }
func (w *WsEnt) GetScore() int       { return w.Score }
func (w *WsEnt) PlusScore(delta int) { w.Score += delta }
func (w *WsEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
}

// MarkEnt
type MarkEnt struct {
	Data  string
	Depth int

	Id    int
	Score int
}

func (m *MarkEnt) setDepth(d int) { m.Depth = d }
func (m *MarkEnt) getDepth() int  { return m.Depth }

func (m *MarkEnt) setID(id int) { m.Id = id }
func (m *MarkEnt) getID() int   { return m.Id }

// 🔥 String() 구현
func (m *MarkEnt) String() string {
	return fmt.Sprintf("MarkEnt{Data:%q, Depth:%d, Id:%d, Score: %d}", m.Data, m.Depth, m.Id, m.Score)
}
func (m *MarkEnt) SetScore(s int)      { m.Score = s }
func (m *MarkEnt) GetScore() int       { return m.Score }
func (m *MarkEnt) PlusScore(delta int) { m.Score += delta }
func (m *MarkEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
}

// KeyValEnt
type KeyValEnt struct {
	Depth     int
	K         Ent
	PlOrNil   Ent
	PrOrNil   Ent
	Delimiter Ent
	V         Ent

	Id    int
	Score int
}

func (kv *KeyValEnt) setDepth(d int) { kv.Depth = d }
func (kv *KeyValEnt) getDepth() int  { return kv.Depth }

func (kv *KeyValEnt) setID(id int) { kv.Id = id }
func (kv *KeyValEnt) getID() int   { return kv.Id }
func (kv *KeyValEnt) String() string {
	return fmt.Sprintf("KeyValEnt{Depth:%d, Id:%d, K=%v, Delim=%v, V=%v, Score: %d}",
		kv.Depth, kv.Id, kv.K, kv.Delimiter, kv.V, kv.Score)
}
func (kv *KeyValEnt) SetScore(s int)      { kv.Score = s }
func (kv *KeyValEnt) GetScore() int       { return kv.Score }
func (kv *KeyValEnt) PlusScore(delta int) { kv.Score += delta }
func (kv *KeyValEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
}

// GroupEnt
type GroupEnt struct {
	Data      []Ent
	Depth     int
	IsPattern bool

	Id    int
	Score int
}

// 🔥 String() 구현
// 자식 정보는 간단히 length만 표시
func (g *GroupEnt) String() string {
	return fmt.Sprintf("GroupEnt{Len:%d, Depth:%d, Id:%d, IsPattern:%v, Score: %d}",
		len(g.Data), g.Depth, g.Id, g.IsPattern, g.Score)
}
func (g *GroupEnt) setDepth(d int) { g.Depth = d }
func (g *GroupEnt) getDepth() int  { return g.Depth }

func (g *GroupEnt) setID(id int)        { g.Id = id }
func (g *GroupEnt) getID() int          { return g.Id }
func (g *GroupEnt) SetScore(s int)      { g.Score = s }
func (g *GroupEnt) GetScore() int       { return g.Score }
func (g *GroupEnt) PlusScore(delta int) { g.Score += delta }
func (g *GroupEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
}

// RootEnt
type RootEnt struct {
	Data      []Ent
	Depth     int
	IsPattern bool
	Pattern   string

	Id int // 루트 자체의 id

	// 2) Id2Ent 맵: ID→Ent 빠른 접근
	Id2Ent map[int]Ent
	Score  int
}

func (r *RootEnt) setDepth(d int) { r.Depth = d }
func (r *RootEnt) getDepth() int  { return r.Depth }

func (r *RootEnt) setID(id int) { r.Id = id }
func (r *RootEnt) getID() int   { return r.Id }

// 🔥 String() 구현
// 요약: Data 개수, Pattern, ID, etc.
func (r *RootEnt) String() string {
	return fmt.Sprintf("RootEnt{Len:%d, Depth:%d, Pattern:%q, Id:%d, Score: %d}",
		len(r.Data), r.Depth, r.Pattern, r.Id, r.Score)
}
func (r *RootEnt) SetScore(s int)      { r.Score = s }
func (r *RootEnt) GetScore() int       { return r.Score }
func (r *RootEnt) PlusScore(delta int) { r.Score += delta }
func (r *RootEnt) Mutate2String(strength int, pattern string) (string, map[string]int) {
	return "", nil
	// DO_Somthing
	// TODO: Chage 메서드 추후 수정핟기
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
// 4) Lexer: []byte → 기본 토큰
// ─────────────────────────────

// Lexer는 이제 원본 입력을 []byte로 보존합니다.
type Lexer struct {
	input []byte
	pos   int
}

// NewLexer는 []byte를 받아 Lexer를 생성합니다.
func NewLexer(input []byte) *Lexer {
	return &Lexer{input: input, pos: 0}
}

func (lx *Lexer) eof() bool {
	return lx.pos >= len(lx.input)
}

// peek()는 현재 위치의 UTF‑8 인코딩된 문자에 해당하는 []byte를 반환합니다.
func (lx *Lexer) peek() []byte {
	if lx.eof() {
		return nil
	}
	// 현재 위치부터 UTF‑8 디코드
	_, size := utf8.DecodeRune(lx.input[lx.pos:])
	return lx.input[lx.pos : lx.pos+size]
}

// next()는 현재 위치의 UTF‑8 인코딩된 문자에 해당하는 []byte를 반환한 후,
// 내부 포지션을 해당 문자 길이만큼 증가시킵니다.
func (lx *Lexer) next() []byte {
	if lx.eof() {
		return nil
	}
	_, size := utf8.DecodeRune(lx.input[lx.pos:])
	b := lx.input[lx.pos : lx.pos+size]
	lx.pos += size
	return b
}

// matchString()은 주어진 문자열과 현재 위치부터의 바이트열을 비교합니다.
func (lx *Lexer) matchString(s string) bool {
	bs := []byte(s)
	if lx.pos+len(bs) > len(lx.input) {
		return false
	}
	for i, b := range bs {
		if lx.input[lx.pos+i] != b {
			return false
		}
	}
	return true
}

// sortMarksByLengthDesc는 마커 문자열을 길이 내림차순으로 정렬합니다.
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

// Lex()는 전체 []byte 입력을 스캔하여 토큰(Ent) 목록을 반환합니다.
func (lx *Lexer) Lex() []Ent {
	var tokens []Ent
	for !lx.eof() {
		t := lx.nextToken()
		if t != nil {
			t.setDepth(0) // lexer 단계에서는 모두 depth 0으로 초기화
			tokens = append(tokens, t)
		}
	}
	return tokens
}

// nextToken()는 전체 입력에서 하나의 토큰(Ent)을 반환합니다.
func (lx *Lexer) nextToken() Ent {
	// 현재 위치의 []byte를 가져와 UTF‑8 문자를 디코드
	pb := lx.peek()
	if pb == nil {
		return nil
	}
	r, _ := utf8.DecodeRune(pb)

	// 1) 줄바꿈 처리
	if r == '\n' {
		lx.next() // 줄바꿈 문자 소비
		return &MarkEnt{Data: "\n"}
	}

	// 2) 공백 (줄바꿈 제외)
	if unicode.IsSpace(r) {
		var sb strings.Builder
		for !lx.eof() {
			pb = lx.peek()
			if pb == nil {
				break
			}
			r, _ = utf8.DecodeRune(pb)
			if !unicode.IsSpace(r) || r == '\n' {
				break
			}
			sb.WriteRune(r)
			lx.next() // 소비
		}
		return &WsEnt{Data: sb.String()}
	}

	// 3) 숫자 또는 '-' 부호
	if unicode.IsDigit(r) || r == '-' {
		return lx.lexNumber()
	}

	// 4) 알파벳 (letter)
	if unicode.IsLetter(r) {
		var sb strings.Builder
		for !lx.eof() {
			pb = lx.peek()
			if pb == nil {
				break
			}
			r, _ = utf8.DecodeRune(pb)
			if !unicode.IsLetter(r) && !unicode.IsDigit(r) && r != '_' {
				break
			}
			sb.WriteRune(r)
			lx.next()
		}
		return &LetterEnt{Data: sb.String()}
	}

	// 5) 다중문자 마커 처리
	sorted := sortMarksByLengthDesc(parserMark)
	for _, mk := range sorted {
		if lx.matchString(mk) {
			lx.pos += len([]byte(mk))
			return &MarkEnt{Data: mk}
		}
	}

	// 6) 나머지 한 글자 처리
	b := lx.next()
	return &MarkEnt{Data: string(b)}
}

// lexNumber()는 숫자(10진수, 16진수, 지수 표현 등)를 파싱하여 NumEnt를 반환합니다.
func (lx *Lexer) lexNumber() Ent {
	sign := ""
	// 만약 음수 부호가 있다면 처리
	pb := lx.peek()
	if pb != nil {
		r, _ := utf8.DecodeRune(pb)
		if r == '-' {
			sign = "-"
			lx.next()
		}
	}
	// 16진수 처리: "0x" 또는 "0X"로 시작하는 경우
	pb = lx.peek()
	if pb != nil {
		r, _ := utf8.DecodeRune(pb)
		if r == '0' {
			if lx.pos+1 < len(lx.input) {
				nb := lx.input[lx.pos+1:]
				nr, _ := utf8.DecodeRune(nb)
				if nr == 'x' || nr == 'X' {
					lx.next()               // '0' 소비
					xCharBytes := lx.next() // 'x' 또는 'X' 소비
					xChar, _ := utf8.DecodeRune(xCharBytes)
					hexDigits := ""
					for !lx.eof() {
						pb = lx.peek()
						if pb == nil {
							break
						}
						r, _ = utf8.DecodeRune(pb)
						if (r >= '0' && r <= '9') || (r >= 'a' && r <= 'f') || (r >= 'A' && r <= 'F') {
							hexDigits += string(r)
							lx.next()
						} else {
							break
						}
					}
					if hexDigits == "" {
						return &NumEnt{
							Data: sign + "0" + string(xChar),
							Hex:  false,
						}
					}
					return &NumEnt{
						Data: sign + "0" + string(xChar) + hexDigits,
						Hex:  true,
					}
				}
			}
		}
	}
	// 10진수 처리
	digits := ""
	for !lx.eof() {
		pb = lx.peek()
		if pb == nil {
			break
		}
		r, _ := utf8.DecodeRune(pb)
		if !unicode.IsDigit(r) {
			break
		}
		digits += string(r)
		lx.next()
	}
	if digits == "" {
		return &MarkEnt{Data: sign}
	}
	// 지수 표현 처리: e 또는 E
	expo := ""
	pb = lx.peek()
	if pb != nil {
		r, _ := utf8.DecodeRune(pb)
		if r == 'e' || r == 'E' {
			lx.next() // e/E 소비
			expSign := ""
			pb = lx.peek()
			if pb != nil {
				r, _ = utf8.DecodeRune(pb)
				if r == '+' || r == '-' {
					expSign = string(r)
					lx.next()
				}
			}
			expDigits := ""
			for !lx.eof() {
				pb = lx.peek()
				if pb == nil {
					break
				}
				r, _ = utf8.DecodeRune(pb)
				if !unicode.IsDigit(r) {
					break
				}
				expDigits += string(r)
				lx.next()
			}
			if expDigits == "" {
				return &NumEnt{Data: sign + digits + "e" + expSign, Hex: false}
			}
			expo = "e" + expSign + expDigits
		}
	}
	return &NumEnt{Data: sign + digits + expo, Hex: false}
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
			if w, ok := tokens[pos].(*WsEnt); ok {
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
		md, ok2 := delimiter.(*MarkEnt)
		if !ok2 || (md.Data != ":" && md.Data != "=" && md.Data != ":=") {
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
			if w2, ok3 := tokens[pos].(*WsEnt); ok3 {
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
		kv := &KeyValEnt{
			Depth:     0,
			K:         left,
			PlOrNil:   leftPadding,
			Delimiter: delimiter,
			PrOrNil:   rightPadding,
			V:         right,
		}
		result = append(result, kv)

		// 키,왼쪽패딩,구분자,오른쪽패딩,값 소비
		i = pos + 1
	} // end for
	return result
}

func isAlphaOrNum(e Ent) bool {
	switch e.(type) {
	case *LetterEnt, *NumEnt:
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
		if mk, ok := tok.(*MarkEnt); ok && len(mk.Data) == 1 {
			openRune := rune(mk.Data[0])
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

func parseBracketGroup(tokens []Ent, from int) (*GroupEnt, int) {
	open, _ := tokens[from].(*MarkEnt)
	closeRune := bracketPairs[rune(open.Data[0])]
	g := &GroupEnt{
		Depth: 0,
		Data:  []Ent{open},
	}
	// open bracket depth는 그대로
	i := from + 1
	for i < len(tokens) {
		tok := tokens[i]
		if mk, ok := tok.(*MarkEnt); ok && len(mk.Data) == 1 {
			if rune(mk.Data[0]) == closeRune {
				// 닫는 bracket depth도 groupEnt.depth

				g.Data = append(g.Data, mk)
				return g, i + 1
			}
			// 중첩 괄호?
			if _, has := bracketPairs[rune(mk.Data[0])]; has {
				sub, consumed := parseBracketGroup(tokens, i)
				g.Data = append(g.Data, sub)
				i = consumed
				continue
			}
		}
		// 일반 토큰 => groupEnt.depth+1
		g.Data = append(g.Data, tok)
		i++
	}
	return g, i
}

// ─────────────────────────────
// 7) rootEnt + pattern
// ─────────────────────────────
func ParseToRoot(b []byte) *RootEnt {
	// 1) Lex
	lx := NewLexer([]byte(b))
	toks := lx.Lex()
	// k := &rootEnt{data: toks, depth: 0}
	// println("lexer")
	// printTree(k, 0)
	// 2) keyVal
	toks2 := parseKeyVals(toks)
	// 3) bracket
	toks3 := parseBrackets(toks2)
	// 4) rootEnt
	r := &RootEnt{Data: toks3, Depth: 0}
	r = applyPatternToRoot(r)
	finalizeDepth(r, 0)
	// 7) finalizeId(새로 추가)
	finalizeId(r)
	finalizeScore(r)
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
		case *WsEnt:
			continue
		case *LetterEnt:
			total++
			low := strings.ToLower(t.Data)
			if low == "return" || low == "func" || low == "for" ||
				low == "if" || low == "case" || low == "switch" || low == "int" {
				gnoCount++
			}
			if low == "http" || low == "https" {
				httpCount++
			}
		case *MarkEnt:
			total++
			d := strings.ToLower(t.Data)
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
		case *KeyValEnt:
			total++
			d := t.Delimiter
			var dStr string
			if delim, ok := d.(*MarkEnt); ok {
				dStr = delim.Data
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
	p, ok := detectPattern(r.Data)
	if ok {
		r.IsPattern = true
		r.Pattern = p
	}
	return r
}

// flattenTokens: groupEnt 안의 내용을 재귀적으로 펼침
func flattenTokens(tokens []Ent) []Ent {
	var out []Ent
	for _, e := range tokens {
		switch gg := e.(type) {
		case *GroupEnt:
			if len(gg.Data) > 0 {
				out = append(out, gg.Data[0]) // open bracket
				if len(gg.Data) > 2 {
					body := gg.Data[1 : len(gg.Data)-1]
					out = append(out, flattenTokens(body)...)
				}
				out = append(out, gg.Data[len(gg.Data)-1]) // close bracket
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
	case *KeyValEnt:
		finalizeDepth(kv.K, currentDepth+1)
		if kv.PlOrNil != nil {
			finalizeDepth(kv.PlOrNil, currentDepth+1)
		}
		finalizeDepth(kv.Delimiter, currentDepth+1)
		if kv.PrOrNil != nil {
			finalizeDepth(kv.PrOrNil, currentDepth+1)
		}
		finalizeDepth(kv.V, currentDepth+1)
	case *GroupEnt:
		// groupEnt 내부 토큰들은 currentDepth+1
		for _, c := range kv.Data {
			finalizeDepth(c, currentDepth+1)
		}
	case *RootEnt:
		// rootEnt 내부도 children은 currentDepth+1
		for _, c := range kv.Data {
			finalizeDepth(c, currentDepth+1)
		}
	}
	// alphaEnt, numEnt, wsEnt, markEnt 등은 자식 없음
}

// finalizeId: RootEnt에 모든 Ent들에 고유 ID를 부여하고,
// RootEnt.id2Ent에 저장.
func finalizeId(root *RootEnt) {
	root.Id2Ent = make(map[int]Ent) // 맵 초기화
	currentID := 0
	assignId(root, &currentID, root) // 시작점
}

// assignId: 재귀적으로 Ent에 ID를 설정하고
// root.id2Ent[currentID] = e로 저장.
func assignId(e Ent, currentID *int, root *RootEnt) {
	// 1) e에 ID 부여
	e.setID(*currentID)
	root.Id2Ent[*currentID] = e
	*currentID++

	// 2) 자식 노드(구조체별로 분기)
	switch node := e.(type) {
	case *KeyValEnt:
		if node.K != nil {
			assignId(node.K, currentID, root)
		}
		if node.PlOrNil != nil {
			assignId(node.PlOrNil, currentID, root)
		}
		if node.Delimiter != nil {
			assignId(node.Delimiter, currentID, root)
		}
		if node.PrOrNil != nil {
			assignId(node.PrOrNil, currentID, root)
		}
		if node.V != nil {
			assignId(node.V, currentID, root)
		}

	case *GroupEnt:
		for _, c := range node.Data {
			assignId(c, currentID, root)
		}

	case *RootEnt:
		for _, c := range node.Data {
			assignId(c, currentID, root)
		}

	// letterEnt, numEnt, wsEnt, markEnt 등 자식 없음
	default:
		// no children
	}
}

func finalizeScore(e Ent) {
	// e의 score를 1로 설정
	e.SetScore(1)

	// 자식 요소가 있으면 재귀적으로 finalizeScore
	switch kv := e.(type) {

	case *KeyValEnt:
		if kv.K != nil {
			finalizeScore(kv.K)
		}
		if kv.PlOrNil != nil {
			finalizeScore(kv.PlOrNil)
		}
		if kv.Delimiter != nil {
			finalizeScore(kv.Delimiter)
		}
		if kv.PrOrNil != nil {
			finalizeScore(kv.PrOrNil)
		}
		if kv.V != nil {
			finalizeScore(kv.V)
		}

	case *GroupEnt:
		for _, c := range kv.Data {
			finalizeScore(c)
		}

	case *RootEnt:
		for _, c := range kv.Data {
			finalizeScore(c)
		}

	// LetterEnt, NumEnt, WsEnt, MarkEnt 등은 자식 없음
	default:
		// no children
	}
}

// ─────────────────────────────
// 8) 출력
// ─────────────────────────────
func PrintTree(e Ent, indent int) {
	ind := strings.Repeat("  ", indent)
	idInfo := ""

	if e != nil {
		idInfo = fmt.Sprintf("id:%d", e.getID()) // 추가}
	}
	switch t := e.(type) {
	case *LetterEnt:
		fmt.Printf("%sletterEnt(%q, depth:%d, %s)\n", ind, t.Data, t.Depth, idInfo)
	case *NumEnt:
		fmt.Printf("%snumEnt(%q, hex:%v, depth:%d, %s)\n", ind, t.Data, t.Hex, t.Depth, idInfo)
	case *WsEnt:
		fmt.Printf("%swsEnt(%q, depth:%d, %s)\n", ind, t.Data, t.Depth, idInfo)
	case *MarkEnt:
		fmt.Printf("%smarkEnt(%q, depth:%d, %s)\n", ind, t.Data, t.Depth, idInfo)
	case *KeyValEnt:
		fmt.Printf("%skeyValEnt(depth:%d, %s)[\n", ind, t.Depth, idInfo)
		fmt.Printf("%s  k:\n", ind)
		PrintTree(t.K, indent+2)
		fmt.Printf("%s  pl:\n", ind)
		PrintTree(t.PlOrNil, indent+2)
		fmt.Printf("%s  delimiter:\n", ind)
		PrintTree(t.Delimiter, indent+2)
		fmt.Printf("%s  pr:\n", ind)
		PrintTree(t.PrOrNil, indent+2)
		fmt.Printf("%s  v:\n", ind)
		PrintTree(t.V, indent+2)
		fmt.Printf("%s]\n", ind)
	case *GroupEnt:
		fmt.Printf("%sgroupEnt(depth:%d, %s)[\n", ind, t.Depth, idInfo)
		for _, c := range t.Data {
			PrintTree(c, indent+1)
		}
		fmt.Printf("%s]\n", ind)
	case *RootEnt:
		if t.IsPattern {
			fmt.Printf("%srootEnt(depth:%d, pattern:%q, %s)[\n", ind, t.Depth, t.Pattern, idInfo)
		} else {
			fmt.Printf("%srootEnt(depth:%d, %s)[\n", ind, t.Depth, idInfo)
		}
		for _, c := range t.Data {
			PrintTree(c, indent+1)
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
func SerializeToTokens(e Ent) []Ent {
	switch t := e.(type) {

	// 1) 기본 토큰 (알파벳, 숫자, 공백, 기호 등)
	case *LetterEnt, *NumEnt, *WsEnt, *MarkEnt:
		// 직접적으로 한 개의 요소로 변환
		return []Ent{e}

	// 2) keyValEnt (k, plOrNil, delimiter, prOrNil, v 순서)
	case *KeyValEnt:
		var out []Ent
		// k
		out = append(out, SerializeToTokens(t.K)...)
		// plOrNil (왼쪽 공백)
		if t.PlOrNil != nil {
			out = append(out, SerializeToTokens(t.PlOrNil)...)
		}
		// delimiter
		out = append(out, SerializeToTokens(t.Delimiter)...)
		// prOrNil (오른쪽 공백)
		if t.PrOrNil != nil {
			out = append(out, SerializeToTokens(t.PrOrNil)...)
		}
		// v
		out = append(out, SerializeToTokens(t.V)...)
		return out

	// 3) groupEnt (첫 자식: 여는 괄호, 마지막 자식: 닫는 괄호, 중간: 내부)
	case *GroupEnt:
		// 보통 data[0]은 여는 bracket, data[len-1]은 닫는 bracket,
		// 나머지 중간이 본문
		// 그대로 재귀 펼침
		var out []Ent
		if len(t.Data) > 0 {
			// 여는 bracket
			out = append(out, SerializeToTokens(t.Data[0])...)
			// 내부
			for i := 1; i < len(t.Data)-1; i++ {
				out = append(out, SerializeToTokens(t.Data[i])...)
			}
			// 닫는 bracket
			if len(t.Data) > 1 {
				out = append(out, SerializeToTokens(t.Data[len(t.Data)-1])...)
			}
		}
		return out

	// 4) rootEnt
	case *RootEnt:
		// rootEnt 내부 data를 순회
		var out []Ent
		for _, c := range t.Data {
			out = append(out, SerializeToTokens(c)...)
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
	case *LetterEnt:
		return t.Data
	case *NumEnt:
		return t.Data
	case *WsEnt:
		return t.Data
	case *MarkEnt:
		return t.Data
	case nil:
		return ""
	default:
		// 이론상 여기는 오지 않음(serializeToTokens가 풀어줌)
		return ""
	}
}

// serializeToString는 AST 노드를 토큰으로 펼친 뒤,
// 각 토큰을 문자열로 변환하여 이어 붙여, 최종 문자열을 반환합니다.
func SerializeToString(e Ent) string {
	tokens := SerializeToTokens(e)
	var sb strings.Builder
	for _, tok := range tokens {
		sb.WriteString(entToString(tok))
	}
	return sb.String()
}

func SafeUTF8(s string) string {
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

	root := ParseToRoot([]byte(SafeUTF8(program)))
	PrintTree(root, 0)
	myAst := ParseToRoot([]byte(program))

	println("Root has", len(myAst.Id2Ent), "nodes total.")

	// 특정 ID로 바로 접근
	if ent, ok := myAst.Id2Ent[16]; ok {
		fmt.Println("ID=16 is Ent:", ent.String())
	}
	pp := "https://www.naver.com/search.naver?query=\xeb"
	rootp := ParseToRoot([]byte(pp))
	PrintTree(rootp, 0)
	ml := `<html><a>yeah!<a/><html/>`
	rootm := ParseToRoot([]byte(ml))
	PrintTree(rootm, 0)
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
