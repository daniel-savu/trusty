var LTCR = artifacts.require("./LTCR.sol");
var TrustyCompound = artifacts.require("./TrustyCompound.sol");
var TrustyAaveProxy = artifacts.require("./TrustyAaveProxy.sol");
var UserProxy = artifacts.require("./UserProxy.sol");
var Trusty = artifacts.require("./Trusty.sol");
// var FlashLoanExecutor = artifacts.require("./FlashLoanExecutor.sol");
// var InitializableAdminUpgradeabilityProxy = artifacts.require("./InitializableAdminUpgradeabilityProxy.sol");
var lpAddressProviderAddress = '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8';
var LendingPoolAddressesProviderABI = require("../test/ABIs/LendingPoolAddressesProvider.json");



module.exports = function (deployer) {
    deployer.deploy(LTCR);
    deployer.deploy(TrustyCompound);
    // deployer.deploy(TrustyAaveProxy);
    // deployer.deploy(UserProxy);
    deployer.deploy(Trusty);
    // const lpAddressProviderContract = new web3.eth.Contract(LendingPoolAddressesProviderABI, lpAddressProviderAddress)
    // deployer.deploy(FlashLoanExecutor, lpAddressProviderContract.options.address);
    // deployer.deploy(InitializableAdminUpgradeabilityProxy);
};