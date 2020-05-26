pragma solidity ^0.5.0;

// import "@openzeppelin/contracts/ownership/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPool.sol";
// import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@nomiclabs/buidler/console.sol";
import "./LTCR.sol";
import "./trusty.sol";
import "./InitializableAdminUpgradeabilityProxy.sol";

contract trustyAaveProxy is Ownable {
    address agentOwner;
    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;
    address constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    mapping(address => address) aTokenUnwrapper;
    mapping(address => address) aTokenWrapper;
    mapping(address => uint256) fundsInTrustyAave;
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

    constructor(address agent) public {
        agentOwner = agent;
        aTokenUnwrapper[aETHContractAddress] = aETHAddress;
        aTokenWrapper[aETHAddress] = aETHContractAddress;

        aTokenUnwrapper[0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d] = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        aTokenWrapper[0x6B175474E89094C44Da98b954EedeAC495271d0F] = 0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d;
    }

    function() external payable {}

    modifier onlyAgentOwner() {
        require(msg.sender == agentOwner, "Caller isn't agentOwner");
        _;
    }

    function setParameters(
        uint8[] memory layers,
        uint256[] memory layerFactors,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds
    ) public onlyOwner { //should be onlyOwner in the future
        ltcr = new LTCR();
        ltcr.setLayers(layers);
        setFactors(layers, layerFactors);
        setBounds(layers, layerLowerBounds, layerUpperBounds);
    }

    function setFactors(uint8[] memory layers, uint256[] memory layerFactors) public onlyOwner {
        require(layers.length == layerFactors.length, "the lengths of layers[] and layerFactors[] are not equal");
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setFactor(layers[i], layerFactors[i]);
        }
    }

    function setBounds(
        uint8[] memory layers,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds
    ) public onlyOwner {
        require(
            layers.length == layerLowerBounds.length && layers.length == layerUpperBounds.length,
            "lengths of layers[], layerLowerBounds[] and layerUpperBounds[] are not equal"
        );
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setBounds(layers[i], layerLowerBounds[i], layerUpperBounds[i]);
        }
    }

    function withdrawFunds(address _reserve) public onlyAgentOwner {
        uint amount = fundsInTrustyAave[_reserve];
        fundsInTrustyAave[_reserve] = 0;
        if(_reserve != aETHAddress) {
            IERC20(_reserve).approve(msg.sender, amount);
        } else {
            msg.sender.transfer(amount);
        }
    }

    function depositFunds(address _reserve, uint _amount) public payable onlyAgentOwner {
        if(_reserve == aETHAddress) {
            require(msg.value == _amount, "_amount does not match the send ETH");
        } else {
            IERC20(_reserve).transferFrom(msg.sender, address(this), _amount);
        }
        fundsInTrustyAave[_reserve] += _amount;
    }

    function isERC20Token(address _reserve) private returns (bool) {
        for(uint i = 0; i < ERC20Tokens.length; i++) {
            if(_reserve == ERC20Tokens[i]) {
                return true;
            }
        }
        return false;
    }

    // function getCurrentATokenBalance(address _reserve) public view returns(uint256) {
    //     return aTokens[_reserve];
    // }

    function getCurrentFundsBalance(address _reserve) public view returns(uint256) {
        return fundsInTrustyAave[_reserve];
    }


    // Aave protocol methods

    function updateAgentReserveData(address _reserve) public {
        if(isERC20Token(_reserve)) {
            updateAgentERC20(_reserve);
        } 
        else {
            updateAgentAToken(_reserve);
        }
    }

    function updateAgentAToken(address _reserve) public {
        address LendingPoolAddress = getLendingPoolAddress();
        // (uint256 currentATokenBalance, , , , , , , , , ,) = ILendingPool(LendingPoolAddress).getUserReserveData(_reserve, address(this));
        bytes memory abiEncoding = abi.encodeWithSignature("getUserReserveData(address,address)", _reserve, this);
        (bool success, bytes memory result) = LendingPoolAddress.call(abiEncoding);
        (uint256 currentATokenBalance, , , , , , , , ,) = abi.decode(
            result,
            (
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                uint256,
                bool
            )
        );
        fundsInTrustyAave[_reserve] = currentATokenBalance;
    }

    function updateAgentERC20(address _reserve) public {
        if(_reserve != aETHAddress) {
            fundsInTrustyAave[_reserve] = IERC20(_reserve).balanceOf(address(this));
        }
    }

    function redeem(address _reserve, uint256 _amount) public {
        bytes memory redeemAbiEncoding = abi.encodeWithSignature("redeem(uint256)", _amount);
        (bool success, ) = _reserve.call(redeemAbiEncoding);
        // require(success);
        updateAgentReserveData(_reserve);
    }

    // LendingPool contract

    function getLendingPoolAddress() view private returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPool();
    }

    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) public {
        // transforms fundsInTrustyAave to aTokens
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
        // require(success);
        updateAgentReserveData(_reserve);
        updateAgentReserveData(aTokenWrapper[_reserve]);
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
        // require(success);
        updateAgentReserveData(_reserve);
    }

    function repay(address _reserve, uint256 _amount, address _onBehalfOf) public {
        // repay loan using funds deposited in contract
        require(_amount <= fundsInTrustyAave[_reserve], "You don't have enough funds deposited in this contract to repay");
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
        // require(success);
        // we're paying back the loan using fundsInTrustyAave, so both
        // the aToken amount and the fundsInTrustyAave[_reserve] will shrink
        updateAgentReserveData(_reserve);
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
        // require(success);
        updateAgentReserveData(_reserve);
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
        // require(success);
        updateAgentReserveData(_collateral);
        updateAgentReserveData(_reserve);
    }

}


