pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPool.sol";
import "./LTCR.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@nomiclabs/buidler/console.sol";
import "./Trusty.sol";
import "./UserProxy.sol";
import "./AaveCollateralManager.sol";
import "./UserProxyFactory.sol";

// import "./InitializableAdminUpgradeabilityProxy.sol";

contract TrustyAaveProxy is Ownable {
    address agentOwner;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;
    address constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    LTCR ltcr;
    AaveCollateralManager aaveCollateralManager;
    UserProxyFactory userProxyFactory;

    uint256 depositAction;
    uint256 borrowAction;
    uint256 repayAction;
    uint256 liquidationCallAction;
    uint256 flashLoanAction;
    uint256 redeemAction;
    UserProxy userProxy;

    constructor(
        address agent,
        address ltcrAddress,
        address payable userProxyFactoryAddress,
        address payable userProxyAddress,
        address payable aaveCollateralManagerAddress
    ) public {
        agentOwner = agent;
        userProxyFactory = UserProxyFactory(userProxyFactoryAddress);
        userProxy = UserProxy(userProxyAddress);
        ltcr = LTCR(ltcrAddress);
        aaveCollateralManager = AaveCollateralManager(aaveCollateralManagerAddress);
        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidationCallAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
    }

    function() external payable {}

    function registerAgentToLTCR() public onlyOwner {
        ltcr.registerAgent(agentOwner, 100);
        console.log("registered agent");
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


    // Aave protocol methods

    function redeem(address reserveContract, uint256 amount) public {
        bytes memory abiEncoding = abi.encodeWithSignature("redeem(uint256)", amount);
        bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
            "makeCall(address,bytes)",
            reserveContract,
            abiEncoding
        );
        bool success = userProxy.proxyCall(address(aaveCollateralManager), collateralManagerAbiEncoding);
        require(success, "redeem failed");
        ltcr.update(agentOwner, redeemAction);
    }


    // LendingPool contract

    function getLendingPoolAddress() private view returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPool();
    }

    function deposit(address reserve, uint256 amount, uint16 referralCode) public {
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256,uint16)",
            reserve,
            amount,
            referralCode
        );
        bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
            "makeCall(address,bytes)",
            LendingPoolAddress,
            abiEncoding
        );
        bool success = userProxy.proxyCall(address(aaveCollateralManager), collateralManagerAbiEncoding, reserve, amount);
        require(success, "deposit failed");
        ltcr.update(agentOwner, depositAction);
    }

    function borrow(address reserve, uint256 amount, uint256 interestRateMode, uint16 referralCode) public {
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16)",
            reserve,
            amount,
            interestRateMode,
            referralCode
        );
        bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
            "makeCall(address,bytes)",
            LendingPoolAddress,
            abiEncoding
        );
        bool success = userProxy.proxyCall(address(aaveCollateralManager), collateralManagerAbiEncoding);
        require(success, "borrow failed");
        ltcr.update(agentOwner, borrowAction);
    }

    function repay(address reserve, uint256 amount, address onBehalfOf) public {
        // repay loan using funds deposited in userProxy
        address agentRecipient = userProxyFactory.findUserProxy(onBehalfOf);
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "repay(address,uint256,address)",
            reserve,
            amount,
            agentRecipient
        );
        bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
            "makeCall(address,bytes)",
            LendingPoolAddress,
            abiEncoding
        );
        bool success = userProxy.proxyCall(address(aaveCollateralManager), collateralManagerAbiEncoding, reserve, amount);
        require(success, "repay failed");
        ltcr.update(agentOwner, repayAction);
    }

    function flashLoan(address receiver, address reserve, uint256 amount, bytes calldata params) external {
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "flashLoan(address,address,uint256,bytes)",
            receiver,
            reserve,
            amount,
            params
        );
        // bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
        //     "makeCall(address,bytes)",
        //     LendingPoolAddress,
        //     abiEncoding
        // );
        aaveCollateralManager._upgradeTo(1, address(uint160(address(LendingPoolAddress))));
        bool success = userProxy.proxyCall(address(aaveCollateralManager), abiEncoding);
        require(success, "flashLoan failed");
        ltcr.update(agentOwner, flashLoanAction);
    }

    function liquidationCall(
        address collateral,
        address reserve,
        address user,
        uint256 purchaseAmount,
        bool receiveAToken
    ) external payable {
        // liquidates using funds in this contract.
        // unsure how to test this function
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "liquidationCall(address,address,address,uint256,bool)",
            collateral,
            reserve,
            user,
            purchaseAmount,
            receiveAToken
        );
        bytes memory collateralManagerAbiEncoding = abi.encodeWithSignature(
            "makeCall(address,bytes)",
            LendingPoolAddress,
            abiEncoding
        );
        bool success = userProxy.proxyCall(address(aaveCollateralManager), collateralManagerAbiEncoding);
        require(success, "liquidation failed");
        ltcr.update(agentOwner, liquidationCallAction);
    }

}


