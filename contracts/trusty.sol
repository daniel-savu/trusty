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
        uint baseCollateralisationRateValue = 1500;
        simpleLendingLTCR.addAuthorisedContract(address(userProxyFactory));
        simpleLending = new SimpleLending(address(this), baseCollateralisationRateValue);
        userProxyFactory = new UserProxyFactory(
            address(simpleLendingLTCR),
            address(this)
        );
        initializeSimpleLendingProxy();
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