✔️ 📃 TAIR Validation Protocol 📻
================================

A validation game contract that implements a commit-reveal scheme coupled with a
random + stake economic incentive for validating events in the RF spectrum.

Requires
--------

* TruffleJS
* Oraclize API

Development
-----------

* Run Ganache
* Run ethereum bridge `node bridge -H localhost:7545 -a 9 --dev`
* Create tests for any contract methods
* Run tests `truffle test`
* To run with geth in Rinkeby
```
geth --syncmode "light" --rinkeby --ws --wsport 8545 --wsaddr 0.0.0.0 --wsorigins "*" --wsapi "eth,web3" console --unlock <address>
```

Protocol Description
--------------------

The interactive protocol game aims to surface the truth as the strongest focal
point so as to determine that a specific event happened in the RF spectrum for
a particular geography.

Steps
-----

Assumptions for DEMO
* Only one Round is open at a time per station
* Clients are known, registered and staked
* Anyone can create a Round
* Validators listen for RoundCreation Event

1. Software identifies pattern
2. Client hashes(station, ipfs location of sample, ipfs location of proof)
3. Client commits hash, first generates new round id, others get aggregated or
mapped
4. Client checks reveal period availability for every new block, it has to
actively seek to resolve an open round
5. Client reveals committed vote (sample ipfs location, proof ipfs location)
6. Contract sorts all votes for the round and calls Oraclize update()
7. Callback uses random bytes to select winner of round and slash any outliers
8. Contract subtracts fee amount from order balance
9. Contract adds fee amount to balance of winner

Selecting a Winner
------------------

1. Check which matchId has the most votes
2. Iterate though addresses to create stake table
3. Place random number in range of stake table
4. Winner is picked
