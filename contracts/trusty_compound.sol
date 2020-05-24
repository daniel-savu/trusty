pragma solidity ^0.5.0;

import "@studydefi/money-legos/compound/contracts/ICEther.sol";
import "@nomiclabs/buidler/console.sol";
import "./LTCR.sol";
import "./trusty.sol";

contract trusty_compound {

    address constant CEtherAddress = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    LTCR ltcr;

    function setParameters(
        uint8[] memory layers,
        uint256[] memory layerFactors,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds
    ) public returns (bool) { //should be onlyOwner in the future
        ltcr = new LTCR();
        ltcr.setLayers(layers);
        setFactors(layers, layerFactors);
        setBounds(layers, layerLowerBounds, layerUpperBounds);
        return true;
    }

    function setFactors(uint8[] memory layers, uint256[] memory layerFactors) private returns(bool) {
        require(layers.length == layerFactors.length, "the lengths of layers[] and layerFactors[] are not equal");
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setFactor(layers[i], layerFactors[i]);
        }
        return true;
    }

    function setBounds(
        uint8[] memory layers,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds
    ) private returns(bool) {
        require(
            layers.length == layerLowerBounds.length && layers.length == layerUpperBounds.length,
            "lengths of layers[], layerLowerBounds[] and layerUpperBounds[] are not equal"
        );
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setBounds(layers[i], layerLowerBounds[i], layerUpperBounds[i]);
        }
        return true;
    }

    // Compound protocol methods

    // CEther contract

    function mint() public payable {
        // address agent = msg.sender;
        // CEtherAddress.call.value(msg.value)(abi.encodeWithSignature("mint()"));
        ICEther(CEtherAddress).mint.value(msg.value)();
    }

    function balanceOfUnderlying() public returns (uint) {
        return ICEther(CEtherAddress).balanceOfUnderlying(address(this));
    }

    function balanceOf() view public returns (uint256) {
        return ICEther(CEtherAddress).balanceOf(address(this));
    }

    function redeem(uint redeemTokens) public {
        // ICEther(CEtherAddress).redeem(redeemTokens);
        CEtherAddress.call(abi.encodeWithSignature("redeem(uint256)", redeemTokens));
    }

    function borrow(uint borrowAmount) public returns (uint) {
        return ICEther(CEtherAddress).borrow(borrowAmount);
    }

    function() external payable {}
}


