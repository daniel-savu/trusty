pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract trusty {
    string[] _protocols;
    address constant CEtherAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    // you have maps from a protocol name to Balance parameters
    
    function protocolAlreadyAdded(string memory protocol) view private returns(bool) {
        for (uint8 i = 0; i < _protocols.length; i++) {
            if(identicalStrings(_protocols[i], protocol)) {
                return true;
            }
        }
        return false;
    }

    function identicalStrings(string memory a, string memory b) pure public returns(bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function() external payable {
        console.log("reached the fallback");
    }

}