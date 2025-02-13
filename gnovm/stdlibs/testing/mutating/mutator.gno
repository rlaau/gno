package mutating

import (
	"sort"
	"testing/fuzzing"
)

type Mutator struct {
	data map[fuzzing.HashNumber]MutSampleSet // key: hashNumber, value: mutSampleSet
}

type MutSample struct {
	seed     fuzzing.Seed
	rootEnts []RootEnt
}

type MutSampleSet struct {
	samples map[int]MutSample // Maintain ID-based dictionary
}

func (mss *MutSampleSet) add(id int, sample MutSample) {
	mss.samples[id] = sample
}

func (mss *MutSampleSet) isEmpty() bool {
	return len(mss.samples) == 0
}

func (mss *MutSampleSet) size() int {
	return len(mss.samples)
}

func (mss *MutSampleSet) getAll() []MutSample {
	values := make([]MutSample, 0, len(mss.samples))
	for _, sample := range mss.samples {
		values = append(values, sample)
	}
	return values
}

func (mss *MutSampleSet) getElById(id int) (*MutSample, bool) {
	sample, exists := mss.samples[id]
	return &sample, exists
}

// 공통 함수 타입 정의
type MutateFunc func(Ent, string) bool

// MutationCode 타입과 관련 상수를 정의할 수도 있습니다.
type MutationCode int

const (
	DS    MutationCode = iota // Delete Start
	DE                        // Delete End
	AS                        // Append Start
	ASI                       // Append Start Interesting
	ASP                       // Append Start Pattern
	AE                        // Append End
	AEI                       // Append End Interesting
	AEP                       // Append End Pattern
	OS                        // Overwrite Start
	OM                        // Overwrite Middle
	CPS                       // Copy Start
	CPM                       // Copy Middle
	CPE                       // Copy End
	CHR                       // Change (Randomly)
	CHG                       // Change Gradual
	CHG16                     // Change Gradual 16
	CHG32                     // Change Gradual 32
	CHG64                     // Change Gradual 64
	CHI                       // Change Interesting
	CHI16                     // Change Interesting 16
	CHI32                     // Change Interesting 32
	CHP                       // Change Pattern
	IR                        // Insert Randomly
	IG                        // Insert Gradual
	II                        // Insert Interesting
	IP                        // Insert Pattern
	SW                        // Swap
	PKL                       // Preserve Kind Light
	PKH                       // Preserve Kind Hard
	SKL                       // Switch Kind Light
	SKH                       // Switch Kind Hard
)

// 함수들을 약어와 함께 등록
var entMutators = map[MutationCode]MutateFunc{
	DS:    deleteStart,
	DE:    deleteEnd,
	AS:    appendStart,
	ASI:   appendStartInteresting,
	ASP:   appendStartPattern,
	AE:    appendEnd,
	AEI:   appendEndInteresting,
	AEP:   appendEndPattern,
	OS:    overwriteStart,
	OM:    overwriteMiddle,
	CPS:   copyStart,
	CPM:   copyMiddle,
	CPE:   copyEnd,
	CHR:   changeRandomly,
	CHG:   changeGradual,
	CHG16: changeGradual16,
	CHG32: changeGradual32,
	CHG64: changeGradual64,
	CHI:   changeInteresting,
	CHI16: changeInteresting16,
	CHI32: changeInteresting32,
	CHP:   changePattern,
	IR:    insertRandomly,
	IG:    insertGradual,
	II:    insertInteresting, // 수정된 이름
	IP:    insertPattern,
	SW:    swap,
	PKL:   preserveKindLight,
	PKH:   preserveKindHard,
	SKL:   switchKindLight,
	SKH:   switchKindHard,
}

