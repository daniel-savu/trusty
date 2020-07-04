import env = require("@nomiclabs/buidler");
import CEtherABI from "./ABIs/CEther.json";
import DaiTokenABI from "./ABIs/DAItoken.json";
import LendingPoolAddressesProviderABI from "./ABIs/LendingPoolAddressesProvider.json";
import LendingPoolABI from "./ABIs/LendingPool.json";
import ATokenABI from "./ABIs/AToken.json"
import ltcrABI from "./ABIs/LTCR.json"
import { assert } from "console";


var web3 = env.web3;
var artifacts = env.artifacts;
var contract = env.contract;

const Trusty = artifacts.require("Trusty");
const TrustyCompound = artifacts.require("TrustyCompound");
const TrustyAaveProxy = artifacts.require("TrustyAaveProxy");
const TrustySimpleLendingProxy = artifacts.require("TrustySimpleLendingProxy");
const UserProxyFactory = artifacts.require("UserProxyFactory");
const userProxy = artifacts.require("UserProxy");
const LTCR = artifacts.require("LTCR");
const SimpleLending = artifacts.require("SimpleLending");
const AaveCollateralManager = artifacts.require("AaveCollateralManager");

const privateKey = "01ad2f5ee476f3559b0d2eb8ec22968e847f0dcf3e1fc7ec02e57ecce5000548";
web3.eth.accounts.wallet.add('0x' + privateKey);
const myWalletAddress = web3.eth.accounts.wallet[0].address;

const ethAddress = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
const ethAmountInWei = web3.utils.toWei('1', 'ether')
const aETHToken = '0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04'
const aETHContract = new web3.eth.Contract(ATokenABI, aETHToken)

