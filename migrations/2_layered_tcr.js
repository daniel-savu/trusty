var LTCR = artifacts.require("./LTCR.sol");
var trusty = artifacts.require("./trusty.sol");

module.exports = function (deployer) {
    deployer.deploy(LTCR);
    deployer.deploy(trusty);
};