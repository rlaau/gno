// Copyright 2015 go-fuzz project authors. All rights reserved.
// Modified by rlaau in 2025.
// This file is based on go-fuzz (Apache 2.0 License).
// https://github.com/dvyukov/go-fuzz/blob/master/go-fuzz/versifier/versifier.go is original code.
// Some functions were modified to fit "GNO" language.

// Package versifier recognizes internal structure of random (currently text-only) data
// and allows to generate data of a similar structure (for some very weak definition of "similar").
package versifier

/*
On efficiency of versifier.
On xml text after 2.5 hours of fuzzing:
Without versifier fuzzing discovered 902 inputs.
With versifier fuzzing discovered 1055 inputs and versifier discovered 83 inputs.
Versifier generated new inputs + increased fuzzing efficiency by 25% +
uncovered 62 new basic blocks (excluding counters) which accounts for 2.5% of all discovered basic blocks.
On json test after 1 hour of fuzzing:
Versifier uncovered 15 new basic blocks (excluding counters) which accounts for 1.15% of all discovered basic blocks.

Research on automatic protocol reverse engineering:
- Sequitur (or Nevill-Manning algorithm) algorithm:
http://en.wikipedia.org/wiki/Sequitur_algorithm
- Discoverer: Automatic Protocol Reverse Engineering from Network Traces
http://research.microsoft.com/pubs/153196/discoverer-security07.pdf
- Reverse Engineering of Protocols from Network Traces
http://www.di.fc.ul.pt/~nuno/PAPERS/WCRE11.pdf
*/

import (
	"bytes"
	"fmt"
	"io"
	"strings"
	"testing"
	"unicode/utf8"
)

func BuildVerse(oldv *Verse, data []byte) *Verse {
	// Check if the data is something texty. If not, don't bother parsing it.
	// Versifier don't know how to recognize structure in binary data.
	// TODO: we could detect text and binary parts and handle them separately
	// (think of an HTTP request with compressed body).

	printable := 0
	for _, b := range data {
		if b >= 0x20 && b < 0x7f {
			printable++
		}
	}
	if printable < len(data)*9/10 {
		return oldv
	}

	newv := &Verse{}
	if oldv != nil {
		newv.blocks = oldv.blocks
		newv.allNodes = oldv.allNodes
	}
	n := tokenize(data)
	n = structure(n)
	b := &BlockNode{n}
	newv.blocks = append(newv.blocks, b)
	b.Visit(func(n Node) {
		newv.allNodes = append(newv.allNodes, n)
	})
	newv.r = testing.GetPCG()
	return newv
}

type Node interface {
	Visit(f func(Node))
	Print(sb *strings.Builder, ident int)
	Generate(sb *strings.Builder, v *Verse)
}

func makeDict(s []byte) map[string]struct{} {
	return map[string]struct{}{string(s): {}}
}

func fmtDict(dict map[string]struct{}) string {
	var list []string
	for s := range dict {
		list = append(list, fmt.Sprintf("%q", s))
	}
	return strings.Join(list, ",")
}

func randTerm(v *Verse, dict map[string]struct{}) []byte {
	terms := make([]string, 0, len(dict))
	for k := range dict {
		terms = append(terms, k)
	}
	return []byte(terms[v.Rand(len(terms))])
}

func singleTerm(dict map[string]struct{}) string {
	for k := range dict {
		return k
	}
	panic("bad")
}

type WsNode struct {
	dict map[string]struct{}
}

func (n *WsNode) Visit(f func(n Node)) {
	f(n)
}

func (n *WsNode) Print(sb *strings.Builder, ident int) {
	s := fmt.Sprintf("%sws{%s}\n", repeatString("  ", ident), fmtDict(n.dict))
	sb.WriteString(s)
}

func repeatString(s string, count int) string {
	if count <= 0 {
		return ""
	}
	var sb strings.Builder
	sb.Grow(len(s) * count) // 미리 메모리 예약
	for i := 0; i < count; i++ {
		sb.WriteString(s)
	}
	return sb.String()
}

func (n *WsNode) Generate(sb *strings.Builder, v *Verse) {
	if v.Rand(5) != 0 {
		sb.WriteString(string(randTerm(v, n.dict)))
	} else {
	loop:
		for {
			switch v.Rand(3) {
			case 0:
				break loop
			case 1:
				sb.WriteString(" ")
			case 2:
				sb.WriteString("\t")
			}
		}
	}
}