// 변형하기
// 캐시된 키와 누적합 배열을 받음. 그럼으로써 누적합 연산 없이 랜덤으로 즉시 셀렉트 가능
// 누적합 빌등은 아래의 buildCumulativeStrategy 참고
func Mutate2String(e Ent, strength int, pattern string, chachedKeys []MutationCode, chachedCum []int) (string, map[MutationCode]int) {
	// TODO: 복사 후 수정 수행하기
	// TODO: nil,null값 주의하기기
	// TODO: 일반적으로 리시버를 줄 것으로 기대.
	// TODO: 그러니 root도 리시버를 줘야 하긴 함!!
	clone := cloneEnt(e)
	// e의 strategy따라 확률적으로 변이
	// 전략 카운트를 저장할 맵을 초기화합니다.
	strategyCounts := make(map[MutationCode]int)

	cnt := 0
	for {
		strategy := selectStrategy(chachedKeys, chachedCum)
		selectedMutator := entMutators[strategy]

		isSuccess := selectedMutator(clone, "SomePattern")
		if isSuccess {
			// 원본 전략은 여기선 건드리지 않음
			// 추후 생존자 기반 업뎃. 편향 생성.
			// 다만, 추후 생성될 시드에 줄 전략-횟수 기록은 여기서 생성해서 전달.
			// 이후 그 기록을 기반으로 원본 시드를 업데이트
			strategyCounts[strategy]++
			cnt++
		} else {
			continue
		}
		if cnt >= strength {
			break
		}
	}
	result := SerializeToString(clone)
	return result, strategyCounts
}

// cloneEnt는 주어진 Ent를 깊은 복사하여 반환합니다.
// 원본 Ent는 변경되지 않습니다.
func cloneEnt(e Ent) Ent {
	switch v := e.(type) {
	case *LetterEnt:
		// 구조체 전체를 복사한 후,
		copied := *v
		return &copied

	case *NumEnt:
		copied := *v
		return &copied

	case *WsEnt:
		copied := *v
		return &copied

	case *MarkEnt:
		copied := *v
		return &copied

	case *KeyValEnt:
		copied := *v
		if v.K != nil {
			copied.K = cloneEnt(v.K)
		}
		if v.PlOrNil != nil {
			copied.PlOrNil = cloneEnt(v.PlOrNil)
		}
		if v.Delimiter != nil {
			copied.Delimiter = cloneEnt(v.Delimiter)
		}
		if v.PrOrNil != nil {
			copied.PrOrNil = cloneEnt(v.PrOrNil)
		}
		if v.V != nil {
			copied.V = cloneEnt(v.V)
		}
		return &copied

	case *GroupEnt:
		copied := *v
		if v.Data != nil {
			newData := make([]Ent, len(v.Data))
			for i, child := range v.Data {
				newData[i] = cloneEnt(child)
			}
			copied.Data = newData
		}
		return &copied

	case *RootEnt:
		copied := *v
		if v.Data != nil {
			newData := make([]Ent, len(v.Data))
			for i, child := range v.Data {
				newData[i] = cloneEnt(child)
			}
			copied.Data = newData
		}
		if v.Id2Ent != nil {
			newMap := make(map[int]Ent, len(v.Id2Ent))
			for k, val := range v.Id2Ent {
				// 만약 Id2Ent 내부 값은 깊은 복사가 필요한 경우
				newMap[k] = cloneEnt(val)
			}
			copied.Id2Ent = newMap
		}
		return &copied
	}
	return nil
}

// selectStrategy는 누적합 슬라이스(cum)에서 랜덤값을 이용해 전략 하나를 선택합니다.
func selectStrategy(keys []MutationCode, cum []int) MutationCode {
	total := cum[len(cum)-1]
	rng := fuzzing.GetPCG()
	r := rng.Intn(total)
	// sort.Search를 사용하여 누적합 배열에서 r보다 큰 첫 인덱스를 찾습니다.
	idx := sort.Search(len(cum), func(i int) bool { return cum[i] > r })
	return keys[idx]
}

// buildCumulativeStrategy는 strategy 맵으로부터 누적합 슬라이스와 키 슬라이스를 생성합니다.
// 일단 정렬을 해 둬야 추후에 값으로 찾음
func BuildCumulativeStrategy(strategy map[MutationCode]int) ([]MutationCode, []int) {
	keys := make([]MutationCode, 0, len(strategy))
	for code := range strategy {
		keys = append(keys, code)
	}
	// MutationCode는 int형이므로 오름차순으로 정렬합니다.
	quickSortMutationCodes(keys)

	cum := make([]int, len(keys))
	total := 0
	for i, code := range keys {
		total += strategy[code]
		cum[i] = total
	}
	return keys, cum
}

