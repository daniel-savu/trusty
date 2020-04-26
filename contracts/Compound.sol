pragma solidity 0.6.2;
import "@nomiclabs/buidler/console.sol";

contract Compound {

  function sum(uint256 a, uint256 b) public returns (uint256) {
    console.log("\nreached sum");
    uint256 callDataSize;
    assembly {
      callDataSize := calldatasize()
    }
    console.log(callDataSize);
    console.log(address(this));
    console.logBytes(msg.data);

    // bytes memory msgdata;
    // assembly {
    //   calldatacopy(msgdata, 0, calldatasize())
    // }
    // console.logBytes(msgdata);
    return a + b;
  }

  fallback() payable external {
    console.log("\nCompound_fb");
    uint256 callDataSize;
    bytes memory msgdata;
    assembly {
      callDataSize := calldatasize()
      calldatacopy(msgdata, 0, calldatasize())
    }
    console.log(callDataSize);
    console.logBytes(msgdata);
  }

}