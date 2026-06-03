// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title TokenVesting
 * @notice 代币解锁（Vesting）合约 —— 按时间线性释放代币给受益人
 * @dev 支持悬崖期（cliff）、线性解锁期、可撤销计划，防重入保护
 */
contract TokenVesting is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @notice 每个受益人的解锁计划
     * @param totalAmount 总解锁数量
     * @param released 已释放数量
     * @param startTime 解锁开始时间戳
     * @param cliffDuration 悬崖期时长（秒），期间代币完全锁定
     * @param vestingDuration 解锁总时长（秒）
     * @param revocable 是否可撤销
     * @param revoked 是否已被撤销
     */
    struct Schedule {
        uint256 totalAmount;
        uint256 released;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        bool revocable;
        bool revoked;
    }

    IERC20 public token;                     // 要解锁的代币
    mapping(address => Schedule) public schedules;  // 受益人 => 解锁计划
    uint256 public totalAllocated;           // 已分配的总代币数量

    event ScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration
    );
    event TokensReleased(address indexed beneficiary, uint256 amount);
    event ScheduleRevoked(address indexed beneficiary, uint256 refundAmount);

    /**
     * @notice 构造函数
     * @param tokenAddress 代币合约地址
     * @param owner_ 合约所有者地址
     */
    constructor(address tokenAddress, address owner_) {
        require(tokenAddress != address(0), "Invalid token");
        token = IERC20(tokenAddress);
        _transferOwnership(owner_);
    }

    /**
     * @notice 为受益人创建解锁计划（仅所有者可调用）
     * @param beneficiary 受益地址
     * @param amount 解锁总数量
     * @param startTime 起始时间（0 表示当前时间）
     * @param cliffDuration 悬崖期（秒）
     * @param vestingDuration 解锁总时长（秒）
     * @param revocable 是否可撤销
     */
    function createSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revocable
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(schedules[beneficiary].totalAmount == 0, "Schedule exists");
        require(amount > 0, "Amount must be > 0");
        require(vestingDuration > 0, "Vesting must be > 0");
        require(cliffDuration <= vestingDuration, "Cliff > vesting");
        if (startTime == 0) startTime = block.timestamp;

        schedules[beneficiary] = Schedule({
            totalAmount: amount,
            released: 0,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            revocable: revocable,
            revoked: false
        });

        totalAllocated += amount;
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit ScheduleCreated(
            beneficiary,
            amount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    /**
     * @notice 查询受益人当前可释放但尚未释放的代币数量
     * @param beneficiary 受益地址
     * @return 可释放数量
     */
    function releasable(address beneficiary) public view returns (uint256) {
        Schedule storage s = schedules[beneficiary];
        if (s.totalAmount == 0 || s.revoked) return 0;
        return vestedAmount(beneficiary) - s.released;
    }

    /**
     * @notice 计算截至当前时间已经解锁的代币数量
     * @param beneficiary 受益地址
     * @return 已解锁数量
     */
    function vestedAmount(address beneficiary) public view returns (uint256) {
        Schedule storage s = schedules[beneficiary];
        if (s.totalAmount == 0) return 0;
        if (block.timestamp < s.startTime + s.cliffDuration) return 0;
        if (block.timestamp >= s.startTime + s.vestingDuration) {
            return s.totalAmount;
        }
        uint256 elapsed = block.timestamp - s.startTime;
        return (s.totalAmount * elapsed) / s.vestingDuration;
    }

    /**
     * @notice 受益人领取已解锁的代币（任何人可为自己调用）
     */
    function release() external nonReentrant {
        uint256 amount = releasable(msg.sender);
        require(amount > 0, "No tokens to release");

        Schedule storage s = schedules[msg.sender];
        s.released += amount;
        token.safeTransfer(msg.sender, amount);
        emit TokensReleased(msg.sender, amount);
    }

    /**
     * @notice 撤销受益人的解锁计划（仅所有者可调用）
     * @param beneficiary 受益地址
     */
    function revoke(address beneficiary) external onlyOwner {
        Schedule storage s = schedules[beneficiary];
        require(s.revocable, "Not revocable");
        require(!s.revoked, "Already revoked");
        require(s.totalAmount > 0, "No schedule");

        s.revoked = true;
        uint256 vested = vestedAmount(beneficiary);
        uint256 unreleased = vested - s.released;
        uint256 refund = s.totalAmount - vested;

        if (unreleased > 0) {
            s.released += unreleased;
            token.safeTransfer(beneficiary, unreleased);
        }
        if (refund > 0) {
            token.safeTransfer(owner(), refund);
        }
        emit ScheduleRevoked(beneficiary, refund);
    }

    /**
     * @notice 紧急提现 —— 将所有代币转回所有者（仅所有者可调用）
     */
    function emergencyWithdraw() external onlyOwner {
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No balance");
        token.safeTransfer(owner(), balance);
    }
}