contract("SimpleLending Protocol", accounts => {

    async function initializeSimpleLendingLTCR(trusty: typeof Trusty) {
        const simpleLendingLTCRAddress = await trusty.getSimpleLendingLTCR();
        // const aaveLTCRAddress = await trusty.getAaveLTCR({
        //     from: myWalletAddress,
        //     gasLimit: web3.utils.toHex(150000),
        //     gasPrice: web3.utils.toHex(20000000000),
        // });
        const simpleLendingLTCRContractTruffle = await LTCR.at(simpleLendingLTCRAddress);
        const simpleLendingLTCRContract = new web3.eth.Contract(simpleLendingLTCRContractTruffle.abi, simpleLendingLTCRAddress)

        console.log(simpleLendingLTCRContract.methods.setCollateral);
        // await simpleLendingLTCRContract.methods.setCollateral(1).call();
        
        // let data = simpleLendingLTCRContract.methods.setCollateral(1).encodeABI();
        // await web3.eth.sendTransaction({
        //     from: accs[0],
        //     to: simpleLendingLTCRContract.address,
        //     data: data,
        //     gasLimit: web3.utils.toHex(150000),
        //     gasPrice: web3.utils.toHex(20000000000),
        // });

        await simpleLendingLTCRContractTruffle.setCollateral(1);
        let simpleLendingLayers = [1, 2, 3, 4, 5];
        let simpleLendingLayerFactors = [2000, 1800, 1500, 1250, 1100]; // 153% is the highest collateral ratio in Aave
        let simpleLendingLayerLowerBounds = [0, 20, 40, 60, 80];
        let simpleLendingLayerUpperBounds = [25, 45, 65, 85, 10000];

        await simpleLendingLTCRContractTruffle.addLayers(simpleLendingLayers.length);

        console.log("the layers are:");
        // let LTCRLayers = await simpleLendingLTCRContract.getLayers();
        // console.log(LTCRLayers);

        for(let i = 0; i < simpleLendingLayers.length; i++) {
            await simpleLendingLTCRContract.setFactor(simpleLendingLayers[i], simpleLendingLayerFactors[i]);
        }

        for(let i = 0; i < simpleLendingLayers.length; i++) {
            await simpleLendingLTCRContract.setBounds(simpleLendingLayers[i], simpleLendingLayerLowerBounds[i], simpleLendingLayerUpperBounds[i]);
        }

        // setting the reward for each action
        // ideally, the reward depends on call parameters
        // Mapping of actions to their id:
        const depositAction = 1;
        const borrowAction = 2;
        const repayAction = 3;
        const liquidationCallAction = 4;
        const flashLoanAction = 5;
        const redeemAction = 6;
        
        await simpleLendingLTCRContract.setReward(depositAction, 15);
        await simpleLendingLTCRContract.setReward(borrowAction, 0);
        await simpleLendingLTCRContract.setReward(repayAction, 5);
        await simpleLendingLTCRContract.setReward(liquidationCallAction, 10);
        await simpleLendingLTCRContract.setReward(flashLoanAction, 10);
        await simpleLendingLTCRContract.setReward(redeemAction, 0);
    }

    it("Should deposit to SimpleLending", async function () {
        this.timeout(1000000);
        let accs = await web3.eth.getAccounts();
        const t = await Trusty.new();
        const userProxyFactoryAddress = await t.getUserProxyFactoryAddress();
        const simpleLendingAddress = await t.getSimpleLendingAddress();
        const simpleLending = await SimpleLending.at(simpleLendingAddress);
        // initializeSimpleLendingLTCR(t);
        const userProxyFactory = await UserProxyFactory.at(userProxyFactoryAddress);
        let addAgentTx = await userProxyFactory.addAgent();

        const trustySimpleLendingProxyAddress = await userProxyFactory.getTrustySimpleLendingProxy();
        const trustySimpleLendingProxy = await TrustySimpleLendingProxy.at(trustySimpleLendingProxyAddress);

        const userProxyAddress = await userProxyFactory.getUserProxy(accs[0]);
        const up = await userProxy.at(userProxyAddress);
        let tr = await up.depositFunds(
            ethAddress,
            ethAmountInWei,
            {
                gasLimit: web3.utils.toHex(1500000),
                gasPrice: web3.utils.toHex(20000000000),
                value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
            }
        );

        console.log("Deposited funds in UserProxy");
        let balanceAfterDeposit = await web3.eth.getBalance(up.address)
        console.log(`Balance:                 ${balanceAfterDeposit}`)

        tr = await trustySimpleLendingProxy.deposit(
            ethAddress,
            ethAmountInWei
        );

        console.log("Deposited 1 Ether")

        let balanceAfterSLDeposit = await web3.eth.getBalance(up.address)
        console.log(`Balance left:            ${balanceAfterSLDeposit}`)

        let balanceInSLProxy = await web3.eth.getBalance(simpleLendingAddress)
        console.log(`Balance in SLProxy:      ${balanceInSLProxy}`)
        
        // console.log(tr);

        // let balanceInSL = await web3.eth.getBalance("0x45070c0860d5d74e0294b6cb9bcc73cddfbef7c0")
        // console.log(`Balance in SL:           ${balanceInSL}`)


        // const simpleLendingAddressReal = await t.getSimpleLendingRealAddress();
        // const trustySimpleLendingProxyReal = await TrustySimpleLendingProxy.at(simpleLendingAddressReal);

        // tr = await trustySimpleLendingProxyReal.deposit(
        //     ethAddress,
        //     ethAmountInWei,
        //     {
        //         gasLimit: web3.utils.toHex(1500000),
        //         gasPrice: web3.utils.toHex(20000000000),
        //         value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
        //     }
        // );
        

        // let userSimpleLendingBalance = await simpleLending.getAccountDeposits(up.address);
        // console.log(`Balance in the SimpleLending contract: ${userSimpleLendingBalance}`)

        // let userSimpleLendingBorrows = await simpleLending.getAccountBorrows(up.address);
        // console.log(`Borrows in the SimpleLending contract: ${userSimpleLendingBorrows}`)
        
    });

});

