require("@nomicfoundation/hardhat-ethers");

module.exports = {
  solidity: {
    version: "0.8.34",
    settings: { evmVersion: "cancun", optimizer: { enabled: true, runs: 200 } },
  },
};
