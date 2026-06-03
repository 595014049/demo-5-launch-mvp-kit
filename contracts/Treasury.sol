// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title Treasury
 * @notice 资金库合约 —— 按类别分配带时间锁的代币资金
 * @dev 支持多个分配类别（如 Marketing、Team、Ecosystem），每个类别有独立的释放时间
 */
contract Treasury is Ownable {
    using SafeERC20 for IERC20;

    /**
     * @notice 资金分配结构体
     * @param amount 分配总额
     * @param released 已释放数量
     * @param category 类别名称
     * @param releaseTime 解锁时间戳
     */
    struct Allocation {
        uint256 amount;
        uint256 released;
        string category;
        uint256 releaseTime;
    }

    IERC20 public token;                              // 管理的代币
    mapping(string => Allocation) public allocations;  // 类别 => 分配详情
    string[] public categories;                        // 所有类别列表
    uint256 public totalAllocated;                     // 已分配总量

    event FundAllocated(string category, uint256 amount, uint256 releaseTime);
    event FundReleased(string category, uint256 amount);
    event TokenReceived(address indexed sender, uint256 amount);

    /**
     * @notice 构造函数
     * @param tokenAddress 代币合约地址
     * @param owner_ 合约所有者地址（建议设为多签钱包）
     */
    constructor(address tokenAddress, address owner_) {
        require(tokenAddress != address(0), "Invalid token");
        token = IERC20(tokenAddress);
        _transferOwnership(owner_);
    }

    /**
     * @notice 创建新的资金分配类别（仅所有者可调用）
     * @param category 类别名称（如 "Marketing"）
     * @param amount 分配数量
     * @param releaseTime 解锁时间戳
     */
    function allocate(
        string calldata category,
        uint256 amount,
        uint256 releaseTime
    ) external onlyOwner {
        require(bytes(category).length > 0, "Empty category");
        require(amount > 0, "Amount must be > 0");
        require(allocations[category].amount == 0, "Category exists");

        uint256 balance = token.balanceOf(address(this));
        require(balance >= totalAllocated + amount, "Insufficient balance");

        allocations[category] = Allocation({
            amount: amount,
            released: 0,
            category: category,
            releaseTime: releaseTime
        });
        categories.push(category);
        totalAllocated += amount;
        emit FundAllocated(category, amount, releaseTime);
    }

    /**
     * @notice 释放某类别的资金到指定地址（仅所有者可调用）
     * @param category 类别名称
     * @param to 接收地址
     * @param amount 释放数量
     */
    function release(
        string calldata category,
        address to,
        uint256 amount
    ) external onlyOwner {
        Allocation storage a = allocations[category];
        require(a.amount > 0, "Category not found");
        require(block.timestamp >= a.releaseTime, "Not released yet");
        require(a.released + amount <= a.amount, "Exceeds allocation");

        a.released += amount;
        token.safeTransfer(to, amount);
        emit FundReleased(category, amount);
    }

    /// @notice 获取所有类别名称列表
    function getCategories()
        external
        view
        returns (string[] memory)
    {
        return categories;
    }

    /// @notice 获取某类别的分配详情
    function getAllocation(
        string calldata category
    ) external view returns (Allocation memory) {
        return allocations[category];
    }

    /// @notice 查询合约中未分配的可用余额
    function availableBalance() external view returns (uint256) {
        return token.balanceOf(address(this)) - totalAllocated;
    }

    /**
     * @notice 紧急提现 —— 将指定数量代币转出
     * @param to 接收地址
     * @param amount 转出数量
     */
    function emergencyWithdraw(
        address to,
        uint256 amount
    ) external onlyOwner {
        token.safeTransfer(to, amount);
    }

    /// @notice 向资金库转入代币
    function receiveTokens(uint256 amount) external {
        token.safeTransferFrom(msg.sender, address(this), amount);
        emit TokenReceived(msg.sender, amount);
    }
}
