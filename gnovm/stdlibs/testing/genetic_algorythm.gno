package testing

import (
	"bytes"
	"fmt"
	"math"
	"time"
	"unicode/utf8"
)

// Evolve replaces the existing fitness and selection logic with f.manager to increase speed by managing seeds using a queue,set, arrary instead of following AFL's fitness management logic.
// It takes one or two parent seeds and returns evolved child seeds by performing crossover, mutate, and insertDelete operations.
//
// Parameters:
// seeds: parent seeds.
// seedCount: A pointer to f.seedCount, used to measure the number of inputs during the fuzzing process.
// stringByteCandidates: A slice of indexes“ indicating which arguments in seed.Content are of type string or []byte, which need to be specially handled during insertDelete.
func (f *F) evolve(seeds []seed, seedCount *uint, stringByteCandidates []int) []seed {
	p1 := seeds[0]
	// Set the mutation strength.
	// The lower the seed.Gen, the stronger the mutation, meaning more transformation attempts.
	MutationStrength := [10]int{5, 4, 3, 3, 2, 2, 2, 2, 2, 2}
	var mutationStrength int
	if int(p1.gen) > len(MutationStrength) {
		// The minimum number of transformations is 1
		mutationStrength = 1
	} else {
		mutationStrength = MutationStrength[p1.gen-1]
	}
	// Set the number of children to create.
	// The lower the seed.Gen, the higher the number, meaning more children are generated.
	// creatingCount values are experimentally determined to efficiently find failing inputs
	// in the shortest time while also maximizing coverage.
	// Setting larger values may allow trials to complete faster overall,
	// but it will likely increase the time needed to identify failing inputs.
	CreatingCount := [10]int{1440, 1280, 960, 480, 320, 280, 270, 260, 250, 240}
	var creatingCount int
	if int(p1.gen) > len(CreatingCount) {
		creatingCount = 240
	} else {
		creatingCount = CreatingCount[p1.gen-1]
	}

	loopCount := creatingCount / 2

	newGeneration := []seed{}

	// Case when there is only one parent seed
	if len(seeds) == 1 {
		for i := 0; i < int(creatingCount); i++ {
			newContent := make([]interface{}, len(seeds[0].content))
			// Perform immediate transformation without twoPointCrossover.
			for i, v := range seeds[0].content {
				newContent[i] = v
			}
			*seedCount++
			newInd := seed{
				gen:           seeds[0].gen + 1,
				isCoordinated: false,
				content:       newContent,
				result:        nil,
				pid:           seeds[0].id,
				id:            *seedCount,
			}

			// Maintain the ratio and strength of mutate and insertDelete.
			randSeed := i % 10
			switch randSeed {
			case 0, 1, 2, 3:
				// Only mutate
				newInd = mutate(newInd, mutationStrength)
			case 4, 5, 6:
				// Only insertDelete
				newInd = insertDelete(newInd, mutationStrength, stringByteCandidates)
			case 7, 8:
				// Modify with a fixed strength regardless of seed.gen to prevent mutations that are too small or too large.
				newInd = mutate(newInd, 2)
			case 9:
				// Mutate and insertDelete
				newInd = mutate(newInd, mutationStrength)
				newInd = insertDelete(newInd, mutationStrength, stringByteCandidates)
			}

			newInd.gen = seeds[0].gen + 1
			newGeneration = append(newGeneration, newInd)

		}
		return newGeneration
	}

	if len(seeds) > 3 {
		panic("not covered len")
	}

	p2 := seeds[1]

	// 1. Create newGeneration through twoPointCrossover
	for i := 0; i < int(loopCount); i++ {
		c1, c2 := twoPointCrossover(p1, p2, seedCount)
		newGeneration = append(newGeneration, c1)
		newGeneration = append(newGeneration, c2)

	}

	// 2. Modify each element of newGeneration with a certain ratio
	for i := range newGeneration {
		randSeed := i % 10
		switch randSeed {
		case 0, 1, 2:
			// Only mutate
			newGeneration[i] = mutate(newGeneration[i], mutationStrength)
		case 3:
			// Modify with a fixed strength regardless of seed.gen to prevent mutations that are too small or too large.
			newGeneration[i] = mutate(newGeneration[i], 2)
		case 4, 5, 6:
			// Crossover and do nothing
		case 7, 8:
			// Only insertDelete
			newGeneration[i] = insertDelete(newGeneration[i], mutationStrength, stringByteCandidates)
		case 9:
			// Mutate and insertDelete
			newGeneration[i] = mutate(newGeneration[i], mutationStrength)
			newGeneration[i] = insertDelete(newGeneration[i], mutationStrength, stringByteCandidates)
		}

	}

	return newGeneration
}

