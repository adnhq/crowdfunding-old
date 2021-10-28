const { assert } = require("console");

const Factory = artifacts.require("Factory");
const Crowdsale = artifacts.require("Crowdsale");
const TokenContract = artifacts.require("TokenContract");

contract("Factory", () => {
    let accounts;
    let instance;
    let saleAddress, tokenAddress;
    let saleInstance, tokenInstance;

    it("...should deploy crowdsale contract", async () => {
        accounts = await web3.eth.getAccounts();
        instance = await Factory.new();
        await instance.createSale(
            "Sample sale",
            "Testing sale creation",
            web3.utils.toWei("1", "ether"),
            web3.utils.toWei("0.01", "ether"),
            "Test Token",
            "TTK",
            "1000",
            { from: accounts[0] }
        );
        [saleAddress] = await instance.getDeployedSales();
        assert(saleAddress);
    });

    it("...should deploy token contract", async () => {
        tokenAddress = await instance.getTokenAddress(saleAddress);
        assert(tokenAddress);
    });

    it("...should transfer initial supply to factory", async () => {
        tokenInstance = await TokenContract.at(tokenAddress);
        const factoryBalance = await tokenInstance.balanceOf(instance.address);
        assert(factoryBalance.toString() == "1000");
    });

    it("...should be able to contribute", async () => {
        saleInstance = await Crowdsale.at(saleAddress);
        await saleInstance.contribute({
            from: accounts[1],
            value: web3.utils.toWei("0.1", "ether"),
        });

        const balance = await web3.eth.getBalance(saleAddress);
        assert(balance.toString() == web3.utils.toWei("0.1", "ether"));
    });

    it("... contributors should receive tokens", async () => {
        const tokens = await saleInstance.getTokenBalance.call({
            from: accounts[1],
        });
        assert(tokens.toString() == "10");
    });

    const delay = (ms) => {
        const startPoint = new Date().getTime();
        while (new Date().getTime() - startPoint <= ms) {}
    };
    /*
    it("...contributors should be able to claim refund if target is not met", async () => {
        await saleInstance.contribute({
            from: accounts[4],
            value: web3.utils.toWei("0.6", "ether"),
        });
        const initialBalance = await web3.eth.getBalance(accounts[4]);
        delay(10000);
        await saleInstance.getRefund({ from: accounts[4] });
        const updatedBalance = await web3.eth.getBalance(accounts[4]);
        console.log(initialBalance);
        console.log(updatedBalance);
    });
    */
    //Crowdsale timespan set to 8 seconds for testing

    it("...should be able to execute spend requests if target is met", async () => {
        await saleInstance.contribute({
            from: accounts[2],
            value: web3.utils.toWei("1", "ether"),
        });
        delay(10000);
        await saleInstance.makeRequest(
            "Sample request",
            web3.utils.toWei("0.5", "ether"),
            accounts[3],
            { from: accounts[0] }
        );
        await saleInstance.vote("0", { from: accounts[2] });
        await saleInstance.makePayment("0", { from: accounts[0] });
        const receiverBalance = await web3.eth.getBalance(accounts[3]);
        assert(
            receiverBalance.toString() == web3.utils.toWei("100.5", "ether")
        );
    });
    it("...should send remaining balance and tokens to owner on sale end", async () => {
        /*
        await saleInstance.contribute({
            from: accounts[4],
            value: web3.utils.toWei("1", "ether"),
        });
        delay(10000);
        */
        await saleInstance.endRequest("Project complete", {
            from: accounts[0],
        });
        await saleInstance.endVote({ from: accounts[1] });
        await saleInstance.endVote({ from: accounts[2] });
        await saleInstance.end({ from: accounts[0] });
        const ownerTokens = await tokenInstance.balanceOf(accounts[0]);
        const ownerBalance = await web3.eth.getBalance(accounts[0]);
        assert(ownerTokens.toString());
        assert(ownerBalance);
    });
});
