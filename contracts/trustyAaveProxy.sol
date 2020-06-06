pragma solidity ^0.5.0;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPool.sol";
import "./LTCR.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@nomiclabs/buidler/console.sol";
import "./trusty.sol";
// import "./InitializableAdminUpgradeabilityProxy.sol";

contract trustyAaveProxy is Ownable {
    address agentOwner;
    uint256 constant INT256_MAX = ~(uint256(1) << 255);
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;
    address constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    mapping(address => address) aTokenUnwrapper;
    mapping(address => address) aTokenWrapper;
    mapping(address => int256) agentFundsInPool;
    LTCR ltcr;
    address[] ERC20Tokens = [
        aETHAddress,
        0x6B175474E89094C44Da98b954EedeAC495271d0F,
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
        0x57Ab1ec28D129707052df4dF418D58a2D46d5f51,
        0x0000000000085d4780B73119b644AE5ecd22b376,
        0xdAC17F958D2ee523a2206206994597C13D831ec7,
        0x4Fabb145d64652a948d72533023f6E7A623C7C53,
        0x0D8775F648430679A709E98d2b0Cb6250d2887EF,
        0xdd974D5C2e2928deA5F71b9825b8b646686BD200
    ];
    uint depositAction;
    uint borrowAction;
    uint repayAction;
    uint liquidationCallAction;
    uint flashLoanAction;
    uint redeemAction;
    trusty trustyContract;

    constructor(address agent, address ltcrAddress, trusty trustyContract) public {
        agentOwner = agent;
        trustyContract = trustyContract;
        ltcr = LTCR(ltcrAddress);

        depositAction = 1;
        borrowAction = 2;
        repayAction = 3;
        liquidationCallAction = 4;
        flashLoanAction = 5;
        redeemAction = 6;
    }

    function registerAgentToLTCR() public onlyOwner {
        console.log(agentOwner);
        ltcr.registerAgent(agentOwner, 100);
    }

    function() external payable {}

    modifier onlyAgentOwner() {
        require(msg.sender == agentOwner, "Caller isn't agentOwner");
        _;
    }

    modifier hasEnoughFunds(address _reserve, uint _amount) {
        int256 amount = uintToInt(_amount);
        // agentFundsInPool[_reserve] can be negative but this is accounted for
        if(_reserve != aETHAddress) {
            int256 ERCTokenBalance = uintToInt(IERC20(_reserve).balanceOf(address(this)));
            int256 fundsInPool = agentFundsInPool[_reserve];
            require(ERCTokenBalance + fundsInPool >= amount, "You don't have enough funds");
            if(ERCTokenBalance < amount && ERCTokenBalance + fundsInPool >= amount) {
                uint256 difference = intToUint(amount - ERCTokenBalance);
                trustyContract.moveFundsToAaveProxy(agentOwner, _reserve, difference);
                agentFundsInPool[_reserve] -= amount;

            }
        } else {
            int256 ethBalance = uintToInt(address(this).balance);
            int256 fundsInPool = agentFundsInPool[aETHAddress];
            require(ethBalance + fundsInPool >= amount, "You don't have enough funds");
            if(ethBalance < amount && ethBalance + fundsInPool >= amount) {
                uint256 difference = intToUint(amount - ethBalance);
                trustyContract.moveFundsToAaveProxy(agentOwner, _reserve, difference);
                agentFundsInPool[_reserve] -= amount;
            }
        }
        _;
    }

    function uintToInt(uint256 a) private view returns (int256) {
        require(a < INT256_MAX, "uint value is too big to convert to int");
        return int256(a);
    }

    function intToUint(int256 a) private view returns (uint256) {
        require(a >= 0, "int value is too small to convert to uint");
        return uint256(a);
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

    function moveFundsToPool(address _reserve, uint _amount) public onlyOwner hasEnoughFunds(_reserve, _amount) {
        agentFundsInPool[_reserve] += uintToInt(_amount);
        withdrawFunds(_reserve, _amount);
    }

    function withdrawFunds(address _reserve, uint _amount) public onlyAgentOwner hasEnoughFunds(_reserve, _amount) {
        if(_reserve != aETHAddress) {
            IERC20(_reserve).transfer(msg.sender, _amount);
        } else {
            msg.sender.transfer(_amount);
        }
    }

    function depositFunds(address _reserve, uint _amount) public payable onlyAgentOwner {
        if(_reserve == aETHAddress) {
            require(msg.value == _amount, "_amount does not match the send ETH");
        } else {
            IERC20(_reserve).transferFrom(msg.sender, address(this), _amount);
        }
    }

    function isERC20Token(address _reserve) private returns (bool) {
        for(uint i = 0; i < ERC20Tokens.length; i++) {
            if(_reserve == ERC20Tokens[i]) {
                return true;
            }
        }
        return false;
    }

    function getFundsInPool(address _reserve) public view returns(int256) {
        return agentFundsInPool[_reserve];
    }

    function getTotalBalance(address _reserve) public view returns(uint256) {
        if(_reserve != aETHAddress) {
            uint256 ERCTokenBalance = IERC20(_reserve).balanceOf(address(this));
            uint256 fundsInPool = intToUint(agentFundsInPool[_reserve]);
            return ERCTokenBalance + fundsInPool;
        } else {
            uint256 balance = address(this).balance;
            uint256 fundsInPool = intToUint(agentFundsInPool[aETHAddress]);
            return balance + fundsInPool;
        }
    }


    // Aave protocol methods

    function redeem(address _reserve, uint256 _amount) public {
        bytes memory redeemAbiEncoding = abi.encodeWithSignature("redeem(uint256)", _amount);
        (bool success, ) = _reserve.call(redeemAbiEncoding);
        require(success, "redeem failed");
        ltcr.update(agentOwner, redeemAction);
    }

    // LendingPool contract

    function getLendingPoolAddress() view private returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPool();
    }

    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) public {
        bool success;
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256,uint16)",
            _reserve,
            _amount,
            _referralCode
        );
        if(_reserve != aETHAddress) {
            // Approve LendingPool contract to move token
            address LendingPoolCoreAddress = ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPoolCore();
            IERC20(_reserve).approve(LendingPoolCoreAddress, _amount);
            (success, ) = LendingPoolAddress.call(abiEncoding);
        } else {
            (success, ) = LendingPoolAddress.call.value(_amount)(abiEncoding);
        }
        require(success, "deposit failed");
        ltcr.update(agentOwner, depositAction);
    }

    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) public {
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16)",
            _reserve,
            _amount,
            _interestRateMode,
            _referralCode
        );
        (bool success, ) = LendingPoolAddress.call(abiEncoding);
        require(success, "borrow failed");
        ltcr.update(agentOwner, borrowAction);
    }

    function repay(address _reserve, uint256 _amount, address _onBehalfOf) public hasEnoughFunds(_reserve, _amount) {
        // repay loan using funds deposited in contract
        bool success;
        bytes memory abiEncoding = abi.encodeWithSignature(
            "repay(address,uint256,address)",
            _reserve,
            _amount,
            address(this)
        );
        address LendingPoolAddress = getLendingPoolAddress();
        if(_reserve != aETHAddress) {
            address LendingPoolCoreAddress = ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPoolCore();
            IERC20(_reserve).approve(LendingPoolCoreAddress, _amount);
            (success, ) = LendingPoolAddress.call(abiEncoding);
        } else {
            (success, ) = LendingPoolAddress.call.value(_amount)(abiEncoding);
        }
        require(success, "repay failed");
        ltcr.update(agentOwner, repayAction);
    }

    function flashLoan(address _receiver, address _reserve, uint256 _amount, bytes calldata _params) external {
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory flashLoanAbiEncoding = abi.encodeWithSignature(
            "flashLoan(address,address,uint256,bytes)",
            _receiver,
            _reserve,
            _amount,
            _params
        );
        (bool success, ) = LendingPoolAddress.call(flashLoanAbiEncoding);
        require(success, "flashLoan failed");
        ltcr.update(agentOwner, flashLoanAction);
    }

    function liquidationCall(
        address _collateral,
        address _reserve,
        address _user,
        uint256 _purchaseAmount,
        bool _receiveAToken
    ) external payable {
        // liquidates using funds in this contract.
        // unsure how to test this function
        bool success;
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory abiEncoding = abi.encodeWithSignature(
            "liquidationCall(address,address,address,uint256,bool)",
            _collateral,
            _reserve,
            _user,
            _purchaseAmount,
            _receiveAToken
        );

        if(_reserve != aETHAddress) {
            address LendingPoolCoreAddress = ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPoolCore();
            IERC20(_reserve).approve(LendingPoolCoreAddress, _purchaseAmount);
            (success, ) = LendingPoolAddress.call(abiEncoding);
        } else {
            (success, ) = LendingPoolAddress.call.value(msg.value)(abiEncoding);
        }
        require(success, "liquidation failed");
        ltcr.update(agentOwner, liquidationCallAction);
    }

}


