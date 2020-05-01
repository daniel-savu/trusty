"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
var __generator = (this && this.__generator) || function (thisArg, body) {
    var _ = { label: 0, sent: function() { if (t[0] & 1) throw t[1]; return t[1]; }, trys: [], ops: [] }, f, y, t, g;
    return g = { next: verb(0), "throw": verb(1), "return": verb(2) }, typeof Symbol === "function" && (g[Symbol.iterator] = function() { return this; }), g;
    function verb(n) { return function (v) { return step([n, v]); }; }
    function step(op) {
        if (f) throw new TypeError("Generator is already executing.");
        while (_) try {
            if (f = 1, y && (t = op[0] & 2 ? y["return"] : op[0] ? y["throw"] || ((t = y["return"]) && t.call(y), 0) : y.next) && !(t = t.call(y, op[1])).done) return t;
            if (y = 0, t) op = [op[0] & 2, t.value];
            switch (op[0]) {
                case 0: case 1: t = op; break;
                case 4: _.label++; return { value: op[1], done: false };
                case 5: _.label++; y = op[1]; op = [0]; continue;
                case 7: op = _.ops.pop(); _.trys.pop(); continue;
                default:
                    if (!(t = _.trys, t = t.length > 0 && t[t.length - 1]) && (op[0] === 6 || op[0] === 2)) { _ = 0; continue; }
                    if (op[0] === 3 && (!t || (op[1] > t[0] && op[1] < t[3]))) { _.label = op[1]; break; }
                    if (op[0] === 6 && _.label < t[1]) { _.label = t[1]; t = op; break; }
                    if (t && _.label < t[2]) { _.label = t[2]; _.ops.push(op); break; }
                    if (t[2]) _.ops.pop();
                    _.trys.pop(); continue;
            }
            op = body.call(thisArg, _);
        } catch (e) { op = [6, e]; y = 0; } finally { f = t = 0; }
        if (op[0] & 5) throw op[1]; return { value: op[0] ? op[1] : void 0, done: true };
    }
};
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
var buidler_1 = require("@nomiclabs/buidler");
var chai_1 = __importDefault(require("chai"));
var ethereum_waffle_1 = require("ethereum-waffle");
var trusty_json_1 = __importDefault(require("../artifacts/trusty.json"));
chai_1.default.use(ethereum_waffle_1.solidity);
var expect = chai_1.default.expect;
function getABI(filename) {
    var fs = require('fs');
    var jsonFile = "/Users/dani/dani/Pro/facultate/Master/Term_3_Dissertation/trusty/build/contracts/" + filename;
    var parsed = JSON.parse(fs.readFileSync(jsonFile));
    var abi = parsed.abi;
    return abi;
}
describe("Counter", function () {
    // 1
    var provider = buidler_1.waffle.provider;
    // 2
    var wallet = provider.getWallets()[0];
    // 3
    var trusty;
    beforeEach(function () { return __awaiter(void 0, void 0, void 0, function () {
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0: return [4 /*yield*/, ethereum_waffle_1.deployContract(wallet, trusty_json_1.default)];
                case 1:
                    trusty = (_a.sent());
                    // 4
                    expect(trusty.address).to.properAddress;
                    return [2 /*return*/];
            }
        });
    }); });
    // 5
    it("should log msg.data", function () { return __awaiter(void 0, void 0, void 0, function () {
        var overrides, protocol, contracts, layers, layerFactors, layerLowerBounds, layerUpperBounds, minCollateral, actions, actionRewards, compoundAddress, compoundABI, compoundCEthContract, supplyRatePerBlockMantissa, interestPerEthThisBlock;
        return __generator(this, function (_a) {
            switch (_a.label) {
                case 0:
                    console.log(trusty.address);
                    overrides = {
                        // The maximum units of gas for the transaction to use
                        gasLimit: 230000
                    };
                    protocol = "Compound";
                    contracts = ["0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5"];
                    layers = [1, 2, 3];
                    layerFactors = [1200, 1050, 1000];
                    layerLowerBounds = [0, 50, 100];
                    layerUpperBounds = [100, 200, 100000];
                    minCollateral = 100;
                    actions = [0];
                    actionRewards = [100];
                    console.log("adding protocol");
                    return [4 /*yield*/, trusty.addProtocol(protocol, contracts, layers, layerFactors, layerLowerBounds, layerUpperBounds, minCollateral, actions, actionRewards)];
                case 1:
                    _a.sent();
                    console.log("done adding protocol");
                    compoundAddress = '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5';
                    compoundABI = getABI("RealCompound.json");
                    compoundCEthContract = new buidler_1.web3.eth.Contract(compoundABI, compoundAddress);
                    return [4 /*yield*/, compoundCEthContract.methods.supplyRatePerBlock().call({
                            from: wallet.address,
                            gasLimit: buidler_1.web3.utils.toHex(150000),
                            gasPrice: buidler_1.web3.utils.toHex(20000000000)
                        })];
                case 2:
                    supplyRatePerBlockMantissa = _a.sent();
                    interestPerEthThisBlock = supplyRatePerBlockMantissa / 1e18;
                    console.log("Each supplied ETH will increase by " + interestPerEthThisBlock +
                        " this block, based on the current interest rate.");
                    console.log("wallet address: " + wallet.address);
                    return [2 /*return*/];
            }
        });
    }); });
});
