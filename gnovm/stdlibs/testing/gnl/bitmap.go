package gnl

import (
	"fmt"
	"sync/atomic"

	gno "github.com/gnolang/gno/gnovm/pkg/gnolang"
)

// CoverageBitmapSize는 고정 크기 비트맵 배열의 크기
// 여기서는 64K를 예시로 잡았습니다. (AFL 스타일)
const CoverageBitmapSize = 65536

// CoverageBitmap은 전역 배열 형태로, 분기별 실행 횟수를 저장.
// 인덱스 = "오퍼코드 ID(또는 분기 ID)"
var CoverageBitmap [CoverageBitmapSize]uint32

// OpCodeToName는 "오퍼코드 정수값 -> 문자열 이름" 매핑 예시
var OpCodeToName = map[int]string{
	int(gno.OpCall):              "OpCall",
	int(gno.OpDefer):             "OpDefer",
	int(gno.OpPanic1):            "OpPanic1",
	int(gno.OpPanic2):            "OpPanic2",
	int(gno.OpSelect):            "OpSelect",
	int(gno.OpSwitchClause):      "OpSwitchClause",
	int(gno.OpSwitchClauseCase):  "OpSwitchClauseCase",
	int(gno.OpIfCond):            "OpIfCond",
	int(gno.OpForLoop):           "OpForloop",
	int(gno.OpRangeIterArrayPtr): "OpRangeIterArrayPtr",
	int(gno.OpRangeIterString):   "OpRangeIterString",
	int(gno.OpRangeIterMap):      "OpRangeIterMap",
}

// coverageMark는 coverageBitmap[index] 값을 1 증가시킵니다.
// 주의: index 범위를 초과하지 않도록 관리해야 합니다.
func MarkCoverage(index int) {
	if index < 0 || index >= CoverageBitmapSize {
		return // 범위 밖이면 무시
	}
	atomic.AddUint32(&CoverageBitmap[index], 1)
}

// DumpCoverageBitmap은 실행된 분기/오퍼코드 ID와 실행 횟수를
// map 형태로 반환합니다. (0이 아닌 것만)
func DumpCoverageBitmap() map[int]uint32 {
	result := make(map[int]uint32)
	for i := 0; i < CoverageBitmapSize; i++ {
		count := atomic.LoadUint32(&CoverageBitmap[i])
		if count > 0 {
			result[i] = count
		}
	}
	return result
}
func PrintCoverageBitmap() {
	dump := DumpCoverageBitmap()
	fmt.Println("=== Coverage Bitmap ===")
	for idx, cnt := range dump {
		opName, ok := OpCodeToName[idx]
		if ok {
			fmt.Printf("  - index=%d (%s), count=%d\n", idx, opName, cnt)
		} else {
			fmt.Printf("  - index=%d (UnknownOp?), count=%d\n", idx, cnt)
		}
	}
}

// ResetCoverageBitmap은 CoverageBitmap 전체를 0으로 초기화
func ResetCoverageBitmap() {
	for i := 0; i < CoverageBitmapSize; i++ {
		atomic.StoreUint32(&CoverageBitmap[i], 0)
	}
}
