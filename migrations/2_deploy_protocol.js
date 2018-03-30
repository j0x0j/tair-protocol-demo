/* global artifacts */

const usingOraclize = artifacts.require('./usingOraclize.sol')
const Ownable = artifacts.require('./Ownable.sol')
const SafeMath = artifacts.require('./SafeMath.sol')
const TairProtocol = artifacts.require('./TairProtocol.sol')

module.exports = async function (deployer) {
  await deployer.deploy([
    usingOraclize,
    Ownable,
    SafeMath,
    TairProtocol
  ])
  return true
}