contract("TrustyAaveProxy", accounts => {
    const referralCode = '0'
    const daiAddress = '0x6B175474E89094C44Da98b954EedeAC495271d0F' // mainnet
    const daiAmountinWei = web3.utils.toWei("0.1", "ether")
    const interestRateMode = 2 // variable rate
    const lpAddressProviderAddress = '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8'
    const lpAddressProviderContract = new web3.eth.Contract(LendingPoolAddressesProviderABI, lpAddressProviderAddress)

    xit("Should take an Aave flashloan using Trusty", async function () {
        // const FlashLoanExecutor = artifacts.require("FlashLoanExecutor");

        this.timeout(1000000);
        const t = await Trusty.new();
        await t.addAgent();
        const taAddress = await t.getTrustyAaveProxy({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(150000),
            gasPrice: web3.utils.toHex(20000000000),
        });
        const ta = await TrustyAaveProxy.at(taAddress)

        // const flr = await FlashLoanExecutor.new(lpAddressProviderContract.options.address);
        // let amount = web3.utils.toWei("100", "ether");
        // let params = "0x0";

        // let feeRate = 0.0009;
        // let fee = Number(amount) * feeRate;

        // // send enough funds to FlashLoanExecutor to pay the flashloan fee

        // await web3.eth.sendTransaction({
        //     from: myWalletAddress,
        //     to: flr.address,
        //     value: web3.utils.toHex(fee),
        //     gasLimit: web3.utils.toHex(150000),
        //     gasPrice: web3.utils.toHex(20000000000),
        // });

        // var balance = await web3.eth.getBalance(flr.address); 
        // console.log(`Balance before the flashloan (0.09%): ${balance}`);
        // let tr = await ta.flashLoan(
        //     flr.address, 
        //     ethAddress, 
        //     amount,
        //     params,
        //     {
        //         from: myWalletAddress,
        //         gasLimit: web3.utils.toHex(1500000000),
        //         gasPrice: web3.utils.toHex(20000000000),
        //     }
        // );
        // balance = await web3.eth.getBalance(flr.address); 
        // console.log(`Balance after the flashloan                 : ${balance}`);
        // console.log(tr)
        // assert(balance == 0);
    });

    xit("Should call Aave from Trusty", async function () {
        this.timeout(1000000);

        // Get the latest LendingPool contract address
        const lpAddress = await lpAddressProviderContract.methods
            .getLendingPool()
            .call()
            .catch((e: { message: any; }) => {
                throw Error(`Error getting lendingPool address: ${e.message}`)
            })

        console.log(lpAddress)

        // Make the deposit transaction via LendingPool contract
        const lpContract = new web3.eth.Contract(LendingPoolABI, lpAddress)

        const t = await Trusty.new();
        await t.addAgent();
        const taAddress = await t.getTrustyAaveProxy({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(150000),
            gasPrice: web3.utils.toHex(20000000000),
        });
        const ta = await TrustyAaveProxy.at(taAddress);

        const userProxyAddress = await t.getUserProxy(
            myWalletAddress,
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(150000),
                gasPrice: web3.utils.toHex(20000000000),
            }
        );
        const up = await userProxy.at(userProxyAddress);
        let tr = await up.depositFunds(
            ethAddress,
            ethAmountInWei,
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(1500000),
                gasPrice: web3.utils.toHex(20000000000),
                value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
            }
        );

        console.log("Deposited funds in UserProxy");
        let balanceAfterDeposit = await web3.eth.getBalance(up.address)
        console.log(`Balance:                                                    ${balanceAfterDeposit}`)

        tr = await ta.deposit(
            ethAddress,
            ethAmountInWei,
            referralCode,
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(1500000),
                gasPrice: web3.utils.toHex(20000000000),
            }
        );
        console.log(tr);
        console.log("Deposited 1 Ether")

        let balanceAfterAaveDeposit = await web3.eth.getBalance(up.address)
        console.log(`Balance left:                                         ${balanceAfterAaveDeposit}`)

        let ethContractBalance = await aETHContract.methods.balanceOf(up.address).call()
        console.log(`Balance in the Aave ETH contract: ${ethContractBalance}`)

        const aaveCollateralManagerAddress = await t.getAaveCollateralManager(
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(150000),
                gasPrice: web3.utils.toHex(20000000000),
            }
        );

        let aaveCollateralManagerContractBalanceInAToken = await aETHContract.methods.balanceOf(aaveCollateralManagerAddress).call()
        console.log(`Balance in the Aave ETH contract for CM: ${aaveCollateralManagerContractBalanceInAToken}`)

        let aaveCollateralManagerContractBalance = await web3.eth.getBalance(aaveCollateralManagerAddress)
        console.log(`Balance left in CM:                                         ${aaveCollateralManagerContractBalance}`)


        // Borrowing Dai using the deposited Eth as collateral
        // tr = await ta.borrow(
        //         daiAddress,
        //         daiAmountinWei,
        //         interestRateMode,
        //         referralCode,
        //         {
        //                 from: myWalletAddress,
        //                 gasLimit: web3.utils.toHex(1500000),
        //                 gasPrice: web3.utils.toHex(20000000000)
        //         }
        // );
        // console.log(`Borrowed ${daiAmountinWei} Dai amount in Wei`)
        // let d = await lpContract.methods.getUserAccountData(up.address).call()
        // console.log(d);

        // // // await delay(2000);
        // console.log(`Paying back ${daiAmountinWei} gwei`)
        // tr = await ta.repay(
        //         daiAddress,
        //         daiAmountinWei,
        //         myWalletAddress,
        //         {
        //                 from: myWalletAddress,
        //                 gasLimit: web3.utils.toHex(15000000),
        //                 gasPrice: web3.utils.toHex(200000000000),
        //         }
        // );
        // console.log(tr)
        // console.log("Repaid the borrow")
        // // d = await lpContract.methods.getUserAccountData(up.address).call()
        // // console.log(d);

        // let balanceBeforeRedeem = await aETHContract.methods.balanceOf(up.address).call()

        // // account for slippage from borrow repayment
        // balanceBeforeRedeem = parseInt(balanceBeforeRedeem) - 30000000000000
        // balanceBeforeRedeem = balanceBeforeRedeem.toString()
        // console.log(`Redeeming the balance of: ${balanceBeforeRedeem}`)

        // tr = await ta.redeem(
        //         aETHToken,
        //         balanceBeforeRedeem,
        //         {
        //                 from: myWalletAddress,
        //                 gasLimit: web3.utils.toHex(15000000),
        //                 gasPrice: web3.utils.toHex(200000000000),
        //         }
        // );
        // let balanceAfterRedeem = await aETHContract.methods.balanceOf(up.address).call()
        // console.log(`Balance left:                         ${balanceAfterRedeem}`)

        // let balanceInUserProxyAfterRedeem = await web3.eth.getBalance(up.address)
        // console.log(`Balance in UserProxy:                                         ${balanceInUserProxyAfterRedeem}`)
        // console.log(tr)
        // assert(balanceAfterRedeem < balanceBeforeRedeem);


        // let agentScore = await ta.getAgentScore({
        //                 from: myWalletAddress,
        //                 gasLimit: web3.utils.toHex(15000000),
        //                 gasPrice: web3.utils.toHex(200000000000),
        //         });
        // console.log(`Based on the tested actions, the test agent has achieved a score of ${agentScore}. `);
        // console.log(`Keep performing desired Aave actions to further reduce your collateral!`);

        // await ta.curate({
        //         from: myWalletAddress,
        //         gasLimit: web3.utils.toHex(15000000),
        //         gasPrice: web3.utils.toHex(200000000000),
        // });
    });

    xit("Should call Aave directly from javascript", async function () {
        this.timeout(1000000);

        // Get the latest LendingPool contract address
        const lpAddress = await lpAddressProviderContract.methods
            .getLendingPool()
            .call()
            .catch((e: { message: any; }) => {
                throw Error(`Error getting lendingPool address: ${e.message}`)
            })

        // Make the deposit transaction via LendingPool contract
        const lpContract = new web3.eth.Contract(LendingPoolABI, lpAddress)

        let tr = await lpContract.methods
            .deposit(
                ethAddress,
                ethAmountInWei,
                referralCode
            )
            .send({
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(1500000),
                gasPrice: web3.utils.toHex(20000000000),
                value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
            })

        // console.log(tr)
        console.log("Deposited 1 Ether")

        tr = await lpContract.methods
            .getUserReserveData(ethAddress, myWalletAddress)
            .call()
            .catch((e: { message: any; }) => {
                throw Error(`Error with getUserReserveData() call to the LendingPool contract: ${e.message}`)
            })
        // console.log(tr)

        // Borrowing Dai using the deposited Eth as collateral

        // await lpContract.methods
        // .borrow(
        //         daiAddress,
        //         daiAmountinWei,
        //         interestRateMode,
        //         referralCode
        // )
        // .send({
        //         from: myWalletAddress,
        //         gasLimit: web3.utils.toHex(1500000),
        //         gasPrice: web3.utils.toHex(20000000000)
        // })


        // console.log(`Borrowed ${daiAmountinWei} Dai amount in Wei`)

        // let d = await lpContract.methods.getUserAccountData(myWalletAddress).call()
        // console.log(d);

        // console.log(`Paying back ${daiAmountinWei} gwei`)

        // // Get the latest LendingPoolCore address
        // const lpCoreAddress = await lpAddressProviderContract.methods
        //         .getLendingPoolCore()
        //         .call()

        // // Approve the LendingPoolCore address with the DAI contract
        // const daiContract = new web3.eth.Contract(DaiTokenABI, daiAddress)
        // await daiContract.methods
        //         .approve(
        //                 lpCoreAddress,
        //                 daiAmountinWei
        //         )
        //         .send({
        //                 from: myWalletAddress,
        //                 gasLimit: web3.utils.toHex(15000000),
        //                 gasPrice: web3.utils.toHex(200000000000),
        //         })

        // await lpContract.methods
        // .repay(
        //         daiAddress,
        //         daiAmountinWei,
        //         myWalletAddress
        // )
        // .send({
        //         from: myWalletAddress,
        //         gasLimit: web3.utils.toHex(15000000),
        //         gasPrice: web3.utils.toHex(200000000000),
        // })

        // console.log("Repaid the borrow")
        // d = await lpContract.methods.getUserAccountData(myWalletAddress).call()
        // console.log(d);

        let balance = await aETHContract.methods.balanceOf(myWalletAddress).call()
        console.log(`Redeeming the balance of: ${balance}`)
        // tr = await aETHContract.methods
        //         .redeem(balance)
        //         .send({
        //                 from: myWalletAddress,
        //                 gasLimit: web3.utils.toHex(15000000),
        //                 gasPrice: web3.utils.toHex(200000000000),
        //         })

        // // console.log(tr)
        // balance = await aETHContract.methods.balanceOf(myWalletAddress).call()
        // console.log(`Balance left:                         ${balance}`)
        // There seems to be some slippage occuring
    });
});


