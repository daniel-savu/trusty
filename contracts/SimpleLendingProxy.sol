pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LTCR.sol";
import "@nomiclabs/buidler/console.sol";
import "./Trusty.sol";
import "./UserProxy.sol";
import "./UserProxyFactory.sol";
import "./SimpleLending/SimpleLending.sol";

// import "./InitializableAdminUpgradeabilityProxy.sol";

contract SimpleLendingProxy is Ownable {
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;
    address constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    LTCR ltcr;

    uint256 depositAction;
    uint256 borrowAction;
    uint256 repayAction;
    uint256 liquidationCallAction;
    uint256 flashLoanAction;
    uint256 redeemAction;
    Trusty trusty;
    UserProxyFactory userProxyFactory;

    constructor(
        address ltcrAddress,
        address payable trustyAddress,
        address payable UserProxyFactoryAddress
    ) public {
        ltcr = LTCR(ltcrAddress);
        trusty = Trusty(trustyAddress);
        userProxyFactory = UserProxyFactory(UserProxyFactoryAddress);
        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidationCallAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
    }

    function() external payable {}

    function curate() public {
        ltcr.curate();
    }

    function getAgentFactor(address agent) public view returns (uint256) {
        return ltcr.getAgentFactor(agent);
    }

    function getAgentScore(address agent) public view returns (uint256) {
        return ltcr.getScore(agent);
    }


    // SimpleLending protocol methods

    // LendingPool contract

    function deposit(address reserve, uint256 amount) public {
        address simpleLendingAddress = trusty.getSimpleLendingAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256)",
            reserve,
            amount
        );
        address payable a = userProxyFactory.getUserProxyAddress(msg.sender);
        UserProxy userProxy = UserProxy(a);
        bool success = userProxy.proxyCall(simpleLendingAddress, abiEncoding, reserve, amount);
        require(success, "deposit failed");
        ltcr.update(address(userProxy), depositAction);
    }

    function borrow(address reserve, uint256 amount) public {
        address simpleLendingAddress = trusty.getSimpleLendingAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256)",
            reserve,
            amount
        );
        UserProxy userProxy = UserProxy(userProxyFactory.getUserProxyAddress(msg.sender));
        bool success = userProxy.proxyCall(simpleLendingAddress, abiEncoding);
        require(success, "borrow failed");
        ltcr.update(address(userProxy), borrowAction);
    }

}


