// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @title LaunchToken
 * @notice 项目启动代币合约 —— 支持铸造、销毁、批量转账和限额供应
 * @dev 继承 OpenZeppelin 的 ERC20 + Burnable + Ownable + Permit 标准
 */
contract LaunchToken is ERC20, ERC20Burnable, Ownable, ERC20Permit {
    uint8 private _decimals;       // 自定义小数位数
    uint256 public maxSupply;      // 最大供应量上限
    bool public mintingFinished;   // 是否已停止铸造

    event MintingFinished();       // 铸造停止事件

    /**
     * @notice 构造函数：初始化代币基本信息
     * @param name_ 代币名称（如 "My Token"）
     * @param symbol_ 代币符号（如 "MTK"）
     * @param decimals_ 小数位数（最大 18）
     * @param initialSupply_ 初始铸造量（部署时直接给 owner）
     * @param maxSupply_ 最大供应量（铸造不可超过此值）
     * @param owner_ 合约所有者地址
     */
    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply_,
        uint256 maxSupply_,
        address owner_
    ) ERC20(name_, symbol_) ERC20Permit(name_) {
        require(decimals_ <= 18, "Decimals too high");
        require(maxSupply_ >= initialSupply_, "Max supply < initial");
        _decimals = decimals_;
        maxSupply = maxSupply_;
        if (initialSupply_ > 0) {
            _mint(owner_, initialSupply_);
        }
        _transferOwnership(owner_);
    }

    /**
     * @notice 返回自定义的小数位数
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @notice 铸造新代币（仅合约所有者可调用）
     * @param to 接收地址
     * @param amount 铸造数量
     */
    function mint(address to, uint256 amount) external onlyOwner {
        require(!mintingFinished, "Minting finished");
        require(totalSupply() + amount <= maxSupply, "Exceeds max supply");
        _mint(to, amount);
    }

    /**
     * @notice 永久停止铸造功能（仅合约所有者可调用）
     * @dev 此操作不可逆
     */
    function finishMinting() external onlyOwner {
        require(!mintingFinished, "Already finished");
        mintingFinished = true;
        emit MintingFinished();
    }

    /**
     * @notice 批量转账 —— 一次性向多个地址转账
     * @param recipients 接收地址数组
     * @param amounts 对应转账金额数组
     * @return 是否成功
     */
    function batchTransfer(
        address[] calldata recipients,
        uint256[] calldata amounts
    ) external returns (bool) {
        require(recipients.length == amounts.length, "Length mismatch");
        for (uint256 i = 0; i < recipients.length; i++) {
            _transfer(msg.sender, recipients[i], amounts[i]);
        }
        return true;
    }
}
