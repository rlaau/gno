package fuzzing

// EntForNotSB represents a non-string, non-byte entity for mutation analysis.
type EntForNotSB struct {
	data              interface{}              // Original data stored in the entity.
	isBool            bool                     // Indicates if the data is a boolean value.
	isIntegerCategory bool                     // Indicates if the data belongs to an integer category.
	isFactorized      bool                     // True if factorization was attempted and successful.
	factorizedList    []uint64                 // Stores the factorized components of an integer.
	strategy2count    [NumNotSbMutCodes]uint64 // Stores mutation strategy usage counts.
	// Cached strategy fields for optimization.
	cachedStrategyCums [NumNotSbMutCodes]uint64
	needsUpdateCache   bool
}

// ParseToEntForNotSB parses the given data into an EntForNotSB entity.
// It initializes the entity fields and performs factorization if the data is an integer.
func ParseToEntForNotSB(data interface{}) *EntForNotSB {
	ens := &EntForNotSB{
		data:              nil,
		isBool:            false,
		isIntegerCategory: true,
		isFactorized:      false,
		needsUpdateCache:  true,
	}
	// Prevents string and byte types from being parsed into this entity.
	switch data.(type) {
	case string, []byte:
		panic("data cannot be of type string or []byte")
	case bool:
		ens.isBool = true
		ens.isIntegerCategory = false
	case float32, float64:
		ens.isIntegerCategory = false
	}
	ens.data = data
	// Attempt factorization if data is an integer.
	var n uint64
	switch v := data.(type) {
	case int:
		n := toUint64(int64(v))
		ens.factorizedList, ens.isFactorized = factorize(n)
	case int8:
		n := toUint64(int64(v))
		ens.factorizedList, ens.isFactorized = factorize(n)
	case int16:
		n := toUint64(int64(v))
		ens.factorizedList, ens.isFactorized = factorize(n)
	case int32:
		n := toUint64(int64(v))
		ens.factorizedList, ens.isFactorized = factorize(n)
	case int64:
		n := toUint64(int64(v))
		ens.factorizedList, ens.isFactorized = factorize(n)
	case uint:
		ens.factorizedList, ens.isFactorized = factorize(uint64(n))
	case uint8:
		ens.factorizedList, ens.isFactorized = factorize(uint64(n))
	case uint16:
		ens.factorizedList, ens.isFactorized = factorize(uint64(n))
	case uint32:
		ens.factorizedList, ens.isFactorized = factorize(uint64(n))
	case uint64:
		ens.factorizedList, ens.isFactorized = factorize(uint64(n))
	default:
	}

	// Initialize strategy count and update the cache.
	ens.InitStrategyCount()
	ens.updateStrategyCache()

	return ens
}

// toUint64 converts an int64 to uint64, ensuring non-negative values.
func toUint64(v int64) uint64 {
	if v < 0 {
		return uint64(-v)
	}
	return uint64(v)
}

// factorize attempts to find prime factors of n within 500 iterations.
// Beacuse factorization can be extremely resource-intensive for certain numbers.
// However, since successful factorization is not essential for fuzzing mutations,
// a balance between performance and effectiveness is necessary.(so used heuristic)
// To cover frequently occurring numbers below 10⁶(or above),
// it has been optimized to 500 iterations,
// providing a good trade-off between feasibility and coverage in most cases.
// If factorization is successful, the function returns the factors and true; otherwise, it returns nil and false.
func factorize(n uint64) ([]uint64, bool) {
	var factors []uint64
	iterations := 0
	// Heuristic boundary
	trialBoundary := 500

	// Return immediately for numbers below 2.
	if n < 2 {
		return []uint64{n}, true
	}

	// Trial division starting from 2.
	for i := uint64(2); i*i <= n; i++ {
		for n%i == 0 {
			if iterations >= trialBoundary {
				return nil, false
			}
			factors = append(factors, i)
			n /= i
			iterations++
		}
	}
	if n > 1 {
		factors = append(factors, n)
	}
	return factors, true
}

