const SecureMessaging = artifacts.require("SecureMessaging");

contract("SecureMessaging", accounts => {
    let secureMessaging;

    before(async () => {
        secureMessaging = await SecureMessaging.deployed();
    });

    it("should deploy the contract", async () => {
        assert(secureMessaging.address !== '');
    });
    
});
