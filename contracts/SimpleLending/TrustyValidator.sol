pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";

contract TrustyValidator is Ownable {

    mapping (bytes => uint) collateralizationRatios;
    address collateralManagerAddress;
    uint baseCollateralisationRate;

    constructor(address collateralManagerAddressValue, uint baseCollateralisationRateValue) {
        collateralManagerAddress = collateralManagerAddressValue;
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function setCollateralManagerAddress(address collateralManagerAddressValue) public ownlyOwner {
        collateralManagerAddress = collateralManagerAddressValue;
    }

    function setBaseCollateralisationRate(uint baseCollateralisationRateValue) public ownlyOwner {
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function generateAuthToken(address forAccount, bytes memory abiEncoding, uint collateralizationRatio) public returns (bytes) {
        require(msg.sender == collateralManagerAddress, "Caller must be the CollateralManager of SimpleLending");
        bytes authToken = keccak256(abi.encodePacked(forAccount, abiEncoding, block.timestamp));
        collateralizationRatios[authToken] = collateralizationRatio;
    }

    function getCollateralizationRatio(address forAccount, bytes memory abiEncoding) public returns (uint) {
        bytes token = keccak256(abi.encodePacked(forAccount, abiEncoding, block.timestamp));
        if(collateralizationRatios[token] == 0) {
            return baseCollateralisationRate;
        }
        return collateralizationRatios[token];
    }

}