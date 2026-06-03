const { ethers } = require("hardhat");
async function main() {
  const [owner] = await ethers.getSigners();
  console.log("3332111")
  const vestingAddr = "0x11C0ffbf9711E309f451f8A04b58a86f51E8D01a";
  const vesting = await ethers.getContractAt("TokenVesting", vestingAddr);

  const addr = "0x98a3B1C6430017A6D5BCe65e9A341A781C57932f";
  const s = await vesting.schedules(addr);
  const r = await vesting.releasable(addr);
  const v = await vesting.vestedAmount(addr);
  console.log("12222211111212")
  console.log("Total:", ethers.formatUnits(s[0], 18));
  console.log("Released:", ethers.formatUnits(s[1], 18));
  console.log("Vested:", ethers.formatUnits(v, 18));
  console.log("Releasable now:", ethers.formatUnits(r, 18));
  console.log("Revoked:", s[6]);
  console.log("Cliff (days):", (Number(s[3]) / 86400).toFixed(2));      // ← 悬崖天数
  console.log("Vesting (days):", (Number(s[4]) / 86400).toFixed(2));  
}
main();