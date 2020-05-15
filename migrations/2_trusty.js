var LTCR = artifacts.require("./LTCR.sol");
var trusty_compound = artifacts.require("./trusty_compound.sol");
var trusty = artifacts.require("./trusty.sol");

module.exports = function (deployer) {
    deployer.deploy(LTCR);
    deployer.deploy(trusty_compound);
    deployer.deploy(trusty);
};