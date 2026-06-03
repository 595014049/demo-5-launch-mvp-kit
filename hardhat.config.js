require("@nomicfoundation/hardhat-toolbox");
require("dotenv").config();

const { Wallet } = require("ethers");

/**
 * 每次启动节点时生成随机助记词
 * 这样每次 npx hardhat node 的账户地址和私钥都不同
 */
const randomMnemonic = Wallet.createRandom().mnemonic.phrase;

// 打印助记词和全部 20 个账户的地址 + 私钥
const { HDNodeWallet } = require("ethers");
console.log(`\n🔑 Random Mnemonic: ${randomMnemonic}`);
console.log("=".repeat(80));
for (let i = 0; i < 20; i++) {
  const w = HDNodeWallet.fromPhrase(randomMnemonic, undefined, `m/44'/60'/0'/0/${i}`);
  console.log(`Account #${i}: ${w.address}  PK: ${w.privateKey}`);
}
console.log("=".repeat(80) + "\n");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.20",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    hardhat: {
      chainId: 31337,
      accounts: {
        mnemonic: randomMnemonic,
        count: 20,
        accountsBalance: "10000000000000000000000",
      },
    },
    sepolia: {
      url: process.env.SEPOLIA_RPC || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    baseSepolia: {
      url: process.env.BASE_SEPOLIA_RPC || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
    arbitrumSepolia: {
      url: process.env.ARBITRUM_SEPOLIA_RPC || "",
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      baseSepolia: process.env.BASESCAN_API_KEY || "",
      arbitrumSepolia: process.env.ARBISCAN_API_KEY || "",
    },
  },
};
