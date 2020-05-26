import env = require("@nomiclabs/buidler");
import CEtherABI from "./ABIs/CEther.json";
import DaiTokenABI from "./ABIs/DAItoken.json";
import LendingPoolAddressesProviderABI from "./ABIs/LendingPoolAddressesProvider.json";
import LendingPoolABI from "./ABIs/LendingPool.json";
import ATokenABI from "./ABIs/AToken.json"
import { assert } from "console";


var web3 = env.web3;
var artifacts = env.artifacts;
var contract = env.contract;

const trusty = artifacts.require("trusty");
const trusty_compound = artifacts.require("trusty_compound");
const trustyAaveProxy = artifacts.require("trustyAaveProxy");
const FlashLoanExecutor = artifacts.require("FlashLoanExecutor");

const privateKey = "01ad2f5ee476f3559b0d2eb8ec22968e847f0dcf3e1fc7ec02e57ecce5000548";
web3.eth.accounts.wallet.add('0x' + privateKey);
const myWalletAddress = web3.eth.accounts.wallet[0].address;

contract("trustyAaveProxy", accounts => {
    const referralCode = '0'
    const ethAddress = '0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE'
    const ethAmountInWei = web3.utils.toWei('1', 'ether')
    const aETHToken = '0x3a3A65aAb0dd2A17E3F1947bA16138cd37d08c04'
    const aETHContract = new web3.eth.Contract(ATokenABI, aETHToken)
    const daiAddress = '0x6B175474E89094C44Da98b954EedeAC495271d0F' // mainnet
    const daiAmountinWei = web3.utils.toWei("0.5", "gwei")
    const interestRateMode = 2 // variable rate
    const lpAddressProviderAddress = '0x24a42fD28C976A61Df5D00D0599C34c4f90748c8'
    const lpAddressProviderContract = new web3.eth.Contract(LendingPoolAddressesProviderABI, lpAddressProviderAddress)

    it("Should take an Aave flashloan using trusty", async function() {
        this.timeout(1000000);
        const t = await trusty.new();
        await t.initializeAaveProxy();
        const taAddress = await t.getAaveProxy({
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(150000),
                gasPrice: web3.utils.toHex(20000000000),
            });
        const ta = await trustyAaveProxy.at(taAddress)
        const flr = await FlashLoanExecutor.new(lpAddressProviderContract.options.address);
        let amount = web3.utils.toWei("100", "ether");
        let params = "0x0";

        let feeRate = 0.0009;
        let fee = Number(amount) * feeRate;

        // send enough funds to FlashLoanExecutor to pay the flashloan fee

        await web3.eth.sendTransaction({
            from: myWalletAddress,
            to: flr.address,
            value: web3.utils.toHex(fee),
            gasLimit: web3.utils.toHex(150000),
            gasPrice: web3.utils.toHex(20000000000),
         });

        var balance = await web3.eth.getBalance(flr.address); 
        console.log(`Balance before the flashloan (0.09%): ${balance}`);
        let tr = await ta.flashLoan(
            flr.address, 
            ethAddress, 
            amount,
            params,
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(1500000000),
                gasPrice: web3.utils.toHex(20000000000),
            }
        );
        balance = await web3.eth.getBalance(flr.address); 
        console.log(`Balance after the flashloan         : ${balance}`);
        assert(balance == 0);
    });

    it("Should call Aave from trusty", async function() {
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

        const t = await trusty.new();
        await t.initializeAaveProxy();
        const taAddress = await t.getAaveProxy({
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(150000),
                gasPrice: web3.utils.toHex(20000000000),
            });
        const ta = await trustyAaveProxy.at(taAddress);

        let tr = await ta.depositFunds(
            ethAddress, 
            ethAmountInWei, 
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(1500000),
                gasPrice: web3.utils.toHex(20000000000),
                value: web3.utils.toHex(web3.utils.toWei('1', 'ether'))
            }
        );

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
        // console.log(tr.receipt.rawLogs);
        console.log("Deposited 1 Ether")

        // Borrowing Dai using the deposited Eth as collateral
        tr = await ta.borrow(
            daiAddress,
            daiAmountinWei,
            interestRateMode,
            referralCode,
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(1500000),
                gasPrice: web3.utils.toHex(20000000000)
            }
        );
        console.log(`Borrowed ${daiAmountinWei} Dai amount in Wei`)
        let d = await lpContract.methods.getUserAccountData(ta.address).call()
        console.log(d);

        await delay(2000);
        console.log(`Paying back ${daiAmountinWei} gwei`)
        tr = await ta.repay(
            daiAddress,
            daiAmountinWei,
            myWalletAddress,
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(15000000),
                gasPrice: web3.utils.toHex(200000000000),
            }
        );
        console.log("Repaid the borrow")
        d = await lpContract.methods.getUserAccountData(ta.address).call()
        console.log(d);

        let balance = await aETHContract.methods.balanceOf(ta.address).call()
        console.log(`Redeeming the balance of: ${balance}`)

        tr = await ta.redeem(
            aETHToken,
            '-1',
            {
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(15000000),
                gasPrice: web3.utils.toHex(200000000000),
            }
        );
        balance = await aETHContract.methods.balanceOf(ta.address).call()
        console.log(`Balance left:             ${balance}`)
        assert(balance == 0);

        await ta.curate({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(15000000),
            gasPrice: web3.utils.toHex(200000000000),
        });

        let agentFactor = await ta.getAgentFactor({
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(15000000),
                gasPrice: web3.utils.toHex(200000000000),
            });
        console.log(`Based on the tested actions, the test agent has achieved a collateral ratio of ${agentFactor}. `);
        console.log(`Keep performing desired Aave actions to further reduce your collateral!`);
    });

    it("Should call Aave directly from javascript", async function() {
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
        console.log(lpAddress)

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
            .catch((e: { message: any; }) => {
                throw Error(`Error depositing to the LendingPool contract: ${e.message}`)
            })
        // console.log(tr)
        console.log("Deposited 1 Ether")

        // Borrowing Dai using the deposited Eth as collateral

        await lpContract.methods
        .borrow(
            daiAddress,
            daiAmountinWei,
            interestRateMode,
            referralCode
        )
        .send({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(1500000),
            gasPrice: web3.utils.toHex(20000000000)
        })
        .catch((e: { message: any; }) => {
            throw Error(`Error with borrow() call to the LendingPool contract: ${e.message}`)
        })

        console.log(`Borrowed ${daiAmountinWei} Dai amount in Wei`)

        let d = await lpContract.methods.getUserAccountData(myWalletAddress).call()
        console.log(d);

        console.log(`Paying back ${daiAmountinWei} gwei`)

        // Get the latest LendingPoolCore address
        const lpCoreAddress = await lpAddressProviderContract.methods
            .getLendingPoolCore()
            .call()

        // Approve the LendingPoolCore address with the DAI contract
        const daiContract = new web3.eth.Contract(DaiTokenABI, daiAddress)
        await daiContract.methods
            .approve(
                lpCoreAddress,
                daiAmountinWei
            )
            .send({
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(15000000),
                gasPrice: web3.utils.toHex(200000000000),
            })

        await lpContract.methods
        .repay(
            daiAddress,
            daiAmountinWei,
            myWalletAddress
        )
        .send({
            from: myWalletAddress,
            gasLimit: web3.utils.toHex(15000000),
            gasPrice: web3.utils.toHex(200000000000),
        })

        console.log("Repaid the borrow")
        d = await lpContract.methods.getUserAccountData(myWalletAddress).call()
        console.log(d);

        let balance = await aETHContract.methods.balanceOf(myWalletAddress).call()
        console.log(`Redeeming the balance of: ${balance}`)
        tr = await aETHContract.methods
            .redeem(balance)
            .send({
                from: myWalletAddress,
                gasLimit: web3.utils.toHex(15000000),
                gasPrice: web3.utils.toHex(200000000000),
            })

        // console.log(tr)
        balance = await aETHContract.methods.balanceOf(myWalletAddress).call()
        console.log(`Balance left:             ${balance}`)
        // There seems to be some slippage occuring
    });
});


