pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./LTCR.sol";
import "./UserProxy.sol";
import "./SimpleLending/SimpleLending.sol";
import "./TrustySimpleLendingProxy.sol";
import "./UserProxyFactory.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract Trusty {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    LTCR simpleLendingLTCR;

    SimpleLending simpleLending;
    UserProxyFactory userProxyFactory;
    TrustySimpleLendingProxy trustySimpleLendingProxy;

    uint8[] simpleLendingLayers;
    uint256[] simpleLendingLayerFactors;
    uint256[] simpleLendingLayerLowerBounds;
    uint256[] simpleLendingLayerUpperBounds;

    constructor() public {
        simpleLendingLTCR = new LTCR();
        initializeSimpleLendingLTCR();
        uint baseCollateralisationRateValue = 1500;
        simpleLendingLTCR.addAuthorisedContract(address(userProxyFactory));
        // temporary deployment simpleLending related contracts
        simpleLending = new SimpleLending(address(this), baseCollateralisationRateValue);
        userProxyFactory = new UserProxyFactory(
            address(simpleLendingLTCR),
            address(this)
        );
        initializeSimpleLendingProxy();
    }

    function initializeSimpleLendingLTCR() private {
        uint depositAction;
        uint borrowAction;
        uint repayAction;
        uint liquidationCallAction;
        uint flashLoanAction;
        uint redeemAction;

        // Below are some mock layer factors for demonstration purposes.
        // Proper factors need to be chosen following a game theoretical analysis,
        // like in the section 7 of the Balance paper: https://dl.acm.org/doi/pdf/10.1145/3319535.3354221

        simpleLendingLayers.push(1);
        simpleLendingLayers.push(2);
        simpleLendingLayers.push(3);
        simpleLendingLayers.push(4);
        simpleLendingLayers.push(5);

        // the Layer Token Curated Registry contract (LTCR) uses 3 decimals
        // the LTCR is based on Balance: https://github.com/nud3l/balance
        simpleLendingLayerFactors.push(1000); // 100% of the collateral must be paid
        simpleLendingLayerFactors.push(900);
        simpleLendingLayerFactors.push(850); // 85% of the collateral must be paid
        simpleLendingLayerFactors.push(800);
        simpleLendingLayerFactors.push(750);

        simpleLendingLayerLowerBounds.push(0);
        simpleLendingLayerLowerBounds.push(20);
        simpleLendingLayerLowerBounds.push(40);
        simpleLendingLayerLowerBounds.push(60);
        simpleLendingLayerLowerBounds.push(80);

        simpleLendingLayerUpperBounds.push(25);
        simpleLendingLayerUpperBounds.push(45);
        simpleLendingLayerUpperBounds.push(65);
        simpleLendingLayerUpperBounds.push(85);
        simpleLendingLayerUpperBounds.push(10000);

        simpleLendingLTCR.setLayers(simpleLendingLayers);

        for (uint8 i = 0; i < simpleLendingLayers.length; i++) {
            simpleLendingLTCR.setFactor(simpleLendingLayers[i], simpleLendingLayerFactors[i]);
        }

        for (uint8 i = 0; i < simpleLendingLayers.length; i++) {
            simpleLendingLTCR.setBounds(simpleLendingLayers[i], simpleLendingLayerLowerBounds[i], simpleLendingLayerUpperBounds[i]);
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
        
        simpleLendingLTCR.setReward(depositAction, 15); // user can be promoted to next layer with two deposits
        simpleLendingLTCR.setReward(borrowAction, 0);
        simpleLendingLTCR.setReward(repayAction, 5);
        simpleLendingLTCR.setReward(liquidationCallAction, 10);
        simpleLendingLTCR.setReward(flashLoanAction, 10);
        simpleLendingLTCR.setReward(redeemAction, 0);
    }

    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    function getSimpleLendingRealAddress() public view returns (address) {
        return address(simpleLending);
    }

    function getSimpleLendingLTCR() public view returns (address) {
        return address(simpleLendingLTCR);
    }

    function getSimpleLendingAddress() public view returns (address) {
        return address(simpleLending);
    }

    function getAgentCollateralizationRatio(address agent) public returns (uint256) {
        // a factor of 1500 is equal to 1.5 times the collateral
        return aggregateLTCRs(agent);
    }

    function aggregateLTCRs(address agent) public returns (uint) {
        return simpleLendingLTCR.getAgentFactor(agent);
    }

    function moveFundsToUserProxy(address agentOwner, address _reserve, uint _amount) public {
        // this method assumes proxies will never ask for more funds than they have
        if(_reserve != aETHAddress) {
            IERC20(_reserve).transfer(msg.sender, _amount);
        } else {
            msg.sender.transfer(_amount);
        }
    }

    function initializeSimpleLendingProxy() private {
        console.log("in initializeSimpleLendingProxy");
        console.log(address(userProxyFactory));
        console.log(address(simpleLendingLTCR));
        trustySimpleLendingProxy = new TrustySimpleLendingProxy(
            address(simpleLendingLTCR),
            address(this),
            address(userProxyFactory)
        );
        // simpleLendingLTCR.addAuthorisedContract(address(trustySimpleLendingProxy));
        // userProxy.addAuthorisedContract(address(agentSimpleLendingContracts[msg.sender]));
    }

    function setTrustySimpleLendingProxy(address payable trustySimpleLendingProxyAddress) public {
        trustySimpleLendingProxy = TrustySimpleLendingProxy(trustySimpleLendingProxyAddress);
    }

    function getTrustySimpleLendingProxy()  public view returns (address) {
        return address(trustySimpleLendingProxy);
    }

    function() external payable {
        console.log("reached the fallback");
    }

}