contract("TrustyCompound", accounts => {
    xit("Should call Compound through TrustyCompound", async function () {
        const tc = await TrustyCompound.new();

        const contractAddress = '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5';
        const compoundCEthContract = new web3.eth.Contract(CEtherABI, contractAddress);

        const supplyRatePerBlockMantissa = await compoundCEthContract.methods.
            supplyRatePerBlock().call()
        const interestPerEthThisBlock = supplyRatePerBlockMantissa / 1e18;
        console.log(`Each supplied ETH will increase by ${interestPerEthThisBlock}` +
            ` this block, based on the current interest rate.`)

        console.log('Supplying ETH to the Compound Protocol...');
        // Mint some cETH by supplying ETH to the Compound Protocol
        await tc.mint({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(150000),
            gasPrice: web3.utils.toHex(20000000000),
            value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
        });
        console.log('cETH "Mint" operation successful.');

        const _balanceOfUnderlying = await compoundCEthContract.methods
            .balanceOfUnderlying(tc.address).call();

        let balanceOfUnderlying = web3.utils.fromWei(_balanceOfUnderlying).toString();
        console.log("ETH supplied to the Compound Protocol:", balanceOfUnderlying);

        const _cTokenBalance = await compoundCEthContract.methods.
            balanceOf(tc.address).call();
        let cTokenBalance: number = (_cTokenBalance / 1e8);
        console.log("My wallet's cETH Token Balance:", cTokenBalance);

        let exchangeRateCurrent = await compoundCEthContract.methods.
            exchangeRateCurrent().call();
        exchangeRateCurrent = (exchangeRateCurrent / 1e28).toString();
        console.log("Current exchange rate from cETH to ETH:", exchangeRateCurrent);

        console.log('Redeeming the cETH for ETH...');
        let tr = await tc.redeem(cTokenBalance * 1e8, {
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(1500000),
            gasPrice: web3.utils.toHex(20000000000),
        });

        cTokenBalance = await compoundCEthContract.methods.balanceOf(tc.address).call();
        cTokenBalance = (cTokenBalance / 1e8);
        console.log("Trusty's cETH Token Balance:", cTokenBalance);

    });
});


