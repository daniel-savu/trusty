pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./trusty.sol";
import "./interfaces/IPriceOracleGetter.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AaveCollateralManager {
// can be called by any address
// however, trusty addresses may receive a collateral discount

    trusty trustyContract;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    uint256 defaultCollateralisation = 1200; // i.e. 1.2x
    uint256 _decimals = 3; // decimals to calculate collateral factor


    constructor(address payable trustyAddress) public {
        trustyContract = trusty(trustyAddress);
    }

    function makeCall(
        address target,
        bytes memory abiEncoding
    ) public payable returns (bool) {
        if(callNeedsCollateral(target, abiEncoding)) {
            (address reserve, uint256 amount) = getReserveAndAmount(abiEncoding);
            require(checkReserveAmount(reserve, amount), "Funds received are not enough");
            uint256 totalCollateral = getTotalCollateral();
            uint256 loanWorth = getWorthOfLoan(reserve, amount);

            if(trustyContract.isAddressATrustyProxy(msg.sender)) {
                // we can apply collateral reduction
                uint256 collateralisation = trustyContract.getAgentCollateral(msg.sender);
                require(totalCollateral >= loanWorth * ((defaultCollateralisation * collateralisation) / (10 ** _decimals)), "too little collateral");
            } else {
                // otherwise, just use the defaultCollateralisation
                require(totalCollateral >= loanWorth * (defaultCollateralisation / (10 ** _decimals)), "too little collateral");
            }
        }
        (bool success, ) = target.delegatecall(abiEncoding);
        return success;
    }

    function checkReserveAmount(address reserve, uint256 amount) private returns (bool) {
        if(reserve == aETHAddress) {
            return msg.value == amount;
        } else {
            uint256 allowance = IERC20(reserve).allowance(msg.sender, address(this));
            return allowance >= amount;
        }
    }

    function callNeedsCollateral(address target, bytes memory abiEncoding) private view returns (bool) {
        // check that the target is the Aave LendingPool and that abiEncoding matches the signature of `borrow`
        // first decode abiEncoding to get parameters, the use those params to build our own encoding with signature
        address LendingPoolAddress = getLendingPoolAddress();

        (address reserve, uint256 amount, uint256 interestRateMode, uint16 referralCode) = abi.decode(abiEncoding, (address, uint256, uint256, uint16));

        bytes memory abiEncodingWhichRequiresCollateral = abi.encodeWithSignature(
                "borrow(address,uint256,uint256,uint16)",
                reserve,
                amount,
                interestRateMode,
                referralCode
            );

        if(keccak256(abiEncodingWhichRequiresCollateral) == keccak256(abiEncoding) && target == LendingPoolAddress) {
            return true;
        }
        return false;
    }

    function getLendingPoolAddress() private view returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPool();
    }

    function getPriceOracleAddress() private view returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getPriceOracle();
    }

    function getTotalCollateral() public returns (uint256) {
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature("getUserAccountData(address)", msg.sender);
        (bool success, bytes memory result) = LendingPoolAddress.call(abiEncoding);
        (
            uint256 totalLiquidityETH,
            uint256 totalCollateralETH,
            uint256 totalBorrowsETH,
            uint256 totalFeesETH,
            uint256 availableBorrowsETH,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = abi.decode(
                result,
                (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
            );
        return totalCollateralETH;
    }

    function getWorthOfLoan(address reserve, uint256 amount) private view returns (uint256) {
        address priceOracleAddress = getPriceOracleAddress();
        IPriceOracleGetter priceOracle = IPriceOracleGetter(priceOracleAddress);
        uint256 price = priceOracle.getAssetPrice(reserve);
        return price * amount;
    }

    function getReserveAndAmount(bytes memory abiEncoding) private view returns (address, uint256) {
        (address reserve, uint256 amount, uint256 interestRateMode, uint16 referralCode) = abi.decode(abiEncoding, (address, uint256, uint256, uint16));
        return (reserve, amount);

    }

    function() external payable {
        console.log("reached the fallback");
    }

}