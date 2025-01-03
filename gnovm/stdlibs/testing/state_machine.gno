package testing

import (
	"sort"
	"strconv"
	"strings"
)

type SupportedType string

const (
	Byte_Array SupportedType = "[]byte"
	String     SupportedType = "string"
	Bool       SupportedType = "bool"
	Byte       SupportedType = "byte"
	Rune       SupportedType = "rune"
	Float32    SupportedType = "float32"
	Float64    SupportedType = "float64"
	Int        SupportedType = "int"
	Int8       SupportedType = "int8"
	Int16      SupportedType = "int16"
	Int32      SupportedType = "int32"
	Int64      SupportedType = "int64"
	Uint       SupportedType = "uint"
	Uint8      SupportedType = "uint8"
	Uint16     SupportedType = "uint16"
	Uint32     SupportedType = "uint32"
	Uint64     SupportedType = "uint64"
)

type Seed struct {
	Pid           uint
	Id            uint
	Gen           uint
	IsCoordinated bool
	HashNumber    HashNumber
	Content       []interface{}
	Result        interface{}
}

const (
	// 10만개의 경로 종류를 감당(반복문 따른 경로 차이도 개별 종료로 포함).
	// pathHash가 10만개 미만일때 효과적.
	// 그 이상도 가능은 하지만 효과 낮아짐.
	MAX_CAPACITY     uint64 = 100_000
	Partial_Capacity        = MAX_CAPACITY / 5
)

type StateMachine struct {
	Trials      uint
	Input_count uint

	All_Coverage     Coverage // []coveredline
	Covered_Coverage Coverage // []coveredline

	// Path_Hash2Coverage *PathHash2Coverage_table
	InitSeeds []Seed
	SeedType  []SupportedType

	Priority_Cache         uint
	HashNumber2Seeds       *[MAX_CAPACITY]*Seed_Queue             // 시드 큐의 배열 포인터
	HashNumber2Priority    *[MAX_CAPACITY]uint                    // 배열. 가장 간단.
	Priority2HashNumberULL *[MAX_CAPACITY]*Unique_Uint_LinkedList // 시간복잡도 줄인 특수

	Crash_Logger *Crash_Logger
}

// New_StateMachine: 새로운 StateMachine 생성
func New_StateMachine(trials uint, inputCount uint) *StateMachine {
	setted_AllULL := func() *[MAX_CAPACITY]*Unique_Uint_LinkedList {
		arr := &[MAX_CAPACITY]*Unique_Uint_LinkedList{}
		for i := range arr {
			arr[i] = New_Unique_Uint_LinkedList()
		}
		return arr
	}()
	return &StateMachine{
		Input_count: inputCount,
		// TODO: cmd로 반복 가능 횟수 설정정하게 하기
		// 지금은 3만회로 설정
		Trials: trials,
		// 기본값으로 0 설정
		All_Coverage:     Coverage{{co_name: "nil", co_line: 0}},
		Covered_Coverage: Coverage{{co_name: "nil", co_line: 0}},

		Priority_Cache: 1,
		// Path_Hash2Coverage: New_PathHash2Coverage_table(),

		HashNumber2Priority:    &[MAX_CAPACITY]uint{},        // 빈 uint 배열
		HashNumber2Seeds:       &[MAX_CAPACITY]*Seed_Queue{}, // 빈 Seed 배열
		Priority2HashNumberULL: setted_AllULL,                // 빈 링크드 리스트 배열

		Crash_Logger: New_Crash_Logger(),
	}
}

type EndInfo struct {
	Complete_Trials bool
	MAXed_CAPACITY  bool
}