contract("trusty_compound", accounts => {
  xit("Should call Compound through trusty_compound", async function() {
    const tc = await trusty_compound.new();

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
    let cTokenBalance:number = (_cTokenBalance / 1e8);
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
    console.log("trusty's cETH Token Balance:", cTokenBalance);

  });
});


contract("Compound", accounts => {
  xit("Should call Compound directly from javascript", async function() {
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
    let cTokenBalance:number = (_cTokenBalance / 1e8);
    console.log("My wallet's cETH Token Balance:", cTokenBalance);

    let exchangeRateCurrent = await compoundCEthContract.methods.
      exchangeRateCurrent().call();
    exchangeRateCurrent = (exchangeRateCurrent / 1e28).toString();
    console.log("Current exchange rate from cETH to ETH:", exchangeRateCurrent);

    console.log('Redeeming the cETH for ETH...');
    await compoundCEthContract.methods.redeem(cTokenBalance * 1e8).send({
      from: myWalletAddress,
      gasLimit: web3.utils.toHex(150000),      // posted at compound.finance/developers#gas-costs
      gasPrice: web3.utils.toHex(20000000000), // use ethgasstation.info (mainnet only)
    });

    cTokenBalance = await compoundCEthContract.methods.balanceOf(myWalletAddress).call();
    cTokenBalance = (cTokenBalance / 1e8);
    console.log("My wallet's cETH Token Balance:", cTokenBalance);
  });
});


function delay(ms: number) {
    return new Promise( resolve => setTimeout(resolve, ms) );
}