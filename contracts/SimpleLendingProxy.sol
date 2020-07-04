pragma solidity ^0.5.0;


import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./upgradeabilityProxy/Proxy.sol";
import "./upgradeabilityProxy/UpgradeabilityStorage.sol";
import "@nomiclabs/buidler/console.sol";


contract SimpleLendingProxy is Proxy, UpgradeabilityStorage {
    event Upgraded(uint256 version, address indexed implementation);

    function _upgradeTo(uint256 version, address payable implementation) public {
        require(_implementation != implementation);
        require(version > _version);
        _version = version;
        _implementation = implementation;
        // console.log("upgraded proxy to:");
        // console.log(_implementation);
        // console.log("the address of this proxy:");
        // console.log(address(this));
        emit Upgraded(version, implementation);
    }

}