type AlphaNumNode struct {
	dict map[string]struct{}
}

func (n *AlphaNumNode) Visit(f func(n Node)) {
	f(n)
}

func (n *AlphaNumNode) Print(sb *strings.Builder, ident int) {
	s := fmt.Sprintf("%salphanum{%s}\n", repeatString("  ", ident), fmtDict(n.dict))
	sb.WriteString(s)
}

func (n *AlphaNumNode) Generate(sb *strings.Builder, v *Verse) {
	if v.Rand(5) != 0 {
		sb.WriteString(string(randTerm(v, n.dict)))
	} else {
		lenght := 0
		switch v.Rand(3) {
		case 0:
			lenght = v.Rand(4)
		case 1:
			lenght = v.Rand(20)
		case 2:
			lenght = v.Rand(100)
		}
		res := make([]byte, lenght)
		for i := range res {
			switch v.Rand(4) {
			case 0:
				res[i] = '_'
			case 1:
				res[i] = '0' + byte(v.Rand(10))
			case 2:
				res[i] = 'a' + byte(v.Rand(26))
			case 3:
				res[i] = 'A' + byte(v.Rand(26))
			}
		}
		sb.WriteString(string(res))
	}
}

type NumNode struct {
	dict map[string]struct{}
	hex  bool
}

func (n *NumNode) Visit(f func(n Node)) {
	f(n)
}

func (n *NumNode) Print(sb *strings.Builder, ident int) {
	s := fmt.Sprintf("%snum{hex=%v, %s}\n", repeatString("  ", ident), n.hex, fmtDict(n.dict))
	sb.WriteString(s)
}

func (n *NumNode) Generate(sb *strings.Builder, v *Verse) {
	if v.Rand(2) == 0 {
		sb.WriteString(string(randTerm(v, n.dict)))
	} else {
		randNum := func() []byte {
			base := []int{8, 10, 16}[v.Rand(3)]
			lenght := 0
			switch v.Rand(3) {
			case 0:
				lenght = v.Rand(4)
			case 1:
				lenght = v.Rand(16)
			case 2:
				lenght = v.Rand(40)
			}
			num := make([]byte, lenght+1)
			for i := range num {
				switch base {
				case 8:
					num[i] = '0' + byte(v.Rand(8))
				case 10:
					num[i] = '0' + byte(v.Rand(10))
				case 16:
					switch v.Rand(3) {
					case 0:
						num[i] = '0' + byte(v.Rand(10))
					case 1:
						num[i] = 'a' + byte(v.Rand(6))
					case 2:
						num[i] = 'A' + byte(v.Rand(6))
					}
				}
			}
			switch base {
			case 8:
				num = append([]byte{'0'}, num...)
			case 10:
			case 16:
				num = append([]byte{'0', 'x'}, num...)
			default:
				panic("bad")
			}
			if v.Rand(2) == 0 {
				num = append([]byte{'-'}, num...)
			}
			return num
		}
		switch v.Rand(3) {
		case 0:
			sb.WriteString(string(randNum()))
		case 1:
			sb.WriteString(string(randNum()))
			sb.WriteString(string("."))
			sb.WriteString(string(randNum()))

		case 2:
			sb.WriteString(string(randNum()))

			sb.WriteString(string("e"))
			sb.WriteString(string(randNum()))

		}
	}
}

type ControlNode struct {
	ch rune
}

func (n *ControlNode) Visit(f func(n Node)) {
	f(n)
}

func (n *ControlNode) Print(sb *strings.Builder, ident int) {
	s := fmt.Sprintf("%s%q\n", repeatString("  ", ident), string(n.ch))
	sb.WriteString(s)
}

func (n *ControlNode) Generate(sb *strings.Builder, v *Verse) {
	if v.Rand(10) != 0 {
		sb.WriteString(string(n.ch))
	} else {
		for {
			b := byte(v.Rand(128))
			if b >= '0' && b <= '9' || b >= 'a' && b <= 'z' || b >= 'A' && b <= 'Z' {
				continue
			}
			sb.WriteString(string(b))
			break
		}
	}
}

type BracketNode struct {
	open rune
	clos rune
	b    *BlockNode
}

