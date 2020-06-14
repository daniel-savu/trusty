pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./trustyAaveProxy.sol";
import "./LTCR.sol";
import "./UserProxy.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract trusty {
    string[] _protocols;
    address constant CEtherAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    mapping (address => UserProxy) userAddressToUserProxy;
    mapping (address => address) userProxyToUserAddress;
    mapping (address => trustyAaveProxy) agentAaveContracts;
    LTCR aaveLTCR;
    mapping (address => bool) isAgentInitialized;

    uint8[] aaveLayers;
    uint256[] aaveLayerFactors;
    uint256[] aaveLayerLowerBounds;
    uint256[] aaveLayerUpperBounds;

    constructor() public {
        aaveLTCR = new LTCR();
        initializeAaveLTCR();
    }

    function initializeAaveLTCR() private {
        uint depositAction;
        uint borrowAction;
        uint repayAction;
        uint liquidationCallAction;
        uint flashLoanAction;
        uint redeemAction;

        aaveLTCR.setCollateral(1);
        
        // Below are some mock layer factors for demonstration purposes.
        // Proper factors need to be chosen following a game theoretical analysis,
        // like in the section 7 of the Balance paper: https://dl.acm.org/doi/pdf/10.1145/3319535.3354221

        aaveLayers.push(1);
        aaveLayers.push(2);
        aaveLayers.push(3);
        aaveLayers.push(4);
        aaveLayers.push(5);

        // the Layer Token Curated Registry contract (LTCR) uses 3 decimals
        // the LTCR is based on Balance: https://github.com/nud3l/balance
        aaveLayerFactors.push(2000);
        aaveLayerFactors.push(1800);
        aaveLayerFactors.push(1500); // 153% is the highest collateral ratio in Aave
        aaveLayerFactors.push(1250);
        aaveLayerFactors.push(1100);

        aaveLayerLowerBounds.push(0);
        aaveLayerLowerBounds.push(20);
        aaveLayerLowerBounds.push(40);
        aaveLayerLowerBounds.push(60);
        aaveLayerLowerBounds.push(80);

        aaveLayerUpperBounds.push(25);
        aaveLayerUpperBounds.push(45);
        aaveLayerUpperBounds.push(65);
        aaveLayerUpperBounds.push(85);
        aaveLayerUpperBounds.push(10000);

        aaveLTCR.setLayers(aaveLayers);

        require(aaveLayers.length == aaveLayerFactors.length, "the lengths of layers[] and layerFactors[] are not equal");
        for (uint8 i = 0; i < aaveLayers.length; i++) {
            aaveLTCR.setFactor(aaveLayers[i], aaveLayerFactors[i]);
        }

        require(
            aaveLayers.length == aaveLayerLowerBounds.length && aaveLayers.length == aaveLayerUpperBounds.length,
            "lengths of layers[], layerLowerBounds[] and layerUpperBounds[] are not equal"
        );
        for (uint8 i = 0; i < aaveLayers.length; i++) {
            aaveLTCR.setBounds(aaveLayers[i], aaveLayerLowerBounds[i], aaveLayerUpperBounds[i]);
        }

        // setting the reward for each action
        // ideally, the reward depends on the parameters of the call to Aave
        // but for now, a certain action will carry a certain score.
        // The rewards could potentially be decided by the Aave Protocol Governance
        // Mapping of actions to their id:
        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidationCallAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
        
        aaveLTCR.setReward(depositAction, 15);
        aaveLTCR.setReward(borrowAction, 0);
        aaveLTCR.setReward(repayAction, 5);
        aaveLTCR.setReward(liquidationCallAction, 10);
        aaveLTCR.setReward(flashLoanAction, 10);
        aaveLTCR.setReward(redeemAction, 0);
    }

    function addAgent() public {
        if (!isAgentInitialized[msg.sender]) {
            UserProxy userProxy = new UserProxy(msg.sender, address(this));
            userAddressToUserProxy[msg.sender] = userProxy;
            userProxyToUserAddress[address(userProxy)] = msg.sender;
            initializeAaveProxy();
            // add other protocol initializations here
            // such as initializeCompoundProxy when done
            isAgentInitialized[msg.sender] = true;
        }
    }

    function isAddressATrustyProxy(address userProxyAddress) public view returns (bool) {
        return userProxyToUserAddress[userProxyAddress] != address(0);
    }

    function addLTCRsToUserProxy() private {
        userAddressToUserProxy[msg.sender].addLTCR(address(aaveLTCR));
    }

    function initializeAaveProxy() private {
        UserProxy userProxy = userAddressToUserProxy[msg.sender];
        trustyAaveProxy aaveProxy = new trustyAaveProxy(msg.sender, address(aaveLTCR), address(this), address(userProxy));
        agentAaveContracts[msg.sender] = aaveProxy;
        aaveLTCR.addAuthorisedContract(address(aaveProxy));
        aaveProxy.registerAgentToLTCR();
        userProxy.addAuthorisedContract(address(agentAaveContracts[msg.sender]));
    }

    function getAaveProxy()  public view returns (trustyAaveProxy) {
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

    function getAgentCollateral(address agent) public pure returns (uint256) {
        // a factor of 1500 is equal to 1.5 times the collateral
        return 1000;
    }

    function moveFundsToUserProxy(address agentOwner, address _reserve, uint _amount) public {
        // this method assumes proxies will never ask for more funds than they have
        require(address(agentAaveContracts[agentOwner]) == msg.sender, "Proxy/User mismatch");
        if(_reserve != aETHAddress) {
            IERC20(_reserve).transfer(msg.sender, _amount);
        } else {
            msg.sender.transfer(_amount);
        }
    }

    function() external payable {
        console.log("reached the fallback");
    }

}