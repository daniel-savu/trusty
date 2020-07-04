pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./LTCR.sol";
import "./UserProxy.sol";
import "./SimpleLending.sol";
import "./SimpleLendingProxy.sol";
import "./SimpleLendingCollateralManager.sol";
import "./TrustySimpleLendingProxy.sol";
import "./UserProxyFactory.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract Trusty {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    LTCR simpleLendingLTCR;

    SimpleLending simpleLending;
    SimpleLendingProxy simpleLendingProxy;
    SimpleLendingCollateralManager simpleLendingCollateralManager;
    UserProxyFactory userProxyFactory;

    uint8[] simpleLendingLayers;
    uint256[] simpleLendingLayerFactors;
    uint256[] simpleLendingLayerLowerBounds;
    uint256[] simpleLendingLayerUpperBounds;

    constructor() public {
        simpleLendingLTCR = new LTCR();
        initializeSimpleLendingLTCR();
        simpleLendingCollateralManager = new SimpleLendingCollateralManager(address(this));
        uint baseCollateralisationRateValue = 1200;

        userProxyFactory = new UserProxyFactory(
            address(simpleLendingCollateralManager),
            address(simpleLendingLTCR),
            address(this)
        );

        simpleLendingLTCR.addAuthorisedContract(address(userProxyFactory));

        // temporary deployment simpleLending related contracts
        simpleLending = new SimpleLending(address(simpleLendingCollateralManager), baseCollateralisationRateValue);
        simpleLendingProxy = new SimpleLendingProxy();
        simpleLendingProxy._upgradeTo(1, address(uint160(address(simpleLending))));
    }

    function initializeSimpleLendingLTCR() private {
        uint depositAction;
        uint borrowAction;
        uint repayAction;
        uint liquidationCallAction;
        uint flashLoanAction;
        uint redeemAction;

        simpleLendingLTCR.setCollateral(1);
        
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
        simpleLendingLayerFactors.push(2000);
        simpleLendingLayerFactors.push(1800);
        simpleLendingLayerFactors.push(1500); // 153% is the highest collateral ratio in Aave
        simpleLendingLayerFactors.push(1250);
        simpleLendingLayerFactors.push(1100);

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
        
        simpleLendingLTCR.setReward(depositAction, 15);
        simpleLendingLTCR.setReward(borrowAction, 0);
        simpleLendingLTCR.setReward(repayAction, 5);
        simpleLendingLTCR.setReward(liquidationCallAction, 10);
        simpleLendingLTCR.setReward(flashLoanAction, 10);
        simpleLendingLTCR.setReward(redeemAction, 0);
    }

    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    function getSimpleLendingAddress() public view returns (address) {
        return address(simpleLendingProxy);
    }

    function getSimpleLendingLTCR() public view returns (address) {
        return address(simpleLendingLTCR);
    }

    function getAgentCollateral(address agent) public pure returns (uint256) {
        // a factor of 1500 is equal to 1.5 times the collateral
        return 1000;
    }

    function moveFundsToUserProxy(address agentOwner, address _reserve, uint _amount) public {
        // this method assumes proxies will never ask for more funds than they have
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