import { BuidlerConfig, usePlugin, task } from "@nomiclabs/buidler/config";

usePlugin("@nomiclabs/buidler-waffle");
usePlugin("@nomiclabs/buidler-etherscan");
usePlugin("buidler-typechain");
usePlugin("@nomiclabs/buidler-web3");
// usePlugin('tasks');

task("balance", "Prints an account's balance")
  .addParam("account", "The account's address")
  .setAction(async (taskArgs: { account: any; }, bre) => {
    const account = bre.web3.utils.toChecksumAddress(taskArgs.account);
    const balance = await bre.web3.eth.getBalance(account);

    console.log(bre.web3.utils.fromWei(balance, "ether"), "ETH");
  });




const LOCAL_NETWORK_PRIVATE_KEY = "0x710fd8db1b881e948e291d85ebde38829f774c79d99b775f88c99cbe3f4649c1";
const config: BuidlerConfig = {
  defaultNetwork: "buidlerevm",
  solc: {
    version: "0.5.0"
  },
  networks: {
    localhost: {
      url: `http://127.0.0.1:2000`,
      accounts: [LOCAL_NETWORK_PRIVATE_KEY]
    },
    evm: {
      url: `http://127.0.0.1:8545`,
      accounts: [`0xc5e8f61d1ab959b397eecc0a37a6517b8e67a0e7cf1f4bce5591f3ed80199122`]
    },
  },
  typechain: {
    outDir: "typechain",
    target: "ethers"
  }
};



export default config;