var brackets = map[rune]rune{
	'<':  '>',
	'[':  ']',
	'(':  ')',
	'{':  '}',
	'\'': '\'',
	'"':  '"',
	'`':  '`',
}

func (n *BracketNode) Visit(f func(n Node)) {
	f(n)
	n.b.Visit(f)
}

func (n *BracketNode) Print(sb *strings.Builder, ident int) {
	s1 := fmt.Sprintf("%s%s\n", repeatString("  ", ident), string(n.open))
	sb.WriteString(s1)

	n.b.Print(sb, ident+1)

	s2 := fmt.Sprintf("%s%s\n", repeatString("  ", ident), string(n.clos))

	sb.WriteString(s2)
}

func (n *BracketNode) Generate(sb *strings.Builder, v *Verse) {
	if v.Rand(10) != 0 {
		sb.WriteString(string(n.open))
		n.b.Generate(sb, v)
		sb.WriteString(string(n.clos))
	} else {
		brk := []rune{'<', '[', '(', '{', '\'', '"', '`'}
		open := brk[v.Rand(len(brk))]
		clos := brackets[open]
		if v.Rand(5) == 0 {
			clos = brackets[brk[v.Rand(len(brk))]]
		}
		sb.WriteString(string(open))
		n.b.Generate(sb, v)
		sb.WriteString(string(clos))
	}
}

type KeyValNode struct {
	delim rune
	key   *AlphaNumNode
	value Node // 기존의 *AlphaNumNode 대신 Node로 허용하여, 알파넘이나 숫자 모두 지원
}

func (n *KeyValNode) Visit(f func(n Node)) {
	f(n)
	n.key.Visit(f)
	n.value.Visit(f)
}

func (n *KeyValNode) Print(sb *strings.Builder, ident int) {
	s1 := fmt.Sprintf("%skeyval\n", repeatString("  ", ident))
	sb.WriteString(s1)

	n.key.Print(sb, ident+1)

	s2 := fmt.Sprintf("%s%s\n", repeatString("  ", ident+1), string(n.delim))
	sb.WriteString(s2)

	n.value.Print(sb, ident+1)
}

func (n *KeyValNode) Generate(sb *strings.Builder, v *Verse) {
	delim := []rune{'=', ':'}
	n.delim = delim[v.Rand(len(delim))]
	n.key.Generate(sb, v)
	sb.WriteString(string(n.delim))
	n.value.Generate(sb, v)
}

type ListNode struct {
	delim  rune
	blocks []*BlockNode
}

func (n *ListNode) Visit(f func(n Node)) {
	f(n)
	for _, b := range n.blocks {
		b.Visit(f)
	}
}

func (n *ListNode) Print(sb *strings.Builder, ident int) {
	s := fmt.Sprintf("%slist\n", repeatString("  ", ident))
	sb.WriteString(s)

	for i, b := range n.blocks {
		if i != 0 {
			sDelim := fmt.Sprintf("%s%s\n", repeatString("  ", ident), string(n.delim))
			sb.WriteString(sDelim)
		}
		b.Print(sb, ident+1)
	}
}

func (n *ListNode) Generate(sb *strings.Builder, v *Verse) {
	blocks := n.blocks
	if v.Rand(5) == 0 {
		blocks = nil
		for v.Rand(3) != 0 {
			blocks = append(blocks, n.blocks[v.Rand(len(n.blocks))])
		}
	}
	for i, b := range blocks {
		if i != 0 {
			sb.WriteString(string(n.delim))
		}
		b.Generate(sb, v)
	}
}

type LineNode struct {
	r bool
	b *BlockNode
}

func (n *LineNode) Visit(f func(n Node)) {
	f(n)
	n.b.Visit(f)
}

func (n *LineNode) Print(sb *strings.Builder, ident int) {
	rn := "\\n"
	if n.r {
		rn = "\\r\\n"
	}
	s := fmt.Sprintf("%sline %s\n", repeatString("  ", ident), rn)
	sb.WriteString(s)
	n.b.Print(sb, ident+1)
}

func (n *LineNode) Generate(sb *strings.Builder, v *Verse) {
	n.b.Generate(sb, v)
	if n.r {
		sb.WriteString(string("\r\n"))
	} else {
		sb.WriteString(string("\n"))
	}
}

type BlockNode struct {
	nodes []Node
}

func (n *BlockNode) Visit(f func(n Node)) {
	f(n)
	for _, n := range n.nodes {
		n.Visit(f)
	}
}