func (sm *StateMachine) CoordinateMachine(seed Seed) EndInfo {
	// 이미 코디네이팅 되었으면 큐 삽입 후 바로 리턴 (우선순위 조정 x)
	if seed.IsCoordinated {
		sm.HashNumber2Seeds[seed.HashNumber].Enqueue(seed)
		return EndInfo{
			Complete_Trials: false,
			MAXed_CAPACITY:  false,
		}
	}
	hn := seed.HashNumber
	seed.IsCoordinated = true
	sm.Input_count++
	if sm.Input_count%3000 == 0 {
		kinds := sm.Crash_Logger.Kind()
		totalNums := len(sm.Crash_Logger.data)
		println(sm.Input_count, "times runned: found total", totalNums, "failing inputs", "("+strconv.Itoa(len(kinds))+" kind(s) of crash)")

	}
	// 미등록 해시 넘버시 새 큐 매칭
	if sm.HashNumber2Seeds[hn] == nil {
		sm.HashNumber2Seeds[hn] = New_Seed_Queue()
	}
	sm.HashNumber2Seeds[hn].Enqueue(seed)
	old_priority := sm.HashNumber2Priority[hn]
	sm.HashNumber2Priority[hn]++
	// 얻데이트 우선순위
	updated_priority := sm.HashNumber2Priority[hn]

	// 처음 들어온 해시넘버일 경우
	if updated_priority == 1 {
		// 첫 해시넘버 시 우선순위 캐싱 초기화
		sm.Priority_Cache = 1
		sm.Priority2HashNumberULL[updated_priority].Append(uint(hn))
	} else {
		sm.Priority2HashNumberULL[old_priority].Delete(uint(hn))
		sm.Priority2HashNumberULL[updated_priority].Append(uint(hn))
	}
	// 개수에 따른 종료조건 카운팅팅
	if sm.Input_count >= sm.Trials {
		return EndInfo{
			Complete_Trials: true,
			MAXed_CAPACITY:  false,
		}
		// 맥스 캐파시티티 찰 때마다 신호호
	} else if uint64(sm.Input_count)%MAX_CAPACITY == 0 {
		return EndInfo{
			Complete_Trials: false,
			MAXed_CAPACITY:  true,
		}
	} else {
		return EndInfo{
			Complete_Trials: false,
			MAXed_CAPACITY:  false,
		}
	}
}

func (sm *StateMachine) PopSeeds() []Seed {
	// 가장 높은 우선순위의 hashnumber를 선택
	var highest_hn uint
	// 캐싱 통해 total이 O(맥스 캐파시티티)내로 탐색됨

	for {
		// 가장 높은 우선순위의 hashnumber를 선택
		hn, isExist := sm.Priority2HashNumberULL[sm.Priority_Cache].Peek()
		if !isExist {
			sm.Priority_Cache++

			continue
		}

		highest_hn = hn
		break
	}

	popedSeed_1, isOnce := sm.HashNumber2Seeds[highest_hn].Dequeue()
	if !isOnce {
		panic("logical internal error: it must has more than one seed")
	}
	peekedSeed_2, err := sm.HashNumber2Seeds[highest_hn].Peek()
	if err != nil {
		return []Seed{popedSeed_1}
	}
	pid_1 := popedSeed_1.Pid
	pid_2 := peekedSeed_2.Pid
	if pid_1 == pid_2 {
		popedSeed_2, _ := sm.HashNumber2Seeds[highest_hn].Dequeue()
		return []Seed{popedSeed_1, popedSeed_2}
	} else {
		return []Seed{popedSeed_1}
	}
}

// (우선순위, pathHash) 튜플
type P_HN_Pair struct {
	Priority   uint
	HashNumber int
}
type PHP_List []P_HN_Pair

func (phpl PHP_List) Len() int           { return len(phpl) }
func (phpl PHP_List) Less(i, j int) bool { return phpl[i].Priority < phpl[j].Priority }
func (phpl PHP_List) Swap(i, j int)      { phpl[i], phpl[j] = phpl[j], phpl[i] }

type S_P_Pair struct {
	Seed     Seed
	Priority uint
}