// quickSortMutationCodes는 MutationCode 슬라이스를 퀵소트 알고리즘으로 오름차순 정렬합니다.
func quickSortMutationCodes(keys []MutationCode) {
	if len(keys) < 2 {
		return
	}
	pivotIndex := len(keys) / 2
	pivot := keys[pivotIndex]
	// 피벗을 마지막 요소와 교환합니다.
	keys[pivotIndex], keys[len(keys)-1] = keys[len(keys)-1], keys[pivotIndex]

	storeIndex := 0
	for i := 0; i < len(keys)-1; i++ {
		if keys[i] < pivot {
			keys[i], keys[storeIndex] = keys[storeIndex], keys[i]
			storeIndex++
		}
	}
	// 피벗을 올바른 위치로 이동합니다.
	keys[storeIndex], keys[len(keys)-1] = keys[len(keys)-1], keys[storeIndex]

	quickSortMutationCodes(keys[:storeIndex])
	quickSortMutationCodes(keys[storeIndex+1:])
}

// deleteEndRandom 함수: Ent 타입에 따라 마지막 일부를 삭제하는 변형을 수행
// 변형한 Ent와, 해당 타입에 해당 변형전략이 있는지 대답
func deleteStart(e Ent, p string) bool {
	// 마지막의 일부를 랜덤 범위로 삭제. 최대 50%?
	// switch v := e.(type) {
	// case *LetterEnt:
	// rand.Intn대신 fuzzing.Intn이용하기.
	// *v등으로
	// TODO: 여기서부턴 수정된 값 포인터로 리턴. 보존 필요 x
	// TODO: 스위치 케이스 이후, 거기에 주석 달아서 AI한테 주기
	// 기본적으로 변형 없이 반환
	return true
}

func deleteEnd(e Ent, p string) bool {
	return true
}

func appendStart(e Ent, p string) bool {
	return true
}

func appendStartInteresting(e Ent, p string) bool {
	return true
}

func appendStartPattern(e Ent, p string) bool {
	return true
}

func appendEnd(e Ent, p string) bool {
	return true
}

func appendEndInteresting(e Ent, p string) bool {
	return true
}

func appendEndPattern(e Ent, p string) bool {
	return true
}

func overwriteStart(e Ent, p string) bool {
	return true
}

func overwriteMiddle(e Ent, p string) bool {
	return true
}

func copyStart(e Ent, p string) bool {
	return true
}

func copyMiddle(e Ent, p string) bool {
	return true
}

func copyEnd(e Ent, p string) bool {
	return true
}

func changeRandomly(e Ent, p string) bool {
	return true
}

// TODO: gofuzz의 7,8,9,10 참조
func changeGradual(e Ent, p string) bool {
	return true
}

func changeGradual16(e Ent, p string) bool {
	return true
}

func changeGradual32(e Ent, p string) bool {
	return true
}

func changeGradual64(e Ent, p string) bool {
	return true
}

// TODO: gofuzz의 11,12,13 참조
func changeInteresting(e Ent, p string) bool {
	return true
}

func changeInteresting16(e Ent, p string) bool {
	return true
}

func changeInteresting32(e Ent, p string) bool {
	return true
}

func changePattern(e Ent, p string) bool {
	return true
}

func insertRandomly(e Ent, p string) bool {
	return true
}

func insertGradual(e Ent, p string) bool {
	// TODO: 이런건 특히 nil값 주의
	return true
}

func insertInteresting(e Ent, p string) bool {
	return true
}

func insertPattern(e Ent, p string) bool {
	return true
}

func swap(e Ent, p string) bool {
	return true
}

func preserveKindLight(e Ent, p string) bool {
	// TODO: 타입이나 종류와 연관해선 값 집합 관리에 주의하기
	return true
}

func preserveKindHard(e Ent, p string) bool {
	return true
}

func switchKindLight(e Ent, p string) bool {
	return true
}

func switchKindHard(e Ent, p string) bool {
	return true
}
