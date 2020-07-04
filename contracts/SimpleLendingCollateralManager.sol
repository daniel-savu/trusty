pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "./Trusty.sol";
import "./interfaces/IPriceOracleGetter.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./upgradeabilityProxy/Proxy.sol";
import "./upgradeabilityProxy/UpgradeabilityStorage.sol";
import "@nomiclabs/buidler/console.sol";



contract SimpleLendingCollateralManager is Proxy, UpgradeabilityStorage {
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

    event Upgraded(uint256 version, address indexed implementation);

    function _upgradeTo(uint256 version, address payable implementation) public {
        require(_implementation != implementation, "implementation must be different from existing one");
        require(version > _version, "version must be different from existing one");
        _version = version;
        _implementation = implementation;
        emit Upgraded(version, implementation);
    }

    // function() external payable {
    //     assembly {
    //         let _target := sload(0)
    //         //0x40 is the address where the next free memory slot is stored in Solidity
    //         let _calldataMemoryOffset := mload(0x40)
    //         // new "memory end" including padding. The bitwise operations here ensure we get rounded up to the nearest 32 byte boundary
    //         let _size := and(add(calldatasize, 0x1f), not(0x1f))
    //         // Update the pointer at 0x40 to point at new free memory location so any theoretical allocation doesn't stomp our memory in this call
    //         mstore(0x40, add(_calldataMemoryOffset, _size))
    //         // Copy method signature and parameters of this call into memory
    //         calldatacopy(_calldataMemoryOffset, 0x0, calldatasize)
    //         // Call the actual method via delegation
    //         let _retval := call(gas, _target, callvalue, _calldataMemoryOffset, calldatasize, 0, 0)
    //         switch _retval
    //         case 0 {
    //             // 0 == it threw, so we revert
    //             revert(0,0)
    //         } default {
    //             // If the call succeeded return the return data from the delegate call
    //             let _returndataMemoryOffset := mload(0x40)
    //             // Update the pointer at 0x40 again to point at new free memory location so any theoretical allocation doesn't stomp our memory in this call
    //             mstore(0x40, add(_returndataMemoryOffset, returndatasize))
    //             returndatacopy(_returndataMemoryOffset, 0x0, returndatasize)
    //             return(_returndataMemoryOffset, returndatasize)
    //         }
    //     }
    // }

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

        (bool success, ) = target.delegatecall(abiEncoding);

        return success;
    }

    function convertBytesToBytes8(bytes memory inBytes) private returns (bytes4 outBytes4) {
        if (inBytes.length == 0) {
            return 0x0;
        }

        assembly {
            outBytes4 := mload(add(inBytes, 16))
        }
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