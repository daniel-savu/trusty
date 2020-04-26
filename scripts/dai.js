// import { McdPlugin, ETH, MDAI } from '@makerdao/dai-plugin-mcd';
// import { Maker } from '@makerdao/dai';
const { McdPlugin, ETH, MDAI } = require('@makerdao/dai-plugin-mcd');
const Maker = require('@makerdao/dai');


// you provide these values from accounts.json
const myPrivateKey = '0x710fd8db1b881e948e291d85ebde38829f774c79d99b775f88c99cbe3f4649c1';

async function main() {
  const maker = await Maker.create('http', {
    plugins: [McdPlugin],
    url: `https://localhost:2000`,
    privateKey: myPrivateKey
  });

  // verify that the private key was read correctly
  console.log(maker.currentAddress());

  // make sure the current account owns a proxy contract;
  // create it if needed. the proxy contract is used to 
  // perform multiple operations in a single transaction



  await maker.service('proxy').ensureProxy();

  // use the "vault manager" service to work with vaults
  const manager = maker.service('mcd:cdpManager');
    
  // ETH-A is the name of the collateral type; in the future,
  // there could be multiple collateral types for a token with
  // different risk parameters
  const vault = await manager.openLockAndDraw(
    'ETH-A', 
    ETH(50), 
    MDAI(1000)
  );

  console.log("The vault");
  console.log(vault.id);
  console.log(vault.debtValue); // '1000.00 DAI'
}

main()
  // .then(() => process.exit(0))
  // .catch(error => {
  //   console.error(error);
  //   process.exit(1);
  // });
