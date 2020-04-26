pragma solidity 0.6.2;
import "@nomiclabs/buidler/console.sol";
import "./Compound.sol";
contract Counter {
  uint256 count = 0;
  event CountedTo(uint256 number);

  function countUp() public returns (uint256) {
    uint256 newCount = count + 1;
    require(newCount > count, "Uint256 overflow");
    console.log("Increasing counter from %d to %d", count, newCount);
    count = newCount;
    emit CountedTo(count);
    return count;
  }

  function countDown() public returns (uint256) {
    uint256 newCount = count - 1;
    require(newCount < count, "Uint256 underflow");
    console.log("Decreasing counter from %d to %d", count, newCount);
    
    count = newCount;
    emit CountedTo(count);
    return count;
  }

  function args(int x, int y) public {
    console.log("reached args");
    // console.logBytes(msg.data);
    // bytes memory d = msg.data;
    // bytes memory implementation
    //  = new bytes(32);
    // bytes memory newCalldata = new bytes(d.length - 32);

    // // bytes memory calledFunctionHash = new bytes(4);
    // for (uint256 i = 0; i < 4; i++) {
    //   // calledFunctionHash[i] = d[i];
    //   newCalldata[i] = d[i];
    // }
    // // console.logBytes(calledFunctionHash);

    // bytes memory param = new bytes(32);
    // for (uint8 i = 4; i < d.length; i += 32) {
    //   for (uint8 j = 0; j < 32 && (i + j) < d.length; j++) {
    //     param[j] = d[i + j];
    //     if(i < 32) {
    //       implementation
    //       [j] = d[i + j];
    //     } else {
    //       newCalldata[i + j - 32] = d[i + j];
    //     }
    //   }
    //   console.logBytes(param);
    //   // console.logByte(d[i]);
    //   console.log(i);
    // }
    // console.log("implementation:");
    // console.logBytes(implementation);
    // console.log("newCalldata:");
    // console.logBytes(newCalldata);
  }

  function proxy(address implementation, bytes memory params) public {
    console.log("\nin proxy");
    console.log(implementation);
    console.logBytes(params);
    uint len = params.length;
    assembly {
      let result := delegatecall(gas(), implementation, params, len, 0, 0)
    }
  }

  function getCount() public view returns (uint256) {
      return count;
  }
}