// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title MultiSigWallet
 * @notice 多签钱包合约 —— N 个所有者中需 M 个签名才能执行交易
 * @dev 支持提交交易、批准、撤销批准和执行，可接收 ETH
 */
contract MultiSigWallet {
    // ============ 事件 ============
    event Deposit(address indexed sender, uint256 amount);       // 存入 ETH
    event Submit(uint256 indexed txId);                          // 提交新交易
    event Approve(address indexed owner, uint256 indexed txId);  // 批准交易
    event Revoke(address indexed owner, uint256 indexed txId);   // 撤销批准
    event Execute(uint256 indexed txId);                         // 执行交易

    // ============ 数据结构 ============
    /**
     * @notice 交易结构体
     * @param to 目标地址
     * @param value 发送的 ETH 数量
     * @param data 调用数据（函数选择器 + 参数）
     * @param executed 是否已执行
     */
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    // ============ 状态变量 ============
    address[] public owners;                           // 所有者列表
    mapping(address => bool) public isOwner;           // 地址是否是所有者
    uint256 public required;                           // 执行交易所需的最少批准数

    Transaction[] public transactions;                 // 所有交易记录
    mapping(uint256 => mapping(address => bool)) public approved;  // txId => 所有者 => 是否批准

    // ============ 修饰器 ============
    modifier onlyOwner() {
        require(isOwner[msg.sender], "Not owner");
        _;
    }

    modifier txExists(uint256 _txId) {
        require(_txId < transactions.length, "Tx does not exist");
        _;
    }

    modifier notExecuted(uint256 _txId) {
        require(!transactions[_txId].executed, "Tx already executed");
        _;
    }

    modifier notApproved(uint256 _txId) {
        require(!approved[_txId][msg.sender], "Tx already approved");
        _;
    }

    /**
     * @notice 构造函数：设定所有者列表和所需批准数
     * @param _owners 所有者地址数组
     * @param _required 执行交易所需的最小签名数
     */
    constructor(address[] memory _owners, uint256 _required) {
        require(_owners.length > 0, "Owners required");
        require(
            _required > 0 && _required <= _owners.length,
            "Invalid required number"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "Invalid owner");
            require(!isOwner[owner], "Owner not unique");
            isOwner[owner] = true;
            owners.push(owner);
        }
        required = _required;
    }

    /** @notice 接收 ETH 时触发 Deposit 事件 */
    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    /**
     * @notice 提交新交易（仅所有者可调用）
     * @param _to 目标合约地址
     * @param _value 发送的 ETH 数量
     * @param _data 调用数据（如函数选择器）
     */
    function submit(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external onlyOwner {
        transactions.push(
            Transaction({to: _to, value: _value, data: _data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    /**
     * @notice 批准某笔交易（仅所有者可调用，不可重复批准）
     * @param _txId 交易 ID
     */
    function approve(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) notApproved(_txId) {
        approved[_txId][msg.sender] = true;
        emit Approve(msg.sender, _txId);
    }

    /**
     * @notice 获取某笔交易当前的批准数量
     * @param _txId 交易 ID
     * @return count 已批准的人数
     */
    function getApprovalCount(
        uint256 _txId
    ) public view returns (uint256 count) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (approved[_txId][owners[i]]) {
                count++;
            }
        }
    }

    /**
     * @notice 执行交易（达到足够批准数后任何人均可触发）
     * @param _txId 交易 ID
     */
    function execute(
        uint256 _txId
    ) external txExists(_txId) notExecuted(_txId) {
        require(getApprovalCount(_txId) >= required, "Not enough approvals");
        Transaction storage transaction = transactions[_txId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "Tx failed");
        emit Execute(_txId);
    }

    /**
     * @notice 撤销对某笔交易的批准（仅所有者可调用）
     * @param _txId 交易 ID
     */
    function revoke(
        uint256 _txId
    ) external onlyOwner txExists(_txId) notExecuted(_txId) {
        require(approved[_txId][msg.sender], "Tx not approved");
        approved[_txId][msg.sender] = false;
        emit Revoke(msg.sender, _txId);
    }

    // ============ 查询函数 ============
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /**
     * @notice 获取某笔交易的详细信息
     * @param _txId 交易 ID
     */
    function getTransaction(
        uint256 _txId
    )
        external
        view
        returns (
            address to,
            uint256 value,
            bytes memory data,
            bool executed
        )
    {
        Transaction storage t = transactions[_txId];
        return (t.to, t.value, t.data, t.executed);
    }
}
