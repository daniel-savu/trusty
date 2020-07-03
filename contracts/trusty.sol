pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./TrustyAaveProxy.sol";
import "./LTCR.sol";
import "./UserProxy.sol";
import "./AaveCollateralManager.sol";
import "./SimpleLending.sol";
import "./SimpleLendingProxy.sol";
import "./SimpleLendingCollateralManager.sol";
import "./TrustySimpleLendingProxy.sol";
import "./UserProxyFactory.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract Trusty {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    LTCR aaveLTCR;
    LTCR simpleLendingLTCR;

    AaveCollateralManager aaveCollateralManager;
    SimpleLending simpleLending;
    SimpleLendingProxy simpleLendingProxy;
    SimpleLendingCollateralManager simpleLendingCollateralManager;
    UserProxyFactory userProxyFactory;

    uint8[] simpleLendingLayers;
    uint256[] simpleLendingLayerFactors;
    uint256[] simpleLendingLayerLowerBounds;
    uint256[] simpleLendingeLayerUpperBounds;

    constructor() public {
        aaveLTCR = new LTCR();
        simpleLendingLTCR = new LTCR();
        aaveCollateralManager = new AaveCollateralManager(address(this));
        simpleLendingCollateralManager = new SimpleLendingCollateralManager(address(this));
        uint baseCollateralisationRateValue = 1200;

        userProxyFactory = new UserProxyFactory(
            address(aaveCollateralManager),
            address(simpleLendingCollateralManager),
            address(aaveLTCR),
            address(simpleLendingLTCR)
        );

        aaveLTCR.addAuthorisedContract(address(userProxyFactory));
        simpleLendingLTCR.addAuthorisedContract(address(userProxyFactory));

        // temporary deployment simpleLending related contracts
        simpleLending = new SimpleLending(address(simpleLendingCollateralManager), baseCollateralisationRateValue);
        simpleLendingProxy = new SimpleLendingProxy();
        simpleLendingProxy._upgradeTo(1, address(simpleLending));
    }

    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    function getSimpleLendingAddress() public view returns (address) {
        return address(simpleLendingProxy);
    }

    function getAaveCollateralManager() public view returns (AaveCollateralManager) {
        return aaveCollateralManager;
    }

    function getAaveLTCR() public view returns (address) {
        return address(aaveLTCR);
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