// mutate modifies the seed.content by the given mutationStrength and returns the mutated seed.
func mutate(seed seed, mutationStrength int) seed {
	var index int
	if len(seed.content) > 1 {
		index = int(RandRange(0, int64(len(seed.content))))
	} else {
		index = 0
	}

	selected := seed.content[index]

	// Use randomXXXFrom functions to gradually modify the given value.
	switch v := selected.(type) {
	case int, int8, int16, int32, int64:
		for i := 0; i < mutationStrength; i++ {
			seed.content[index] = randomIntFrom(v)
		}
	case uint, uint8, uint16, uint32, uint64:
		for i := 0; i < mutationStrength; i++ {
			seed.content[index] = randomUintFrom(v)
		}
	case float32, float64:
		for i := 0; i < mutationStrength; i++ {
			seed.content[index] = randomFloatFrom(v)
		}
	case bool:
		seed.content[index] = randomBool()
	// String is treated as []byte rather than []rune
	// []rune is not allowed to contain escaped bytes, but string can contain them.
	// https://go.dev/blog/strings
	// So all strings must be treated as []byte in fuzzing.
	// This describes the logic that handles strings as bytes.
	case string:

		tokens := tokenizeXXX(v)
		if len(tokens) > 0 {
			for i := 0; i < mutationStrength; i++ {
				tokenIndex := RandRange(0, int64(len(tokens)))
				tokens[tokenIndex].Data = mutateTokenData(tokens[tokenIndex].Data)
			}
		}

		var newStr string = rebuildString(tokens)
		seed.content[index] = newStr

		// bytes := []byte(v)
		// if len(bytes) > 0 {
		// 	for i := 0; i < mutationStrength; i++ {
		// 		byteIndex := RandRange(0, int64(len(bytes)))
		// 		bytes[byteIndex] = randomByteFrom(bytes[byteIndex])
		// 	}
		// }
		// var newStr string = string(bytes)
		// seed.content[index] = newStr

	case []byte:

		tokens := tokenizeXXX(v)
		if len(tokens) > 0 {
			for i := 0; i < mutationStrength; i++ {
				tokenIndex := RandRange(0, int64(len(tokens)))
				tokens[tokenIndex].Data = mutateTokenData(tokens[tokenIndex].Data)
			}
		}

		var newBytes []byte = rebuildBytes(tokens)
		seed.content[index] = newBytes
	default:
		panic("not supported type")
	}

	return seed
}

// mutateTokenData는 주어진 token data ([]byte)를 검사하여,
// 50% 확률로 원래 케이스 내에서, 50% 확률로 인접 케이스(자기 케이스 ±1)를 선택한 후,
// 그 케이스에 맞는 새로운 데이터를 생성하여 반환합니다.
func mutateTokenData(data []byte) []byte {
	origCase := inspectTokenData(data)
	var newCase int

	// 50% 확률로 자기 케이스, 50% 확률로 인접 케이스 선택
	if randomBool() {
		newCase = origCase
	} else {
		// 인접 케이스 선택: 경계인 경우 한쪽만 선택
		if origCase == 0 {
			newCase = 1
		} else if origCase == 4 {
			newCase = 3
		} else {
			// origCase가 1, 2, 또는 3이면, 랜덤으로 ±1
			if RandRange(0, 2) == 0 {
				newCase = origCase - 1
			} else {
				newCase = origCase + 1
			}
		}
	}

	// newCase에 따라 새로운 token data 생성
	switch newCase {
	case 0:
		// control/special: [0x00, 0x1F]
		return []byte{byte(RandRange(0, 0x1F-0x00+1) + 0x00)}
	case 1:
		// ASCII: [0x20, 0x7E]
		return []byte{byte(RandRange(0, 0x7E-0x20+1) + 0x20)}
	case 2:
		// DEL: 0x7F (DEL은 고정된 값)
		return []byte{0x7F}
	case 3:
		// 단독으로 사용된 바이트: [0x80, 0xFF]
		return []byte{byte(RandRange(0, 0xFF-0x80+1) + 0x80)}
	case 4:
		// 유효한 비-ASCII UTF-8 문자
		// 토큰 data의 길이에 따라 두 가지 경우로 나눕니다.
		if len(data) == 2 {
			// 두 바이트 문자: 예를 들어, U+0100 ~ U+07FF 범위
			r := rune(RandRange(0, 0x07FF-0x0100+1) + 0x0100)
			buf := make([]byte, utf8.UTFMax)
			n := utf8.EncodeRune(buf, r)
			return buf[:n]
		} else if len(data) == 3 {
			// 세 바이트 문자: U+0800 ~ U+FFFF (단, surrogate 영역은 제외)
			for {
				r := rune(RandRange(0, 0xFFFF-0x0800+1) + 0x0800)
				if r < 0xD800 || r > 0xDFFF {
					buf := make([]byte, utf8.UTFMax)
					n := utf8.EncodeRune(buf, r)
					return buf[:n]
				}
			}
		} else {
			// 그 외 길이인 경우, 기본적으로 두 바이트 문자 생성
			r := rune(RandRange(0, 0x07FF-0x0100+1) + 0x0100)
			buf := make([]byte, utf8.UTFMax)
			n := utf8.EncodeRune(buf, r)
			return buf[:n]
		}
	default:
		// 발생하면 안 됨
		return data
	}
}

