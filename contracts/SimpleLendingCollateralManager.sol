pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./Trusty.sol";
import "./interfaces/IPriceOracleGetter.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./upgradeabilityProxy/Proxy.sol";
import "./upgradeabilityProxy/UpgradeabilityStorage.sol";
import "@nomiclabs/buidler/console.sol";



contract SimpleLendingCollateralManager {
// can be called by any address
// however, Trusty addresses may receive a collateral discount
    address targetAddress;
    Trusty trusty;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    uint256 defaultCollateralisation = 1200; // i.e. 1.2x
    uint256 _decimals = 3; // decimals to calculate collateral factor


    constructor(address payable trustyAddress) public {
        trusty = Trusty(trustyAddress);
        // console.log("SimpleLendingCollateralManager address:");
        // console.log(address(this));
    }

    function setTarget(address target) public {
        targetAddress = target;
    }

// we need to pass the target because there are several Aave contracts deployed
    function makeCall(
        address target,
        bytes memory abiEncoding
    ) public payable returns (bool) {
        // console.log("in makecall");
        // console.logBytes(abiEncoding);
        // console.logBytes(abi.encodePacked(bytes4(keccak256("borrow(address,uint256)"))));
        // (address reserve, uint256 amount) = getReserveAndAmount(abiEncoding);
        if(callNeedsCollateral(abiEncoding)) {
        //     require(checkReserveAmount(reserve, amount), "Funds received are not enough");
        //     uint256 totalCollateral = getTotalCollateral();
        //     uint256 loanWorth = getWorthOfLoan(reserve, amount);

        //     if(trusty.isAddressATrustyProxy(msg.sender)) {
        //         // we can apply collateral reduction
        //         uint256 collateralisation = trusty.getAgentCollateral(msg.sender);
        //         require(totalCollateral >= loanWorth * ((defaultCollateralisation * collateralisation) / (10 ** _decimals)), "too little collateral");
        //     } else {
        //         // otherwise, just use the defaultCollateralisation
        //         require(totalCollateral >= loanWorth * (defaultCollateralisation / (10 ** _decimals)), "too little collateral");
        //     }
        // }

        // if(amount > 0) {
        //     require(reserve != address(0), "Reserve address cannot be 0");
        //     if(reserve != aETHAddress) {
        //         IERC20(reserve).transferFrom(msg.sender, address(this), amount);
        //         IERC20(reserve).approve(target, amount);
        //     }
        }
        // console.log("delegating call to:");
        // console.log(target);

        (bool success, ) = target.call(abiEncoding);

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

    function callNeedsCollateral(bytes memory abiEncoding) private view returns (bool) {
        bytes[1] memory callsThatNeedCollateral = [
            abi.encodePacked(bytes4(keccak256("borrow(address,uint256)")))
        ];
        for(uint i = 0; i < callsThatNeedCollateral.length; i++) {
            uint callLength = callsThatNeedCollateral[i].length;
            uint j;
            for(j = 0; j < callLength; j++) {
                if(abiEncoding[j] != callsThatNeedCollateral[i][j]) {
                    break;
                }
            }
            if(j == callLength) {
                return true;
            }
        }
        // console.log("call doesn't need collateral");
        return false;
    }

}