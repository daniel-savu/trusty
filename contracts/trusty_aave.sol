pragma solidity ^0.5.0;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@studydefi/money-legos/aave/contracts/ILendingPool.sol";
// import "@studydefi/money-legos/aave/contracts/ILendingPoolAddressesProvider.sol";
import "@nomiclabs/buidler/console.sol";
import "./LTCR.sol";
import "./trusty.sol";
import "./InitializableAdminUpgradeabilityProxy.sol";

contract trusty_aave is trusty {

    address constant LendingPoolAddressesProviderAddress = 0x24a42fD28C976A61Df5D00D0599C34c4f90748c8;
    address constant aETHAddress = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address constant aETHContractAddress = 0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04;
    address constant daiAddress = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    LTCR ltcr;
    mapping (address => bool) agents;
    mapping (address => uint256) liquidatoinBonus;
    mapping(address => mapping(address => uint256)) aToken;
    mapping(address => mapping(address => uint256)) agentFundsInTrusty;
    uint mantissa = 8;

    constructor() public {
        // aETH 5%
        liquidatoinBonus[0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04] = applyMantissa(5, 2);

        // aDAI 5%
        liquidatoinBonus[0xfC1E690f61EFd961294b3e1Ce3313fBD8aa4f85d] = applyMantissa(5, 2);

        // aUSDC 5%
        liquidatoinBonus[0x9bA00D6856a4eDF4665BcA2C2309936572473B7E] = applyMantissa(5, 2);

        // aREP 10%
        liquidatoinBonus[0x71010A9D003445aC60C4e6A7017c1E89A477B438] = applyMantissa(10, 2);

        // aZRX 10%
        liquidatoinBonus[0x6Fb0855c404E09c47C3fBCA25f08d4E41f9F062f] = applyMantissa(10, 2);
    }

    function() external payable {}

    function applyMantissa(uint x, uint divideByPower) internal returns (uint) {
        return x * (10 ^ (mantissa - divideByPower));
    }

    function setParameters(
        uint8[] memory layers,
        uint256[] memory layerFactors,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds
    ) public { //should be onlyOwner in the future
        ltcr = new LTCR();
        ltcr.setLayers(layers);
        setFactors(layers, layerFactors);
        setBounds(layers, layerLowerBounds, layerUpperBounds);
    }

    function setFactors(uint8[] memory layers, uint256[] memory layerFactors) private {
        require(layers.length == layerFactors.length, "the lengths of layers[] and layerFactors[] are not equal");
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setFactor(layers[i], layerFactors[i]);
        }
    }

    function setBounds(
        uint8[] memory layers,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds
    ) private {
        require(
            layers.length == layerLowerBounds.length && layers.length == layerUpperBounds.length,
            "lengths of layers[], layerLowerBounds[] and layerUpperBounds[] are not equal"
        );
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setBounds(layers[i], layerLowerBounds[i], layerUpperBounds[i]);
        }
    }

    function checkAgent() public {
        if (!agents[msg.sender]) {
            agents[msg.sender] = true;
            // perhaps some other initialization operations
        }
    }

    function withdrawFunds(address _reserve) public {
        uint amount = agentFundsInTrusty[_reserve][msg.sender];
        agentFundsInTrusty[_reserve][msg.sender] = 0;
        uint value = 0;
        if(_reserve != aETHAddress) {
            IERC20(_reserve).approve(msg.sender, amount);
        } else {
            msg.sender.transfer(amount);
        }
        agents[msg.sender] = false;
    }


    // Aave protocol methods

    function redeem(address _reserve, uint256 _amount) public {
        checkAgent();
        // could disallow the use of _amount = -1
        // require(aToken[_reserve][msg.sender] >= _amount, "Not enough funds to redeem");
        bytes memory redeemAbiEncoding = abi.encodeWithSignature("redeem(uint256)", _amount);
        // AToken(_reserve).redeem(_amount);
        (bool success, ) = _reserve.call(redeemAbiEncoding);
        // require(success);

        // might be safer to add/subtract the amount that was subtracted from trusty's account
        // by checking the change in balance after the action
        aToken[_reserve][msg.sender] -= _amount;
        agentFundsInTrusty[_reserve][msg.sender] += _amount;
    }

    // LendingPool contract

    function getLendingPoolAddress() view private returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPool();
    }

    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) public payable {
        checkAgent();
        address LendingPoolAddress = getLendingPoolAddress();
        if(_reserve != aETHAddress) {
            // Approve LendingPool contract to move token
            address LendingPoolCoreAddress = ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPoolCore();
            IERC20(_reserve).approve(LendingPoolCoreAddress, _amount);
        }
        bytes memory depositAbiEncoding = abi.encodeWithSignature(
            "deposit(address,uint256,uint16)",
            _reserve,
            _amount,
            _referralCode
        );
        (bool success, ) = LendingPoolAddress.call.value(msg.value)(depositAbiEncoding);
        // require(success);


        // might be safer to add the amount that was subtracted from trusty's account
        // by checking the change in balance after the action
        aToken[_reserve][msg.sender] += _amount;
    }

    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) public {
        checkAgent();
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory borrowAbiEncoding = abi.encodeWithSignature(
            "borrow(address,uint256,uint256,uint16)",
            _reserve,
            _amount,
            _interestRateMode,
            _referralCode
        );
        (bool success, ) = LendingPoolAddress.call(borrowAbiEncoding);
        // require(success);

        // might be safer to add the amount that was subtracted from trusty's account
        // by checking the change in balance after the action
        aToken[_reserve][msg.sender] += _amount;
    }

    function repay(address _reserve, uint256 _amount, address _onBehalfOf) public payable {
        checkAgent();
        address LendingPoolAddress = getLendingPoolAddress();
        if(_reserve != aETHAddress) {
            // Approve LendingPool contract to move token
            // At the moment we're not checking whether the caller
            // actually has funds in trusty.
            // Trusty should use the `transferFrom(_onBehalfOf, _amount)` ERC20 method to claim ownership over sent token allowance
            address LendingPoolCoreAddress = ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPoolCore();
            IERC20(_reserve).approve(LendingPoolCoreAddress, _amount);
        }
        bytes memory repayAbiEncoding = abi.encodeWithSignature(
            "repay(address,uint256,address)",
            _reserve,
            _amount,
            address(this)
        );
        (bool success, ) = LendingPoolAddress.call.value(msg.value)(repayAbiEncoding);
        // require(success);

        // might be safer to subtract the amount that was subtracted from trusty's account
        // by checking the change in balance after the action
        aToken[_reserve][msg.sender] -= _amount;
    }

    function flashLoan(address _receiver, address _reserve, uint256 _amount, bytes calldata _params) external {
        checkAgent();
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
    }

    function liquidationCall(
        address _collateral,
        address _reserve,
        address _user,
        uint256 _purchaseAmount,
        bool _receiveAToken
    ) external payable {
        // unsure how to test this function
        checkAgent();
        address LendingPoolAddress = getLendingPoolAddress();
        bytes memory liquidationCallAbiEncoding = abi.encodeWithSignature(
            "liquidationCall(address,address,address,uint256,bool)",
            _collateral,
            _reserve,
            _user,
            _purchaseAmount,
            _receiveAToken
        );
        (bool success, ) = LendingPoolAddress.call.value(msg.value)(liquidationCallAbiEncoding);
        // require(success);

        // reduce the _purchaseAmount 
        // aToken[_reserve][msg.sender] -= _purchaseAmount;

        // need to add the reveived funds
        // can compute how much the user is supposed to receive, or check trusty's balance afterwards
    }

}