contract("Compound", accounts => {
    xit("Should call Compound directly from javascript", async function () {
        const contractAddress = '0x4ddc2d193948926d02f9b1fe9e1daa0718270ed5';
        const compoundCEthContract = new web3.eth.Contract(CEtherABI, contractAddress);
        const supplyRatePerBlockMantissa = await compoundCEthContract.methods.
            supplyRatePerBlock().call()
        const interestPerEthThisBlock = supplyRatePerBlockMantissa / 1e18;
        console.log(`Each supplied ETH will increase by ${interestPerEthThisBlock}` +
            ` this block, based on the current interest rate.`)

        console.log('Supplying ETH to the Compound Protocol...');
        // Mint some cETH by supplying ETH to the Compound Protocol
        await compoundCEthContract.methods.mint().send({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(150000),
            gasPrice: web3.utils.toHex(20000000000),
            value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
        });

        console.log('cETH "Mint" operation successful.');

        const _balanceOfUnderlying = await compoundCEthContract.methods
            .balanceOfUnderlying(myWalletAddress).call();

        let balanceOfUnderlying = web3.utils.fromWei(_balanceOfUnderlying).toString();
        console.log("ETH supplied to the Compound Protocol:", balanceOfUnderlying);

        const _cTokenBalance = await compoundCEthContract.methods.
            balanceOf(myWalletAddress).call();
        let cTokenBalance: number = (_cTokenBalance / 1e8);
        console.log("My wallet's cETH Token Balance:", cTokenBalance);

        let exchangeRateCurrent = await compoundCEthContract.methods.
            exchangeRateCurrent().call();
        exchangeRateCurrent = (exchangeRateCurrent / 1e28).toString();
        console.log("Current exchange rate from cETH to ETH:", exchangeRateCurrent);

        console.log('Redeeming the cETH for ETH...');
        await compoundCEthContract.methods.redeem(cTokenBalance * 1e8).send({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(150000),            // posted at compound.finance/developers#gas-costs
            gasPrice: web3.utils.toHex(20000000000), // use ethgasstation.info (mainnet only)
        });

        cTokenBalance = await compoundCEthContract.methods.balanceOf(myWalletAddress).call();
        cTokenBalance = (cTokenBalance / 1e8);
        console.log("My wallet's cETH Token Balance:", cTokenBalance);
    });
});


function delay(ms: number) {
    return new Promise(resolve => setTimeout(resolve, ms));
}