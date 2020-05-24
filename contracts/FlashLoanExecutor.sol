
pragma solidity ^0.5.0;

// import "@openzeppelin/contracts/math/SafeMath.sol";
import "./FlashLoanReceiverBase.sol";
import "./InitializableAdminUpgradeabilityProxy.sol";


contract FlashLoanExecutor is FlashLoanReceiverBase {
    using SafeMath for uint256;

    constructor(LendingPoolAddressesProvider _provider)
        FlashLoanReceiverBase(_provider)
        public {}

    function executeOperation(
        address _reserve,
        uint256 _amount,
        uint256 _fee,
        bytes calldata _params) external {

        //check the contract has the specified balance
        require(_amount <= getBalanceInternal(address(this), _reserve), "Invalid balance for the contract");

        /**
            CUSTOM ACTION TO PERFORM WITH THE BORROWED LIQUIDITY
            
            Example of decoding bytes param of type `address` and `uint`
            (address sampleAddress, uint sampleAmount) = abi.decode(_params, (address, uint));
        */

        // the fee needs to be paid in the loaned asset
        transferFundsBackToPoolInternal(_reserve, _amount.add(_fee));
    }

    function() external payable {}
}