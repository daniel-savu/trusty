import { waffle, web3 } from "@nomiclabs/buidler";
import chai from "chai";
import { deployContract, solidity } from "ethereum-waffle";

import CounterArtifact from "../artifacts/Counter.json";
import { Counter } from "../typechain/Counter";

import CompoundArtifact from "../artifacts/Compound.json";
import { Compound } from "../typechain/Compound";

chai.use(solidity);
const { expect } = chai;

describe("Counter", () => {
  // 1
  const provider = waffle.provider;

  // 2
  let [wallet] = provider.getWallets();

  // 3
  let counter: Counter;
  let compound: Compound;

  beforeEach(async () => {
    counter = await deployContract(wallet, CounterArtifact) as Counter;
    compound = await deployContract(wallet, CompoundArtifact) as Compound;
    const initialCount = await counter.getCount();

    // 4
    expect(initialCount).to.eq(0);
    expect(counter.address).to.properAddress;
  });

  // 5
  it("should log msg.data", async () => {
    console.log(compound.address);

    let sum = await compound.sum(1,2);
    console.log("sum is:" + sum);

    var contract = new web3.eth.Contract(CompoundArtifact.abi, compound.address);
    var callData = contract.methods.sum(1, 2).encodeABI();
    let count = await counter.proxy(compound.address, callData);
    console.log("sum is:" + count);




    // var addr = counter.address;
    // console.log(addr.encodeABI());
    // web3.eth.call({
    //   to: counter.address,
    //   data: proxyData
    // }).then(console.log);
    // let count = await counter.getCount();
    expect(1).to.eq(1);
  });

});

