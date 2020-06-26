pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./trusty.sol";
import "./interfaces/IPriceOracleGetter.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract AaveCollateralManager {
// can be called by any address
// however, trusty addresses may receive a collateral discount
    address targetAddress;
    trusty trustyContract;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    uint256 defaultCollateralisation = 1200; // i.e. 1.2x
    uint256 _decimals = 3; // decimals to calculate collateral factor


    constructor(address payable trustyAddress) public {
        trustyContract = trusty(trustyAddress);
    }

    function() external payable {
        assembly {
            let _target := sload(0)
            //0x40 is the address where the next free memory slot is stored in Solidity
            let _calldataMemoryOffset := mload(0x40)
            // new "memory end" including padding. The bitwise operations here ensure we get rounded up to the nearest 32 byte boundary
            let _size := and(add(calldatasize, 0x1f), not(0x1f))
            // Update the pointer at 0x40 to point at new free memory location so any theoretical allocation doesn't stomp our memory in this call
            mstore(0x40, add(_calldataMemoryOffset, _size))
            // Copy method signature and parameters of this call into memory
            calldatacopy(_calldataMemoryOffset, 0x0, calldatasize)
            // Call the actual method via delegation
            let _retval := call(gas, _target, callvalue, _calldataMemoryOffset, calldatasize, 0, 0)
            switch _retval
            case 0 {
                // 0 == it threw, so we revert
                revert(0,0)
            } default {
                // If the call succeeded return the return data from the delegate call
                let _returndataMemoryOffset := mload(0x40)
                // Update the pointer at 0x40 again to point at new free memory location so any theoretical allocation doesn't stomp our memory in this call
                mstore(0x40, add(_returndataMemoryOffset, returndatasize))
                returndatacopy(_returndataMemoryOffset, 0x0, returndatasize)
                return(_returndataMemoryOffset, returndatasize)
            }
        }
    }

    function setTarget(address target) public {
        targetAddress = target;
    }

// we need to pass the target because there are several Aave contracts deployed
    function makeCall(
        address target,
        bytes memory abiEncoding
    ) public payable returns (bool) {
        // (address reserve, uint256 amount) = getReserveAndAmount(abiEncoding);
        // if(callNeedsCollateral(target, abiEncoding)) {
        //     require(checkReserveAmount(reserve, amount), "Funds received are not enough");
        //     uint256 totalCollateral = getTotalCollateral();
        //     uint256 loanWorth = getWorthOfLoan(reserve, amount);

        //     if(trustyContract.isAddressATrustyProxy(msg.sender)) {
        //         // we can apply collateral reduction
        //         uint256 collateralisation = trustyContract.getAgentCollateral(msg.sender);
        //         require(totalCollateral >= loanWorth * ((defaultCollateralisation * collateralisation) / (10 ** _decimals)), "too little collateral");
        //     } else {
        //         // otherwise, just use the defaultCollateralisation
        //         require(totalCollateral >= loanWorth * (defaultCollateralisation / (10 ** _decimals)), "too little collateral");
        //     }
        // }
        bool success;
        // if(amount > 0) {
        //     require(reserve != address(0), "Reserve address cannot be 0");
        //     if(reserve != aETHAddress) {
        //         IERC20(reserve).transferFrom(msg.sender, address(this), amount);
        //         IERC20(reserve).approve(target, amount);
        //     }
        // }
        (success, ) = target.delegatecall(abiEncoding);

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

}