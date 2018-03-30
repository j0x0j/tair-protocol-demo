pragma solidity ^0.4.18;

import './Ownable.sol';
import './SafeMath.sol';
import './usingOraclize.sol';

/**
* @title TAIR Protocol
*/
contract TairProtocol is Ownable, usingOraclize {
  using SafeMath for uint256;

  // ============
  // EVENTS:
  // ============

  // When Oraclize callback is successfull
  event LogOraclizeResult(string random, bytes32 id);
  // When a Round is created
  event RoundCreation(uint roundId, uint sampleId, uint256 bounty);
  // When a Round is validated
  event RoundValidated(uint roundId, uint sampleId, address winner);

  // Testing Events
  event WillCallOraclize(uint roundId);

  // ============
  // DATA STRUCTURES:
  // ============

  // Valid query ids to check against in callback
  mapping(bytes32 => bool) validOraclizeIds;
  // Valid query ids to check against in callback
  mapping(bytes32 => Round) roundOraclizeIds;
  // Staked validators balances
  mapping (address => uint256) stakedValidators;
  // All Rounds
  mapping (uint => Round) rounds;
  // Winner balances
  mapping (address => uint256) winnerBalances;

  struct Round {
    uint id;                               // Internal auto-increment id
    bytes32 queryId;                       // Oraclize query id
    uint status;                           // 0 = idle, 1 = commited, 2 = revealed
    uint validators;                       // The amount of participants in the Round
    uint committed;                        // The amount of commits for the Round
    uint revealed;                         // The amount of reveals for the Round
    uint256 bounty;                        // Amount of ETH for winner
    uint[] matchIds;                       // List of matchIds in Round
    address[] ballots;                     // The proportional votes for possible winners
    mapping (address => bytes32) commits;  // Committed matches as secrets
    mapping (uint => address[]) matches;   // Addresses that matched a particular id
  }

  // Incremental id for rounds
  uint numRounds;

  // ============
  // CONSTRUCTOR:
  // ============

  /**
  * @dev constructor
  */
  function TairProtocol() public payable {
    // Set oraclize proof type
    oraclize_setProof(proofType_Ledger);
  }

  /**
  * @dev oraclize callback
  * @param _queryId oraclize query id
  * @param _result oraclize query result
  */
  function __callback(bytes32 _queryId, string _result, bytes _proof) public {
    require(validOraclizeIds[_queryId]);
    require(msg.sender == oraclize_cbAddress());
    require(oraclize_randomDS_proofVerify__returnCode(_queryId, _result, _proof) == 0);

    LogOraclizeResult(_result, _queryId);

    delete validOraclizeIds[_queryId];

    // for simplicity of use, let's also convert the random bytes to uint if we need
    // this is the highest uint we want to get. It should never be greater than
    // 2^(8*N), where N is the number of random bytes we had asked the datasource to return
    // Use 100 as maxRange because winner selection is proportional
    uint maxRange = 100;
    // this is an efficient way to get the uint out in the [0, maxRange] range
    uint randomNumber = uint(keccak256(_result)) % maxRange;

    // Finalize the Round by providing a random number
    finalizeRound(roundOraclizeIds[_queryId].id, randomNumber);
  }

  /**
  * @dev getRandomBytesForRound calls oraclize for some random bytes
  * @param roundId the internal id of the Round
  */
  function getRandomBytesForRound(uint roundId) public payable {
    // delay = 0, number of random bytes = 4, callbackGas = 200000
    bytes32 queryId = oraclize_newRandomDSQuery(0, 4, 200000);

    validOraclizeIds[queryId] = true;
    // Set the queryId for the Round
    rounds[roundId].queryId = queryId;
  }

  /**
  @notice Need a better way to manage stake, maybe ERC900
  @dev adds stake (ETH) to a validator address
  anyone can be a validator, in reality this should be
  matched against a registry or another contract
  @param validator the address of the validator or owner
  */
  function addStake(address validator) payable public {
    // should add to balance not just overwrite
    stakedValidators[validator] += msg.value;
  }

  /**
  * @dev creates a Round
  * @param sample the internal id for the matching database
  */
  function createRound(uint sample) payable public {
    uint roundId = numRounds + 1;
    uint[] memory matchIds;
    address[] memory ballots;
    rounds[roundId] = Round(roundId, 0x0, 0, 0, 0, 0, msg.value, matchIds, ballots);
    numRounds++;
    RoundCreation(roundId, sample, msg.value);
  }

  /**
  @dev commit match id to a round,
  @param roundId the round to commit to, eventually will included in hash
  @param matchSecret a salted secret as a hash
  */
  function commitMatch(uint roundId, bytes32 matchSecret) public {
    // game already claimed
    require(rounds[roundId].status != 2);

    if (rounds[roundId].status == 0) {
      // switch committed flag
      rounds[roundId].status = 1;
    }
    rounds[roundId].commits[msg.sender] = matchSecret;
    rounds[roundId].validators += 1;
    rounds[roundId].committed += 1;
  }

  /**
  @notice should have a min block span to allow a reveal
  @dev reveal matchId reading for a Round,
  @param roundId the game for which to to reveal vote
  @param matchId as a uint
  @param salt used to create the hash
  */
  function revealMatch(uint roundId, uint matchId, uint salt) public {
    // check against commit
    require(keccak256(matchId, salt) == rounds[roundId].commits[msg.sender]);

    // Add sender to matchId
    rounds[roundId].matches[matchId].push(msg.sender);
    // Push matchId to Round
    rounds[roundId].matchIds.push(matchId);
    // Add to revealed commits
    rounds[roundId].revealed += 1;

    if (rounds[roundId].revealed == rounds[roundId].committed) {
      // Round ended, every vaidator revealed
      rounds[roundId].status = 2;
      // Call Oraclize to generate random number to select a winner
      /* getRandomBytesForRound(roundId); */
      WillCallOraclize(roundId);
    }
  }

  /**
  @notice Add modifier for onlyOraclize
  @dev finalizes Round
  @param roundId the Round id
  @param random the random number provided by Oraclize
  */
  function finalizeRound(uint roundId, uint random) public returns(address) {
    // Loop throught winning condition addresses
    uint leadingMatchId;
    uint matchId;
    Round storage r = rounds[roundId];
    for (uint i = 0; i < r.matchIds.length; ++i) {
      matchId = r.matchIds[i];
      if (i == 0) {
        // Set first match as leader by default
        leadingMatchId = matchId;
      }
      if (r.matches[matchId].length > r.matches[leadingMatchId].length) {
        leadingMatchId = matchId;
      }
    }
    return selectWinner(roundId, leadingMatchId, random);
  }

  /**
  @dev selects the winner according to random + stake
  @param roundId the Round id
  @param matchId the leading group for the Round
  @param random the random number provided by Oraclize
  */
  function selectWinner(uint roundId, uint matchId, uint random) internal returns(address) {
    // Iterate through winners to their stake column
    address winner;
    uint256 totalWinnersStake;
    for (uint j = 0; j < rounds[roundId].matches[matchId].length; ++j) {
      address validator = rounds[roundId].matches[matchId][j];
      uint256 currStake = stakedValidators[validator];
      totalWinnersStake = SafeMath.add(currStake, totalWinnersStake);
    }
    // Loop again to create possibleWinner proportional stake
    for (uint y = 0; y < rounds[roundId].matches[matchId].length; ++y) {
      address possibleWinner = rounds[roundId].matches[matchId][y];
      uint256 stake = stakedValidators[possibleWinner];
      uint256 proportion = SafeMath.div(stake * 10**2, totalWinnersStake);
      // Push the proportional number of ballots
      for (uint z = 0; z < proportion; ++z) {
        rounds[roundId].ballots.push(possibleWinner);
      }
    }

    // Need to make random fit in proportion range
    // Get a random ballot
    winner = rounds[roundId].ballots[random];
    // Add balance to winner
    winnerBalances[winner] += rounds[roundId].bounty;
    // @TODO: Slash validators in other matchId sets for this Round
    RoundValidated(roundId, matchId, winner);
    return winner;
  }
}