// InitStrategyCount initializes all mutation strategy counts to 1.
func (ens *EntForNotSB) InitStrategyCount() {
	for code := 0; code < NumNotSbMutCodes; code++ {
		ens.strategy2count[code] = 1
	}
}

func (ens *EntForNotSB) StrategyCache() [NumNotSbMutCodes]uint64 {
	if ens.cachedStrategyCums[0] == 0 {
		ens.needsUpdateCache = true
		ens.updateStrategyCache()
	}
	return ens.cachedStrategyCums
}

// updateStrategyCache updates the cached mutation strategy data.
func (ens *EntForNotSB) updateStrategyCache() {
	if !ens.needsUpdateCache && ens.cachedStrategyCums[0] != 0 {
		return
	}
	if ens.strategy2count[0] == 0 {
		ens.InitStrategyCount()
	}
	cum := buildCumulativeStrategyUint64ForNotSB(ens.strategy2count)
	ens.cachedStrategyCums = cum
	ens.needsUpdateCache = false
}

func buildCumulativeStrategyUint64ForNotSB(strategy [NumNotSbMutCodes]uint64) [NumNotSbMutCodes]uint64 {
	var cum [NumNotSbMutCodes]uint64
	var total uint64 = 0

	for code := 0; code < NumNotSbMutCodes; code++ {
		total += strategy[code]
		cum[code] = total
	}
	return cum
}

// ReflectMutationInfo operates only when MutationInfo has IsMutated set to true
// and IsStringOrByteArray set to false.
// For each strategy recorded in UsedCodesForNotSbMap, it calls plusStrategyCount
// with an increment of 5 per usage count, updating both Strategy2count
// and TotalStrategyCount.
func (ens *EntForNotSB) ReflectMutationInfo(mutInfo MutationInfo) {
	if !mutInfo.IsMutated || mutInfo.IsStringOrByteArray {
		return
	}
	for code, count := range mutInfo.UsedCodesForNotSbMap {
		ens.plusStrategyCount(code, 5*count)
	}
}

// plusStrategyCount increases the count of a given mutation strategy.
func (ens *EntForNotSB) plusStrategyCount(code MutationCodeForNotSB, delta int) {
	if ens.strategy2count[0] == 0 {
		ens.InitStrategyCount()
	}
	ens.needsUpdateCache = true
	ens.strategy2count[code] += uint64(delta)
}

// cloneEntForNotSb creates a copy of an EntForNotSB instance, excluding strategy-related fields.
// The following fields are excluded from the copy:
// - Strategy2count
// - TotalStrategyCount
// - cachedStrategyCodes
// - cachedStrategySums
// - needsUpdateCache
func cloneEntForNotSb(orig *EntForNotSB) *EntForNotSB {
	if orig == nil {
		return nil
	}

	// deep copy for the FactorizedList field
	var clonedFactorizedList []uint64
	if orig.factorizedList != nil {
		clonedFactorizedList = make([]uint64, len(orig.factorizedList))
		copy(clonedFactorizedList, orig.factorizedList)
	}

	clone := &EntForNotSB{
		data:              orig.data,
		isBool:            orig.isBool,
		isIntegerCategory: orig.isIntegerCategory,
		isFactorized:      orig.isFactorized,
		factorizedList:    clonedFactorizedList,
		// The following fields are excluded from the copy:
		// Strategy2count, TotalStrategyCount,
		// cachedStrategyCodes, cachedStrategySums, needsUpdateCache
	}

	return clone
}

// StrategyCount retrieves the count for a given mutation strategy.
func (ens *EntForNotSB) StrategyCount(code MutationCodeForNotSB) uint64 {
	if ens.strategy2count[0] == 0 {
		ens.InitStrategyCount()
	}
	if int(code) < len(ens.strategy2count) {
		return ens.strategy2count[code]
	}
	return 1
}

// Strategy2count returns the complete strategy count mapping.
func (a *EntForNotSB) Strategy2count() [NumNotSbMutCodes]uint64 {
	return a.strategy2count
}
