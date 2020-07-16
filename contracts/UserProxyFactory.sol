pragma solidity ^0.5.0;

import "./LTCR.sol";
import "./Trusty.sol";
import "./UserProxy.sol";
import "./SimpleLendingProxy.sol";
import "@nomiclabs/buidler/console.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";


contract UserProxyFactory is Ownable {
    mapping (address => UserProxy) userAddressToUserProxy;
    mapping (address => address) userProxyToUserAddress;

    LTCR simpleLendingLTCR;
    LTCR simpleLendingTwoLTCR;
    Trusty trusty;
    mapping (address => bool) isAgentInitialized;

    constructor(
        address simpleLendingLTCRAddress,
        address simpleLendingTwoLTCRAddress,
        address payable trustyAddress
    ) public {
        simpleLendingLTCR = LTCR(simpleLendingLTCRAddress);
        simpleLendingTwoLTCR = LTCR(simpleLendingTwoLTCRAddress);
        trusty = Trusty(trustyAddress);
    }

    function() external payable {}

    function addAgent() public {
        if (!isAgentInitialized[msg.sender]) {
            UserProxy userProxy = new UserProxy(msg.sender, address(trusty));
            userAddressToUserProxy[msg.sender] = userProxy;
            userProxyToUserAddress[address(userProxy)] = msg.sender;
            simpleLendingLTCR.registerAgent(address(userProxy));
            simpleLendingTwoLTCR.registerAgent(address(userProxy));
            // add other protocol initializations here
            // such as initializeCompoundProxy when done
            isAgentInitialized[msg.sender] = true;
        }
    }

    function isAddressATrustyProxy(address userProxyAddress) public view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function getUserProxyAddress(address userAddress) public view returns (address payable) {
        return address(userAddressToUserProxy[userAddress]);
    }

}