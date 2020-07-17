pragma solidity ^0.5.0;

// import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";
import "./LTCR.sol";
import "./UserProxy.sol";
import "./SimpleLending/SimpleLending.sol";
import "./SimpleLendingProxy.sol";
import "./SimpleLendingTwoProxy.sol";
import "./UserProxyFactory.sol";
import "./ILTCR.sol";
// import "node_modules/@studydefi/money-legos/compound/contracts/ICEther.sol";


contract Trusty {
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    UserProxyFactory userProxyFactory;
    LTCR[] ltcrs;
    mapping (address => address) protocolToLtcr;

    LTCR simpleLendingLTCR;
    LTCR simpleLendingTwoLTCR;

    SimpleLending simpleLending;
    SimpleLending simpleLendingTwo;

    SimpleLendingProxy simpleLendingProxy;
    SimpleLendingTwoProxy simpleLendingTwoProxy;

    constructor() public {
        uint baseCollateralisationRateValue = 1500;

        simpleLendingLTCR = new LTCR();
        simpleLendingLTCR.addAuthorisedContract(address(userProxyFactory));
        simpleLending = new SimpleLending(address(this), baseCollateralisationRateValue);

        simpleLendingTwoLTCR = new LTCR();
        simpleLendingTwoLTCR.addAuthorisedContract(address(userProxyFactory));
        simpleLendingTwo = new SimpleLending(address(this), baseCollateralisationRateValue);

        simpleLendingLTCR.setCompatibilityScoreWith(address(simpleLendingTwoLTCR), 50);
        simpleLendingTwoLTCR.setCompatibilityScoreWith(address(simpleLendingLTCR), 50);

        ltcrs.push(simpleLendingLTCR);
        ltcrs.push(simpleLendingTwoLTCR);

        protocolToLtcr[address(simpleLending)] = address(simpleLendingLTCR);
        protocolToLtcr[address(simpleLendingTwo)] = address(simpleLendingTwoLTCR);

        userProxyFactory = new UserProxyFactory(
            address(simpleLendingLTCR),
            address(simpleLendingTwoLTCR),
            address(this)
        );
        
        simpleLendingProxy = new SimpleLendingProxy(
            address(simpleLendingLTCR),
            address(this),
            address(userProxyFactory)
        );

        simpleLendingTwoProxy = new SimpleLendingTwoProxy(
            address(simpleLendingTwoLTCR),
            address(this),
            address(userProxyFactory)
        );
    }

    function() external payable {
        console.log("reached the fallback");
    }

    function getUserProxyFactoryAddress() public view returns (address) {
        return address(userProxyFactory);
    }

    function getSimpleLendingLTCR() public view returns (address) {
        return address(simpleLendingLTCR);
    }

    function getSimpleLendingTwoLTCR() public view returns (address) {
        return address(simpleLendingTwoLTCR);
    }

    function getSimpleLendingAddress() public view returns (address) {
        return address(simpleLending);
    }

    function getSimpleLendingTwoAddress() public view returns (address) {
        return address(simpleLendingTwo);
    }

    function getAggregateAgentFactorForProtocol(address agent, address protocol) public returns (uint256) {
        // a factor of 1500 is equal to 1.5 times the collateral
        uint aggregateAgentFactor = aggregateLTCRsForProtocol(agent, protocol);
        console.log("aggregateAgentFactorForProtocol:");
        console.log(aggregateAgentFactor);
        return aggregateAgentFactor;
    }

    function aggregateLTCRsForProtocol(address agent, address protocol) public returns (uint) {
        uint agentFactorSum = 0;
        uint agentFactorDenominator = 0;
        address LTCRAddress = protocolToLtcr[protocol];

        for(uint i = 0; i < ltcrs.length; i ++) {
            LTCR ltcr = ltcrs[i];
            if(ltcr.getInteractionCount(agent) > 0) {
                agentFactorSum += (ltcr.getAgentFactor(agent) * ILTCR(LTCRAddress).getCompatibilityScoreWith(address(ltcr)));
                agentFactorDenominator += ILTCR(LTCRAddress).getCompatibilityScoreWith(address(ltcr));
            }
        }
        if(agentFactorDenominator > 0) {
            return agentFactorSum / agentFactorDenominator;
        }
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

    function setSimpleLendingProxy(address payable simpleLendingProxyAddress) public {
        simpleLendingProxy = SimpleLendingProxy(simpleLendingProxyAddress);
    }

    function getSimpleLendingProxy()  public view returns (address) {
        return address(simpleLendingProxy);
    }

    function getSimpleLendingTwoProxy()  public view returns (address) {
        return address(simpleLendingTwoProxy);
    }

    function curateLTCRs() public {
        simpleLendingLTCR.curate();
        simpleLendingTwoLTCR.curate();
    }

}