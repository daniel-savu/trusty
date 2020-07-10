pragma solidity ^0.5.0;


import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@nomiclabs/buidler/console.sol";
import "./TrustyValidator.sol";



contract SimpleLending is Ownable {
    struct Balance {
        uint eth;
        uint dai;
    }

    struct Borrow {
        uint eth;
        uint dai;
    }

    mapping (address => Balance) userBalance;
    mapping (address => Borrow) userBorrow;
    address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    uint ethLiquidity = 0;
    uint daiLiquidity = 0;
    address collateralManager;
    uint baseCollateralisationRate;
    TrustyValidator trustyValidator;

    constructor(address collateralManagerAddress, uint baseCollateralisationRateValue) public {
        collateralManager = collateralManagerAddress;
        baseCollateralisationRate = baseCollateralisationRateValue;
        trustyValidator = new TrustyValidator(collateralManagerAddress, baseCollateralisationRate);
        console.log("SimpleLending address:");
        console.log(address(this));
    }

    function() external payable {
        console.log("in SimpleLending fallback");
    }

    function setBaseCollateralisationRate(uint baseCollateralisationRateValue) public onlyOwner {
        baseCollateralisationRate = baseCollateralisationRateValue;
    }

    function getBaseCollateralisationRate() public returns (uint) {
        return baseCollateralisationRate;
    }

    function deposit(address reserve, uint256 amount) public payable {
        console.log("in SimpleLending deposit");
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
            console.log("adding balance to:");
            console.log(msg.sender);
            userBalance[msg.sender].eth += amount;
            ethLiquidity += amount;
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
            userBalance[msg.sender].dai += amount;
            daiLiquidity += amount;
        }
    }

    function borrow(address reserve, uint256 amount) public hasEnoughCollateral(reserve, amount) enoughLiquidity(reserve, amount) {
        console.log("in SimpleLending borrow");
        if(reserve == ethAddress) {
            msg.sender.transfer(amount);
            userBorrow[msg.sender].eth += amount;
            ethLiquidity -= amount;
        } else {
            IERC20(reserve).transfer(msg.sender, amount);
            userBorrow[msg.sender].dai += amount;
            daiLiquidity -= amount;
        }
    }

    function repay(address reserve, uint256 amount, address onBehalf) public payable {
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
            require(userBorrow[onBehalf].eth >= amount, "amount is larger than actual borrow");
            userBorrow[onBehalf].eth -= amount;
            ethLiquidity += amount;
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
            userBorrow[onBehalf].dai -= amount;
            daiLiquidity += amount;
        }
    }

    function liquidate(address account, address reserve, uint256 amount) public {
        // need to retrieve the collateralization ratio of 'account'
        // from the Trusty contract
        // and check whether user is undercollateralized
        uint deposits = getAccountDeposits(msg.sender);
        uint borrows = getAccountBorrows(msg.sender);
        uint callCollateralization = trustyValidator.getCollateralizationRatio(msg.sender, msg.data);
        uint availableCollateral = deposits - borrows * callCollateralization;
        


    }

    function redeem(address reserve, uint256 amount) public hasEnoughCollateral(reserve, amount) {
        // if hasEnoughCollateral fails, it means that the user will have too little collateral left
        // after redeeming
        if(reserve == ethAddress) {
            uint userLiquidity = userBalance[msg.sender].eth - userBorrow[msg.sender].eth;
            require(userLiquidity > 0, "You don't have enough liquidity in this reserve");
            userBalance[msg.sender].eth -= amount;
        } else {
            uint userLiquidity = userBalance[msg.sender].dai - userBorrow[msg.sender].dai;
            require(userLiquidity > 0, "You don't have enough liquidity in this reserve");
            userBalance[msg.sender].dai -= amount;
        }
        makePayment(reserve, amount, msg.sender);
    }

    function makePayment(address reserve, uint256 amount, address payee) internal enoughLiquidity(reserve, amount) {
        if(reserve == ethAddress) {
            payee.transfer(amount);
        } else {
            IERC20(reserve).transfer(payee, amount);
        }
    }

    modifier hasEnoughCollateral(address reserve, uint256 amount) {
        uint deposits = getAccountDeposits(msg.sender);
        uint borrows = getAccountBorrows(msg.sender);
        uint callCollateralization = trustyValidator.getCollateralizationRatio(msg.sender, msg.data);
        uint availableCollateral = deposits - borrows * callCollateralization;

        uint loanWorth;
        if(reserve == ethAddress) {
            loanWorth = amount;
        } else {
            loanWorth = amount * getEthToDaiPrice();
        }
        require(availableCollateral >= loanWorth * (callCollateralization / (10 ** _decimals)), "too little collateral");
        _;
    }

    modifier enoughLiquidity(address reserve, uint256 amount) {
        if(reserve == ethAddress) {
            require(ethLiquidity >= amount, "not enough ETH liquidity");
        } else {
            require(ethLiquidity >= amount, "not enough DAI liquidity");
        }
        _;
    }

    function getAccountDeposits(address account) public view returns (uint) {
        uint deposits = userBalance[account].eth + (userBalance[account].dai * getDaiToEthPrice());
        return deposits;
    }

    function getAccountBorrows(address account) public view returns (uint) {
        uint borrows = userBorrow[account].eth + (userBorrow[account].dai * getDaiToEthPrice());
        return borrows;
    }

    function getEthToDaiRandomPrice() public view returns (uint) {
        uint random_number = uint(blockhash(block.number - 1)) % 100 + 1;
        uint sign = uint256(keccak256(abi.encodePacked(block.timestamp))) % 2;
        if(sign == 0) {
            return 229 - random_number;
        } else {
            return 229 + random_number;
        }
    }

    function getEthToDaiPrice() public view returns (uint) {
        if (ethLiquidity == 0) {
            // if there's no liquidity, the price is "infinity"
            return type(uint256).max;
        }
        return daiLiquidity / ethLiquidity;
    }

    function getDaiToEthPrice() public view returns (uint) {
        if (daiLiquidity == 0) {
            // if there's no liquidity, the price is "infinity"
            return type(uint256).max;
        }
        return ethLiquidity / daiLiquidity;
    }

}

