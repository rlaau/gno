// Copyright 2023 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fuzzing

import (
	"fmt"
	"math"
	"math/bits"
)

// -----------------------------------------------------------------------------
// 2. PCG 구현 (128비트 내부 상태, PCG-XSH-RR + DXSM)
// -----------------------------------------------------------------------------

// PCG is a PCG generator with 128 bits of internal state.
type PCG struct {
	hi uint64
	lo uint64
}

// used to calculate execution times; only present in testing stdlibs
func unixNano() int64

func UnixNano() int64 {
	return unixNano()
}

// NewPCG returns a new PCG seeded with the given two 64-bit values.
func NewPCG(seed1, seed2 uint64) *PCG {
	return &PCG{hi: seed1, lo: seed2}
}

// NewPCGFromInt64 returns a new PCG seeded with a single int64 value.
// 여기서는 hi=0, lo=seed로 초기화합니다.
func NewPCGFromInt64(seed int64) *PCG {
	return &PCG{hi: 0, lo: uint64(seed)}
}

// Seed resets the PCG state.
func (p *PCG) Seed(seed1, seed2 uint64) {
	p.hi = seed1
	p.lo = seed2
}

// --- 내부 상태 업데이트 및 난수 생성 ---
//
// next()는 내부 상태(state)를 업데이트한 후,
// 128비트 곱셈과 덧셈을 수행하여 새로운 (hi, lo)를 반환합니다.
func (p *PCG) next() (hi, lo uint64) {
	const (
		mulHi = 2549297995355413924
		mulLo = 4865540595714422341
		incHi = 6364136223846793005
		incLo = 1442695040888963407
	)
	hi, lo = bits.Mul64(p.lo, mulLo)
	hi += p.hi*mulLo + p.lo*mulHi
	lo, c := bits.Add64(lo, incLo, 0)
	hi, _ = bits.Add64(hi, incHi, c)
	p.lo = lo
	p.hi = hi
	return hi, lo
}

// Uint64 returns a uniformly-distributed random uint64 value.
// 내부에서는 PCG-XSH-RR 방식의 후처리와 DXSM (Double Xorshift Multiply)을 사용합니다.
func (p *PCG) Uint64() uint64 {
	hi, lo := p.next()
	const cheapMul = 0xda942042e4dd58b5
	hi ^= hi >> 32
	hi *= cheapMul
	hi ^= hi >> 48
	hi *= (lo | 1)
	return hi
}

// Int() - int 타입의 난수 생성 (비트 마스킹을 통해 음수 제거)
func (p *PCG) Int() int {
	return int(p.Uint64() &^ (1 << 63)) // 최상위 비트를 제거하여 음수가 아닌 값 반환
}

func (p *PCG) Intn(n int) int {
	if n <= 0 {
		panic("n must be greater than 0")
	}
	return int(p.Uint64() % uint64(n))
}

// Int32() - int32 타입의 난수 생성
func (p *PCG) Int32() int32 {
	return int32(p.Uint64() >> 32) // 32비트 상위 부분을 잘라서 int32로 변환
}

func (p *PCG) Int64() int64 {
	return int64(p.Uint64() &^ (1 << 63)) // 최상위 비트를 제거하여 음수가 아닌 값 반환
}

// Uint32 returns a 32-bit random number.
func (p *PCG) Uint32() uint32 {
	return uint32(p.Uint64() >> 32)
}

// Float64 returns a random float64 in [0.0, 1.0) using 53 bits of precision.
func (p *PCG) Float64() float64 {
	return float64(p.Uint64()>>11) / float64(1<<53)
}

// NormFloat64 returns a normally distributed random float64 (mean=0, stddev=1)
// using the Box–Muller transform.
func (p *PCG) NormFloat64() float64 {
	u1 := p.Float64()
	if u1 < 1e-12 {
		u1 = 1e-12
	}
	u2 := p.Float64()
	radius := math.Sqrt(-2 * math.Log(u1))
	theta := 2 * math.Pi * u2
	return radius * math.Cos(theta)
}

// RandRange returns a random int64 in [start, end).
func (p *PCG) RandRange(start, end int64) int64 {
	if start >= end {
		panic("start must be < end")
	}
	return start + int64(p.Uint64()%(uint64(end-start)))
}

// UintRandRange returns a random uint64 in [start, end).
func (p *PCG) UintRandRange(start, end uint64) uint64 {
	if start >= end {
		panic("start must be < end")
	}
	return start + p.Uint64()%(end-start)
}

