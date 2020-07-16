pragma solidity ^0.5.0;


import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@nomiclabs/buidler/console.sol";
import "../Trusty.sol";



contract SimpleLending is Ownable {
    mapping (address => mapping(address => uint)) userDeposits;
    mapping (address => mapping(address => uint)) userLoans;
    mapping(address => uint) reserveLiquidity;
    address[] reserves;
    uint baseCollateralisationRate;
    Trusty trusty;
    address ethAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    uint256 collateralizationDecimals = 3; // decimals to calculate collateral factor

    uint conversionDecimals = 25;

    constructor(address payable trustyAddress, uint baseCollateralisationRateValue) public {
        baseCollateralisationRate = baseCollateralisationRateValue;
        trusty = Trusty(trustyAddress);
        reserves.push(ethAddress);
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

    function addReserve(address newReserve) public {
        reserves.push(newReserve);
    }

    function deposit(address reserve, uint256 amount) public payable {
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
        }
        userDeposits[msg.sender][reserve] += amount;
        reserveLiquidity[reserve] += amount;
    }

    function borrow(address reserve, uint256 amount) public hasEnoughCollateral(reserve, amount) {
        require(reserveLiquidity[reserve] >= amount, "not enough reserve liquidity");
        makePayment(reserve, amount, msg.sender);
        userLoans[msg.sender][reserve] += amount;
    }

    function repay(address reserve, uint256 amount, address onBehalf) public payable {
        require(userLoans[onBehalf][reserve] >= amount, "amount is larger than actual borrow");
        if(reserve == ethAddress) {
            require(msg.value == amount, "amount is different from msg.value");
        } else {
            IERC20(reserve).transferFrom(msg.sender, address(this), amount);
        }
        userLoans[msg.sender][reserve] -= amount;
        reserveLiquidity[reserve] += amount;
    }

    function liquidate(address borrower, address collateralReserve, address loanReserve, uint256 loanAmount) public payable {
        // need to retrieve the collateralization ratio of 'account'
        // from the Trusty contract
        // and check whether user is undercollateralized
        uint deposits = getAccountDeposits(borrower);
        uint borrows = getAccountBorrows(borrower);
        uint accountCollateralizationRatio = baseCollateralisationRate * trusty.getAggregateAgentFactor(borrower);
        uint availableCollateral = deposits - borrows * accountCollateralizationRatio;

        require(availableCollateral < 0, "The account is already properly collateralized");
        require(userLoans[borrower][loanReserve] >= loanAmount, "amount is larger than actual loan");
        if(loanReserve == ethAddress) {
            require(msg.value == loanAmount, "amount is different from msg.value");
        } else {
            IERC20(loanReserve).transferFrom(msg.sender, address(this), loanAmount);
        }
        userLoans[borrower][loanReserve] -= loanAmount;
        uint returnedCollateralAmount = convert(loanReserve, collateralReserve, loanAmount);
        userDeposits[borrower][collateralReserve] -= returnedCollateralAmount;
        makePayment(collateralReserve, loanAmount, msg.sender);
        reserveLiquidity[loanReserve] += loanAmount;
        reserveLiquidity[collateralReserve] -= returnedCollateralAmount;
    }

    function redeem(address reserve, uint256 amount) public hasEnoughCollateral(reserve, amount) {
        // if hasEnoughCollateral fails, it means that the user will have too little collateral left
        // after redeeming
        uint userLiquidity = userDeposits[msg.sender][reserve] - userLoans[msg.sender][reserve];
        require(userLiquidity > 0, "You don't have enough liquidity in this reserve");
        makePayment(reserve, amount, msg.sender);
        userDeposits[msg.sender][reserve] -= amount;
    }

    function makePayment(address reserve, uint256 amount, address payable payee) internal enoughLiquidity(reserve, amount) {
        if(reserve == ethAddress) {
            payee.transfer(amount);
        } else {
            IERC20(reserve).transfer(payee, amount);
        }
        reserveLiquidity[reserve] -= amount;
    }

    modifier hasEnoughCollateral(address reserve, uint256 amount) {
        uint borrowableAmountInETH = getBorrowableAmountInETH(msg.sender);
        uint loanWorthInETH;
        if(reserve == ethAddress) {
            loanWorthInETH = amount;
        } else {
            loanWorthInETH = convert(ethAddress, reserve, amount);
        }
        require(borrowableAmountInETH >= loanWorthInETH, "too little collateral");
        _;
    }

    modifier enoughLiquidity(address reserve, uint256 amount) {
        require(reserveLiquidity[reserve] >= amount, "not enough reserve liquidity");
        _;
    }

    function getAccountDeposits(address account) public view returns (uint) {
        uint deposits = 0;
        for(uint i = 0; i < reserves.length; i++) {
            deposits += convert(reserves[i], ethAddress, userDeposits[account][reserves[i]]);
        }
        return deposits;
    }

    function getAccountBorrows(address account) public view returns (uint) {
        uint borrows = 0;
        for(uint i = 0; i < reserves.length; i++) {
            borrows += convert(reserves[i], ethAddress, userLoans[account][reserves[i]]);
        }
        return borrows;
    }

    function getBorrowableAmountInETH(address account) public returns (uint) {
        uint deposits = getAccountDeposits(account);
        uint borrows = getAccountBorrows(account);
        uint accountCollateralizationRatio = baseCollateralisationRate * trusty.getAggregateAgentFactor(account);
        uint borrowableAmountInETH = ((deposits * (10 ** collateralizationDecimals)) / accountCollateralizationRatio) - borrows;
        console.log("borrowableAmountInETH:");
        console.log(borrowableAmountInETH);
        return borrowableAmountInETH;
    }

    function conversionRate(address fromReserve, address toReserve) public view returns (uint) {
        if (reserveLiquidity[fromReserve] == 0 || reserveLiquidity[toReserve] == 0) {
            // if there's no liquidity, the price is "infinity"
            return  2**100;
        }
        uint from = reserveLiquidity[fromReserve];
        uint to = reserveLiquidity[toReserve];
        return from * (10 ** conversionDecimals) / to;
    }

    function convert(address fromReserve, address toReserve, uint amount) public view returns (uint) {
        return (amount * conversionRate(toReserve, fromReserve)) / (10 ** conversionDecimals);
    }

}