// inspectTokenData는 토큰의 data를 검사하여 아래와 같이 분류합니다:
// 0: 단일 바이트인데 0x00 ~ 0x1F (제어/특수문자)
// 1: 단일 바이트인데 0x20 ~ 0x7E (ASCII)
// 2: 단일 바이트인데 0x7F (DEL)
// 3: 단일 바이트인데 0x80 이상 (단독으로 쓰면 유효하지 않은 UTF-8)
// 4: 다바이트이고, 유효한 UTF-8 문자 (비-ASCII)
func inspectTokenData(data []byte) int {
	// 빈 배열인 경우
	if len(data) == 0 {
		panic("logic error: token data can't empty")
	}

	// 길이가 1인 경우: 단일 바이트 값만 가지고 판별
	if len(data) == 1 {
		v := data[0]
		switch {
		case v < 0x20:
			// 특수문자=0
			return 0
		case v >= 0x20 && v <= 0x7E:
			// 아스키=1
			return 1
		case v == 0x7F:
			// DEL=2
			return 2
		default: // v >= 0x80
			// invalid utf=3
			return 3
		}
	}

	// 길이가 2 이상인 경우: UTF-8 디코딩을 시도
	r, size := utf8.DecodeRune(data)
	if r == utf8.RuneError && size == 1 {
		return 3
	}
	// 만약 b의 길이와 디코딩된 rune의 크기가 다르면, b에는 추가 바이트가 포함되어 있을 수 있습니다.
	if len(data) != size {
		// data가 룬의 조합이었을 경우
		// 토크나이징이 제대로 되지 않은 경우 발생 가능
		// 그러나 이는 로직 에러라고 볼 수 있음
		panic("logic error: tokenier didnt tokenize string well")
	}
	// 비영어권, 그러나 utf8문자자
	return 4
}

// insertDelete performs insertions and deletions on string and []byte fields in seed.content by the given mutationStrength and returns the modified seed.
func insertDelete(seed seed, mutationStrength int, stringByteCandidates []int) seed {
	if len(stringByteCandidates) == 0 {
		return seed
	}

	index := 0
	if len(stringByteCandidates) > 0 {
		selectedFieldIdx := RandRange(0, int64(len(stringByteCandidates)))
		index = stringByteCandidates[selectedFieldIdx]
	}

	selected := seed.content[index]

	switch v := selected.(type) {
	case []byte:

		// 1) []byte를 토큰화
		tokens := tokenizeXXX(v)
		// 2) 토큰 단위로 insert/delete
		tokens = insertDeleteTokens(tokens, mutationStrength)
		// 3) 토큰들을 다시 []byte로 복원
		newBytes := rebuildBytes(tokens)
		seed.content[index] = newBytes
	case string:
		// 1) 문자열을 토큰화
		tokens := tokenizeXXX(v)
		// 2) 토큰 단위로 insert/delete
		tokens = insertDeleteTokens(tokens, mutationStrength)
		// 3) 토큰들을 다시 문자열로 복원
		newStr := rebuildString(tokens)
		seed.content[index] = newStr
	default:
		panic("internal logic error")
	}
	return seed
}

// insertDeleteTokens는 주어진 tokens 슬라이스에 대해
// mutationStrength 횟수만큼 랜덤 삽입 또는 삭제를 수행합니다.
func insertDeleteTokens(tokens []token, mutationStrength int) []token {
	for i := 0; i < mutationStrength; i++ {
		if GenerateRandomBool(0.6) {
			// 60% 확률로 새 토큰 삽입
			tokens = insertRandomToken(tokens)
		} else {
			// 40% 확률로 토큰 삭제
			if len(tokens) > 0 {
				tokens = deleteRandomToken(tokens)
			} else {
				// 빈 슬라이스라면 토큰 삽입과 동일
				tokens = insertRandomToken(tokens)
			}
		}
	}
	return tokens
}

// insertRandomToken는 토큰 하나를 새로 생성하여
// tokens 슬라이스 내 임의 위치에 삽입합니다.
func insertRandomToken(tokens []token) []token {
	pos := RandRange(0, int64(len(tokens)+1))

	// 새 토큰(예: 간단히 랜덤 ASCII 문자 하나로 구성된 토큰) 생성
	newTok := randomToken()

	// 슬라이스에 삽입
	tokens = append(tokens[:pos], append([]token{newTok}, tokens[pos:]...)...)
	return tokens
}

// deleteRandomToken는 tokens 슬라이스에서 임의의 토큰 하나를 삭제합니다.
func deleteRandomToken(tokens []token) []token {
	if len(tokens) == 0 {
		return tokens
	}
	pos := RandRange(0, int64(len(tokens)))
	tokens = append(tokens[:pos], tokens[pos+1:]...)
	return tokens
}

// randomToken은 새로 삽입할 토큰 하나를 생성합니다.
// 필요에 따라 더 다양한 케이스(두 바이트, 세 바이트 한글 등)를 만들 수 있습니다.
func randomToken() token {
	// 예: 50% 확률로 단일 ASCII 문자, 50% 확률로 두 바이트 UTF-8 문자
	if GenerateRandomBool(0.5) {
		// 단일 ASCII
		b := byte(RandRange(0x20, 0x7E+1))
		return token{Data: []byte{b}, Valid: true}
	} else {
		// 간단히 2바이트 UTF-8 문자 범위 (U+00A0~U+07FF) 중 하나 생성
		r := rune(RandRange(0x00A0, 0x07FF+1))
		buf := make([]byte, 4)
		n := utf8.EncodeRune(buf, r)
		return token{Data: buf[:n], Valid: true}
	}
}