func (n *BlockNode) Print(sb *strings.Builder, ident int) {
	for _, n := range n.nodes {
		n.Print(sb, ident)
	}
}

func (n *BlockNode) Generate(sb *strings.Builder, v *Verse) {
	nodes := append([]Node{}, n.nodes...)
	if v.Rand(10) == 0 {
		for len(nodes) > 0 && v.Rand(2) == 0 {
			idx := v.Rand(len(nodes))
			copy(nodes[:idx], nodes[idx+1:])
			nodes = nodes[:len(nodes)-1]
		}
	}
	if v.Rand(10) == 0 {
		for len(nodes) > 0 && v.Rand(2) == 0 {
			idx := v.Rand(len(nodes))
			nodes = append(nodes, nil)
			copy(nodes[idx+1:], nodes[idx:])
		}
	}
	if v.Rand(10) == 0 {
		for len(nodes) > 0 && v.Rand(2) == 0 {
			idx1 := v.Rand(len(nodes))
			idx2 := v.Rand(len(nodes))
			nodes[idx1], nodes[idx2] = nodes[idx2], nodes[idx1]
		}
	}
	for _, n := range nodes {
		if v.Rand(20) == 0 {
			continue
		}
		if v.Rand(20) == 0 {
			// TODO: replace subranges of nodes with other subranges of nodes.
			// That is, currently RandNode returns either a BlockNode or
			// an individual node within that BlockNode, but it ought to
			// be able to return a subrange of nodes within a BlockNode.
			n = v.RandNode()
		}
		n.Generate(sb, v)
	}
}

type Verse struct {
	blocks   []*BlockNode
	allNodes []Node
	r        *testing.PCG
}

func (v *Verse) Print(sb *strings.Builder) {
	for _, b := range v.blocks {
		b.Print(sb, 0)
		s := fmt.Sprintf("=======================\n")
		sb.WriteString(s)
	}
}

func (v *Verse) Rhyme() string {
	var sb strings.Builder
	v.blocks[v.Rand(len(v.blocks))].Generate(&sb, v)
	return sb.String()
}

func (v *Verse) Rand(n int) int {
	return v.r.Intn(n)
}

func (v *Verse) RandNode() Node {
	return v.allNodes[v.Rand(len(v.allNodes))]
}

func tokenize(data []byte) []Node {
	var res []Node
	const (
		stateControl = iota // 특수문자
		stateWs             // White space
		stateAlpha          // 영어
		stateNum            // 넘버
	)
	state := stateControl
	start := 0
	for i := 0; i < len(data); {
		r, s := utf8.DecodeRune(data[i:])
		switch {
		case r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r == '_':
			switch state {
			case stateControl:
				start = i
				state = stateAlpha
			case stateWs:
				res = append(res, &WsNode{makeDict(data[start:i])})
				start = i
				state = stateAlpha
			case stateAlpha:
			case stateNum:
				state = stateAlpha
			}

		case r >= '0' && r <= '9':
			switch state {
			case stateControl:
				start = i
				state = stateNum
			case stateWs:
				res = append(res, &WsNode{makeDict(data[start:i])})
				start = i
				state = stateNum
			case stateAlpha:
			case stateNum:
			}

		case r == ' ' || r == '\t':
			switch state {
			case stateControl:
				start = i
				state = stateWs
			case stateWs:
			case stateAlpha:
				res = append(res, &AlphaNumNode{makeDict(data[start:i])})
				start = i
				state = stateWs
			case stateNum:
				res = append(res, &NumNode{dict: makeDict(data[start:i])})
				start = i
				state = stateWs
			}

		default:
			switch state {
			case stateControl:
			case stateWs:
				res = append(res, &WsNode{makeDict(data[start:i])})
			case stateAlpha:
				res = append(res, &AlphaNumNode{makeDict(data[start:i])})
			case stateNum:
				res = append(res, &NumNode{dict: makeDict(data[start:i])})
			}
			state = stateControl
			res = append(res, &ControlNode{r})
		}
		i += s
	}
	switch state {
	case stateAlpha:
		res = append(res, &AlphaNumNode{map[string]struct{}{string(data[start:]): {}}})
	case stateNum:
		res = append(res, &NumNode{dict: map[string]struct{}{string(data[start:]): {}}})
	case stateWs:
		res = append(res, &WsNode{dict: map[string]struct{}{string(data[start:]): {}}})
	}
	return res
}

