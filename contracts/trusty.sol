pragma solidity ^0.5.0;

import "@openzeppelin/contracts-ethereum-package/contracts/ownership/Ownable.sol";
import "@nomiclabs/buidler/console.sol";

import "./LTCR.sol";

contract trusty {
    string[] _protocols;

    // each protocols has a corresponding LTCR instance
    mapping (string => LTCR) _protocolToLTCR;
    mapping (string => address[]) _protocolToContracts;

    // because contract addresses are unique, we can map them to their action codes directly
    mapping (address => uint256) _contractToAction;

    function addProtocol(
        string memory protocol,
        address[] memory contracts,
        uint8[] memory layers,
        uint256[] memory layerFactors,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds,
        uint256 minCollateral,
        uint256[] memory actions,
        uint256[] memory actionRewards
    ) public returns (bool) { //should be onlyOwner in the future
        require(!protocolAlreadyAdded(protocol), "protocol already added");

        _protocols.push(protocol);
        _protocolToContracts[protocol] = contracts;
        for(uint8 i = 0; i < contracts.length; i++) {
            _contractToAction[contracts[i]] = actions[i];
        }
        LTCR ltcr = new LTCR();
        _protocolToLTCR[protocol] = ltcr;
        ltcr.setLayers(layers);
        ltcr.setCollateral(minCollateral);

        setFactors(layers, layerFactors, ltcr);
        setRewards(actions, actionRewards, ltcr);
        setBounds(layers, layerLowerBounds, layerUpperBounds, ltcr);
        return true;
    }

    function protocolAlreadyAdded(string memory protocol) private returns(bool) {
        for (uint8 i = 0; i < _protocols.length; i++) {
            if(identicalStrings(_protocols[i], protocol)) {
                return true;
            }
        }
        return false;
    }

    function identicalStrings(string memory a, string memory b) private returns(bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function setFactors(uint8[] memory layers, uint256[] memory layerFactors, LTCR ltcr) private returns(bool) {
        require(layers.length == layerFactors.length, "the lengths of layers[] and layerFactors[] are not equal");
        for (uint8 i = 0; i < layers.length; i++) {
            ltcr.setFactor(layers[i], layerFactors[i]);
        }
        return true;
    }

    function setRewards(uint256[] memory actions, uint256[] memory actionRewards, LTCR ltcr) private returns(bool) {
        require(actions.length == actionRewards.length, "the lengths of actions[] and actionRewards[] are not equal");
        for (uint8 i = 0; i < actions.length; i++) {
            ltcr.setReward(actions[i], actionRewards[i]);
        }
        return true;
    }

    function setBounds(
        uint8[] memory layers,
        uint256[] memory layerLowerBounds,
        uint256[] memory layerUpperBounds,
        LTCR ltcr
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

    function setContracts(string memory protocol, address[] memory contracts) public returns(bool) { //should be onlyOwner in the future
        console.log("console log working 2");
        require(protocolAlreadyAdded(protocol), "protocol not integrated with trusty");
        _protocolToContracts[protocol] = contracts;
        return true;
    }

    function proxy(address implementation, bytes memory params) public payable {
        address agent = msg.sender;
        string memory protocol = getTrustyIntegration(implementation);
        console.log("reached proxy. Received wei:");
        console.log(msg.value);
        require(!identicalStrings(protocol, ""), "contract not integrated with trusty");

        LTCR ltcr = _protocolToLTCR[protocol];

        // mock agent collateral for now
        uint256 collateral = 130;
        addAgentToLTCR(agent, collateral, ltcr);

// at the moment, an entire contract is associated with an action, 
// because I'm unsure how to distinguish between the methods being called
        uint256 action = _contractToAction[implementation];


        uint len = params.length;
        assembly {
            let result := delegatecall(gas(), implementation, add(params, 32), len, 0, 0)
            returndatacopy(0, 0, returndatasize())
        }
        console.log("call successful");
        ltcr.update(agent, action);
        // no need to check `result`, since a a failed trasnaction will revert state and the following code won't be reached
    }

    function getTrustyIntegration(address implementation) private returns(string memory) {
        for (uint8 i = 0; i < _protocols.length; i++) {
            address[] memory contracts = _protocolToContracts[_protocols[i]];
            for (uint8 j = 0; j < contracts.length; j++) {
                if (contracts[j] == implementation) {
                    return _protocols[i];
                }
            }
        }
        return "";
    }

    function addAgentToLTCR(address agent, uint256 collateral, LTCR ltcr) private {
        if(ltcr.getAssignment(agent) == 0) {
            ltcr.registerAgent(agent, collateral);
        }

    }

    function() external payable {
        console.log("reached the fallback");
    }

}