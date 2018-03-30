// const HDWalletProvider = require('truffle-hdwallet-provider')

// Pub address: 0x25cc3f46855fa2ceaa165860681dd9071306f03b
// const mnemonic =
//   'payment local math advance attract region energy barely kitten model unveil armor'
// const INFURA_KEY = 'npPr7wL0YRxP3ewG82AL'

module.exports = {
  // See <http://truffleframework.com/docs/advanced/configuration>
  // to customize your Truffle configuration!
  networks: {
    development: {
      host: '127.0.0.1',
      port: 7545,
      network_id: '*' // Match any network id
    }
  }
}