// UniformRandomBool returns true with the given probability in [0,1].
func (p *PCG) UniformRandomBool(probability float64) bool {
	if probability < 0 || probability > 1 {
		panic("probability must be between 0 and 1")
	}
	return p.Float64() < probability
}

// GenerateRandomBool returns a boolean value using a bias based on a normal distribution.
// 내부적으로 NormFloat64()를 [-1,1] 범위로 변환하여 사용합니다.
func (p *PCG) GenerateRandomBool(bias float64) bool {
	if bias < 0 || bias > 1 {
		panic("bias must be in range [0,1]")
	}
	res := (p.NormFloat64() + 1) / 2
	return res > bias
}

// -----------------------------------------------------------------------------
// 3. 싱글턴 패턴: 실행 시마다 다른 난수를 생성하도록 단 한 번만 초기화되는 인스턴스 제공
// -----------------------------------------------------------------------------

var (
	singlePCG   *PCG
	initialized bool
)

// GetPCG returns a singleton instance of the PCG-based random generator.
// 매 실행 시, UnixNano()를 통해 다른 seed로 초기화됩니다.
func GetPCG() *PCG {
	if !initialized {
		initialized = true
		seed := uint64(unixNano())
		singlePCG = NewPCGFromInt64(int64(seed))
	}
	return singlePCG
}

// -----------------------------------------------------------------------------
// 4. 편의 함수들: nrand, RandRange, RandInt64, RandUint64, RandUint32,
//    GenerateRandomBool, UniformRandomBool
// -----------------------------------------------------------------------------

// Nrand returns a value approximating a normal distribution scaled to roughly [-1,1].
// (Box–Muller 변환 결과를 3으로 나누어 스케일 조정)
func Nrand() float64 {
	pcg := GetPCG()
	val := pcg.NormFloat64()
	scaled := val / 3
	if scaled < -1 {
		return -1
	} else if scaled > 1 {
		return 1
	}
	return scaled
}

// RandRange returns a pseudo-random int64 in [start, end).
func RandRange(start, end int64) int64 {
	if start >= end {
		panic("start >= end")
	}
	pcg := GetPCG()
	// Int64() 효과: 상위 1비트를 제거한 63비트 값을 사용
	randNum := int64(pcg.Uint64() &^ (1 << 63))
	if randNum < 0 {
		randNum = -randNum
	}
	hashedNum := randNum % (end - start)
	return start + hashedNum
}

// UintRandRange returns a pseudo-random uint64 in [start, end).
func UintRandRange(start, end uint64) uint64 {
	if start >= end {
		panic("start >= end")
	}
	pcg := GetPCG()
	randNum := pcg.Uint64()
	hashedNum := randNum % (end - start)
	return start + hashedNum
}

// RandInt64 returns a pseudo-random int64 (full range).
func RandInt64() int64 {
	pcg := GetPCG()
	return int64(pcg.Uint64() &^ (1 << 63))
}

// RandUint64 returns a pseudo-random uint64 (full range).
func RandUint64() uint64 {
	return GetPCG().Uint64()
}

// RandUint32 returns a pseudo-random uint32 (full range).
func RandUint32() uint32 {
	return GetPCG().Uint32()
}

// GenerateRandomBool returns a boolean value based on a bias using a normal distribution.
// (nrand()가 [-1,1] 범위를 가지므로, [0,1]로 변환 후 bias와 비교)
func GenerateRandomBool(bias float64) bool {
	if bias < 0 || bias > 1 {
		panic("bias should be in the range [0,1]")
	}
	res := (Nrand() + 1) / 2
	return res > bias
}

// UniformRandomBool returns true with the given probability.
func UniformRandomBool(probability float64) bool {
	if probability < 0.0 || probability > 1.0 {
		panic("Probability must be between 0.0 and 1.0")
	}
	return GetPCG().Float64() < probability
}

// 랜덤 값 5개를 한 번에 생성하는 함수
func GenerateFiveRandomInts() []int64 {
	return []int64{
		RandInt64(),
		RandInt64(),
		RandInt64(),
		RandInt64(),
		RandInt64(),
	}
}

func GenerateFiveRandomFloats() []float64 {
	return []float64{
		GetPCG().Float64(),
		GetPCG().Float64(),
		GetPCG().Float64(),
		GetPCG().Float64(),
		GetPCG().Float64(),
	}
}

func GenerateFiveRandomBools(probability float64) []bool {
	return []bool{
		UniformRandomBool(probability),
		UniformRandomBool(probability),
		UniformRandomBool(probability),
		UniformRandomBool(probability),
		UniformRandomBool(probability),
	}
}
