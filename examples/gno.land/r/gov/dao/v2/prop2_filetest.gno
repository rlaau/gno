package main

import (
	"time"

	"gno.land/p/demo/dao"
	gnoblog "gno.land/r/gnoland/blog"
	govdao "gno.land/r/gov/dao/v2"
)

func init() {
	ex := gnoblog.NewPostExecutor(
		"hello-from-govdao",                             // slug
		"Hello from GovDAO!",                            // title
		"This post was published by a GovDAO proposal.", // body
		time.Now().Format(time.RFC3339),                 // publication date
		"moul",                                          // authors
		"govdao,example",                                // tags
	)

	// Create a proposal
	description := "post a new blogpost about govdao"

	prop := dao.ProposalRequest{
		Description: description,
		Executor:    ex,
	}

	govdao.Propose(prop)
}

func main() {
	println("--")
	println(govdao.Render(""))
	println("--")
	println(govdao.Render("0"))
	println("--")
	govdao.VoteOnProposal(0, "YES")
	println("--")
	println(govdao.Render("0"))
	println("--")
	println(gnoblog.Render(""))
	println("--")
	govdao.ExecuteProposal(0)
	println("--")
	println(govdao.Render("0"))
	println("--")
	println(gnoblog.Render(""))
}

// Output:
// --
// - [Proposal #0](/r/gov/dao/v2:0) - (**active**)(by g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm)
//
// --
// # Prop #0
//
// Author: g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm
//
// post a new blogpost about govdao
//
// Status: active
//
// Voting stats: YES 0 (0%), NO 0 (0%), ABSTAIN 0 (0%), MISSING VOTE 10 (100%)
//
// Threshold met: false
//
//
// --
// --
// # Prop #0
//
// Author: g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm
//
// post a new blogpost about govdao
//
// Status: accepted
//
// Voting stats: YES 10 (100%), NO 0 (0%), ABSTAIN 0 (0%), MISSING VOTE 0 (0%)
//
// Threshold met: true
//
//
// --
// # Gnoland's Blog
//
// No posts.
// --
// --
// # Prop #0
//
// Author: g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm
//
// post a new blogpost about govdao
//
// Status: execution successful
//
// Voting stats: YES 10 (100%), NO 0 (0%), ABSTAIN 0 (0%), MISSING VOTE 0 (0%)
//
// Threshold met: true
//
//
// --
// # Gnoland's Blog
//
// <div class='columns-3'><div>
//
// ### [Hello from GovDAO!](/r/gnoland/blog:p/hello-from-govdao)
//  13 Feb 2009
// </div></div>

// Events:
// [
//   {
//     "type": "ProposalAdded",
//     "attrs": [
//       {
//         "key": "proposal-id",
//         "value": "0"
//       },
//       {
//         "key": "proposal-author",
//         "value": "g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm"
//       }
//     ],
//     "pkg_path": "gno.land/r/gov/dao/v2",
//     "func": "EmitProposalAdded"
//   },
//   {
//     "type": "VoteAdded",
//     "attrs": [
//       {
//         "key": "proposal-id",
//         "value": "0"
//       },
//       {
//         "key": "author",
//         "value": "g1wymu47drhr0kuq2098m792lytgtj2nyx77yrsm"
//       },
//       {
//         "key": "option",
//         "value": "YES"
//       }
//     ],
//     "pkg_path": "gno.land/r/gov/dao/v2",
//     "func": "EmitVoteAdded"
//   },
//   {
//     "type": "ProposalAccepted",
//     "attrs": [
//       {
//         "key": "proposal-id",
//         "value": "0"
//       }
//     ],
//     "pkg_path": "gno.land/r/gov/dao/v2",
//     "func": "EmitProposalAccepted"
//   },
//   {
//     "type": "ProposalExecuted",
//     "attrs": [
//       {
//         "key": "proposal-id",
//         "value": "0"
//       },
//       {
//         "key": "exec-status",
//         "value": "accepted"
//       }
//     ],
//     "pkg_path": "gno.land/r/gov/dao/v2",
//     "func": "ExecuteProposal"
//   }
// ]