func structure(nn []Node) []Node {
	nn = extractNumbers(nn)
	nn = structureBrackets(nn)
	nn = structureKeyValue(nn)
	nn = structureLists(nn)
	nn = structureLines(nn)
	return nn
}

func isHexNum(s string) bool {
	if len(s) == 0 {
		return false
	}
	for _, c := range s {
		if c >= '0' && c <= '9' || c >= 'a' && c <= 'f' || c >= 'A' && c <= 'F' {
			continue
		}
		return false
	}
	return true
}

func isDecNum(s string) bool {
	if len(s) == 0 {
		return false
	}
	for _, c := range s {
		if c >= '0' && c <= '9' {
			continue
		}
		return false
	}
	return true
}

// 기존의 extractNumbers를 수정했음
// 기존 함수는 progress, preserve방식으로 한 번 순회마다 하나씩 extract했는데, 이걸 바꿈
// 문자열이 길어져도 안정적으로 바꾸게 함
// extractNumbers는 nn 슬라이스를 한 번 순회하면서
// 숫자에 해당하는 토큰들을 적절히 병합하여 NumNode로 변환합니다.
func extractNumbers(nn []Node) []Node {
	var result []Node
	for i := 0; i < len(nn); {
		// tryParseNumber가 nil이 아닌 값을 반환하면 숫자 토큰으로 인식한 것임
		if numNode, newIdx := tryParseNumber(nn, i, result); numNode != nil && newIdx > i {
			result = append(result, numNode)
			i = newIdx
		} else {
			result = append(result, nn[i])
			i++
		}
	}
	return result
}

// tryParseNumber는 nn[i:]에서 숫자 토큰을 추출하려 시도합니다.
// result에는 지금까지 누적된 토큰들이 들어가는데, 이는 부호('-')를 숫자로
// 해석할 수 있는지 결정할 때 사용됩니다. (sector-1같은 경우 -가 minus가 아니기 때문. 문맥을 보는 것)
func tryParseNumber(nn []Node, i int, result []Node) (Node, int) {
	var sb strings.Builder

	// [1] 선택적 부호 처리: 앞 토큰이 없거나, 이전 토큰이 알파벳 토큰이 아니거나,
	//     이전 토큰의 값이 'e'로 끝나는 경우에 한해서 부호로 취급합니다.
	if i < len(nn) {
		if ctrl, ok := nn[i].(*ControlNode); ok && ctrl.ch == '-' {
			// 이전 토큰이 없으면 그냥 부호로 취급
			if len(result) == 0 {
				sb.WriteRune('-')
				i++
			} else {
				last := result[len(result)-1]
				if alpha, ok := last.(*AlphaNumNode); !ok || (len(singleTerm(alpha.dict)) > 0 &&
					singleTerm(alpha.dict)[len(singleTerm(alpha.dict))-1] == 'e') {
					sb.WriteRune('-')
					i++
				}
			}
		}
	}

	// [2] 숫자로 시작하는 토큰이 있어야 함 (AlphaNumNode나 이미 변환된 NumNode)
	if i >= len(nn) || !isNumericCandidate(nn[i]) {
		return nil, i
	}
	sb.WriteString(tokenValue(nn[i]))
	i++

	// [3] 소수점 처리: 현재 토큰 뒤에 점('.')과 이어지는 숫자 토큰이 있으면 병합
	if i+1 < len(nn) {
		if dot, ok := nn[i].(*ControlNode); ok && dot.ch == '.' && isNumericCandidate(nn[i+1]) {
			sb.WriteRune('.')
			i++ // 점을 건너뜀
			sb.WriteString(tokenValue(nn[i]))
			i++
		}
	}

	// [4] 지수부 처리: 현재까지 병합된 문자열이 'e'로 끝나거나,
	//     다음 토큰이 'e' 또는 'E'라면 지수부로 인식
	s := sb.String()
	if strings.HasSuffix(s, "e") {
		// 지수부의 부호 처리 (예: 1e-1)
		if i < len(nn) {
			if ctrl, ok := nn[i].(*ControlNode); ok && (ctrl.ch == '-' || ctrl.ch == '+') {
				sb.WriteRune(ctrl.ch)
				i++
			}
		}
		if i < len(nn) && isNumericCandidate(nn[i]) {
			sb.WriteString(tokenValue(nn[i]))
			i++
		}
	} else if i < len(nn) {
		if ctrl, ok := nn[i].(*ControlNode); ok && (ctrl.ch == 'e' || ctrl.ch == 'E') {
			sb.WriteRune(ctrl.ch)
			i++
			if i < len(nn) {
				if ctrl2, ok := nn[i].(*ControlNode); ok && (ctrl2.ch == '-' || ctrl2.ch == '+') {
					sb.WriteRune(ctrl2.ch)
					i++
				}
			}
			if i < len(nn) && isNumericCandidate(nn[i]) {
				sb.WriteString(tokenValue(nn[i]))
				i++
			}
		}
	}

	numStr := sb.String()
	// [5] 최종 문자열에 따라 NumNode로 변환
	if len(numStr) >= 3 && numStr[0] == '0' &&
		(numStr[1] == 'x' || numStr[1] == 'X') && isHexNum(numStr[2:]) {
		return &NumNode{hex: true, dict: makeDict([]byte(numStr))}, i
	}
	// 소수점이나 지수부가 있거나 모든 문자가 십진수라면
	if strings.Contains(numStr, ".") || strings.ContainsAny(numStr, "eE") || isDecNum(numStr) {
		return &NumNode{hex: false, dict: makeDict([]byte(numStr))}, i
	}
	// 그 외에는 원래 알파벳 숫자 토큰으로 남김
	return &AlphaNumNode{dict: makeDict([]byte(numStr))}, i
}

