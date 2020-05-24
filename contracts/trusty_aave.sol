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


    // Aave protocol methods

    function redeem(address _reserve, uint256 _amount) public {
        bytes memory redeemAbiEncoding = abi.encodeWithSignature("redeem(uint256)", _amount);
        // AToken(_reserve).redeem(_amount);
        (bool success, ) = _reserve.call(redeemAbiEncoding);
        // require(success);

    }

    // LendingPool contract

    function getLendingPoolAddress() view private returns (address) {
        return ILendingPoolAddressesProvider(LendingPoolAddressesProviderAddress).getLendingPool();
    }

    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) public payable {
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
    }

    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) public {
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
    }

    function repay(address _reserve, uint256 _amount, address _onBehalfOf) public payable {
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
    }


    function() external payable {}

}