// twoPointCrossover performs two-point crossover on seed.content and returns two new seeds.
func twoPointCrossover(parent1, parent2 seed, seedCount *uint) (seed, seed) {
	content1 := make([]interface{}, len(parent1.content))
	for i, v := range parent1.content {
		content1[i] = v
	}
	content2 := make([]interface{}, len(parent2.content))
	for i, v := range parent2.content {
		content2[i] = v
	}

	for i := 0; i < len(parent1.content); i++ {
		switch v1 := content1[i].(type) {
		case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64, float32, float64:
			content1[i], content2[i] = factorizationCrossover(v1, content2[i])
		case bool:
			content1[i] = v1
			content2[i] = content2[i]

		case []byte:
			byt1 := v1
			byt2, ok := parent2.content[i].([]byte)
			if !ok {
				panic("type not equal")
			}
			p1Bytes := []byte(byt1)
			p2Bytes := []byte(byt2)
			resultByt1, resultByt2 := hybridCrossoverToken(p1Bytes, p2Bytes)
			content1[i] = resultByt1
			content2[i] = resultByt2
		case string:
			byt1 := v1
			byt2, ok := parent2.content[i].(string)
			if !ok {
				panic("type not equal")
			}
			p1Bytes := []byte(byt1)
			p2Bytes := []byte(byt2)
			resultByt1, resultByt2 := hybridCrossoverToken(p1Bytes, p2Bytes)
			resultStr1 := string(resultByt1)
			resultStr2 := string(resultByt2)
			content1[i] = resultStr1
			content2[i] = resultStr2
		default:
			panic("not supported type")

		}
	}

	*seedCount++
	updatedIdv1 := seed{
		gen:           parent1.gen + 1,
		isCoordinated: false,
		content:       content1,
		result:        nil,
		pid:           parent1.id,
		id:            *seedCount,
	}
	*seedCount++
	updatedIdv2 := seed{
		gen:           parent2.gen + 1,
		isCoordinated: false,
		content:       content2,
		result:        nil,
		pid:           parent1.id,
		id:            *seedCount,
	}

	return updatedIdv1, updatedIdv2
}

// hybridCrossoverToken performs a hybrid crossover on two []byte inputs at token level.
// It randomly selects one of several strategies:
//   - LCS-based crossover (40% 확률): 부모 간 공통 토큰 시퀀스를 그대로 물려줌.
//   - Two-point crossover (30% 확률): 기존 두 점 교차 방식.
//   - One-point crossover (15% 확률): 한 점에서 분할하여 교차.
//   - Uniform crossover (15% 확률): 각 토큰 위치마다 무작위 선택.
func hybridCrossoverToken(p1Bytes, p2Bytes []byte) ([]byte, []byte) {
	// 1) 토큰화
	tokens1 := tokenizeXXX(p1Bytes)
	tokens2 := tokenizeXXX(p2Bytes)

	// 토큰 배열 중 하나라도 비어 있으면, 임의 바이트로 대체.
	if len(tokens1) == 0 || len(tokens2) == 0 {
		seedByte := byte(' ')
		return []byte{randomByteFrom(seedByte)}, []byte{randomByteFrom(seedByte)}
	}

	r := GetPCG().Float64() // 0.0 <= r < 1.0

	// 40% 확률: LCS 기반 크로스오버로 공통 부분 보존
	if r < 0.4 {
		commonTokens := longestCommonSubsequence(tokens1, tokens2)
		if len(commonTokens) > 0 {
			newBytes := rebuildBytes(commonTokens)
			// 두 자손 모두 공통 토큰 시퀀스를 그대로 상속
			return newBytes, newBytes
		}
		// 만약 공통 토큰이 없으면 폴백하여 두 점 교차로 진행.
	}

	// 30% 확률: 기존 두 점 교차
	if r < 0.7 {
		return twoPointCrossoverToken(p1Bytes, p2Bytes)
	} else if r < 0.85 {
		// 15% 확률: 단일 점 교차
		return onePointCrossoverToken(p1Bytes, p2Bytes)
	} else {
		// 15% 확률: 균등 교차
		return uniformCrossoverToken(p1Bytes, p2Bytes)
	}
}

// longestCommonSubsequence는 두 토큰 슬라이스 a와 b의 LCS를 계산합니다.
func longestCommonSubsequence(a, b []token) []token {
	n, m := len(a), len(b)
	// dp[i][j]는 a[:i]와 b[:j]의 LCS 길이
	dp := make([][]int, n+1)
	for i := range dp {
		dp[i] = make([]int, m+1)
	}
	// 동적 계획법(DP) 테이블 채우기
	for i := 1; i <= n; i++ {
		for j := 1; j <= m; j++ {
			if tokensEqual(a[i-1], b[j-1]) {
				dp[i][j] = dp[i-1][j-1] + 1
			} else {
				dp[i][j] = max(dp[i-1][j], dp[i][j-1])
			}
		}
	}

	// DP 테이블을 거꾸로 추적하여 LCS 재구성
	var lcs []token
	i, j := n, m
	for i > 0 && j > 0 {
		if tokensEqual(a[i-1], b[j-1]) {
			// 앞쪽에 추가 (prepend)
			lcs = append([]token{a[i-1]}, lcs...)
			i--
			j--
		} else if dp[i-1][j] >= dp[i][j-1] {
			i--
		} else {
			j--
		}
	}
	return lcs
}