func (sm *StateMachine) Summarize() []Seed {
	// new_seeds := [Partial_Capacity]Seed{}
	// ph수집
	collected_P_HN_Pair := PHP_List{}
	for i, e := range sm.HashNumber2Priority {
		// end포인트 체킹
		if e == 0 {
			break
		}
		collected_P_HN_Pair = append(collected_P_HN_Pair, P_HN_Pair{
			Priority:   e,
			HashNumber: i,
		})
		// 슬라이스 길이가 Partial_Capacity를를 초과하면 종료
		if len(collected_P_HN_Pair) >= int(Partial_Capacity) {
			break
		}
	}
	// 길이 1만의 p_hn배열 정렬
	sort.Sort(collected_P_HN_Pair)
	// println("state_machine- 정렬 완료:", collected_P_HN_Pair)
	// 각 hashNumber별로 시드 샘플링
	sampled_sp_pair := []S_P_Pair{}

	for _, pair := range collected_P_HN_Pair {
		hn := pair.HashNumber
		seed := sm.HashNumber2Seeds[hn].data[0]
		priority := pair.Priority
		sampled_sp_pair = append(sampled_sp_pair, S_P_Pair{seed, priority})
	}

	// 요약시킬 배열 생성
	summarized_seeds := []Seed{}
	// 시드 내용 초기화(gen, Pid, Id, IsC )
	for i, sp_pair := range sampled_sp_pair {
		// 시드를 알맞은 인풋 형태로 매핑
		seed := sp_pair.Seed
		seed.Pid = 0
		seed.Id = uint(i)
		seed.Gen = genAllocation(sp_pair.Priority)
		seed.IsCoordinated = false
		// 배열에 매핑된 시드 추가
		summarized_seeds = append(summarized_seeds, seed)
	}
	return summarized_seeds
}

func genAllocation(priority uint) uint {
	// 7~10단계 정도의 하드코딩
	c1_cutLine := uint(float64(MAX_CAPACITY) * 0.012)
	c2_cutLine := uint(float64(MAX_CAPACITY) * 0.015)
	c3_cutLine := uint(float64(MAX_CAPACITY) * 0.02)
	c4_cutLine := uint(float64(MAX_CAPACITY) * 0.05)
	c5_cutLine := uint(float64(MAX_CAPACITY) * 0.8)
	c6_cutLine := uint(float64(MAX_CAPACITY) * 0.15)
	c7_cutLine := uint(float64(MAX_CAPACITY) * 0.25)
	c8_cutLine := uint(float64(MAX_CAPACITY) * 0.30)
	switch {
	case priority <= c1_cutLine:
		return 1
	case priority <= c2_cutLine:
		return 2
	case priority <= c3_cutLine:
		return 3
	case priority <= c4_cutLine:
		return 4
	case priority <= c5_cutLine:
		return 5
	case priority <= c6_cutLine:
		return 6
	case priority <= c7_cutLine:
		return 7
	case priority <= c8_cutLine:
		return 8
	default:
		// 기본값 (c7_cutLine보다 큰 경우)
		return 9
	}
}

// func main() {
// 	state_machine := New_StateMachine()
// 	state_machine.Format_StateMachine("some_func", "apple")
// 	println(state_machine.ToString())
// }

// print_machine: StateMachine을 예쁘게 출력하는 메서드
func (sm *StateMachine) ToString() string {
	// 문자열 빌더 사용
	var sb strings.Builder

	sb.WriteString("StateMachine:\n")
	sb.WriteString("  Input_count: ")
	sb.WriteString(uintToString(sm.Input_count))
	sb.WriteString("\n")

	sb.WriteString("  All_lines: ")
	sb.WriteString(CoverageToString(sm.All_Coverage)) // 수정된 부분
	sb.WriteString("\n")

	sb.WriteString("  Covered_lines: ")
	sb.WriteString(CoverageToString(sm.Covered_Coverage)) // 수정된 부분
	sb.WriteString("\n")

	sb.WriteString("  Path_hash2Priority: ")
	sb.WriteString(sliceToString(sm.HashNumber2Priority[:]))
	sb.WriteString("\n")

	sb.WriteString("  나머진 추가 구현해보삼: ")

	// 반환
	return sb.String()
}