// isNumericCandidate는 토큰이 숫자 시작으로 적합한지 검사합니다.
func isNumericCandidate(n Node) bool {
	switch t := n.(type) {
	case *AlphaNumNode:
		s := singleTerm(t.dict)
		if s == "" {
			return false
		}
		// 첫 글자가 숫자이거나 "0x"/"0X"로 시작하면 숫자로 간주
		if (s[0] >= '0' && s[0] <= '9') || (len(s) > 1 && s[0] == '0' &&
			(s[1] == 'x' || s[1] == 'X')) {
			return true
		}
		return false
	case *NumNode:
		s := singleTerm(t.dict)
		return s != ""
	default:
		return false
	}
}

// tokenValue는 AlphaNumNode나 NumNode의 실제 문자열 값을 반환합니다.
func tokenValue(n Node) string {
	switch t := n.(type) {
	case *AlphaNumNode:
		return singleTerm(t.dict)
	case *NumNode:
		return singleTerm(t.dict)
	default:
		return ""
	}
}

func structureKeyValue(nn []Node) []Node {
	// '='와 ':'를 key-value 구분자로 사용합니다.
	delims := map[rune]bool{'=': true, ':': true}

	// 먼저 괄호 내부의 노드들부터 재귀적으로 처리합니다.
	for _, n := range nn {
		if brk, ok := n.(*BracketNode); ok {
			brk.b.nodes = structureKeyValue(brk.b.nodes)
		}
	}

	// 인덱스 i를 0부터 순회하며 key-value 패턴을 찾아 합칩니다.
	i := 0
	for i < len(nn) {
		// 현재 토큰이 ControlNode여야 하며, 구분자여야 합니다.
		ctrl, ok := nn[i].(*ControlNode)
		if !ok || !delims[ctrl.ch] || i == 0 || i >= len(nn)-1 {
			i++
			continue
		}

		// 좌측 토큰를 키로 취급합니다.
		keyNode, ok := nn[i-1].(*AlphaNumNode)
		if !ok {
			i++
			continue
		}

		// 우측 토큰을 값으로 취급합니다.
		// 값은 알파넘(문자열) 또는 NumNode(숫자) 모두 허용합니다.
		var value Node
		switch v := nn[i+1].(type) {
		case *AlphaNumNode:
			value = v
		case *NumNode:
			value = v
		default:
			i++
			continue
		}

		// 새로운 KeyValNode를 생성합니다.
		kv := &KeyValNode{
			delim: ctrl.ch,
			key:   keyNode,
			value: value,
		}

		// 좌측의 key, 현재의 구분자, 우측의 값 토큰을 하나의 토큰으로 합칩니다.
		// nn를 재구성합니다.
		newNN := make([]Node, 0, len(nn)-2)
		newNN = append(newNN, nn[:i-1]...) // i-1 이전의 토큰들
		newNN = append(newNN, kv)          // 합쳐진 key-value 토큰
		if i+2 < len(nn) {
			newNN = append(newNN, nn[i+2:]...) // i+2 이후의 토큰들
		}
		nn = newNN

		// 합쳐졌으므로, 다시 처음부터 처리하거나 적절히 인덱스를 재조정합니다.
		// 여기서는 i를 0으로 재설정하여 중첩된 key-value도 처리합니다.
		i = 0
	}
	return nn
}

