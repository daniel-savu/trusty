pragma solidity ^0.5.0;

import "./SimpleLendingCollateralManager.sol";
import "./LTCR.sol";
import "./Trusty.sol";
import "./UserProxy.sol";
import "./TrustySimpleLendingProxy.sol";
import "@nomiclabs/buidler/console.sol";

contract UserProxyFactory {
    mapping (address => UserProxy) userAddressToUserProxy;
    mapping (address => address) userProxyToUserAddress;
    mapping (address => TrustySimpleLendingProxy) agentSimpleLendingContracts;

    SimpleLendingCollateralManager simpleLendingCollateralManager;
    LTCR simpleLendingLTCR;
    Trusty trusty;
    mapping (address => bool) isAgentInitialized;


    constructor(
        address payable simpleLendingCollateralManagerAddress,
        address simpleLendingLTCRAddress,
        address payable trustyAddress
    ) public {
        simpleLendingCollateralManager = SimpleLendingCollateralManager(simpleLendingCollateralManagerAddress);
        simpleLendingLTCR = LTCR(simpleLendingLTCRAddress);
        trusty = Trusty(trustyAddress);
    }

    function() external payable {}

    function addAgent() public {
        console.log("in addAgent");
        if (!isAgentInitialized[msg.sender]) {
            UserProxy userProxy = new UserProxy(msg.sender, address(trusty));
            userAddressToUserProxy[msg.sender] = userProxy;
            userProxyToUserAddress[address(userProxy)] = msg.sender;
            initializeSimpleLendingProxy();
            // add other protocol initializations here
            // such as initializeCompoundProxy when done
            isAgentInitialized[msg.sender] = true;
        }
    }

    function isAddressATrustyProxy(address userProxyAddress) public view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function initializeSimpleLendingProxy() private {
        UserProxy userProxy = userAddressToUserProxy[msg.sender];
        TrustySimpleLendingProxy trustySimpleLendingProxy = new TrustySimpleLendingProxy(
            msg.sender,
            address(simpleLendingLTCR),
            address(this),
            address(userProxy),
            address(simpleLendingCollateralManager),
            address(trusty)
        );
        agentSimpleLendingContracts[msg.sender] = trustySimpleLendingProxy;
        // simpleLendingLTCR.addAuthorisedContract(address(trustySimpleLendingProxy));
        trustySimpleLendingProxy.registerAgentToLTCR();
        // userProxy.addAuthorisedContract(address(agentSimpleLendingContracts[msg.sender]));
    }

    function getTrustySimpleLendingProxy()  public view returns (TrustySimpleLendingProxy) {
        require(isAgentInitialized[msg.sender], "No proxy contract exists for caller. You need to call addAgent first.");
        return agentSimpleLendingContracts[msg.sender];
    }

    function getUserProxy(address userAddress) public view returns (address) {
        return address(userAddressToUserProxy[userAddress]);
    }

    function findUserProxy(address userAddress) public returns (address) {
        address userProxy = getUserProxy(userAddress);
        if(userProxy == address(0)) {
            return userAddress;
        }
        return userProxy;
    }
}