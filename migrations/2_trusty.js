var LTCR = artifacts.require("./LTCR.sol");
var trusty_compound = artifacts.require("./trusty_compound.sol");
var trusty_aave = artifacts.require("./trusty_aave.sol");
var trusty = artifacts.require("./trusty.sol");
var FlashLoanExecutor = artifacts.require("./FlashLoanExecutor.sol");
var InitializableAdminUpgradeabilityProxy = artifacts.require("./InitializableAdminUpgradeabilityProxy.sol");
var lpAddressProviderAddress = '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8';
var LendingPoolAddressesProviderABI = require("../test/ABIs/LendingPoolAddressesProvider.json");



module.exports = function (deployer) {
    deployer.deploy(LTCR);
    deployer.deploy(trusty_compound);
    deployer.deploy(trusty_aave);
    deployer.deploy(trusty);
    const lpAddressProviderContract = new web3.eth.Contract(LendingPoolAddressesProviderABI, lpAddressProviderAddress)
    deployer.deploy(FlashLoanExecutor, lpAddressProviderContract.options.address);
    deployer.deploy(InitializableAdminUpgradeabilityProxy);
};