func structureBrackets(nn []Node) []Node {
	type Brk struct {
		open rune
		clos rune
		pos  int
	}
	// 스택. 브라켓용
	var stk []Brk
loop:
	for i := 0; i < len(nn); i++ {
		n := nn[i]
		ctrl, ok := n.(*ControlNode)
		if !ok {
			continue
		}
		// 스택에서 하나씩 제거하는 느낌. PDA의 간략한 구현인듯
		for si := len(stk) - 1; si >= 0; si-- {
			if ctrl.ch == stk[si].clos {
				b := &BracketNode{stk[si].open, stk[si].clos, &BlockNode{append([]Node{}, nn[stk[si].pos+1:i]...)}}
				nn[stk[si].pos] = b
				copy(nn[stk[si].pos+1:], nn[i+1:])
				nn = nn[:len(nn)-i+stk[si].pos]
				i = stk[si].pos
				stk = stk[:si]
				continue loop
			}
		}
		if clos, ok := brackets[ctrl.ch]; ok {
			stk = append(stk, Brk{ctrl.ch, clos, i})
		}
	}
	return nn
}

func structureLists(nn []Node) []Node {
	// 괄호 내부 노드들부터 재귀적으로 처리합니다.
	for _, n := range nn {
		if brk, ok := n.(*BracketNode); ok {
			brk.b.nodes = structureLists(brk.b.nodes)
		}
	}

	// 구분자로 쪼개기 위해 임시 배열 준비
	var elements [][]Node
	var current []Node

	// 노드들을 순회하면서 구분자(콤마, 세미콜론)를 기준으로 분할합니다.
	for _, node := range nn {
		if ctrl, ok := node.(*ControlNode); ok && (ctrl.ch == ',' || ctrl.ch == ';') {
			// 구분자 만났으면 지금까지 모은 current를 하나의 요소로 저장
			if len(current) > 0 {
				elements = append(elements, current)
				current = nil
			}
			// 구분자 노드는 버립니다.
			continue
		}
		current = append(current, node)
	}
	// 마지막 요소가 남았다면 추가
	if len(current) > 0 {
		elements = append(elements, current)
	}

	// 구분자로 분리된 요소가 2개 이상이면 ListNode로 묶습니다.
	if len(elements) > 1 {
		var blocks []*BlockNode
		for _, elem := range elements {
			// 각 요소(노드 슬라이스)를 BlockNode로 감쌉니다.
			blocks = append(blocks, &BlockNode{nodes: elem})
		}
		// ListNode를 생성하고 ListNode 하나만 담은 슬라이스로 반환합니다.
		return []Node{&ListNode{delim: ',', blocks: blocks}}
	}
	// 분리된 요소가 없다면 원본 nn을 그대로 반환합니다.
	return nn
}

func mapsEqual(a, b map[rune]bool) bool {
	if len(a) != len(b) {
		return false
	}
	for key := range a {
		if !b[key] {
			return false
		}
	}
	return true
}

type NodeSet struct {
	ctrl map[rune]bool
	brk  map[rune]bool
}

func structureLines(nn []Node) (res []Node) {
	for i := 0; i < len(nn); i++ {
		n := nn[i]
		if brk, ok := n.(*BracketNode); ok {
			brk.b.nodes = structureLines(brk.b.nodes)
			continue
		}
		if ctrl, ok := n.(*ControlNode); !ok || ctrl.ch != '\n' {
			continue
		}
		r := false
		end := i
		if i != 0 {
			if prev, ok := nn[i-1].(*ControlNode); ok && prev.ch == '\r' {
				r = true
				end--
			}
		}
		res = append(res, &LineNode{r, &BlockNode{nn[:end]}})
		nn = nn[i+1:]
		i = -1
	}
	if len(nn) != 0 {
		res = append(res, nn...)
	}
	return res
}
