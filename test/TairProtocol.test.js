/* global artifacts */
/* global contract */
/* global it */
/* global assert */
/* global web3 */
/* global before */

const web3Utils = require('web3-utils')
const { soliditySha3 } = web3Utils

const { promisifyEventWatcher } = require('./utils')

const salts = ['123', '456', '789']

const getContract = name => artifacts.require(name)

contract('TairProtocol', function (accounts) {
  let contract
  before(async function () {
    this.timeout(30000)
    contract = await getContract('TairProtocol').new()
  })

  it('should return an instance of the protocol contract', async function () {
    assert.isTrue(typeof contract !== 'undefined')
  })

  it('should add stake to an address', async function () {
    const txnWei = web3.toWei(0.012, 'ether')
    const txn = await contract.addStake(accounts[3], { from: accounts[3], value: txnWei })

    const txn2Wei = web3.toWei(0.015, 'ether')
    const txn2 = await contract.addStake(accounts[4], { from: accounts[4], value: txn2Wei })

    const txn3Wei = web3.toWei(0.017, 'ether')
    const txn3 = await contract.addStake(accounts[5], { from: accounts[5], value: txn3Wei })

    assert.equal(txn.receipt.status, '0x01')
    assert.equal(txn2.receipt.status, '0x01')
    assert.equal(txn3.receipt.status, '0x01')
  })

  it('should create a Round', async function () {
    const events = contract.allEvents()
    const txnWei = web3.toWei(0.10, 'ether')
    const txn = await contract.createRound(30, {
      from: accounts[2],
      value: txnWei
    })
    assert.equal(txn.receipt.status, '0x01')

    const log = await promisifyEventWatcher(events)
    assert.equal(log.event, 'RoundCreation')
    assert.equal(log.args.roundId, 1)
    assert.equal(log.args.sampleId, 30)
    events.stopWatching()
  })

  it('should commit a hashed version of the matched Id', async function () {
    const txn = await contract.commitMatch(1, soliditySha3('30', salts[0]), { from: accounts[3] })
    const txn2 = await contract.commitMatch(1, soliditySha3('30', salts[1]), { from: accounts[4] })
    const txn3 = await contract.commitMatch(1, soliditySha3('29', salts[2]), { from: accounts[5] })

    assert.equal(txn.receipt.status, '0x01')
    assert.equal(txn2.receipt.status, '0x01')
    assert.equal(txn3.receipt.status, '0x01')
  })

  it('should reveal committed matchId for round', async function () {
    const events = contract.allEvents()

    const txn1 = await contract.revealMatch(1, 30, +salts[0], { from: accounts[3] })
    const txn2 = await contract.revealMatch(1, 30, +salts[1], { from: accounts[4] })
    const txn3 = await contract.revealMatch(1, 29, +salts[2], { from: accounts[5] })

    assert.equal(txn1.receipt.status, '0x01')
    assert.equal(txn2.receipt.status, '0x01')
    assert.equal(txn3.receipt.status, '0x01')

    const log = await promisifyEventWatcher(events)
    assert.equal(log.event, 'WillCallOraclize')
    events.stopWatching()
  })

  it('should finalize round and select a winner', async function () {
    const events = contract.allEvents()
    const random = Math.floor(Math.random() * 100) + 1
    const txn = await contract.finalizeRound(
      1, random, { from: accounts[0] }
    )
    assert.equal(txn.receipt.status, '0x01')
    const log = await promisifyEventWatcher(events)
    assert.equal(log.event, 'RoundValidated')
    events.stopWatching()
  })
})
