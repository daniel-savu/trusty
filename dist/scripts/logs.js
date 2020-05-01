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
var bre = require("@nomiclabs/buidler");
chai_1.default.use(ethereum_waffle_1.solidity);
var expect = chai_1.default.expect;
function getABI(filename) {
    var fs = require('fs');
    var jsonFile = "/Users/dani/dani/Pro/facultate/Master/Term_3_Dissertation/protocol-integrations/build/contracts/" + filename;
    var parsed = JSON.parse(fs.readFileSync(jsonFile));
    var abi = parsed.abi;
    return abi;
}
function getContract(name, contractAddress) {
    return __awaiter(this, void 0, void 0, function () {
        var artifact, provider, contract;
        return __generator(this, function (_a) {
            artifact = getABI(name);
            provider = buidler_1.ethers.getDefaultProvider();
            contract = new buidler_1.ethers.Contract(contractAddress, artifact.abi, provider);
            return [2 /*return*/, contract];
        });
    });
}
function main() {
    return __awaiter(this, void 0, void 0, function () {
        var provider, wallet, trusty, trustyAddress;
        return __generator(this, function (_a) {
            provider = buidler_1.waffle.provider;
            wallet = provider.getWallets()[0];
            trustyAddress = "0xFE5Ae1AFf17E6D58926FFE40cff63DedC17C8695";
            return [2 /*return*/];
        });
    });
}
main()
    .then(function () { return process.exit(0); })
    .catch(function (error) {
    console.error(error);
    process.exit(1);
});
