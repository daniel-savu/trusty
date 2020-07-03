pragma solidity ^0.5.0;

import "./AaveCollateralManager.sol";
import "./SimpleLendingCollateralManager.sol";
import "./LTCR.sol";
import "./UserProxy.sol";
import "./TrustyAaveProxy.sol";
import "./TrustySimpleLendingProxy.sol";
import "@nomiclabs/buidler/console.sol";

contract UserProxyFactory {
    mapping (address => UserProxy) userAddressToUserProxy;
    mapping (address => address) userProxyToUserAddress;
    mapping (address => TrustyAaveProxy) agentAaveContracts;
    mapping (address => TrustySimpleLendingProxy) agentSimpleLendingContracts;

    AaveCollateralManager aaveCollateralManager;
    LTCR aaveLTCR;
    SimpleLendingCollateralManager simpleLendingCollateralManager;
    LTCR simpleLendingLTCR;
    mapping (address => bool) isAgentInitialized;


    constructor(
        address payable aaveCollateralManagerAddress,
        address payable simpleLendingCollateralManagerAddress,
        address aaveLTCRAddress,
        address simpleLendingLTCRAddress
    ) public {
        aaveCollateralManager = AaveCollateralManager(aaveCollateralManagerAddress);
        simpleLendingCollateralManager = SimpleLendingCollateralManager(simpleLendingCollateralManagerAddress);
        aaveLTCR = LTCR(aaveLTCRAddress);
        simpleLendingLTCR = LTCR(simpleLendingLTCRAddress);
    }

    function() external payable {}

    function addAgent() public {
        console.log("in addAgent");
        if (!isAgentInitialized[msg.sender]) {
            UserProxy userProxy = new UserProxy(msg.sender, address(this));
            userAddressToUserProxy[msg.sender] = userProxy;
            userProxyToUserAddress[address(userProxy)] = msg.sender;
            initializeTrustyAaveProxy();
            // initializeSimpleLendingProxy();
            // add other protocol initializations here
            // such as initializeCompoundProxy when done
            isAgentInitialized[msg.sender] = true;
        }
    }

    function isAddressATrustyProxy(address userProxyAddress) public view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function initializeTrustyAaveProxy() private {
        UserProxy userProxy = userAddressToUserProxy[msg.sender];
        TrustyAaveProxy trustyAaveProxy = new TrustyAaveProxy(
            msg.sender,
            address(aaveLTCR),
            address(this),
            address(userProxy),
            address(aaveCollateralManager)
        );
        agentAaveContracts[msg.sender] = trustyAaveProxy;
        aaveLTCR.addAuthorisedContract(address(trustyAaveProxy));
        userProxy.addAuthorisedContract(address(agentAaveContracts[msg.sender]));
        trustyAaveProxy.registerAgentToLTCR();
    }

    function initializeSimpleLendingProxy() private {
        UserProxy userProxy = userAddressToUserProxy[msg.sender];
        TrustySimpleLendingProxy trustySimpleLendingProxy = new TrustySimpleLendingProxy(
            msg.sender,
            address(simpleLendingLTCR),
            address(this),
            address(userProxy),
            address(simpleLendingCollateralManager)
        );
        agentSimpleLendingContracts[msg.sender] = trustySimpleLendingProxy;
        simpleLendingLTCR.addAuthorisedContract(address(trustySimpleLendingProxy));
        trustySimpleLendingProxy.registerAgentToLTCR();
        userProxy.addAuthorisedContract(address(agentSimpleLendingContracts[msg.sender]));
    }

    function getTrustySimpleLendingProxy()  public view returns (TrustySimpleLendingProxy) {
        require(isAgentInitialized[msg.sender], "No proxy contract exists for caller. You need to call addAgent first.");
        return agentSimpleLendingContracts[msg.sender];
    }

    function getTrustyAaveProxy()  public view returns (TrustyAaveProxy) {
        require(isAgentInitialized[msg.sender], "No proxy contract exists for caller. You need to call addAgent first.");
        return agentAaveContracts[msg.sender];
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