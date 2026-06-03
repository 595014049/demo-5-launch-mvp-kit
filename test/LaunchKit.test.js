const { expect } = require("chai");
const { ethers } = require("hardhat");

/**
 * Launch MVP Kit - 合约测试套件
 *
 * 覆盖 4 个合约的核心功能：
 * - LaunchToken：铸造、批量转账
 * - TokenVesting：创建解锁计划
 * - MultiSigWallet：提交和批准交易
 * - Treasury：分配资金类别
 */
describe("Launch MVP Kit", function () {
  let token, vesting, multiSig, treasury;
  let owner, addr1, addr2, addr3;

  /** 每个测试用例前重新部署所有合约 */
  beforeEach(async function () {
    [owner, addr1, addr2, addr3] = await ethers.getSigners();

    // 部署 LaunchToken
    const LaunchToken = await ethers.getContractFactory("LaunchToken");
    token = await LaunchToken.deploy(
      "TestToken", "TTK", 18,
      ethers.parseUnits("1000000", 18),
      ethers.parseUnits("10000000", 18),
      owner.address
    );

    // 部署 TokenVesting
    const TokenVesting = await ethers.getContractFactory("TokenVesting");
    vesting = await TokenVesting.deploy(await token.getAddress(), owner.address);

    // 部署 MultiSigWallet（2个所有者，需2签）
    const MultiSigWallet = await ethers.getContractFactory("MultiSigWallet");
    multiSig = await MultiSigWallet.deploy([owner.address, addr1.address], 2);

    // 部署 Treasury
    const Treasury = await ethers.getContractFactory("Treasury");
    treasury = await Treasury.deploy(await token.getAddress(), owner.address);
  });

  describe("LaunchToken", function () {
    it("Should have correct initial supply", async function () {
      expect(await token.totalSupply()).to.equal(ethers.parseUnits("1000000", 18));
    });

    it("Should allow owner to mint", async function () {
      await token.mint(addr1.address, ethers.parseUnits("1000", 18));
      expect(await token.balanceOf(addr1.address)).to.equal(ethers.parseUnits("1000", 18));
    });

    it("Should allow batch transfer", async function () {
      await token.batchTransfer([addr1.address, addr2.address], [ethers.parseUnits("100", 18), ethers.parseUnits("200", 18)]);
      expect(await token.balanceOf(addr1.address)).to.equal(ethers.parseUnits("100", 18));
      expect(await token.balanceOf(addr2.address)).to.equal(ethers.parseUnits("200", 18));
    });
  });

  describe("TokenVesting", function () {
    it("Should create a schedule", async function () {
      await token.approve(await vesting.getAddress(), ethers.parseUnits("1000", 18));
      await vesting.createSchedule(
        addr1.address,
        ethers.parseUnits("1000", 18),
        0,
        86400,
        86400 * 365,
        true
      );
      const schedule = await vesting.schedules(addr1.address);
      expect(schedule.totalAmount).to.equal(ethers.parseUnits("1000", 18));
    });
  });

  describe("MultiSigWallet", function () {
    it("Should submit and approve transaction", async function () {
      await multiSig.submit(addr1.address, 100, "0x");
      await multiSig.approve(0);
      expect(await multiSig.getApprovalCount(0)).to.equal(1);
    });
  });

  describe("Treasury", function () {
    it("Should allocate funds", async function () {
      await token.transfer(await treasury.getAddress(), ethers.parseUnits("10000", 18));
      await treasury.allocate("Marketing", ethers.parseUnits("5000", 18), Math.floor(Date.now() / 1000));
      const cats = await treasury.getCategories();
      expect(cats.length).to.equal(1);
      expect(cats[0]).to.equal("Marketing");
    });
  });
});
