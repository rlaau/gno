package state

import (
	abci "github.com/tendermint/classic/abci/types"
	dbm "github.com/tendermint/classic/db"
	"github.com/tendermint/classic/types"
)

//
// TODO: Remove dependence on all entities exported from this file.
//
// Every entity exported here is dependent on a private entity from the `state`
// package. Currently, these functions are only made available to tests in the
// `state_test` package, but we should not be relying on them for our testing.
// Instead, we should be exclusively relying on exported entities for our
// testing, and should be refactoring exported entities to make them more
// easily testable from outside of the package.
//

const ValSetCheckpointInterval = valSetCheckpointInterval

// UpdateState is an alias for updateState exported from execution.go,
// exclusively and explicitly for testing.
func UpdateState(
	state State,
	blockID types.BlockID,
	header *types.Header,
	abciResponses *ABCIResponses,
) (State, error) {
	return updateState(state, blockID, header, abciResponses)
}

// ValidateValidatorUpdates is an alias for validateValidatorUpdates exported
// from execution.go, exclusively and explicitly for testing.
func ValidateValidatorUpdates(abciUpdates []abci.ValidatorUpdate, params abci.ValidatorParams) error {
	return validateValidatorUpdates(abciUpdates, params)
}

// CalcValidatorsKey is an alias for the private calcValidatorsKey method in
// store.go, exported exclusively and explicitly for testing.
func CalcValidatorsKey(height int64) []byte {
	return calcValidatorsKey(height)
}

// SaveABCIResponses is an alias for the private saveABCIResponses method in
// store.go, exported exclusively and explicitly for testing.
func SaveABCIResponses(db dbm.DB, height int64, abciResponses *ABCIResponses) {
	saveABCIResponses(db, height, abciResponses)
}

// SaveConsensusParamsInfo is an alias for the private saveConsensusParamsInfo
// method in store.go, exported exclusively and explicitly for testing.
func SaveConsensusParamsInfo(db dbm.DB, nextHeight, changeHeight int64, params abci.ConsensusParams) {
	saveConsensusParamsInfo(db, nextHeight, changeHeight, params)
}

// SaveValidatorsInfo is an alias for the private saveValidatorsInfo method in
// store.go, exported exclusively and explicitly for testing.
func SaveValidatorsInfo(db dbm.DB, height, lastHeightChanged int64, valSet *types.ValidatorSet) {
	saveValidatorsInfo(db, height, lastHeightChanged, valSet)
}