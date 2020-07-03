pragma solidity ^0.5.0;


import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SimpleLending is Ownable {
    struct Balance {
        uint ethBalance;
        uint daiBalance;
    }

    struct Borrow {
        uint ethBorrow;
        uint daiBorrow;
    }

    mapping (address => Balance) userBalance;
    mapping (address => Borrow) userBorrow;
    address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address collateralManager;
    uint baseCollateralisationRate;

    constructor(address collateralManagerAddress, uint baseCollateralisationRateValue) public {
        collateralManager = collateralManagerAddress;
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function setBaseCollateralisationRate(uint baseCollateralisationRateValue) public onlyOwner {
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function getBaseCollateralisationRate() public returns (uint) {
        return baseCollateralisationRate;
    }

    function() external payable {}

    function deposit(address reserve, uint amount) public payable {
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
            userBalance[msg.sender].ethBalance += amount;
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
            userBalance[msg.sender].daiBalance += amount;
        }
    }

    function borrow(address reserve, uint amount) public {
        require(address(this) == collateralManager, "You must use the Collateral Manager contract as a proxy to call this contract");
        if(reserve == ethAddress) {
            msg.sender.transfer(amount);
            userBorrow[msg.sender].ethBorrow += amount;
        } else {
            IERC20(reserve).transfer(msg.sender, amount);
            userBorrow[msg.sender].daiBorrow += amount;
        }
    }

    function getAccountBalance(address account) public returns (uint, uint) {
        uint deposits = userBalance[account].ethBalance + (userBalance[account].daiBalance / getEthToDaiPrice());
        uint borrows = userBorrow[account].ethBorrow + (userBorrow[account].daiBorrow / getEthToDaiPrice());
        return (deposits, borrows);
    }

    function getEthToDaiPrice() public returns (uint) {
        uint random_number = uint(blockhash(block.number - 1)) % 100 + 1;
        uint sign = uint256(keccak256(abi.encodePacked(block.timestamp))) % 2;
        if(sign == 0) {
            return 229 - random_number;
        } else {
            return 229 + random_number;
        }
    }

    function liquidate(address account) public {

    }


}

