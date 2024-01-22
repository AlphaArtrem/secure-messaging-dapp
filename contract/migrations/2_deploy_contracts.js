const SecureMessaging = artifacts.require("SecureMessaging");

export default function (deployer) {
    deployer.deploy(SecureMessaging);
};
