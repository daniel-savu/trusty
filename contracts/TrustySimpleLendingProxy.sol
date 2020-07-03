pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPool.sol";
import "./LTCR.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@nomiclabs/buidler/console.sol";
import "./Trusty.sol";
import "./UserProxy.sol";
import "./SimpleLendingCollateralManager.sol";
import "./UserProxyFactory.sol";

// import "./InitializableAdminUpgradeabilityProxy.sol";

contract TrustySimpleLendingProxy is Ownable {
    address agentOwner;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;
    address constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    LTCR ltcr;
    SimpleLendingCollateralManager simpleLendingCollateralManager;
    UserProxyFactory userProxyFactory;

    uint256 depositAction;
    uint256 borrowAction;
    uint256 repayAction;
    uint256 liquidationCallAction;
    uint256 flashLoanAction;
    uint256 redeemAction;
    Trusty trusty;
    UserProxy userProxy;

    constructor(
        address agent,
        address ltcrAddress,
        address payable userProxyFactoryAddress,
        address payable userProxyAddress,
        address payable simpleLendingCollateralManagerAddress
    ) public {
        agentOwner = agent;
        userProxyFactory = UserProxyFactory(userProxyFactoryAddress);
        userProxy = UserProxy(userProxyAddress);
        ltcr = LTCR(ltcrAddress);
        simpleLendingCollateralManager = SimpleLendingCollateralManager(simpleLendingCollateralManagerAddress);
        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidationCallAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
    }

    function() external payable {}

    function registerAgentToLTCR() public onlyOwner {
        console.log(agentOwner);
        ltcr.registerAgent(agentOwner, 100);
    }

    function curate() public {
        ltcr.curate();
    }

    function getAgentFactor() public view returns (uint256) {
        return ltcr.getAgentFactor(agentOwner);
    }

    function getAgentScore() public view returns (uint256) {
        return ltcr.getScore(agentOwner);
    }


    // SimpleLending protocol methods

    // LendingPool contract

    function deposit(address reserve, uint256 amount) public {
        address SimpleLendingAddress = trusty.getSimpleLendingAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256)",
            reserve,
            amount
        );
        // bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
        //     "makeCall(address,bytes)",
        //     SimpleLendingAddress,
        //     abiEncoding
        // );
        simpleLendingCollateralManager._upgradeTo(1, address(uint160(address(SimpleLendingAddress))));
        bool success = userProxy.proxyCall(address(simpleLendingCollateralManager), abiEncoding, reserve, amount);
        require(success, "deposit failed");
        // ltcr.update(agentOwner, depositAction);
    }

    function borrow(address reserve, uint256 amount) public {
        // address SimpleLendingAddress = trusty.getSimpleLendingAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256)",
            reserve,
            amount
        );
        // bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
        //     "makeCall(address,bytes)",
        //     SimpleLendingAddress,
        //     abiEncoding
        // );
        bool success = userProxy.proxyCall(address(simpleLendingCollateralManager), abiEncoding);
        require(success, "borrow failed");
        // ltcr.update(agentOwner, borrowAction);
    }

}


