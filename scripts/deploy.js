const { ethers } = require("hardhat");
const fs = require("fs");
const path = require("path");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying with account:", deployer.address);

  const tokenName = process.env.TOKEN_NAME || "LaunchToken";
  const tokenSymbol = process.env.TOKEN_SYMBOL || "LAUNCH";
  const tokenDecimals = parseInt(process.env.TOKEN_DECIMALS || "18");
  const initialSupply = ethers.parseUnits(process.env.INITIAL_SUPPLY || "1000000", tokenDecimals);
  const maxSupply = ethers.parseUnits(process.env.MAX_SUPPLY || "10000000", tokenDecimals);

  const LaunchToken = await ethers.getContractFactory("LaunchToken");
  const token = await LaunchToken.deploy(tokenName, tokenSymbol, tokenDecimals, initialSupply, maxSupply, deployer.address);
  await token.waitForDeployment();
  const tokenAddr = await token.getAddress();
  console.log("LaunchToken:", tokenAddr);

  const TokenVesting = await ethers.getContractFactory("TokenVesting");
  const vesting = await TokenVesting.deploy(tokenAddr, deployer.address);
  await vesting.waitForDeployment();
  const vestingAddr = await vesting.getAddress();
  console.log("TokenVesting:", vestingAddr);

  const owners = process.env.MULTISIG_OWNERS ? process.env.MULTISIG_OWNERS.split(",") : [deployer.address];
  const required = parseInt(process.env.MULTISIG_REQUIRED || "1");
  const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
  const multiSig = await MultiSigWallet.deploy(owners, required);
  await multiSig.waitForDeployment();
  const multiSigAddr = await multiSig.getAddress();
  console.log("MultiSigWallet:", multiSigAddr);

  const Treasury = await ethers.getContractFactory("Treasury");
  const treasury = await Treasury.deploy(tokenAddr, multiSigAddr);
  await treasury.waitForDeployment();
  const treasuryAddr = await treasury.getAddress();
  console.log("Treasury:", treasuryAddr);

  // 写入 contracts.json 供前端读取
  const output = {
    31337: {
      LaunchToken: tokenAddr,
      TokenVesting: vestingAddr,
      MultiSigWallet: multiSigAddr,
      Treasury: treasuryAddr,
    },
  };
  const outPath = path.join(__dirname, "..", "frontend", "src", "config", "deployed-addresses.json");
  fs.writeFileSync(outPath, JSON.stringify(output, null, 2));
  console.log("\n✅ Addresses saved to: frontend/src/config/deployed-addresses.json");
}

main().catch((error) => { console.error(error); process.exitCode = 1; });