// tokensEqual는 두 토큰이 같은지 비교합니다.
// 여기서는 token의 Data 필드를 바이트 단위로 비교합니다.
func tokensEqual(t1, t2 token) bool {
	return bytes.Equal(t1.Data, t2.Data)
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// onePointCrossoverToken performs one-point crossover on two []byte inputs at token level.
func onePointCrossoverToken(p1Bytes, p2Bytes []byte) ([]byte, []byte) {
	tokens1 := tokenizeXXX(p1Bytes)
	tokens2 := tokenizeXXX(p2Bytes)

	// 두 토큰 배열의 최소 길이 결정
	minLen := len(tokens1)
	if len(tokens2) < minLen {
		minLen = len(tokens2)
	}
	if minLen == 0 {
		seedByte := byte(' ')
		return []byte{randomByteFrom(seedByte)}, []byte{randomByteFrom(seedByte)}
	}

	// 한 점을 무작위로 선택
	point := int(RandRange(0, int64(minLen)))
	child1Tokens := append([]token{}, tokens1[:point]...)
	child1Tokens = append(child1Tokens, tokens2[point:]...)

	child2Tokens := append([]token{}, tokens2[:point]...)
	child2Tokens = append(child2Tokens, tokens1[point:]...)

	return rebuildBytes(child1Tokens), rebuildBytes(child2Tokens)
}

// uniformCrossoverToken performs uniform crossover on two []byte inputs at token level.
// 각 토큰 인덱스마다 무작위로 어느 부모의 토큰을 선택합니다.
func uniformCrossoverToken(p1Bytes, p2Bytes []byte) ([]byte, []byte) {
	tokens1 := tokenizeXXX(p1Bytes)
	tokens2 := tokenizeXXX(p2Bytes)

	// 두 토큰 배열의 최소 길이 결정
	minLen := len(tokens1)
	if len(tokens2) < minLen {
		minLen = len(tokens2)
	}
	if minLen == 0 {
		seedByte := byte(' ')
		return []byte{randomByteFrom(seedByte)}, []byte{randomByteFrom(seedByte)}
	}

	child1Tokens := make([]token, 0, minLen)
	child2Tokens := make([]token, 0, minLen)

	for i := 0; i < minLen; i++ {
		if randomBool() {
			child1Tokens = append(child1Tokens, tokens1[i])
			child2Tokens = append(child2Tokens, tokens2[i])
		} else {
			child1Tokens = append(child1Tokens, tokens2[i])
			child2Tokens = append(child2Tokens, tokens1[i])
		}
	}

	// (옵션) 남은 토큰이 있다면, 더 긴 부모의 나머지 부분을 붙여 넣을 수 있음.
	// 여기서는 단순화를 위해 minLen까지만 사용합니다.
	return rebuildBytes(child1Tokens), rebuildBytes(child2Tokens)
}

// twoPointCrossoverToken는 p1Bytes와 p2Bytes를 토큰 단위로 2점 교차를 수행합니다.
// 1) 각각을 tokenize
// 2) minLen을 기준으로 두 점(point1, point2)을 뽑아서 교차
// 3) rebuildBytes로 다시 []byte로 변환
func twoPointCrossoverToken(p1Bytes []byte, p2Bytes []byte) ([]byte, []byte) {
	// 1) 각 바이트 슬라이스를 토큰화
	tokens1 := tokenizeXXX(p1Bytes)
	tokens2 := tokenizeXXX(p2Bytes)

	l1 := len(tokens1)
	l2 := len(tokens2)

	// 둘 중 더 짧은 길이를 minLen으로
	minLen := l1
	minIdx := 1
	if l2 < l1 {
		minLen = l2
		minIdx = 2
	}

	// 만약 두 쪽 중 하나라도 토큰이 없으면(둘 중 하나가 empty)
	if minLen == 0 {
		// 둘 다 empty라면 임의의 바이트 하나씩 생성
		maxLen := l1
		if minIdx == 1 {
			maxLen = l2
		}
		if maxLen == 0 {
			// 둘 다 빈 토큰 슬라이스
			seedByte := byte(' ')
			return []byte{randomByteFrom(seedByte)}, []byte{randomByteFrom(seedByte)}
		}
		// 둘 중 하나가 empty라면, empty쪽은 임의 바이트, 다른 쪽은 첫 토큰에서 랜덤 바이트를 뽑음
		var seedByte byte
		if minIdx == 1 {
			// tokens2가 empty
			seedByte = tokens1[0].Data[0]
		} else {
			// tokens1이 empty
			seedByte = tokens2[0].Data[0]
		}
		return []byte{randomByteFrom(seedByte)}, []byte{randomByteFrom(seedByte)}
	}

	// 2) point1, point2를 minLen 범위 내에서 선택
	point1 := RandRange(0, int64(minLen))
	point2 := RandRange(0, int64(minLen))
	if point1 > point2 {
		point1, point2 = point2, point1
	}

	// 3) 두 점 사이의 구간을 서로 교환하여 교차
	// tokens1 -> crossedTok1
	crossedTok1 := append([]token{}, tokens1[:point1]...)
	crossedTok1 = append(crossedTok1, tokens2[point1:point2]...)
	crossedTok1 = append(crossedTok1, tokens1[point2:]...)

	// tokens2 -> crossedTok2
	crossedTok2 := append([]token{}, tokens2[:point1]...)
	crossedTok2 = append(crossedTok2, tokens1[point1:point2]...)
	crossedTok2 = append(crossedTok2, tokens2[point2:]...)

	// 4) rebuildBytes로 다시 []byte 생성
	new1 := rebuildBytes(crossedTok1)
	new2 := rebuildBytes(crossedTok2)

	return new1, new2
}

// factorizationCrossover implements the crossover by multiplying two numbers and then dividing them into two numbers.
// and return these two numbers. It actually worked.
func factorizationCrossover(a interface{}, b interface{}) (interface{}, interface{}) {
	switch v1 := a.(type) {
	case int:
		v2, ok := b.(int)
		if !ok {
			panic("type not equal")
		}
		min := v1
		max := v2
		if v1 > v2 {
			min = v2
			max = v1
		}
		if min < 0 && max < 0 {
			min = max
			min = min * (-1)
		}
		if min < 0 {
			min = -1 * min
		}
		if min < 4 {
			min = 4
		}
		var newV1 int
		var newV2 int
		divisor := int(RandRange(1, int64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2
	case int8:
		v2, ok := b.(int8)
		if !ok {
			panic("type not equal")
		}
		min := v1
		max := v2
		if v1 > v2 {
			min = v2
			max = v1
		}
		if min < 0 && max < 0 {
			min = max
			min = min * (-1)
		}
		if min < 0 {
			min = -1 * min
		}
		if min < 4 {
			min = 4
		}
		var newV1 int8
		var newV2 int8
		divisor := int8(RandRange(1, int64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2
	case int16:
		v2, ok := b.(int16)
		if !ok {
			panic("type not equal")
		}
		min := v1
		max := v2
		if v1 > v2 {
			min = v2
			max = v1
		}
		if min < 0 && max < 0 {
			min = max
			min = min * (-1)
		}
		if min < 0 {
			min = -1 * min
		}
		if min < 4 {
			min = 4
		}
		var newV1 int16
		var newV2 int16
		divisor := int16(RandRange(1, int64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}

		return newV1, newV2
	case int32:
		v2, ok := b.(int32)
		if !ok {
			panic("type not equal")
		}
		min := v1
		max := v2
		if v1 > v2 {
			min = v2
			max = v1
		}
		if min < 0 && max < 0 {
			min = max
			min = min * (-1)
		}
		if min < 0 {
			min = -1 * min
		}
		if min < 4 {
			min = 4
		}
		var newV1 int32
		var newV2 int32
		divisor := int32(RandRange(1, int64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2

	case int64:
		v2, ok := b.(int64)
		if !ok {
			panic("type not equal")
		}
		min := v1
		max := v2
		if v1 > v2 {
			min = v2
			max = v1
		}
		if min < 0 && max < 0 {
			min = max
			min = min * (-1)
		}
		if min < 0 {
			min = -1 * min
		}
		if min < 4 {
			min = 4
		}
		var newV1 int64
		var newV2 int64
		divisor := RandRange(1, int64(min)/2)
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2

	case uint:
		v2, ok := b.(uint)
		if !ok {
			panic("type not equal")
		}
		min := v1
		if v1 > v2 {
			min = v2
		}
		if min < 4 {
			min = 4
		}
		var newV1 uint
		var newV2 uint
		divisor := uint(UintRandRange(1, uint64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2
	case uint8:
		v2, ok := b.(uint8)
		if !ok {
			panic("type not equal")
		}
		min := v1
		if v1 > v2 {
			min = v2
		}
		if min < 4 {
			min = 4
		}
		var newV1 uint8
		var newV2 uint8
		divisor := uint8(UintRandRange(1, uint64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2

	case uint16:
		v2, ok := b.(uint16)
		if !ok {
			panic("type not equal")
		}
		min := v1
		if v1 > v2 {
			min = v2
		}
		if min < 4 {
			min = 4
		}
		var newV1 uint16
		var newV2 uint16
		divisor := uint16(UintRandRange(1, uint64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2

	case uint32:
		v2, ok := b.(uint32)
		if !ok {
			panic("type not equal")
		}
		min := v1
		if v1 > v2 {
			min = v2
		}
		if min < 4 {
			min = 4
		}
		var newV1 uint32
		var newV2 uint32
		divisor := uint32(UintRandRange(1, uint64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2

	case uint64:
		v2, ok := b.(uint64)
		if !ok {
			panic("type not equal")
		}
		min := v1
		if v1 > v2 {
			min = v2
		}
		if min < 4 {
			min = 4
		}
		var newV1 uint64
		var newV2 uint64
		divisor := uint64(UintRandRange(1, uint64(min)/2))
		if randomBool() {
			newV1 = v1 / divisor
			newV2 = v2 * divisor
		} else {
			newV1 = v1 * divisor
			newV2 = v2 / divisor
		}
		return newV1, newV2

	case float32:
		v2, ok := b.(float32)
		if !ok {
			panic("type not equal")
		}
		newV1 := float32(0.7*float64(v1) + 0.3*float64(v2))
		newV2 := float32(0.3*float64(v1) + 0.7*float64(v2))
		return newV1, newV2
	case float64:
		v2, ok := b.(float64)
		if !ok {
			panic("type not equal")
		}
		newV1 := float64(0.3*float64(v1) + 0.7*float64(v2))
		newV2 := float64(0.3*float64(v1) + 0.7*float64(v2))
		return newV1, newV2
	default:
		panic("type can't be  factorization crossovered.")
	}
}

// randomXXXFrom gradually mutates XXX and return XXX
func randomByteFrom(seedByte byte) byte {
	p := GetPCG().Float64() // 0.0 <= p < 1.0

	var b uint8

	currentCase := determineCase(rune(seedByte))

	isProgress := GenerateRandomBool(0.5)
	if currentCase == 2 {
		switch {
		case p < 0.45:
			currentCase = (currentCase + 3) % 4
			break
		case p < 0.55:
			break

		case p <= 1.0:
			currentCase = (currentCase + 1) % 4
		}
	} else {
		switch {
		case p < 0.1:
			currentCase = (currentCase + 2) % 4
			isProgress = false
			break
		case p >= 0.1 && p < 0.25:
			currentCase = (currentCase + 3) % 4
			isProgress = false
			break
		case p >= 0.25 && p < 0.75:
			break

		case p >= 0.75 && p < 0.90:
			isProgress = true
			currentCase = (currentCase + 1) % 4
		case p >= 0.90 && p <= 1.0:
			isProgress = true
			currentCase = (currentCase + 2) % 4
		}
	}

	if currentCase == 2 {
		if isProgress {
			if UniformRandomBool(0.8) {
				currentCase = (currentCase + 1) % 4
			}
		} else {
			if UniformRandomBool(0.8) {
				currentCase = (currentCase + 3) % 4
			}
		}
	}

	switch currentCase {
	case 0:
		b = uint8(RandRange(AbsoluteMin, SpecialMAX+1))
	case 1:
		b = uint8(RandRange(LowAsciiMIN, LowAsciiMAX+1))
	case 2:

		b = Del
	case 3:
		b = uint8(RandRange(HighAsciiMin, HighAscillMax+1))

	}

	return byte(b)
}

const (
	AbsoluteMin = 0x00
	SpecialMAX  = 0x1F

	LowAsciiMIN = 0x20
	LowAsciiMAX = 0x7E
	Del         = 0x7F

	HighAsciiMin  = 0x80
	HighAscillMax = 0xFF
)

func determineCase(seedRune rune) int {
	switch {
	case seedRune >= AbsoluteMin && seedRune <= SpecialMAX:
		return 0
	case seedRune >= LowAsciiMIN && seedRune <= LowAsciiMAX:
		return 1
	case seedRune == Del:
		return 2
	case seedRune >= HighAsciiMin && seedRune <= HighAscillMax:
		return 3
	default:
		panic("logical error: default case must not be caught")
	}
}

// randomXXXFrom gradually mutates XXX and return XXX
func randomIntFrom(i interface{}) interface{} {
	p := GetPCG().Float64()

	switch v := i.(type) {
	case int:
		var i interface{}
		if v == 0 {
			return int(RandInt64())
		}
		switch {
		case p < 0.15:
			min := int64(v) * (-2)
			max := int64(v) * 2
			if min > max {
				min, max = max, min
			}
			i = int(RandRange(min, max))
		case p < 0.3:
			min := int64(v) * (-4)
			max := int64(v) * (4)
			if min > max {
				min, max = max, min
			}
			i = int(RandRange(min, max))
		case p < 0.45:
			min := int64(v) * (-8)
			max := int64(v) * (8)
			if min > max {
				min, max = max, min
			}
			i = int(RandRange(min, max))
		case p < 0.60:
			min := int64(v) * (-16)
			max := int64(v) * (16)
			if min > max {
				min, max = max, min
			}
			i = int(RandRange(min, max))
		default:
			i = int(GetPCG().Int())
		}
		return i

	case int8:
		if v == 0 {
			return int8(RandInt64())
		}
		var i8 interface{}
		switch {
		case p < 0.3:
			min := int64(v) * (-2)
			max := int64(v) * (2)
			if min > max {
				min, max = max, min
			}
			i8 = int8(RandRange(min, max))
		case p < 0.5:
			min := int64(v) * (-4)
			max := int64(v) * (4)
			if min > max {
				min, max = max, min
			}
			i8 = int8(RandRange(min, max))
		default:
			i8 = int8(RandRange(-128, 128))
		}
		return i8

	case int16:
		if v == 0 {
			return int16(RandInt64())
		}
		var i16 interface{}
		switch {
		case p < 0.3:
			min := int64(v) * (-2)
			max := int64(v) * (2)
			if min > max {
				min, max = max, min
			}
			i16 = int16(RandRange(min, max))
		case p < 0.5:
			min := int64(v) * (-4)
			max := int64(v) * (4)
			if min > max {
				min, max = max, min
			}
			i16 = int16(RandRange(min, max))
		default:
			i16 = int16(RandRange(-32768, 32768))
		}
		return i16

	case int32:
		if v == 0 {
			return int32(RandInt64())
		}
		var i16 interface{}
		switch {
		case p < 0.2:
			min := int64(v) * (-2)
			max := int64(v) * (2)
			if min > max {
				min, max = max, min
			}
			i16 = int32(RandRange(min, max))
		case p < 0.4:
			min := int64(v) * (-4)
			max := int64(v) * (4)
			if min > max {
				min, max = max, min
			}
			i16 = int32(RandRange(min, max))
		case p < 0.6:
			min := int64(v) * (-8)
			max := int64(v) * (8)
			if min > max {
				min, max = max, min
			}
			i16 = int32(RandRange(min, max))
		default:
			i16 = GetPCG().Int32
		}
		return i16

	case int64:
		if v == 0 {
			return RandInt64()
		}
		var i64 interface{}
		switch {
		case p < 0.15:
			min := v * (-2)
			max := v * (2)
			if min > max {
				min, max = max, min
			}
			i64 = RandRange(min, max)
		case p < 0.3:
			min := v * (-4)
			max := v * (4)
			if min > max {
				min, max = max, min
			}
			i64 = RandRange(min, max)
		case p < 0.45:
			min := v * (-8)
			max := v * (8)
			if min > max {
				min, max = max, min
			}
			i64 = RandRange(min, max)
		case p < 0.60:
			min := v * (-16)
			max := v * (16)
			if min > max {
				min, max = max, min
			}
			i64 = RandRange(min, max)
		default:
			i64 = GetPCG().Int64()
		}
		return i64

	default:
		panic("it's not supported int type")
	}
}

// randomXXXFrom gradually mutates XXX and return XXX
func randomUintFrom(u interface{}) interface{} {
	p := GetPCG().Float64()

	switch v := u.(type) {
	case uint:
		if v == 0 {
			return uint(RandUint64())
		}
		var u interface{}
		switch {
		case p < 0.3:
			min := v / 256
			max := v * 2
			u = uint(UintRandRange(uint64(min), uint64(max)))
		case p < 0.6:
			min := v / 9096
			max := v * 8
			u = uint(UintRandRange(uint64(min), uint64(max)))
		default:
			u = uint(GetPCG().Uint64())
		}
		return u

	case uint8:
		if v == 0 {
			return uint8(RandUint64())
		}
		var u8 interface{}
		switch {
		case p < 0.3:
			min := int64(v) / 8
			max := int64(v) * 2
			u8 = uint8(RandRange(min, max))
		case p < 0.6:
			min := int64(v) / 32
			max := int64(v) * 8
			u8 = uint8(RandRange(min, max))
		default:
			u8 = uint8(RandRange(0, 256))
		}
		return u8

	case uint16:
		if v == 0 {
			return uint16(RandUint64())
		}
		var u16 interface{}
		switch {
		case p < 0.3:
			min := int64(v) / 256
			max := int64(v) * 2
			u16 = uint16(RandRange(min, max))
		case p < 0.6:
			min := int64(v) / 9096
			max := int64(v) * 8
			u16 = uint16(RandRange(min, max))
		default:
			u16 = uint16(RandRange(0, 65536))
		}
		return u16

	case uint32:
		if v == 0 {
			return uint32(RandUint64())
		}
		var u32 interface{}
		switch {
		case p < 0.2:
			min := int64(v) / 256
			max := int64(v) * 2
			u32 = uint32(RandRange(min, max))
		case p < 0.4:
			min := int64(v) / 9096
			max := int64(v) * 8
			u32 = uint32(RandRange(min, max))
		case p < 0.6:
			min := int64(v) / (9096 * 9096)
			max := int64(v) * 16
			u32 = uint32(RandRange(min, max))
		default:
			u32 = uint32(RandRange(0, int64(^uint32(0))))
		}
		return u32

	case uint64:
		if v == 0 {
			return RandUint64()
		}
		var u64 interface{}
		switch {
		case p < 0.2:
			min := v / 256
			max := v * 2
			u64 = UintRandRange(min, max)
		case p < 0.5:
			min := v / 9096
			max := v * 8
			u64 = UintRandRange(min, max)
		case p < 0.5:
			min := v / (9096 * 9096)
			max := v * 16
			u64 = UintRandRange(min, max)
		default:
			u64 = RandUint64()
		}
		return u64

	default:
		panic("it's not a supported uint type")
	}
}

// randomXXXFrom gradually mutates XXX and return XXX
func randomFloatFrom(f interface{}) interface{} {
	switch v := f.(type) {
	case float32:
		var f32 float32
		f32 = randFloat32From(float32(v))
		return float32(f32)
	case float64:
		var f64 float64
		f64 = randFloat64From(float64(v))
		return float64(f64)
	default:
		panic("argument is not float 32 or float4")
	}
}

func randFloat32From(f float32) float32 {
	return randomFloat32(f)
}

func randFloat64From(f float64) float64 {
	return randomFloat64(f)
}

func randomBool() bool {
	return UniformRandomBool(0.5)
}

func randomFloat32(a float32) float32 {
	bits := math.Float32bits(a)

	exponent := (bits >> 23) & 0xFF
	mantissa := bits & 0x7FFFFF
	sign := bits & 0x80000000
	t := uint32(unixNano())
	manshift := 1 + (t % 7)

	var shift int8
	if exponent <= 1 {
		shift = int8(1 + int(mantissa%2))
	} else if exponent >= 0xFE {
		shift = int8(-1 - int(mantissa%2))
	} else {
		shift = int8(-2 + int(mantissa%5))
	}

	newExp := int32(exponent) + int32(shift)
	newExponent := uint32(newExp)

	newMantissa := mantissa ^ (mantissa >> manshift)

	newBits := sign | (newExponent << 23) | (newMantissa & 0x7FFFFF)

	return math.Float32frombits(newBits)
}

func randomFloat64(a float64) float64 {
	bits := math.Float64bits(a)

	exponent := (bits >> 52) & 0x7FF

	mantissa := bits & 0xFFFFFFFFFFFFF

	sign := bits & 0x8000000000000000

	t := uint64(time.Now().UnixNano())
	manshift := 1 + (t % 7)

	var shift int16
	if exponent <= 1 {
		shift = int16(1 + int64(mantissa%2))
	} else if exponent >= 0x7FE {
		shift = int16(-1 - int64(mantissa%2))
	} else {
		shift = int16(-2 + int64(mantissa%5))
	}

	newExp := int64(exponent) + int64(shift)
	newExponent := uint64(newExp)

	newMantissa := mantissa ^ (mantissa >> manshift)

	newBits := sign | (newExponent << 52) | (newMantissa & 0xFFFFFFFFFFFFF)

	return math.Float64frombits(newBits)
}
