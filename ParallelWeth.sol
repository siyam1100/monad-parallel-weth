// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title ParallelWeth
 * @dev Distributes structural state balances into partitioned storage buckets to avoid parallel access conflicts.
 */
contract ParallelWeth is IERC20 {
    
    string public constant name = "Parallel Wrapped Ether";
    string public constant symbol = "pWETH";
    uint8 public constant decimals = 18;

    // Split balance allocations across 16 completely separate structural bucket tracking slots
    uint256 private constant BUCKET_COUNT = 16;
    mapping(address => mapping(uint256 => uint256)) private _bucketedBalances;
    mapping(address => mapping(address => uint256)) private _allowances;
    
    uint256 private _totalAssetSupply;

    event DepositLogged(address indexed investor, uint256 value);
    event WithdrawalLogged(address indexed investor, uint256 value);

    function totalSupply() external view override returns (uint256) {
        return _totalAssetSupply;
    }

    /**
     * @notice Retrieves the total aggregated balance across all partitioned storage buckets.
     */
    function balanceOf(address account) public view override returns (uint256 balance) {
        for (uint256 i = 0; i < BUCKET_COUNT; i++) {
            balance += _bucketedBalances[account][i];
        }
    }

    /**
     * @notice Wraps native asset tokens using a bucket calculated from the target address.
     */
    function deposit() external payable {
        uint256 targetBucket = uint256(uint160(msg.sender)) % BUCKET_COUNT;
        
        _bucketedBalances[msg.sender][targetBucket] += msg.value;
        _totalAssetSupply += msg.value;
        
        emit DepositLogged(msg.sender, msg.value);
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function transfer(address to, uint256 amount) external override returns (bool) {
        uint256 sourceBucket = uint256(uint160(msg.sender)) % BUCKET_COUNT;
        uint256 targetBucket = uint256(uint160(to)) % BUCKET_COUNT;

        require(_bucketedBalances[msg.sender][sourceBucket] >= amount, "ERC20: transfer amount exceeds balance");

        _bucketedBalances[msg.sender][sourceBucket] -= amount;
        _bucketedBalances[to][targetBucket] += amount;

        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override returns (bool) {
        uint256 currentAllowance = _allowances[from][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        
        uint256 sourceBucket = uint256(uint160(from)) % BUCKET_COUNT;
        uint256 targetBucket = uint256(uint160(to)) % BUCKET_COUNT;

        require(_bucketedBalances[from][sourceBucket] >= amount, "ERC20: transfer amount exceeds balance");

        _allowances[from][msg.sender] = currentAllowance - amount;
        _bucketedBalances[from][sourceBucket] -= amount;
        _bucketedBalances[to][targetBucket] += amount;

        emit Transfer(from, to, amount);
        return true;
    }
}
