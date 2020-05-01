import { waffle, web3 } from "@nomiclabs/buidler";
import chai from "chai";
import { deployContract, solidity } from "ethereum-waffle";

import trustyArtifact from '../artifacts/trusty.json'
import { trusty } from "../typechain/trusty";

import CompoundArtifact from '../artifacts/Compound.json'
import { Compound } from "../typechain/Compound";

import { ContractTransaction, ethers } from "ethers";

chai.use(solidity);
const { expect } = chai;

function getABI(filename: string) {
  var fs = require('fs');
  var jsonFile = "/Users/dani/dani/Pro/facultate/Master/Term_3_Dissertation/protocol-integrations/build/contracts/" + filename;
  var parsed= JSON.parse(fs.readFileSync(jsonFile));
  var abi = parsed.abi;
  return abi;
}

describe("trusty proxy", () => {
  // 1
  const provider = waffle.provider;

  // 2
  let [wallet] = provider.getWallets();

  // 3
  let trusty: trusty;
  let Compound: Compound;

  beforeEach(async () => {
    trusty = await deployContract(wallet, trustyArtifact) as trusty;
    Compound = await deployContract(wallet, CompoundArtifact) as Compound;

    // 4
    expect(trusty.address).to.properAddress;
  });

  // 5
  it("should update agent score upon performing an action", async () => {
    console.log(trusty.address);

    // let sum = await compound.sum(1,2);
    // console.log("sum is:" + sum);

    let overrides = {
      // The maximum units of gas for the transaction to use
      gasLimit: 2300000
  };

    // var contract = new web3.eth.Contract(CompoundArtifact.abi, compound.address);
    // var callData = contract.methods.sum(5, 6).encodeABI();
    // let result = await counter.proxy(compound.address, callData, overrides);

    let protocol = "Compound";
    let contracts = ["0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5"];
    // let contracts = [Compound.address.toString()];
    let layers = [1,2,3];
    let layerFactors = [1200, 1050, 1000];
    let layerLowerBounds = [0, 50, 100];
    let layerUpperBounds = [100, 200, 100000];
    let minCollateral = 100;
    let actions = [0];
    let actionRewards = [100];
  
    console.log("adding protocol");

  await trusty.addProtocol(
    protocol,
    contracts,
    layers,
    layerFactors,
    layerLowerBounds,
    layerUpperBounds,
    minCollateral,
    actions,
    actionRewards
  );

  console.log("done adding protocol");

  // const dummyCompoundContract = new web3.eth.Contract(getABI("Compound.json"), Compound.address);
  // const compoundCallData = dummyCompoundContract.methods.sum(1,2).encodeABI();
  // await trusty.proxy(Compound.address, compoundCallData);

  const compoundAddress = '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5';
  const compoundABI = getABI("RealCompound.json");
  const compoundCEthContract = new web3.eth.Contract(compoundABI, compoundAddress);

  const compoundCallData = compoundCEthContract.methods.supplyRatePerBlock().encodeABI();
  let supplyRatePerBlockMantissa: ContractTransaction = await trusty.proxy(compoundAddress, compoundCallData);


  // const supplyRatePerBlockMantissa = await compoundCEthContract.methods.supplyRatePerBlock().call({
  //   from: wallet.address,
  //   gasLimit: web3.utils.toHex(150000),
  //   gasPrice: web3.utils.toHex(20000000000)
  // });
  // const interestPerEthThisBlock = supplyRatePerBlockMantissa / 1e18;
  // console.log(`Each supplied ETH will increase by ${interestPerEthThisBlock}` +
  // ` this block, based on the current interest rate.`)

  // console.log("wallet address: " + wallet.address);


  // console.log('Supplying ETH to the Compound Protocol...');

  // await compoundCEthContract.methods.mint().send({
  //   from: wallet.address,
  //   gasLimit: web3.utils.toHex(150000),      // posted at compound.finance/developers#gas-costs
  //   gasPrice: web3.utils.toHex(20000000000), // use ethgasstation.info (mainnet only)
  //   value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
  // });

  // modified for trusty
  // let cEthMintData = compoundCEthContract.methods.mint().encodeABI();
  // let trustyContract = new web3.eth.Contract(getABI("trusty.json"), trusty.address);

  // let trustyData = trustyContract.methods.proxy(compoundAddress, cEthMintData).encodeABI();


  // let tx = {
  //   to: trusty.address,
  //   from: wallet.address,
  //   gasLimit: web3.utils.toHex(150000),
  //   gasPrice: web3.utils.toHex(20000000000),
  //   value: web3.utils.toHex(web3.utils.toWei('1', 'ether')),
  //   data: trustyData
  // };

  // await web3.eth.sendTransaction(tx);

  // await trusty.proxy(compoundAddress, cEthMintData);

//   console.log('cETH "Mint" operation successful.');



//   const _balanceOfUnderlying = await compoundCEthContract.methods
//   .balanceOfUnderlying(wallet.address).call();
// let balanceOfUnderlying = web3.utils.fromWei(_balanceOfUnderlying).toString();
// console.log("ETH supplied to the Compound Protocol:", balanceOfUnderlying);

  const _balanceOfUnderlyingData = await compoundCEthContract.methods
    .balanceOfUnderlying(wallet.address).encodeABI();
  let _balanceOfUnderlying = await trusty.proxy(compoundAddress, _balanceOfUnderlyingData);

  // let balanceOfUnderlying = web3.utils.fromWei(_balanceOfUnderlying).toString();
  // console.log("ETH supplied to the Compound Protocol:", balanceOfUnderlying);
  
  // const _cTokenBalanceData = await compoundCEthContract.methods.
  //   balanceOf(wallet.address).encodeABI();
  // let cTokenBalance = await trusty.proxy(compoundAddress, _cTokenBalanceData);


  // console.log("My wallet's cETH Token Balance:", cTokenBalance);

  // let exchangeRateCurrent = await compoundCEthContract.methods.
  //   exchangeRateCurrent().call();
  // exchangeRateCurrent = (exchangeRateCurrent / 1e28).toString();
  // console.log("Current exchange rate from cETH to ETH:", exchangeRateCurrent);
  });

  

});

