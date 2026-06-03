const { ethers } = require("hardhat");

async function main() {
  const [owner, beneficiary] = await ethers.getSigners();

  const tokenAddr = "0x77c8A2D4ea5F446D9412BE87670616f6f1C72B8E";
  const vestingAddr = "0x11C0ffbf9711E309f451f8A04b58a86f51E8D01a";

  const token = await ethers.getContractAt("LaunchToken", tokenAddr);
  const vesting = await ethers.getContractAt("TokenVesting", vestingAddr);

  // 1. Approve
  let tx = await token.approve(vestingAddr, ethers.parseUnits("100000", 18));
  await tx.wait();
  console.log("✅ Approve done");

  // 2. Create schedule: 30000, cliff 0, vesting 5 days
  tx = await vesting.createSchedule(
    beneficiary.address,
    ethers.parseUnits("30000", 18),
    0,
    0,          // 悬崖 0 天
    432000,     // 解锁 5 天 (5*86400)
    true
  );
  await tx.wait();
  console.log("✅ Schedule created for:", beneficiary.address);

  // 3. 快进 3 天
  await ethers.provider.send("evm_increaseTime", [3 * 86400]);
  await ethers.provider.send("evm_mine", []);

  // 4. 查询可释放
  const r = await vesting.releasable(beneficiary.address);
  console.log("Releasable after 3 days:", ethers.formatUnits(r, 18));

  // 5. Release
  const balBefore = await token.balanceOf(beneficiary.address);
  await vesting.connect(beneficiary).release();
  const balAfter = await token.balanceOf(beneficiary.address);
  console.log("Released:", ethers.formatUnits(balAfter - balBefore, 18));
  console.log("\n=== Done ===");
}

main().catch(console.error);